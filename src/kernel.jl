include("multimedia.jl")
include("IJulia.jl")
include("inline.jl")
include("wrappers.jl")

using IPythonDisplay
pushdisplay(InlineDisplay())

using IJulia

ccall(:jl_install_sigint_handler, Void, ())

println(IJulia.orig_STDOUT, "Starting kernel event loops.")
IJulia.watch_stdio()
for sock in (IJulia.requests, IJulia.control)
    @async IJulia.eventloop(sock)
end

IJulia.waitloop()
