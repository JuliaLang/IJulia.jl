module MIMEDisplay

export Display, display, push_display, pop_display, displayqueue, displayable,
   MIME, @MIME, mime_write, mime_repr, mime_string_repr, istextmime,
   mime_writable

###########################################################################
# We define a singleton type MIME{mime symbol} for each MIME type, so
# that Julia's dispatch and overloading mechanisms can be used to
# dispatch mime_write and to add conversions for new types.

immutable MIME{mime} end

import Base: show, string, convert
MIME(s) = MIME{symbol(s)}()
show{mime}(io::IO, ::MIME{mime}) = print(io, "MIME type ", string(mime))
string{mime}(::MIME{mime}) = string(mime)

# needs to be a macro so that we can use ::@mime(s) in type declarations
macro MIME(s)
    quote
        MIME{symbol($s)}
    end
end

###########################################################################
# For any type T one can define mime_write(io, ::@MIME(mime), x::T) = ...
# in order to provide a way to export T as a given mime type.

# We provide a fallback text/plain representation of any type:
mime_write(io, ::@MIME("text/plain"), x) = repl_show(io, x)

mime_writable{mime}(::MIME{mime}, T::Type) =
  method_exists(mime_write, (IO, MIME{mime}, T))

###########################################################################
# MIME types are assumed to be binary data except for a set of types known
# to be text data (possibly Unicode).  istextmime(m) returns whether
# m::MIME is text data, and mime_repr(m, x) returns x written to either
# a string (for text m::MIME) or a Vector{Uint8} (for binary m::MIME),
# assuming the corresponding write_mime method exists.  mime_string_repr
# is like mime_repr except that it always returns a string, which in the
# case of binary data is Base64-encoded.
#
# Also, if mime_repr is passed a String for a text type or Vector{Uint8} for
# a binary type, the argument is assumed to already be in the corresponding
# format and is returned unmodified.  This is useful so that raw data can be
# passed to display(m::MIME, x).

for mime in ["text/cmd", "text/css", "text/csv", "text/html", "text/javascript", "text/plain", "text/vcard", "text/xml", "application/atom+xml", "application/ecmascript", "application/json", "application/rdf+xml", "application/rss+xml", "application/xml-dtd", "application/postscript", "image/svg+xml", "application/x-latex", "application/xhtml+xml", "application/javascript", "application/xml", "model/x3d+xml", "model/x3d+vrml", "model/vrml"]
    @eval begin
        istextmime(::@MIME($mime)) = true
        mime_repr(m::@MIME($mime), x::String) = x
        mime_repr(m::@MIME($mime), x) = sprint(mime_write, m, x)
        mime_string_repr(m::@MIME($mime), x) = mime_repr(m, x)
        # avoid method ambiguities with definitions below:
        # (Q: should we treat Vector{Uint8} as a bytestring?)
        mime_repr(m::@MIME($mime), x::Vector{Uint8}) = sprint(mime_write, m, x)
        mime_string_repr(m::@MIME($mime), x::Vector{Uint8}) = mime_repr(m, x)
    end
end

istextmime(::MIME) = false
function mime_repr(m::MIME, x)
    s = IOBuffer()
    mime_write(s, m, x)
    takebuf_array(s)
end
mime_repr(m::MIME, x::Vector{Uint8}) = x
using Base64
mime_string_repr(m::MIME, x) = base64(mime_write, m, x)
mime_string_repr(m::MIME, x::Vector{Uint8}) = base64(write, x)

###########################################################################
# We have an abstract Display class that can be subclassed in order to
# define new rich-display output devices.  A typical subclass should
# overload display(d::Display, m::MIME, x) for supported MIME types m,
# (typically using mime_repr or mime_string_repr to get the MIME
# representation of x) and should also overload display(d::Display, x)
# to display x in whatever MIME type is preferred by the Display and
# is writable by x.  display(..., x) should throw a MethodError if x
# cannot be displayed.  The return value of display(...) is up to the
# Display type.

abstract Display
display(d::Display, mime::String, x) = display(d, MIME(mime), x)
display(mime::String, x) = display(MIME(mime), x)

# simplest display, which only knows how to display text/plain
immutable IODisplay <: Display
    io::IO
end
display(d::IODisplay, ::@MIME("text/plain"), x) =
    mime_write(d.io, MIME("text/plain"), x)
display(d::IODisplay, x) = display(d, MIME("text/plain"), x)

###########################################################################
# We keep a stack of Displays, and calling display(x) uses the topmost
# Display that is capable of displaying x (doesn't throw an error)

const displays = Display[ IODisplay(STDOUT) ]
function push_display(d::Display)
    global displays
    push!(displays, d)
end
pop_display() = pop!(displays)
function pop_display(d::Display)
    for i = length(displays):-1:1
        if d == displays[i]
            return splice!(displays, i)
        end
    end
    throw(KeyError(d))
end

function display(x)
    for i = length(displays):-1:1
        try
            return display(displays[i], x)
        end
    end
    throw(MethodError(display, (x,)))
end

function display(m::MIME, x)
    for i = length(displays):-1:1
        try
            return display(displays[i], m, x)
        end
    end
    throw(MethodError(display, (m, x)))
end

displayable{D<:Display,mime}(d::D, ::MIME{mime}) =
  method_exists(display, (D, MIME{mime}, Any))

function displayable(m::MIME)
    for d in displays
        if displayable(d, m)
            return true
        end
    end
    return false
end

###########################################################################
# In some cases, it is better to queue something for display later,
# for example in Matlab-like stateful plotting where you often create
# a plot and modify it several times, and you only want to display it
# at the end of the input.  In this case, you would push!(displayqueue, x)
# instead of display(x), and call display() at the end.
#
# (The IJulia interface calls flush_displayqueue() at the end of each cell.)

const displayqueue = Any[] # queue of objects to display (in order 1:end)

function display()
    for x in displayqueue
        display(x)
    end
end

###########################################################################

end # module
