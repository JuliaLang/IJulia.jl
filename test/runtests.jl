for file in ["install.jl","comm.jl", "completion.jl", "msg.jl", "execute_request.jl", "stdio.jl"]
    println(file)
    include(file)
end
