using Conda

if !haskey(ENV, "IJULIA_NODEFAULTKERNEL")
    # Install Jupyter kernel-spec file.
    include("kspec.jl")
    kernelpath = installkernel("Julia", "--project=@.")
end

# make it easier to get more debugging output by setting JULIA_DEBUG=1
# when building.
IJULIA_DEBUG = lowercase(get(ENV, "IJULIA_DEBUG", "0"))
IJULIA_DEBUG = IJULIA_DEBUG in ("1", "true", "yes")

# remember the user's Jupyter preference, if any; empty == Conda
prefsfile = joinpath(first(DEPOT_PATH), "prefs", "IJulia")
mkpath(dirname(prefsfile))
jupyter = get(ENV, "JUPYTER", isfile(prefsfile) ? readchomp(prefsfile) : Sys.isunix() && !Sys.isapple() ? "jupyter" : "")
condajupyter = normpath(Conda.SCRIPTDIR, exe("jupyter"))
if isempty(jupyter) || dirname(jupyter) == abspath(Conda.SCRIPTDIR)
    jupyter = condajupyter # will be installed if needed
elseif isabspath(jupyter)
    if !Sys.isexecutable(jupyter)
        @warn("ignoring non-executable JUPYTER=$jupyter")
        jupyter = condajupyter
    end
elseif jupyter != basename(jupyter) # relative path
    @warn("ignoring relative path JUPYTER=$jupyter")
    jupyter = condajupyter
elseif Sys.which(jupyter) === nothing
    @warn("JUPYTER=$jupyter not found in PATH")
end

function write_if_changed(filename, contents)
    if !isfile(filename) || read(filename, String) != contents
        write(filename, contents)
    end
end

# Install the deps.jl file:
deps = """
    const IJULIA_DEBUG = $(IJULIA_DEBUG)
    const JUPYTER = $(repr(jupyter))
"""
write_if_changed("deps.jl", deps)
write_if_changed(prefsfile, jupyter)
