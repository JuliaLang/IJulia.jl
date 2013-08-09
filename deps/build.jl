# TODO: Build IPython 1.0 dependency? (wait for release?)

# print to stderr, since that is where Pkg prints its messages
eprintln(x...) = println(STDERR, x...)

ipyvers = try
    v = split(chomp(readall(`ipython --version`)),r"[\.-]")
    if length(v) == 4
        VersionNumber(int(v[1]), int(v[2]), int(v[3]), (v[4],), ())
    else
        VersionNumber(map(int, v)...)
    end
catch e
    error("IPython is required for IJulia, got error $e")
end

if ipyvers < v"1.0.0-dev"
    error("IPython 1.0 or later is required for IJulia, got $ipyvers instead")
else
    eprintln("Found IPython version $ipyvers ... ok.")
end

# create julia profile (no-op if we already have one)
eprintln("Creating julia profile in IPython...")
run(`ipython profile create julia`)

# add Julia kernel manager if we don't have one yet
juliaprof = chomp(readall(`ipython locate profile julia`))
juliaconf = joinpath(juliaprof, "ipython_config.py")
if !ismatch(r"^\s*c\.KernelManager\.kernel_cmd\s*="m, readall(juliaconf))
    eprintln("Adding KernelManager.kernel_cmd to Julia IPython configuration")
    open(juliaconf, "a") do f
        print(f, """

c.KernelManager.kernel_cmd = ["$(joinpath(JULIA_HOME,"julia-release-basic"))", "$(joinpath(Pkg2.dir("IJulia"),"src","kernel.jl"))", "{connection_file}"]
""")
    end
else
    eprintln("(Existing KernelManager.kernel_cmd setting is untouched.)")
end

# make qtconsole require shift-enter to complete input
qtconf = joinpath(juliaprof, "ipython_qtconsole_config.py")
if isfile(qtconf)
    if !ismatch(r"^\s*c\.IPythonWidget\.execute_on_complete_input\s*="m,
                readall(qtconf))
        eprintln("Adding execute_on_complete_input = False to qtconsole config")
        open(qtconf, "a") do f
            print(f, """

c.IPythonWidget.execute_on_complete_input = False
""")
        end
    else
        eprintln("(Existing execute_on_complete_input qtconsole setting untouched.)")
    end
else
    eprintln("Creating qtconsole config with execute_on_complete_input = False")
    open(qtconf, "w") do f
        print(f, """
c = get_config()
c.IPythonWidget.execute_on_complete_input = False
""")
    end
end

# copy IJulia icon to profile so that IPython will use it
mkpath(joinpath(juliaprof, "static", "base", "images"))
for T in ("png", "svg")
    ipynblogo = joinpath(juliaprof, "static", "base", "images", "ipynblogo.$T")
    if !isfile(ipynblogo)
        eprintln("Copying IJulia $T logo to Julia IPython profile.")
        open(ipynblogo, "w") do f
            write(f, open(readbytes, joinpath(Pkg2.dir("IJulia"), "deps",
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
        write(f, open(readbytes, joinpath(Pkg2.dir("IJulia"), "deps",
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
        write(f, open(readbytes, joinpath(Pkg2.dir("IJulia"), "deps",
                                          "custom.js")))
    end
else
    eprintln("(Existing custom.js file untouched.)")
end
