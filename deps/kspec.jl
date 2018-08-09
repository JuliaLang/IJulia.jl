#######################################################################
# Install Jupyter kernel-spec file.

copy_config(src, dest) = cp(src, joinpath(dest, basename(src)), force=true)

"""
    installkernel(name, options...; specname=replace(lowercase(name), " "=>"-")

Install a new Julia kernel, where the given `options` are passed to the `julia`
executable, and the user-visible kernel name is given by `name` followed by the
Julia version.

Internally, the Jupyter name for the kernel (for the `jupyter kernelspec`
command is given by the optional keyword `specname` (which defaults to
`name`, converted to lowercase with spaces replaced by hyphens),
followed by the Julia version number.

Both the `kernelspec` command (a `Cmd` object)
and the new kernel name are returned by `installkernel`.
For example:
```
kernelspec, kernelname = installkernel("Julia O3", "-O3")
```
creates a new Julia kernel in which `julia` is launched with the `-O3`
optimization flag.  The returned `kernelspec` command will be something
like `jupyter kernelspec` (perhaps with different path), and `kernelname`
will be something like `julia-O3-0.6` (in Julia 0.6).   You could
uninstall the kernel by running e.g.
```
run(`\$kernelspec remove -f \$kernelname`)
```
"""
function installkernel(name::AbstractString, julia_options::AbstractString...;
                   specname::AbstractString = replace(lowercase(name), " "=>"-"))
    # Is IJulia being built from a debug build? If so, add "debug" to the description.
    debugdesc = ccall(:jl_is_debugbuild,Cint,())==1 ? "-debug" : ""

    # name of the Jupyter kernelspec directory to install
    spec_name = "$specname-$(VERSION.major).$(VERSION.minor)$debugdesc"

    juliakspec = joinpath(tempdir(), spec_name)
    try
        binary_name = Sys.iswindows() ? "julia.exe" : "julia"
        kernelcmd_array = String[joinpath(Sys.BINDIR,"$binary_name"), "-i",
                                 "--startup-file=yes", "--color=yes"]
        append!(kernelcmd_array, julia_options)
        ijulia_dir = get(ENV, "IJULIA_DIR", dirname(@__DIR__)) # support non-Pkg IJulia installs
        append!(kernelcmd_array, [joinpath(ijulia_dir,"src","kernel.jl"), "{connection_file}"])

        ks = Dict(
            "argv" => kernelcmd_array,
            "display_name" => name * " " * Base.VERSION_STRING * debugdesc,
            "language" => "julia",
        )

        destname = "kernel.json"
        mkpath(juliakspec)
        dest = joinpath(juliakspec, destname)

        open(dest, "w") do f
            # indent by 2 for readability of file
            write(f, JSON.json(ks, 2))
        end

        copy_config(joinpath(ijulia_dir,"deps","logo-32x32.png"), juliakspec)
        copy_config(joinpath(ijulia_dir,"deps","logo-64x64.png"), juliakspec)

        @info("Installing $name kernelspec $spec_name")

        # remove these hacks when
        # https://github.com/jupyter/notebook/issues/448 is closed and the fix
        # is widely available -- just run `$jupyter kernelspec ...` then.
        kspec_cmd = String[] # keep track of the kernelspec command used
        try
            run(`$jupyter kernelspec install --replace --user $juliakspec`)
            push!(kspec_cmd, jupyter, "kernelspec")
        catch
            @static if Sys.isunix()
                run(`$jupyter-kernelspec install --replace --user $juliakspec`)
                push!(kspec_cmd, jupyter * "-kernelspec")
            end

            # issue #363:
            @static if Sys.iswindows()
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

        return `$kspec_cmd`, spec_name
    finally
        rm(juliakspec, force=true, recursive=true)
    end
end
