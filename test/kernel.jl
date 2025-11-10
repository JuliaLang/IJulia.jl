# Copy CondaPkg.toml to the test project so that it gets found by CondaPkg
# during the tests. If this was instead in the project directory it would also
# be used by CondaPkg outside of the tests, which we don't want.
cp(joinpath(@__DIR__, "CondaPkg.toml"), joinpath(dirname(Base.active_project()), "CondaPkg.toml"))

ENV["JULIA_CONDAPKG_ENV"] = "@ijulia-tests"
ENV["JULIA_CONDAPKG_VERBOSITY"] = -1

# If you're running the tests locally you could uncomment the two environment
# variables below. This will be a bit faster since it stops CondaPkg from
# re-resolving the environment each time (but you do need to run it at least
# once locally to initialize the `@ijulia-tests` environment).
# ENV["JULIA_PYTHONCALL_EXE"] = joinpath(Base.DEPOT_PATH[1], "conda_environments", "ijulia-tests", "bin", "python")
# ENV["JULIA_CONDAPKG_BACKEND"] = "Null"


using Test
import Sockets
import Sockets: listenany

import ZMQ
import PythonCall
import PythonCall: Py, pyimport, pyconvert, pytype, pystr

# A little bit of hackery to fix the version number sent by the client. See:
# https://github.com/jupyter/jupyter_client/pull/1054
jupyter_client_lib = pyimport("jupyter_client")
jupyter_client_lib.session.protocol_version = "5.4"

const BlockingKernelClient = jupyter_client_lib.BlockingKernelClient

import IJulia: Kernel
# These symbols are imported so that we can test that setproperty!(::Kernel)
# will propagate changes from the corresponding Kernel fields to the
# module-global variables.
import IJulia: ans, In, Out


function test_py_get!(get_func, result)
    try
        result[] = get_func(timeout=0)
        return true
    catch ex
        exception_type = pyconvert(String, ex.t.__name__)
        if exception_type != "Empty"
            rethrow()
        end

        return false
    end
end

function recursive_pyconvert(x)
    x_type = pyconvert(String, pytype(x).__name__)

    if x_type == "dict"
        x = pyconvert(Dict{String, Any}, x)
        for key in copy(keys(x))
            if x[key] isa Py
                x[key] = recursive_pyconvert(x[key])
            elseif x[key] isa PythonCall.PyDict
                x[key] = recursive_pyconvert(x[key].py)
            end
        end
    elseif x_type == "str"
        x = pyconvert(String, x)
    end

    return x
end

# Calling methods directly with `reply=true` on the BlockingKernelClient will
# cause a deadlock because the client will block the whole thread while polling
# the socket, which means that the thread will never enter a GC safepoint so any
# other code that happens to allocate will get blocked. Instead, we send
# requests by themselves and then poll the appropriate socket with `timeout=0`
# so that the Python code will never block and we never get into a deadlock.
function make_request(request_func, get_func, args...; wait=true, kwargs...)
    request_func(args...; kwargs..., reply=false)
    if !wait
        return nothing
    end

    result = Ref{Py}()
    timeout = haskey(ENV, "CI") ? 120 : 20
    if timedwait(() -> test_py_get!(get_func, result), timeout) == :timed_out
        error("Jupyter channel get timed out")
    end

    return recursive_pyconvert(result[])
end

kernel_info(client) = make_request(client.kernel_info, client.get_shell_msg)
comm_info(client) = make_request(client.comm_info, client.get_shell_msg)
history(client) = make_request(client.history, client.get_shell_msg)
shutdown(client; wait=true) = make_request(client.shutdown, client.get_control_msg; wait)
execute(client, code) = make_request(client.execute, client.get_shell_msg; code)
inspect(client, code) = make_request(client.inspect, client.get_shell_msg; code)
complete(client, code) = make_request(client.complete, client.get_shell_msg; code)
get_stdin_msg(client) = make_request(Returns(nothing), client.get_stdin_msg)
get_iopub_msg(client) = make_request(Returns(nothing), client.get_iopub_msg)

function get_iopub_msgtype(client, msg_type)
    while true
        msg = get_iopub_msg(client)
        if msg["header"]["msg_type"] == msg_type
            return msg
        end
    end
end

get_execute_result(client) = get_iopub_msgtype(client, "execute_result")
get_comm_close(client) = get_iopub_msgtype(client, "comm_close")
get_comm_msg(client) = get_iopub_msgtype(client, "comm_msg")

function msg_ok(msg)
    ok = msg["content"]["status"] == "ok"
    if !ok
        @error "Kernel is not ok" msg["content"]
    end

    return ok
end

msg_error(msg) = msg["content"]["status"] == "error"

function jupyter_client(f, profile)
    client = BlockingKernelClient()
    client.load_connection_info(profile)
    client.start_channels()

    try
        f(client)
    finally
        client.stop_channels()
    end
end

function run_precompile()
    profile = IJulia.create_profile(; key=IJulia._TEST_KEY)

    zmq_recv = """

    ZMQ.send_multipart(requests_socket, [only(idents), "<IDS|MSG>", signature, header, parent_header, metadata, content])
    ZMQ.recv_multipart(requests_socket, String)
    """

    Kernel(profile; capture_stdout=false, capture_stderr=false) do kernel
        jupyter_client(profile) do client
            println("# Kernel info")
            kernel_info(client)
            println(zmq_recv)

            println("# Completion request")
            complete(client, "mk")
            println(zmq_recv)

            println("# Execute `42`")
            execute(client, "42")
            println(zmq_recv)

            println("# Execute `?import`")
            execute(client, "?import")
            println(zmq_recv)

            println("""# Execute `error("foo")`""")
            execute(client, """error("foo")""")
            println(zmq_recv)

            println("# Get history")
            history(client)
            println(zmq_recv)

            println("# Get comm info")
            comm_info(client)
            println(zmq_recv)
        end
    end
end

# Uncomment this to run the precompilation workload
# run_precompile()

@testset "Kernel" begin
    profile = IJulia.create_profile(; key=IJulia._TEST_KEY)
    profile_kwargs = Dict([Symbol(key) => value for (key, value) in profile])
    profile_kwargs[:key] = pystr(profile_kwargs[:key]).encode()

    @testset "Pkg integration" begin
        Kernel(profile; capture_stdout=false, capture_stderr=false) do kernel
            stdout_pipe = Pipe()
            redirect_stdout(stdout_pipe) do
                IJulia.do_pkg_cmd("st")
            end
            close(stdout_pipe.in)
            stdout_str = read(stdout_pipe, String)
            @test contains(stdout_str, r"Status `.+Project.toml`")
        end
    end

    @testset "getproperty()/setproperty!()" begin
        # Test setting special fields that should be mirrored to global variables
        Kernel(profile; capture_stdout=false, capture_stderr=false) do kernel
            # Check that init() set Out/In appropriately
            @test In === kernel.In
            @test Out === kernel.Out

            for field in (:ans, :n, :In, :Out, :inited,)
                test_value = if field === :inited
                    true
                elseif field === :In
                    Dict{Int, String}()
                elseif field === :Out
                    Dict{Int, Any}()
                else
                    10
                end

                setproperty!(kernel, field, test_value)
                @test getproperty(IJulia, field) === test_value
                @test getproperty(kernel, field) === test_value

                # Sanity check that these fields are mirrored to Main correctly
                if field ∈ (:ans, :In, :Out)
                    @test getproperty(kernel.current_module, field) === test_value
                end
            end
        end
    end

    @testset "Explicit tests with jupyter_client" begin
        # Some of these tests have their own kernel instance to avoid
        # interfering with the state of other tests.

        # Test clear_history() and In/Out
        Kernel(profile; capture_stdout=false, capture_stderr=false) do kernel
            jupyter_client(profile) do client
                for i in 1:10
                    @test msg_ok(execute(client, "$(i)"))
                end
                @test length(In) == 10
                @test length(Out) == 10
                @test msg_ok(execute(client, "IJulia.clear_history(-1:5)"))
                @test Set(keys(kernel.In)) == Set(6:11) # The 11th entry is the call to clear_history()
                @test msg_ok(execute(client, "IJulia.clear_history()"))
                @test isempty(kernel.In)
                @test isempty(kernel.Out)
            end
        end

        # Test input
        Kernel(profile; capture_stdout=false, capture_stderr=false) do kernel
            jupyter_client(profile) do client
                # The input system in Jupyter is a bit convoluted. First we
                # make a request to the kernel:
                client.execute("readline()")
                # Then wait for readline(::IJuliaStdio) to send its own
                # `input_request` message on the stdin socket.
                @test msg_ok(get_stdin_msg(client))
                # Send an `input_reply` back
                client.input("foo")

                # Wait for the original `execute_request` to complete and
                # send an `execute_result` message with the 'input'.
                msg = get_execute_result(client)
                @test msg["content"]["data"]["text/plain"] == "\"foo\""
            end
        end


        # Revise integration
        Kernel(profile; capture_stdout=false, capture_stderr=false) do _
            jupyter_client(profile) do client
                @test length(IJulia._preexecute_hooks) == 1
                @test nameof(IJulia._preexecute_hooks[1]) == :revise_hook

                mktemp() do path, _
                    write(path, "foo() = 1")
                    code = """
                           using Revise
                           includet($(repr(path)))
                           """
                    @test msg_ok(execute(client, code))

                    # Test running the initial version of the code
                    client.execute("foo()")
                    msg = get_execute_result(client)
                    @test msg["content"]["data"]["text/plain"] == "1"

                    # Change the file and try again. Note that we allow multiple
                    # attempts because file events on Mac OS have a bit of
                    # latency so it might take some time for Revise to notice
                    # the update.
                    write(path, "foo() = 2")
                    ret = timedwait(10; pollint=0.5) do
                        client.execute("foo()")
                        msg = get_execute_result(client)
                        msg["content"]["data"]["text/plain"] == "2"
                    end
                    @test ret == :ok
                end
            end
        end

        shutdown_called = false
        Kernel(profile; capture_stdout=false, capture_stderr=false, shutdown=(_) -> shutdown_called = true) do kernel
            jupyter_client(profile) do client
                @testset "Comms" begin
                    # Try opening a Comm without a target_name, which should
                    # only trigger a comm_close message.
                    open_msg = IJulia.Msg(["foo"],
                                          Dict("username" => "user",
                                               "session" => "session1"),
                                          Dict("comm_id" => "foo",
                                               "data" => Dict()))
                    IJulia.comm_open(kernel.requests[], kernel, open_msg)
                    @test get_comm_close(client)["content"]["comm_id"] == "foo"

                    # Setting the target_name should cause the Comm to be created
                    open_msg.content["target_name"] = "foo"
                    IJulia.comm_open(kernel.requests[], kernel, open_msg)
                    @test kernel.comms["foo"] isa IJulia.Comm{:foo}

                    @test haskey(comm_info(client)["content"]["comms"], "foo")

                    # Smoke test for comm_msg (incoming to the kernel)
                    msg_msg = IJulia.Msg(["foo"],
                                         Dict("username" => "user",
                                              "session" => "session1"),
                                         Dict("comm_id" => "foo",
                                              "data" => Dict()))
                    IJulia.comm_msg(kernel.requests[], kernel, msg_msg)

                    # Test comm_msg (outgoing from the kernel)
                    IJulia.send_comm(kernel.comms["foo"], Dict(1 => 2))
                    @test get_comm_msg(client)["content"]["data"]["1"] == 2

                    # Test comm_close (outgoing from the kernel)
                    IJulia.close_comm(kernel.comms["foo"])
                    # Should this also delete the Comm from kernel.comms?
                    @test get_comm_close(client)["content"]["comm_id"] == "foo"

                    # Test comm_close (incoming to the kernel)
                    close_msg = IJulia.Msg(["foo"],
                                           Dict("username" => "user",
                                                "session" => "session1"),
                                           Dict("comm_id" => "foo",
                                                "data" => Dict()))
                    IJulia.comm_close(kernel.requests[], kernel, close_msg)
                    @test !haskey(kernel.comms, "foo")
                end

                # Test load()/load_string()
                mktemp() do path, _
                    write(path, "42")

                    msg = execute(client, "IJulia.load($(repr(path)))")
                    @test msg_ok(msg)
                    @test length(msg["content"]["payload"]) == 1
                end

                # Test hooks
                @testset "Hooks" begin
                    preexecute = false
                    postexecute = false
                    posterror = false
                    preexecute_hook = () -> preexecute = !preexecute
                    postexecute_hook = () -> postexecute = !postexecute
                    posterror_hook = () -> posterror = !posterror
                    IJulia.push_preexecute_hook(preexecute_hook)
                    IJulia.push_postexecute_hook(postexecute_hook)
                    IJulia.push_posterror_hook(posterror_hook)
                    @test msg_ok(execute(client, "42"))

                    # The pre/post hooks should've been called but not the posterror hook
                    @test preexecute
                    @test postexecute
                    @test !posterror

                    # With a throwing cell the posterror hook should be called
                    @test msg_error(execute(client, "error(42)"))
                    @test posterror

                    # After popping the hooks they should no longer be executed
                    preexecute = false
                    postexecute = false
                    posterror = false
                    IJulia.pop_preexecute_hook(preexecute_hook)
                    IJulia.pop_postexecute_hook(postexecute_hook)
                    IJulia.pop_posterror_hook(posterror_hook)
                    @test msg_ok(execute(client, "42"))
                    @test msg_error(execute(client, "error(42)"))
                    @test !preexecute
                    @test !postexecute
                    @test !posterror
                end

                # Smoke tests
                @test msg_ok(kernel_info(client))
                @test msg_ok(comm_info(client))
                @test msg_ok(history(client))
                @test msg_ok(execute(client, "IJulia.set_verbose(false)"))
                @test msg_ok(execute(client, "flush(stdout)"))

                # Test history(). This test requires `capture_stdout=false`.
                IJulia.clear_history()
                @test msg_ok(execute(client, "1"))
                @test msg_ok(execute(client, "42"))
                stdout_pipe = Pipe()
                redirect_stdout(stdout_pipe) do
                    IJulia.history()
                end
                close(stdout_pipe.in)
                @test collect(eachline(stdout_pipe)) == ["1", "42"]

                # Test that certain global variables are updated in kernel.current_module
                @test msg_ok(execute(client, "42"))
                @test msg_ok(execute(client, "ans == 42"))
                @test kernel.ans

                # Test an edge-case with displaying Type's:
                # https://github.com/JuliaLang/IJulia.jl/issues/1098
                @test msg_ok(execute(client, "Pair.body"))

                # Test shutdown_request
                @test msg_ok(shutdown(client))
                @test timedwait(() -> shutdown_called, 10) == :ok
            end
        end
    end

    @testset "jupyter_kernel_test" begin
        stdout_pipe = Pipe()
        stderr_pipe = Pipe()
        Base.link_pipe!(stdout_pipe)
        Base.link_pipe!(stderr_pipe)
        stdout_str = ""
        stderr_str = ""
        test_proc = nothing

        Kernel(profile; shutdown=Returns(nothing)) do kernel
            test_file = joinpath(@__DIR__, "kernel_test.py")

            mktemp() do connection_file, io
                # Write the connection file
                jupyter_client_lib.connect.write_connection_file(; fname=connection_file, profile_kwargs...)

                try
                    # Run jupyter_kernel_test
                    cmd = ignorestatus(`$(PythonCall.C.python_executable_path()) $(test_file)`)
                    cmd = addenv(cmd, "IJULIA_TESTS_CONNECTION_FILE" => connection_file)
                    cmd = pipeline(cmd; stdout=stdout_pipe, stderr=stderr_pipe)
                    test_proc = run(cmd)
                finally
                    close(stdout_pipe.in)
                    close(stderr_pipe.in)
                    stdout_str = read(stdout_pipe, String)
                    stderr_str = read(stderr_pipe, String)
                    close(stdout_pipe)
                    close(stderr_pipe)
                end
            end
        end

        if !isempty(stdout_str)
            @info "jupyter_kernel_test stdout:"
            println(stdout_str)
        end
        if !isempty(stderr_str)
            @info "jupyter_kernel_test stderr:"
            println(stderr_str)
        end
        if !success(test_proc)
            error("jupyter_kernel_test failed")
        end
    end

    # run_kernel() is the function that's actually run by Jupyter
    @testset "run_kernel()" begin
        julia = joinpath(Sys.BINDIR, "julia")

        mktemp() do connection_file, io
            # Write the connection file
            jupyter_client_lib.connect.write_connection_file(; fname=connection_file, profile_kwargs...)

            cmd = `$julia --startup-file=no --project=$(Base.active_project()) -e 'import IJulia; IJulia.run_kernel()' $(connection_file)`
            kernel_proc = run(pipeline(cmd; stdout, stderr); wait=false)
            try
                jupyter_client(profile) do client
                    @test msg_ok(kernel_info(client))
                    @test msg_ok(execute(client, "42"))

                    # Note that we don't wait for a reply because the kernel
                    # will shut down almost immediately and it's not guaranteed
                    # we'll receive the reply. We also sleep for a bit to try to
                    # ensure that the shutdown message is sent.
                    shutdown(client; wait=false)
                    sleep(0.1)
                end

                @test timedwait(() -> process_exited(kernel_proc), 60) == :ok
            finally
                kill(kernel_proc)
            end
        end
    end
end

@testset "Python integration" begin
    profile = IJulia.create_profile(; key=IJulia._TEST_KEY)

    # These are mostly just smoke tests
    Kernel(profile; capture_stdout=false, capture_stderr=false) do kernel
        jupyter_client(profile) do client
            # Test ipywidgets
            @test msg_ok(execute(client, """
                    using PythonCall
                    IJulia.init_matplotlib()

                    ipywidgets = pyimport("ipywidgets")
                    slider = ipywidgets.IntSlider(value=5)
            """))

            # Check that we've registered some comms
            @test length(methods(IJulia.CommManager.register_comm)) == 3

            # Test matplotlib
            @test msg_ok(execute(client, """
                    plt = pyimport("matplotlib.pyplot")
                    plt.figure()
                    plt.plot([1, 2, 3], [1, 4, 2])
            """))
        end
    end

    @testset "Utilities" begin
        ext = Base.get_extension(IJulia, :IJuliaPythonCallExt)

        x = Dict(1 => Dict{Int, Any}(2 => [1, 2]), "foo" => "bar")
        ext.arrays_to_pylist!(x)
        @test x[1][2] isa Py
        @test x["foo"] == "bar"

        @test_logs (:error, r"has not been implemented") ext.PyComm.open(1)
        @test_logs (:error, r"has not been implemented") ext.PyCommManager.unregister_target(1)
    end
end
