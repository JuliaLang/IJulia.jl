using Scratch: @get_scratch!

# Initialized to empty string; will be lazily set on first use (e.g., notebook())
# or explicitly via update_jupyter_path()
JUPYTER::String = ""

# Get the IJULIA_DEBUG setting from environment variable.
function ijulia_debug()
    debug_val = lowercase(get(ENV, "IJULIA_DEBUG", "0"))
    return debug_val in ("1", "true", "yes")
end

# Load the user's Jupyter preference from the Scratch space.
# Returns the stored Jupyter path, or empty string if not set.
function load_jupyter_preference()
    # Check new Scratch.jl location first
    prefsfile = preference_path("jupyter")
    if isfile(prefsfile)
        return readchomp(prefsfile)
    end

    # Backwards compat with .julia/prefs
    old_prefsfile = joinpath(first(DEPOT_PATH), "prefs", "IJulia")
    if isfile(old_prefsfile)
        return readchomp(old_prefsfile)
    end

    return ""
end

# Save the users preference to the Scratch space.
preference_path(name::String) = joinpath(@get_scratch!("prefs"), name)

function save_preference(name::String, value::String)
    prefsfile = preference_path(name)
    mkpath(dirname(prefsfile))
    write(prefsfile, value)
    return value
end

delete_preference(name::String) = rm(preference_path(name); force=true)

# Determine the Jupyter executable path based on environment variables and preferences.
function determine_jupyter_path()
    condajupyter = get_Conda() do Conda
        normpath(Conda.SCRIPTDIR, exe("jupyter"))
    end

    # Get user preference from environment or stored preference
    jupyter = get(load_jupyter_preference, ENV, "JUPYTER")

    # Default to "jupyter" on Unix (non-Apple) if nothing is set
    if isempty(jupyter)
        jupyter = Sys.isunix() && !Sys.isapple() ? "jupyter" : ""
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
    end

    return jupyter
end

"""
    update_jupyter_path()

Set or determine the Jupyter executable path preference and save it.

The function checks `ENV["JUPYTER"]` first:
- If not set: uses existing preference, or searches if no preference exists
- If set to a path: uses that path
- If set to empty string `""`: deletes existing preference and forces a fresh search

The search checks (in order):
1. `ENV["JUPYTER"]` environment variable
2. Previously saved preference (from Scratch.jl)
3. System default (Conda-based Jupyter or system `jupyter`)

The saved preference will be used by `IJulia.notebook()` and `IJulia.jupyterlab()`.

Returns the Jupyter path that was saved.

## Examples
```julia
using IJulia

# Use existing preference (or search if none exists)
IJulia.update_jupyter_path()

# Explicitly set Jupyter path via ENV
ENV["JUPYTER"] = "/usr/local/bin/jupyter"
IJulia.update_jupyter_path()

# Force re-detection, ignoring saved preference
ENV["JUPYTER"] = ""
IJulia.update_jupyter_path()
```
"""
function update_jupyter_path()
    # Check ENV first
    jupyter = get(ENV, "JUPYTER", nothing)

    if jupyter === nothing
        # No ENV set - use existing preference or search if none exists
        jupyter = determine_jupyter_path()
    elseif isempty(jupyter)
        # ENV set to "" - delete preference and force fresh search
        delete_preference("jupyter")
        jupyter = determine_jupyter_path()
    end
    # else: ENV set to specific path - use it

    save_preference("jupyter", jupyter)
    global JUPYTER = jupyter
    @info "Jupyter path updated: $jupyter"
    return jupyter
end
