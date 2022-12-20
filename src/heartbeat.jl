# Spawn a thread (using pthreads on Unix/OSX and Windows threads on Windows)
# to implement the "heartbeat" message channel, which is just a ZMQ
# socket that echoes all messages.  This is implemented with the zmq_proxy
# call in libzmq, which simply blocks forever, so the usual lack of
# thread safety in Julia should not be an issue here.

import Libdl

const threadid = zeros(Int, 128) # sizeof(uv_thread_t) <= 8 on Linux, OSX, Win
const zmq_proxy = Ref(C_NULL)

# entry point for new thread
function heartbeat_thread(sock::Ptr{Cvoid})
    @static if VERSION ≥ v"1.9.0-DEV.1588" # julia#46609
        # julia automatically "adopts" this thread because
        # we entered a Julia cfunction.  We then have to enable
        # a GC "safe" region to prevent us from grabbing the
        # GC lock with the call to zmq_proxy, which never returns.
        # (see julia#47196)
        ccall(:jl_gc_safe_enter, Int8, ())
    end
    ccall(zmq_proxy[], Cint, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
          sock, sock, C_NULL)
    nothing
end

function start_heartbeat(sock)
    zmq_proxy[] = Libdl.dlsym(Libdl.dlopen(ZMQ.libzmq), :zmq_proxy)
    heartbeat_c = @cfunction(heartbeat_thread, Cvoid, (Ptr{Cvoid},))
    ccall(:uv_thread_create, Cint, (Ptr{Int}, Ptr{Cvoid}, Ptr{Cvoid}),
          threadid, heartbeat_c, sock)
end
