# Spawn a thread (using pthreads on Unix/OSX and Windows threads on Windows)
# to implement the "heartbeat" message channel, which is just a ZMQ
# socket that echoes all messages.  This is implemented with the zmq_proxy
# call in libzmq, which simply blocks forever, so the usual lack of
# thread safety in Julia should not be an issue here.

# entry point for new thread
function heartbeat_thread(heartbeat::Ptr{Cvoid})
    # Julia automatically "adopts" this thread because
    # we entered a Julia cfunction.  We then have to enable
    # a GC "safe" region to prevent us from grabbing the
    # GC lock with the call to zmq_proxy, which never returns.
    # (see julia#47196, julia#46609)
    ccall(:jl_gc_safe_enter, Int8, ())
    ret = ZMQ.lib.zmq_proxy(heartbeat, heartbeat, C_NULL)
    # leave safe region if zmq_proxy returns (when context is closed)
    ccall(:jl_gc_safe_leave, Int8, ())
    return ret
end

function start_heartbeat(kernel)
    heartbeat = kernel.heartbeat[]
    heartbeat.linger = 0
    heartbeat_c = @cfunction(heartbeat_thread, Cint, (Ptr{Cvoid},))
    ccall(:uv_thread_create, Cint, (Ptr{Int}, Ptr{Cvoid}, Ptr{Cvoid}),
          kernel.heartbeat_threadid, heartbeat_c, heartbeat)
end
