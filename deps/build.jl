# TODO: Buld IPython 1.0 dependency? (wait for release?)

#######################################################################
import JSON
using Compat

# print to stderr, since that is where Pkg prints its messages
eprintln(x...) = println(STDERR, x...)

juliaprofiles = Array(String,0)

@windows_only begin
    ipython_version_to_install = "2.4.1"

    existing_install_tag_filename = normpath(pwd(),"usr","python342-exists")
    downloadsdir = normpath(pwd(), "downloads")
    pythonzipfilename = normpath(pwd(), "downloads", "python-3.4.2.zip")
    pyinstalldir = normpath(pwd(),"usr","python34")
    pythonexepath = normpath(pwd(),"usr","python34","python.exe")
    ijuliaprofiledir = normpath(pwd(), "usr", ".ijulia")

    upgrade_private_python = ispath(existing_install_tag_filename)

    if upgrade_private_python
        rm(existing_install_tag_filename)

        run(`$pythonexepath -m pip install -U pip`)
        run(`$pythonexepath -m pip install -U ipython[notebook]==$ipython_version_to_install`)
    else
        using BinDeps

        if ispath(downloadsdir)
            rm(downloadsdir, recursive=true)
        end

        if ispath(normpath(pwd(),"usr"))
            rm(normpath(pwd(),"usr"), recursive=true)
        end

        mkdir(downloadsdir)

        run(download_cmd("https://sourceforge.net/projects/minimalportablepython/files/python-3.4.2.zip", "$pythonzipfilename"))

        run(`7z x $pythonzipfilename -y -o$pyinstalldir`)

        run(`$pythonexepath -m ensurepip`)
        run(`$pythonexepath -m pip install -U pip`)

        run(`$pythonexepath -m pip install ipython[notebook]==$ipython_version_to_install`)
    end

    if ispath(ijuliaprofiledir)
        rm(ijuliaprofiledir, recursive=true)
    end

    run(`$pythonexepath -m IPython profile create --ipython-dir="$ijuliaprofiledir"`)

    internaljuliaprof = chomp(readall(`$pythonexepath -m IPython locate profile --ipython-dir="$ijuliaprofiledir"`))
    push!(juliaprofiles, internaljuliaprof)

    touch(existing_install_tag_filename)
end

include("ipython.jl")
const ipython, ipyvers = find_ipython()

if ipython==nothing
    if length(juliaprofiles)==0
        error("IPython 1.0 or later is required for IJulia")
    else
        eprintln("No system IPython found, using private IPython.")
    end
elseif ipyvers < v"1.0.0-dev"
    if length(juliaprofiles)==0
        error("IPython 1.0 or later is required for IJulia")
    else
        eprintln("IPython 1.0 or later is required for system IJulia, got $ipyvers instead. Skipped integration with system IPython.")
    end
else
    eprintln("Found IPython version $ipyvers ... ok.")

    # create julia profile (no-op if we already have one)
    eprintln("Creating julia profile in IPython...")
    run(`$ipython profile create julia`)

    systemjuliaprof = chomp(readall(`$ipython locate profile julia`))
    push!(juliaprofiles, systemjuliaprof)
end

# set c.$s in prof file to val, or nothing if it is already set
# unless overwrite is true
function add_config(profdir::String, prof::String, s::String, val; overwrite::Bool=false)
    p = joinpath(profdir, prof)
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

rb(filename::String) = open(readbytes, filename)
eqb(a::Vector{Uint8}, b::Vector{Uint8}) =
    length(a) == length(b) && all(a .== b)

# copy IJulia/deps/src to destpath/destname if it doesn't
# already exist at the destination, or if it has changed (if overwrite=true).
function copy_config(src::String, destpath::String,
                     destname::String=src; overwrite::Bool=true)
    mkpath(destpath)
    dest = joinpath(destpath, destname)
    srcbytes = rb(joinpath(Pkg.dir("IJulia"), "deps", src))
    if !isfile(dest) || (overwrite && !eqb(srcbytes, rb(dest)))
        eprintln("Copying $src to Julia IPython profile.")
        open(dest, "w") do f
            write(f, srcbytes)
        end
    else
        eprintln("(Existing $destname file untouched.)")
    end
end

function createijuliaprofile(juliaprof::String)
    # add Julia kernel manager if we don't have one yet
    if VERSION >= v"0.3-"
        binary_name = @windows? "julia.exe":"julia"
    else
        binary_name = @windows? "julia.bat":"julia-basic"
    end

    kernelcmd_array = [escape_string(joinpath(JULIA_HOME,("$binary_name")))]

    if VERSION >= v"0.3"
        push!(kernelcmd_array,"-i")
    end

    append!(kernelcmd_array, ["-F", escape_string(joinpath(Pkg.dir("IJulia"),"src","kernel.jl")), "{connection_file}"])



    kernelcmd = JSON.json(kernelcmd_array)

    add_config(juliaprof, "ipython_config.py", "KernelManager.kernel_cmd",
               kernelcmd,
               overwrite=true)

    # make qtconsole require shift-enter to complete input
    add_config(juliaprof, "ipython_qtconsole_config.py",
               "IPythonWidget.execute_on_complete_input", "False")

    add_config(juliaprof, "ipython_qtconsole_config.py",
               "FrontendWidget.lexer_class", "'pygments.lexers.JuliaLexer'")

    # set Julia notebook to use a different port than IPython's 8888 by default
    add_config(juliaprof, "ipython_notebook_config.py", "NotebookApp.port", 8998)

    #######################################################################
    # Copying files into the correct paths in the profile lets us override
    # the files of the same name in IPython.


    # copy IJulia icon to profile so that IPython will use it
    for T in ("png", "svg")
        copy_config("ijulialogo.$T",
                    joinpath(juliaprof, "static", "base", "images"),
                    "ipynblogo.$T")
    end

    # copy IJulia favicon to profile
    copy_config("ijuliafavicon.ico",
                joinpath(juliaprof, "static", "base", "images"),
                "favicon.ico")

    # On IPython < 3.
    # custom.js can contain custom js login that will be loaded
    # with the notebook to add info and/or monkey-patch some javascript
    # -- e.g. we use it to add .ipynb metadata that this is a Julia notebook

    # on IPython 3+, still upgrade custom.js because old version can prevent
    # notebook from loading.
    # todo: maybe do not copy if don't exist.
    # todo: maybe remove if user custom.js is identical to the one
    # shipped with IJulia ?
    copy_config("custom.js", joinpath(juliaprof, "static", "custom"))

    # julia.js implements a CodeMirror mode for Julia syntax highlighting in the notebook.
    # Eventually this will ship with CodeMirror and hence IPython, but for now we manually bundle it.

    copy_config("julia.js", joinpath(juliaprof, "static", "components", "codemirror", "mode", "julia"))

    #######################################################################
    #       Part specific to Jupyter/IPython 3.0 and above
    #######################################################################

    #Is IJulia being built from a debug build? If so, add "debug" to the description
    debugdesc = ccall(:jl_is_debugbuild,Cint,())==1 ? " debug" : ""

    juliakspec = joinpath(chomp(readall(`$ipython locate`)), "kernels", "julia $(VERSION.major).$(VERSION.minor)"*debugdesc)


    ks = @compat Dict(
        "argv" => kernelcmd_array,
        "display_name" => "Julia " * Base.VERSION_STRING * debugdesc,
        "language" => "julia",
    )

    destname = "kernel.json"
    mkpath(juliakspec)
    dest = joinpath(juliakspec, destname)


    eprintln("Writing IJulia kernelspec to $dest ...")

    open(dest, "w") do f
        # indent by 2 for readability of file
        write(f, JSON.json(ks, 2))
    end
    copy_config("logo-32x32.png", juliakspec)
    copy_config("logo-64x64.png", juliakspec)
end

#######################################################################
# Create Julia profiles for IPython and fix the config options.

for profiledir in juliaprofiles
    createijuliaprofile(profiledir)
end
