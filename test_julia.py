"""Test suite for the Python/Julia integration bridge.
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
from unittest import TestCase

# Third-party
import numpy as np
import numpy.testing as npt

# Our own
import julia

#-----------------------------------------------------------------------------
# Test suite begins
#-----------------------------------------------------------------------------

class JuliaTestCase(TestCase):
    def setUp(self):
        self.j = julia.Julia()

    def check_expr(self, expr, val, val_type):
        v = self.j.run(expr)
        self.assertEquals(v, val)
        self.assertEquals(type(v), val_type)

    def test_simple(self):
        for t in [ ('1', 1, int), ('1.0', 1.0, float),
                   ('1+2', 3, int), ('1+2.0', 3.0, float)]:
            self.check_expr(*t)

    def test_numpy_creation(self):
        a = self.j.run('[1:10]')
        npt.assert_array_equal(a, np.arange(1, 11))
