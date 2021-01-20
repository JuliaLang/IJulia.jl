# Spawn a thread (using pthreads on Unix/OSX and Windows threads on Windows)
# to implement the "heartbeat" message channel, which is just a ZMQ
# socket that echoes all messages.  This is implemented with the zmq_proxy
# call in libzmq, which simply blocks forever, so the usual lack of
# thread safety in Julia should not be an issue here.


using ZMQ: libzmq

function heartbeat_thread(addr)
    heartbeat = Ref{Socket}()
    heartbeat[] = Socket(ROUTER)
    sock = heartbeat[]

    bind(sock, addr)
    
    ccall((:zmq_proxy,libzmq), Cint, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
          sock, sock, C_NULL)
end

hb_pid = 0

function start_heartbeat(addr)
    global hb_pid = addprocs(1)[1]
    println("hb on pid $hb_pid, $addr")
    
    @everywhere @eval (!isdefined(Main, :IJulia) && using IJulia)

    @spawnat hb_pid IJulia.heartbeat_thread("$addr")
end
