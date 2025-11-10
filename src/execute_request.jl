# Handlers for execute_request and related messages, which are
# the core of the Jupyter protocol: execution of Julia code and
# returning results.

import Base.Libc: flush_cstdio

import REPL: helpmode


# Pkg is a rather heavy dependency so we go to some effort to load it lazily
const Pkg_pkgid = Base.PkgId(Base.UUID("44cfe95a-1eb2-52ea-b672-e2afdf69b78f"), "Pkg")

function load_Pkg()
    if !haskey(Base.loaded_modules, Pkg_pkgid)
        @eval import Pkg
    end
end

function _do_pkg_cmd(cmd::AbstractString)
    Pkg = Base.loaded_modules[Pkg_pkgid]

    @static if VERSION < v"1.11"
        Pkg.REPLMode.do_cmd(IJulia._default_kernel.minirepl::MiniREPL, cmd; do_rethrow=true)
    else # Pkg.jl#3777
        Pkg.REPLMode.do_cmds(cmd, stdout)
    end
end

function do_pkg_cmd(cmd::AbstractString)
    load_Pkg()
    @invokelatest _do_pkg_cmd(cmd)
end

# Helper function to check if `code` is a valid special mode command. If it is,
# then comment lines will be stripped. If it isn't, then the original `code`
# will be returned.
function special_mode_strip(code::String)
    # Exit early if there are no comment or special mode characters at all
    if !contains(code, r"#|;|\]|\?")
        return code
    end

    # Loop over the string and look for lines that aren't comments and aren't
    # all whitespace.
    uncommented_line = ""
    has_special_mode = false
    for line in eachline(IOBuffer(code))
        if isempty(line) || all(isspace, line)
            continue
        end

        first_char = strip(line)[1]
        if first_char != '#'
            # If we've already found an uncommented line then bail out. We only
            # support special modes with one line of commands.
            if !isempty(uncommented_line)
                return code
            end

            uncommented_line = line
            has_special_mode = first_char ∈ (';', ']', '?')
        end
    end

    if isempty(uncommented_line)
        # If there are no uncommented lines then return the original code
        code
    elseif has_special_mode
        # If there's one and it is a special mode return just that line
        uncommented_line
    else
        # Otherwise return the original code
        code
    end
end

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

    code = special_mode_strip(code)

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
        foreach(invokelatest, IJulia._preexecute_hooks)

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

        maybe_launch_precompile(kernel)

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

        foreach(invokelatest, IJulia._postexecute_hooks)

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
        @invokelatest flush_kernel_display(kernel) # flush pending display requests

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
            foreach(invokelatest, IJulia._posterror_hooks)
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
