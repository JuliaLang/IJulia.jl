include("IJulia.jl")
include("inline.jl")

using IPythonDisplay
pushdisplay(InlineDisplay())

using IJulia

ccall(:jl_install_sigint_handler, Void, ())

# the size of truncated output to show should not depend on the terminal
# where the kernel is launched, since the display is elsewhere
ENV["LINES"] = 30
ENV["COLUMNS"] = 80

println(IJulia.orig_STDOUT, "Starting kernel event loops.")
IJulia.watch_stdio()
for sock in (IJulia.requests, IJulia.control)
    @async IJulia.eventloop(sock)
end

IJulia.waitloop()
