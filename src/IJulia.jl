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

uuid4() = repr(Base.Random.uuid4())

function init(args)
    if length(args) > 0
        global const profile = open(JSON.parse,args[1])
        verbose && println("PROFILE = $profile")
    else
        # generate profile and save
        let port0 = 5678
            global const profile = (String=>Any)[
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
    global hmac
    if isempty(profile["key"])
        hmac(s1,s2,s3,s4) = ""
    else
        signature_scheme = get(profile, "signature_scheme", "hmac-sha256")
        isempty(signature_scheme) && (signature_scheme = "hmac-sha256")
        signature_scheme = split(signature_scheme, "-")
        if signature_scheme[1] != "hmac" || length(signature_scheme) != 2
            error("unrecognized signature_scheme")
        end
        global const hmacstate = HMACState(eval(symbol(uppercase(signature_scheme[2]))),
                                    profile["key"])
        function hmac(s1,s2,s3,s4)
            update!(hmacstate, s1)
            update!(hmacstate, s2)
            update!(hmacstate, s3)
            update!(hmacstate, s4)
            hexdigest!(hmacstate)
        end
    end

    global const ctx = Context()
    global const publish = Socket(ctx, PUB)
    global const raw_input = Socket(ctx, ROUTER)
    global const requests = Socket(ctx, ROUTER)
    global const control = Socket(ctx, ROUTER)
    global const heartbeat = Socket(ctx, REP)
    bind(publish, "$(profile["transport"])://$(profile["ip"]):$(profile["iopub_port"])")
    bind(requests, "$(profile["transport"])://$(profile["ip"]):$(profile["shell_port"])")
    bind(control, "$(profile["transport"])://$(profile["ip"]):$(profile["control_port"])")
    bind(raw_input, "$(profile["transport"])://$(profile["ip"]):$(profile["stdin_port"])")
    bind(heartbeat, "$(profile["transport"])://$(profile["ip"]):$(profile["hb_port"])")

    global const heartbeat_c = cfunction(heartbeat_thread, Void, (Ptr{Void},))
    global const threadid = Array(Int, 128) # sizeof(uv_thread_t) <= 8 on Linux, OSX, Win
    start_heartbeat(heartbeat)

    global const orig_STDIN = STDIN
    global const orig_STDOUT = STDOUT
    global const orig_STDERR = STDERR

    global read_stdin
    global write_stdin
    global read_stdout
    global write_stdout
    global read_stderr
    global write_stderr
    read_stdin, write_stdin = redirect_stdin()
    read_stdout, write_stdout = redirect_stdout()
    read_stderr, write_stderr = redirect_stderr()

    send_status("starting")

end

include("stdio.jl")
include("msg.jl")
include("history.jl")
include("handlers.jl")
include("heartbeat.jl")

function eventloop(socket)
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
                    map(s -> println(orig_STDERR, s), content["traceback"])
                    send_ipython(publish, 
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

function waitloop()
    @async eventloop(control)
    requests_task = @async eventloop(requests)
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

