=======================================================
 Simple interactive Python kernel/frontend with ZeroMQ
=======================================================

This is the code that served as the original prototype for today's IPython
client/server model.  It is kept here purely as a reference to illustrate how
to implement similar ideas for interactive Python interpreters on top of
zeromq.  This example used to be included with pyzmq but for some reason was
removed, so it's available here in standalone form.  It should be useful to
anyone wishing to either implement a similar system or understand IPython's
basic architecture without all of the details.

The message spec included here was the original, minimal spec we used for this
implementation, today's IPython messaging is based on these ideas but has
evolved substantially.


Usage
=====

Run in one terminal::

  ./kernel.py

and in another::

  ./frontend.py

In the latter, you can type python code, tab-complete, etc.  The kernel
terminal prints all messages for debugging.  Exit the frontend with Ctrl-D, and
the kernel with Ctrl-\ (note that Ctrl-C will *not* stop the kernel).


License
=======

This code is released under the terms of the BSD license, same as IPython
itself.  It was originally authored by Brian Granger and Fernando Perez, but no
further development is planned, as all the ideas illustrated here are now
implemented in IPython and developed there as production code.
