# Troubleshooting

Jupyter notebooks run code by connecting to a [kernel](https://docs.jupyter.org/en/stable/projects/kernels.html). That's exactly what the `IJulia` package provides. Jupyter knows about available kernels through [kernel specs](https://jupyter-client.readthedocs.io/en/stable/kernels.html#kernel-specs), which are `kernel.json` files inside [Jupyter's data paths](https://docs.jupyter.org/en/stable/use/jupyter-directories.html#data-files). You can list the available kernel specs on the command line with

```sh
jupyter kernelspec list
```

Or, explore the data directory relevant to your system, e.g., `~/.local/share/jupyter/kernels`.

Make sure that you can find a Julia kernel. If you can't, run [`IJulia.installkernel`](@ref), e.g., as `import IJulia; IJulia.installkernel("Julia", "--project=@.")` in the Julia REPL.

The `kernel.json` file for the `IJulia` kernel should look something like this:


```json
{
  "display_name": "Julia 1.11.5",
  "argv": [
    "/home/user/.julia/juliaup/julia-1.11.5+0.x64.linux.gnu/bin/julia",
    "-i",
    "--color=yes",
    "--project=@.",
    "-e",
    "import IJulia; IJulia.run_kernel()",
    "{connection_file}"
  ],
  "language": "julia",
  "env": {},
  "interrupt_mode": "signal"
}
```

Note the reference to the `julia` executable in line 4, and the call to `IJulia.run_kernel()` in line 9. There isn't much magical about kernels. All that happens when Jupyter starts the kernel based on a specific kernel spec is that it runs the process given by `argv`. That is, it runs `julia` with the given command line arguments. It then expects that it can talk to the resulting process with a specific [messaging protocol](https://jupyter-client.readthedocs.io/en/latest/messaging.html#messaging). Here, the code in `run_kernel()` exposes the implementation of that protocol.


## Kernel connection failure tips

Fundamentally, if the `IJulia` kernel fails to connect, it is most likely due to one of the following two issues:

* The `julia` executable no longer exists (maybe you updated your installed Julia versions).
* The environment that the `julia` executable runs in does not have the `IJulia` package installed. This is a common error. In general, the `IJulia` package should be installed in the base environment of your Julia installation (what you get when you type `] activate` into the REPL without any further options, or when you simply start the Julia REPL without any options). Note that the `--project=@.` option in the above `kernel.json` falls back to the base environment, so it should generally be safe. If you like to use [shared environments](https://pkgdocs.julialang.org/v1/environments/#Shared-environments), you may want to have a `--project` flag that references that shared environment, and make sure that `IJulia` is installed in that environment. Also make sure that the environment is instantiated.

You can edit the `kernel.json` file to fix any issues. Or, delete the entire folder containing the `kernel.json` file to start from scratch. This is entirely safe to do, or you could also use `jupyter kernelspec uninstall <name>` from the command line, see `jupyter kernelspec --help`. After deleting an old kernel, simply create a new one, using [`IJulia.installkernel`](@ref) from the Julia REPL.

For further insight into kernel connection issues, look at the error messages emitted by Jupyter. If you started `jupyter lab` / `jupyter notebook` in the terminal, messages will be printed there, not in the web interface that you access via the browser. For more details, you can pass the `--debug` command line flag to `jupyter`. If you started Jupyter via `IJulia.jupyterlab()` / `IJulia.notebook()`, you must also pass `verbose=true` to see any of the output emitted by `jupyter`, including error messages about connection failures; cf. [Debugging IJulia problems](@ref), below.



## General troubleshooting tips

* If you ran into a problem with the above steps, after fixing the
  problem you can type `Pkg.build()` to try to rerun the install scripts.
* If you tried it a while ago, try running `Pkg.update()` and try again:
  this will fetch the latest versions of the Julia packages in case
  the problem you saw was fixed.  Run `Pkg.build("IJulia")` if your Julia version may have changed.  If this doesn't work, you could try just deleting the whole `.julia/conda` directory in your home directory (on Windows, it is called `Users\USERNAME\.julia\conda` in your home directory) via `rm(abspath(first(DEPOT_PATH), "conda"),recursive=true)` in Julia and re-adding the packages.
* On MacOS, you currently need MacOS 10.7 or later; [MacOS 10.6 doesn't work](https://github.com/JuliaLang/julia/issues/4215) (unless you compile Julia yourself, from source code).
* Internet Explorer 8 (the default in Windows 7) or 9 don't work with the notebook; use Firefox (6 or later) or Chrome (13 or later).  Internet Explorer 10 in Windows 8 works (albeit with a few rendering glitches), but Chrome or Firefox is better.
* If the notebook opens up, but doesn't respond (the input label is `In[*]` indefinitely), try creating a new Python notebook (not Julia) from the `New` button in the Jupyter dashboard, to see if `1+1` works in Python.  If it is the same problem, then probably you have a [firewall running](https://github.com/ipython/ipython/issues/2499) on your machine (this is common on Windows) and you need to disable the firewall or at least to allow the IP address 127.0.0.1.  (For the [Sophos](https://en.wikipedia.org/wiki/Sophos) endpoint security software, go to "Configure Anti-Virus and HIPS", select "Authorization" and then "Websites", and add 127.0.0.1 to "Authorized websites"; finally, restart your computer.) If the Python test works, then IJulia may not be installed in the global or default environment and you may need to install a custom Julia kernel that uses your required `Project.toml` (see [Julia projects](@ref)).
* Try running `jupyter --version` and make sure that it prints `3.0.0` or larger; earlier versions of IPython are no longer supported by IJulia.
* You can try setting `ENV["JUPYTER"]=""; Pkg.build("IJulia")` to force IJulia to go back to its own Conda-based Jupyter version (if you previously tried a different `jupyter`).


## Debugging IJulia problems

If IJulia is crashing (e.g. it gives you a "kernel appears to have
died" message), you can modify it to print more descriptive error
messages to the terminal by doing:

```julia
ENV["IJULIA_DEBUG"]=true
Pkg.build("IJulia")
```

Restart the notebook and look for the error message when IJulia dies.
(This changes IJulia to default to `verbose = true` mode, and sets
`capture_stderr = false`, hopefully sending a bunch of debugging to
the terminal where you launched `jupyter`).

When you are done, set `ENV["IJULIA_DEBUG"]=false` and re-run
`Pkg.build("IJulia")` to turn off the debugging output.
