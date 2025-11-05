using Preferences

# Initialized to empty string; will be lazily set on first use (e.g., notebook())
# or explicitly via update_jupyter_path()
JUPYTER::String = ""

# Get the IJULIA_DEBUG setting from environment variable.
function ijulia_debug()
    debug_val = lowercase(get(ENV, "IJULIA_DEBUG", "0"))
    return debug_val in ("1", "true", "yes")
end

# Load the user's Jupyter preference.
# Returns the stored Jupyter path, or empty string if not set.
function load_jupyter_preference()
    # Check Preferences.jl location first
    pref = @load_preference("jupyter", nothing)
    if pref !== nothing
        return pref
    end

    # Backwards compat: check old .julia/prefs location
    old_prefsfile = joinpath(first(DEPOT_PATH), "prefs", "IJulia")
    if isfile(old_prefsfile)
        jupyter = readchomp(old_prefsfile)
        # Migrate to Preferences.jl
        @set_preferences!("jupyter" => jupyter)
        return jupyter
    end

    return ""
end

# Determine the Jupyter executable path based on environment variables and preferences.
function determine_jupyter_path()
    condajupyter = get_Conda() do Conda
        normpath(Conda.SCRIPTDIR, exe("jupyter"))
    end

    # Get user preference from environment or stored preference
    jupyter = get(load_jupyter_preference, ENV, "JUPYTER")

    # Default to "jupyter" on Unix (non-Apple) if nothing is set
    if isempty(jupyter)
        jupyter = Sys.isunix() && !Sys.isapple() ? "jupyter" : condajupyter
    end

    # Validate the jupyter path
    if !isempty(condajupyter) && (isempty(jupyter) || dirname(jupyter) == abspath(dirname(condajupyter)))
        jupyter = condajupyter # will be installed if needed
    elseif isabspath(jupyter)
        if !Sys.isexecutable(jupyter)
            @warn("ignoring non-executable JUPYTER=$jupyter")
            jupyter = condajupyter
        end
    elseif jupyter != basename(jupyter) # relative path
        @warn("ignoring relative path JUPYTER=$jupyter")
        jupyter = condajupyter
    elseif Sys.which(jupyter) === nothing
        @warn("JUPYTER=$jupyter not found in PATH")
    end

    return jupyter
end

"""
    update_jupyter_path([jupyter::String])

Set or determine the Jupyter executable path preference and save it.

If `jupyter` is provided, that path is saved directly. Otherwise, the function
automatically determines the Jupyter path by checking (in order):
1. `ENV["JUPYTER"]` environment variable
2. Previously saved preference
3. System default (Conda-based Jupyter or system `jupyter`)

The saved preference will be used by `IJulia.notebook()` and `IJulia.jupyterlab()`.

Returns the Jupyter path that was saved.

## Examples
```julia
using IJulia

# Auto-detect Jupyter path (checks ENV, saved prefs, system default)
IJulia.update_jupyter_path()

# Explicitly set Jupyter path
IJulia.update_jupyter_path("/usr/local/bin/jupyter")

# Use Conda Jupyter (empty string triggers auto-detection)
IJulia.update_jupyter_path("")
```
"""
function update_jupyter_path(jupyter::Union{String,Nothing} = nothing)
    if jupyter === nothing
        jupyter = determine_jupyter_path()
    elseif isempty(jupyter)
        # Empty string means "auto-detect" for convenience
        jupyter = determine_jupyter_path()
    end

    @set_preferences!("jupyter" => jupyter)
    global JUPYTER = jupyter
    @info "Jupyter path updated: $jupyter"
    return jupyter
end
