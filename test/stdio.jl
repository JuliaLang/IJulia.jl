using Test
using IJulia

@testset "stdio" begin

    mktemp() do path, io
        IJulia.redirect_stream("stdout", io) do
            println(Base.stdout, "stdout")
            println("print")
        end
        flush(io)
        seek(io, 0)
        @test read(io, String) == "stdout\nprint\n"
    end
    mktemp() do path, io
        IJulia.redirect_stream("stderr", io) do
            println(Base.stderr, "stderr")
        end
        flush(io)
        seek(io, 0)
        @test read(io, String) == "stderr\n"
    end

    mktemp() do path, io
        IJulia.redirect_stream("stdin")
        # We can't actually do anything here because `IJuliaexecute_msg` has not
        # yet been initialized, so we just make sure that redirect_stdin does
        # not error.
    end

end
