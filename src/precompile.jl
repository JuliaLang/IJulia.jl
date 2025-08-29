import PrecompileTools: @compile_workload

# This key is used by the tests and precompilation workload to keep some
# consistency in the message signatures.
const _TEST_KEY = "a0436f6c-1916-498b-8eb9-e81ab9368e84"

# How to update the precompilation workload:
# 1. Uncomment the `@show` expressions in `recv_ipython()` in msg.jl.
# 2. Copy this workload into tests/kernel.jl and update as desired:
#
#    Kernel(profile; capture_stdout=false, capture_stderr=false) do kernel
#        jupyter_client(profile) do client
#            kernel_info(client)
#            execute(client, "42")
#            execute(client, "?import")
#            execute(client, """error("foo")""")
#        end
#    end
#
# 3. When the above runs it will print out the contents of the received messages
#    as strings. You can copy these verbatim into the precompilation workload
#    below. Note that if you modify any step of the workload you will need to
#    update *all* the messages to ensure they have the right parent
#    headers/signatures.
@compile_workload begin
    local profile = create_profile(45_000; key=_TEST_KEY)

    __init__()

    mktemp() do path, io
        JSON.print(io, profile)
        flush(io)

        Kernel(path; capture_stdout=true, capture_stderr=false, capture_stdin=false) do kernel
            # Connect as a client to the kernel
            requests_socket = ZMQ.Socket(ZMQ.DEALER)
            ip = profile["ip"]
            port = profile["shell_port"]
            ZMQ.connect(requests_socket, "tcp://$(ip):$(port)")

            # kernel_info
            idents = ["a1cd3a77-85e3881309b0cc3701e51156"]
            signature = "af03588308cec89e76d0568134c0eaf24e9fe869aac729d5b9aed6baac6d369b"
            header = "{\"msg_id\": \"a1cd3a77-85e3881309b0cc3701e51156_1694526_0\", \"msg_type\": \"kernel_info_request\", \"username\": \"james\", \"session\": \"a1cd3a77-85e3881309b0cc3701e51156\", \"date\": \"2025-08-29T09:54:47.389494Z\", \"version\": \"5.4\"}"
            parent_header = "{}"
            metadata = "{}"
            content = "{}"

            ZMQ.send_multipart(requests_socket, [only(idents), "<IDS|MSG>", signature, header, parent_header, metadata, content])
            ZMQ.recv_multipart(requests_socket, String)

            # Execute `42`
            idents = ["a1cd3a77-85e3881309b0cc3701e51156"]
            signature = "23df4f581ab69b5b249caced71fc0a77bcb8f5c1f4eeb88d44ca49456db16e0d"
            header = "{\"msg_id\": \"a1cd3a77-85e3881309b0cc3701e51156_1694526_1\", \"msg_type\": \"execute_request\", \"username\": \"james\", \"session\": \"a1cd3a77-85e3881309b0cc3701e51156\", \"date\": \"2025-08-29T09:54:49.546467Z\", \"version\": \"5.4\"}"
            parent_header = "{}"
            metadata = "{}"
            content = "{\"code\": \"42\", \"silent\": false, \"store_history\": true, \"user_expressions\": {}, \"allow_stdin\": true, \"stop_on_error\": true}"

            ZMQ.send_multipart(requests_socket, [only(idents), "<IDS|MSG>", signature, header, parent_header, metadata, content])
            ZMQ.recv_multipart(requests_socket, String)

            # Execute `?import`
            idents = ["a1cd3a77-85e3881309b0cc3701e51156"]
            signature = "8f2b31cc4751d17bbd4d1216180e129b0759fdc9f05e0de1e91ca03db85fc5e1"
            header = "{\"msg_id\": \"a1cd3a77-85e3881309b0cc3701e51156_1694526_2\", \"msg_type\": \"execute_request\", \"username\": \"james\", \"session\": \"a1cd3a77-85e3881309b0cc3701e51156\", \"date\": \"2025-08-29T09:54:49.951328Z\", \"version\": \"5.4\"}"
            parent_header = "{}"
            metadata = "{}"
            content = "{\"code\": \"?import\", \"silent\": false, \"store_history\": true, \"user_expressions\": {}, \"allow_stdin\": true, \"stop_on_error\": true}"

            ZMQ.send_multipart(requests_socket, [only(idents), "<IDS|MSG>", signature, header, parent_header, metadata, content])
            ZMQ.recv_multipart(requests_socket, String)

            # Execute `error("foo")`
            idents = ["a1cd3a77-85e3881309b0cc3701e51156"]
            signature = "c8415a60d32d231b582128a8f85ecce0996ee76734ab6aecf93af850d7e19e4a"
            header = "{\"msg_id\": \"a1cd3a77-85e3881309b0cc3701e51156_1694526_3\", \"msg_type\": \"execute_request\", \"username\": \"james\", \"session\": \"a1cd3a77-85e3881309b0cc3701e51156\", \"date\": \"2025-08-29T09:54:50.755285Z\", \"version\": \"5.4\"}"
            parent_header = "{}"
            metadata = "{}"
            content = "{\"code\": \"error(\\\"foo\\\")\", \"silent\": false, \"store_history\": true, \"user_expressions\": {}, \"allow_stdin\": true, \"stop_on_error\": true}"

            ZMQ.send_multipart(requests_socket, [only(idents), "<IDS|MSG>", signature, header, parent_header, metadata, content])
            ZMQ.recv_multipart(requests_socket, String)

            close(requests_socket)
        end
    end
end

# This function is executed by Jupyter so make sure that it's precompiled
precompile(run_kernel, ())

# Precompile all the handlers
for f in handlers
    precompile(f, (ZMQ.Socket, Kernel, Msg))
end
