# return a String=>Any dictionary to attach as metadata
# in Jupyter display_data and pyout messages
metadata(x) = Dict()

# queue of objects to display at end of cell execution
const displayqueue = Any[]

# remove x from the display queue
function undisplay(x)
    i = findfirst(isequal(x), displayqueue)
    i !== nothing && splice!(displayqueue, i)
    return x
end

import Base: ip_matches_func

function show_bt(io::IO, top_func::Symbol, t, set)
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
                       backtrace_top::Symbol=SOFTSCOPE[] ? :softscope_include_string : :include_string,
                       msg::AbstractString="")
    tb = map(String, split(sprint(show_bt,
                                        backtrace_top,
                                        bt, 1:typemax(Int)),
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
    Dict("ename" => ename, "evalue" => evalue,
                 "traceback" => tb)
end

#######################################################################
