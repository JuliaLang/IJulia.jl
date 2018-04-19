import IJulia
using Compat

# workaround #60:
if IJulia.Compat.Sys.isapple()
    ENV["PATH"] = IJulia.Compat.Sys.BINDIR*":"*ENV["PATH"]
end

IJulia.init(ARGS)

# import things that we want visible in IJulia but not in REPL's using IJulia
import IJulia: ans, In, Out, clear_history

pushdisplay(IJulia.InlineDisplay())

ccall(:jl_exit_on_sigint, Cvoid, (Cint,), 0)

# the size of truncated output to show should not depend on the terminal
# where the kernel is launched, since the display is elsewhere
ENV["LINES"] = get(ENV, "LINES", 30)
ENV["COLUMNS"] = get(ENV, "COLUMNS", 80)

println(IJulia.orig_STDOUT[], "Starting kernel event loops.")
IJulia.watch_stdio()

# workaround JuliaLang/julia#4259
delete!(task_local_storage(),:SOURCE_PATH)

# workaround JuliaLang/julia#6765
eval(Base, :(is_interactive = true))

IJulia.waitloop()
