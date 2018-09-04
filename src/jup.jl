using Conda, VersionParsing

function prog_version(prog)
    v = try
        chomp(read(`$prog --version`, String))
    catch
        return nothing
    end
    try
       return vparse(v)
    catch
        Compat.@warn("`$jupyter --version` returned an unrecognized version number $v")
        return v"0.0"
    end
end

exe(f) = @static Compat.Sys.iswindows() ? f * ".exe" : f
condabin(f) = exe(joinpath(Conda.BINDIR, f))

# find the Jupyter notebook, installing it if necessary via Conda
function find_notebook()
    j = condabin("jupyter")
    if !isfile(j)
        if
    end
end



jupyter=""

# remove deps.jl at exit if it exists, in case build.jl fails
try
#######################################################################

# Make sure Python uses UTF-8 output for Unicode paths
ENV["PYTHONIOENCODING"] = "UTF-8"


global jupyter = get(ENV, "JUPYTER", isfile("JUPYTER") ? readchomp("JUPYTER") : : "")
if isempty(jupyter)
    jupyter_vers = nothing
else
    jupyter_vers = prog_version(jupyter)
    if jupyter_vers === nothing
        jupyter_vers = prog_version(jupyter * "-notebook")
    end
    if jupyter_vers === nothing
        Compat.@warn("Could not execute `$jupyter --version`.")
    end
end
isconda = dirname(jupyter) == abspath(Conda.SCRIPTDIR)
if Sys.ARCH in (:i686, :x86_64) && (jupyter_vers === nothing || jupyter_vers < v"3.0" || isconda)
    isconda || jupyter_vers === nothing || Compat.@info("$jupyter was too old: got $jupyter_vers, required ≥ 3.0")
    Compat.@info("Installing Jupyter via the Conda package.")
    Conda.add("jupyter")
    jupyter = abspath(Conda.SCRIPTDIR, "jupyter")
    jupyter_vers = prog_version(jupyter)
end
if jupyter_vers === nothing || jupyter_vers < v"3.0"
    error("Failed to find or install Jupyter 3.0 or later. Please install Jupyter manually, set `ENV[\"JUPYTER\"]=\"/path/to/jupyter\", and rerun `Pkg.build(\"IJulia\")`.")
end
Compat.@info("Found Jupyter version $jupyter_vers: $jupyter")

#######################################################################
# Get the latest syntax highlighter file.
if isconda
    highlighter = joinpath(Conda.LIBDIR, "python2.7", "site-packages", "notebook", "static",
                           "components", "codemirror", "mode", "julia", "julia.js")
    # CodeMirror commit from which we get the syntax highlighter
    cm_commit = "ed9278cba6e1f75328df6b257f1043d35a690c59"
    highlighter_url = "https://raw.githubusercontent.com/codemirror/CodeMirror/" *
                      cm_commit * "/mode/julia/julia.js"
    if isfile(highlighter)
        try
            download(highlighter_url, highlighter)
        catch e
            Compat.@warn("The following error occurred while attempting to download latest ",
                 "syntax highlighting definitions:\n\n", e, "\n\nSyntax highlighting may ",
                 "not work as expected.")
        end
    end
end

#######################################################################
# Warn people upgrading from older IJulia versions:
try
    juliaprof = chomp(read(pipeline(`$ipython locate profile julia`,
                                    stderr=devnull), String))
    Compat.@warn("""You should now run IJulia just via `$jupyter notebook`, without
            the `--profile julia` flag.  IJulia no longer maintains the profile.
            Consider deleting $juliaprof""")
catch
end



# figure out the notebook command by replacing (only!) the last occurrence of
# "kernelspec" with "notebook":
notebook = kspec_cmd.exec
n = notebook[end]
ki = VERSION < v"0.7.0-DEV.3252" ? rsearch(n, "kernelspec") : findlast("kernelspec", n)
notebook[end] = n[1:prevind(n,first(ki))] * "notebook" * n[nextind(n,last(ki)):end]


if v"4.2" ≤ jupyter_vers < v"5.1"
    # disable broken data-rate limit (issue #528)
    push!(notebook, "--NotebookApp.iopub_data_rate_limit=2147483647")
end

        # remove these hacks when
        # https://github.com/jupyter/notebook/issues/448 is closed and the fix
        # is widely available -- just run `$jupyter kernelspec ...` then.
        kspec_cmd = String[] # keep track of the kernelspec command used
        try
            run(`$jupyter kernelspec install --replace --user $juliakspec`)
            push!(kspec_cmd, jupyter, "kernelspec")
        catch
            @static if Compat.Sys.isunix()
                run(`$jupyter-kernelspec install --replace --user $juliakspec`)
                push!(kspec_cmd, jupyter * "-kernelspec")
            end

            # issue #363:
            @static if Compat.Sys.iswindows()
                jupyter_dir = dirname(jupyter)
                jks_exe = ""
                if jupyter_dir == abspath(Conda.SCRIPTDIR)
                    jk_path = "$jupyter-kernelspec"
                    if isfile(jk_path * "-script.py")
                        jk_path *= "-script.py"
                    end
                    python = abspath(Conda.PYTHONDIR, "python.exe")
                else
                    jks_exe = joinpath(jupyter_dir, "jupyter-kernelspec.exe")
                    if !isfile(jks_exe)
                        jk_path = readchomp(`where.exe $jupyter-kernelspec`)
                        # jupyter-kernelspec should start with "#!/path/to/python":
                        python = strip(chomp(open(readline, jk_path, "r"))[3:end])
                        # strip quotes, if any
                        if python[1] == python[end] == '"'
                            python = python[2:end-1]
                        end
                    end
                end
                if isfile(jks_exe)
                    run(`$jks_exe install --replace --user $juliakspec`)
                    push!(kspec_cmd, jks_exe)
                else
                    run(`$python $jk_path install --replace --user $juliakspec`)
                    push!(kspec_cmd, python, jk_path)
                end
            end
        end