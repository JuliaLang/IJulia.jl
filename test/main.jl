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
    @testset "argument parsing" begin
        # Test default subcommand (lab)
        called_with = nothing
        mock_jupyterlab = function(args=``; dir=homedir(), detached=false, port=nothing, verbose=false)
            called_with = (; args, dir, detached, port, verbose)
            return nothing
        end

        ret = IJulia.main(["--dir=/test", "--port=9999", "--detached", "--verbose", "--no-browser"]; jupyterlab_cmd=mock_jupyterlab)
        @test ret == 0
        @test !isnothing(called_with)
        @test called_with.dir == "/test"
        @test called_with.port == 9999
        @test called_with.detached == true
        @test called_with.verbose == true
        @test "--no-browser" in called_with.args

        # Test explicit notebook subcommand
        called_with = nothing
        mock_notebook = function(args=``; dir=homedir(), detached=false, port=nothing, verbose=false)
            called_with = (; args, dir, detached, port, verbose)
            return nothing
        end

        ret = IJulia.main(["notebook", "--dir=/test", "--port=9999", "--detached", "--verbose", "--no-browser"]; notebook_cmd=mock_notebook)
        @test ret == 0
        @test !isnothing(called_with)
        @test called_with.dir == "/test"
        @test called_with.port == 9999
        @test called_with.detached == true
        @test called_with.verbose == true
        @test "--no-browser" in called_with.args

        # Test lab subcommand
        called_with = nothing
        mock_jupyterlab = function(args=``; dir=homedir(), detached=false, port=nothing, verbose=false)
            called_with = (; args, dir, detached, port, verbose)
            return nothing
        end

        ret = IJulia.main(["lab", "--dir=/lab", "--verbose"]; jupyterlab_cmd=mock_jupyterlab)
        @test ret == 0
        @test !isnothing(called_with)
        @test called_with.dir == "/lab"
        @test called_with.verbose == true
    end

    # Test InterruptException handling
    @testset "interrupt handling" begin
        mock_notebook = function(args=``; kwargs...)
            throw(InterruptException())
        end

        ret = IJulia.main(["notebook"]; notebook_cmd=mock_notebook)
        @test ret == 0  # InterruptException should return 0
    end

    # Test error handling
    @testset "error handling" begin
        mock_notebook = function(args=``; kwargs...)
            error("Test error")
        end

        ret = @test_logs (:error, r"Failed to launch") IJulia.main(["notebook"]; notebook_cmd=mock_notebook)
        @test ret == 1  # Errors should return 1
    end
end
