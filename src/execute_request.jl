# Handlers for execute_request and related messages, which are
# the core of the Jupyter protocol: execution of Julia code and
# returning results.

import Base.Libc: flush_cstdio

import Pkg
if VERSION < v"1.11"
    do_pkg_cmd(cmd::AbstractString) =
        Pkg.REPLMode.do_cmd(minirepl[], cmd; do_rethrow=true)
else # Pkg.jl#3777
    do_pkg_cmd(cmd::AbstractString) =
        Pkg.REPLMode.do_cmds(cmd, stdout)
end

import REPL: helpmode


"""
    execute_request(socket, kernel, msg)

Handle a [execute
request](https://jupyter-client.readthedocs.io/en/latest/messaging.html#execute).
This will execute Julia code, along with Pkg and shell commands.
"""
function execute_request(socket, kernel, msg)
    code = msg.content["code"]::String
    @vprintln("EXECUTING ", code)
    kernel.execute_msg = msg
    kernel.stdio_bytes = 0
    silent = msg.content["silent"]::Bool
    store_history = get(msg.content, "store_history", !silent)::Bool
    empty!(kernel.execute_payloads)

    if !silent
        kernel.n += 1
        send_ipython(kernel.publish[], kernel,
                     msg_pub(msg, "execute_input",
                             Dict("execution_count" => kernel.n,
                                          "code" => code)))
    end

    silent = silent || REPL.ends_with_semicolon(code)
    if store_history
        kernel.In[kernel.n] = code
    end

    # "; ..." cells are interpreted as shell commands for run
    code = replace(code, r"^\s*;.*$" =>
                   m -> string(replace(m, r"^\s*;" => "Base.repl_cmd(`"),
                               "`, stdout)"))


    # "] ..." cells are interpreted as pkg shell commands
    if occursin(r"^\].*$", code)
        code = "IJulia.do_pkg_cmd(\"" * escape_string(strip(code[2:end])) * "\")"
    end

    # a cell beginning with "? ..." is interpreted as a help request
    hcode = replace(code, r"^\s*\?" => "")

    try
        foreach(invokelatest, kernel.preexecute_hooks)

        kernel.ans = result = if hcode != code # help request
            Core.eval(Main, helpmode(hcode))
        else
            #run the code!
            occursin(magics_regex, code) && match(magics_regex, code).offset == 1 ? magics_help(code) :
                SOFTSCOPE[] ? include_string(REPL.softscope, kernel.current_module, code, "In[$(kernel.n)]") :
                include_string(kernel.current_module, code, "In[$(kernel.n)]")
        end

        if silent
            result = nothing
        elseif (result !== nothing) && (result !== kernel.Out)
            if store_history
                kernel.Out[kernel.n] = result
            end
        end

        user_expressions = Dict()
        for (v::String, ex::String) in msg.content["user_expressions"]
            try
                value = include_string(kernel.current_module, ex)
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

        foreach(invokelatest, kernel.postexecute_hooks)

        # flush pending stdio
        flush_all()
        yield()
        if haskey(kernel.bufs, "stdout")
            send_stdout(kernel)
        end
        if haskey(kernel.bufs, "stderr")
            send_stderr(kernel)
        end

        undisplay(result, kernel) # dequeue if needed, since we display result in pyout
        @invokelatest display(kernel) # flush pending display requests

        if result !== nothing
            result_metadata = invokelatest(metadata, result)
            result_data = invokelatest(display_dict, result)
            send_ipython(kernel.publish[], kernel,
                         msg_pub(msg, "execute_result",
                                 Dict("execution_count" => kernel.n,
                                      "metadata" => result_metadata,
                                      "data" => result_data)))

        end
        send_ipython(kernel.requests[], kernel,
                     msg_reply(msg, "execute_reply",
                               Dict("status" => "ok",
                                    "payload" => kernel.execute_payloads,
                                    "execution_count" => kernel.n,
                                    "user_expressions" => user_expressions)))
        empty!(kernel.execute_payloads)
    catch e
        bt = catch_backtrace()
        try
            # flush pending stdio
            flush_all()
            foreach(invokelatest, kernel.posterror_hooks)
        catch
        end
        empty!(kernel.displayqueue) # discard pending display requests on an error
        content = error_content(e,bt)
        send_ipython(kernel.publish[], kernel, msg_pub(msg, "error", content))
        content["status"] = "error"
        content["execution_count"] = kernel.n
        send_ipython(kernel.requests[], kernel, msg_reply(msg, "execute_reply", content))
    end
end
