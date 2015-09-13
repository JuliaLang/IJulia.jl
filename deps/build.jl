#######################################################################
import JSON
using Compat

# print to stderr, since that is where Pkg prints its messages
eprintln(x...) = println(STDERR, x...)

# Make sure Python uses UTF-8 output for Unicode paths
ENV["PYTHONIOENCODING"] = "UTF-8"

include("jupyter.jl")
const jupyter, jupyter_vers = find_jupyter()

if basename(jupyter) == "jupyter"
    eprintln("Found jupyter kernelspec version $jupyter_vers ... ok.")
else
    if jupyter_vers < v"3.0"
        error("Jupyter or IPython 3.0 or later is required for IJulia, got IPython $jupyter_vers instead")
    else
        eprintln("Found IPython version $jupyter_vers ... ok.")
    end
end

#######################################################################
# Warn people upgrading from older IJulia versions:
try
    juliaprof = chomp(readall(pipeline(`$ipython locate profile julia`,
                                       stderr=DevNull)))
    warn("""You should now run IJulia just via `$jupyter notebook`, without
            the `--profile julia` flag.  IJulia no longer maintains the profile.
            Consider deleting $juliaprof""")
end

#######################################################################
# Install Jupyter kernel-spec file.

# Is IJulia being built from a debug build? If so, add "debug" to the description.
debugdesc = ccall(:jl_is_debugbuild,Cint,())==1 ? "-debug" : ""

spec_name = "julia-$(VERSION.major).$(VERSION.minor)"*debugdesc
juliakspec = spec_name

binary_name = @windows? "julia.exe":"julia"
kernelcmd_array = [joinpath(JULIA_HOME,("$binary_name")), "-i"]
ijulia_dir = get(ENV, "IJULIA_DIR", Pkg.dir("IJulia")) # support non-Pkg IJulia installs
append!(kernelcmd_array, ["-F", joinpath(ijulia_dir,"src","kernel.jl"), "{connection_file}"])

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

if VERSION < v"0.4-"
    function copy_config(src, destdir)
        dest = joinpath(destdir, src)
        if ispath(dest)
            rm(dest)
        end
        cp(src, dest)
    end
else
    copy_config(src, dest) = cp(src, joinpath(dest, src), remove_destination=true)
end

copy_config("logo-32x32.png", juliakspec)
copy_config("logo-64x64.png", juliakspec)

eprintln("Installing julia kernelspec $spec_name")
run(`$jupyter kernelspec install --replace --user $juliakspec`)
