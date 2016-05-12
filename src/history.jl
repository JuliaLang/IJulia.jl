#######################################################################
# History: global In/Out and other exported history variables
const In = Dict{Int,String}()
const Out = Dict{Int,Any}()
ans = nothing

export In, Out
# (don't export ans to avoid conflicts from "using IJulia" in ordinary REPL;
#  ans is imported into Main by kernel.jl)

# execution counter
_n = 0

#######################################################################
# methods to clear history or any subset thereof

export clear_history # user-visible in IJulia

function clear_history(indices)
    for n in indices
        delete!(In, n)
        if haskey(Out, n)
            delete!(Out, n)
        end
    end
end

# since a range could be huge, intersect it with 1:_n first
clear_history{T<:Integer}(r::Range{T}) =
    invoke(clear_history, (Any,), intersect(r, 1:_n))

function clear_history()
    empty!(In)
    empty!(Out)
    global ans = nothing
end

#######################################################################
