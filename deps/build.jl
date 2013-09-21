# TODO: Build IPython 1.0 dependency? (wait for release?)

#######################################################################

# print to stderr, since that is where Pkg prints its messages
eprintln(x...) = println(STDERR, x...)

# on OSX, make sure PATH changes in profile are used in detecting ipython
const ipython = @osx ? chomp(readall(`bash -lc "which ipython"`)) : "ipython"

ipyvers = try
    convert(VersionNumber, chomp(readall(`$ipython --version`)))
catch e
    error("IPython is required for IJulia, got error $e")
end

if ipyvers < v"1.0.0-dev"
    error("IPython 1.0 or later is required for IJulia, got $ipyvers instead")
else
    eprintln("Found IPython version $ipyvers ... ok.")
end

#######################################################################
# Create Julia profile for IPython and fix the config options.

# create julia profile (no-op if we already have one)
eprintln("Creating julia profile in IPython...")
run(`$ipython profile create julia`)

juliaprof = chomp(readall(`$ipython locate profile julia`))

# set c.$s in prof file to val, or nothing if it is already set
# unless overwrite is true
function add_config(prof::String, s::String, val, overwrite=false)
    p = joinpath(juliaprof, prof)
    r = Regex(string("^[ \\t]*c\\.", replace(s, r"\.", "\\."), "\\s*=.*\$"), "m")
    if isfile(p)
        c = readall(p)
        if ismatch(r, c)
            m = replace(match(r, c).match, r"\s*$", "")
            if !overwrite || m[search(m,'c'):end] == "c.$s = $val"
                eprintln("(Existing $s setting in $prof is untouched.)")
            else
                eprintln("Changing $s to $val in $prof...")
                open(p, "w") do f
                    print(f, replace(c, r, old -> "# $old"))
                    print(f, """
c.$s = $val
""")
                end
            end
        else
            eprintln("Adding $s = $val to $prof...")
            open(p, "a") do f
                print(f, """
        
c.$s = $val
""")
            end
        end
    else
        eprintln("Creating $prof with $s = $val...")
        open(p, "w") do f
            print(f, """
c = get_config()
c.$s = $val
""")
        end
    end
end

# add Julia kernel manager if we don't have one yet
add_config("ipython_config.py", "KernelManager.kernel_cmd",
           """["$(escape_string(joinpath(JULIA_HOME,(@windows?"julia.bat":"julia-basic"))))", "$(escape_string(joinpath(Pkg.dir("IJulia"),"src","kernel.jl")))", "{connection_file}"]""",
           true)

# make qtconsole require shift-enter to complete input
add_config("ipython_qtconsole_config.py",
           "IPythonWidget.execute_on_complete_input", "False")

# set Julia notebook to use a different port than IPython's 8888 by default
add_config("ipython_notebook_config.py", "NotebookApp.port", 8998)

#######################################################################
# Copying files into the correct paths in the profile lets us override
# the files of the same name in IPython.

# copy IJulia icon to profile so that IPython will use it
mkpath(joinpath(juliaprof, "static", "base", "images"))
for T in ("png", "svg")
    ipynblogo = joinpath(juliaprof, "static", "base", "images", "ipynblogo.$T")
    if !isfile(ipynblogo)
        eprintln("Copying IJulia $T logo to Julia IPython profile.")
        open(ipynblogo, "w") do f
            write(f, open(readbytes, joinpath(Pkg.dir("IJulia"), "deps",
                                              "ijulialogo.$T")))
        end
    else
        eprintln("(Existing Julia IPython $T logo file untouched.)")
    end
end

# Use our own version of tooltip to handle identifiers ending with !
# (except for line 211, tooltip.js is identical to the IPython version)
# IPython might make his configurable later, at which point the logic
# should be moved to custom.js or a config file.
mkpath(joinpath(juliaprof, "static", "notebook", "js"))
tooltipjs = joinpath(juliaprof, "static", "notebook", "js", "tooltip.js")
if !isfile(tooltipjs)
    eprintln("Copying tooltip.js to Julia IPython profile.")
    open(tooltipjs, "w") do f
        write(f, open(readbytes, joinpath(Pkg.dir("IJulia"), "deps",
                                          "tooltip.js")))
    end
else
    eprintln("(Existing tooltip.js file untouched.)")
end

# custom.js can contain custom js login that will be loaded
# with the notebook to add info and/or monkey-patch some javascript
# -- e.g. we use it to add .ipynb metadata that this is a Julia notebook
mkpath(joinpath(juliaprof, "static", "custom"))
customjs = joinpath(juliaprof, "static", "custom", "custom.js")
if !isfile(customjs)
    eprintln("Copying custom.js to Julia IPython profile.")
    open(customjs, "w") do f
        write(f, open(readbytes, joinpath(Pkg.dir("IJulia"), "deps",
                                          "custom.js")))
    end
else
    eprintln("(Existing custom.js file untouched.)")
end

#######################################################################
