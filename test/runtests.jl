import JET
import Aqua
import IJulia

const TEST_FILES = [
    "install.jl", "comm.jl", "msg.jl", "execute_request.jl", "stdio.jl",
    "inline.jl", "completion.jl", "jsonx.jl"
]

for file in TEST_FILES
    println(file)
    include(file)
end

# Python is well-nigh impossible to install on 32bit
if Sys.WORD_SIZE != 32
    include("kernel.jl")
else
    @warn "Skipping the Kernel tests on 32bit"
end

@testset "Aqua.jl" begin
    # Note that Pkg and Conda are loaded lazily
    Aqua.test_all(IJulia; stale_deps=(; ignore=[:Pkg, :Conda]))
end

@testset "JET.jl" begin
    JET.test_package(IJulia; target_modules=(IJulia,))
end
