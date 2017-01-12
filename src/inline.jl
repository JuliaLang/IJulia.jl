import Base: display, redisplay

immutable InlineDisplay <: Display end

# supported MIME types for inline display in IPython, in descending order
# of preference (descending "richness")
const ipy_mime = [ "text/html", "text/latex", "image/svg+xml", "image/png", "image/jpeg", "text/plain", "text/markdown", "application/javascript" ]

for mime in ipy_mime
    @eval begin
        function display(d::InlineDisplay, ::MIME{Symbol($mime)}, x)
            send_ipython(publish[],
                         msg_pub(execute_msg, "display_data",
                                 Dict("source" => "julia", # optional
                                  "metadata" => metadata(x), # optional
                                  "data" => Dict($mime => stringmime(MIME($mime), x)))))
        end
        displayable(d::InlineDisplay, ::MIME{Symbol($mime)}) = true
    end
end

# deal with annoying application/x-latex == text/latex synonyms
display(d::InlineDisplay, m::MIME"application/x-latex", x) = display(d, MIME("text/latex"), stringmime(m, x))

# deal with annoying text/javascript == application/javascript synonyms
display(d::InlineDisplay, m::MIME"text/javascript", x) = display(d, MIME("application/javascript"), stringmime(m, x))

# if the user explicitly calls display("text/foo", x), we should output the text
displayable(d::InlineDisplay, M::MIME) = istextmime(M)
function display(d::InlineDisplay, M::MIME, x)
    istextmime(M) || throw(MethodError(display, (d, M, x)))
    send_ipython(publish[],
                 msg_pub(execute_msg, "display_data",
                         Dict("source" => "julia", # optional
                          "metadata" => metadata(x), # optional
                          "data" => Dict("text/plain" => stringmime(M, x)))))
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
