# IJulia redirects stdout and stderr into "stream" messages sent to the
# Jupyter front-end.

# create a wrapper type around redirected stdio streams,
# both for overloading things like `flush` and so that we
# can set properties like `color`.
struct IJuliaStdio{IO_t <: IO} <: Base.AbstractPipe
    io::IOContext{IO_t}
end
IJuliaStdio(io::IO, stream::AbstractString="unknown") =
    IJuliaStdio{typeof(io)}(IOContext(io, :color=>Base.have_color,
                            :jupyter_stream=>stream,
                            :displaysize=>displaysize()))
Base.pipe_reader(io::IJuliaStdio) = io.io.io
Base.pipe_writer(io::IJuliaStdio) = io.io.io
Base.lock(io::IJuliaStdio) = lock(io.io.io)
Base.unlock(io::IJuliaStdio) = unlock(io.io.io)
Base.in(key_value::Pair, io::IJuliaStdio) = in(key_value, io.io)
Base.haskey(io::IJuliaStdio, key) = haskey(io.io, key)
Base.getindex(io::IJuliaStdio, key) = getindex(io.io, key)
Base.get(io::IJuliaStdio, key, default) = get(io.io, key, default)
Base.displaysize(io::IJuliaStdio) = displaysize(io.io)
Base.unwrapcontext(io::IJuliaStdio) = Base.unwrapcontext(io.io)
Base.setup_stdio(io::IJuliaStdio, readable::Bool) = Base.setup_stdio(io.io.io, readable)

if VERSION < v"1.7.0-DEV.254"
    for s in ("stdout", "stderr", "stdin")
        f = Symbol("redirect_", s)
        sq = QuoteNode(Symbol(s))
        @eval function Base.$f(io::IJuliaStdio)
            io[:jupyter_stream] != $s && throw(ArgumentError(string("expecting ", $s, " stream")))
            Core.eval(Base, Expr(:(=), $sq, io))
            return io
        end
    end
end

# logging in verbose mode goes to original stdio streams.  Use macros
# so that we do not even evaluate the arguments in no-verbose modes

using Printf
function get_log_preface()
    t = now()
    taskname = get(task_local_storage(), :IJulia_task, "")
    @sprintf("%02d:%02d:%02d(%s): ", Dates.hour(t),Dates.minute(t),Dates.second(t),taskname)
end

macro vprintln(x...)
    quote
        if verbose::Bool
            println(orig_stdout[], get_log_preface(), $(map(esc, x)...))
        end
    end
end

macro verror_show(e, bt)
    quote
        if verbose::Bool
            showerror(orig_stderr[], $(esc(e)), $(esc(bt)))
        end
    end
end

#name=>iobuffer for each stream ("stdout","stderr") so they can be sent in flush
const bufs = Dict{String,IOBuffer}()
const stream_interval = 0.1
# maximum number of bytes in libuv/os buffer before emptying
const max_bytes = 10*1024
# max output per code cell is 512 kb by default
const max_output_per_request = Ref(1 << 19)

"""
Continually read from (size limited) Libuv/OS buffer into an `IObuffer` to avoid problems when
the Libuv/OS buffer gets full (https://github.com/JuliaLang/julia/issues/8789). Send data immediately
when buffer contains more than `max_bytes` bytes. Otherwise, if data is available it will be sent every
`stream_interval` seconds (see the Timers set up in watch_stdio). Truncate the output to `max_output_per_request`
bytes per execution request since excessive output can bring browsers to a grinding halt.
"""
function watch_stream(rd::IO, name::AbstractString)
    task_local_storage(:IJulia_task, "read $name task")
    try
        buf = IOBuffer()
        bufs[name] = buf
        while !eof(rd) # blocks until something is available
            nb = bytesavailable(rd)
            if nb > 0
                stdio_bytes[] += nb
                # if this stream has surpassed the maximum output limit then ignore future bytes
                if stdio_bytes[] >= max_output_per_request[]
                    read(rd, nb) # read from libuv/os buffer and discard
                    if stdio_bytes[] - nb < max_output_per_request[]
                        send_ipython(publish[], msg_pub(execute_msg, "stream",
                                     Dict("name" => "stderr", "text" => "Excessive output truncated after $(stdio_bytes[]) bytes.")))
                    end
                else
                    write(buf, read(rd, nb))
                end
            end
            if buf.size > 0
                if buf.size >= max_bytes
                    #send immediately
                    send_stream(name)
                end
            end
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

function send_stdio(name)
    if verbose::Bool && !haskey(task_local_storage(), :IJulia_task)
        task_local_storage(:IJulia_task, "send $name task")
    end
    send_stream(name)
end

send_stdout(t::Timer) = send_stdio("stdout")
send_stderr(t::Timer) = send_stdio("stderr")

"""
Jupyter associates cells with message headers. Once a cell's execution state has
been set as to idle, it will silently drop stream messages (i.e. output to
stdout and stderr) - see https://github.com/jupyter/notebook/issues/518.
When using Interact, and a widget's state changes, a new
message header is sent to the IJulia kernel, and while Reactive
is updating Signal graph state, it's execution state is busy, meaning Jupyter
will not drop stream messages if Interact can set the header message under which
the stream messages will be sent. Hence the need for this function.
"""
function set_cur_msg(msg)
    global execute_msg = msg
end

function send_stream(name::AbstractString)
    buf = bufs[name]
    if buf.size > 0
        d = take!(buf)
        n = num_utf8_trailing(d)
        dextra = d[end-(n-1):end]
        resize!(d, length(d) - n)
        s = String(copy(d))
        if isvalid(String, s)
            write(buf, dextra) # assume that the rest of the string will be written later
            length(d) == 0 && return
        else
            # fallback: base64-encode non-UTF8 binary data
            sbuf = IOBuffer()
            print(sbuf, "base64 binary data: ")
            b64 = Base64EncodePipe(sbuf)
            write(b64, d)
            write(b64, dextra)
            close(b64)
            print(sbuf, '\n')
            s = String(take!(sbuf))
        end
        send_ipython(publish[],
             msg_pub(execute_msg, "stream",
                     Dict("name" => name, "text" => s)))
    end
end

"""
If `d` ends with an incomplete UTF8-encoded character, return the number of trailing incomplete bytes.
Otherwise, return `0`.
"""
function num_utf8_trailing(d::Vector{UInt8})
    i = length(d)
    # find last non-continuation byte in d:
    while i >= 1 && ((d[i] & 0xc0) == 0x80)
        i -= 1
    end
    i < 1 && return 0
    c = d[i]
    # compute number of expected UTF-8 bytes starting at i:
    n = c <= 0x7f ? 1 : c < 0xe0 ? 2 : c < 0xf0 ? 3 : 4
    nend = length(d) + 1 - i # num bytes from i to end
    return nend == n ? 0 : nend
end

"""
    readprompt(prompt::AbstractString; password::Bool=false)

Display the `prompt` string, request user input,
and return the string entered by the user.  If `password`
is `true`, the user's input is not displayed during typing.
"""
function readprompt(prompt::AbstractString; password::Bool=false)
    if !execute_msg.content["allow_stdin"]
        error("IJulia: this front-end does not implement stdin")
    end
    send_ipython(raw_input[],
                 msg_reply(execute_msg, "input_request",
                           Dict("prompt"=>prompt, "password"=>password)))
    while true
        msg = recv_ipython(raw_input[])
        if msg.header["msg_type"] == "input_reply"
            return msg.content["value"]
        else
            error("IJulia error: unknown stdin reply")
        end
    end
end

# override prompts using julia#28038 in 0.7
function check_prompt_streams(input::IJuliaStdio, output::IJuliaStdio)
    if get(input,:jupyter_stream,"unknown") != "stdin" ||
        get(output,:jupyter_stream,"unknown") != "stdout"
        throw(ArgumentError("prompt on IJulia stdio streams only works for stdin/stdout"))
        end
    end
function Base.prompt(input::IJuliaStdio, output::IJuliaStdio, message::AbstractString; default::AbstractString="")
    check_prompt_streams(input, output)
    val = chomp(readprompt(message * ": "))
    return isempty(val) ? default : val
end
function Base.getpass(input::IJuliaStdio, output::IJuliaStdio, message::AbstractString)
    check_prompt_streams(input, output)
    # fixme: should we do more to zero memory associated with the password?
    #        doing this properly might require working with the raw ZMQ message buffer here
    return Base.SecretBuffer!(Vector{UInt8}(codeunits(readprompt(message * ": ", password=true))))
end

# IJulia issue #42: there doesn't seem to be a good way to make a task
# that blocks until there is a read request from STDIN ... this makes
# it very hard to properly redirect all reads from STDIN to pyin messages.
# In the meantime, however, we can just hack it so that readline works:
import Base.readline
function readline(io::IJuliaStdio)
    if get(io,:jupyter_stream,"unknown") == "stdin"
        return readprompt("stdin> ")
    else
        readline(io.io)
    end
end

function watch_stdio()
    task_local_storage(:IJulia_task, "init task")
    if capture_stdout
        read_task = @async watch_stream(read_stdout[], "stdout")
        #send stdout stream msgs every stream_interval secs (if there is output to send)
        Timer(send_stdout, stream_interval, interval=stream_interval)
    end
    if capture_stderr
        readerr_task = @async watch_stream(read_stderr[], "stderr")
        #send STDERR stream msgs every stream_interval secs (if there is output to send)
        Timer(send_stderr, stream_interval, interval=stream_interval)
    end
end

function flush_all()
    flush_cstdio() # flush writes to stdout/stderr by external C code
    flush(stdout)
    flush(stderr)
end

function oslibuv_flush()
    #refs: https://github.com/JuliaLang/IJulia.jl/issues/347#issuecomment-144505862
    #      https://github.com/JuliaLang/IJulia.jl/issues/347#issuecomment-144605024
    @static if Sys.iswindows()
        ccall(:SwitchToThread, stdcall, Cvoid, ())
    end
    yield()
    yield()
end

import Base.flush
function flush(io::IJuliaStdio)
    flush(io.io)
    oslibuv_flush()
    send_stream(get(io,:jupyter_stream,"unknown"))
end
