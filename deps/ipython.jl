# return (ipython, version) tuple, where ipython is the string of the
# IPython executable, and version is the VersionNumber.
function find_ipython()
    try
        "ipython",convert(VersionNumber, chomp(readall(`ipython --version`)))
    catch e1
        try
            "ipython2",convert(VersionNumber, chomp(readall(`ipython2 --version`)))
        catch e2
            try
                "ipython3",convert(VersionNumber, chomp(readall(`ipython3 --version`)))
            catch e3
                try
                    "ipython.bat",convert(VersionNumber, chomp(readall(`ipython.bat --version`)))
                catch e4
                    error("IPython is required for IJulia, got errors\n",
                          "   $e1\n   $e2\n   $e3" * (is_windows() ? "\n$e4\n" : "") )
                end
            end
        end
    end
end
