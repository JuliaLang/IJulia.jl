#######################################################################
import JSON
using Compat

# print to stderr, since that is where Pkg prints its messages
eprintln(x...) = println(STDERR, x...)

# Make sure Python uses UTF-8 output for Unicode paths
ENV["PYTHONIOENCODING"] = "UTF-8"

include("ipython.jl")
const ipython, ipyvers = find_ipython()

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
function add_config(prof::String, s::String, val; overwrite::Bool=false)
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

add_config("ipython_config.py", "KernelManager.kernel_cmd",
           kernelcmd,
           overwrite=true)

# make qtconsole require shift-enter to complete input
add_config("ipython_qtconsole_config.py",
           "IPythonWidget.execute_on_complete_input", "False")

add_config("ipython_qtconsole_config.py",
           "FrontendWidget.lexer_class", "'pygments.lexers.JuliaLexer'")

# set Julia notebook to use a different port than IPython's 8888 by default
add_config("ipython_notebook_config.py", "NotebookApp.port", 8998)

#######################################################################
# Copying files into the correct paths in the profile lets us override
# the files of the same name in IPython.

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

juliakspec = joinpath(chomp(readall(`$ipython locate`)), "kernels", "julia-$(VERSION.major).$(VERSION.minor)"*debugdesc)


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
