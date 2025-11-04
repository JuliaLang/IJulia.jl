# Running IJulia


## Command-Line Launcher

Starting with Julia 1.12, you can launch IJulia directly from the command line using the `ijulia` command. First, you need to install the app entry point (see [Julia app documentation](https://pkgdocs.julialang.org/v1/apps/)) by running in the Julia REPL:

```julia
pkg> app add IJulia
```

You may need to add `~/.julia/bin` to your PATH if it's not already there.

Then you can use the `ijulia` command from your terminal:

```bash
ijulia
```

This provides a convenient way to launch Jupyter without starting a Julia REPL session first. The launcher supports the following options:

- `ijulia` or `ijulia notebook` - Launch Jupyter Notebook (default)
- `ijulia lab` - Launch JupyterLab
- `--dir=PATH` - Launch in the specified directory (default: home directory)
- `--port=N` - Open on the specified port number
- `--detached` - Run in detached mode (continues after Julia exits)
- `--verbose` - Enable verbose output from Jupyter
- `--help, -h` - Show help message

Any additional arguments are passed directly to the jupyter command.

**Examples:**
```bash
# Launch notebook in a specific directory
ijulia --dir=/path/to/project

# Launch JupyterLab on a specific port
ijulia lab --port=8888 --detached

# Pass additional arguments to Jupyter
ijulia --no-browser
```


## Running the IJulia Notebook

If you are comfortable managing your own Python/Jupyter installation, you can just run `jupyter notebook` yourself in a terminal.   To simplify installation, however, you can alternatively type the following in Julia, at the `julia>` prompt:
```julia
using IJulia
notebook()
```
to launch the IJulia notebook in your browser.

The first time you run `notebook()`, it will prompt you for whether it should
install Jupyter.  Hit enter to have it use the
[Conda.jl](https://github.com/Luthaf/Conda.jl) package to install a minimal
Python+Jupyter distribution (via
[Miniconda](https://www.anaconda.com/docs/getting-started/miniconda/install#quickstart-install-instructions))
that is private to Julia (not in your `PATH`).  On Linux, it defaults to looking
for `jupyter` in your `PATH` first, and only asks to installs the Conda Jupyter
if that fails; you can force `notebook()` to use an existing environment on
Linux by setting `ENV["JUPYTER"] = "/path/to/jupyter"` during the installation of
IJulia (see above).  (In a Debian or Ubuntu GNU/Linux system, install the
package `jupyter-client` to install the system `jupyter`.)

You can
use `notebook(detached=true)` to launch a notebook server
in the background that will persist even when you quit Julia.
This is also useful if you want to keep using the current Julia
session instead of opening a new one.

```julia
using IJulia; notebook(detached=true)
```

By default, the notebook "dashboard" opens in your
home directory (`homedir()`), but you can open the dashboard
in a different directory with `notebook(dir="/some/path")`.

Alternatively, you can run
```
jupyter notebook
```
from the command line (the
[Terminal](https://en.wikipedia.org/wiki/Terminal_%28OS_X%29) program
in MacOS or the [Command
Prompt](https://en.wikipedia.org/wiki/Command_Prompt) in Windows).
Note that if you installed `jupyter` via automated Miniconda installer
in `Pkg.add`, above, then `jupyter` may not be in your `PATH`; type
`import Conda; Conda.SCRIPTDIR` in Julia to find out where Conda
installed `jupyter`.

A "dashboard" window like this should open in your web browser.  Click
on the *New* button and choose the *Julia* option to start a new
"notebook".  A notebook will combine code, computed results, formatted
text, and images, just as in IPython.  You can enter multiline input
cells and execute them with *shift-ENTER*, and the menu items are
mostly self-explanatory.  Refer to [the Jupyter notebook
documentation](https://jupyter-notebook.readthedocs.io/en/stable/) for more
information, and see also the "Help" menu in the notebook itself.

Given an IJulia notebook file, you can execute its code within any
other Julia file (including another notebook) via the [NBInclude](https://github.com/stevengj/NBInclude.jl) package.


## Running the JupyterLab

Instead of running the classic notebook interface, you can use the IDE-like JupyterLab. If you are comfortable managing your own JupyterLab installation, you can just run `jupyter lab` yourself in a terminal.   To simplify installation, however, you can alternatively type the following in Julia, at the `julia>` prompt:

```julia
using IJulia
jupyterlab()
```

Like `notebook()`, above, this will install JupyterLab via Conda if it is
not installed already.   `jupyterlab()` also supports `detached` and `dir` keyword options similar to `notebook()`.


## Running nteract

The [nteract Desktop](https://nteract.io/) is an application that lets you work with notebooks without a Python installation. First, install IJulia (but do not run `notebook()` unless you want a Python installation) and then nteract.


## Other IPython interfaces

Most people will use the notebook (browser-based) interface, but you
can also use the IPython
[qtconsole](http://ipython.org/ipython-doc/dev/interactive/qtconsole.html)
or IPython terminal interfaces by running `ipython qtconsole --kernel
julia-0.7` or `ipython console --kernel julia-0.7`, respectively.
(Replace `0.7` with whatever major Julia version you are using.)
