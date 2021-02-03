import Base: display, redisplay

struct InlineDisplay <: AbstractDisplay end

# supported MIME types for inline display in IPython, in descending order
# of preference (descending "richness")
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

# need special handling for showing a string as a textmime
# type, since in that case the string is assumed to be
# raw data unless it is text/plain
israwtext(::MIME, x::AbstractString) = true
israwtext(::MIME"text/plain", x::AbstractString) = false
israwtext(::MIME, x) = false


# Check mime bundle dict key type and convert to string keys for JSON
_format_mime_key(k::String) = k
_format_mime_key(k::MIME) = string(k)
_format_mime_key(k) = error("MIME bundle keys should be instances of String or MIME")
_format_mimebundle(d::Dict{String}) = d
_format_mimebundle(d::AbstractDict) = Dict(_format_mime_key(k) => v for (k, v) in pairs(d))

"""
    display_data(mime::Union{MIME, String}, data, metadata::AbstractDict=Dict())
    display_data(mimebundle::AbstractDict, metadata::AbstractDict=Dict())

Publish encoded multimedia data to be displayed all Jupyter front ends.

This is a low-level function which acts as a direct interface to Jupyter's display system. It does
not perform any additional processing on the input data, use `display(::IJulia.InlineDisplay, x)` to
calculate and display the multimedia representation of an arbitrary object `x`.

In the Jupyter notebook/lab the data will be displayed in the output area of the cell being executed.
This will appear in addition to the display of the cell's execution result, if any. Multiple calls
to this function within the same cell will result in multiple displays within the same output area.

The first form of the function takes a single MIME type `mime` and encoded data `data`, which should
be one of the following:

* A string containing text data (e.g. for MIME types `text/html` or `application/javascript`) or
  base64-encoded binary data (e.g. for `image/png`).
* Any other value which can be converted to a JSON string by `JSON.json`, including `JSON.JSONText`.

The second form of the function takes a MIME bundle, which is a dictionary containing multiple
representations of the data keyed by MIME type. The front end will automatically select the richest
supported type to display.

`metadata` is an additional JSON dictionary describing the output. See the
[jupyter client documentation](https://jupyter-client.readthedocs.io/en/latest/messaging.html#display-data)
for the keys used by IPython, notable ones are `width::Int` and `height::Int` to control the size
of displayed images. When using the second form of the function the argument should be a dictionary
of dictionaries keyed by MIME type.


# Examples

Displaying a MIME bundle containing rich text in three different formats (the front end
will select only the richest type to display):

```julia
bundle = Dict(
    "text/plain" => "text/plain: foo bar baz",
    "text/html" => "<code>text/html</code>: foo <strong>bar</strong> <em>baz</em>",
    "text/markdown" => "`text/markdown`: foo **bar** *baz*",
)

IJulia.display_data(bundle)
```

Display each of these types individually:

```julia
for (mime, data) in pairs(bundle)
    IJulia.display_data(mime, data)
end
```

Displaying base64-encoded PNG image data:

```julia
using Base64

data = open(read, "example.png")  # Array{UInt8}
data_enc = base64encode(data)  # String

IJulia.display_data("image/png", data_enc)
```

Adjust the size of the displayed image by passing a metadata dictionary:

```julia
IJulia.display_data("image/png", data_enc, Dict("width" => 800, "height" => 600))
```
"""
function display_data(mimebundle::AbstractDict, metadata::AbstractDict=Dict())
    content = Dict("data" => _format_mimebundle(mimebundle), "metadata" => _format_mimebundle(metadata))
    flush_all() # so that previous stream output appears in order
    send_ipython(publish[], msg_pub(execute_msg, "display_data", content))
end

function display_data(mime::Union{MIME, AbstractString}, data, metadata::AbstractDict=Dict())
    mt = string(mime)
    d = Dict{String, Any}(mt => data)
    md = Dict{String, Any}(mt => metadata)
    mt != "text/plain" && (d["text/plain"] = "Unable to display data with MIME type $mt")  # Fallback
    display_data(d, md)
end


InlineIOContext(io, KVs::Pair...) = IOContext(
    io,
    :limit=>true, :color=>true, :jupyter=>true,
    KVs...
)

# convert x to a string of type mime, making sure to use an
# IOContext that tells the underlying show function to limit output
function limitstringmime(mime::MIME, x)
    buf = IOBuffer()
    if istextmime(mime)
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
        function display(d::InlineDisplay, ::MIME{Symbol($mime)}, x)
            flush_all() # so that previous stream output appears in order
            send_ipython(publish[],
                         msg_pub(execute_msg, "display_data",
                                 Dict(
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

# If the user explicitly calls display("foo/bar", x), we send
# the display message, also sending text/plain for text data.
displayable(d::InlineDisplay, M::MIME) = istextmime(M)
function display(d::InlineDisplay, M::MIME, x)
    sx = limitstringmime(M, x)
    d = Dict(string(M) => sx)
    if istextmime(M)
        d["text/plain"] = sx # directly show text data, e.g. text/csv
    end
    flush_all() # so that previous stream output appears in order
    send_ipython(publish[],
                 msg_pub(execute_msg, "display_data",
                         Dict("metadata" => metadata(x), # optional
                              "data" => d)))
end

# override display to send IPython a dictionary of all supported
# output types, so that IPython can choose what to display.
function display(d::InlineDisplay, x)
    undisplay(x) # dequeue previous redisplay(x)
    flush_all() # so that previous stream output appears in order
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
