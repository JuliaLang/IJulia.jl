include("base64.jl")
include("datadisplay.jl")
include("ipython.jl")
include("inline.jl")

using DataDisplay
using IPythonDataDisplay
set_display(InlineDisplay())

using IPythonKernel
for sock in (IPythonKernel.requests, IPythonKernel.control)
    IPythonKernel.eventloop(sock)
end

wait()
