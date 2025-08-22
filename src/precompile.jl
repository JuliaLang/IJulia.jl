import PrecompileTools: @compile_workload

# This key is used by the tests and precompilation workload to keep some
# consistency in the message signatures.
const _TEST_KEY = "a0436f6c-1916-498b-8eb9-e81ab9368e84"

# How to update the precompilation workload:
# 1. Uncomment the `@show` expressions in `recv_ipython()` in msg.jl.
# 2. Copy this workload into tests/kernel.jl and update as desired:
#
#     Kernel(profile; capture_stdout=false, capture_stderr=false) do kernel
#         jupyter_client(profile) do client
#             kernel_info(client)
#             execute(client, "42")
#             execute(client, "error(42)")
#         end
#     end
#
# 3. When the above runs it will print out the contents of the received messages
#    as strings. You can copy these verbatim into the precompilation workload
#    below. Note that if you modify any step of the workload you will need to
#    update *all* the messages to ensure they have the right parent
#    headers/signatures.
@compile_workload begin
    local profile = create_profile(45_000; key=_TEST_KEY)

    Kernel(profile; capture_stdout=false, capture_stderr=false, capture_stdin=false) do kernel
        # Connect as a client to the kernel
        requests_socket = ZMQ.Socket(ZMQ.DEALER)
        ip = profile["ip"]
        port = profile["shell_port"]
        ZMQ.connect(requests_socket, "tcp://$(ip):$(port)")

        # kernel_info
        idents = ["d2bd8e47-b2c9cd130d2967a19f52c1a3"]
        signature = "3c4f523a0e8b80e5b3e35756d75f62d12b851e1fd67c609a9119872e911f83d2"
        header = "{\"msg_id\": \"d2bd8e47-b2c9cd130d2967a19f52c1a3_3534705_0\", \"msg_type\": \"kernel_info_request\", \"username\": \"james\", \"session\": \"d2bd8e47-b2c9cd130d2967a19f52c1a3\", \"date\": \"2025-02-20T22:29:47.616834Z\", \"version\": \"5.4\"}"
        parent_header = "{}"
        metadata = "{}"
        content = "{}"

        ZMQ.send_multipart(requests_socket, [only(idents), "<IDS|MSG>", signature, header, parent_header, metadata, content])
        ZMQ.recv_multipart(requests_socket, String)

        # Execute `42`
        idents = ["d2bd8e47-b2c9cd130d2967a19f52c1a3"]
        signature = "758c034ba5efb4fd7fd5a5600f913bc634739bf6a2c1e1d87e88b008706337bc"
        header = "{\"msg_id\": \"d2bd8e47-b2c9cd130d2967a19f52c1a3_3534705_1\", \"msg_type\": \"execute_request\", \"username\": \"james\", \"session\": \"d2bd8e47-b2c9cd130d2967a19f52c1a3\", \"date\": \"2025-02-20T22:29:49.835131Z\", \"version\": \"5.4\"}"
        parent_header = "{}"
        metadata = "{}"
        content = "{\"code\": \"42\", \"silent\": false, \"store_history\": true, \"user_expressions\": {}, \"allow_stdin\": true, \"stop_on_error\": true}"

        ZMQ.send_multipart(requests_socket, [only(idents), "<IDS|MSG>", signature, header, parent_header, metadata, content])
        ZMQ.recv_multipart(requests_socket, String)

        # Execute `error(42)`
        idents = ["d2bd8e47-b2c9cd130d2967a19f52c1a3"]
        signature = "953702763b65d9b0505f34ae0eb195574b9c2c65eebedbfa8476150133649801"
        header = "{\"msg_id\": \"d2bd8e47-b2c9cd130d2967a19f52c1a3_3534705_2\", \"msg_type\": \"execute_request\", \"username\": \"james\", \"session\": \"d2bd8e47-b2c9cd130d2967a19f52c1a3\", \"date\": \"2025-02-20T22:29:50.320836Z\", \"version\": \"5.4\"}"
        parent_header = "{}"
        metadata = "{}"
        content = "{\"code\": \"error(42)\", \"silent\": false, \"store_history\": true, \"user_expressions\": {}, \"allow_stdin\": true, \"stop_on_error\": true}"

        ZMQ.send_multipart(requests_socket, [only(idents), "<IDS|MSG>", signature, header, parent_header, metadata, content])
        ZMQ.recv_multipart(requests_socket, String)

        close(requests_socket)
    end
end
