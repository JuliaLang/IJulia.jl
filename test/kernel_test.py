import os
import unittest
import typing as t

import jupyter_kernel_test
import jupyter_client
from jupyter_client import KernelManager, BlockingKernelClient

# A little bit of hackery to fix the version number sent by the client. See:
# https://github.com/jupyter/jupyter_client/pull/1054
jupyter_client.session.protocol_version = "5.4"

# This is a modified version of jupyter_client.start_new_kernel() that uses an
# existing kernel from a connection file rather than trying to launch one.
def start_new_kernel2(
    startup_timeout: float = 1, kernel_name: str = "python", **kwargs: t.Any
) -> t.Tuple[KernelManager, BlockingKernelClient]:
    """Start a new kernel, and return its Manager and Client"""
    connection_file = os.environ["IJULIA_TESTS_CONNECTION_FILE"]

    km = KernelManager(owns_kernel=False)
    km.load_connection_file(connection_file)
    km._connect_control_socket()

    kc = BlockingKernelClient()
    kc.load_connection_file(connection_file)

    kc.start_channels()
    try:
        kc.wait_for_ready(timeout=startup_timeout)
    except RuntimeError:
        kc.stop_channels()
        km.shutdown_kernel()
        raise

    return km, kc

# Modified version of:
# https://github.com/jupyter/jupyter_kernel_test/blob/main/test_ipykernel.py
#
# We skip the pager and history tests because they aren't supporteed.
class IJuliaTests(jupyter_kernel_test.KernelTests):
    # Required --------------------------------------

    # The name identifying an installed kernel to run the tests against
    kernel_name = "IJuliaKernel"

    # Optional --------------------------------------

    # language_info.name in a kernel_info_reply should match this
    language_name = "julia"

    # the normal file extension (including the leading dot) for this language
    # checked against language_info.file_extension in kernel_info_reply
    file_extension = ".jl"

    # Code in the kernel's language to write "hello, world" to stdout
    code_hello_world = 'println("hello, world")'

    # code which should cause (any) text to be written to STDERR
    code_stderr = 'println(stderr, "foo")'

    # samples for the autocompletion functionality
    # for each dictionary, `text` is the input to try and complete, and
    # `matches` the list of all complete matching strings which should be found
    completion_samples = [
        {
            "text": "zi",
            "matches": {"zip"},
        },
    ]

    # samples for testing code-completeness (used by console only)
    # these samples should respectively be unambiguously complete statements
    # (which should be executed on <enter>), incomplete statements or code
    # which should be identified as invalid
    complete_code_samples = ["1", 'print("hello, world")', "f(x) = x*2"]
    incomplete_code_samples = ['print("hello', "f(x) = x*"]
    invalid_code_samples = ["import = 7q"]

    # code which should generate a (user-level) error in the kernel, and send
    # a traceback to the client
    code_generate_error = "error(42)"

    # Samples of code which generate a result value (ie, some text
    # displayed as Out[n])
    code_execute_result = [{"code": "6*7", "result": "42"}]

    # Samples of code which should generate a rich display output, and
    # the expected MIME type.
    # Note that we slice down the image so it doesn't display such a massive
    # amount of text when debugging.
    code_display_data = [
        {
            "code": 'using FileIO, ImageShow; display(load("mandrill.png")[1:5, 1:5])',
            "mime": "image/png"
        },
        {
            "code": 'display(MIME("image/svg+xml"), read("plus.svg", String))',
            "mime": "image/svg+xml"
        },
        {
            "code": 'display(MIME("text/latex"), "\\frac{1}{2}")',
            "mime": "text/latex"
        },
        {
            "code": 'display(MIME("text/markdown"), "# header")',
            "mime": "text/markdown"
        },
        {
            "code": 'display(MIME("text/html"), "<b>foo</b>")',
            "mime": "text/html"
        },
        {
            "code": 'display("foo")',
            "mime": "text/plain"
        }
    ]

    # test the support for object inspection
    # the sample should be a name about which the kernel can give some help
    # information (a built-in function is probably a good choice)
    # only the default inspection level (equivalent to ipython "obj?")
    # is currently tested
    code_inspect_sample = "zip"

    # a code sample which should cause a `clear_output` message to be sent to
    # the client
    code_clear_output = "IJulia.clear_output()"

    @classmethod
    def setUpClass(cls) -> None:
        cls.km, cls.kc = start_new_kernel2(kernel_name=cls.kernel_name)

if __name__ == "__main__":
    unittest.main()
