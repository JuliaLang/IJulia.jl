module IPythonDisplay

using IJulia
import IJulia: send_ipython, publish, msg_pub, execute_msg, display_dict

using MIMEDisplay
import MIMEDisplay: display
export display, InlineDisplay

immutable InlineDisplay <: Display end

# supported MIME types for inline display in IPython, in descending order
# of preference (descending "richness")
const ipy_mime = [ "text/html", "text/latex", "image/svg+xml", "image/png", "image/jpeg", "text/plain" ]

for mime in ipy_mime
    @eval begin
        function display(d::InlineDisplay, ::@MIME($mime), x)
            send_ipython(publish, 
                         msg_pub(execute_msg, "display_data",
                                 ["source" => "julia", # optional
                                  "metadata" => Dict(), # optional
                                  "data" => [$mime => mime_string_repr(MIME($mime), x)] ]))
        end
    end
end

# override display to send IPython a dictionary of all supported
# output types, so that IPython can choose what to display.
function display(d::InlineDisplay, x)
    send_ipython(publish, 
                 msg_pub(execute_msg, "display_data",
                         ["source" => "julia", # optional
                          "metadata" => Dict(), # optional
                          "data" => display_dict(x) ]))
end

end # module
