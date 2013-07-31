module IJulia

# in the IPython front-end, enable verbose output via IJulia.set_verbose()
verbose = false
function set_verbose(v=true)
    global verbose::Bool = v
end


using ZMQ
using JSON
using REPL

include("msg.jl")
include("handlers.jl")

uuid4() = repr(Random.uuid4())

if length(ARGS) > 0
    global const profile = open(JSON.parse,ARGS[1])
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
        if verbose
            println("connect ipython with --existing $(pwd())/$fname")
        end
        open(fname, "w") do f
            JSON.print(f, profile)
        end
    end
end

include("hmac.jl") # must go after profile is initialized

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

# execution counter
_n = 0

send_status("starting")

# heartbeat (should eventually be forked in a separate thread & use zmq_device)
@async begin
    while true
        msg = recv(heartbeat)
        send(heartbeat, msg)
    end
end

function eventloop(socket)
    @async begin
        while true
            msg = recv_ipython(socket)
            try
                handlers[msg.header["msg_type"]](socket, msg)
            catch e
                # FIXME: IPython doesn't seem to do anything with crash msg
                send_ipython(publish, 
                             Msg([ "crash" ],
                                 [ "msg_id" => uuid4(),
                                  "username" => "jlkernel",
                                  "session" => uuid4(),
                                  "msg_type" => "crash" ],
                                 [ "info" => sprint(Base.error_show, e, 
                                                    catch_backtrace())]))
                # rethrow(e) # FIXME: seems to hang?
                Base.error_show(STDERR, e, catch_backtrace())
                exit(1)
            end
        end
    end
end

end # IJulia

