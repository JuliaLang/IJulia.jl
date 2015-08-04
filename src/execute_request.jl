# Handers for execute_request and related messages, which are
# the core of the IPython protocol: execution of Julia code and
# returning results.

if VERSION >= v"0.4.0-dev+3844"
    import Base.Libc: flush_cstdio
end

#######################################################################
const text_plain = MIME("text/plain")
const image_svg = MIME("image/svg+xml")
const image_png = MIME("image/png")
const image_jpeg = MIME("image/jpeg")
const text_markdown = MIME("text/markdown")
const text_html = MIME("text/html")
const text_latex = MIME("text/latex") # IPython expects this
const text_latex2 = MIME("application/x-latex") # but this is more standard?

# return a AbstractString=>Any dictionary to attach as metadata
# in IPython display_data and pyout messages
metadata(x) = Dict()

# return a AbstractString=>AbstractString dictionary of mimetype=>data for passing to
# IPython display_data and pyout messages.
function display_dict(x)
    data = @compat Dict{ASCIIString,ByteString}("text/plain" => 
                                        sprint(writemime, "text/plain", x))
    if mimewritable(image_svg, x)
        data[string(image_svg)] = stringmime(image_svg, x)
    end
    if mimewritable(image_png, x)
        data[string(image_png)] = stringmime(image_png, x)
    elseif mimewritable(image_jpeg, x) # don't send jpeg if we have png
        data[string(image_jpeg)] = stringmime(image_jpeg, x)
    end
    if mimewritable(text_markdown, x)
        data[string(text_markdown)] = stringmime(text_markdown, x)
    elseif mimewritable(text_html, x)
        data[string(text_html)] = stringmime(text_html, x)
    end
    if mimewritable(text_latex, x)
        data[string(text_latex)] = stringmime(text_latex, x)
    elseif mimewritable(text_latex2, x)
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

if v"0.4.0-dev+6438" <= VERSION < v"0.4.0-dev+6492" # julia PR #12250
    function show_bt(io::IO, top_func::Symbol, t, set)
        process_entry(lastname, lastfile, lastline, n) = Base.show_trace_entry(io, lastname, lastfile, lastline, n)
        Base.process_backtrace(process_entry, top_func, t, set)
    end
else
    show_bt(io::IO, top_func::Symbol, t, set) =
        Base.show_backtrace(io, top_func, t, set)
end

# return the content of a pyerr message for exception e
function error_content(e; backtrace_top::Symbol=:execute_request_0x535c5df2, msg::AbstractString="")
    bt = catch_backtrace()
    tb = map(utf8, @compat(split(sprint(show_bt,
                                        backtrace_top, 
                                        bt, 1:typemax(Int)),
                                 "\n", keep=true)))
    if !isempty(tb) && ismatch(r"^\s*in\s+include_string\s+", tb[end])
        pop!(tb) # don't include include_string in backtrace
    end
    ename = string(typeof(e))
    evalue = try
        sprint(VERSION < v"0.4.0-dev+5252" ? (io, e, bt) -> showerror(io, e) :
               (io, e, bt) -> showerror(io, e, bt, backtrace=false), e, bt)
    catch
        "SYSTEM: show(lasterr) caused an error"
    end
    unshift!(tb, evalue) # fperez says this needs to be in traceback too
    if !isempty(msg)
        unshift!(tb, msg)
    end
    @compat Dict("ename" => ename, "evalue" => evalue,
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
execute_msg = Msg(["julia"], @compat(Dict("username"=>"julia", "session"=>"????")), Dict())

if VERSION >= v"0.4.0-dev+1853"
    # in Julia commit edbfd4053ccd2970789931ad56dc336c8dd7f029,
    # repl_cmd(cmd) was replaced by repl_cmd(cmd, out); just add the old method
    Base.repl_cmd(cmd) = Base.repl_cmd(cmd, STDOUT)
end

function helpcode(code::AbstractString)
    if VERSION < v"0.4.0-dev+2891" # old Base.@help macro
        return "Base.@help " * code
    else # new Base.Docs.@repl macro from julia@08663d4bb05c5b8805a57f46f4feacb07c7f2564
        code_ = strip(code)
        # as in base/REPL.jl, special-case keywords so that they parse
        return "Base.Docs.@repl " * (haskey(Docs.keywords, symbol(code_)) ?
                                     ":"*code_ : code_)
    end
end

# note: 0x535c5df2 is a random integer to make name collisions in
# backtrace analysis less likely.
function execute_request_0x535c5df2(socket, msg)
    code = msg.content["code"]
    @vprintln("EXECUTING ", code)
    global execute_msg = msg
    global _n, In, Out, ans
    silent = msg.content["silent"]
    store_history = get(msg.content, "store_history", !silent)

    if !silent
        _n += 1
        send_ipython(publish, 
                     msg_pub(msg, "execute_input",
                             @compat Dict("execution_count" => _n,
                                          "code" => code)))
    end
    
    silent = silent || ismatch(r";\s*$", code)
    if store_history
        In[_n] = code
    end

    # "; ..." cells are interpreted as shell commands for run
    code = replace(code, r"^\s*;.*$", 
                   m -> string(replace(m, r"^\s*;", "Base.repl_cmd(`"), 
                               "`)"), 0)

    # a cell beginning with "? ..." is interpreted as a help request
    hcode = replace(code, r"^\s*\?", "")
    if hcode != code
        code = helpcode(hcode)
    end

    try 
        for hook in preexecute_hooks
            hook()
        end
        ans = result = include_string(code, "In[$_n]")
        if silent
            result = nothing
        elseif result != nothing
            if store_history
                if result != Out # workaround for Julia #3066
                    Out[_n] = result 
                end
            end
        end

        user_expressions = Dict()
        for (v,ex) in msg.content["user_expressions"]
            user_expressions[v] = eval(Main,parse(ex))
        end

        for hook in postexecute_hooks
            hook()
        end

	# flush pending stdio
        flush_cstdio() # flush writes to stdout/stderr by external C code
        yield()
        send_stream(read_stdout, "stdout")
        send_stream(read_stderr, "stderr")

        undisplay(result) # dequeue if needed, since we display result in pyout
        display() # flush pending display requests

        if result != nothing

            # Work around for Julia issue #265 (see # #7884 for context)
            # We have to explicitly invoke the correct metadata method.
            result_metadata = invoke(metadata, (typeof(result),), result)

            send_ipython(publish,
                         msg_pub(msg, "execute_result",
                                 @compat Dict("execution_count" => _n,
                                              "metadata" => result_metadata,
                                              "data" => display_dict(result))))
            
            flush_cstdio() # flush writes to stdout/stderr by external C code
            yield()
            send_stream(read_stdout, "stdout")
            send_stream(read_stderr, "stderr")
        end
        
        send_ipython(requests,
                     msg_reply(msg, "execute_reply",
                               @compat Dict("status" => "ok",
                                            "payload" => "", # TODO: remove (see #325)
                                            "execution_count" => _n,
                                            "user_expressions" => user_expressions)))
    catch e
        try
            # flush pending stdio
            flush_cstdio() # flush writes to stdout/stderr by external C code
            yield()
            send_stream(read_stdout, "stdout")
            send_stream(read_stderr, "stderr")
            for hook in posterror_hooks
                hook()
            end
        catch
        end
        empty!(displayqueue) # discard pending display requests on an error
        content = error_content(e)
        send_ipython(publish, msg_pub(msg, "error", content))
        content["status"] = "error"
        content["execution_count"] = _n
        send_ipython(requests, msg_reply(msg, "execute_reply", content))
    end
end

#######################################################################

# The user can call IJulia.clear_output() to clear visible output from the
# front end, useful for simple animations.  Using wait=true clears the
# output only when new output is available, for minimal flickering.
function clear_output(wait=false)
    # flush pending stdio
    flush_cstdio() # flush writes to stdout/stderr by external C code   
    send_stream(read_stdout, "stdout")
    send_stream(read_stderr, "stderr")
    send_ipython(publish, msg_reply(execute_msg::Msg, "clear_output",
                                    @compat Dict("wait" => wait)))
end
