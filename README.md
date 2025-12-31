<div align="center"><img src="assets/ijulialogo.png" alt="IJulia logo" width="150"/></div>

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaLang.github.io/IJulia.jl/stable)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://JuliaLang.github.io/IJulia.jl/dev)
[![Run tests](https://github.com/JuliaLang/IJulia.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/JuliaLang/IJulia.jl/actions/workflows/CI.yml)

# IJulia

**IJulia** is a [Julia-language](http://julialang.org/) backend
combined with the [Jupyter](http://jupyter.org/) interactive
environment (also used by [IPython](http://ipython.org/)).  This
combination allows you to interact with the Julia language using
Jupyter/IPython's powerful [graphical
notebook](http://ipython.org/notebook.html), which combines code,
formatted text, math, and multimedia in a single document.
IJulia is a Jupyter language kernel and works with a variety of notebook
user interfaces. In addition to the classic Jupyter Notebook, IJulia
also works with [JupyterLab](https://jupyterlab.readthedocs.io/en/stable/), a Jupyter-based
integrated development environment for notebooks and code.
The [nteract notebook desktop](https://nteract.io/) supports IJulia with
detailed instructions for its [installation with nteract](https://nteract.io/kernels/julia).

(IJulia notebooks can also be re-used in other Julia code via
the [NBInclude](https://github.com/stevengj/NBInclude.jl) package.)

## Quick start

Install IJulia from the Julia REPL by pressing `]` to enter pkg mode and entering:

```
add IJulia
```

To launch the Jupyter notebook, type the following in Julia at the `julia>` prompt:

```julia
using IJulia
notebook()
```

The first time you run `notebook()`, it will:
- Prompt you to install Jupyter if you don't already have it (hit enter to
  install via [Conda.jl](https://github.com/JuliaPy/Conda.jl), which creates a
  minimal Python+Jupyter distribution private to Julia).
- Automatically install the Julia kernel for your current Julia version.

If you already have Jupyter installed and prefer to use it, you can launch it
from the terminal with `jupyter notebook` instead. A Julia kernel can be
installed with `IJulia.installkernel()`.

**Note:** IJulia should generally be installed in Julia's global package
environment, unless you install a custom kernel that specifies a particular
environment.

For more advanced installation options, such as specifying a specific Jupyter
installation to use, see the [documentation](https://JuliaLang.github.io/IJulia.jl/stable).
