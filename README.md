<div align="center"><img src="deps/ijulialogo.png" alt="IJulia logo" width="150"/></div>

# IJulia

**IJulia** is a [Julia-language](http://julialang.org/) backend combined
with the [IPython](http://ipython.org/) interactive environment.  This
combination allows you to interact with the Julia language using
IPython's powerful [graphical
notebook](http://ipython.org/notebook.html), which combines code,
formatted text, math, and multimedia in a single document

(This package also includes a prototype Python module to call Julia
from Python, including
["magics"](http://ipython.org/ipython-doc/dev/interactive/tutorial.html)
to call Julia code from within a Python session in IPython.)

## Tutorial

High-level installation instructions using precompiled binaries, as well as a basic usage tutorial, can be found in these tutorial notes:

* [Julia at MIT](https://github.com/stevengj/julia-mit/blob/master/README.md)

### Low-level installation info

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

* You need Julia version 0.2 (or rather, a recent git `master` snapshot, since 0.2 is not yet released).

Once IPython 1.0+ and Julia 0.2 is installed, you can install IJulia with:
```
Pkg.add("IJulia")
```
This will download IJulia and a few other prerequisites, and will set up a
Julia profile for IPython.

If the command above returns an error, you may need to run `Pkg.update()`, then
retry it.

## Running IJulia

Given the above, you have three choices:

* The richest interface is the [IPython notebook](http://ipython.org/notebook.html), which you can
  invoke for Julia by: `ipython notebook --profile julia` (a window will open in your web browser).

* A lightweight terminal-like interface that nevertheless supports
  inline graphics and multiline editing is the [IPython qtconsole](http://ipython.org/ipython-doc/dev/interactive/qtconsole.html), which you can invoke for Julia by: `ipython qtconsole --profile julia`

* A basic text terminal interface (no graphics) can be invoked for Julia by `ipython console --profile julia`

Please refer to [the IPython documentation](http://ipython.org/documentation.html) for other configuration options.  For example, if you plan to connect the notebook front-end to a Julia kernel running on a different machine (yes, this is possible!), we strongly recommend that you run notebook [over https with a password](http://ipython.org/ipython-doc/stable/interactive/public_server.html#notebook-security).  These configuration settings can go in the file: `~/.ipython/profile_julia/ipython_notebook_config.py`.

## Usage

Once you have launched IJulia via a notebook or console interface,
usage is straightforward and is similar to IPython. You can enter
multiline input cells and execute them with shift-ENTER, and the menu
items are mostly self-explanatory.  Refer to the IPython documentation
for more information.

(One difference from IPython is that the IJulia kernel currently does
not support "magics", which are special commands prefixed with `%` or `%%`
to execute code in a different language.  This and other features are
under consideration in the [IJulia issues](https://github.com/JuliaLang/IJulia.jl/issues) list.)
