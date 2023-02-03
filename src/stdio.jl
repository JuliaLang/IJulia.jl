function send_callback(name, data)
    send_ipython(
        publish[],
        msg_pub(
            execute_msg,
            "stream",
            Dict("name" => name, "text" => data)
        )
    )
end
