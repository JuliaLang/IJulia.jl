import Aqua
import IJulia

const TEST_FILES = [
    "install.jl", "comm.jl", "msg.jl", "execute_request.jl", "stdio.jl",
    "inline.jl", "completion.jl"
]

for file in TEST_FILES
    println(file)
    include(file)
end

Aqua.test_all(IJulia; piracies=(; broken=true))
