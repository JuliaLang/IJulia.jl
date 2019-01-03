using Test
import IJulia, JSON

@testset "installkernel" begin
    let kspec = IJulia.installkernel("ijuliatest", "-O3", "-p2",
                    env=Dict("FOO"=>"yes"), specname="Yef1rLr4kXKxq9rbEh3m")
        try
            @test dirname(kspec) == IJulia.kerneldir()
            @test isfile(joinpath(kspec, "kernel.json"))
            @test isfile(joinpath(kspec, "logo-32x32.png"))
            @test isfile(joinpath(kspec, "logo-64x64.png"))
            let k = open(JSON.parse, joinpath(kspec, "kernel.json"))
                debugdesc = ccall(:jl_is_debugbuild,Cint,())==1 ? "-debug" : ""
                @test k["display_name"] == "ijuliatest" * " " * Base.VERSION_STRING * debugdesc
                @test k["argv"][end] == "{connection_file}"
                @test k["argv"][end-3:end-2] == ["-O3", "-p2"]
                @test k["language"] == "julia"
                @test k["env"]["FOO"] == "yes"
            end
        finally
            rm(kspec, force=true, recursive=true)
        end
    end
end
