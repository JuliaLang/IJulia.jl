# Spawn a thread (using pthreads on Unix/OSX and Windows threads on Windows)
# to implement the "heartbeat" message channel, which is just a ZMQ
# socket that echoes all messages.  This is implemented with the zmq_proxy
# call in libzmq, which simply blocks forever, so the usual lack of
# thread safety in Julia should not be an issue here.


function heartbeat_thread(addr)
    heartbeat = Ref{Socket}()
    heartbeat[] = Socket(REP)
    sock = heartbeat[]
    bind(sock, addr)

    while true
        msg = recv(sock, String)
        # println(msg)
        send(sock, msg)
    end
end


function start_heartbeat(addr)
    hb_pid = addprocs(1)[1]
    println("heart beat on: pid = $hb_pid, addr = $addr")
    
    @everywhere @eval (!isdefined(Main, :IJulia) && using IJulia)

    @spawnat hb_pid IJulia.heartbeat_thread(addr)
end
