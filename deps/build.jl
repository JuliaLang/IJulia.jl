using Compat
using Compat.Unicode: lowercase

# Install Jupyter kernel-spec file.
include("kspec.jl")
kernelpath = installkernel("Julia")

# make it easier to get more debugging output by setting JULIA_DEBUG=1
# when building.
IJULIA_DEBUG = lowercase(get(ENV, "IJULIA_DEBUG", "0"))
IJULIA_DEBUG = IJULIA_DEBUG in ("1", "true", "yes")

# Install the deps.jl file:
deps = """
    const IJULIA_DEBUG = $(IJULIA_DEBUG)
"""
if !isfile("deps.jl") || read("deps.jl", String) != deps
    write("deps.jl", deps)
end
