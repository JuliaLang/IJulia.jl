using ZMQ
using JSON

uuid4() = repr(Random.uuid4())

const port0 = 5678
const profile = ["ip" => "127.0.0.1", "transport" => "tcp",
                 "stdin_port" => port0,
                 "control_port" => port0+1,
                 "hb_port" => port0+2,
                 "shell_port" => port0+3,
                 "iopub_port" => port0+4,
                 "key" => ""]
let fname = "profile-$(getpid()).json"
    println("connect ipython with --existing $(pwd())/$fname")
    open(fname, "w") do f
        JSON.print(f, profile)
    end
end

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

# execution counter
_n = 1



function execute_request(socket, idents, msg)
    user_variables = Dict() # TODO
    user_expressions = Dict() # TODO
    result = try 
        println("Executing ", msg["content"]["code"])
        eval(parse(msg["content"]["code"]))
    catch
        nothing
    end
    send_ipython(requests, idents, 
                 ["msg_id" => uuid4(),
                  "username" => msg["header"]["username"],
                  "session" => msg["header"]["session"],
                  "msg_type" => "execute_reply"],
                 msg["header"],
                 ["status" => "ok",
                  "execution_count" => _n,
                  "payload" => [],
                  "user_variables" => user_variables,
                  "user_expressions" => user_expressions])
    send_ipython(publish, ["pyout"],
                 ["msg_id" => uuid4(),
                  "username" => msg["header"]["username"],
                  "session" => msg["header"]["session"],
                  "msg_type" => "pyout"],
                 msg["header"],
                 ["execution_count" => _n,
                  "data" => [ "text/plain" => repr(result) ] ])
end

const handlers = (String=>Function)[
                                    "execute_request" => execute_request
                                    ]

# heartbeat (should eventually be forked in a separate thread & use zmq_device)
@async begin
    while true
        msg = recv(heartbeat)
        send(heartbeat, msg)
    end
end

function send_ipython(socket, idents,
                      header, parent_header, content, metadata=Dict())
    println("sending $header + $content")
    for i in idents
        send(socket, i, SNDMORE)
    end
    send(socket, "<IDS|MSG>", SNDMORE)
    send(socket, "", SNDMORE)
    send(socket, json(header), SNDMORE)
    send(socket, json(parent_header), SNDMORE)
    send(socket, json(metadata), SNDMORE)
    send(socket, json(content))
end

function recv_ipython(socket)
    msg = recv(socket)
    idents = String[]
    s = bytestring(msg)
    println("got msg part $s")
    while s != "<IDS|MSG>"
        push!(idents, s)
        msg = recv(socket)
        s = bytestring(msg)
        println("got msg part $s")
    end
    signature = bytestring(recv(socket))
    request = Dict{String,Any}()
    request["header"] = JSON.parse(bytestring(recv(socket)))
    request["parent_header"] = JSON.parse(bytestring(recv(socket)))
    request["metadata"] = JSON.parse(bytestring(recv(socket)))
    request["content"] = JSON.parse(bytestring(recv(socket)))
    return idents, signature, request
end

function eventloop(socket)
    @async begin
        while true
            idents, signature, request = recv_ipython(socket)
            println("REQUEST from $idents ($signature): $request")
            try
                handlers[request["header"]["msg_type"]](socket, idents, request)
            catch e
                println("REQUEST ERROR $e in handling", request["header"]["msg_type"])
            end
        end
    end
end

for sock in (requests, control)
    eventloop(sock)
end

wait()
