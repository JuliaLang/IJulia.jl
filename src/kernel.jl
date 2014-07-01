# workaround #60:
@osx_only ENV["PATH"] = JULIA_HOME*":"*ENV["PATH"]

include("IJulia.jl")
using IJulia
IJulia.init(ARGS)

include("inline.jl")
using IPythonDisplay
pushdisplay(InlineDisplay())

ccall(:jl_install_sigint_handler, Void, ())

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
