# Spawn a thread (using pthreads on Unix/OSX and Windows threads on Windows)
# to implement the "heartbeat" message channel, which is just a ZMQ
# socket that echoes all messages.  This is implemented with the zmq_device
# call in libzmq, which simply blocks forever, so the usual lack of
# thread safety in Julia should not be an issue here.

# entry point for new thread
function heartbeat_thread(sock::Ptr{Void})
    ccall((:zmq_device,ZMQ.zmq), Cint, (Cint, Ptr{Void}, Ptr{Void}),
          2, sock, sock)
    nothing # not correct on Windows, but irrelevant since we never return
end
const heartbeat_c = cfunction(heartbeat_thread, Void, (Ptr{Void},))

if @windows? false : true
    const threadid = Array(Int, 128) # sizeof(pthread_t) is <= 8 on Linux & OSX
end

function start_heartbeat(sock)
    @windows? begin
        ccall(:_beginthread, Int, (Ptr{Void}, Cuint, Ptr{Void}),
              heartbeat_c, 0, sock.data)
    end : begin
        ccall((:pthread_create, :libpthread), Cint,
              (Ptr{Int}, Ptr{Void}, Ptr{Void}, Ptr{Void}),
              threadid, C_NULL, heartbeat_c, sock.data)
    end
end
