import IJulia
using InteractiveUtils

# workaround #60:
if Sys.isapple()
    ENV["PATH"] = Sys.BINDIR*":"*ENV["PATH"]
end

IJulia.init(ARGS)

startupfile = abspath(homedir(), ".julia", "config", "startup_ijulia.jl")
isfile(startupfile) && Base.JLOptions().startupfile != 2 && Base.include(Main, startupfile)

# import things that we want visible in IJulia but not in REPL's using IJulia
import IJulia: ans, In, Out, clear_history

pushdisplay(IJulia.InlineDisplay())

ccall(:jl_exit_on_sigint, Cvoid, (Cint,), 0)

# the size of truncated output to show should not depend on the terminal
# where the kernel is launched, since the display is elsewhere
ENV["LINES"] = get(ENV, "LINES", 30)
ENV["COLUMNS"] = get(ENV, "COLUMNS", 80)

println(IJulia.orig_stdout[], "Starting kernel event loops.")
IJulia.watch_stdio()

# workaround JuliaLang/julia#4259
delete!(task_local_storage(),:SOURCE_PATH)

# workaround JuliaLang/julia#6765
Core.eval(Base, :(is_interactive = true))

# check whether Revise is running and as needed configure it to run before every prompt
if isdefined(Main, :Revise)
    mode = get(ENV, "JULIA_REVISE", "auto")
    mode == "auto" && IJulia.push_preexecute_hook(Main.Revise.revise)
end

IJulia.waitloop()
