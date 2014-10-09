# Handers for execute_request and related messages, which are
# the core of the IPython protocol: execution of Julia code and
# returning results.

#######################################################################
const text_plain = MIME("text/plain")
const image_svg = MIME("image/svg+xml")
const image_png = MIME("image/png")
const image_jpeg = MIME("image/jpeg")
const text_html = MIME("text/html")
const text_latex = MIME("text/latex") # IPython expects this
const text_latex2 = MIME("application/x-latex") # but this is more standard?

# backwards compatibility with old mimewritable API
if method_exists(mimewritable, (String,Any))
    mimewritable_(mime, x) = mimewritable(mime, x)
else
    mimewritable_(mime, x) = mimewritable(mime, typeof(x))
end

# return a String=>Any dictionary to attach as metadata
# in IPython display_data and pyout messages
metadata(x) = Dict()

# return a String=>String dictionary of mimetype=>data for passing to
# IPython display_data and pyout messages.
function display_dict(x)
    data = Dict{ASCIIString,ByteString}( "text/plain" =>
                                          sprint(writemime, "text/plain", x) )
    if mimewritable_(image_svg, x)
        data[string(image_svg)] = stringmime(image_svg, x)
    end
    if mimewritable_(image_png, x)
        data[string(image_png)] = stringmime(image_png, x)
    elseif mimewritable_(image_jpeg, x) # don't send jpeg if we have png
        data[string(image_jpeg)] = stringmime(image_jpeg, x)
    end
    if mimewritable_(text_html, x)
        data[string(text_html)] = stringmime(text_html, x)
    end
    if mimewritable_(text_latex, x)
        data[string(text_latex)] = stringmime(text_latex, x)
    elseif mimewritable_(text_latex2, x)
        data[string(text_latex)] = stringmime(text_latex2, x)
    end
    return data
end

# queue of objects to display at end of cell execution
const displayqueue = Any[]

# remove x from the display queue
function undisplay(x)
    i = findfirst(displayqueue, x)
    if i > 0
        splice!(displayqueue, i)
    end
    return x
end

#######################################################################

# avoid deprecation warning for change in split API
if VERSION >= v"0.4-"
    splitkeep(str, splitter) = split(str, splitter, keep=true)
else
    splitkeep(str, splitter) = split(str, splitter, true)
end

# return the content of a pyerr message for exception e
function pyerr_content(e, msg::String="")
    tb = map(utf8, splitkeep(sprint(Base.show_backtrace, :execute_request_0x535c5df2, 
                                    catch_backtrace(), 1:typemax(Int)), "\n"))
    if !isempty(tb) && ismatch(r"^\s*in\s+include_string\s+", tb[end])
        pop!(tb) # don't include include_string in backtrace
    end
    ename = string(typeof(e))
    evalue = sprint(showerror, e)
    unshift!(tb, evalue) # fperez says this needs to be in traceback too
    if !isempty(msg)
        unshift!(tb, msg)
    end
    Dict("execution_count" => _n,
         "ename" => ename, "evalue" => evalue,
         "traceback" => tb)
end

#######################################################################
# Similar to the ipython kernel, we provide a mechanism by
# which modules can register thunk functions to be called after
# executing an input cell, e.g. to "close" the current plot in Pylab.
# Modules should only use these if isdefined(Main, IJulia) is true.

const postexecute_hooks = Function[]
push_postexecute_hook(f::Function) = push!(postexecute_hooks, f)
pop_postexecute_hook(f::Function) = splice!(postexecute_hooks, findfirst(postexecute_hooks, f))

const preexecute_hooks = Function[]
push_preexecute_hook(f::Function) = push!(preexecute_hooks, f)
pop_preexecute_hook(f::Function) = splice!(preexecute_hooks, findfirst(pretexecute_hooks, f))

# similar, but called after an error (e.g. to reset plotting state)
const posterror_hooks = Function[]
push_posterror_hook(f::Function) = push!(posterror_hooks, f)
pop_posterror_hook(f::Function) = splice!(posterror_hooks, findfirst(posterror_hooks, f))

#######################################################################

# global variable so that display can be done in the correct Msg context
execute_msg = Msg(["julia"], Dict("username"=>"julia", "session"=>"????"), Dict())

# note: 0x535c5df2 is a random integer to make name collisions in
# backtrace analysis less likely.
function execute_request_0x535c5df2(socket, msg)
    code = msg.content["code"]
    @vprintln("EXECUTING ", code)
    global execute_msg = msg
    global _n, In, Out, _, __, ___, ans
    silent = msg.content["silent"] || ismatch(r";\s*$", code)

    # present in spec but missing from notebook's messages:
    store_history = get(msg.content, "store_history", !silent)

    _n += 1
    if store_history
        In[_n] = code
    end
    send_ipython(publish, 
                 msg_pub(msg, "pyin",
                         Dict("execution_count" => _n,
                              "code" => code)))

    # "; ..." cells are interpreted as shell commands for run
    code = replace(code, r"^\s*;.*$", 
                   m -> string(replace(m, r"^\s*;", "Base.repl_cmd(`"), 
                               "`)"), 0)

    # a cell beginning with "? ..." is interpreted as a help request
    code = replace(code, r"^\s*\?", "Base.@help ")

    try 
        for hook in preexecute_hooks
            hook()
        end
        ans = result = include_string(code, "In[$_n]")
        if silent
            result = nothing
        elseif result != nothing
            ___ = __ # 3rd result from last
            __ = _ # 2nd result from last
            _ = result
            if store_history
                if result != Out # workaround for Julia #3066
                    Out[_n] = result 
                    # note: don't use result in eval, since things
                    # get confused if result is a symbol:
                    eval(Main, :($(symbol(string("_",_n))) = Out[$_n]))
                end
            end
        end

        user_variables = Dict()
        user_expressions = Dict()
        for v in get(msg.content, "user_variables", String[]) # gone in IPy3
            user_variables[v] = eval(Main,parse(v))
        end
        for (v,ex) in msg.content["user_expressions"]
            user_expressions[v] = eval(Main,parse(ex))
        end

        for hook in postexecute_hooks
            hook()
        end

	# flush pending stdio
        flush_cstdio() # flush writes to stdout/stderr by external C code
	send_stream(takebuf_string(read_stdout.buffer), "stdout")
	send_stream(takebuf_string(read_stderr.buffer), "stderr")

        undisplay(result) # dequeue if needed, since we display result in pyout
        display() # flush pending display requests

        if result != nothing

            # Work around for Julia issue #265 (see # #7884 for context)
            # We have to explicitly invoke the correct metadata method.
            result_metadata = invoke(metadata, (typeof(result),), result)

            send_ipython(publish,
                         msg_pub(msg, "pyout",
                                 Dict("execution_count" => _n,
                                      "metadata" => result_metadata,
                                      "data" => display_dict(result) )))
        end
        
        send_ipython(requests,
                     msg_reply(msg, "execute_reply",
                               Dict("status" => "ok", "execution_count" => _n,
                                    "payload" => [],
                                    "user_variables" => user_variables,
                                    "user_expressions" => user_expressions)))
    catch e
        try
            # flush pending stdio
            flush_cstdio() # flush writes to stdout/stderr by external C code
            send_stream(takebuf_string(read_stdout.buffer), "stdout")
            send_stream(takebuf_string(read_stderr.buffer), "stderr")
            for hook in posterror_hooks
                hook()
            end
        catch
        end
        empty!(displayqueue) # discard pending display requests on an error
        content = pyerr_content(e)
        send_ipython(publish, msg_pub(msg, "pyerr", content))
        content["status"] = "error"
        send_ipython(requests, msg_reply(msg, "execute_reply", content))
    end
end

#######################################################################
