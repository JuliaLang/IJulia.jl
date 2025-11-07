# define our own method to avoid type piracy with Base.showable
_showable(a::AbstractVector{<:MIME}, @nospecialize(x)) = any(m -> showable(m, x), a)
_showable(m, @nospecialize(x)) = showable(m, x)

"""
A vector of MIME types (or vectors of MIME types) that IJulia will try to
render. IJulia will try to render every MIME type specified in the first level
of the vector. If a vector of MIME types is specified, IJulia will include only
the first MIME type that is renderable (this allows for the expression of
priority and exclusion of redundant data).

For example, since "text/plain" is specified as a first-child of the array,
IJulia will always try to include a "text/plain" representation of anything that
is displayed. Since markdown and html are specified within a sub-vector, IJulia
will always try to render "text/markdown", and will only try to render
"text/html" if markdown isn't possible.
"""
const ijulia_mime_types = Vector{Union{MIME, AbstractVector{MIME}}}([
    MIME("text/plain"),
    MIME("image/svg+xml"),
    [MIME("image/png"),MIME("image/jpeg")],
    [
        MIME("text/markdown"),
        MIME("text/html"),
    ],
    MIME("text/latex"),
])

"""
MIME types that when rendered (via stringmime) return JSON data. See
`ijulia_mime_types` for a description of how MIME types are selected.

This is necessary to embed the JSON as is in the displaydata bundle (rather than
as stringify'd JSON).
"""
const ijulia_jsonmime_types = Vector{Union{MIME, Vector{MIME}}}([
    [[MIME("application/vnd.vegalite.v$n+json") for n in 4:-1:2]...,
    [MIME("application/vnd.vega.v$n+json") for n in 5:-1:3]...],
    MIME("application/vnd.dataresource+json"), MIME("application/vnd.plotly.v1+json")
])

"""
    register_mime(x::Union{MIME, Vector{MIME}})
    register_mime(x::AbstractVector{<:MIME})

Register a new MIME type.
"""
register_mime(x::Union{MIME, Vector{MIME}}) = push!(ijulia_mime_types, x)
register_mime(x::AbstractVector{<:MIME}) = push!(ijulia_mime_types, Vector{MIME}(x))

"""
    register_jsonmime(x::Union{MIME, Vector{MIME}})
    register_jsonmime(x::AbstractVector{<:MIME})

Register a new JSON MIME type.
"""
register_jsonmime(x::Union{MIME, Vector{MIME}}) = push!(ijulia_jsonmime_types, x)
register_jsonmime(x::AbstractVector{<:MIME}) = push!(ijulia_jsonmime_types, Vector{MIME}(x))

# return a String=>Any dictionary to attach as metadata
# in Jupyter display_data and pyout messages
metadata(x) = Dict()
transient(x) = Dict()

"""
Generate the preferred MIME representation of x.

Returns a tuple with the selected MIME type and the representation of the data
using that MIME type.
"""
function display_mimestring(mime_array::Vector{MIME}, @nospecialize(x))
    for m in mime_array
        if _showable(m, x)
            return display_mimestring(m, x)
        end
    end
    error("No displayable MIME types in mime array.")
end

display_mimestring(m::MIME, @nospecialize(x)) = (m, limitstringmime(m, x))

# text/plain output must have valid Unicode data to display in Jupyter
function display_mimestring(m::MIME"text/plain", @nospecialize(x))
    s = limitstringmime(m, x)
    return m, (isvalid(s) ? s : "(binary data)")
end

"""
Generate the preferred json-MIME representation of x.

Returns a tuple with the selected MIME type and the representation of the data
using that MIME type (as a `JSONText`).
"""
function display_mimejson(mime_array::Vector{MIME}, x)
    for m in mime_array
        if _showable(m, x)
            return display_mimejson(m, x)
        end
    end
    error("No displayable MIME types in mime array.")
end

display_mimejson(m::MIME, x) = (m, JSONX.JSONText(limitstringmime(m, x, true)))

function _display_dict(@nospecialize(x))
    data = Dict{String, Union{String, JSONX.JSONText}}()
    for m in ijulia_mime_types
        if _showable(m, x)
            mime, mime_repr = display_mimestring(m, x)
            data[string(mime)] = mime_repr
        end
    end

    for m in ijulia_jsonmime_types
        try
            if _showable(m, x)
                mime, mime_repr = display_mimejson(m, x)
                data[string(mime)] = mime_repr
            end
        catch
        end
    end

    return data

end

"""
Generate a dictionary of `mime_type => data` pairs for all registered MIME
types. This is the format that Jupyter expects in `display_data` and
`execute_result` messages.
"""
display_dict(@nospecialize(x)) = _display_dict(x)

# remove x from the display queue
function undisplay(@nospecialize(x), kernel)
    # We do an explicit loop instead of calling findfirst() because findfirst()
    # ends up having a significant compile-time cost for complex types, and by
    # writing a loop we can despecialize the `x` argument. For types like Dict's
    # this removes ~0.5s from the display time.
    for i in eachindex(kernel.displayqueue)
        if isequal(x, kernel.displayqueue[i])
            splice!(kernel.displayqueue, i)
            break
        end
    end

    return x
end

import Base: ip_matches_func

function show_bt(io::IO, top_func::Symbol, t::Vector)
    # follow PR #17570 code in removing top_func from backtrace
    eval_ind = findlast(addr->ip_matches_func(addr, top_func), t)
    eval_ind !== nothing && (t = t[1:eval_ind-1])
    Base.show_backtrace(io, t)
end

# wrapper for showerror(..., backtrace=false) since invokelatest
# doesn't support keyword arguments.
showerror_nobt(io, e, bt) = showerror(io, e, bt, backtrace=false)

# return the content of a pyerr message for exception e
function error_content(e, bt=catch_backtrace();
                       backtrace_top::Symbol=:include_string,
                       msg::AbstractString="")
    tb = map(String, split(sprint(show_bt,
                                        backtrace_top,
                                        bt; context=:color => true),
                                  "\n", keepempty=true))

    ename = string(typeof(e))
    evalue = try
        # Peel away one LoadError layer that comes from running include_string on the cell
        isa(e, LoadError) && (e = e.error)
        sprint((io, e, bt) -> invokelatest(showerror_nobt, io, e, bt), e, bt; context=InlineIOContext(stderr))
    catch
        "SYSTEM: show(lasterr) caused an error"
    end
    pushfirst!(tb, evalue) # fperez says this needs to be in traceback too
    if !isempty(msg)
        pushfirst!(tb, msg)
    end

    # Specify the value type as Any because types other than String may be in
    # the returned JSON.
    Dict{String, Any}("ename" => ename, "evalue" => evalue,
                      "traceback" => tb)
end

#######################################################################
