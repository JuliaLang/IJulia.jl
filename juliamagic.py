"""Julia magics for IPython.
"""

#-----------------------------------------------------------------------------
#  Copyright (C) 2013 The IPython Development Team
#
#  Distributed under the terms of the BSD License.  The full license is in
#  the file COPYING, distributed as part of this software.
#-----------------------------------------------------------------------------

import ctypes


from IPython.core.displaypub import publish_display_data
from IPython.core.magic import ( Magics, magics_class,
                                 line_cell_magic )


class JuliaMagicError(Exception):
    pass


@magics_class
class JuliaMagics(Magics):
    """A set of magics useful for interactive work with Julia via oct2py.
    """
    def __init__(self, shell):
        """
        Parameters
        ----------
        shell : IPython shell

        """
        super(JuliaMagics, self).__init__(shell)
        j = ctypes.CDLL('libjulia-release.so', ctypes.RTLD_GLOBAL)
        j.jl_init()
        
        j.jl_typeof_str.restype = ctypes.c_char_p

        unbox_map = dict(float32 = ctypes.c_float,
                         float64 = ctypes.c_double,
                         int32 = ctypes.c_short,
                         int64 = ctypes.c_int,
                         )

        j_unboxers = {}
        for jname, ctype in unbox_map.iteritems():
            junboxer = getattr(j, 'jl_unbox_' + jname)
            junboxer.restype = ctype
            j_unboxers[jname] = junboxer

        self._junboxers = j_unboxers
        self._j = j
        self._plot_format = 'png'

        # Allow publish_display_data to be overridden for
        # testing purposes.
        self._publish_display_data = publish_display_data

    @line_cell_magic
    def julia(self, line, cell=None):
        '''
        Execute code in Julia, and pull some of the results back into the
        Python namespace.
        '''
        src = str(line if cell is None else cell)
        ans = self._j.jl_eval_string(src)
        anstype = self._j.jl_typeof_str(ans).lower()
        print 'anstype:', anstype
        try:
            unboxer = self._junboxers[anstype]
        except KeyError:
            #print "Unboxer not found for return type:", anstype  # dbg
            return None
        else:
            return unboxer(ans)


__doc__ = __doc__.format(
    JULIA_DOC = ' '*8 + JuliaMagics.julia.__doc__,
    )


def load_ipython_extension(ip):
    """Load the extension in IPython."""
    ip.register_magics(JuliaMagics)
