<div align="center"><img src="deps/ijulialogo.png" alt="IJulia logo" width="150"/></div>

[![Build Status](https://api.travis-ci.org/JuliaLang/IJulia.jl.svg)](https://travis-ci.org/JuliaLang/IJulia.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/aaw818ykpducu6ue?svg=true)](https://ci.appveyor.com/project/StevenGJohnson/ijulia-jl)

# IJulia

**IJulia** is a [Julia-language](http://julialang.org/) backend
combined with the [Jupyter](http://jupyter.org/) interactive
environment (also used by [IPython](http://ipython.org/)).  This
combination allows you to interact with the Julia language using
Jupyter/IPython's powerful [graphical
notebook](http://ipython.org/notebook.html), which combines code,
formatted text, math, and multimedia in a single document.

(IJulia notebooks can also be re-used in other Julia code via
the [NBInclude](https://github.com/stevengj/NBInclude.jl) package.)

## Installation

First, [download Julia](http://julialang.org/downloads/) *version 0.4
or later* and run the installer.  Then run the Julia application
(double-click on it); a window with a `julia>` prompt will appear.  At
the prompt, type:
```
Pkg.add("IJulia")
```
to install IJulia.

The `Pkg.add` process will look for a program named `jupyter` or
`ipython` (version 3 or later) in your `PATH`.  If it doesn't find
one, it will use the [Conda.jl](https://github.com/Luthaf/Conda.jl)
package to install a minimal Python+Jupyter distribution (via
[Miniconda](http://conda.pydata.org/docs/install/quick.html)) that is
private to Julia (not in your `PATH`).  You can use the `Conda` Julia
package to install more Python packages, and `import Conda` to
print the `Conda.SCRIPTDIR` directory where `jupyter` was installed.

Alternatively, you can [install
Jupyter](http://jupyter.readthedocs.org/en/latest/install.html) (or
IPython 3 or later) yourself *before* adding the IJulia package.  The
simplest way to do this on Mac and Windows is by [downloading the
Anaconda package](http://continuum.io/downloads) and running its
installer.  (Do *not* use Enthought Canopy/EPD.)  On Windows, the
Anaconda installer window gives options *Add Anaconda to the System
Path* and also *Register Anaconda as default Python version of the
system*.  Be sure to **check these boxes**.

If you want `Pkg.add` to use a specific path for `jupyter` on your
system (not the defaults above), you can do so by setting the
`JUPYTER` environment variable before running `Pkg.add("IJulia")`.  To
force IJulia to use its own Miniconda installation, just set `JUPYTER`
to the empty string, e.g. set `ENV["JUPYTER"] = ""` in Julia.  You can
run `Pkg.build("IJulia")` to re-run the installation process if
needed.

On subsequent builds (e.g. when IJulia is updated via `Pkg.update`),
it will use the same `jupyter` program by default, unless you
override it by setting the `JUPYTER` environment variable, or
delete the file `joinpath(Pkg.dir("IJulia"), "deps", "JUPYTER")`.

### Running the IJulia Notebook

In Julia, at the `julia>` prompt, you can type
```
using IJulia
notebook()
```
to launch the IJulia notebook in your browser.  You can
use `notebook(detached=true)` to launch a notebook server
in the background that will persist even when you quit Julia.
This is also useful if you want to keep using the current Julia
session instead of opening a new one.

```julia
julia> using IJulia; notebook(detached=true)
Process(`'C:\Users\JuliaUser\.julia\v0.4\Conda\deps\usr\Scripts\jupyter' notebook`, ProcessRunning)

julia> 
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
mostly self-explanatory.  Refer to the [the IPython
documentation](http://ipython.org/documentation.html) for more
information.

Given an IJulia notebook file, you can execute its code within any
other Julia file (including another notebook) via the [NBInclude](https://github.com/stevengj/NBInclude.jl) package.

### Updating Julia and IJulia

Julia is improving rapidly, so it won't be long before you want to
update to a more recent version.  To update the packages only, keeping
Julia itself the same, just run:
```
Pkg.update()
```
at the Julia prompt (or in IJulia).

If you download and install a new version of Julia from the Julia web
site, you will also probably want to update the packages with
`Pkg.update()` (in case newer versions of the packages are required
for the most recent Julia).  In any case, if you install a new Julia
binary (or do anything that changes the location of Julia on your
computer), you *must* update the IJulia installation (to tell Jupyter
where to find the new Julia) by running
```
Pkg.build("IJulia")
```
at the Julia command line (**important**: not in IJulia).

### Troubleshooting:

* If you ran into a problem with the above steps, after fixing the
problem you can type `Pkg.build()` to try to rerun the install scripts.
* If you tried it a while ago, try running `Pkg.update()` and try again:
  this will fetch the latest versions of the Julia packages in case
  the problem you saw was fixed.  Run `Pkg.build("IJulia")` if your Julia version may have changed.  If this doesn't work, you could try just deleting the whole `.julia` directory in your home directory (on Windows, it is called `AppData\Roaming\julia\packages` in your home directory) via `rm(Pkg.dir(),recursive=true)` in Julia and re-adding the packages.
* On MacOS, you currently need MacOS 10.7 or later; [MacOS 10.6 doesn't work](https://github.com/JuliaLang/julia/issues/4215) (unless you compile Julia yourself, from source code).
* Internet Explorer 8 (the default in Windows 7) or 9 don't work with the notebook; use Firefox (6 or later) or Chrome (13 or later).  Internet Explorer 10 in Windows 8 works (albeit with a few rendering glitches), but Chrome or Firefox is better.
* If the notebook opens up, but doesn't respond (the input label is `In[*]` indefinitely), try creating a new Python notebook (not Julia) from the `New` button in the Jupyter dashboard, to see if `1+1` works in Python.  If it is the same problem, then probably you have a [firewall running](https://github.com/ipython/ipython/issues/2499) on your machine (this is common on Windows) and you need to disable the firewall or at least to allow the IP address 127.0.0.1.  (For the [Sophos](https://en.wikipedia.org/wiki/Sophos) endpoint security software, go to "Configure Anti-Virus and HIPS", select "Authorization" and then "Websites", and add 127.0.0.1 to "Authorized websites"; finally, restart your computer.)
* Try running `ipython --version` and make sure that it prints `3.0.0` or larger; earlier versions of IPython are no longer supported by IJulia.
* You can try setting `ENV["JUPYTER"]=""; Pkg.build("IJulia")` to force IJulia to use its own Conda-based Jupyter version.

## Low-level Information

### Using older IPython versions

While we strongly recommend using IPython version 3 or later (note that this
has nothing to do with whether you use Python version 2 or 3), we recognize
that in the short term some users may need to continue using IPython 2.x.  You
can do this by checkout out the `ipython2` branch of the IJulia package:

```
Pkg.checkout("IJulia", "ipython2")
Pkg.build("IJulia")
```

### Clearing output

Analogous to the [IPython.display.clear_output()](http://ipython.org/ipython-doc/dev/api/generated/IPython.display.html#IPython.display.clear_output) function in IPython, IJulia provides a function:

```
IJulia.clear_output(wait=false)
```

to clear the output from the current input cell.  If the optional
`wait` argument is `true`, then the front-end waits to clear the
output until new output is available to replace it (to minimize
flickering).  This is useful to make simple animations, via repeated
calls to `IJulia.clear_output(true)` followed by calls to
`display(...)` to display a new animation frame.

### Default display size

When Julia displays a large data structure such as a matrix, by default
it truncates the display to a given number of lines and columns.  In IJulia,
this truncation is to 30 lines and 80 columns by default.   You can change
this default by the `LINES` and `COLUMNS` environment variables, respectively,
which can also be changed within IJulia via `ENV` (e.g. `ENV["LINES"] = 60`).
(Like in the REPL, you can also display non-truncated data structures via `print(x)`.)

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

* You need Julia version 0.4 or later.

Once IPython 3.0+ and Julia 0.4+ are installed, you can install IJulia from a Julia console by typing:
```
Pkg.add("IJulia")
```
This will download IJulia and a few other prerequisites, and will set up a
Julia kernel for IPython.

If the command above returns an error, you may need to run `Pkg.update()`, then
retry it, or possibly run `Pkg.build("IJulia")` to force a rebuild.

### Other IPython interfaces

Most people will use the notebook (browser-based) interface, but you
can also use the IPython
[qtconsole](http://ipython.org/ipython-doc/dev/interactive/qtconsole.html)
or IPython terminal interfaces by running `ipython qtconsole --kernel
julia-0.4` or `ipython console --kernel julia-0.4`, respectively.
(Replace `0.4` with whatever major Julia version you are using.)

### Julia and IPython Magics

One difference from IPython is that the IJulia kernel does
not use "magics", which are special commands prefixed with `%` or
`%%` to execute code in a different language.   Instead, other
syntaxes to accomplish the same goals are more natural in Julia,
work in environments outside of IJulia code cells, and are often
more powerful.

However, if you enter an IPython magic command
in an IJulia code cell, it will print help explaining how to
achieve a similar effect in Julia if possible.
For example, the analogue of IPython's `%load filename` in IJulia
is `IJulia.load("filename")`.

### Debugging IJulia problems

If IJulia is crashing (e.g. it gives you a "kernel appears to have
died" message), you can modify it to print more descriptive error
messages to the terminal: edit your [`IJulia/src/IJulia.jl`](src/IJulia.jl) file (in
your `.julia` package directory) to change the line `verbose = false`
at the top to `verbose = true` and `const capture_stderr = true` to
`const capture_stderr = false`.  Then restart the kernel or open a new
notebook and look for the error message when IJulia dies.

### Preventing truncation of output

The new default behavior of IJulia is to truncate stdout (via `show` or `println`)
after 512kb. This to prevent browsers from getting bogged down when displaying the
results. This limit can be increased to a custom value, like 1MB, as follows

```
IJulia.set_max_stdio(1 << 20)
```
