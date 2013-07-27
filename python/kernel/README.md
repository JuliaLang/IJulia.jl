# Simple Julia kernel/frontend with ZeroMQ in the style of IPython

Sample, minimalistic Julia kernel.  Just enough to test the protocol ideas.
Once we get this working, all development should be done on the real IPython
kernel code.  But that code is way more complex than this.

## Usage

This code can be used in one of two ways, from a plain terminal or within
Julia.  To use it from a plain terminal, simply type:

    ./kernel.py

while from Julia, use:

    include("jip.jl")

Regardless of which approach you use above, once the kernel shows that it's
active, from another terminal start the frontend:

    ./frontend.py

Exit the frontend with Ctrl-D, and the kernel with Ctrl-\ (note that Ctrl-C
will *not* stop the kernel).

Note that you can restart either component (kernel or frontend) without
restarting the other.
