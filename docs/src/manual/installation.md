# Installation

## Installing IJulia

1. [Go to the Julia Install page.](https://julialang.org/install/)
2. Follow the instructions recommended to install Julia and the `juliaup` tool.
3. Run the Julia application by double-clicking on the icon or running
   `julia` in a terminal. This will open the Julia REPL and a window with
   a `julia>` prompt will appear.
4. At the `julia>` prompt, install IJulia by typing:

   ```julia
   using Pkg
   Pkg.add("IJulia")
   ```

!!! info
    The Julia kernel will be automatically installed the first time you run
    [`IJulia.notebook()`](@ref) or [`IJulia.jupyterlab()`](@ref), or you can
    install it manually by running [`IJulia.installkernel()`](@ref). The kernel
    specification contains the instructions for launching a Julia kernel that a
    notebook frontend (Jupyter, JupyterLab, nteract) can use.

    IJulia respects the standard
    [`JUPYTER_DATA_DIR`](https://docs.jupyter.org/en/stable/use/jupyter-directories.html#data-files)
    environment variable, so you can set that before installing the kernel if you want
    it to be installed in a specific location.

!!! warning
    The command, `Pkg.add("IJulia")`, does not install Jupyter
    Notebook itself.

    You can install Jupyter Notebook by following the Notebook's
    installation instructions if you want. Conveniently, Jupyter
    Notebook can also be installed automatically when you run
    `IJulia.notebook()`.
    See [Running the Julia notebook](running.md#Running-the-IJulia-Notebook).

    You can direct `IJulia.notebook()` to use a specific Jupyter
    installation by passing the path directly to `IJulia.update_jupyter_path()`,
    or by setting `ENV["JUPYTER"]` before calling it. This preference will be
    remembered for subsequent updates. For example:
    ```julia
    # Option 1: Pass path directly
    IJulia.update_jupyter_path("/usr/local/bin/jupyter")

    # Option 2: Set environment variable
    ENV["JUPYTER"] = "/usr/local/bin/jupyter"
    IJulia.update_jupyter_path()
    ```

## Updating Julia and IJulia

Julia is improving rapidly, so it won't be long before you want to
update your packages or Julia to a more recent version.

### Update packages

To update the packages only and keep the same Julia version, run
at the Julia prompt (or in IJulia):

```julia
Pkg.update()
```

### Update Julia and packages

If you download and install a new version of Julia from the Julia web
site, you will also probably want to update the packages with
`Pkg.update()` (in case newer versions of the packages are required
for the most recent Julia). If you're using juliaup to manage Julia, then for
every Julia *minor release* (1.11, 1.12, etc) you will need to explicitly update
the IJulia installation to tell Jupyter where to find the new Julia version:
```julia
using IJulia
IJulia.installkernel()
```

This is because IJulia creates default kernels for every minor version if it
detects that juliaup is used.

If you are not using juliaup to manage Julia, then you *must* update the IJulia
installation every time you install a new Julia binary (or do anything that
*changes the location of Julia* on your computer).


## Installing and customizing kernels

You may find it helpful to run multiple Julia kernels to support different Julia
executable versions and/or environment settings.

You can install one or more custom Julia kernels by using the
[`IJulia.installkernel()`](@ref) function. For example, if you want to run Julia
with all deprecation warnings disabled, you can create a custom IJulia kernel:

```julia
using IJulia
installkernel("Julia nodeps", "--depwarn=no")
```
and a kernel called `Julia nodeps 0.7` (if you are using Julia 0.7)
will be installed (will show up in your main Jupyter kernel menu) that
lets you open notebooks with this flag. Note that the default kernel
that IJulia installs passes the `--project=@.` option to Julia, if you
want to preserve this behaviour for custom kernels make sure to pass it
explicitly to [`IJulia.installkernel`](@ref):
```julia
installkernel("Julia nodeps", "--depwarn=no", "--project=@.")
```

You can also install kernels to run Julia with different environment
variables, for example to set
[`JULIA_NUM_THREADS`](https://docs.julialang.org/en/v1/manual/environment-variables/index.html#JULIA_NUM_THREADS-1)
for use with Julia
[multithreading](https://docs.julialang.org/en/v1/manual/parallel-computing/#Multi-Threading-(Experimental)-1):
```julia
using IJulia
installkernel("Julia (4 threads)", env=Dict("JULIA_NUM_THREADS"=>"4"))
```

The `env` keyword should be a `Dict` which maps environment variables to values.

If you want to disable automatic installation of the default kernel (for example, if
you only want custom kernels), set the `IJULIA_NODEFAULTKERNEL` environment variable:

```julia
using IJulia

# Disable auto-installation of the default kernel
ENV["IJULIA_NODEFAULTKERNEL"] = "true"

# Install custom kernels
IJulia.installkernel("Julia O3", "-O3")
IJulia.installkernel("Julia (4 threads)", env=Dict("JULIA_NUM_THREADS"=>"4"))
```

With `IJULIA_NODEFAULTKERNEL` set, [`IJulia.notebook()`](@ref) will not
auto-install the default kernel. You can still manually install the default
kernel by calling [`IJulia.installkernel()`](@ref) without arguments.

## Low-level IPython Installations

We recommend using IPython 7.15 or later as well as Python 3.

### Manual installation of IPython

First, you will need to install a few prerequisites:

* You need **version 3.0** or later of IPython, or version 4 or later
  of Jupyter.  Note that IPython 3.0 was released in February 2015, so
  if you have an older operating system you may have to
  [install IPython manually](http://ipython.org/ipython-doc/stable/install/install.html).
  On Mac and Windows systems, it is currently easiest to use the
  [Anaconda Python](http://continuum.io/downloads) installer.

* To use the [IPython notebook](http://ipython.org/notebook.html) interface, which runs in your web
  browser and provides a rich multimedia environment, you will need
  to install the [jsonschema](https://pypi.python.org/pypi/jsonschema), [Jinja2](http://jinja.pocoo.org/docs/), [Tornado](http://www.tornadoweb.org/en/stable/),
  and [pyzmq](https://github.com/zeromq/pyzmq) (requires `apt-get install libzmq-dev` and possibly `pip install --upgrade --force-reinstall pyzmq` on Ubuntu if you are using `pip`) Python packages.
  (Given the [pip](http://www.pip-installer.org/en/latest/) installer, `pip install jsonschema jinja2 tornado pyzmq`
  should normally be sufficient.)  These should have been automatically installed if you installed IPython itself
  [via `easy_install` or `pip`](http://ipython.org/ipython-doc/stable/install/install.html#quickstart).

* To use the [IPython qtconsole](http://ipython.org/ipython-doc/dev/interactive/qtconsole.html) interface,
  you will need to install [PyQt4](http://www.riverbankcomputing.com/software/pyqt/download) or
  [PySide](http://qt-project.org/wiki/Category:LanguageBindings::PySide).

* You need Julia version 0.7 or later.

Once IPython 3.0+ and Julia 0.7+ are installed, you can install IJulia from a Julia console by typing:

```julia
Pkg.add("IJulia")
```

This will download IJulia and a few other prerequisites. The Julia kernel will be
automatically installed the first time you run [`IJulia.notebook()`](@ref) or
[`IJulia.jupyterlab()`](@ref).

If the command above returns an error, you may need to run `Pkg.update()`, then
retry it. If you need to reinstall the kernel, run
[`IJulia.installkernel()`](@ref).
