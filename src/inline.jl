"""
Struct to dispatch on for inline display.
"""
struct InlineDisplay <: AbstractDisplay end

"""
Supported MIME types for inline display in IPython, in descending order
of preference (descending "richness").
"""
const ipy_mime = [
    "application/vnd.dataresource+json",
    ["application/vnd.vegalite.v$n+json" for n in 4:-1:2]...,
    ["application/vnd.vega.v$n+json" for n in 5:-1:3]...,
    "application/vnd.plotly.v1+json",
    "text/html",
    "text/latex",
    "image/svg+xml",
    "image/png",
    "image/jpeg",
    "text/plain",
    "text/markdown",
    "application/javascript"
]

"""
Need special handling for showing a string as a textmime type, since in that
case the string is assumed to be raw data unless it is text/plain.
"""
israwtext(m::MIME, x::AbstractString) = !showable(m, x)
israwtext(::MIME"text/plain", x::AbstractString) = false
israwtext(::MIME, x) = false

"""
    InlineIOContext(io, KVs::Pair...)

Create an `IOContext` for inline display.
"""
InlineIOContext(io, KVs::Pair...) = IOContext(
    io,
    :limit=>true, :color=>true, :jupyter=>true,
    KVs...
)

"""
    limitstringmime(mime::MIME, x, forcetext=false)

Convert x to a string of type mime, making sure to use an IOContext that tells
the underlying show function to limit output.
"""
function limitstringmime(mime::MIME, @nospecialize(x), forcetext=false)
    buf = IOBuffer()
    if forcetext || istextmime(mime)
        if israwtext(mime, x)
            return String(x)
        else
            show(InlineIOContext(buf), mime, x)
        end
    else
        b64 = Base64EncodePipe(buf)
        if isa(x, Vector{UInt8})
            write(b64, x) # x assumed to be raw binary data
        else
            show(InlineIOContext(b64), mime, x)
        end
        close(b64)
    end
    return String(take!(buf))
end

for mime in ipy_mime
    @eval begin
        function Base.display(d::InlineDisplay, ::MIME{Symbol($mime)}, @nospecialize(x))
            kernel = _default_kernel
            if isnothing(kernel)
                error("Kernel has not been instantiated, cannot display.")
            end

            flush_all() # so that previous stream output appears in order
            send_ipython(kernel.publish[], kernel,
                         msg_pub(kernel.execute_msg, "display_data",
                                 Dict(
                                  "metadata" => metadata(x), # optional
                                  "transient" => transient(x), # optional
                                  "data" => Dict($mime => limitstringmime(MIME($mime), x)))))
        end
        Base.displayable(d::InlineDisplay, ::MIME{Symbol($mime)}) = true
    end
end

# deal with annoying application/x-latex == text/latex synonyms
Base.display(d::InlineDisplay, m::MIME"application/x-latex", @nospecialize(x)) = display(d, MIME("text/latex"), limitstringmime(m, x))

# deal with annoying text/javascript == application/javascript synonyms
Base.display(d::InlineDisplay, m::MIME"text/javascript", @nospecialize(x)) = display(d, MIME("application/javascript"), limitstringmime(m, x))

# If the user explicitly calls display("foo/bar", x), we send
# the display message, also sending text/plain for text data.
Base.displayable(d::InlineDisplay, M::MIME) = istextmime(M)
function Base.display(d::InlineDisplay, M::MIME, @nospecialize(x))
    kernel = _default_kernel
    if isnothing(kernel)
        error("Kernel has not been initialized, cannot set its verbosity.")
    end

    sx = limitstringmime(M, x)
    d = Dict(string(M) => sx)
    if istextmime(M)
        d["text/plain"] = sx # directly show text data, e.g. text/csv
    end
    flush_all() # so that previous stream output appears in order
    send_ipython(kernel.publish[], kernel,
                 msg_pub(kernel.execute_msg, "display_data",
                         Dict("metadata" => metadata(x), # optional
                              "transient" => transient(x), # optional
                              "data" => d)))
end

# override display to send IPython a dictionary of all supported
# output types, so that IPython can choose what to display.
function Base.display(d::InlineDisplay, @nospecialize(x))
    kernel = _default_kernel
    if isnothing(kernel)
        error("Kernel has not been initialized, cannot set its verbosity.")
    end

    undisplay(x, kernel) # dequeue previous redisplay(x)
    flush_all() # so that previous stream output appears in order
    send_ipython(kernel.publish[], kernel,
                 msg_pub(kernel.execute_msg, "display_data",
                         Dict("metadata" => metadata(x), # optional
                              "transient" => transient(x), # optional
                              "data" => display_dict(x))))
end

# we overload redisplay(d, x) to add x to a queue of objects to display,
# with the actual display occurring when display() is called or when
# an input cell has finished executing.
function Base.redisplay(d::InlineDisplay, x)
    kernel = _default_kernel
    if !in(x, kernel.displayqueue)
        push!(kernel.displayqueue, x)
    end
end

function flush_kernel_display(kernel::Kernel)
    q = copy(kernel.displayqueue)
    empty!(kernel.displayqueue) # so that undisplay in display(x) is no-op
    for x in q
        display(x, kernel)
    end
end
