
# need special handling for showing a string as a textmime
# type, since in that case the string is assumed to be
# raw data unless it is text/plain
israwtext(::MIME, x::AbstractString) = true
israwtext(::MIME"text/plain", x::AbstractString) = false
israwtext(::MIME, x) = false

# convert x to a string of type mime, making sure to use an
# IOContext that tells the underlying show function to limit output
function limitstringmime(mime::MIME, x)
    buf = IOBuffer()
    if _istextmime(mime)
        if israwtext(mime, x)
            return String(x)
        else
            show(IOContext(buf, :limit=>true, :color=>true), mime, x)
        end
    else
        b64 = Base64EncodePipe(buf)
        if isa(x, Vector{UInt8})
            write(b64, x) # x assumed to be raw binary data
        else
            show(IOContext(b64, :limit=>true, :color=>true), mime, x)
        end
        close(b64)
    end
    return String(take!(buf))
end

# If the user explicitly calls display("foo/bar", x), we send
# the display message, also sending text/plain for text data.
displayable(d::InlineDisplay, M::MIME) = _istextmime(M)
function display(d::InlineDisplay, M::MIME, x)
    sx = limitstringmime(M, x)
    d = Dict(string(M) => sx)
    if _istextmime(M)
        d["text/plain"] = sx # directly show text data, e.g. text/csv
    end
    send_ipython(publish[],
                 msg_pub(execute_msg, "display_data",
                         Dict("metadata" => metadata(x), # optional
                              "data" => d)))
end

# override display to send IPython a dictionary of all supported
# output types, so that IPython can choose what to display.
function display(d::InlineDisplay, x)
    undisplay(x) # dequeue previous redisplay(x)
    send_ipython(publish[],
                 msg_pub(execute_msg, "display_data",
                         Dict("metadata" => metadata(x), # optional
                              "data" => display_dict(x))))
end

# we overload redisplay(d, x) to add x to a queue of objects to display,
# with the actual display occuring when display() is called or when
# an input cell has finished executing.

function redisplay(d::InlineDisplay, x)
    if !in(x,displayqueue)
        push!(displayqueue, x)
    end
end

function display()
    q = copy(displayqueue)
    empty!(displayqueue) # so that undisplay in display(x) is no-op
    for x in q
        display(x)
    end
end
