function execute_request(socket, msg)
    user_variables = Dict() # TODO
    user_expressions = Dict() # TODO
    result = try 
        println("Executing ", msg.content["code"])
        eval(parse(msg.content["code"]))
    catch
        nothing
    end
    send_ipython(requests, msg_reply(msg, "execute_reply",
                                     ["status" => "ok",
                                      "execution_count" => _n,
                                      "payload" => [],
                                      "user_variables" => user_variables,
                                      "user_expressions" => user_expressions]))
    send_ipython(publish, 
                 msg_pub(msg, "pyout",
                         ["execution_count" => _n,
                          "data" => [ "text/plain" => repr(result) ]
                          ]))
end

const handlers = (String=>Function)[
                                    "execute_request" => execute_request
                                    ]
