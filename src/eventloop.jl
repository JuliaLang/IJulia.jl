function eventloop(socket::Socket, msgs::Channel, handlers)
    while true
        try
            while true
                msg = take!(msgs)
                try
                    send_status("busy", msg)
                    invokelatest(get(handlers, msg.header["msg_type"], unknown_request), socket, msg)
                catch e
                    # Try to keep going if we get an exception, but
                    # send the exception traceback to the front-ends.
                    # (Ignore SIGINT since this may just be a user-requested
                    #  kernel interruption to interrupt long calculations.)
                    if !isa(e, InterruptException)
                        content = error_content(e, msg="KERNEL EXCEPTION")
                        map(s -> println(orig_stderr[], s), content["traceback"])
                        send_ipython(publish[], msg_pub(execute_msg, "error", content))
                    else
                        rethrow()
                    end
                finally
                    flush_all()
                    send_status("idle", msg)
                end
                yield()
            end
        catch e
            # the Jupyter manager may send us a SIGINT if the user
            # chooses to interrupt the kernel; don't crash on this
            if !isa(e, InterruptException)
                rethrow()
            end
        end
        yield()
    end
end

const iopub_task = Ref{Task}()
const requests_task = Ref{Task}()
function waitloop()
    control_msgs = Channel{Msg}(32) do ch
        task_local_storage(:IJulia_task, "control_msgs task")
        while isopen(control[])
            msg::Msg = recv_ipython(control[])
            put!(ch, msg)
            yield()
        end
    end

    iopub_msgs = Channel{Msg}(32)
    request_msgs = Channel{Msg}(32) do ch
        task_local_storage(:IJulia_task, "request_msgs task")
        while isopen(requests[])
            msg::Msg = recv_ipython(requests[])
            if haskey(iopub_handlers,  msg.header["msg_type"])
                put!(iopub_msgs, msg)
            else
                put!(ch, msg)
            end
            yield()
        end
    end

    control_task = @async begin
        task_local_storage(:IJulia_task, "control handle/write task")
        eventloop(control[], control_msgs, handlers)
    end
    requests_task[] = @async begin
        task_local_storage(:IJulia_task, "requests handle/write task")
        eventloop(requests[], request_msgs, handlers)
    end
    iopub_task[] = @async begin
        task_local_storage(:IJulia_task, "iopub handle/write task")
        eventloop(requests[], iopub_msgs, iopub_handlers)
    end

    bind(control_msgs, control_task)
    bind(request_msgs, requests_task[])
    bind(iopub_msgs, iopub_task[])

    while true
        try
            wait()
        catch e
            # send interrupts (user SIGINT) to the code-execution task
            if isa(e, InterruptException)
                @async Base.throwto(iopub_task[], e)
                @async Base.throwto(requests_task[], e)
            else
                rethrow()
            end
        end
    end
end

