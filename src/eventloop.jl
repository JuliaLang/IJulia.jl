"""
    eventloop(socket, kernel, msgs, handlers)

Generic event loop for one of the [kernel
sockets](https://jupyter-client.readthedocs.io/en/latest/messaging.html#introduction).
"""
function eventloop(socket, kernel, msgs, handlers)
    while isopen(msgs)
        try
            while isopen(msgs)
                msg = take!(msgs) # can throw if `msgs` is closed while waiting on it
                try
                    send_status("busy", kernel, msg)
                    invokelatest(get(handlers, msg.header["msg_type"], unknown_request), socket, kernel, msg)
                catch e
                    if e isa InterruptException && kernel.shutting_down[]
                        # If we're shutting down, just return immediately
                        return
                    elseif !isa(e, InterruptException)
                        # Try to keep going if we get an exception, but
                        # send the exception traceback to the front-ends.
                        # (Ignore SIGINT since this may just be a user-requested
                        #  kernel interruption to interrupt long calculations.)
                        content = error_content(e, msg="KERNEL EXCEPTION")
                        map(s -> println(orig_stderr[], s), content["traceback"])
                        send_ipython(kernel.publish[], kernel, msg_pub(kernel.execute_msg, "error", content))
                    end
                finally
                    flush_all()
                    send_status("idle", kernel, msg)
                end
                yield()
            end
        catch e
            if kernel.shutting_down[] || isa(e, ZMQ.StateError) || isa(e, InvalidStateException)
                # a ZMQ.StateError is almost certainly because of a closed socket
                # an InvalidStateException is because of a closed channel
                return
            elseif !isa(e, InterruptException)
                # the Jupyter manager may send us a SIGINT if the user
                # chooses to interrupt the kernel; don't crash for that
                rethrow()
            end
        end
        yield()
    end
end

"""
    waitloop(kernel)

Main loop of a kernel. Runs the event loops for the control, shell, and iopub sockets
(note: in IJulia the shell socket is called `requests`).
"""
function waitloop(kernel::Kernel)
    control_msgs = Channel{Msg}(Inf)
    request_msgs = Channel{Msg}(Inf)
    iopub_msgs = Channel{Msg}(Inf)

    bind(control_msgs, @async let poller = kernel.control_poller[], control = kernel.control[], inproc = kernel.control_inproc_pull[]
        task_local_storage(:IJulia_task, "control conductor")

        while isopen(control)
            try
                @vprintln("Control conductor: waiting on poller")
                pr = wait(poller)

                if pr.socket === control
                    @vprintln("Control conductor: received from Jupyter")
                    msg::Msg = recv_ipython(control, kernel)
                    put!(control_msgs, msg)
                elseif pr.socket === inproc
                    @vprintln("Control conductor: forwarding from inproc to Jupyter")
                    data = ZMQ.recv_multipart(inproc)
                    ZMQ.send_multipart(control, data)
                end
            catch e
                if kernel.shutting_down[] || isa(e, EOFError) || !isopen(control) || !isopen(poller)
                    # an EOFError is because of a closed socket when trying to read
                    # wait(::PollResult) can throw either ArgumentError or ErrorException if the socket is closed;
                    # checking if it's closed is simpler than checking for either possible error from wait
                    break
                else
                    rethrow()
                end
            end
            yield()
        end
    end)

    t2 = @async let poller = kernel.requests_poller[], requests = kernel.requests[], inproc = kernel.requests_inproc_pull[]
        task_local_storage(:IJulia_task, "requests conductor")

        while isopen(requests)
            try
                @vprintln("Requests conductor: waiting on poller")
                pr = wait(poller)

                if pr.socket === requests
                    @vprintln("Requests conductor: received from Jupyter")
                    msg::Msg = recv_ipython(requests, kernel)
                    if haskey(IOPUB_HANDLERS, msg.header["msg_type"])
                        put!(iopub_msgs, msg)
                    else
                        put!(request_msgs, msg)
                    end
                elseif pr.socket === inproc
                    @vprintln("Requests conductor: forwarding from inproc to Jupyter")
                    data = ZMQ.recv_multipart(inproc)
                    ZMQ.send_multipart(requests, data)
                end
            catch e
                if kernel.shutting_down[] || isa(e, EOFError) || !isopen(requests) || !isopen(poller)
                    close(iopub_msgs) # otherwise iopubs_msg would remain open, but with no producer anymore
                    # an EOFError is because of a closed socket when trying to read
                    # wait(::PollResult) can throw either ArgumentError or ErrorException if the socket is closed;
                    # checking if it's closed is simpler than checking for either possible error from wait
                    break
                else
                    rethrow()
                end
            end
            yield()
        end
    end
    errormonitor(t2)
    bind(request_msgs, t2)

    # tasks must all be on the same thread as the `waitloop` calling thread, because
    # `throwto` can't cross/change threads
    # Handler tasks - send via inproc sockets
    control_task = @async begin
        task_local_storage(:IJulia_task, "control handler")
        eventloop(kernel.control_inproc_push[], kernel, control_msgs, HANDLERS)
    end
    kernel.requests_task[] = @async begin
        task_local_storage(:IJulia_task, "requests handler")
        eventloop(kernel.requests_inproc_push[], kernel, request_msgs, HANDLERS)
    end
    kernel.iopub_task[] = @async begin
        task_local_storage(:IJulia_task, "iopub handler")
        eventloop(kernel.requests_inproc_push[], kernel, iopub_msgs, IOPUB_HANDLERS)
    end

    # msg channels should close when tasks are terminated
    bind(control_msgs, control_task)
    bind(request_msgs, kernel.requests_task[])
    # unhandled errors in iopub_task should also kill the request_msgs channel (since we
    # currently don't restart a failed iopub task)
    bind(request_msgs, kernel.iopub_task[])
    bind(iopub_msgs, kernel.iopub_task[])

    while kernel.inited
        try
            wait(kernel.stop_event)
        catch e
            # send interrupts (user SIGINT) to the code-execution task
            if isa(e, InterruptException)
                @async Base.throwto(kernel.requests_task[], e)
                @async Base.throwto(kernel.iopub_task[], e)
            else
                rethrow()
            end
        else
            # only wait for tasks to finish for a non-error'ed try wait
            wait(control_task)
            wait(kernel.requests_task[])
            wait(kernel.iopub_task[])
        end
    end
end
