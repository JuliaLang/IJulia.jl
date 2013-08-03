include("base64.jl")
include("mimedisplay.jl")
include("IJulia.jl")
include("inline.jl")
include("wrappers.jl")

using MIMEDisplay
using IPythonDisplay
push_display(InlineDisplay())

using IJulia

println("Starting kernel event loops.")
for sock in (IJulia.requests, IJulia.control)
    IJulia.eventloop(sock)
end

wait()
