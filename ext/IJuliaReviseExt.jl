module IJuliaReviseExt

import IJulia
import Revise
import PrecompileTools: @compile_workload

function revise_hook()
    kernel = IJulia._default_kernel
    if isnothing(kernel)
        return
    end

    # This first time this function is called will be during execution of the
    # first cell, when it's impossible that any other packages have been loaded
    # except for IJulia and those in the startup files. Thus, it's very unlikely
    # that we actually need to call Revise.revise() and so we skip it if
    # possible to avoid compilation latency.
    if !isempty(Revise.revision_queue)
        # Inference barrier to prevent invalidations
        @invokelatest Revise.revise()
    end
end

function __init__()
    if @ccall(jl_generating_output()::Cint) == 0 && get(ENV, "JULIA_REVISE", "auto") == "auto"
        IJulia.push_preexecute_hook(revise_hook)
    end
end

@compile_workload begin
    revise_hook()
    Revise.revise()
end

end
