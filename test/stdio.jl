using Compat.Test
using IJulia

mktemp() do path, io
    redirect_stdout(IJulia.IJuliaStdio(io, "stdout")) do
        println("print")
    end
    flush(io)
    seek(io, 0)
    @test read(io, String) == "print\n"
    @test_throws ArgumentError redirect_stdout(IJulia.IJuliaStdio(io, "stderr"))
    @test_throws ArgumentError redirect_stdout(IJulia.IJuliaStdio(io, "stdin"))
    @test_throws ArgumentError redirect_stderr(IJulia.IJuliaStdio(io, "stdout"))
    @test_throws ArgumentError redirect_stderr(IJulia.IJuliaStdio(io, "stdin"))
    @test_throws ArgumentError redirect_stdin(IJulia.IJuliaStdio(io, "stdout"))
    @test_throws ArgumentError redirect_stdin(IJulia.IJuliaStdio(io, "stderr"))
end

mktemp() do path, io
    redirect_stderr(IJulia.IJuliaStdio(io, "stderr")) do
        warn("warn")
    end
    flush(io)
    seek(io, 0)
    captured = read(io, String)
    @test (captured == "\e[1m\e[33mWARNING: \e[39m\e[22m\e[33mwarn\e[39m\n" ||
           captured == "WARNING: warn\n")  # output will differ based on whether color is currently enabled
end

mktemp() do path, io
    redirect_stdin(IJulia.IJuliaStdio(io, "stdin")) do
        # We can't actually do anything here because `IJuliaexecute_msg` has not
        # yet been initialized, so we just make sure that redirect_stdin does 
        # not error.
    end
end

