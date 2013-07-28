Prototype native Julia kernel for IPython, which allows you to use the IPython
front-end interface for the Julia back-end (instead of the native Julia REPL).

Requires:
* Latest (git `master`) `ZMQ.jl`, `JSON.jl`, `REPL.jl`, and `GnuTLS.jl` packages.
* Latest (git `master` as of 24 July 2013) Julia.
* Possibly 1.0dev version of IPython (we haven't tested it with IPython 0.13)

Basic usage: First, run `julia kernel.jl` to start the Julia kernel.  This will print something like `connect ipython with --existing /path/to/profile-XXXXX.json`.   Copy this string and run IPython with `ipython console --existing /path/to/profile-XXXXX.json`.

Even better: create a file `$HOME/.ipython/profile_julia/ipython_config.py` with the contents:
```
c = get_config()
c.KernelManager.kernel_cmd = ["julia", "/...PATH.../IJulia/src/kernel.jl", "{connection_file}"]
```
(replacing `...PATH...` with the path to your `IJulia` directory).
This tells IPython how to launch the kernel itself, allowing you to simply run `ipython notebook --profile julia` or `ipython qtconsole --profile julia` in order to launch IPython's browser-notebook or Qt interface with Julia.
