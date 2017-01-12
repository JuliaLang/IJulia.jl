import Base: display, redisplay

immutable InlineDisplay <: Display end

# supported MIME types for inline display in IPython, in descending order
# of preference (descending "richness")
const ipy_mime = [ "text/html", "text/latex", "image/svg+xml", "image/png", "image/jpeg", "text/plain", "text/markdown", "application/javascript" ]

if VERSION >= v"0.5.0-dev+4305" # JuliaLang/julia#16354
    # convert x to a string of type mime, making sure to use an
    # IOContext that tells the underlying show function to limit output
    function limitstringmime(mime::MIME, x)
        buf = IOBuffer()
        if istextmime(mime)
            show(IOContext(buf, limit=true), mime, x)
        else
            b64 = Base64EncodePipe(buf)
            show(IOContext(b64, limit=true), mime, x)
            close(b64)
        end
        return Compat.UTF8String(take!(buf))
    end
else
    limitstringmime(mime::MIME, x) = stringmime(mime, x)
end

for mime in ipy_mime
    @eval begin
        function display(d::InlineDisplay, ::MIME{Symbol($mime)}, x)
            send_ipython(publish[],
                         msg_pub(execute_msg, "display_data",
                                 Dict("source" => "julia", # optional
                                  "metadata" => metadata(x), # optional
                                  "data" => Dict($mime => limitstringmime(MIME($mime), x)))))
        end
        displayable(d::InlineDisplay, ::MIME{Symbol($mime)}) = true
    end
end

# deal with annoying application/x-latex == text/latex synonyms
display(d::InlineDisplay, m::MIME"application/x-latex", x) = display(d, MIME("text/latex"), limitstringmime(m, x))

# deal with annoying text/javascript == application/javascript synonyms
display(d::InlineDisplay, m::MIME"text/javascript", x) = display(d, MIME("application/javascript"), limitstringmime(m, x))

# if the user explicitly calls display("text/foo", x), we should output the text
displayable(d::InlineDisplay, M::MIME) = istextmime(M)
function display(d::InlineDisplay, M::MIME, x)
    istextmime(M) || throw(MethodError(display, (d, M, x)))
    send_ipython(publish[],
                 msg_pub(execute_msg, "display_data",
                         Dict("source" => "julia", # optional
                          "metadata" => metadata(x), # optional
                          "data" => Dict("text/plain" => limitstringmime(M, x)))))
end

# override display to send IPython a dictionary of all supported
# output types, so that IPython can choose what to display.
function display(d::InlineDisplay, x)
    undisplay(x) # dequeue previous redisplay(x)
    send_ipython(publish[],
                 msg_pub(execute_msg, "display_data",
                         Dict("source" => "julia", # optional
                                      "metadata" => metadata(x), # optional
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
