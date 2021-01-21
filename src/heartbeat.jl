# Spawn a new process
# to implement the "heartbeat" message channel, which is just a ZMQ
# socket that echoes all messages.


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

