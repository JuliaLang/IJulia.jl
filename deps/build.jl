#######################################################################
import JSON, Conda
using Compat

# remove deps.jl if it exists, in case build.jl fails
isfile("deps.jl") && rm("deps.jl")

# print to stderr, since that is where Pkg prints its messages
eprintln(x...) = println(STDERR, x...)

# Make sure Python uses UTF-8 output for Unicode paths
ENV["PYTHONIOENCODING"] = "UTF-8"


function prog_version(prog)
    try
       return convert(VersionNumber, chomp(readall(`$prog --version`)))
    catch
       return v"0.0"
    end
end

jupyter = ""
jupyter_vers = v"0.0"
for p in (haskey(ENV, "JUPYTER") ? (ENV["JUPYTER"],) : (isfile("JUPYTER") ? readchomp("JUPYTER") : "jupyter", "jupyter", "ipython", "ipython2", "ipython3", "ipython.bat"))
    v = prog_version(p)
    if v >= v"3.0"
       jupyter = p
       jupyter_vers = v
       break
    end
end
if jupyter_vers < v"3.0" || dirname(jupyter) == abspath(Conda.SCRIPTDIR)
    info("Installing Jupyter via the Conda package.")
    Conda.add("jupyter")
    jupyter = abspath(Conda.SCRIPTDIR,"jupyter")
    jupyter_vers = prog_version(jupyter)
    jupyter_vers < v"3.0" && error("failed to find $jupyter 3.0 or later")
end
info("Found Jupyter version $jupyter_vers: $jupyter")

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

# remove these hacks when
# https://github.com/jupyter/notebook/issues/448 is closed and the fix
# is widely available -- just run `$jupyter kernelspec ...` then.
try
    run(`$jupyter kernelspec install --replace --user $juliakspec`)
catch
    @unix_only run(`$jupyter-kernelspec install --replace --user $juliakspec`)

    # issue #363:
    @windows_only begin
        if dirname(jupyter) == abspath(Conda.SCRIPTDIR)
            jk_path = "$jupyter-kernelspec"
            if isfile(jk_path * "-script.py")
                jk_path *= "-script.py"
            end
            python = abspath(Conda.PYTHONDIR, "python.exe")
        else
            jk_path = readchomp(`where.exe $jupyter-kernelspec`)
            # jupyter-kernelspec should start with "#!/path/to/python":
            python = chomp(open(readline, jk_path, "r"))[3:end]
        end
        run(`$python $jk_path install --replace --user $juliakspec`)
    end
end
open("deps.jl", "w") do f
    print(f, """
          const jupyter = "$(escape_string(jupyter))"
          const jupyter_vers = $(repr(jupyter_vers))
          """)
end
open("JUPYTER", "w") do f
    println(f, jupyter)
end
