# Code to launch and interact with Jupyter, not via messaging protocol
##################################################################

include(joinpath("..","deps","kspec.jl"))

##################################################################

import Conda

isyes(s) = isempty(s) || lowercase(strip(s)) in ("y", "yes")

function find_jupyter_subcommand(subcommand::AbstractString)
    jupyter = JUPYTER
    if jupyter == "jupyter" || jupyter == "jupyter.exe" # look in PATH
        jupyter = Sys.which(exe("jupyter"))
        if jupyter === nothing
            jupyter = joinpath(Conda.SCRIPTDIR, exe("jupyter"))
        end
    end
    isconda = dirname(jupyter) == abspath(Conda.SCRIPTDIR)
    if !Sys.isexecutable(jupyter)
        if isconda && isyes(Base.prompt("install Jupyter via Conda, y/n? [y]"))
           Conda.add(subcommand == "lab" ? "jupyterlab" : "jupyter")
        else
            error("$jupyter is not installed, cannot run $subcommand")
        end
    end

    cmd = `$jupyter $subcommand`

    # fails in Windows if jupyter directory is not in PATH (jupyter/jupyter_core#62)
    pathsep = Sys.iswindows() ? ';' : ':'
    withenv("PATH" => dirname(jupyter) * pathsep * get(ENV, "PATH", "")) do
        if isconda
            # sets PATH and other environment variables for Julia's Conda environment
            cmd = Conda._set_conda_env(cmd)
        else
            setenv(cmd, ENV)
        end
    end

    return cmd
end

##################################################################

function launch(cmd, dir, detached)
    @info("running $cmd")
    if Sys.isapple() # issue #551 workaround, remove after macOS 10.12.6 release?
        withenv("BROWSER"=>"open") do
            p = run(Cmd(cmd, detach=true, dir=dir); wait=false)
        end
    else
        p = run(Cmd(cmd, detach=true, dir=dir); wait=false)
    end
    if !detached
        try
            wait(p)
        catch e
            if isa(e, InterruptException)
                kill(p, 2) # SIGINT
            else
                kill(p) # SIGTERM
                rethrow()
            end
        end
    end
    return p
end

"""
    notebook(; dir=homedir(), detached=false)

The `notebook()` function launches the Jupyter notebook, and is
equivalent to running `jupyter notebook` at the operating-system
command-line.    The advantage of launching the notebook from Julia
is that, depending on how Jupyter was installed, the user may not
know where to find the `jupyter` executable.

By default, the notebook server is launched in the user's home directory,
but this location can be changed by passing the desired path in the
`dir` keyword argument.  e.g. `notebook(dir=pwd())` to use the current
directory.

By default, `notebook()` does not return; you must hit ctrl-c
or quit Julia to interrupt it, which halts Jupyter.  So, you
must leave the Julia terminal open for as long as you want to
run Jupyter.  Alternatively, if you run `notebook(detached=true)`,
the `jupyter notebook` will launch in the background, and will
continue running even after you quit Julia.  (The only way to
stop Jupyter will then be to kill it in your operating system's
process manager.)
"""
function notebook(; dir=homedir(), detached=false)
    inited && error("IJulia is already running")
    notebook = find_jupyter_subcommand("notebook")
    return launch(notebook, dir, detached)
end

"""
    jupyterlab(; dir=homedir(), detached=false)

Similar to `IJulia.notebook()` but launches JupyterLab instead
of the Jupyter notebook.
"""
function jupyterlab(; dir=homedir(), detached=false)
    inited && error("IJulia is already running")
    lab = find_jupyter_subcommand("lab")
    jupyter = first(lab)
    if dirname(jupyter) == abspath(Conda.SCRIPTDIR) &&
       !Sys.isexecutable(exe(jupyter, "-lab")) &&
       isyes(Base.prompt("install JupyterLab via Conda, y/n? [y]"))
        Conda.add("jupyterlab")
    end
    return launch(lab, dir, detached)
end

function qtconsole()
    qtconsole = find_jupyter_subcommand("qtconsole")
    if inited
        run(`$qtconsole --existing $connection_file`; wait=false)
    else
        error("IJulia is not running. qtconsole must be called from an IJulia session.")
    end
end
