import Random: seed!
import Logging: ConsoleLogger

# use our own random seed for msg_id so that we
# don't alter the user-visible random state (issue #336)
const IJulia_RNG = seed!(Random.MersenneTwister(0))
import UUIDs
uuid4() = string(UUIDs.uuid4(IJulia_RNG))

const orig_stdin  = Ref{IO}()
const orig_stdout = Ref{IO}()
const orig_stderr = Ref{IO}()
const SOFTSCOPE = Ref{Bool}()
function __init__()
    seed!(IJulia_RNG)
    orig_stdin[]  = stdin
    orig_stdout[] = stdout
    orig_stderr[] = stderr
    SOFTSCOPE[] = lowercase(get(ENV, "IJULIA_SOFTSCOPE", "yes")) in ("yes", "true")
end

# the following constants need to be initialized in init().
const publish = Ref{Socket}()
const raw_input = Ref{Socket}()
const requests = Ref{Socket}()
const control = Ref{Socket}()
const heartbeat = Ref{Socket}()
const profile = Dict{String,Any}()
const read_stdout = Ref{Base.PipeEndpoint}()
const read_stderr = Ref{Base.PipeEndpoint}()
const socket_locks = Dict{Socket,ReentrantLock}()

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

function init(args)
    inited && error("IJulia is already running")
    if length(args) > 0
        merge!(profile, open(JSON.parse,args[1]))
        verbose && println("PROFILE = $profile")
        global connection_file = args[1]
    else
        # generate profile and save
        let port0 = 5678
            merge!(profile, Dict{String,Any}(
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
            global connection_file = "$(pwd())/$fname"
            println("connect ipython with --existing $connection_file")
            open(fname, "w") do f
                JSON.print(f, profile)
            end
        end
    end

    if !isempty(profile["key"])
        signature_scheme = get(profile, "signature_scheme", "hmac-sha256")
        isempty(signature_scheme) && (signature_scheme = "hmac-sha256")
        sigschm = split(signature_scheme, "-")
        if sigschm[1] != "hmac" || length(sigschm) != 2
            error("unrecognized signature_scheme $signature_scheme")
        end
        hmacstate[] = MbedTLS.MD(getfield(MbedTLS, Symbol("MD_", uppercase(sigschm[2]))),
                                 profile["key"])
    end

    publish[] = Socket(PUB)
    raw_input[] = Socket(ROUTER)
    requests[] = Socket(ROUTER)
    control[] = Socket(ROUTER)
    heartbeat[] = Socket(ROUTER)
    sep = profile["transport"]=="ipc" ? "-" : ":"
    bind(publish[], "$(profile["transport"])://$(profile["ip"])$(sep)$(profile["iopub_port"])")
    bind(requests[], "$(profile["transport"])://$(profile["ip"])$(sep)$(profile["shell_port"])")
    bind(control[], "$(profile["transport"])://$(profile["ip"])$(sep)$(profile["control_port"])")
    bind(raw_input[], "$(profile["transport"])://$(profile["ip"])$(sep)$(profile["stdin_port"])")
    bind(heartbeat[], "$(profile["transport"])://$(profile["ip"])$(sep)$(profile["hb_port"])")

    # associate a lock with each socket so that multi-part messages
    # on a given socket don't get inter-mingled between tasks.
    for s in (publish[], raw_input[], requests[], control[], heartbeat[])
        socket_locks[s] = ReentrantLock()
    end

    start_heartbeat(heartbeat[])
    if capture_stdout
        read_stdout[], = redirect_stdout()
        redirect_stdout(IJuliaStdio(stdout,"stdout"))
    end
    if capture_stderr
        read_stderr[], = redirect_stderr()
        redirect_stderr(IJuliaStdio(stderr,"stderr"))
    end
    redirect_stdin(IJuliaStdio(stdin,"stdin"))
    minirepl[] = MiniREPL(TextDisplay(stdout))

    logger = ConsoleLogger(Base.stderr)
    Base.CoreLogging.global_logger(logger)

    send_status("starting")
    global inited = true
end
