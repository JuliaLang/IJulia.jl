#######################################################################
import JSON
using Compat

# print to stderr, since that is where Pkg prints its messages
eprintln(x...) = println(STDERR, x...)

# Make sure Python uses UTF-8 output for Unicode paths
ENV["PYTHONIOENCODING"] = "UTF-8"

include("ipython.jl")
const ipython, ipyvers = find_ipython()

if ipyvers < v"3.0"
    error("IPython 3.0 or later is required for IJulia, got $ipyvers instead")
else
    eprintln("Found IPython version $ipyvers ... ok.")
end

#######################################################################
# Warn people upgrading from older IJulia versions:
try
    juliaprof = chomp(readall(pipe(`$ipython locate profile julia`,
                                   stderr=DevNull)))
    warn("""You should now run IJulia just via `ipython notebook`, without
            without the `--profile julia` flag.  IJulia no longer maintains the profile.
            Consider deleting $juliaprof""")
end

#######################################################################
rb(filename::String) = open(readbytes, filename)
eqb(a::Vector{Uint8}, b::Vector{Uint8}) =
    length(a) == length(b) && all(a .== b)

# copy IJulia/deps/src to destpath/destname if it doesn't
# already exist at the destination, or if it has changed (if overwrite=true).
function copy_config(src::String, destpath::String,
                     destname::String=src; overwrite::Bool=true)
    mkpath(destpath)
    dest = joinpath(destpath, destname)
    srcbytes = rb(joinpath(Pkg.dir("IJulia"), "deps", src))
    if !isfile(dest) || (overwrite && !eqb(srcbytes, rb(dest)))
        eprintln("Copying $src to Julia IPython profile.")
        open(dest, "w") do f
            write(f, srcbytes)
        end
    else
        eprintln("(Existing $destname file untouched.)")
    end
end

#######################################################################
# Install IPython 3 kernel-spec file.

# Is IJulia being built from a debug build? If so, add "debug" to the description.
debugdesc = ccall(:jl_is_debugbuild,Cint,())==1 ? "-debug" : ""

juliakspec = joinpath(chomp(readall(`$ipython locate`)), "kernels", "julia-$(VERSION.major).$(VERSION.minor)"*debugdesc)

binary_name = @windows? "julia.exe":"julia"
kernelcmd_array = [escape_string(joinpath(JULIA_HOME,("$binary_name"))), "-i"]
ijulia_dir = get(ENV, "IJULIA_DIR", Pkg.dir("IJulia")) # support non-Pkg IJulia installs
append!(kernelcmd_array, ["-F", escape_string(joinpath(ijulia_dir,"src","kernel.jl")), "{connection_file}"])

ks = @compat Dict(
    "argv" => kernelcmd_array,
    "display_name" => "Julia " * Base.VERSION_STRING * debugdesc,
    "language" => "julia",
)

destname = "kernel.json"
mkpath(juliakspec)
dest = joinpath(juliakspec, destname)

eprintln("Writing IJulia kernelspec to $dest ...")

open(dest, "w") do f
    # indent by 2 for readability of file
    write(f, JSON.json(ks, 2))
end
copy_config("logo-32x32.png", juliakspec)
copy_config("logo-64x64.png", juliakspec)
