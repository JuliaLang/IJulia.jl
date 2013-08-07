#######################################################################
# History: global In/Out and other history variables exported to Main
const In = Dict{Integer,UTF8String}()
const Out = Dict{Integer,Any}()
_ = __ = __ = ans = nothing
export In, Out, _, __, ___, ans

# execution counter
_n = 0

#######################################################################
# methods to clear history or any subset thereof

export clear_history # user-visible in IJulia

function clear_history(indices)
    for n in indices
        delete!(In, n, nothing)
        if haskey(Out, n)
            delete!(Out, n)
            # no way to undefine _{n} variable, but we can set it to nothing
            eval(Main, :($(symbol(string("_",n))) = nothing))
        end
    end
end

# since a range could be huge, intersect it with 1:_n first
clear_history{T<:Integer}(r::Ranges{T}) =
    invoke(clear_history, (Any,), intersect(r, 1:_n))

function clear_history()
    clear_history(1:_n)
    global _, __, ___, ans
    ans = _ = __ = ___ = nothing
end

#######################################################################
