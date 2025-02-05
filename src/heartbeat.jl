# Spawn a thread (using pthreads on Unix/OSX and Windows threads on Windows)
# to implement the "heartbeat" message channel, which is just a ZMQ
# socket that echoes all messages.  This is implemented with the zmq_proxy
# call in libzmq, which simply blocks forever, so the usual lack of
# thread safety in Julia should not be an issue here.

# entry point for new thread
function heartbeat_thread(heartbeat::Ptr{Cvoid})
    @static if VERSION ≥ v"1.9.0-DEV.1588" # julia#46609
        # julia automatically "adopts" this thread because
        # we entered a Julia cfunction.  We then have to enable
        # a GC "safe" region to prevent us from grabbing the
        # GC lock with the call to zmq_proxy, which never returns.
        # (see julia#47196)
        ccall(:jl_gc_safe_enter, Int8, ())
    end
    ret = ZMQ.lib.zmq_proxy(heartbeat, heartbeat, C_NULL)
    @static if VERSION ≥ v"1.9.0-DEV.1588" # julia#46609
        # leave safe region if zmq_proxy returns (when context is closed)
        ccall(:jl_gc_safe_leave, Int8, ())
    end
    return ret
end

function start_heartbeat(kernel)
    heartbeat = kernel.heartbeat[]
    heartbeat.linger = 0
    heartbeat_c = @cfunction(heartbeat_thread, Cint, (Ptr{Cvoid},))
    ccall(:uv_thread_create, Cint, (Ptr{Int}, Ptr{Cvoid}, Ptr{Cvoid}),
          kernel.heartbeat_threadid, heartbeat_c, heartbeat)
end

function stop_heartbeat(kernel)
    if !isopen(kernel.heartbeat_context[])
        # Do nothing if it has already been stopped (which can happen in the tests)
        return
    end

    # First we call zmq_ctx_shutdown() to ensure that the zmq_proxy() call
    # returns. We don't call ZMQ.close(::Context) directly because that
    # currently isn't threadsafe:
    # https://github.com/JuliaInterop/ZMQ.jl/issues/256
    ZMQ.lib.zmq_ctx_shutdown(kernel.heartbeat_context[])
    @ccall uv_thread_join(kernel.heartbeat_threadid::Ptr{Int})::Cint

    # Now that the heartbeat thread has joined and its guaranteed to no longer
    # be working on the heartbeat socket, we can safely close it and then the
    # context.
    close(kernel.heartbeat[])
    close(kernel.heartbeat_context[])
end
