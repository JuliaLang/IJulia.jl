module IPythonDataDisplay

using IPythonKernel
import IPythonKernel: send_ipython, publish, msg_pub, execute_msg, display_dict

using DataDisplay
import DataDisplay: display_html, display_svg, display_png, display_jpeg, display_latex, display_javascript, display, Display
export display_html, display_svg, display_png, display_jpeg, display_latex, display_javascript, display, InlineDisplay

immutable InlineDisplay <: Display end

for (fmt,mime) in DataDisplay.formats
    display_fmt = symbol(string("display_", fmt))
    string_fmt = symbol(string("string_", fmt))
    @eval begin
        function $display_fmt(d::InlineDisplay, x)
            send_ipython(publish, 
                         msg_pub(execute_msg, "display_data",
                                 [#"source" => "julia", # optional
                                  #"metadata" => Dict(), # optional
                                  "data" => [$mime => $string_fmt(x)] ]))
        end
    end
end

# override display to send IPython a dictionary of all supported
# output types, so that IPython can choose what to display.
function display(d::InlineDisplay, x)
    send_ipython(publish, 
                 msg_pub(execute_msg, "display_data",
                         [#"source" => "julia", # optional
                          #"metadata" => Dict(), # optional
                          "data" => display_dict(x) ]))
end

end # module
