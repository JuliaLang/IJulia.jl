import PrecompileTools: @compile_workload

# This key is used by the tests and precompilation workload to keep some
# consistency in the message signatures.
const _TEST_KEY = "a0436f6c-1916-498b-8eb9-e81ab9368e84"

# How to update the precompilation workload:
# 1. Uncomment the `@show` expressions in `recv_ipython()` in msg.jl.
# 2. Uncomment the call to `run_precompile()` in tests/kernel.jl (and comment
#    out the rest of the tests if you like).
# 3. When the `run_precompile()` runs it will print out the contents of the
#    received messages as strings. You can copy these verbatim into the
#    precompilation workload below. Note that if you modify any step of the
#    workload you will need to update *all* the messages to ensure they have the
#    right parent headers/signatures.
@compile_workload begin
    local profile = create_profile(45_000; key=_TEST_KEY)

    __init__()

    mktemp() do path, io
        write(io, JSONX.json(profile))
        flush(io)

        Kernel(path; capture_stdout=true, capture_stderr=false, capture_stdin=false) do kernel
            # Connect as a client to the kernel
            requests_socket = ZMQ.Socket(ZMQ.DEALER)
            ip = profile["ip"]
            port = profile["shell_port"]
            ZMQ.connect(requests_socket, "tcp://$(ip):$(port)")

            # Kernel info
            idents = ["626c4427-479d61edd6b98ccca470f2d6"]
            signature = "306b616a72292e9a736fe42b3c7d6fd51e10653ea2c5bc8f33810a06d33df8b5"
            header = "{\"msg_id\": \"626c4427-479d61edd6b98ccca470f2d6_3346283_0\", \"msg_type\": \"kernel_info_request\", \"username\": \"james\", \"session\": \"626c4427-479d61edd6b98ccca470f2d6\", \"date\": \"2025-11-02T18:59:07.097698Z\", \"version\": \"5.4\"}"
            parent_header = "{}"
            metadata = "{}"
            content = "{}"

            ZMQ.send_multipart(requests_socket, [only(idents), "<IDS|MSG>", signature, header, parent_header, metadata, content])
            ZMQ.recv_multipart(requests_socket, String)

            # Completion request
            idents = ["626c4427-479d61edd6b98ccca470f2d6"]
            signature = "721d3988d167417f9f0f03a823d3870470a5d924184a9a07dff422d8993eefa8"
            header = "{\"msg_id\": \"626c4427-479d61edd6b98ccca470f2d6_3346283_1\", \"msg_type\": \"complete_request\", \"username\": \"james\", \"session\": \"626c4427-479d61edd6b98ccca470f2d6\", \"date\": \"2025-11-02T18:59:07.587641Z\", \"version\": \"5.4\"}"
            parent_header = "{}"
            metadata = "{}"
            content = "{\"code\": \"mk\", \"cursor_pos\": 2}"

            ZMQ.send_multipart(requests_socket, [only(idents), "<IDS|MSG>", signature, header, parent_header, metadata, content])
            ZMQ.recv_multipart(requests_socket, String)

            # Execute `42`
            idents = ["626c4427-479d61edd6b98ccca470f2d6"]
            signature = "01e135a939f00a11708ca906c6a16ce1226ad07669b7dad49c12c4b792ef6242"
            header = "{\"msg_id\": \"626c4427-479d61edd6b98ccca470f2d6_3346283_2\", \"msg_type\": \"execute_request\", \"username\": \"james\", \"session\": \"626c4427-479d61edd6b98ccca470f2d6\", \"date\": \"2025-11-02T18:59:14.947227Z\", \"version\": \"5.4\"}"
            parent_header = "{}"
            metadata = "{}"
            content = "{\"code\": \"42\", \"silent\": false, \"store_history\": true, \"user_expressions\": {}, \"allow_stdin\": true, \"stop_on_error\": true}"

            ZMQ.send_multipart(requests_socket, [only(idents), "<IDS|MSG>", signature, header, parent_header, metadata, content])
            ZMQ.recv_multipart(requests_socket, String)

            # Execute `?import`
            idents = ["626c4427-479d61edd6b98ccca470f2d6"]
            signature = "a0fc54c9ed7250e8a151a766c7293843a1b8f91b1d766579a4761c18f34862df"
            header = "{\"msg_id\": \"626c4427-479d61edd6b98ccca470f2d6_3346283_3\", \"msg_type\": \"execute_request\", \"username\": \"james\", \"session\": \"626c4427-479d61edd6b98ccca470f2d6\", \"date\": \"2025-11-02T18:59:15.621963Z\", \"version\": \"5.4\"}"
            parent_header = "{}"
            metadata = "{}"
            content = "{\"code\": \"?import\", \"silent\": false, \"store_history\": true, \"user_expressions\": {}, \"allow_stdin\": true, \"stop_on_error\": true}"

            ZMQ.send_multipart(requests_socket, [only(idents), "<IDS|MSG>", signature, header, parent_header, metadata, content])
            ZMQ.recv_multipart(requests_socket, String)

            # Execute `error("foo")`
            idents = ["626c4427-479d61edd6b98ccca470f2d6"]
            signature = "7c7810bce6ff448c3ad8b0c928822d03ad8baf838e417ea5c29ec620a2cc36a7"
            header = "{\"msg_id\": \"626c4427-479d61edd6b98ccca470f2d6_3346283_4\", \"msg_type\": \"execute_request\", \"username\": \"james\", \"session\": \"626c4427-479d61edd6b98ccca470f2d6\", \"date\": \"2025-11-02T18:59:18.648766Z\", \"version\": \"5.4\"}"
            parent_header = "{}"
            metadata = "{}"
            content = "{\"code\": \"error(\\\"foo\\\")\", \"silent\": false, \"store_history\": true, \"user_expressions\": {}, \"allow_stdin\": true, \"stop_on_error\": true}"

            ZMQ.send_multipart(requests_socket, [only(idents), "<IDS|MSG>", signature, header, parent_header, metadata, content])
            ZMQ.recv_multipart(requests_socket, String)

            # Get history
            idents = ["626c4427-479d61edd6b98ccca470f2d6"]
            signature = "1d4bc84a2efb28efa0e8efe8eba32bc6b84decfd55d95e765b062a1adae2ae62"
            header = "{\"msg_id\": \"626c4427-479d61edd6b98ccca470f2d6_3346283_5\", \"msg_type\": \"history_request\", \"username\": \"james\", \"session\": \"626c4427-479d61edd6b98ccca470f2d6\", \"date\": \"2025-11-02T18:59:18.813677Z\", \"version\": \"5.4\"}"
            parent_header = "{}"
            metadata = "{}"
            content = "{\"raw\": true, \"output\": false, \"hist_access_type\": \"range\", \"session\": 0, \"start\": 0}"

            ZMQ.send_multipart(requests_socket, [only(idents), "<IDS|MSG>", signature, header, parent_header, metadata, content])
            ZMQ.recv_multipart(requests_socket, String)

            # Get comm info
            idents = ["626c4427-479d61edd6b98ccca470f2d6"]
            signature = "ff8e9a57a81f5cbdebd12a34a09aad953d63e24e0c866fc3af936a4ef764a181"
            header = "{\"msg_id\": \"626c4427-479d61edd6b98ccca470f2d6_3346283_6\", \"msg_type\": \"comm_info_request\", \"username\": \"james\", \"session\": \"626c4427-479d61edd6b98ccca470f2d6\", \"date\": \"2025-11-02T18:59:18.953835Z\", \"version\": \"5.4\"}"
            parent_header = "{}"
            metadata = "{}"
            content = "{}"

            ZMQ.send_multipart(requests_socket, [only(idents), "<IDS|MSG>", signature, header, parent_header, metadata, content])
            ZMQ.recv_multipart(requests_socket, String)

            close(requests_socket)
        end
    end

    # Clear global variables
    empty!(_preexecute_hooks)
    empty!(_postexecute_hooks)
    empty!(_posterror_hooks)
end

# This function is executed by Jupyter so make sure that it's precompiled
precompile(run_kernel, ())

# Precompile all the handlers
for f in values(handlers)
    precompile(f, (ZMQ.Socket, Kernel, Msg))
end
