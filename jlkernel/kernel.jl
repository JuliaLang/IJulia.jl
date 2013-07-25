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
            "key" => ""
        ]
        fname = "profile-$(getpid()).json"
        println("connect ipython with --existing $(pwd())/$fname")
        open(fname, "w") do f
            JSON.print(f, profile)
        end
    end
end

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
            println("RECEIVED $msg")
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
                rethrow(e)
            end
        end
    end
end

for sock in (requests, control)
    eventloop(sock)
end

wait()
