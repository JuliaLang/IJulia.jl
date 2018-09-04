using Test
using IJulia

mktemp() do path, io
    redirect_stdout(IJulia.IJuliaStdio(io, "stdout")) do
        stdout = isdefined(Base, :devnull) ? Base.stdout : Base.STDOUT
        println(stdout, "stdout")
        println("print")
    end
    flush(io)
    seek(io, 0)
    @test read(io, String) == "stdout\nprint\n"
    @test_throws ArgumentError redirect_stdout(IJulia.IJuliaStdio(io, "stderr"))
    @test_throws ArgumentError redirect_stdout(IJulia.IJuliaStdio(io, "stdin"))
    @test_throws ArgumentError redirect_stderr(IJulia.IJuliaStdio(io, "stdout"))
    @test_throws ArgumentError redirect_stderr(IJulia.IJuliaStdio(io, "stdin"))
    @test_throws ArgumentError redirect_stdin(IJulia.IJuliaStdio(io, "stdout"))
    @test_throws ArgumentError redirect_stdin(IJulia.IJuliaStdio(io, "stderr"))
end

mktemp() do path, io
    redirect_stderr(IJulia.IJuliaStdio(io, "stderr")) do
        stderr = isdefined(Base, :devnull) ? Base.stderr : Base.STDERR
        println(stderr, "stderr")
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

