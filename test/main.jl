using Test
import IJulia

@testset "@main app entry point" begin
    # Test help output
    @testset "help" begin
        # Capture stdout using a pipe
        old_stdout = stdout
        rd, wr = redirect_stdout()

        ret = IJulia.main(["--help"])

        # Restore stdout and read the captured output
        redirect_stdout(old_stdout)
        close(wr)
        help_text = read(rd, String)
        close(rd)

        @test ret == 0
        @test occursin("IJulia Launcher", help_text)
        @test occursin("notebook", help_text)
        @test occursin("lab", help_text)
        @test occursin("--dir=PATH", help_text)
        @test occursin("--port=N", help_text)
        @test occursin("--detached", help_text)
        @test occursin("--verbose", help_text)
    end

    # Test invalid subcommand
    @testset "invalid subcommand" begin
        ret = @test_logs (:error, r"Unknown subcommand.*Use 'notebook' or 'lab'") IJulia.main(["invalid"])
        @test ret == 1
    end

    # Test argument parsing without actually launching
    # We use mutable function references (notebook_cmd/jupyterlab_cmd) to test parsing
    @testset "argument parsing" begin
        # Save original functions
        orig_notebook = IJulia.notebook_cmd
        orig_jupyterlab = IJulia.jupyterlab_cmd

        # Test notebook (default)
        called_with = nothing
        IJulia.notebook_cmd = function(args=``; dir=homedir(), detached=false, port=nothing, verbose=false)
            called_with = (; args, dir, detached, port, verbose)
            return nothing
        end

        try
            ret = IJulia.main(["--dir=/test", "--port=9999", "--detached", "--verbose", "--no-browser"])
            @test ret == 0
            @test !isnothing(called_with)
            @test called_with.dir == "/test"
            @test called_with.port == 9999
            @test called_with.detached == true
            @test called_with.verbose == true
            @test "--no-browser" in called_with.args
        finally
            IJulia.notebook_cmd = orig_notebook
        end

        # Test explicit notebook subcommand
        called_with = nothing
        IJulia.notebook_cmd = function(args=``; dir=homedir(), detached=false, port=nothing, verbose=false)
            called_with = (; args, dir, detached, port, verbose)
            return nothing
        end

        try
            ret = IJulia.main(["notebook", "--port=8888"])
            @test ret == 0
            @test !isnothing(called_with)
            @test called_with.port == 8888
            @test called_with.dir == homedir()
            @test called_with.detached == false
        finally
            IJulia.notebook_cmd = orig_notebook
        end

        # Test lab subcommand
        called_with = nothing
        IJulia.jupyterlab_cmd = function(args=``; dir=homedir(), detached=false, port=nothing, verbose=false)
            called_with = (; args, dir, detached, port, verbose)
            return nothing
        end

        try
            ret = IJulia.main(["lab", "--dir=/lab", "--verbose"])
            @test ret == 0
            @test !isnothing(called_with)
            @test called_with.dir == "/lab"
            @test called_with.verbose == true
        finally
            IJulia.jupyterlab_cmd = orig_jupyterlab
        end
    end

    # Test InterruptException handling
    @testset "interrupt handling" begin
        orig_notebook = IJulia.notebook_cmd
        IJulia.notebook_cmd = function(args=``; kwargs...)
            throw(InterruptException())
        end

        try
            ret = IJulia.main([])
            @test ret == 0  # InterruptException should return 0
        finally
            IJulia.notebook_cmd = orig_notebook
        end
    end

    # Test error handling
    @testset "error handling" begin
        orig_notebook = IJulia.notebook_cmd
        IJulia.notebook_cmd = function(args=``; kwargs...)
            error("Test error")
        end

        try
            ret = @test_logs (:error, r"Failed to launch") IJulia.main([])
            @test ret == 1  # Errors should return 1
        finally
            IJulia.notebook_cmd = orig_notebook
        end
    end
end
