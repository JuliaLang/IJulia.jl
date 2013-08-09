# TODO: Build IPython 1.0 dependency? (wait for release?)

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
    println("Found IPython version $ipyvers ... ok.")
end

# create julia profile (no-op if we already have one)
println("Creating julia profile in IPython...")
run(`ipython profile create julia`)

# add Julia kernel manager if we don't have one yet
juliaprof = chomp(readall(`ipython locate profile julia`))
juliaconf = joinpath(juliaprof, "ipython_config.py")
if !ismatch(r"^\s*c\.KernelManager\.kernel_cmd\s*="m, readall(juliaconf))
    println("Adding KernelManager.kernel_cmd to Julia IPython configuration")
    open(juliaconf, "a") do f
        print(f, """

c.KernelManager.kernel_cmd = ["$(joinpath(JULIA_HOME,"julia-release-basic"))", "$(joinpath(Pkg2.dir("IJulia"),"src","kernel.jl"))", "{connection_file}"]
""")
    end
else
    println("(Existing KernelManager.kernel_cmd setting is untouched.)")
end

# make qtconsole require shift-enter to complete input
qtconf = joinpath(juliaprof, "ipython_qtconsole_config.py")
if isfile(qtconf)
    if !ismatch(r"^\s*c\.IPythonWidget\.execute_on_complete_input\s*="m,
                readall(qtconf))
        println("Adding execute_on_complete_input = False to qtconsole config")
        open(qtconf, "a") do f
            print(f, """

c.IPythonWidget.execute_on_complete_input = False
""")
        end
    else
        println("(Existing execute_on_complete_input qtconsole setting untouched.)")
    end
else
    println("Creating qtconsole config with execute_on_complete_input = False")
    open(qtconf, "w") do f
        print(f, """
c = get_config()
c.IPythonWidget.execute_on_complete_input = False
""")
    end
end

# copy IJulia icon to profile so that IPython will use it
mkpath(joinpath(juliaprof, "static", "base", "images"))
ipynblogo = joinpath(juliaprof, "static", "base", "images", "ipynblogo.png")
if !isfile(ipynblogo)
    println("Copying IJulia logo to Julia IPython profile.")
    open(ipynblogo, "w") do f
        write(f, open(readbytes, joinpath(Pkg2.dir("IJulia"), "deps",
                                          "ijulialogo.png")))
    end
else
    println("(Existing Julia IPython logo file untouched.)")
end
