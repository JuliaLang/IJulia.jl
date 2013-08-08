Prototype native Julia kernel for IPython, which allows you to use the IPython
front-end interface for the Julia back-end (instead of the native Julia REPL).

Requires:
* Packages: `ZMQ.jl`, `JSON.jl`, `REPLCompletions.jl`, and `GnuTLS.jl` packages.
* Latest (recent git `master`) Julia.
* 1.0dev version of IPython

Basic usage: First, run `julia kernel.jl` to start the Julia kernel.  This will print something like `connect ipython with --existing /path/to/profile-XXXXX.json`.   Copy this string and run IPython with `ipython console --existing /path/to/profile-XXXXX.json`.

Even better, create a `julia` IPython profile:
```
$ ipython profile create julia
[ProfileCreate] WARNING | Generating default config file: u'~/.ipython/profile_julia/ipython_config.py'
[ProfileCreate] WARNING | Generating default config file: u'~/.ipython/profile_julia/ipython_qtconsole_config.py'
[ProfileCreate] WARNING | Generating default config file: u'~/.ipython/profile_julia/ipython_notebook_config.py'
```

then edit `$(ipython locate profile julia)/ipython_config.py` with the contents:
```python
c = get_config() # should already be at top of the file

c.KernelManager.kernel_cmd = ["julia", "/...PATH.../IJulia/src/kernel.jl", "{connection_file}"]
```
(replacing `...PATH...` with the path to your `IJulia` directory).
This tells IPython how to launch the kernel itself, allowing you to simply run `ipython notebook --profile julia` or `ipython qtconsole --profile julia` in order to launch IPython's browser-notebook or Qt interface with Julia.

If you want to use the IPython QtConsole with Julia, edit `$(ipython locate profile julia)/ipython_qtconsole_config.py` with the contents:
```python
c.IPythonWidget.execute_on_complete_input = False
```

which prevents IPython from attempting to execute when it thinks there is complete Python input.
Shift-Enter is required to submit each execution.

Please refer to [IPython documentation](http://ipython.org/documentation.html) for other config options of IPython frontend themselves.
We, for example, strongly recommend to run Notebook [over https][1] with [password][2] when on a public port, or even localhost if your machine have several users.

[1]: http://ipython.org/ipython-doc/stable/interactive/htmlnotebook.html#quick-howto-running-a-public-notebook-server]
[2]: http://ipython.org/ipython-doc/stable/interactive/htmlnotebook.html#security
