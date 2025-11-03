module CommManager

using IJulia

import IJulia: Msg, uuid4, send_ipython, msg_pub, Comm

export comm_target, msg_comm, send_comm, close_comm,
       register_comm, comm_msg, comm_open, comm_close, comm_info_request

# Global variable kept around for backwards compatibility
comms::Dict{String, CommManager.Comm} = Dict{String, CommManager.Comm}()

function Comm(target,
              id=uuid4(),
              primary=true,
              on_msg=Returns(nothing),
              on_close=Returns(nothing);
              kernel=IJulia._default_kernel,
              data=Dict(),
              metadata=Dict(),
              buffers=Vector{UInt8}[])
    comm = Comm{Symbol(target)}(id, primary, on_msg, on_close, kernel)
    if primary
        # Request a secondary object be created at the front end
        send_ipython(kernel.publish[], kernel,
                     msg_comm(comm, kernel.execute_msg, "comm_open",
                              data, metadata; target_name=string(target), buffers))
    end
    return comm
end

comm_target(comm :: Comm{target}) where {target} = target::Symbol

function comm_info_request(sock, kernel, msg)
    reply = if haskey(msg.content, "target_name")
        t = Symbol(msg.content["target_name"]::String)
        filter(kv -> comm_target(kv.second) == t, kernel.comms)
    else
        # reply with all comms.
        kernel.comms
    end

    _comms = Dict{String, Dict{Symbol,Symbol}}()
    for (comm_id,comm) in reply
        _comms[comm_id] = Dict(:target_name => comm_target(comm))
    end
    content = Dict(:comms => _comms)

    send_ipython(sock, kernel,
                 msg_reply(msg, "comm_info_reply", content))
end

function msg_comm(comm::Comm, m::IJulia.Msg, msg_type,
                  data=Dict{String,Any}(),
                  metadata=Dict{String, Any}(),
                  buffers=Vector{UInt8}[]; kwargs...)
    content = Dict("comm_id"=>comm.id, "data"=>data)

    for (k, v) in kwargs
        content[string(k)] = v
    end

    return msg_pub(m, msg_type, content, metadata, buffers)
end

function send_comm(comm::Comm, data::Dict,
                   metadata::Dict = Dict(), buffers=Vector{UInt8}[]; kernel=IJulia._default_kernel, kwargs...)
    msg = msg_comm(comm, kernel.execute_msg, "comm_msg", data,
                   metadata, buffers; kwargs...)
    send_ipython(kernel.publish[], kernel, msg)
end

function close_comm(comm::Comm, data::Dict = Dict(),
                    metadata::Dict = Dict(); kernel=IJulia._default_kernel, kwargs...)
    msg = msg_comm(comm, kernel.execute_msg, "comm_close", data,
                   metadata; kwargs...)
    send_ipython(kernel.publish[], kernel, msg)
end

function register_comm(comm::Comm, data)
    # no-op, widgets must override for their targets.
    # Method dispatch on Comm{t} serves
    # the purpose of register_target in IPEP 21.
end

# handlers for incoming comm_* messages

function comm_open(sock, kernel, msg)
    if haskey(msg.content, "comm_id")
        comm_id = msg.content["comm_id"]::String
        if haskey(msg.content, "target_name")
            target = msg.content["target_name"]::String
            if !haskey(msg.content, "data")
                msg.content["data"] = Dict()
            end
            comm = Comm(target, comm_id, false; kernel)
            invokelatest(register_comm, comm, msg)
            kernel.comms[comm_id] = comm
        else
            # Tear down comm to maintain consistency
            # if a target_name is not present
            send_ipython(kernel.publish[], kernel,
                         msg_comm(Comm(:notarget, comm_id, false; kernel),
                                  msg, "comm_close"))
        end
    end

    nothing
end

function comm_msg(sock, kernel, msg)
    if haskey(msg.content, "comm_id")
        comm_id = msg.content["comm_id"]::String
        if haskey(kernel.comms, comm_id)
            comm = kernel.comms[comm_id]
        else
            # We don't have that comm open
            return
        end

        if !haskey(msg.content, "data")
            msg.content["data"] = Dict()
        end
        comm.on_msg(msg)
    end

    nothing
end

function comm_close(sock, kernel, msg)
    if haskey(msg.content, "comm_id")
        comm_id = msg.content["comm_id"]::String
        comm = kernel.comms[comm_id]

        if !haskey(msg.content, "data")
            msg.content["data"] = Dict()
        end
        comm.on_close(msg)

        delete!(kernel.comms, comm.id)
    end

    nothing
end

end # module
