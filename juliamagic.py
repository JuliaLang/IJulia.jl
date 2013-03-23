"""Julia magics for IPython.
"""

#-----------------------------------------------------------------------------
#  Copyright (C) 2013 The IPython Development Team
#
#  Distributed under the terms of the BSD License.  The full license is in
#  the file COPYING, distributed as part of this software.
#-----------------------------------------------------------------------------

# Global to ensure we don't try to initialize the Julia interpreter more than
# once, so this can actually be reloaded.

import ctypes
import ctypes.util
import os
import sys
import commands

from IPython.core.magic import ( Magics, magics_class,
                                 line_cell_magic )


class JuliaMagicError(Exception):
    pass

###########################################################################
# Julia magics using Julia PyCall module to perform type conversions

class Julia(object):
    """Implements a bridge to the Julia interpreter or library.
    """

    def __init__(self, init_julia=True):
        global _julia_initialized
        
        # Ugly hack to register the julia interpreter globally so we can reload
        # this extension without trying to re-open the shared lib, which kills
        # the python interpreter.  Nasty but useful while debugging
        if hasattr(sys, '_julia_initialized'):
            j = sys._julia_initialized
            self._j = j
            return
        
        if init_julia:
            print 'Finding Julia install directory...'
            status, JULIA_HOME = commands.getstatusoutput(
                                     'julia -e "print(JULIA_HOME)"')
            if status != 0:
                raise JuliaMagicError("error executing julia command")
            
            jpath = os.path.abspath('%s/../lib/libjulia-release.so' % JULIA_HOME)
            j = ctypes.PyDLL(jpath, ctypes.RTLD_GLOBAL)
            print 'Initializing Julia...'
            j.jl_init('%s/../lib' % JULIA_HOME)
        else:
            # we're assuming here we're fully inside a running Julia process,
            # so we're fishing for symbols in our own process table
            j = ctypes.PyDLL('')

        sys._julia_initialized = j

        self.j = j
        j.jl_eval_string.restype = ctypes.c_void_p
        j.jl_call1.restype = ctypes.c_void_p
        j.jl_get_field.restype = ctypes.c_void_p
        j.jl_typeof_str.restype = ctypes.c_char_p
        j.jl_unbox_voidpointer.restype = ctypes.py_object

        if init_julia:
            print 'Initializing Julia PyCall module...'
            self.jcall('using PyCall')
            self.jcall('pyinitialize(C_NULL)')
            
        jpyobj = self.jcall('PyObject')
        self.j_py_obj = jpyobj

    def jcall(self, src):
        ans = self.j.jl_eval_string(src)
        if self.j.jl_typeof_str(ctypes.c_void_p(ans)) == "ErrorException":
            raise JuliaMagicError("ErrorException in Julia: %s" %src)
        else:
            return ans

    def run(self, src):
        '''
        Execute code in Julia, and pull some of the results back into the
        Python namespace.
        '''
        if src is None:
            return None
        
        j = self.j
        tstr = self.j.jl_typeof_str
        #print 'Running src:', src  # dbg
        ans = self.jcall(src)
        #print 'Ans:', ans  # dbg
        xx = j.jl_call1(ctypes.c_void_p(self.j_py_obj), ctypes.c_void_p(ans))
        pyans = j.jl_unbox_voidpointer(ctypes.c_void_p(j.jl_get_field(ctypes.c_void_p(xx), 'o')))
        ctypes.pythonapi.Py_IncRef(ctypes.py_object(pyans))
        return pyans
    

@magics_class
class JuliaMagics(Magics):
    """A set of magics useful for interactive work with Julia.
    """
    def __init__(self, shell):
        """
        Parameters
        ----------
        shell : IPython shell

        """

        super(JuliaMagics, self).__init__(shell)
        self.julia = Julia(init_julia=True)
        
    @line_cell_magic
    def julia(self, line, cell=None):
        '''
        Execute code in Julia, and pull some of the results back into the
        Python namespace.
        '''
        src = str(line if cell is None else cell)
        return self.julia.run(src)


__doc__ = __doc__.format(
    JULIA_DOC = ' '*8 + JuliaMagics.julia.__doc__,
    )


def load_ipython_extension(ip):
    """Load the extension in IPython."""
    ip.register_magics(JuliaMagics)
