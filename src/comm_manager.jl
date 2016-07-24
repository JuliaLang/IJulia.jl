module CommManager

using IJulia
using Compat

import IJulia: Msg, uuid4, send_ipython, msg_pub

export Comm, comm_target, msg_comm, send_comm, close_comm,
       register_comm, comm_msg, comm_open, comm_close, comm_info_request


type Comm{target}
    id::AbstractString
    primary::Bool
    on_msg::Function
    on_close::Function
    function Comm(id, primary, on_msg, on_close)
        comm = new(id, primary, on_msg, on_close)
        comms[id] = comm
        return comm
    end
end

# This dict holds a map from CommID to Comm so that we can
# pick out the right Comm object when messages arrive
# from the front-end.
const comms = Dict{AbstractString, Comm}()

noop_callback(msg) = nothing
function Comm(target,
              id=uuid4(),
              primary=true,
              on_msg=noop_callback,
              on_close=noop_callback;
              data=Dict())
    @compat comm = Comm{Symbol(target)}(id, primary, on_msg, on_close)
    if primary
        # Request a secondary object be created at the front end
        send_ipython(IJulia.publish,
                     msg_comm(comm, IJulia.execute_msg, "comm_open",
                              data, target_name=string(target)))
    end
    return comm
end

comm_target{target}(comm :: Comm{target}) = target

function comm_info_request(sock, msg)
    reply = if haskey(msg.content, "target_name")
        t = @compat Symbol(msg.content["target_name"])
        filter((k, v) -> comm_target(v) == t, comms)
    else
        # reply with all comms.
        comms
    end

    _comms = Dict{AbstractString, Dict{Symbol,Symbol}}()
    for (comm_id,comm) in reply
        _comms[comm_id] = @compat Dict(:target_name => comm_target(comm))
    end
    content = @compat Dict(:comms => _comms)

    send_ipython(IJulia.publish,
                 msg_reply(msg, "comm_info_reply", content))
end

function msg_comm(comm::Comm, m::IJulia.Msg, msg_type,
                  data=Dict{AbstractString,Any}(),
                  metadata=Dict{AbstractString, Any}(); kwargs...)
    content = @compat Dict("comm_id"=>comm.id, "data"=>data)

    for (k, v) in kwargs
        content[string(k)] = v
    end

    return msg_pub(m, msg_type, content, metadata)
end


function send_comm(comm::Comm, data::Dict,
                   metadata::Dict = Dict(); kwargs...)
    msg = msg_comm(comm, IJulia.execute_msg, "comm_msg", data,
                   metadata; kwargs...)
    send_ipython(IJulia.publish, msg)
end


function close_comm(comm::Comm, data::Dict = Dict(),
                    metadata::Dict = Dict(); kwargs...)
    msg = msg_comm(comm, IJulia.execute_msg, "comm_msg", data,
                   metadata; kwargs...)
    send_ipython(IJulia.publish, msg)
end

function register_comm(comm::Comm, data)
    # no-op, widgets must override for their targets.
    # Method dispatch on Comm{t} serves
    # the purpose of register_target in IPEP 21.
end

# handlers for incoming comm_* messages

function comm_open(sock, msg)
    if haskey(msg.content, "comm_id")
        comm_id = msg.content["comm_id"]
        if haskey(msg.content, "target_name")
            target = msg.content["target_name"]
            if !haskey(msg.content, "data")
                msg.content["data"] = Dict()
            end
            comm = Comm(target, comm_id, false)
            register_comm(comm, msg)
            comms[comm_id] = comm
        else
            # Tear down comm to maintain consistency
            # if a target_name is not present
            send_ipython(IJulia.publish,
                         msg_comm(Comm(:notarget, comm_id),
                                  msg, "comm_close"))
        end
    end
end


function comm_msg(sock, msg)
    if haskey(msg.content, "comm_id")
        comm_id = msg.content["comm_id"]
        if haskey(comms, comm_id)
            comm = comms[comm_id]
        else
            # We don't have that comm open
            return
        end

        if !haskey(msg.content, "data")
            msg.content["data"] = Dict()
        end
        comm.on_msg(msg)
    end
end


function comm_close(sock, msg)
    if haskey(msg.content, "comm_id")
        comm_id = msg.content["comm_id"]
        comm = comms[comm_id]

        if !haskey(msg.content, "data")
            msg.content["data"] = Dict()
        end
        comm.on_close(msg)

        delete!(comms, comm.id)
    end
end


end # module
