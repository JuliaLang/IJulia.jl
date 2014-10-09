include("comm_manager.jl")
include("execute_request.jl")

using IJulia.CommManager

function complete_request(socket, msg)
    text = msg.content["text"]
    line = msg.content["line"]
    cursorpos = chr2ind(line, msg.content["cursor_pos"])

    comps, positions = completions(line,cursorpos)
    if sizeof(text) > length(positions)
        comps = [line[(cursorpos-sizeof(text)+1):(cursorpos-length(positions))]*s for s in comps]
    end
    send_ipython(requests, msg_reply(msg, "complete_reply", Dict(
        "status" => "ok",
        "matches" => comps,
        "matched_text" => line[positions],
    )))
end

function kernel_info_request(socket, msg)
    send_ipython(requests,
                 msg_reply(msg, "kernel_info_reply",
                           Dict("protocol_version" => [4, 0],
                                "language_version" => [VERSION.major,
                                                       VERSION.minor,
                                                       VERSION.patch],
                                "language" => "julia" )))
end

function connect_request(socket, msg)
    send_ipython(requests,
                 msg_reply(msg, "connect_reply",
                           Dict("shell_port" => profile["shell_port"],
                                "iopub_port" => profile["iopub_port"],
                                "stdin_port" => profile["stdin_port"],
                                "hb_port" => profile["hb_port"])))
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
        s = parse(msg.content["oname"])
        o = eval(Main, s)
        content = Dict("oname" => msg.content["oname"],
                       "found" => true,
                       "ismagic" => false,
                       "isalias" => false,
                       "docstring" => docstring(o),
                       "type_name" => string(typeof(o)),
                       "base_class" => string(typeof(o).super),
                       "string_form" => get(msg.content,"detail_level",0) == 0 ?
                           sprint(16384, show, o) : repr(o) )
        if method_exists(length, (typeof(o),))
            content["length"] = length(o)
        end
        send_ipython(requests, msg_reply(msg, "object_info_reply", content))
    catch e
        @verror_show e catch_backtrace()
        send_ipython(requests,
                     msg_reply(msg, "object_info_reply",
                               Dict("oname" => msg.content["oname"],
                                    "found" => false )))
    end
end

function history_request(socket, msg)
    # we will just send back empty history for now, pending clarification
    # as requested in ipython/ipython#3806
    send_ipython(requests,
                 msg_reply(msg, "history_reply",
                           Dict("history" => [])))
                             
end

const handlers = Dict{String,Function}(
    "execute_request" => execute_request_0x535c5df2,
    "complete_request" => complete_request,
    "kernel_info_request" => kernel_info_request,
    "object_info_request" => object_info_request,
    "connect_request" => connect_request,
    "shutdown_request" => shutdown_request,
    "history_request" => history_request,
    "comm_open" => comm_open,
    "comm_msg" => comm_msg,
    "comm_close" => comm_close
)
