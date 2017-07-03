#######################################################################
import JSON, Conda
using Compat
import Compat.String

# remove deps.jl at exit if it exists, in case build.jl fails
try
#######################################################################

# print to stderr, since that is where Pkg prints its messages
eprintln(x...) = println(STDERR, x...)

# Make sure Python uses UTF-8 output for Unicode paths
ENV["PYTHONIOENCODING"] = "UTF-8"

function prog_version(prog)
    try
       return convert(VersionNumber, chomp(readstring(`$prog --version`)))
    catch
       return v"0.0"
    end
end

jupyter = get(ENV, "JUPYTER", isfile("JUPYTER") ? readchomp("JUPYTER") : is_linux() ? "jupyter" : "")
jupyter_vers = isempty(jupyter) ? v"0.0" : prog_version(jupyter)
if (jupyter_vers == v"0.0")                                                     # some Linux distributions (Debian) use jupyter-notebook to launch Jupyter
    jupyter_vers = prog_version(jupyter * "-notebook")
end
isconda = dirname(jupyter) == abspath(Conda.SCRIPTDIR)
if Sys.ARCH in (:i686, :x86_64) && (jupyter_vers < v"3.0" || isconda)
    isempty(jupyter) || isconda || info("$jupyter was too old: got $jupyter_vers, required ≥ 3.0")
    info("Installing Jupyter via the Conda package.")
    Conda.add("jupyter")
    jupyter = abspath(Conda.SCRIPTDIR, "jupyter")
    jupyter_vers = prog_version(jupyter)
end
if jupyter_vers < v"3.0"
    error("Failed to find or install Jupyter 3.0 or later. Please install Jupyter manually, set `ENV[\"JUPYTER\"]=\"/path/to/jupyter\", and rerun `Pkg.build(\"IJulia\")`.")
end
info("Found Jupyter version $jupyter_vers: $jupyter")

#######################################################################
# Warn people upgrading from older IJulia versions:
try
    juliaprof = chomp(readstring(pipeline(`$ipython locate profile julia`,
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
juliakspec = abspath(spec_name)

binary_name = is_windows() ? "julia.exe" : "julia"
kernelcmd_array = String[joinpath(JULIA_HOME,("$binary_name")), "-i"]
ijulia_dir = get(ENV, "IJULIA_DIR", Pkg.dir("IJulia")) # support non-Pkg IJulia installs
append!(kernelcmd_array, ["--startup-file=yes", "--color=yes", joinpath(ijulia_dir,"src","kernel.jl"), "{connection_file}"])

ks = Dict(
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

copy_config(src, dest) = cp(src, joinpath(dest, src), remove_destination=true)

copy_config("logo-32x32.png", juliakspec)
copy_config("logo-64x64.png", juliakspec)

eprintln("Installing julia kernelspec $spec_name")

# remove these hacks when
# https://github.com/jupyter/notebook/issues/448 is closed and the fix
# is widely available -- just run `$jupyter kernelspec ...` then.
notebook = String[]
try
    run(`$jupyter kernelspec install --replace --user $juliakspec`)
    push!(notebook, jupyter, "notebook")
catch
    @static if is_unix()
        run(`$jupyter-kernelspec install --replace --user $juliakspec`)
        push!(notebook, jupyter * "-notebook")
    end

    # issue #363:
    @static if is_windows()
        jupyter_dir = dirname(jupyter)
        jks_exe = ""
        if jupyter_dir == abspath(Conda.SCRIPTDIR)
            jk_path = "$jupyter-kernelspec"
            if isfile(jk_path * "-script.py")
                jk_path *= "-script.py"
            end
            jn_path = "$jupyter-notebook"
            if isfile(jn_path * "-script.py")
                jn_path *= "-script.py"
            end
            python = abspath(Conda.PYTHONDIR, "python.exe")
        else
            jks_exe = joinpath(jupyter_dir, "jupyter-kernelspec.exe")
            if !isfile(jks_exe)
                jk_path = readchomp(`where.exe $jupyter-kernelspec`)
                jn_path = readchomp(`where.exe $jupyter-notebook`)
                # jupyter-kernelspec should start with "#!/path/to/python":
                python = strip(chomp(open(readline, jk_path, "r"))[3:end])
                # strip quotes, if any
                if python[1] == python[end] == '"'
                    python = python[2:end-1]
                end
            else
                jn_path = joinpath(jupyter_dir, "jupyter-notebook.exe")
                isfile(jn_path) || error("$jn_path not found")
            end
        end
        if isfile(jks_exe)
            run(`$jks_exe install --replace --user $juliakspec`)
        else
            run(`$python $jk_path install --replace --user $juliakspec`)
        end
        if endswith(jn_path, ".exe")
            push!(notebook, jn_path)
        else
            push!(notebook, python, jn_path)
        end
    end
end
if v"4.2" ≤ jupyter_vers < v"5.1"
    # disable broken data-rate limit (issue #528)
    push!(notebook, "--NotebookApp.iopub_data_rate_limit=2147483647")
end
deps = """
    const jupyter = "$(escape_string(jupyter))"
    const notebook_cmd = ["$(join(map(escape_string, notebook), "\", \""))"]
    const jupyter_vers = $(repr(jupyter_vers))
    """
if !isfile("deps.jl") || readstring("deps.jl") != deps
    write("deps.jl", deps)
end
write("JUPYTER", jupyter)

#######################################################################
catch
isfile("deps.jl") && rm("deps.jl") # remove deps.jl file on build error
rethrow()
end
