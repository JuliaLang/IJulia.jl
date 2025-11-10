import Aqua
# Note that we import Revise before IJulia to prevent Revise adding its own
# preexecute hook, which would mess up the tests.
import Revise
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

# JET does not play well on versions prior to 1.12, and we disable it on 32bit
# because it seems to give false positives for the despecialized display methods
# if the kernel tests aren't run.
@static if VERSION >= v"1.12" && Sys.WORD_SIZE == 64
    import JET

    @testset "JET.jl" begin
        JET.test_package(IJulia; target_modules=(IJulia,))
    end
end
