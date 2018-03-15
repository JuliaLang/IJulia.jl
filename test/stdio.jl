using Base.Test
using IJulia

mktemp() do path, io
    redirect_stdout(IJulia.IJuliaStdio(io, "stdout")) do
        println("print")
    end
    flush(io)
    seek(io, 0)
    @test readstring(io) == "print\n"
end

mktemp() do path, io
    redirect_stderr(IJulia.IJuliaStdio(io, "stderr")) do
        warn("warn")
    end
    flush(io)
    seek(io, 0)
    @test readstring(io) == "\e[1m\e[33mWARNING: \e[39m\e[22m\e[33mwarn\e[39m\n"
end

mktemp() do path, io
    redirect_stdin(IJulia.IJuliaStdio(io, "stdin")) do
        # We can't actually do anything here because `IJuliaexecute_msg` has not
        # yet been initialized, so we just make sure that redirect_stdin does 
        # not error.
    end
end
