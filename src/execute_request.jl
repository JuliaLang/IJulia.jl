# Handers for execute_request and related messages, which are
# the core of the Jupyter protocol: execution of Julia code and
# returning results.

import Base.Libc: flush_cstdio
import Pkg

const text_plain = MIME("text/plain")
const image_svg = MIME("image/svg+xml")
const image_png = MIME("image/png")
const image_jpeg = MIME("image/jpeg")
const text_markdown = MIME("text/markdown")
const text_html = MIME("text/html")
const text_latex = MIME("text/latex") # Jupyter expects this
const text_latex2 = MIME("application/x-latex") # but this is more standard?
const application_vnd_vega_v3 = MIME("application/vnd.vega.v3+json")
const application_vnd_vegalite_v2 = MIME("application/vnd.vegalite.v2+json")
const application_vnd_dataresource = MIME("application/vnd.dataresource+json")

include("magics.jl")

# return a String=>Any dictionary to attach as metadata
# in Jupyter display_data and pyout messages
metadata(x) = Dict()

# return a String=>String dictionary of mimetype=>data
# for passing to Jupyter display_data and execute_result messages.
function display_dict(x)
    data = Dict{String,Any}("text/plain" => limitstringmime(text_plain, x))
    if showable(application_vnd_vegalite_v2, x)
        data[string(application_vnd_vegalite_v2)] = JSON.JSONText(limitstringmime(application_vnd_vegalite_v2, x))
    elseif showable(application_vnd_vega_v3, x) # don't send vega if we have vega-lite
        data[string(application_vnd_vega_v3)] = JSON.JSONText(limitstringmime(application_vnd_vega_v3, x))
    end
    if showable(application_vnd_dataresource, x)
        data[string(application_vnd_dataresource)] = JSON.JSONText(limitstringmime(application_vnd_dataresource, x))
    end
    if showable(image_svg, x)
        data[string(image_svg)] = limitstringmime(image_svg, x)
    end
    if showable(image_png, x)
        data[string(image_png)] = limitstringmime(image_png, x)
    elseif showable(image_jpeg, x) # don't send jpeg if we have png
        data[string(image_jpeg)] = limitstringmime(image_jpeg, x)
    end
    if showable(text_markdown, x)
        data[string(text_markdown)] = limitstringmime(text_markdown, x)
    elseif showable(text_html, x)
        data[string(text_html)] = limitstringmime(text_html, x)
    elseif showable(text_latex, x)
        data[string(text_latex)] = limitstringmime(text_latex, x)
    elseif showable(text_latex2, x)
        data[string(text_latex)] = limitstringmime(text_latex2, x)
    end
    return data
end

# queue of objects to display at end of cell execution
const displayqueue = Any[]

# remove x from the display queue
function undisplay(x)
    i = findfirst(isequal(x), displayqueue)
    i !== nothing && splice!(displayqueue, i)
    return x
end

import Base: ip_matches_func

function show_bt(io::IO, top_func::Symbol, t, set)
    # follow PR #17570 code in removing top_func from backtrace
    eval_ind = findlast(addr->ip_matches_func(addr, top_func), t)
    eval_ind !== nothing && (t = t[1:eval_ind-1])
    Base.show_backtrace(io, t)
end

# wrapper for showerror(..., backtrace=false) since invokelatest
# doesn't support keyword arguments.
showerror_nobt(io, e, bt) = showerror(io, e, bt, backtrace=false)

# return the content of a pyerr message for exception e
function error_content(e, bt=catch_backtrace();
                       backtrace_top::Symbol=SOFTSCOPE[] ? :softscope_include_string : :include_string,
                       msg::AbstractString="")
    tb = map(x->String(x), split(sprint(show_bt,
                                        backtrace_top,
                                        bt, 1:typemax(Int)),
                                  "\n", keepempty=true))

    ename = string(typeof(e))
    evalue = try
        # Peel away one LoadError layer that comes from running include_string on the cell
        isa(e, LoadError) && (e = e.error)
        sprint((io, e, bt) -> invokelatest(showerror_nobt, io, e, bt), e, bt)
    catch
        "SYSTEM: show(lasterr) caused an error"
    end
    pushfirst!(tb, evalue) # fperez says this needs to be in traceback too
    if !isempty(msg)
        pushfirst!(tb, msg)
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

import REPL: helpmode

# use a global array to accumulate "payloads" for the execute_reply message
const execute_payloads = Dict[]

const stdout_name = isdefined(Base, :stdout) ? "stdout" : "STDOUT"

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

    silent = silent || REPL.ends_with_semicolon(code)
    if store_history
        In[n] = code
    end

    # "; ..." cells are interpreted as shell commands for run
    code = replace(code, r"^\s*;.*$" =>
                   m -> string(replace(m, r"^\s*;" => "Base.repl_cmd(`"),
                               "`, ", stdout_name, ")"))


    # "] ..." cells are interpreted as pkg shell commands
    if occursin(r"^\].*$", code)
        code = "IJulia.Pkg.REPLMode.do_cmd(IJulia.minirepl[], \"" *
            escape_string(code[2:end]) * "\"; do_rethrow=true)"
    end

    # a cell beginning with "? ..." is interpreted as a help request
    hcode = replace(code, r"^\s*\?" => "")

    try
        for hook in preexecute_hooks
            invokelatest(hook)
        end


        ans = result = if hcode != code # help request
            Core.eval(Main, helpmode(hcode))
        else
            #run the code!
            occursin(magics_regex, code) ? magics_help(code) :
                SOFTSCOPE[] ? softscope_include_string(current_module[], code, "In[$n]") :
                include_string(current_module[], code, "In[$n]")
        end

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
