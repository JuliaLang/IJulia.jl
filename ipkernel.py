"""An IPython kernel for Julia.
"""

from IPython.kernel.zmq.kernelapp import IPKernelApp
from IPython.kernel.zmq.ipkernel import Kernel

from IPython.utils.traitlets import DottedObjectName

from zmq.eventloop.zmqstream import ZMQStream

class JuliaKernel(Kernel):
    def execute_request(self, stream, ident, parent):
        self.log.info(parent)


class JuliaKernelApp(IPKernelApp):
    name = 'juliakernel'
    kernel_class = DottedObjectName('juliamagic.ipkernel.JuliaKernel')
    kernel_class2 = JuliaKernel

    def init_kernel(self):
        """Create the Kernel object itself"""
        shell_stream = ZMQStream(self.shell_socket)

        Kernel = self.kernel_class2
        
        kernel = Kernel(config=self.config, session=self.session,
                                shell_streams=[shell_stream],
                                iopub_socket=self.iopub_socket,
                                stdin_socket=self.stdin_socket,
                                log=self.log,
                                profile_dir=self.profile_dir,
        )
        kernel.record_ports(self.ports)
        self.kernel = kernel



def main():
    """Run a JuliaKernel as an application"""
    app = JuliaKernelApp.instance()
    app.initialize()
    app.start()


if __name__ == '__main__':
    main()
