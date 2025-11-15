import Random: seed!
import Sockets
import Logging
import Logging: AbstractLogger, ConsoleLogger

const orig_stdin  = Ref{IO}()
const orig_stdout = Ref{IO}()
const orig_stderr = Ref{IO}()
const orig_logger = Ref{AbstractLogger}()
const SOFTSCOPE = Ref{Bool}()

# Global variable kept around for backwards compatibility
profile::Dict{String, Any} = Dict{String, Any}()


function __init__()
    seed!(IJulia_RNG)
    orig_stdin[]  = stdin
    orig_stdout[] = stdout
    orig_stderr[] = stderr
    orig_logger[] = Logging.global_logger()
    SOFTSCOPE[] = lowercase(get(ENV, "IJULIA_SOFTSCOPE", "yes")) in ("yes", "true")

    Base.Experimental.register_error_hint(MethodError) do io, exc, argtypes, kwargs
        if exc.f === IJulia.init_ipywidgets || exc.f === IJulia.init_matplotlib || exc.f === IJulia.init_ipython
            if isempty(methods(exc.f))
                print(io, "\nIJulia.$(nameof(exc.f))() cannot be called yet, you must load PythonCall first for the extension to be loaded.")
            end
        end
    end
end

function getports(port_hint, n)
    ports = Int[]

    for i in 1:n
        port, server = Sockets.listenany(Sockets.localhost, port_hint)
        close(server)
        push!(ports, port)
        port_hint = port + 1
    end

    return ports
end

function create_profile(port_hint=8080; key=uuid4())
    # Disable constprop here because SnoopCompile shows that it significantly
    # reduces inference time. It's fine if inference is bad for this function
    # because in practice it's only used in tests and the precompile workload.
    Base.@constprop :none

    ports = getports(port_hint, 5)

    Dict(
        "transport" => "tcp",
        "ip" => "127.0.0.1",
        "control_port" => ports[1],
        "shell_port" => ports[2],
        "stdin_port" => ports[3],
        "hb_port" => ports[4],
        "iopub_port" => ports[5],
        "signature_scheme" => "hmac-sha256",
        "key" => key
    )
end

function maybe_launch_precompile(kernel::Kernel)
    # Execution and completion are likely the most common requests for the user
    # to observe latency, so only precompile those.
    for (task_ref, handler) in ((kernel.execute_precompile_task, execute_request),
                                (kernel.completion_precompile_task, complete_request))
        if !isassigned(task_ref) || istaskdone(task_ref[])
            task_ref[] = Threads.@spawn @invokelatest precompile(handler, (Socket, Kernel, Msg))
        end
    end
end

"""
    init(args, kernel)

Initialize a kernel. `args` may either be empty or have one element containing
the path to an existing connection file. If `args` is empty a connection file
will be generated.
"""
function init(args, kernel, profile=nothing)
    !isnothing(IJulia._default_kernel) && error("IJulia is already running")
    if length(args) > 0
        merge!(kernel.profile, JSONX.parsefile(args[1])::Dict)
        kernel.verbose && println("PROFILE = $profile")
        kernel.connection_file = args[1]
    elseif !isnothing(profile)
        merge!(kernel.profile, profile)
    else
        # generate profile and save
        let port0 = 5678
            merge!(kernel.profile, create_profile(port0))
            fname = "profile-$(getpid()).json"
            kernel.connection_file = "$(pwd())/$fname"
            println("connect ipython with --existing $(kernel.connection_file)")
            open(fname, "w") do f
                write(f, JSONX.json(kernel.profile))
            end
        end
    end

    profile = kernel.profile

    if !isempty(profile["key"])
        signature_scheme = get(profile, "signature_scheme", "hmac-sha256")::String
        isempty(signature_scheme) && (signature_scheme = "hmac-sha256")
        sigschm = split(signature_scheme, "-")
        if sigschm[1] != "hmac" || length(sigschm) != 2
            error("Unrecognized signature_scheme: $(signature_scheme)")
        elseif !startswith(sigschm[2], "sha")
            error("Signature schemes other than SHA are not supported on IJulia anymore, requested signature_scheme is: $(signature_scheme)")
        end

        kernel.sha_ctx[] = getproperty(SHA, Symbol(uppercase(sigschm[2]), "_CTX"))()
        kernel.hmac_key = collect(UInt8, profile["key"])
    end

    kernel.zmq_context[] = Context()
    kernel.publish[] = Socket(kernel.zmq_context[], PUB)
    kernel.raw_input[] = Socket(kernel.zmq_context[], ROUTER)
    kernel.requests[] = Socket(kernel.zmq_context[], ROUTER)
    kernel.control[] = Socket(kernel.zmq_context[], ROUTER)
    kernel.heartbeat[] = Socket(kernel.zmq_context[], REP)
    sep = profile["transport"]=="ipc" ? "-" : ":"
    bind(kernel.publish[], "$(profile["transport"])://$(profile["ip"])$(sep)$(profile["iopub_port"])")
    bind(kernel.requests[], "$(profile["transport"])://$(profile["ip"])$(sep)$(profile["shell_port"])")
    bind(kernel.control[], "$(profile["transport"])://$(profile["ip"])$(sep)$(profile["control_port"])")
    bind(kernel.raw_input[], "$(profile["transport"])://$(profile["ip"])$(sep)$(profile["stdin_port"])")
    bind(kernel.heartbeat[], "$(profile["transport"])://$(profile["ip"])$(sep)$(profile["hb_port"])")

    # associate a lock with each socket so that multi-part messages
    # on a given socket don't get inter-mingled between tasks.
    for s in (kernel.publish[], kernel.raw_input[], kernel.requests[], kernel.control[])
        kernel.socket_locks[s] = ReentrantLock()
    end

    start_heartbeat(kernel)
    if kernel.capture_stdout
        kernel.read_stdout[], = redirect_stdout()
        redirect_stdout(IJuliaStdio(stdout, "stdout"))
    end
    if kernel.capture_stderr
        kernel.read_stderr[], = redirect_stderr()
        redirect_stderr(IJuliaStdio(stderr, "stderr"))
    end
    if kernel.capture_stdin
        redirect_stdin(IJuliaStdio(stdin, "stdin"))
    end

    @static if VERSION < v"1.11"
        kernel.minirepl = MiniREPL(TextDisplay(stdout))
    end

    watch_stdio(kernel)
    pushdisplay(IJulia.InlineDisplay())

    logger = ConsoleLogger(Base.stderr)
    Base.CoreLogging.global_logger(logger)
    IJulia._default_kernel = kernel
    IJulia.CommManager.comms = kernel.comms
    IJulia.profile = kernel.profile

    send_status("starting", kernel)
    kernel.inited = true

    # Explicitly initialize these fields so that setproperty!(::Kernel) is
    # called and assigns them to their corresponding global variables. This is
    # not done by the @kwdef constructor.
    kernel.In = Dict{Int, String}()
    kernel.Out = Dict{Int, Any}()

    maybe_launch_precompile(kernel)
    kernel.waitloop_task[] = @async waitloop(kernel)
end
