#######################################################################
# Install Jupyter kernel-spec file.

copy_config(src, dest) = Compat.cp(src, joinpath(dest, basename(src)), force=true)

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
        binary_name = Compat.Sys.iswindows() ? "julia.exe" : "julia"
        kernelcmd_array = String[joinpath(Compat.Sys.BINDIR,"$binary_name"), "-i",
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

        Compat.@info("Installing $name kernelspec $spec_name")

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

        return `$kspec_cmd`, spec_name
    finally
        rm(juliakspec, force=true, recursive=true)
    end
end


"""
    install_kernel(name,
                   julia_options...;
                   kernel_id = "auto",
                   jupyter_options = String[])

Install a new Julia kernel to Jupyter. Use the String `name` as display name
and the String `kernel_id` as kernel identifier.

If the id provided equals the String "auto", the id is derived from the name.
It has then spaces replaced with underscores and major and minor version
appended. If IJulia was built from debug build, a "-debug" tag suffix is added.

The parameter `julia_options` are passed to the `julia` executable during kernel
startup.

The function returns tuple of a Vector{String} with the validated `jupyter kernelspec`
command and the kernel id as String.

Example:

```
# install kernel
cmd, id = install_kernel("Julia O3", "-O3")

# list kernel
run(`\$cmd list`)

# uninstall kernel
run(`\$cmd remove -f \$id`)
```
"""
function install_kernel(
                        name::String,
                        julia_options::String...;
                        kernel_id::String = "auto",
                        jupyter_options::Vector{String} = String[]
                       )

    # determine if IJulia is being built from a debug build
    tag_debug = ccall(:jl_is_debugbuild,Cint,())==1 ? "-debug" : ""

    # configure kernel id
    if kernel_id == "auto"
        kernel_id = replace(lowercase(name), " " => "_")
        kernel_id = "$kernel_id-$(VERSION.major).$(VERSION.minor)$tag_debug"
    else
        kernel_id = replace(kernel_id, " " => "_")
    end

    # configure path
    kernel_path = joinpath(tempdir(), kernel_id)
    # configure jupyter options
    prepend!(jupyter_options, ["install"])
    push!(jupyter_options, kernel_path)

    # export and install
    try
        binary_name = Compat.Sys.iswindows() ? "julia.exe" : "julia"
        julia_command = [joinpath(Compat.Sys.BINDIR,"$binary_name"),
                         "-i", "--startup-file=yes", "--color=yes"]
        append!(julia_command, julia_options)
        ijulia_dir = get(ENV, "IJULIA_DIR", dirname(@__DIR__)) # support non-Pkg IJulia installs
        append!(julia_command, [joinpath(ijulia_dir, "src", "kernel.jl"), "{connection_file}"])
        kernel_config = Dict(
            "argv" => julia_command,
            "display_name" => name,
            "language" => "julia",
        )
        mkpath(kernel_path)
        open(joinpath(kernel_path, "kernel.json"), "w") do f
            write(f, JSON.json(kernel_config, 2))
        end
        copy_config(joinpath(ijulia_dir, "deps", "logo-32x32.png"), kernel_path)
        copy_config(joinpath(ijulia_dir, "deps", "logo-64x64.png"), kernel_path)
        Compat.@info("Installing kernel '$name' with id '$kernel_id'")
        jupyter_command = [jupyter, "kernelspec"]
        # issue #448
        try
            run(Cmd(vcat(jupyter_command, jupyter_options)))
        catch
            @static if Compat.Sys.isunix()
                jupyter_command = ["$jupyter-kernelspec"]
                run(Cmd(vcat(jupyter_command, jupyter_options)))
            end
            # issue #363
            @static if Compat.Sys.iswindows()
                jupyter_dir = dirname(jupyter)
                if jupyter_dir == abspath(Conda.SCRIPTDIR)
                    jupyter_exe = "$jupyter-kernelspec"
                    if isfile(jupyter_exe * "-script.py")
                        jupyter_exe *= "-script.py"
                    end
                    python = abspath(Conda.PYTHONDIR, "python.exe")
                    jupyter_command = [python, jupyter_exe]
                else
                    jupyter_exe = joinpath(jupyter_dir, "jupyter-kernelspec.exe")
                    if isfile(jupyter_exe)
                        jupyter_command = [jupyter_exe]
                    else
                        jupyter_exe = readchomp(`where.exe $jupyter-kernelspec`)
                        # jupyter-kernelspec should start with "#!/path/to/python":
                        python = strip(chomp(open(readline, jupyter_exe, "r"))[3:end])
                        # strip quotes, if any
                        if python[1] == python[end] == '"'
                            python = python[2:end-1]
                        end
                        jupyter_command = [python, jupyter_exe]
                    end
                end
                run(Cmd(vcat(jupyter_command, jupyter_options)))
            end
        end
        return Cmd(jupyter_command), kernel_id
    finally
        rm(kernel_path, force = true, recursive = true)
    end
end
