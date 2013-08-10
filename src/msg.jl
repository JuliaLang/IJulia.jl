import Base.show

# IPython message structure
type Msg
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

# PUB/broadcast messages use the msg_type as the ident, except for
# stream messages which use the stream name (e.g. "stdout").
# [According to minrk, "this isn't well defined, or even really part
# of the spec yet" and is in practice currently ignored since "all
# subscribers currently subscribe to all topics".]
msg_pub(m::Msg, msg_type, content, metadata=Dict{String,Any}()) =
  Msg([ msg_type == "stream" ? content["name"] : msg_type ], 
      ["msg_id" => uuid4(),
       "username" => m.header["username"],
       "session" => m.header["session"],
       "msg_type" => msg_type],
      content, m.header, metadata)

msg_reply(m::Msg, msg_type, content, metadata=Dict{String,Any}()) =
  Msg(m.idents, 
      ["msg_id" => uuid4(),
       "username" => m.header["username"],
       "session" => m.header["session"],
       "msg_type" => msg_type],
      content, m.header, metadata)

function show(io::IO, msg::Msg)
    print(io, "IPython Msg [ idents ")
    print_joined(io, msg.idents, ", ")
    print(io, " ] {\n  header = $(msg.header),\n  metadata = $(msg.metadata),\n  content = $(msg.content)\n}")
end

function send_ipython(socket, m::Msg)
    @vprintln("SENDING $m")
    for i in m.idents
        send(socket, i, SNDMORE)
    end
    send(socket, "<IDS|MSG>", SNDMORE)
    header = json(m.header)
    parent_header = json(m.parent_header)
    metadata = json(m.metadata)
    content = json(m.content)
    send(socket, hmac(header, parent_header, metadata, content), SNDMORE)
    send(socket, header, SNDMORE)
    send(socket, parent_header, SNDMORE)
    send(socket, metadata, SNDMORE)
    send(socket, content)
end

function recv_ipython(socket)
    msg = recv(socket)
    idents = String[]
    s = bytestring(msg)
    @vprintln("got msg part $s")
    while s != "<IDS|MSG>"
        push!(idents, s)
        msg = recv(socket)
        s = bytestring(msg)
        @vprintln("got msg part $s")
    end
    signature = bytestring(recv(socket))
    request = Dict{String,Any}()
    header = bytestring(recv(socket))
    parent_header = bytestring(recv(socket))
    metadata = bytestring(recv(socket))
    content = bytestring(recv(socket))
    if signature != hmac(header, parent_header, metadata, content)
        error("Invalid HMAC signature") # What should we do here?
    end
    m = Msg(idents, JSON.parse(header), JSON.parse(content), JSON.parse(parent_header), JSON.parse(metadata))
    @vprintln("RECEIVED $m")
    return m
end

