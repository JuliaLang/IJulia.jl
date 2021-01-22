# Spawn via @async
# to implement the "heartbeat" message channel, which is just a ZMQ
# socket that echoes all messages.


function start_heartbeat(sock)
    @vprintln("[hb]: got socket")
    while true
        msg = recv(sock, String)
        @vprintln(msg)
        send(sock, msg)
    end
end

