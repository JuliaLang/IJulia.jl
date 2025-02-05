import Random: seed!
import Logging
import Logging: AbstractLogger, ConsoleLogger

const orig_stdin  = Ref{IO}()
const orig_stdout = Ref{IO}()
const orig_stderr = Ref{IO}()
const orig_logger = Ref{AbstractLogger}()
const SOFTSCOPE = Ref{Bool}()
function __init__()
    seed!(IJulia_RNG)
    orig_stdin[]  = stdin
    orig_stdout[] = stdout
    orig_stderr[] = stderr
    orig_logger[] = Logging.global_logger()
    SOFTSCOPE[] = lowercase(get(ENV, "IJULIA_SOFTSCOPE", "yes")) in ("yes", "true")
end

# needed for executing pkg commands on earlier Julia versions
@static if VERSION < v"1.11"
    # similar to Pkg.REPLMode.MiniREPL, a minimal REPL-like emulator
    # for use with Pkg.do_cmd.  We have to roll our own to
    # make sure it uses the redirected stdout, and because
    # we don't have terminal support.
    import REPL
    struct MiniREPL <: REPL.AbstractREPL
        display::TextDisplay
    end
    REPL.REPLDisplay(repl::MiniREPL) = repl.display
    const minirepl = Ref{MiniREPL}()
end

# Global variable kept around for backwards compatibility
profile::Dict{String, Any} = Dict{String, Any}()

"""
    init(args, kernel)

Initialize a kernel. `args` may either be empty or have one element containing
the path to an existing connection file. If `args` is empty a connection file
will be generated.
"""
function init(args, kernel, profile=nothing)
    !isnothing(_default_kernel) && error("IJulia is already running")
    if length(args) > 0
        merge!(kernel.profile, open(JSON.parse,args[1]))
        kernel.verbose && println("PROFILE = $profile")
        kernel.connection_file = args[1]
    elseif !isnothing(profile)
        merge!(kernel.profile, profile)
    else
        # generate profile and save
        let port0 = 5678
            merge!(kernel.profile, Dict{String,Any}(
                "ip" => "127.0.0.1",
                "transport" => "tcp",
                "stdin_port" => port0,
                "control_port" => port0+1,
                "hb_port" => port0+2,
                "shell_port" => port0+3,
                "iopub_port" => port0+4,
                "key" => uuid4()
            ))
            fname = "profile-$(getpid()).json"
            kernel.connection_file = "$(pwd())/$fname"
            println("connect ipython with --existing $(kernel.connection_file)")
            open(fname, "w") do f
                JSON.print(f, kernel.profile)
            end
        end
    end

    profile = kernel.profile

    if !isempty(profile["key"])
        signature_scheme = get(profile, "signature_scheme", "hmac-sha256")
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

    kernel.publish[] = Socket(PUB)
    kernel.raw_input[] = Socket(ROUTER)
    kernel.requests[] = Socket(ROUTER)
    kernel.control[] = Socket(ROUTER)
    kernel.heartbeat_context[] = Context()
    kernel.heartbeat[] = Socket(kernel.heartbeat_context[], ROUTER)
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
        redirect_stdout(IJuliaStdio(stdout, kernel, "stdout"))
    end
    if kernel.capture_stderr
        kernel.read_stderr[], = redirect_stderr()
        redirect_stderr(IJuliaStdio(stderr, kernel, "stderr"))
    end
    redirect_stdin(IJuliaStdio(stdin, kernel, "stdin"))
    @static if VERSION < v"1.11"
        minirepl[] = MiniREPL(TextDisplay(stdout))
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

    kernel.waitloop_task[] = @async waitloop(kernel)
end
