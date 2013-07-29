module DataDisplay

export display, push_display, pop_display, top_display,
   write_html, write_svg, write_png, write_jpeg, write_latex, write_javascript, write_text,
   can_write_html, can_write_svg, can_write_png, can_write_jpeg, can_write_latex, can_write_javascript, can_write_text,
   repr_html, repr_svg, repr_png, repr_jpeg, repr_latex, repr_javascript, repr_text,
   string_html, string_svg, string_png, string_jpeg, string_latex, string_javascript, string_text,
   display_html, display_svg, display_png, display_jpeg, display_latex, display_javascript, display_text,
   can_display_html, can_display_svg, can_display_png, can_display_jpeg, can_display_latex, can_display_javascript, can_display_text

###########################################################################

abstract Display

# simplest display, which only knows how to display text/plain
immutable IODisplay <: Display
    io::IO
end
display_text(d::IODisplay, x) = write_text(d.io, x)

###########################################################################
# We keep a stack of Displays, and calling display(x) uses the topmost
# Display that is capable of displaying x (doesn't throw an error)

const display_stack = Display[ IODisplay(STDOUT) ]
function push_display(d::Display)
    global display_stack
    push!(display_stack, d)
end
pop_display() = pop!(display_stack)
function pop_display(d::Display)
    for i = length(display_stack):-1:1
        if d == display_stack[i]
            return splice!(display_stack, i)
        end
    end
    throw(KeyError(d))
end
top_display() = display_stack[end]

function display_(display_func::Function, x)
    for i = length(display_stack):-1:1
        try
            return display_func(display_stack[i], x)
        end
    end
    throw(MethodError(display_func, (x,)))
end

display(x) = display_(display, x)

###########################################################################

using Base64

# like sprint but returns Vector{Uint8}, designed for binary data
function bprint(f::Function, args...)
    s = IOBuffer()
    f(s, args...)
    takebuf_array(s)
end

###########################################################################

# formats and the corresponding MIME types, in descending order
# of "richness" (following IPython), which determines the default display
# format.
const formats = [(:javascript, "application/javascript"),
                 (:latex, "application/x-latex"),
                 (:html, "text/html"),
                 (:svg, "image/svg+xml"),
                 (:png, "image/png"),
                 (:jpeg, "image/jpeg"),
                 (:text, "text/plain")]

istext(mime) = let m = split(mime,"/")
    m[1] == "text" || m[1] == "application" || ismatch(r"\+xml$", m[2])
end

for (fmt,mime) in formats
    write_fmt = symbol(string("write_", fmt))
    can_write_fmt = symbol(string("can_write_", fmt))
    repr_fmt = symbol(string("repr_", fmt))
    string_fmt = symbol(string("string_", fmt))
    display_fmt = symbol(string("display_", fmt))
    can_display_fmt = symbol(string("can_display_", fmt))
    @eval begin
        $display_fmt(x) = display_($display_fmt, x)
        $can_display_fmt() = $can_display_fmt(get_display())
        $can_write_fmt{T}(::T) = method_exists($write_fmt, (IO, T))
    end
    if istext(mime)
        if fmt == :text
            # repl_show gives us a usable text representation of any type
            @eval begin
                $write_fmt(io, x) = repl_show(io, x)
                $can_write_fmt(x) = true
            end
        else
            # provide direct conversion of strings to textual MIME types
            # (but not arbitrary user-defined String types, which might
            #  already be some rich format, e.g. the user might define 
            #  an HTML <: String, which we wouldn't want to write as LaTeX)
            @eval begin
                $repr_fmt(x::ByteString) = x
                $string_fmt(x::ByteString) = x
                $write_fmt(io, x::ByteString) = write(io, x)
                $can_write_fmt(::ByteString) = false # no auto-detection
            end
        end
        @eval begin
            $repr_fmt(x) = sprint($write_fmt, x)
            $string_fmt(x) = sprint($write_fmt, x)
            $can_display_fmt{T<:Display}(::T) = 
              method_exists($display_fmt, (T, ByteString))
        end
    else
        @eval begin
            $repr_fmt(x) = bprint($write_fmt, x)
            $string_fmt(x) = base64($write_fmt, x)
            $repr_fmt(x::Vector{Uint8}) = copy(x)
            $string_fmt(x::Vector{Uint8}) = base64(write, x)
            $write_fmt(io, x::Vector{Uint8}) = write(io, x)
            $can_write_fmt(::Vector{Uint8}) = false # no auto-detection
            $can_display_fmt{T<:Display}(::T) = 
               method_exists($display_fmt, (T, Vector{Uint8}))
        end
    end
end

# macro to generate big if-then-else statement to implement generic
# display(d, x) below.  Calls display_fmt(d, x) for the first format (fmt)
# that is supported by both the display d and by the data x, or
# running dflt if none are found.
macro pickdisplay(dflt)
    ex = dflt
    for i = length(formats):-1:1
        fmt = formats[i][1]
        ex = quote
            if $(symbol(string("can_display_", fmt)))(d) &&
               $(symbol(string("can_write_", fmt)))(x)
                $(symbol(string("display_", fmt)))(x)
            else
                $(ex)
            end
        end
    end
    ex
end

# subtypes of Display can override this e.g. to change the preferred choice
# of format (or to display in more than one format as with IPython).
function display(d::Display, x)
    @pickdisplay throw(MethodError(display, (d,x)))
end

end # module
