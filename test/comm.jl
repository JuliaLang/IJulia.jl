using Base.Test
using Compat
import IJulia: Comm, comm_target


target = :notarget
comm_id = "6BA197D8A67A455196279A59EB2FE844"
comm = Comm(target, comm_id, false)
@test :notarget == comm_target(comm)
@test !comm.primary


# comm_info_request in comm_manager.jl
const comms = Dict{String, Comm}(
    "id" => Comm(Symbol("jupyter.widget"), "id", false)
)
msg_content = Dict("target_name" => "jupyter.widget")
reply = if haskey(msg_content, "target_name")
    t = Symbol(msg_content["target_name"])
    filter((k, v) -> comm_target(v) == t, comms)
else
    comms
end
@test Dict{String,Comm} == typeof(reply)
_comms = Dict{String,Dict{Symbol,Symbol}}()
for (comm_id,comm) in reply
    _comms[comm_id] = Dict(:target_name => comm_target(comm))
end
@test Dict("id"=>Dict(:target_name=>Symbol("jupyter.widget"))) == _comms
content = Dict(:comms => _comms)
@test Dict(:comms=>Dict("id"=>Dict(:target_name=>Symbol("jupyter.widget")))) == content
