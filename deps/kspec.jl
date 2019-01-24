import JSON

#######################################################################
# Install Jupyter kernel-spec files.

copy_config(src, dest) = cp(src, joinpath(dest, basename(src)), force=true)

# return the user kernelspec directory, according to
#     https://jupyter-client.readthedocs.io/en/latest/kernels.html#kernelspecs
@static if Sys.iswindows()
    function appdata() # return %APPDATA%
        path = zeros(UInt16, 300)
        CSIDL_APPDATA = 0x001a
        result = ccall((:SHGetFolderPathW,:shell32), stdcall, Cint,
            (Ptr{Cvoid},Cint,Ptr{Cvoid},Cint,Ptr{UInt8}),C_NULL,CSIDL_APPDATA,C_NULL,0,path)
        return result == 0 ? transcode(String, resize!(path, findfirst(iszero, path)-1)) : get(ENV, "APPDATA", "")
    end
    function default_jupyter_data_dir()
        APPDATA = appdata()
        return !isempty(APPDATA) ? joinpath(APPDATA, "jupyter") : joinpath(get(ENV, "JUPYTER_CONFIG_DIR", joinpath(homedir(), ".jupyter")), "data")
    end
elseif Sys.isapple()
    default_jupyter_data_dir() = joinpath(homedir(), "Library/Jupyter")
else
    function default_jupyter_data_dir()
        xdg_data_home = get(ENV, "XDG_DATA_HOME", "")
        data_home = !isempty(xdg_data_home) ? xdg_data_home : joinpath(homedir(), ".local", "share")
        joinpath(data_home, "jupyter")
    end
end

function jupyter_data_dir()
    env_data_dir = get(ENV, "JUPYTER_DATA_DIR", "")
    !isempty(env_data_dir) ? env_data_dir : default_jupyter_data_dir()
end

kerneldir() = joinpath(jupyter_data_dir(), "kernels")


exe(s::AbstractString) = Sys.iswindows() ? "$s.exe" : s
 
"""
    installkernel(name::AbstractString, options::AbstractString...;
                  specname::AbstractString,
                  env=Dict())

Install a new Julia kernel, where the given `options` are passed to the `julia`
executable, the user-visible kernel name is given by `name` followed by the
Julia version, and the `env` dictionary is added to the environment.

The new kernel name is returned by `installkernel`.  For example:
```
kernelpath = installkernel("Julia O3", "-O3", env=Dict("FOO"=>"yes"))
```
creates a new Julia kernel in which `julia` is launched with the `-O3`
optimization flag and `FOO=yes` is included in the environment variables.

The returned `kernelpath` is the path of the installed kernel directory, something like `/...somepath.../kernels/julia-O3-1.0`
(in Julia 1.0).  The `specname` argument can be passed to alter the name of this
directory (which defaults to `name` with spaces replaced by hyphens).

You can uninstall the kernel by calling `rm(kernelpath, recursive=true)`.
"""
function installkernel(name::AbstractString, julia_options::AbstractString...;
                   specname::AbstractString = replace(lowercase(name), " "=>"-"),
                   env::Dict{<:AbstractString}=Dict{String,Any}())
    # Is IJulia being built from a debug build? If so, add "debug" to the description.
    debugdesc = ccall(:jl_is_debugbuild,Cint,())==1 ? "-debug" : ""

    # path of the Jupyter kernelspec directory to install
    juliakspec = joinpath(kerneldir(), "$specname-$(VERSION.major).$(VERSION.minor)$debugdesc")
    @info("Installing $name kernelspec in $juliakspec")
    rm(juliakspec, force=true, recursive=true)
    try
        kernelcmd_array = String[joinpath(Sys.BINDIR,exe("julia")), "-i",
                                 "--startup-file=yes", "--color=yes"]
        append!(kernelcmd_array, julia_options)
        ijulia_dir = get(ENV, "IJULIA_DIR", dirname(@__DIR__)) # support non-Pkg IJulia installs
        append!(kernelcmd_array, [joinpath(ijulia_dir,"src","kernel.jl"), "{connection_file}"])

        ks = Dict(
            "argv" => kernelcmd_array,
            "display_name" => name * " " * Base.VERSION_STRING * debugdesc,
            "language" => "julia",
            "env" => env,
        )

        mkpath(juliakspec)

        open(joinpath(juliakspec, "kernel.json"), "w") do f
            # indent by 2 for readability of file
            write(f, JSON.json(ks, 2))
        end

        copy_config(joinpath(ijulia_dir,"deps","logo-32x32.png"), juliakspec)
        copy_config(joinpath(ijulia_dir,"deps","logo-64x64.png"), juliakspec)

        return juliakspec
    catch
        rm(juliakspec, force=true, recursive=true)
        rethrow()
    end
end
