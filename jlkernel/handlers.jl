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

include("execute_request.jl")

function complete_request(socket, msg)
    text = msg.content["text"]
    line = msg.content["line"]
    cursorpos = msg.content["cursor_pos"]

    completions, positions = REPL.completions(line,cursorpos)
    if sizeof(text) > length(positions)
        completions = [line[(cursorpos-sizeof(text)+1):(cursorpos-length(positions))]*s for s in completions]
    end
    send_ipython(requests, msg_reply(msg, "complete_reply",
                                     [ "matches" => completions]))
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

function shutdown_request(socket, msg)
    send_ipython(request, msg_reply(msg, "shutdown_reply",
                                    msg.content))
    exit()
end

function object_info_request(socket, msg)
    try
        s = symbol(msg["oname"])
        o = eval(s)
        content = ["oname" => msg.content["oname"],
                   "found" => true,
                   "ismagic" => false,
                   "isalias" => false,
                   "type_name" => string(typeof(foo)),
                   "base_class" => string(typeof(foo).super),
                   "string_form" => get(msg.content,"detail_level",0) == 0 ? 
                   sprint(16384, show, foo) : repr(foo) ]
        if method_exists(length, (typeof(o),))
            content["length"] = length(o)
        end
        send_ipython(requests, msg_reply(msg, "object_info_reply", content))
    catch
        send_ipython(requests,
                     msg_reply(msg, "object_info_reply",
                               ["oname" => msg.content["oname"],
                                "found" => false ]))
    end
end

const handlers = (String=>Function)[
    "execute_request" => execute_request,
    "complete_request" => complete_request,
    "kernel_info_request" => kernel_info_request,
    "object_info_request" => object_info_request,
    "connect_request" => connect_request,
    "shutdown_request" => shutdown_request,
]
