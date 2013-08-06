# During handling of an execute_request (when execute_msg is !nothing),
# we redirect STDOUT and STDERR into "stream" messages sent to the IPython
# front-end.

const orig_STDOUT = STDOUT
const read_stdout, write_stdout = redirect_stdout()
const orig_STDERR = STDERR
const read_stderr, write_stderr = redirect_stderr()

# logging in verbose mode goes to original stdio streams:
vprint(x...) = verbose::Bool && print(orig_STDOUT, x...)
vprintln(x...) = verbose::Bool && println(orig_STDOUT, x...)
verror_show(e, bt) = verbose::Bool && Base.error_show(orig_STDERR, e, bt)

function watch_stream(s::IO, name::String)
    try
        @async begin
            while true
                s = readavailable(rd) # blocks until something available
                vprintln("STDIO($name) = $s")
                send_ipython(publish,
                             msg_pub(execute_msg, "stream",
                                     ["name" => name, "data" => s]))
                sleep(0.1) # a little delay to accumulate output
            end
        end
    catch e
        # the IPython manager may send us a SIGINT if the user
        # chooses to interrupt the kernel; don't crash on this
        if isa(e, InterruptException)
            watch_stream(s, name)
        else
            rethrow()
        end
    end
end

function watch_stdio()
    watch_stream(read_stdout, "stdout")
    watch_stream(read_stderr, "stderr")
end