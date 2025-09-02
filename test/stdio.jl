using Test
using IJulia

@testset "stdio" begin
    kernel = IJulia.Kernel()
    # Set _default_kernel so that flush(::IJuliaStdio) works
    IJulia._default_kernel = kernel

    mktemp() do path, io
        redirect_stdout(IJulia.IJuliaStdio(io, "stdout")) do
            println(Base.stdout, "stdout")
            println("print")
        end
        flush(io)
        seek(io, 0)
        @test read(io, String) == "stdout\nprint\n"
    end

    mktemp() do path, io
        redirect_stderr(IJulia.IJuliaStdio(io, "stderr")) do
            println(Base.stderr, "stderr")
        end
        flush(io)
        seek(io, 0)
        @test read(io, String) == "stderr\n"
    end

    mktemp() do path, io
        redirect_stdin(IJulia.IJuliaStdio(io, "stdin")) do
            # We can't actually do anything here because `IJuliaexecute_msg` has not
            # yet been initialized, so we just make sure that redirect_stdin does
            # not error.
        end
    end

    kernel.stdio_bytes = 42
    IJulia.reset_stdio_count(kernel)
    @test kernel.stdio_bytes == 0

    # Test that the IJuliaStdio object is deepcopy-able. See:
    # https://github.com/JuliaLang/IJulia.jl/issues/1179
    mktemp() do path, io
        deepcopy(IJulia.IJuliaStdio(io, "stdout"))
    end

    IJulia._default_kernel = nothing
end
