"""An IPython kernel for Julia.
"""

#-----------------------------------------------------------------------------
# Imports
#-----------------------------------------------------------------------------

# Standard library imports
import __builtin__
import sys
import time
import traceback

# Third-party
from IPython.kernel.zmq.kernelapp import IPKernelApp
from IPython.kernel.zmq.ipkernel import Kernel
from IPython.utils import py3compat
from IPython.utils.jsonutil import json_clean
from IPython.utils.traitlets import DottedObjectName

from zmq.eventloop.zmqstream import ZMQStream

#-----------------------------------------------------------------------------
# Main classes
#-----------------------------------------------------------------------------

class JuliaKernel(Kernel):

    def __init__(self, **kwargs):
        super(JuliaKernel, self).__init__(**kwargs)
        init_julia = kwargs.pop('init_julia', True)
        
        from .core import Julia
        self.j = Julia(init_julia=init_julia)

    def execute_request(self, stream, ident, parent):
        """handle an execute_request"""
        
        self._publish_status(u'busy', parent)
        
        try:
            content = parent[u'content']
            code = content[u'code']
            silent = content[u'silent']
            store_history = content.get(u'store_history', not silent)
        except:
            self.log.error("Got bad msg: ")
            self.log.error("%s", parent)
            return
        
        md = self._make_metadata(parent['metadata'])

        shell = self.shell # we'll need this a lot here

        # Replace raw_input. Note that is not sufficient to replace
        # raw_input in the user namespace.
        if content.get('allow_stdin', False):
            raw_input = lambda prompt='': self._raw_input(prompt, ident, parent)
        else:
            raw_input = lambda prompt='' : self._no_raw_input()

        if py3compat.PY3:
            self._sys_raw_input = __builtin__.input
            __builtin__.input = raw_input
        else:
            self._sys_raw_input = __builtin__.raw_input
            __builtin__.raw_input = raw_input

        # Set the parent message of the display hook and out streams.
        shell.displayhook.set_parent(parent)
        shell.display_pub.set_parent(parent)
        shell.data_pub.set_parent(parent)
        try:
            sys.stdout.set_parent(parent)
        except AttributeError:
            pass
        try:
            sys.stderr.set_parent(parent)
        except AttributeError:
            pass

        # Re-broadcast our input for the benefit of listening clients, and
        # start computing output
        if not silent:
            self._publish_pyin(code, parent, shell.execution_count)

        reply_content = {}
        # Return the execution counter so clients can display prompts
        reply_content['execution_count'] = shell.execution_count
        try:
            jans = self.j.run(code)
            if not silent:
                shell.displayhook(jans)
                shell.execution_count += 1
        except:
            status = u'error'
            etype, evalue, tb = sys.exc_info()
            tb_list = traceback.format_exception(etype, evalue, tb)
            reply_content.update(shell._showtraceback(etype, evalue, tb_list))
        else:
            status = u'ok'
        finally:
            # Restore raw_input.
             if py3compat.PY3:
                 __builtin__.input = self._sys_raw_input
             else:
                 __builtin__.raw_input = self._sys_raw_input

        reply_content[u'status'] = status
        
        # FIXME: We need to get user_variables and user_expressions in Julia.
        reply_content[u'user_variables'] = {}
        reply_content[u'user_expressions'] = {}

        # Payloads should be retrieved regardless of outcome, so we can both
        # recover partial output (that could have been generated early in a
        # block, before an error) and clear the payload system always.
        reply_content[u'payload'] = shell.payload_manager.read_payload()
        # Be agressive about clearing the payload because we don't want
        # it to sit in memory until the next execute_request comes in.
        shell.payload_manager.clear_payload()

        # Flush output before sending the reply.
        sys.stdout.flush()
        sys.stderr.flush()
        # FIXME: on rare occasions, the flush doesn't seem to make it to the
        # clients... This seems to mitigate the problem, but we definitely need
        # to better understand what's going on.
        if self._execute_sleep:
            time.sleep(self._execute_sleep)

        # Send the reply.
        reply_content = json_clean(reply_content)
        
        md['status'] = reply_content['status']
        if reply_content['status'] == 'error' and \
                        reply_content['ename'] == 'UnmetDependency':
                md['dependencies_met'] = False

        reply_msg = self.session.send(stream, u'execute_reply',
                                      reply_content, parent, metadata=md,
                                      ident=ident)
        
        self.log.debug("%s", reply_msg)

        if not silent and reply_msg['content']['status'] == u'error':
            self._abort_queues()

        self._publish_status(u'idle', parent)


class JuliaKernelApp(IPKernelApp):
    name = 'juliakernel'
    kernel_class = DottedObjectName('julia.ipkernel.JuliaKernel')

#-----------------------------------------------------------------------------
# Application entry point
#-----------------------------------------------------------------------------

def main(init_julia=True):
    """Run a JuliaKernel as an application"""
    app = JuliaKernelApp.instance(init_julia)
    app.initialize()
    app.start()

#-----------------------------------------------------------------------------
# Script entry point
#-----------------------------------------------------------------------------

if __name__ == '__main__':
    main()
