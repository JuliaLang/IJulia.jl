function send_status(state::String)
    msg = Msg(
        [ "status" ],
        [ "msg_id" => uuid4(),
          "username" => "jlkernel",
          "session" => uuid4(),
          "msg_type" => "status" ],
        [ "execution_state" => state ]
    )
    send_ipython(publish, msg)
end

# note: 0x535c5df2 is a random integer to make name collisions in
# backtrace analysis less likely.
function execute_request_0x535c5df2(socket, msg)
    println("Executing ", msg.content["code"])
    global _n
    if !msg.content["silent"]
        _n += 1
    end

    send_status("busy")

    try 
        result = eval(parse(msg.content["code"]))
        if msg.content["silent"] || ismatch(r";\s*$", msg.content["code"])
            result = nothing
        end

        user_variables = Dict()
        user_expressions = Dict()
        for v in msg.content["user_variables"]
            user_variables[v] = eval(parse(v))
        end
        for (v,ex) in msg.content["user_expressions"]
            user_expressions[v] = eval(parse(ex))
        end

        if result != nothing
            send_ipython(publish, 
                         msg_pub(msg, "pyout",
                                 ["execution_count" => _n,
                                 "data" => [ "text/plain" => 
                                 sprint(repl_show, result) ]
                                  ]))
        end

        send_ipython(requests,
                     msg_reply(msg, "execute_reply",
                               ["status" => "ok", "execution_count" => _n,
                               "payload" => [],
                               "user_variables" => user_variables,
                                "user_expressions" => user_expressions]))
    catch e
        tb = split(sprint(Base.show_backtrace, :execute_request_0x535c5df2, 
                          catch_backtrace(), 1:typemax(Int)), "\n", false)
        ename = string(typeof(e))
        evalue = sprint(Base.error_show, e)
        unshift!(tb, evalue) # fperez says this needs to be in traceback too
        send_ipython(publish,
                     msg_pub(msg, "pyerr",
                               ["execution_count" => _n,
                               "ename" => ename, "evalue" => evalue,
                               "traceback" => tb]))
        send_ipython(requests,
                     msg_reply(msg, "execute_reply",
                               ["status" => "error", "execution_count" => _n,
                               "ename" => ename, "evalue" => evalue,
                               "traceback" => tb]))
    end

    send_status("idle")
end

function complete_request(socket, msg)
    text = msg.content["text"]
    line = msg.content["line"]
    block = msg.content["block"]
    cursorpos = msg.content["cursor_pos"]

    matches = {}
    for n in names(Base)
        s = string(n)
        if beginswith(s, text)
            push!(matches, s)
        end
    end
    send_ipython(requests, msg_reply(msg, "complete_reply",
                                     [ "matches" => matches ]))
end

function kernel_info_request(socket, msg)
    send_ipython(requests,
                 msg_reply(msg, "kernel_info_reply",
                           ["protocol_version" => [4, 0],
                            "language_version" => [VERSION.major,
                                                   VERSION.minor,
                                                   VERSION.patch],
                            "language" => "julia" ]))
end

function connect_request(socket, msg)
    send_ipython(requests,
                 msg_reply(msg, "connect_reply",
                           ["shell_port" => profile["shell_port"],
                            "iopub_port" => profile["iopub_port"],
                            "stdin_port" => profile["stdin_port"],
                            "hb_port" => profile["hb_port"]]))
end

const handlers = (String=>Function)[
    "execute_request" => execute_request_0x535c5df2,
    "complete_request" => complete_request,
    "kernel_info_request" => kernel_info_request,
    "connect_request" => connect_request,
]
