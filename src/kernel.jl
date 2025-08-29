function run_kernel()
    # Load InteractiveUtils from the IJulia namespace since @stdlib might not be in LOAD_PATH
    @eval Main using IJulia.InteractiveUtils

    # the size of truncated output to show should not depend on the terminal
    # where the kernel is launched, since the display is elsewhere
    ENV["LINES"] = get(ENV, "LINES", "30")
    ENV["COLUMNS"] = get(ENV, "COLUMNS", "80")

    println(Core.stdout, "Starting kernel event loops.")
    IJulia.init(ARGS, IJulia.Kernel())

    let startupfile = !isempty(DEPOT_PATH) ? abspath(DEPOT_PATH[1], "config", "startup_ijulia.jl") : ""
        isfile(startupfile) && Base.JLOptions().startupfile != 2 && Base.include(Main, startupfile)
    end

    # import things that we want visible in IJulia but not in REPL's using IJulia
    @eval Main import IJulia: ans, In, Out, clear_history

    # check whether Revise is running and as needed configure it to run before every prompt
    if isdefined(Main, :Revise)
        let mode = get(ENV, "JULIA_REVISE", "auto")
            mode == "auto" && IJulia.push_preexecute_hook(Main.Revise.revise)
        end
    end

    wait(IJulia._default_kernel::Kernel)
end
