# Spawn a thread (using pthreads on Unix/OSX and Windows threads on Windows)
# to implement the "heartbeat" message channel, which is just a ZMQ
# socket that echoes all messages.  This is implemented with the zmq_device
# call in libzmq, which simply blocks forever, so the usual lack of
# thread safety in Julia should not be an issue here.

# entry point for new thread
function heartbeat_thread(sock::Ptr{Void})
    ccall((:zmq_device,ZMQ.zmq), Cint, (Cint, Ptr{Void}, Ptr{Void}),
          ZMQ.QUEUE, sock, sock)
    nothing
end

function start_heartbeat(sock)
    heartbeat_c = cfunction(heartbeat_thread, Void, (Ptr{Void},))
    ccall(:uv_thread_create, Cint, (Ptr{Int}, Ptr{Void}, Ptr{Void}),
          threadid, heartbeat_c, sock.data)
end
