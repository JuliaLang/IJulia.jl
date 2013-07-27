# IPython/Julia bridge

This is a *highly experimental* code to allow Python code to call
Julia code (starting the Julia runtime system from Python); the
converse is already possible using the PyCall package in Julia.  This
isn't really a package yet, it requires git master versions of Julia,
PyCall and IPython, and tends to segfault everything (you're blending
in one process Python and Julia, with all kinds of convoluted
gymnastics regarding memory management).

Once we get the basics working, we'll clean it up for production.

The `julia.py` file implements the main interface to Julia itself, and is the
most stable part of this story.  It even has a small test suite!
