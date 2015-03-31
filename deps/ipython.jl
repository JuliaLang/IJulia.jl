# return (ipython, version) tuple, where ipython is the string of the
# IPython executable, and version is the VersionNumber.
function find_ipython()
    ipycmds = ("ipython", "ipython2", "ipython3", "ipython.bat")

    for ipy in ipycmds
        try
            return (ipy, convert(VersionNumber, chomp(readall(`$ipy --version`))))
        end
    end
    return (nothing, nothing)
end
