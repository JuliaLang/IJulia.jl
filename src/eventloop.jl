"""
    eventloop(socket)

Generic event loop for one of the [kernel
sockets](https://jupyter-client.readthedocs.io/en/latest/messaging.html#introduction).
"""
function eventloop(socket)
    task_local_storage(:IJulia_task, "write task")
    try
        while true
            msg = recv_ipython(socket)
            try
                send_status("busy", msg)
                invokelatest(get(handlers, msg.header["msg_type"], unknown_request), socket, msg)
            catch e
                if e isa InterruptException && _shutting_down[]
                    # If we're shutting down, just return immediately
                    return
                elseif !isa(e, InterruptException)
                    # Try to keep going if we get an exception, but
                    # send the exception traceback to the front-ends.
                    # (Ignore SIGINT since this may just be a user-requested
                    #  kernel interruption to interrupt long calculations.)
                    content = error_content(e, msg="KERNEL EXCEPTION")
                    map(s -> println(orig_stderr[], s), content["traceback"])
                    send_ipython(publish[], msg_pub(execute_msg, "error", content))
                end
            finally
                flush_all()
                send_status("idle", msg)
            end
        end
    catch e
        if _shutting_down[]
            return
        end

        # the Jupyter manager may send us a SIGINT if the user
        # chooses to interrupt the kernel; don't crash on this
        if isa(e, InterruptException)
            eventloop(socket)
        else
            rethrow()
        end
    end
end

const requests_task = Ref{Task}()

"""
    waitloop()

Main loop of a kernel. Runs the event loops for the control and shell sockets
(note: in IJulia the shell socket is called `requests`).
"""
function waitloop()
    @async eventloop(control[])
    requests_task[] = @async eventloop(requests[])
    while true
        try
            wait()
        catch e
            # send interrupts (user SIGINT) to the code-execution task
            if isa(e, InterruptException)
                @async Base.throwto(requests_task[], e)
            else
                rethrow()
            end
        end
    end
end
