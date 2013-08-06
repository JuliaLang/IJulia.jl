# Handers for execute_request and related messages, which are
# the core of the IPython protocol: execution of Julia code and
# returning results.

#######################################################################
# History: global In/Out and other history variables exported to Main
const In = Dict{Integer,UTF8String}()
const Out = Dict{Integer,Any}()
_ = __ = __ = ans = nothing
export In, Out, _, __, ___, ans

#######################################################################
using Multimedia

const text_plain = MIME("text/plain")
const image_svg = MIME("image/svg+xml")
const image_png = MIME("image/png")
const image_jpeg = MIME("image/jpeg")
const text_html = MIME("text/html")
const text_latex = MIME("application/x-latex")

# return a String=>String dictionary of mimetype=>data for passing to
# IPython display_data and pyout messages.
function display_dict(x)
    data = [ "text/plain" => stringmime(text_plain, x) ]
    T = typeof(x)
    if mimewritable(image_svg, T)
        data[string(image_svg)] = stringmime(image_svg, x)
    end
    if mimewritable(image_png, T)
        data[string(image_png)] = stringmime(image_png, x)
    elseif mimewritable(image_jpeg, T) # don't send jpeg if we have png
        data[string(image_jpeg)] = stringmime(image_jpeg, x)
    end
    if mimewritable(text_html, T)
        data[string(text_html)] = stringmime(text_html, x)
    end
    if mimewritable(text_latex, T)
        data[string(text_latex)] = stringmime(text_latex, x)
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
end

#######################################################################

# return the content of a pyerr message for exception e
function pyerr_content(e)
    tb = split(sprint(Base.show_backtrace, :execute_request_0x535c5df2, 
                      catch_backtrace(), 1:typemax(Int)), "\n", false)
    if !isempty(tb) && ismatch(r"^\s*in\s+include_string\s+", tb[end])
        pop!(tb) # don't include include_string in backtrace
    end
    ename = string(typeof(e))
    evalue = sprint(Base.error_show, e)
    unshift!(tb, evalue) # fperez says this needs to be in traceback too
    ["execution_count" => _n,
     "ename" => ename, "evalue" => evalue,
     "traceback" => tb]
end

#######################################################################
# Similar to the ipython kernel, we provide a mechanism by
# which modules can register thunk functions to be called after
# executing an input cell, e.g. to "close" the current plot in Pylab.
# Modules should only use these if isdefined(Main, IJulia) is true.

const postexecute_hooks = Function[]

push_postexecute_hook(f::Function) = push!(postexecute_hooks, f)
pop_postexecute_hook(f::Function) = splice!(postexecute_hooks, findfirst(postexecute_hooks, f))


#######################################################################

# global variable so that display can be done in the correct Msg context
execute_msg = nothing

# note: 0x535c5df2 is a random integer to make name collisions in
# backtrace analysis less likely.
function execute_request_0x535c5df2(socket, msg)
    vprintln("EXECUTING ", msg.content["code"])
    global execute_msg = msg
    global _n, In, Out, _, __, ___, ans
    silent = msg.content["silent"] || ismatch(r";\s*$", msg.content["code"])

    # present in spec but missing from notebook's messages:
    store_history = get(msg.content, "store_history", !silent)

    if !silent
        _n += 1
        if store_history
            In[_n] = msg.content["code"]
        end
        send_ipython(publish, 
                     msg_pub(msg, "pyin",
                             ["execution_count" => _n,
                              "code" => msg.content["code"]]))
    else
        vprintln("SILENT")
    end

    send_status("busy")

    try 
        ans = result = include_string(msg.content["code"], "In[$_n]")
        if silent
            result = nothing
        elseif result != nothing
            ___ = __ # 3rd result from last
            __ = _ # 2nd result from last
            _ = result
            if store_history
                Out[_n] = result == Out ? nothing : result # Julia #3066
                eval(Main, :($(symbol(string("_",_n))) = Out[$_n]))
            end
        end

        user_variables = Dict()
        user_expressions = Dict()
        for v in msg.content["user_variables"]
            user_variables[v] = eval(Main,parse(v))
        end
        for (v,ex) in msg.content["user_expressions"]
            user_expressions[v] = eval(Main,parse(ex))
        end

        for hook in postexecute_hooks
            hook()
        end

        if result != nothing
            send_ipython(publish, 
                         msg_pub(msg, "pyout",
                                 ["execution_count" => _n,
                                 "metadata" => Dict(), # qtconsole needs this
                                 "data" => display_dict(result) ]))
            undisplay(result) # in case display was queued
        end
        
        display() # flush pending display requests

        send_ipython(requests,
                     msg_reply(msg, "execute_reply",
                               ["status" => "ok", "execution_count" => _n,
                               "payload" => [],
                               "user_variables" => user_variables,
                                "user_expressions" => user_expressions]))
    catch e
        empty!(displayqueue) # discard pending display requests on an error
        content = pyerr_content(e)
        send_ipython(publish, msg_pub(msg, "pyerr", content))
        content["status"] = "error"
        send_ipython(requests, msg_reply(msg, "execute_reply", content))
    end

    send_status("idle")
end

#######################################################################
