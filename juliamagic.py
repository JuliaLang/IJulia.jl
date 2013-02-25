"""Julia magics for IPython.
"""

#-----------------------------------------------------------------------------
#  Copyright (C) 2012 The IPython Development Team
#
#  Distributed under the terms of the BSD License.  The full license is in
#  the file COPYING, distributed as part of this software.
#-----------------------------------------------------------------------------

import ctypes
import tempfile

from glob import glob
from shutil import rmtree

import numpy as np
from xml.dom import minidom

from IPython.core.displaypub import publish_display_data
from IPython.core.magic import (Magics, magics_class, line_magic,
                                line_cell_magic, needs_local_scope)
from IPython.testing.skipdoctest import skip_doctest
from IPython.core.magic_arguments import (
    argument, magic_arguments, parse_argstring
)
from IPython.utils.py3compat import unicode_to_str

class JuliaMagicError(Exception):
    pass

_mimetypes = {'png' : 'image/png',
             'svg' : 'image/svg+xml',
             'jpg' : 'image/jpeg',
             'jpeg': 'image/jpeg'}

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

    @skip_doctest
    @line_magic
    def julia_push(self, line):
        '''
        Line-level magic that pushes a variable to Julia.

        `line` should be made up of whitespace separated variable names in the
        IPython namespace::

            In [7]: import numpy as np

            In [8]: X = np.arange(5)

            In [9]: X.mean()
            Out[9]: 2.0

            In [10]: %julia_push X

            In [11]: %julia mean(X)
            Out[11]: 2.0

        '''
        inputs = line.split(' ')
        for input in inputs:
            input = unicode_to_str(input)
            self._j.put(input, self.shell.user_ns[input])


    @skip_doctest
    @line_magic
    def julia_pull(self, line):
        '''
        Line-level magic that pulls a variable from Julia.

            In [18]: _ = %julia x = [1 2; 3 4]; y = 'hello'

            In [19]: %julia_pull x y

            In [20]: x
            Out[20]:
            array([[ 1.,  2.],
                   [ 3.,  4.]])

            In [21]: y
            Out[21]: 'hello'

        '''
        outputs = line.split(' ')
        for output in outputs:
            output = unicode_to_str(output)
            self.shell.push({output: self._j.get(output)})


    @skip_doctest
    @magic_arguments()
    @argument(
        '-i', '--input', action='append',
        help='Names of input variables to be pushed to Julia. Multiple names '
             'can be passed, separated by commas with no whitespace.'
        )
    @argument(
        '-o', '--output', action='append',
        help='Names of variables to be pulled from Julia after executing cell '
             'body. Multiple names can be passed, separated by commas with no '
             'whitespace.'
        )
    @argument(
        '-s', '--size', action='store',
        help='Pixel size of plots, "width,height". Default is "-s 400,250".'
        )
    @argument(
        '-f', '--format', action='store',
        help='Plot format (png, svg or jpg).'
        )


    @line_cell_magic
    def julia(self, line, cell=None):
        '''
        Execute code in Julia, and pull some of the results back into the
        Python namespace.
        '''
        src = str(line if cell is None else cell)
        ans = self._j.jl_eval_string(src)
        anstype = self._j.jl_typeof_str(ans).lower()
        try:
            unboxer = self._junboxers[anstype]
        except KeyError:
            #print "Unboxer not found for return type:", anstype  # dbg
            return None
        else:
            return unboxer(ans)

    @needs_local_scope
    @argument(
        'code',
        nargs='*',
        )
    @line_cell_magic
    def julia2(self, line, cell=None, local_ns=None):
        '''
        Execute code in Julia, and pull some of the results back into the
        Python namespace.

            In [9]: %julia X = [1 2; 3 4]; mean(X)
            Out[9]: array([[ 2., 3.]])

        As a cell, this will run a block of Julia code, without returning any
        value::

            In [10]: %%julia
               ....: p = [-2, -1, 0, 1, 2]
               ....: polyout(p, 'x')

            -2*x^4 - 1*x^3 + 0*x^2 + 1*x^1 + 2

        In the notebook, plots are published as the output of the cell, e.g.

        %julia plot([1 2 3], [4 5 6])

        will create a line plot.

        Objects can be passed back and forth between Julia and IPython via the
        -i and -o flags in line::

            In [14]: Z = np.array([1, 4, 5, 10])

            In [15]: %julia -i Z mean(Z)
            Out[15]: array([ 5.])


            In [16]: %julia -o W W = Z * mean(Z)
            Out[16]: array([  5.,  20.,  25.,  50.])

            In [17]: W
            Out[17]: array([  5.,  20.,  25.,  50.])

        The size and format of output plots can be specified::

            In [18]: %%julia -s 600,800 -f svg
                ...: plot([1, 2, 3]);

        '''
        args = parse_argstring(self.julia, line)

        # arguments 'code' in line are prepended to the cell lines
        if cell is None:
            code = ''
            return_output = True
        else:
            code = cell
            return_output = False

        code = ' '.join(args.code) + code

        # if there is no local namespace then default to an empty dict
        if local_ns is None:
            local_ns = {}

        if args.input:
            for input in ','.join(args.input).split(','):
                input = unicode_to_str(input)
                try:
                    val = local_ns[input]
                except KeyError:
                    val = self.shell.user_ns[input]
                self._j.put(input, val)

        # generate plots in a temporary directory
        plot_dir = tempfile.mkdtemp().replace('\\', '/')
        if args.size is not None:
            size = args.size
        else:
            size = '400,240'

        if args.format is not None:
            plot_format = args.format
        else:
            plot_format = 'png'

        pre_call = '''
        global __ipy_figures = [];
        page_screen_output(0);

        function fig_create(src, event)
          global __ipy_figures;
          __ipy_figures(size(__ipy_figures) + 1) = src;
          set(src, "visible", "off");
        end

        set(0, 'DefaultFigureCreateFcn', @fig_create);

        close all;
        clear ans;

        # ___<end_pre_call>___ #
        '''

        post_call = '''
        # ___<start_post_call>___ #

        # Save output of the last execution
        if exist("ans") == 1
          _ = ans;
        else
          _ = nan;
        end

        for f = __ipy_figures
          outfile = sprintf('%(plot_dir)s/__ipy_j_fig_%%03d.png', f);
          try
            print(f, outfile, '-d%(plot_format)s', '-tight', '-S%(size)s');
          end
        end

        ''' % locals()

        code = ' '.join((pre_call, code, post_call))
        try:
            text_output = self._j.run(code, verbose=False)
        except (oct2py.Oct2PyError) as exception:
            msg = exception.message
            msg = msg.split('# ___<end_pre_call>___ #')[1]
            msg = msg.split('# ___<start_post_call>___ #')[0]
            raise JuliaMagicError('Julia could not complete execution.  '
                                   'Traceback (currently broken in oct2py): %s'
                                   % msg)

        key = 'JuliaMagic.Julia'
        display_data = []

        # Publish text output
        if text_output:
            display_data.append((key, {'text/plain': text_output}))

        # Publish images
        images = [open(imgfile, 'rb').read() for imgfile in \
                  glob("%s/*" % plot_dir)]
        rmtree(plot_dir)

        plot_mime_type = _mimetypes.get(plot_format, 'image/png')
        width, height = [int(s) for s in size.split(',')]
        for image in images:
            if plot_format == 'svg':
                image = self._fix_gnuplot_svg_size(image, size=(width, height))
            display_data.append((key, {plot_mime_type: image}))

        if args.output:
            for output in ','.join(args.output).split(','):
                output = unicode_to_str(output)
                self.shell.push({output: self._j.get(output)})

        for source, data in display_data:
            self._publish_display_data(source, data)

        if return_output:
            ans = self._j.get('_')

            # Unfortunately, Julia doesn't have a "None" object,
            # so we can't return any NaN outputs
            if np.isscalar(ans) and np.isnan(ans):
                ans = None

            return ans


__doc__ = __doc__.format(
    JULIA_DOC = ' '*8 + JuliaMagics.julia.__doc__,
    JULIA_PUSH_DOC = ' '*8 + JuliaMagics.julia_push.__doc__,
    JULIA_PULL_DOC = ' '*8 + JuliaMagics.julia_pull.__doc__
    )


def load_ipython_extension(ip):
    """Load the extension in IPython."""
    ip.register_magics(JuliaMagics)
