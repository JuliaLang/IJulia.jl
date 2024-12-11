# Spawn a thread (using pthreads on Unix/OSX and Windows threads on Windows)
# to implement the "heartbeat" message channel, which is just a ZMQ
# socket that echoes all messages.  This is implemented with the zmq_proxy
# call in libzmq, which simply blocks forever, so the usual lack of
# thread safety in Julia should not be an issue here.

import Libdl

const threadid = zeros(Int, 128) # sizeof(uv_thread_t) <= 8 on Linux, OSX, Win
const zmq_proxy_context = Ref{Context}()

# entry point for new thread
function heartbeat_thread(heartbeat_addr::Cstring)
    zmq_proxy_context[] = Context()
    heartbeat = Socket(zmq_proxy_context[], ROUTER)
    GC.@preserve heartbeat_addr bind(heartbeat, unsafe_string(heartbeat_addr))
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

function start_heartbeat(heartbeat_addr)
    heartbeat_c = @cfunction(heartbeat_thread, Cint, (Cstring,))
    ccall(:uv_thread_create, Cint, (Ptr{Int}, Ptr{Cvoid}, Cstring),
          threadid, heartbeat_c, heartbeat_addr)
end
