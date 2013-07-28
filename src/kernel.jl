include("base64.jl")
include("datadisplay.jl")
include("IJulia.jl")
include("inline.jl")

using DataDisplay
using IPythonDataDisplay
set_display(InlineDisplay())

import IJulia
for sock in (IJulia.requests, IJulia.control)
    IJulia.eventloop(sock)
end

wait()
