<div align="center"><img src="deps/ijulialogo.png" alt="IJulia logo" width="150"/></div>

# IJulia

**IJulia** is a [Julia-language](http://julialang.org/) backend
combined with the [IPython](http://ipython.org/) interactive
environment (soon to be called [Jupyter](http://jupyter.org/)).  This
combination allows you to interact with the Julia language using
Jupyter/IPython's powerful [graphical
notebook](http://ipython.org/notebook.html), which combines code,
formatted text, math, and multimedia in a single document

## Installation

First, [install IPython](http://ipython.org/install.html); you may
also want some scientific-Python packages (SciPy and Matplotlib).
The simplest way to do this on Mac and Windows is by [downloading the
Anaconda package](http://continuum.io/downloads) and running its
installer.  (Do *not* use Enthought Canopy/EPD.)

* **Important**: on Windows, the Anaconda installer window gives options *Add Anaconda to the System Path* and also *Register Anaconda as default Python version of the system*.  Be sure to **check these boxes**.

Second, [download Julia](http://julialang.org/downloads/) *version 0.3
or later* and run the installer.  Then run the Julia application
(double-click on it); a window with a `julia>` prompt will appear.  At
the prompt, type:
```
Pkg.add("IJulia")
```
to install IJulia.

### Troubleshooting:

* If you ran into a problem with the above steps, after fixing the 
problem you can type `Pkg.build()` to try to rerun the install scripts.
* If you tried it a while ago, try running `Pkg.update()` and try again:
  this will fetch the latest versions of the Julia packages in case
  the problem you saw was fixed.  Run `Pkg.build("IJulia")` if your Julia version may have changed.  If this doesn't work, try just deleting the whole `.julia` directory in your home directory (on Windows, it is called `AppData\Roaming\julia\packages` in your home directory) and re-adding the packages.
* On MacOS, you currently need MacOS 10.7 or later; [MacOS 10.6 doesn't work](https://github.com/JuliaLang/julia/issues/4215) (unless you compile Julia yourself, from source code).
* If the browser opens the notebook and `1+1` works but basic functions like `sin(3)` don't work, then probably you are running Python and not Julia.  Look in the upper-left corner of the notebook window: if it says **IP[y]: Notebook** then you are running Python.  Probably this was because your `Pkg.add("IJulia")` failed and you ignored the error.
* Internet Explorer 8 (the default in Windows 7) or 9 don't work with the notebook; use Firefox (6 or later) or Chrome (13 or later).  Internet Explorer 10 in Windows 8 works (albeit with a few rendering glitches), but Chrome or Firefox is better.
* If the notebook opens up, but doesn't respond (the input label is `In[*]` indefinitely), try running `ipython notebook` (without Julia) to see if `1+1` works in Python.  If it is the same problem, then probably you have a [firewall running](https://github.com/ipython/ipython/issues/2499) on your machine (this is common on Windows) and you need to disable the firewall or at least to allow the IP address 127.0.0.1.  (For the [Sophos](https://en.wikipedia.org/wiki/Sophos) endpoint security software, go to "Configure Anti-Virus and HIPS", select "Authorization" and then "Websites", and add 127.0.0.1 to "Authorized websites"; finally, restart your computer.)

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
computer), you *must* update the IJulia installation (to tell IPython
where to find the new Julia) by running
```
Pkg.build("IJulia")
```
at the Julia command line (not in IJulia).

## Running the IJulia Notebook

In Julia, at the `julia>` prompt, you can type
```
using IJulia
notebook()
```
to launch the IJulia notebook in your browser.  Alternatively, you can run
```
ipython notebook --profile julia
```
from the command line (the
[Terminal](https://en.wikipedia.org/wiki/Terminal_%28OS_X%29) program
in MacOS or the [Command
Prompt](https://en.wikipedia.org/wiki/Command_Prompt) in Windows).

A "dashboard" window like this should open in your web browser.  Click
on the *New Notebook* button to start a new "notebook".  A notebook
will combine code, computed results, formatted text, and images, just
as in IPython.  You can enter multiline input cells and execute them
with *shift-ENTER*, and the menu items are mostly self-explanatory.
Refer to the [the IPython
documentation](http://ipython.org/documentation.html) for more
information.

## Low-level Information

### Default display size

When Julia displays a large data structure such as a matrix, by default
it truncates the display to a given number of lines and columns.  In IJulia,
this truncation is to 30 lines and 80 columns by default.   You can change
this default by the `LINES` and `COLUMNS` environment variables, respectively,
which can also be changed within IJulia via `ENV` (e.g. `ENV["LINES"] = 60`).
(Like in the REPL, you can also display non-truncated data structures via `print(x)`.)

### Manual installation of IPython

First, you will need to install a few prerequisites:

* You need **version 1.0** or later of IPython.  Note that IPython 1.0
was released in August 2013, so the version pre-packaged with operating-system distribution is likely to be too old for
the next few weeks or months.  Until then, you may have to
[install IPython manually](http://ipython.org/ipython-doc/stable/install/install.html).  On Mac and Windows systems, it is currently easiest to use the [Anaconda Python](http://continuum.io/downloads) installer.

* To use the [IPython notebook](http://ipython.org/notebook.html) interface, which runs in your web
  browser and provides a rich multimedia environment, you will need
  to install the [Jinja2](http://jinja.pocoo.org/docs/), [Tornado](http://www.tornadoweb.org/en/stable/),
  and [pyzmq](https://github.com/zeromq/pyzmq) Python packages.
  (Given the [pip](http://www.pip-installer.org/en/latest/) installer, `pip install jinja2 tornado pyzmq`
  should be sufficient.)  These should have been automatically installed if you installed IPython itself
  [via `easy_install` or `pip`](http://ipython.org/ipython-doc/stable/install/install.html#quickstart).

* To use the [IPython qtconsole](http://ipython.org/ipython-doc/dev/interactive/qtconsole.html) interface,
  you will need to install [PyQt4](http://www.riverbankcomputing.com/software/pyqt/download) or 
  [PySide](http://qt-project.org/wiki/Category:LanguageBindings::PySide).

* You need Julia version 0.3 or later.

Once IPython 1.0+ and Julia 0.3+ are installed, you can install IJulia from a Julia console by typing:
```
Pkg.add("IJulia")
```
This will download IJulia and a few other prerequisites, and will set up a
Julia profile for IPython.

If the command above returns an error, you may need to run `Pkg.update()`, then
retry it.

### Other IPython interfaces

Given the above, you have three choices:

* The richest interface is the [IPython notebook](http://ipython.org/notebook.html), which you can
  invoke for Julia by: `ipython notebook --profile julia` (a window will open in your web browser).

* A lightweight terminal-like interface that nevertheless supports
  inline graphics and multiline editing is the [IPython qtconsole](http://ipython.org/ipython-doc/dev/interactive/qtconsole.html), which you can invoke for Julia by: `ipython qtconsole --profile julia`

* A basic text terminal interface (no graphics) can be invoked for Julia by `ipython console --profile julia`

Please refer to [the IPython documentation](http://ipython.org/documentation.html) for other configuration options.  For example, if you plan to connect the notebook front-end to a Julia kernel running on a different machine (yes, this is possible!), we strongly recommend that you run notebook [over https with a password](http://ipython.org/ipython-doc/stable/interactive/public_server.html#notebook-security).  These configuration settings can go in the file: `~/.ipython/profile_julia/ipython_notebook_config.py`.

### Differences from IPython

One difference from IPython is that the IJulia kernel currently does
not support "magics", which are special commands prefixed with `%` or
`%%` to execute code in a different language.  This and other features
are under consideration in the [IJulia
issues](https://github.com/JuliaLang/IJulia.jl/issues) list.

### Debugging IJulia problems

If IJulia is crashing (e.g. it gives you a "kernel appears to have
died" message), you can modify it to print more descriptive error
messages to the terminal: edit your `IJulia/src/IJulia.jl` file (in
your `.julia` package directory) to change the line `verbose = false`
at the top to `verbose = true` and `const capture_stderr = true` to
`const capture_stderr = false`.  Then re-run `ipython notebook
--profile julia` from your terminal and look for the error message
when IJulia dies.
