# Handers for execute_request and related messages, which are
# the core of the Jupyter protocol: execution of Julia code and
# returning results.

import Base.Libc: flush_cstdio

using Compat

const text_plain = MIME("text/plain")
const image_svg = MIME("image/svg+xml")
const image_png = MIME("image/png")
const image_jpeg = MIME("image/jpeg")
const text_markdown = MIME("text/markdown")
const text_html = MIME("text/html")
const text_latex = MIME("text/latex") # Jupyter expects this
const text_latex2 = MIME("application/x-latex") # but this is more standard?
const application_vnd_vegalite_v2 = MIME("application/vnd.vegalite.v2+json")

include("magics.jl")

# return a String=>Any dictionary to attach as metadata
# in Jupyter display_data and pyout messages
metadata(x) = Dict()

# return a String=>String dictionary of mimetype=>data
# for passing to Jupyter display_data and execute_result messages.
function display_dict(x)
    data = Dict{String,Any}("text/plain" => limitstringmime(text_plain, x))
    if mimewritable(application_vnd_vegalite_v2, x)
        data[string(application_vnd_vegalite_v2)] = JSON.parse(limitstringmime(application_vnd_vegalite_v2, x))
    end
    if mimewritable(image_svg, x)
        data[string(image_svg)] = limitstringmime(image_svg, x)
    end
    if mimewritable(image_png, x)
        data[string(image_png)] = limitstringmime(image_png, x)
    elseif mimewritable(image_jpeg, x) # don't send jpeg if we have png
        data[string(image_jpeg)] = limitstringmime(image_jpeg, x)
    end
    if mimewritable(text_markdown, x)
        data[string(text_markdown)] = limitstringmime(text_markdown, x)
    elseif mimewritable(text_html, x)
        data[string(text_html)] = limitstringmime(text_html, x)
    elseif mimewritable(text_latex, x)
        data[string(text_latex)] = limitstringmime(text_latex, x)
    elseif mimewritable(text_latex2, x)
        data[string(text_latex)] = limitstringmime(text_latex2, x)
    end
    return data
end

# queue of objects to display at end of cell execution
const displayqueue = Any[]

# remove x from the display queue
function undisplay(x)
    i = findfirst(equalto(x), displayqueue)
    if i > 0
        splice!(displayqueue, i)
    end
    return x
end

function show_bt(io::IO, top_func::Symbol, t, set)
    # follow PR #17570 code in removing top_func from backtrace
    eval_ind = findlast(addr->Base.REPL.ip_matches_func(addr, top_func), t)
    eval_ind != 0 && (t = t[1:eval_ind-1])
    Base.show_backtrace(io, t)
end

# wrapper for showerror(..., backtrace=false) since invokelatest
# doesn't support keyword arguments.
showerror_nobt(io, e, bt) = showerror(io, e, bt, backtrace=false)

# return the content of a pyerr message for exception e
function error_content(e, bt=catch_backtrace(); backtrace_top::Symbol=:include_string, msg::AbstractString="")
    tb = map(x->String(x), split(sprint(show_bt,
                                        backtrace_top,
                                        bt, 1:typemax(Int)),
                                 "\n", keep=true))
    ename = string(typeof(e))
    evalue = try
        # Peel away one LoadError layer that comes from running include_string on the cell
        isa(e, LoadError) && (e = e.error)
        sprint((io, e, bt) -> invokelatest(showerror_nobt, io, e, bt), e, bt)
    catch
        "SYSTEM: show(lasterr) caused an error"
    end
    unshift!(tb, evalue) # fperez says this needs to be in traceback too
    if !isempty(msg)
        unshift!(tb, msg)
    end
    Dict("ename" => ename, "evalue" => evalue,
                 "traceback" => tb)
end

#######################################################################

# global variable so that display can be done in the correct Msg context
execute_msg = Msg(["julia"], Dict("username"=>"jlkernel", "session"=>uuid4()), Dict())
# global variable tracking the number of bytes written in the current execution
# request
const stdio_bytes = Ref(0)

function helpcode(code::AbstractString)
    code_ = strip(code)
    # as in base/REPL.jl, special-case keywords so that they parse
    if !haskey(Docs.keywords, Symbol(code_))
        return "Base.Docs.@repl $code_"
    else
        return "eval(:(Base.Docs.@repl \$(Symbol(\"$code_\"))))"
    end
end

# use a global array to accumulate "payloads" for the execute_reply message
const execute_payloads = Dict[]

function execute_request(socket, msg)
    code = msg.content["code"]
    @vprintln("EXECUTING ", code)
    global execute_msg = msg
    global n, In, Out, ans
    stdio_bytes[] = 0
    silent = msg.content["silent"]
    store_history = get(msg.content, "store_history", !silent)
    empty!(execute_payloads)

    if !silent
        n += 1
        send_ipython(publish[],
                     msg_pub(msg, "execute_input",
                             Dict("execution_count" => n,
                                          "code" => code)))
    end

    silent = silent || Base.REPL.ends_with_semicolon(code)
    if store_history
        In[n] = code
    end

    # "; ..." cells are interpreted as shell commands for run
    code = replace(code, r"^\s*;.*$",
                   m -> string(replace(m, r"^\s*;", "Base.repl_cmd(`"),
                               "`, STDOUT)"))

    # a cell beginning with "? ..." is interpreted as a help request
    hcode = replace(code, r"^\s*\?", "")
    if hcode != code
        code = helpcode(hcode)
    end

    try
        for hook in preexecute_hooks
            invokelatest(hook)
        end

        #run the code!
        ans = result = ismatch(magics_regex, code) ? magics_help(code) :
            include_string(current_module[], code, "In[$n]")

        if silent
            result = nothing
        elseif result !== nothing
            if store_history
                Out[n] = result
            end
        end

        user_expressions = Dict()
        for (v,ex) in msg.content["user_expressions"]
            user_expressions[v] = invokelatest(parse, ex)
        end

        for hook in postexecute_hooks
            invokelatest(hook)
        end

        # flush pending stdio
        flush_all()

        undisplay(result) # dequeue if needed, since we display result in pyout
        invokelatest(display) # flush pending display requests

        if result !== nothing
            result_metadata = invokelatest(metadata, result)
            result_data = invokelatest(display_dict, result)
            send_ipython(publish[],
                         msg_pub(msg, "execute_result",
                                 Dict("execution_count" => n,
                                              "metadata" => result_metadata,
                                              "data" => result_data)))

        end
        send_ipython(requests[],
                     msg_reply(msg, "execute_reply",
                               Dict("status" => "ok",
                                            "payload" => execute_payloads,
                                            "execution_count" => n,
                                            "user_expressions" => user_expressions)))
        empty!(execute_payloads)
    catch e
        bt = catch_backtrace()
        try
            # flush pending stdio
            flush_all()
            for hook in posterror_hooks
                invokelatest(hook)
            end
        catch
        end
        empty!(displayqueue) # discard pending display requests on an error
        content = error_content(e,bt)
        send_ipython(publish[], msg_pub(msg, "error", content))
        content["status"] = "error"
        content["execution_count"] = n
        send_ipython(requests[], msg_reply(msg, "execute_reply", content))
    end
end
