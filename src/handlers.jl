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

    completions, positions = REPLCompletions.completions(line,cursorpos)
    if sizeof(text) > length(positions)
        completions = [line[(cursorpos-sizeof(text)+1):(cursorpos-length(positions))]*s for s in completions]
    end
    send_ipython(requests, msg_reply(msg, "complete_reply", [
        "status" => "ok",
        "matches" => completions,
        "matched_text" => line[positions],
    ]))
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
    send_ipython(requests, msg_reply(msg, "shutdown_reply",
                                     msg.content))
    exit()
end

# TODO: better Julia help integration (issue #13)
docstring(o) = ""
docstring(o::Union(Function,DataType)) = sprint(show, methods(o))

function object_info_request(socket, msg)
    try
        s = symbol(msg.content["oname"])
        o = eval(s)
        content = ["oname" => msg.content["oname"],
                   "found" => true,
                   "ismagic" => false,
                   "isalias" => false,
                   "docstring" => docstring(o),
                   "type_name" => string(typeof(o)),
                   "base_class" => string(typeof(o).super),
                   "string_form" => get(msg.content,"detail_level",0) == 0 ? 
                   sprint(16384, show, o) : repr(o) ]
        if method_exists(length, (typeof(o),))
            content["length"] = length(o)
        end
        send_ipython(requests, msg_reply(msg, "object_info_reply", content))
    catch e
        verror_show(e, catch_backtrace())
        send_ipython(requests,
                     msg_reply(msg, "object_info_reply",
                               ["oname" => msg.content["oname"],
                                "found" => false ]))
    end
end

function history_request(socket, msg)
    # we will just send back empty history for now, pending clarification
    # as requested in ipython/ipython#3806
    send_ipython(requests,
                 msg_reply(msg, "history_reply",
                           ["history" => []]))
                             
end

const handlers = (String=>Function)[
    "execute_request" => execute_request_0x535c5df2,
    "complete_request" => complete_request,
    "kernel_info_request" => kernel_info_request,
    "object_info_request" => object_info_request,
    "connect_request" => connect_request,
    "shutdown_request" => shutdown_request,
    "history_request" => history_request,
]
