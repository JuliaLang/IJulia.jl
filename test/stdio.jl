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

# Helper function to strip out color codes from strings to make it easier to
# compare output within tests that has been colorized
function strip_colorization(s)
    return replace(s, r"(\e\[\d+m)"m => "")
end

mktemp() do path, io
    redirect_stderr(IJulia.IJuliaStdio(io, "stderr")) do
        warn("warn")
    end
    flush(io)
    seek(io, 0)
    @test strip_colorization(read(io, String)) == "WARNING: warn\n"
end

mktemp() do path, io
    redirect_stdin(IJulia.IJuliaStdio(io, "stdin")) do
        # We can't actually do anything here because `IJuliaexecute_msg` has not
        # yet been initialized, so we just make sure that redirect_stdin does 
        # not error.
    end
end

