"""
==========================
 Julia magics for IPython
==========================

{JULIAMAGICS_DOC}

Usage
=====

``%%julia``

{JULIA_DOC}
"""

#-----------------------------------------------------------------------------
# Imports
#-----------------------------------------------------------------------------

from __future__ import print_function

import sys

from IPython.core.magic import Magics, magics_class, line_cell_magic

from julia import Julia    

#-----------------------------------------------------------------------------
# Main classes
#-----------------------------------------------------------------------------

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
        print("Initializing Julia interpreter. This may take some time...",
              end='')
        # Flush, otherwise the Julia startup will keep stdout buffered
        sys.stdout.flush()
        self.julia = Julia(init_julia=True)
        print()
        
    @line_cell_magic
    def julia(self, line, cell=None):
        """
        Execute code in Julia, and pull some of the results back into the
        Python namespace.
        """
        src = str(line if cell is None else cell)
        return self.julia.run(src)


# Add to the global docstring the class information.
__doc__ = __doc__.format(
    JULIAMAGICS_DOC = ' '*8 + JuliaMagics.__doc__,
    JULIA_DOC = ' '*8 + JuliaMagics.julia.__doc__,
    )


#-----------------------------------------------------------------------------
# IPython registration entry point.
#-----------------------------------------------------------------------------

def load_ipython_extension(ip):
    """Load the extension in IPython."""
    ip.register_magics(JuliaMagics)
