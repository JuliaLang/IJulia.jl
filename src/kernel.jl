# workaround #60:
@osx_only ENV["PATH"] = JULIA_HOME*":"*ENV["PATH"]

include("IJulia.jl")
using IJulia
IJulia.init(ARGS)

# import things that we want visible in IJulia but not in REPL's using IJulia
import IJulia.ans

include("inline.jl")
using IPythonDisplay
pushdisplay(InlineDisplay())

if VERSION >= v"0.3"
    ccall(:jl_exit_on_sigint, Void, (Cint,), 0)
else
    ccall(:jl_install_sigint_handler, Void, ())
end

# the size of truncated output to show should not depend on the terminal
# where the kernel is launched, since the display is elsewhere
ENV["LINES"] = 30
ENV["COLUMNS"] = 80

println(IJulia.orig_STDOUT, "Starting kernel event loops.")
IJulia.watch_stdio()

# workaround JuliaLang/julia#4259
delete!(task_local_storage(),:SOURCE_PATH)

# workaround JuliaLang/julia#6765
eval(Base, :(is_interactive = true))

IJulia.waitloop()
