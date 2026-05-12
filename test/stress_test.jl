# Stress test for the IJulia eventloop and ZMQ polling.
#
# Hammers the kernel with rapid, overlapping requests across multiple channels
# to surface race conditions, spurious wakeups, and polling bugs.
#
# Usage:
#   julia --project=@. test/stress_test.jl [rounds]
#
# `rounds` defaults to 10. Each round spins up a fresh kernel and runs a battery
# of high-throughput request patterns against it.

using TestEnv; TestEnv.activate()

# ── CondaPkg / PythonCall bootstrap (copied from kernel.jl) ──────────────
cp(joinpath(@__DIR__, "CondaPkg.toml"),
   joinpath(dirname(Base.active_project()), "CondaPkg.toml"); force=true)
ENV["JULIA_CONDAPKG_ENV"] = "@ijulia-tests"
ENV["JULIA_CONDAPKG_VERBOSITY"] = "-1"

using Test
import Sockets
import ZMQ
import PythonCall
import PythonCall: Py, pyimport, pyconvert, pytype, pystr

jupyter_client_lib = pyimport("jupyter_client")
jupyter_client_lib.session.protocol_version = "5.4"
const BlockingKernelClient = jupyter_client_lib.BlockingKernelClient

import IJulia
import IJulia: Kernel

# ── Helpers (shared with kernel.jl) ──────────────────────────────────────

function test_py_get!(get_func, result)
    try
        result[] = get_func(timeout=0)
        return true
    catch ex
        exception_type = pyconvert(String, ex.t.__name__)
        exception_type == "Empty" || rethrow()
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

function make_request(request_func, get_func, args...; wait=true, timeout=20, kwargs...)
    request_func(args...; kwargs..., reply=false)
    wait || return nothing
    result = Ref{Py}()
    if timedwait(() -> test_py_get!(get_func, result), timeout) == :timed_out
        error("Jupyter channel get timed out")
    end
    return recursive_pyconvert(result[])
end

kernel_info(client)       = make_request(client.kernel_info,  client.get_shell_msg)
comm_info(client)         = make_request(client.comm_info,    client.get_shell_msg)
history(client)           = make_request(client.history,      client.get_shell_msg)
execute(client, code)     = make_request(client.execute,      client.get_shell_msg; code)
inspect(client, code)     = make_request(client.inspect,      client.get_shell_msg; code)
complete(client, code)    = make_request(client.complete,     client.get_shell_msg; code)
shutdown(client; wait=true) = make_request(client.shutdown, client.get_control_msg; wait)
get_iopub_msg(client)     = make_request(Returns(nothing), client.get_iopub_msg)

function drain_iopub(client; timeout=5)
    count = 0
    deadline = time() + timeout
    while time() < deadline
        result = Ref{Py}()
        if test_py_get!(client.get_iopub_msg, result)
            count += 1
        else
            sleep(0.05)
        end
    end
    return count
end

msg_ok(msg) = msg["content"]["status"] == "ok"
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

# ── Stress-test batteries ───────────────────────────────────────────────

"""
Rapid-fire execute requests: send N executions as fast as possible, then
collect all N replies. Exercises the requests conductor poll loop, channel
throughput, and inproc forwarding.
"""
function stress_rapid_execute!(client, n)
    @info "  rapid execute: $n requests"
    # fire all requests without waiting
    for i in 1:n
        client.execute("$i + $i"; reply=false)
    end
    # collect all replies
    for i in 1:n
        result = Ref{Py}()
        if timedwait(() -> test_py_get!(client.get_shell_msg, result), 30) == :timed_out
            error("rapid execute timed out at reply $i/$n")
        end
        msg = recursive_pyconvert(result[])
        msg["content"]["status"] == "ok" || error("rapid execute failed at $i: $(msg["content"])")
    end
end

"""
Interleaved request types: alternate between execute, complete, inspect,
kernel_info, comm_info, and history. Exercises handler dispatch and makes
sure different msg_types don't step on each other.
"""
function stress_interleaved_requests!(client, n)
    @info "  interleaved requests: $n cycles"
    for i in 1:n
        @assert msg_ok(execute(client, "x_$i = $i"))
        @assert msg_ok(complete(client, "prin"))
        @assert msg_ok(kernel_info(client))
        @assert msg_ok(inspect(client, "println"))
        @assert msg_ok(comm_info(client))
        @assert msg_ok(history(client))
    end
end

"""
Stdout-heavy execution: code that prints many lines, generating lots of
iopub stream messages. Stresses the publish socket and iopub forwarding.
"""
function stress_stdout_flood!(client, lines)
    @info "  stdout flood: $lines lines"
    code = """
    for i in 1:$lines
        println("line ", i)
    end
    """
    msg = execute(client, code)
    msg_ok(msg) || error("stdout flood execution failed: $(msg["content"])")
    drain_iopub(client; timeout=10)
end

"""
Rapid completions: fire many tab-completion requests. Stresses the shell
socket with small, fast round-trips.
"""
function stress_rapid_completions!(client, n)
    @info "  rapid completions: $n requests"
    prefixes = ["prin", "Base.", "mk", "is", "read", "write", "parse", "split"]
    for i in 1:n
        prefix = prefixes[mod1(i, length(prefixes))]
        msg = complete(client, prefix)
        msg_ok(msg) || error("rapid completion failed at $i: $(msg["content"])")
    end
end

"""
Comm open/msg/close cycles: rapidly create, message, and tear down comms.
Exercises iopub handler (comm messages route through IOPUB_HANDLERS) and
the comm registry on the kernel.
"""
function stress_comms!(client, kernel, n)
    @info "  comm cycles: $n"
    for i in 1:n
        comm_id = "stress-comm-$i"
        open_msg = IJulia.Msg(
            ["stress"],
            Dict("username" => "stress", "session" => "stress-session"),
            Dict("comm_id" => comm_id, "target_name" => "stress_target", "data" => Dict()))
        IJulia.comm_open(kernel.requests[], kernel, open_msg)

        if haskey(kernel.comms, comm_id)
            IJulia.send_comm(kernel.comms[comm_id], Dict("i" => i))

            close_msg = IJulia.Msg(
                ["stress"],
                Dict("username" => "stress", "session" => "stress-session"),
                Dict("comm_id" => comm_id, "data" => Dict()))
            IJulia.comm_close(kernel.requests[], kernel, close_msg)
        end
    end
    drain_iopub(client; timeout=5)
end

"""
Mixed concurrent load: interleave stdout-heavy executes with completions.
The execute generates iopub traffic while completions exercise the shell
socket simultaneously.
"""
function stress_mixed_load!(client, n)
    @info "  mixed load: $n iterations"
    for i in 1:n
        # An execute that produces some output
        msg = execute(client, """
            for j in 1:10
                println("mixed-$i-", j)
            end
            $i * 2
        """)
        msg_ok(msg) || error("mixed load execute failed at $i: $(msg["content"])")
        # Immediately follow with a completion
        msg = complete(client, "Base.pri")
        msg_ok(msg) || error("mixed load completion failed at $i: $(msg["content"])")
    end
end

"""
Async output stress: execute code that spawns tasks writing to stdout
concurrently. This creates many iopub messages from multiple sources.
"""
function stress_async_output!(client, ntasks, lines_per_task)
    @info "  async output: $ntasks tasks x $lines_per_task lines"
    code = """
    tasks = map(1:$ntasks) do t
        Threads.@spawn begin
            for i in 1:$lines_per_task
                println("task-", t, " line-", i)
            end
        end
    end
    foreach(wait, tasks)
    "done"
    """
    msg = execute(client, code)
    msg_ok(msg) || error("async output execution failed: $(msg["content"])")
    drain_iopub(client; timeout=10)
end

# ── Main loop ────────────────────────────────────────────────────────────

const ROUNDS = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 10

@info "Starting stress test" rounds=ROUNDS

for round in 1:ROUNDS
    @info "══ Round $round/$ROUNDS ══"
    profile = IJulia.create_profile(; key=IJulia._TEST_KEY)

    Kernel(profile; capture_stdout=true, capture_stderr=false) do kernel
        jupyter_client(profile) do client
            # Warm up
            @assert msg_ok(kernel_info(client))
            @assert msg_ok(execute(client, "1 + 1"))

            stress_rapid_execute!(client, 50)
            stress_interleaved_requests!(client, 10)
            stress_stdout_flood!(client, 500)
            stress_rapid_completions!(client, 50)
            stress_comms!(client, kernel, 30)
            stress_mixed_load!(client, 20)
            stress_async_output!(client, 5, 50)

            # Clean shutdown
            shutdown(client; wait=false)
            sleep(0.1)
        end
    end

    @info "Round $round passed"
end

@info "All $ROUNDS rounds passed"
