using Compat.is_apple

# workaround #60:
if is_apple()
    ENV["PATH"] = JULIA_HOME*":"*ENV["PATH"]
end

include("IJulia.jl")
using IJulia
IJulia.init(ARGS)

# import things that we want visible in IJulia but not in REPL's using IJulia
import IJulia.ans

include("inline.jl")
using IPythonDisplay
pushdisplay(InlineDisplay())

ccall(:jl_exit_on_sigint, Void, (Cint,), 0)

# the size of truncated output to show should not depend on the terminal
# where the kernel is launched, since the display is elsewhere
ENV["LINES"] = get(ENV, "LINES", 30)
ENV["COLUMNS"] = get(ENV, "COLUMNS", 80)

println(IJulia.orig_STDOUT, "Starting kernel event loops.")
IJulia.watch_stdio()

# workaround JuliaLang/julia#4259
delete!(task_local_storage(),:SOURCE_PATH)

# workaround JuliaLang/julia#6765
eval(Base, :(is_interactive = true))

IJulia.waitloop()
