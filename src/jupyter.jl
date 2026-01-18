# Code to launch and interact with Jupyter, not via messaging protocol
##################################################################

isyes(s) = isempty(s) || lowercase(strip(s)) in ("y", "yes")

"""
    find_jupyter_subcommand(subcommand::AbstractString, port::Union{Nothing,Int}=nothing)

Return a `Cmd` for the program `subcommand`.
"""
function find_jupyter_subcommand(subcommand::AbstractString, port::Union{Nothing,Int}=nothing)
    global JUPYTER
    if isempty(JUPYTER)
        JUPYTER = determine_jupyter_path()
    end
    jupyter = JUPYTER
    scriptdir = get_Conda() do Conda
        Conda.SCRIPTDIR
    end
    if jupyter == "jupyter" || jupyter == "jupyter.exe" # look in PATH
        jupyter = Sys.which(exe("jupyter"))
        if jupyter === nothing
            jupyter = joinpath(scriptdir, exe("jupyter"))
        end
    end
    isconda = dirname(jupyter) == abspath(scriptdir)
    port_flag = !isnothing(port) ? `--port=$(port)` : ``
    cmd = `$(jupyter) $(subcommand) $(port_flag)`

    # fails in Windows if jupyter directory is not in PATH (jupyter/jupyter_core#62)
    pathsep = Sys.iswindows() ? ';' : ':'
    withenv("PATH" => dirname(jupyter) * pathsep * get(ENV, "PATH", "")) do
        if isconda
            # sets PATH and other environment variables for Julia's Conda environment
            cmd = get_Conda() do Conda
                Conda._set_conda_env(cmd)
            end
        else
            setenv(cmd, ENV)
        end
    end

    return cmd
end

##################################################################

# Check if the default Julia kernel is installed for the current Julia version.
# If not (and IJULIA_NODEFAULTKERNEL is not set), automatically install it.
function maybe_install_default_kernel()
    if haskey(ENV, "IJULIA_NODEFAULTKERNEL")
        return
    end

    # Check if the default kernel for the current version exists
    specname = kernelspec_name("Julia")
    kernel_path = joinpath(kerneldir(), specname)

    if !isdir(kernel_path)
        # No default kernel found, install it
        debugdesc = ccall(:jl_is_debugbuild,Cint,())==1 ? "-debug" : ""
        @info """
        No default Julia kernel found for Julia $(VERSION.major).$(VERSION.minor)$(debugdesc).
        Installing kernel automatically. You can reinstall or update the kernel
        anytime by running: IJulia.installkernel()

        To disable this auto-installation, set the environment variable:
            ENV["IJULIA_NODEFAULTKERNEL"] = "true"
        """
        installkernel()
    end
end

##################################################################

"""
    launch(cmd, dir, detached, verbose)

Run `cmd` in `dir`. If `detached` is `false` it will not wait for the command to
finish. If `verbose` is `true` then the stdout/stderr from the `cmd` process
will be echoed to stdout/stderr.
"""
function launch(cmd, args, dir, detached, verbose)
    cmd = `$cmd $args`
    @info("running $cmd")

    cmd = Cmd(cmd, detach=true, dir=dir)
    if verbose
        cmd = pipeline(cmd; stdout, stderr)
    end
    p = run(cmd; wait=false)

    if !detached
        try
            wait(p)
        catch e
            # SIGTERM will shutdown the server cleanly in a non-interactive
            # session. SIGINT will just raise an internal exception and not do
            # any cleanup if the session isn't interactive (i.e. no stdin or
            # TTY).
            kill(p)

            if isa(e, InterruptException)
                wait(p)
            else
                rethrow()
            end
        end
    end
    return p
end

function run_subcommand(name, package_name, port, args...)
    inited && error("IJulia is already running")
    maybe_install_default_kernel()
    subcmd = find_jupyter_subcommand(name, port)
    jupyter = first(subcmd)
    scriptdir = get_Conda() do Conda
        Conda.SCRIPTDIR
    end


    if dirname(jupyter) == abspath(scriptdir) && !Sys.isexecutable(exe(jupyter, "-$(name)"))
        if isyes(Base.prompt("install $(package_name) via Conda, y/n? [y]"))
            get_Conda() do Conda
                Conda.add(package_name)
            end
        else
            error("Cannot run $(package_name), it is not installed")
        end
    end
    return launch(subcmd, args...)
end

"""
    notebook(args=``; dir=homedir(), detached=false, port::Union{Nothing,Int}=nothing, verbose=ijulia_debug())

The `notebook()` function launches the Jupyter notebook, and is
equivalent to running `jupyter notebook` at the operating-system
command-line.    The advantage of launching the notebook from Julia
is that, depending on how Jupyter was installed, the user may not
know where to find the `jupyter` executable.

Extra arguments can be passed with the `args` argument,
e.g. ```notebook(`--help`; verbose=true)``` to see the command help. By default,
the notebook server is launched in the user's home directory, but this location
can be changed by passing the desired path in the `dir` keyword argument.
e.g. `notebook(dir=pwd())` to use the current directory.

By default, `notebook()` does not return; you must hit ctrl-c
or quit Julia to interrupt it, which halts Jupyter.  So, you
must leave the Julia terminal open for as long as you want to
run Jupyter.  Alternatively, if you run `notebook(detached=true)`,
the `jupyter notebook` will launch in the background, and will
continue running even after you quit Julia.  (The only way to
stop Jupyter will then be to kill it in your operating system's
process manager.)

When the optional keyword `port` is not `nothing`, open the notebook on the
given port number.

If `verbose=true` then the stdout/stderr from Jupyter will be echoed to the
terminal. By default, this is enabled when `ENV["IJULIA_DEBUG"]` is set.
Try enabling this if you're having problems connecting to a kernel to
see if there's any useful error messages from Jupyter.

For launching a JupyterLab instance, see [`IJulia.jupyterlab()`](@ref).
"""
function notebook(args=``; dir=homedir(), detached=false, port::Union{Nothing,Int}=nothing, verbose=ijulia_debug())
    run_subcommand("notebook", "jupyter", port, args, dir, detached, verbose)
end

"""
    jupyterlab(args=``; dir=homedir(), detached=false, port::Union{Nothing,Int}=nothing, verbose=ijulia_debug())

Similar to [`IJulia.notebook()`](@ref) but launches JupyterLab instead
of the Jupyter notebook.
"""
function jupyterlab(args=``; dir=homedir(), detached=false, port::Union{Nothing,Int}=nothing, verbose=ijulia_debug())
    run_subcommand("lab", "jupyterlab", port, args, dir, detached, verbose)
end

"""
    nbclassic(args=``; dir=homedir(), detached=false, port::Union{Nothing,Int}=nothing, verbose=ijulia_debug())

Similar to [`IJulia.notebook()`](@ref) but launches the v6
[nbclassic](https://nbclassic.readthedocs.io) notebook instead of the v7
notebook.
"""
function nbclassic(args=``; dir=homedir(), detached=false, port::Union{Nothing,Int}=nothing, verbose=ijulia_debug())
    run_subcommand("nbclassic", "nbclassic", port, args, dir, detached, verbose)
end

"""
    qtconsole()

Launches [qtconsole](https://qtconsole.readthedocs.io) for the current
kernel. IJulia must be initialized already.
"""
function qtconsole(kernel=_default_kernel)
    if isnothing(kernel)
        error("IJulia has not been started, cannot run qtconsole")
    end

    qtconsole = find_jupyter_subcommand("qtconsole")
    if inited
        run(`$qtconsole --existing $(kernel.connection_file)`; wait=false)
    else
        error("IJulia is not running. qtconsole must be called from an IJulia session.")
    end
end
