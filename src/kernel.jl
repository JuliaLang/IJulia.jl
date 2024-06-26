import IJulia

let
    ijulia_kernel_file = joinpath(dirname(pathof(IJulia)), "kernel.jl")
    this_kernel_file = @__FILE__
    if stat(ijulia_kernel_file) != stat(this_kernel_file)
        @warn "this kernel.jl is different from the one provided by IJulia" this_kernel_file ijulia_kernel_file
    end
end

# Load InteractiveUtils from the IJulia namespace since @stdlib might not be in LOAD_PATH
using IJulia.InteractiveUtils

# workaround #60:
if Sys.isapple()
    ENV["PATH"] = Sys.BINDIR*":"*ENV["PATH"]
end

# the size of truncated output to show should not depend on the terminal
# where the kernel is launched, since the display is elsewhere
ENV["LINES"] = get(ENV, "LINES", 30)
ENV["COLUMNS"] = get(ENV, "COLUMNS", 80)

IJulia.init(ARGS)

let startupfile = !isempty(DEPOT_PATH) ? abspath(DEPOT_PATH[1], "config", "startup_ijulia.jl") : ""
    isfile(startupfile) && Base.JLOptions().startupfile != 2 && Base.include(Main, startupfile)
end

# import things that we want visible in IJulia but not in REPL's using IJulia
import IJulia: ans, In, Out, clear_history

pushdisplay(IJulia.InlineDisplay())

ccall(:jl_exit_on_sigint, Cvoid, (Cint,), 0)

println(IJulia.orig_stdout[], "Starting kernel event loops.")
IJulia.watch_stdio()

# workaround JuliaLang/julia#4259
delete!(task_local_storage(),:SOURCE_PATH)

# workaround JuliaLang/julia#6765
Core.eval(Base, :(is_interactive = true))

# check whether Revise is running and as needed configure it to run before every prompt
if isdefined(Main, :Revise)
    let mode = get(ENV, "JULIA_REVISE", "auto")
        mode == "auto" && IJulia.push_preexecute_hook(Main.Revise.revise)
    end
end

IJulia.waitloop()
