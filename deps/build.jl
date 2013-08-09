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
end

# create julia profile (no-op if we already have one)
run(`ipython profile create julia`)

# add Julia kernel manager if we don't have one yet
juliaprof = chomp(readall(`ipython locate profile julia`))
juliaconf = joinpath(juliaprof, "ipython_config.py")
if !ismatch(r"^\s*c\.KernelManager\.kernel_cmd\s*="m, readall(juliaconf))
    open(juliaconf, "a") do f
        print(f, """

c.KernelManager.kernel_cmd = ["$(joinpath(JULIA_HOME,"julia"))", "$(joinpath(Pkg2.dir("IJulia"),"src","kernel.jl"))", "{connection_file}"]
""")
    end
end

# make qtconsole require shift-enter to complete input
qtconf = joinpath(juliaprof, "ipython_qtconsole_config.py")
if isfile(qtconf)
    if !ismatch(r"^\s*c\.IPythonWidget\.execute_on_complete_input\s*="m,
                readall(qtconf))
        open(qtconf, "a") do f
            print(f, """

c.IPythonWidget.execute_on_complete_input = False
""")
        end
    end
else
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
    open(ipynblogo, "w") do f
        write(f, open(readbytes, joinpath(Pkg2.dir("IJulia"), "deps",
                                          "ijulialogo.png")))
    end
end
