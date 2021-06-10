# Installation


## Installing IJulia

First, [download Julia](http://julialang.org/downloads/) *version 0.7
or later* and run the installer.  Then run the Julia application
(double-click on it); a window with a `julia>` prompt will appear.  After ensuring that you have activated the default Julia environment, at
the prompt, type:
```julia
using Pkg
Pkg.add("IJulia")
```
to install IJulia.

This process installs a [kernel specification](https://jupyter-client.readthedocs.io/en/latest/kernels.html#kernelspecs) that tells Jupyter (or JupyterLab) etcetera
how to launch Julia.

`Pkg.add("IJulia")` does not actually install Jupyter itself.
You can install Jupyter if you want, but it can also be installed
automatically when you run `IJulia.notebook()` below.  (You
can force it to use a specific `jupyter` installation by
setting `ENV["JUPYTER"]` to the path of the `jupyter` program
before `Pkg.add`, or before running `Pkg.build("IJulia")`;
your preference is remembered on subsequent updates.


## Updating Julia and IJulia

Julia is improving rapidly, so it won't be long before you want to
update to a more recent version.  To update the packages only, keeping
Julia itself the same, just run:
```julia
Pkg.update()
```
at the Julia prompt (or in IJulia).

If you download and install a new version of Julia from the Julia web
site, you will also probably want to update the packages with
`Pkg.update()` (in case newer versions of the packages are required
for the most recent Julia).  In any case, if you install a new Julia
binary (or do anything that *changes the location of Julia* on your
computer), you *must* update the IJulia installation (to tell Jupyter
where to find the new Julia) by running
```julia
Pkg.build("IJulia")
```
at the Julia command line (**important**: not in IJulia).


## Installing additional Julia kernels

You can also install additional Julia kernels, for example, to
pass alternative command-line arguments to the `julia` executable,
by using the `IJulia.installkernel` function.  See the help for this
function (`? IJulia.installkernel` in Julia) for complete details.

For example, if you want to run Julia with all deprecation warnings
disabled, you can do:
```julia
using IJulia
installkernel("Julia nodeps", "--depwarn=no")
```
and a kernel called `Julia nodeps 0.7` (if you are using Julia 0.7)
will be installed (will show up in your main Jupyter kernel menu) that
lets you open notebooks with this flag.

You can also install kernels to run Julia with different environment
variables, for example to set [`JULIA_NUM_THREADS`](https://docs.julialang.org/en/v1/manual/environment-variables/index.html#JULIA_NUM_THREADS-1) for use with Julia [multithreading](https://docs.julialang.org/en/v1/manual/parallel-computing/#Multi-Threading-(Experimental)-1):
```
using IJulia
installkernel("Julia (4 threads)", env=Dict("JULIA_NUM_THREADS"=>"4"))
```
The `env` keyword should be a `Dict` mapping environment variables to values.

To *prevent* IJulia from installing a default kernel when the package is built, define the `IJULIA_NODEFAULTKERNEL` environment variable before adding/building IJulia.

## Low-level Information

### Using older IPython versions

While we strongly recommend using IPython version 3 or later (note that this
has nothing to do with whether you use Python version 2 or 3), we recognize
that in the short term some users may need to continue using IPython 2.x.  You
can do this by checkout out the `ipython2` branch of the IJulia package:

```julia
Pkg.checkout("IJulia", "ipython2")
Pkg.build("IJulia")
```

### Manual installation of IPython

First, you will need to install a few prerequisites:

* You need **version 3.0** or later of IPython, or version 4 or later
of Jupyter.  Note that IPython 3.0 was released in February 2015, so
if you have an older operating system you may
have to [install IPython
manually](http://ipython.org/ipython-doc/stable/install/install.html).
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
This will download IJulia and a few other prerequisites, and will set up a
Julia kernel for IPython.

If the command above returns an error, you may need to run `Pkg.update()`, then
retry it, or possibly run `Pkg.build("IJulia")` to force a rebuild.
