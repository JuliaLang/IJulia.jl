using Test
import IJulia: Comm, comm_target

@testset "comm" begin
    target = :notarget
    comm_id = "6BA197D8A67A455196279A59EB2FE844"
    comm = Comm(target, comm_id, false)
    @test :notarget == comm_target(comm)
    @test !comm.primary


    # comm_info_request in comm_manager.jl
    comms = Dict{String, Comm}(
        "id" => Comm(Symbol("jupyter.widget"), "id", false)
    )
    msg_content = Dict("target_name" => "jupyter.widget")
    reply = if haskey(msg_content, "target_name")
        let t, cb
            t = Symbol(msg_content["target_name"])
            cb(k, v) = comm_target(v) == t # For 0.6
            cb(kv) = comm_target(kv[2]) == t # For 0.7
            filter(cb, comms)
        end
    else
        comms
    end
    @test Dict{String,Comm} == typeof(reply)
    _comms = Dict{String,Dict{Symbol,Symbol}}()
    for (comm_id,comm) in reply
        local comm_id, comm
        _comms[comm_id] = Dict(:target_name => comm_target(comm))
    end
    @test Dict("id"=>Dict(:target_name=>Symbol("jupyter.widget"))) == _comms
    content = Dict(:comms => _comms)
    @test Dict(:comms=>Dict("id"=>Dict(:target_name=>Symbol("jupyter.widget")))) == content
end