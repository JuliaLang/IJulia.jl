"""
Bridge Python and Julia by initializing the Julia interpreter inside the Python one.
"""

#-----------------------------------------------------------------------------
#  Copyright (C) 2013 The IPython and Julia Development Teams.
#
#  Distributed under the terms of the BSD License.  The full license is in
#  the file COPYING, distributed as part of this software.
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# Imports
#-----------------------------------------------------------------------------

# Stdlib
import ctypes
import ctypes.util
import os
import sys
import commands

#-----------------------------------------------------------------------------
# Classes and funtions
#-----------------------------------------------------------------------------

class JuliaMagicError(Exception):
    pass


class Julia(object):
    """Implements a bridge to the Julia interpreter or library.

    This uses the Julia PyCall module to perform type conversions and allow
    full access to the entire Julia interpreter.
    """
    

    def __init__(self, init_julia=True):
        """Create a Python object that represents a live Julia interpreter.

        Parameters
        ==========

        init_julia : bool
          If True, try to initialize the Julia interpreter.  If this code is
          being called from inside an already running Julia, the flag should be
          passed as False so the interpreter isn't re-initialized.

          Note that it is safe to call this class constructor twice in the same
          process with `init_julia` set to True, as a global reference is kept
          to avoid re-initializing it.  The purpose of the flag is only to
          manage situations when Julia was initialized from outside this code.
        """
        
        # Ugly hack to register the julia interpreter globally so we can reload
        # this extension without trying to re-open the shared lib, which kills
        # the python interpreter.  Nasty but useful while debugging
        if hasattr(sys, '_julia_runtime'):
            self.j = sys._julia_runtime
            return
        
        if init_julia:
            # print 'Finding Julia install directory...'  # dbg
            status, JULIA_HOME = commands.getstatusoutput(
                                     'julia -e "print(JULIA_HOME)"')
            if status != 0:
                raise JuliaMagicError('error starting up the Julia process')
            
            jpath = os.path.abspath('%s/../lib/libjulia-release.so' % JULIA_HOME)
            j = ctypes.PyDLL(jpath, ctypes.RTLD_GLOBAL)
            # print 'Initializing Julia...'  # dbg
            j.jl_init('%s/../lib' % JULIA_HOME)
        else:
            # we're assuming here we're fully inside a running Julia process,
            # so we're fishing for symbols in our own process table
            j = ctypes.PyDLL('')

        # Store the running interpreter reference so we can start using it via self.jcall
        self.j = j

        # Set the return types of some of the bridge functions in ctypes terminology
        j.jl_eval_string.restype = ctypes.c_void_p
        j.jl_call1.restype = ctypes.c_void_p
        j.jl_get_field.restype = ctypes.c_void_p
        j.jl_typeof_str.restype = ctypes.c_char_p
        j.jl_unbox_voidpointer.restype = ctypes.py_object

        if init_julia:
            # print 'Initializing Julia PyCall module...' # dbg
            self.jcall('using PyCall')
            self.jcall('pyinitialize(C_NULL)')

        # Whether we initialized Julia or not, we MUST create at least one
        # instance of PyObject.  Since this will be needed on every call, we
        # hold it in the Julia object itself so it can survive across
        # reinitializations.
        j.PyObject = self.jcall('PyObject')

        # Flag process-wide that Julia is initialized and store the actual
        # runtime interpreter, so we can reuse it across calls and module reloads.
        sys._julia_runtime = j
        
    def jcall(self, src):
        """Low-level call to execute a snippet of Julia source.

        This only raises an exception if Julia itself throws an error, but it
        does NO type conversion into usable Python objects nor any memory
        management.  It should never be used for returning the result of Julia
        expressions, only to execute statements.
        """
        ans = self.j.jl_eval_string(src)
        if self.j.jl_typeof_str(ctypes.c_void_p(ans)) == 'ErrorException':
            raise JuliaMagicError('ErrorException in Julia: %s' %src)
        else:
            return ans

    def run(self, src):
        """
        Execute code in Julia, and pull some of the results back into the
        Python namespace.
        """
        if src is None:
            return None
        
        #print 'Running src:', src  # dbg
        ans = self.jcall(src)
        #print 'Ans:', ans  # dbg
        # local shorthands for clarity
        j = self.j
        void_p = ctypes.c_void_p
        # Unbox the Julia result into something Python understands
        xx = j.jl_call1(j.PyObject, void_p(ans))
        pyans = j.jl_unbox_voidpointer(void_p(j.jl_get_field(void_p(xx), 'o')))
        # make sure we incref it before returning it, since this is a borrowed ref
        ctypes.pythonapi.Py_IncRef(ctypes.py_object(pyans))
        #print 'Pyans (s, r):', str(pyans), '|||', repr(pyans)  # dbg
        return pyans
