include("base64.jl")
include("datadisplay.jl")
include("IJulia.jl")
include("inline.jl")
include("wrappers.jl")

using DataDisplay
using IPythonDataDisplay
push_display(InlineDisplay())

using IJulia

println("Starting kernel event loops.")
for sock in (IJulia.requests, IJulia.control)
    IJulia.eventloop(sock)
end

wait()
