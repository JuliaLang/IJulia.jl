function send_status(state::String)
    send_ipython(publish, 
                 Msg([ "status" ],
                     ["msg_id" => uuid4(),
                      "username" => "jlkernel",
                      "session" => uuid4(),
                      "msg_type" => "status"],
                     [ "execution_state" => "starting" ]))
end

function execute_request(socket, msg)
    println("Executing ", msg.content["code"])
    global _n
    if !msg.content["silent"]
        _n += 1
    end

    send_status("busy")

    result = try 
        eval(parse(msg.content["code"]))
    catch
        # FIXME
        nothing
    end
    if msg.content["silent"] || ismatch(r";\s*$", msg.content["code"])
        result = nothing
    end

    user_variables = Dict() # TODO
    user_expressions = Dict() # TODO
    try
        for v in msg.content["user_variables"]
            user_variables[v] = eval(parse(v))
        end
        for (v,ex) in msg.content["user_expressions"]
            user_expressions[v] = eval(parse(ex))
        end
    catch
        # ??
    end

    if result != nothing
        send_ipython(publish, 
                     msg_pub(msg, "pyout",
                             ["execution_count" => _n,
                              "data" => [ "text/plain" => 
                                         sprint(repl_show, result) ]
                              ]))
    end

    send_ipython(requests, msg_reply(msg, "execute_reply",
                                     ["status" => "ok",
                                      "execution_count" => _n,
                                      "payload" => [],
                                      "user_variables" => user_variables,
                                      "user_expressions" => user_expressions]))

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

const handlers = (String=>Function)[
                                    "execute_request" => execute_request,
                                    "complete_request" => complete_request,
                                    ]
