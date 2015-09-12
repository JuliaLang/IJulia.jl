# return (jupyter, version) tuple, where jupyter is the string of the
# Jupyter or IPython executable, and version is the VersionNumber.
function find_jupyter()
    try
        "jupyter",convert(VersionNumber, chomp(readall(`jupyter kernelspec --version`)))
    catch e1
        try
            "ipython",convert(VersionNumber, chomp(readall(`ipython --version`)))
        catch e2
            try
                "ipython2",convert(VersionNumber, chomp(readall(`ipython2 --version`)))
            catch e3
                try
                    "ipython3",convert(VersionNumber, chomp(readall(`ipython3 --version`)))
                catch e4
                    try
                        "ipython.bat",convert(VersionNumber, chomp(readall(`ipython.bat --version`)))
                    catch e5
                        error("Jupyter or IPython is required for IJulia, got errors\n",
                              "   $e1\n   $e2\n   $e3\n   $e4" * (@windows ? "\n$e5\n" : "") )
                    end
                end
            end
        end
    end
end
