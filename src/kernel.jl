include("base64.jl")
include("multimedia.jl")
include("IJulia.jl")
include("inline.jl")
include("wrappers.jl")

using Multimedia
using IPythonDisplay
pushdisplay(InlineDisplay())

using IJulia

ccall(:jl_install_sigint_handler, Void, ())

println(IJulia.orig_STDOUT, "Starting kernel event loops.")
IJulia.watch_stdio()
for sock in (IJulia.requests, IJulia.control)
    IJulia.eventloop(sock)
end

IJulia.waitloop()
