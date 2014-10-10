# During handling of an execute_request (when execute_msg is !nothing),
# we redirect STDOUT and STDERR into "stream" messages sent to the IPython
# front-end.

# logging in verbose mode goes to original stdio streams.  Use macros
# so that we do not even evaluate the arguments in no-verbose modes
macro vprintln(x...)
    quote
        if verbose::Bool
            println(orig_STDOUT, $(x...))
        end
    end
end
macro verror_show(e, bt)
    quote
        if verbose::Bool
            showerror(orig_STDERR, $e, $bt)
        end
    end
end

function send_stream(s::String, name::String)
    if !isempty(s)
        send_ipython(publish,
                     msg_pub(execute_msg, "stream",
                             @Compat.Dict("name" => name, "data" => s)))
    end
end

function watch_stream(rd::IO, name::String)
    try
        while !eof(rd) # blocks until something is available
            d = readbytes(rd, nb_available(rd))
            s = try
                bytestring(d)
            catch
                # FIXME: what should we do here?
                string("<ERROR: invalid UTF8 data ", d, ">")
            end
	    send_stream(s, name)
            sleep(0.1) # a little delay to accumulate output
        end
    catch e
        # the IPython manager may send us a SIGINT if the user
        # chooses to interrupt the kernel; don't crash on this
        if isa(e, InterruptException)
            watch_stream(rd, name)
        else
            rethrow()
        end
    end
end

# IJulia issue #42: there doesn't seem to be a good way to make a task
# that blocks until there is a read request from STDIN ... this makes
# it very hard to properly redirect all reads from STDIN to pyin messages.
# In the meantime, however, we can just hack it so that readline works:
import Base.readline
function readline(io::Base.Pipe)
    if io == STDIN
        if !execute_msg.content["allow_stdin"]
            error("IJulia: this front-end does not implement stdin")
        end
        send_ipython(raw_input,
                     msg_reply(execute_msg, "input_request",
                               @Compat.Dict("prompt" => "STDIN> ")))
        while true
            msg = recv_ipython(raw_input)
            if msg.header["msg_type"] == "input_reply"
                return msg.content["value"]
            else
                error("IJulia error: unknown stdin reply")
            end
        end
    else
        invoke(readline, (Base.AsyncStream,), io)
    end
end

function watch_stdio()
    @async watch_stream(read_stdout, "stdout")
    @async watch_stream(read_stderr, "stderr")
end

import Base.flush
function flush(io::Base.Pipe)
    invoke(flush, (super(Base.Pipe),), io)
    # send any available bytes to IPython (don't use readavailable,
    # since we don't want to block).
    if io == STDOUT
        send_stream(takebuf_string(read_stdout.buffer), "stdout")
    elseif io == STDERR
        send_stream(takebuf_string(read_stderr.buffer), "stderr")
    end
end
