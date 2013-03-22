"""An IPython kernel for Julia.
"""

from IPython.kernel.zmq.kernelapp import IPKernelApp
from IPython.kernel.zmq.ipkernel import Kernel

from IPython.utils.traitlets import DottedObjectName


class JuliaKernel(Kernel):
    def execute_request(self, stream, ident, parent):
        self.log.info(parent)


class JuliaKernelApp(IPKernelApp):
    name = 'juliakernel'
    kernel_class = DottedObjectName('juliamagic.ipkernel.JuliaKernel')
    kernel_class2 = JuliaKernel


def main():
    """Run a JuliaKernel as an application"""
    app = JuliaKernelApp.instance()
    app.initialize()
    app.start()


if __name__ == '__main__':
    main()
