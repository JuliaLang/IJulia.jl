# IPython/Julia bridge

This is a *highly experimental* code to integrate Julia and IPython.  This
isn't really a package yet, it requires git master versions of Julia, PyCall
and IPython, and tends to segfault everything (you're blending in one process
Python and Julia, with all kinds of convoluted gymnastics regarding memory
management).

Once we get the basics working, we'll clean it up for production.

The `kernel/` directory contains a simpler version of a minimalistic kernel
based on the original IPython-over-ZeroMQ prototype.  That has the advantage of
not depending on all of the real IPython, and therefore being much easier to
understand and debug.

Once we get that working, development will switch to the `ipkernel.py` module
in the `julia` directory, that uses the real IPython protocols.

The `julia.py` file implements the main interface to Julia itself, and is the
most stable part of this story.  It even has a small test suite!


## ToDo

* Stdout/err capture for all printing.
* sparse matrices
* matplotlib figures.
* Wrap julia errors into Python exceptions or at least print them to python
  stderr: 
  
<PyCall.jlwrap ArgumentError("matplotlib.pyplot is not a valid module variable
name, use @pyimport matplotlib.pyplot as <name>")>


* print isprime(20) fails, when isprime is a python handle on the Julia func.

* capturing the result of a %%julia block into a named variable
* in/out vars like R/octave

* Return also a callable julia object that can be used functionally in pure
  python instead of with magic syntax.
  
* silent option to supress cell output (useful for plots to prevent the return
  of big matplotlib lists/collections.
