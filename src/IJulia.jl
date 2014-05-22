module IJulia

# in the IPython front-end, enable verbose output via IJulia.set_verbose()
verbose = false
function set_verbose(v=true)
    global verbose::Bool = v
end


using ZMQ
using JSON

if isdefined(Base, :REPLCompletions)
    using Base.REPLCompletions
else
    using REPLCompletions
end

uuid4() = repr(Base.Random.uuid4())

if length(ARGS) > 0
    global const profile = open(JSON.parse,ARGS[1])
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

include("hmac.jl") # must go after profile is initialized
include("stdio.jl")
include("msg.jl")
include("history.jl")
include("handlers.jl")

const ctx = Context()
const publish = Socket(ctx, PUB)
const raw_input = Socket(ctx, ROUTER)
const requests = Socket(ctx, ROUTER)
const control = Socket(ctx, ROUTER)
const heartbeat = Socket(ctx, REP)

bind(publish, "$(profile["transport"])://$(profile["ip"]):$(profile["iopub_port"])")
bind(requests, "$(profile["transport"])://$(profile["ip"]):$(profile["shell_port"])")
bind(control, "$(profile["transport"])://$(profile["ip"]):$(profile["control_port"])")
bind(raw_input, "$(profile["transport"])://$(profile["ip"]):$(profile["stdin_port"])")
bind(heartbeat, "$(profile["transport"])://$(profile["ip"]):$(profile["hb_port"])")

include("heartbeat.jl")
start_heartbeat(heartbeat)

send_status("starting")

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

