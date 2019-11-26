# Handers for execute_request and related messages, which are
# the core of the Jupyter protocol: execution of Julia code and
# returning results.

import Base.Libc: flush_cstdio
import Pkg

# global variable so that display can be done in the correct Msg context
execute_msg = Msg(["julia"], Dict("username"=>"jlkernel", "session"=>uuid4()), Dict())
# global variable tracking the number of bytes written in the current execution
# request
const stdio_bytes = Ref(0)

import REPL: helpmode

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

    silent = silent || REPL.ends_with_semicolon(code)
    if store_history
        In[n] = code
    end

    # "; ..." cells are interpreted as shell commands for run
    code = replace(code, r"^\s*;.*$" =>
                   m -> string(replace(m, r"^\s*;" => "Base.repl_cmd(`"),
                               "`, stdout)"))


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
            occursin(magics_regex, code) && match(magics_regex, code).offset == 1 ? magics_help(code) :
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
            try
                value = include_string(current_module[], ex)
                # Like the IPython reference implementation, we return
                # something that looks like a `display_data` but also has a
                # `status` field:
                # https://github.com/ipython/ipython/blob/master/IPython/core/interactiveshell.py#L2609-L2614
                user_expressions[v] = Dict("status" => "ok",
                                           "data" => display_dict(value),
                                           "metadata" => metadata(value))
            catch e
                # The format of user_expressions[v] is like `error` except that
                # it also has a `status` field:
                # https://jupyter-client.readthedocs.io/en/stable/messaging.html#execution-errors
                user_expressions[v] = Dict("status" => "error",
                                           error_content(e, catch_backtrace())...)
            end
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
