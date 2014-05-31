module IJulia

# in the IPython front-end, enable verbose output via IJulia.set_verbose()
verbose = false
function set_verbose(v=true)
    global verbose::Bool = v
end

using ZMQ
using JSON
using Nettle

if isdefined(Base, :REPLCompletions)
    using Base.REPLCompletions
else
    using REPLCompletions
end

import Base.Pipe

uuid4() = repr(Base.Random.uuid4())

type Session
    profile::Dict{String,Any}
    ctx::Context
    publish::Socket
    raw_input::Socket
    requests::Socket
    control::Socket
    heartbeat::Socket
    usehmac::Bool
    hmacstate # usehmac == false ? "" : HMACState
    read_stdin::Pipe; read_stdout::Pipe; read_stderr::Pipe
    write_stdin::Pipe; write_stdout::Pipe; write_stderr::Pipe
end

function getprofile(args)
    if length(args) > 0
        profile = open(JSON.parse,args[1])
        verbose && println("PROFILE = $profile")
    else
        # generate profile and save
        let port0 = 5678
            profile = (String=>Any)[
                "ip" => "127.0.0.1",
                "transport" => "tcp",
                "stdin_port" => port0,
                "control_port" => port0+1,
                "hb_port" => port0+2,
                "shell_port" => port0+3,
                "iopub_port" => port0+4,
                "key" => uuid4()
            ]
            fname = "profile-$(getpid()).json"
            println("connect ipython with --existing $(pwd())/$fname")
            open(fname, "w") do f
                JSON.print(f, profile)
            end
        end
    end
    return profile
end

function sethmac(profile)
    if isempty(profile["key"])
        usehmac = false
        hmacstate = ""
    else
        signature_scheme = get(profile, "signature_scheme", "hmac-sha256")
        isempty(signature_scheme) && (signature_scheme = "hmac-sha256")
        signature_scheme = split(signature_scheme, "-")
        if signature_scheme[1] != "hmac" || length(signature_scheme) != 2
            error("unrecognized signature_scheme")
        end
        usehmac = true
        hmacstate = HMACState(eval(symbol(uppercase(signature_scheme[2]))),
                                    profile["key"])
    end
    return usehmac, hmacstate
end

function Session(args)
    profile = getprofile(args)
    usehmac,hmacstate = sethmac(profile)
    ctx = Context()
    publish = Socket(ctx, PUB)
    raw_input = Socket(ctx, ROUTER)
    requests = Socket(ctx, ROUTER)
    control = Socket(ctx, ROUTER)
    heartbeat = Socket(ctx, REP)
    bind(publish, "$(profile["transport"])://$(profile["ip"]):$(profile["iopub_port"])")
    bind(requests, "$(profile["transport"])://$(profile["ip"]):$(profile["shell_port"])")
    bind(control, "$(profile["transport"])://$(profile["ip"]):$(profile["control_port"])")
    bind(raw_input, "$(profile["transport"])://$(profile["ip"]):$(profile["stdin_port"])")
    bind(heartbeat, "$(profile["transport"])://$(profile["ip"]):$(profile["hb_port"])")
    
    heartbeat_c = cfunction(heartbeat_thread, Void, (Ptr{Void},))
    threadid = Array(Int, 128) # sizeof(uv_thread_t) <= 8 on Linux, OSX, Win
    start_heartbeat(heartbeat,heartbeat_c,threadid)

    read_stdin, write_stdin = redirect_stdin()
    read_stdout, write_stdout = redirect_stdout()
    read_stderr, write_stderr = redirect_stderr()

    return Session(profile,ctx, publish, raw_input, requests,
                    control, heartbeat, usehmac, hmacstate,
                    read_stdin, read_stdout, read_stderr,
                    write_stdin, write_stdout, write_stderr)
end

function init(args)
    global const SESSION = Session(args)
end

include("hmac.jl")
include("stdio.jl")
include("msg.jl")
include("history.jl")
include("handlers.jl")
include("heartbeat.jl")

function eventloop(socket,s::Session=SESSION)
    try
        while true
            msg = recv_ipython(socket)
            try
                handlers[msg.header["msg_type"]](socket, msg)
            catch e
                # Try to keep going if we get an exception, but
                # send the exception traceback to the front-ends.
                # (Ignore SIGINT since this may just be a user-requested
                #  kernel interruption to interrupt long calculations.)
                if !isa(e, InterruptException)
                    content = pyerr_content(e, "KERNEL EXCEPTION")
                    map(ss -> println(orig_STDERR, ss), content["traceback"])
                    send_ipython(s.publish, 
                                 execute_msg == nothing ?
                                 Msg([ "pyerr" ],
                                     [ "msg_id" => uuid4(),
                                     "username" => "jlkernel",
                                     "session" => uuid4(),
                                      "msg_type" => "pyerr" ], content) :
                                 msg_pub(execute_msg, "pyerr", content)) 
                end
            end
        end
    catch e
        # the IPython manager may send us a SIGINT if the user
        # chooses to interrupt the kernel; don't crash on this
        if isa(e, InterruptException)
            eventloop(socket)
        else
            rethrow()
        end
    end
end

function waitloop(s::Session=SESSION)
    @async eventloop(s.control)
    requests_task = @async eventloop(s.requests)
    while true
        try
            wait()
        catch e
            # send interrupts (user SIGINT) to the code-execution task
            if isa(e, InterruptException)
                @async Base.throwto(requests_task, e)
            else
                rethrow()
            end
        end
    end
end

end # IJulia

