import Base.show

export Msg, msg_pub, msg_reply, send_status, send_ipython

# IPython message structure
mutable struct Msg
    idents::Vector{String}
    header::Dict
    content::Dict
    parent_header::Dict
    metadata::Dict
    function Msg(idents, header::Dict, content::Dict,
                 parent_header=Dict{String,Any}(), metadata=Dict{String,Any}())
        new(idents,header,content,parent_header,metadata)
    end
end

msg_header(m::Msg, msg_type::String) = Dict("msg_id" => uuid4(),
                                            "username" => m.header["username"],
                                            "session" => m.header["session"],
                                            "date" => now(),
                                            "msg_type" => msg_type,
                                            "version" => "5.3")

# PUB/broadcast messages use the msg_type as the ident, except for
# stream messages which use the stream name (e.g. "stdout").
# [According to minrk, "this isn't well defined, or even really part
# of the spec yet" and is in practice currently ignored since "all
# subscribers currently subscribe to all topics".]
msg_pub(m::Msg, msg_type, content, metadata=Dict{String,Any}()) =
  Msg([ msg_type == "stream" ? content["name"] : msg_type ],
      msg_header(m, msg_type), content, m.header, metadata)

msg_reply(m::Msg, msg_type, content, metadata=Dict{String,Any}()) =
  Msg(m.idents, msg_header(m, msg_type), content, m.header, metadata)

function show(io::IO, msg::Msg)
    print(io, "IPython Msg [ idents ")
    print(io, join(msg.idents, ", "))
    print(io, " ] {\n  parent_header = $(msg.parent_header),\n  header = $(msg.header),\n  metadata = $(msg.metadata),\n  content = $(msg.content)\n}")
end

function send_ipython(socket, m::Msg)
    lock(socket_locks[socket])
    try
        @vprintln("SENDING ", m)
        for i in m.idents
            send(socket, i, more=true)
        end
        send(socket, "<IDS|MSG>", more=true)
        header = json(m.header)
        parent_header = json(m.parent_header)
        metadata = json(m.metadata)
        content = json(m.content)
        send(socket, hmac(header, parent_header, metadata, content), more=true)
        send(socket, header, more=true)
        send(socket, parent_header, more=true)
        send(socket, metadata, more=true)
        send(socket, content)
    finally
        unlock(socket_locks[socket])
    end
end

function recv_ipython(socket)
    lock(socket_locks[socket])
    try
        idents = String[]
        s = recv(socket, String)
        @vprintln("got msg part $s")
        while s != "<IDS|MSG>"
            push!(idents, s)
            s = recv(socket, String)
            @vprintln("got msg part $s")
        end
        signature = recv(socket, String)
        request = Dict{String,Any}()
        header = recv(socket, String)
        parent_header = recv(socket, String)
        metadata = recv(socket, String)
        content = recv(socket, String)
        if signature != hmac(header, parent_header, metadata, content)
            error("Invalid HMAC signature") # What should we do here?
        end
        m = Msg(idents, JSON.parse(header), JSON.parse(content), JSON.parse(parent_header), JSON.parse(metadata))
        @vprintln("RECEIVED $m")
        return m
    finally
        unlock(socket_locks[socket])
    end
end

function send_status(state::AbstractString, parent_msg::Msg=execute_msg)
    send_ipython(publish[], Msg([ "status" ], msg_header(parent_msg, "status"),
                                Dict("execution_state" => state), parent_msg.header))
end
