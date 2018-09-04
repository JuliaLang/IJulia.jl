# Spawn a thread (using pthreads on Unix/OSX and Windows threads on Windows)
# to implement the "heartbeat" message channel, which is just a ZMQ
# socket that echoes all messages.  This is implemented with the zmq_proxy
# call in libzmq, which simply blocks forever, so the usual lack of
# thread safety in Julia should not be an issue here.


const threadid = zeros(Int, 128) # sizeof(uv_thread_t) <= 8 on Linux, OSX, Win
using ZMQ: libzmq

# entry point for new thread
function heartbeat_thread(sock::Ptr{Cvoid})
    ccall((:zmq_proxy,libzmq), Cint, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
          sock, sock, C_NULL)
    nothing
end

function start_heartbeat(sock)
    heartbeat_c = @cfunction(heartbeat_thread, Cvoid, (Ptr{Cvoid},))
    ccall(:uv_thread_create, Cint, (Ptr{Int}, Ptr{Cvoid}, Ptr{Cvoid}),
          threadid, heartbeat_c, sock)
end
