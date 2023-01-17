using Documenter, IJulia

# Copy assets from `deps` directory
path_assets = joinpath(@__DIR__, "src/assets")
path_deps = joinpath(@__DIR__, "../deps")
mkpath(path_assets)
cp(joinpath(path_deps, "ijuliafavicon.ico"), joinpath(path_assets, "favicon.ico"), force=true)
cp(joinpath(path_deps, "ijulialogo.svg"), joinpath(path_assets, "logo.svg"), force=true)

# Make docs to `docs/build` directory
makedocs(
    modules=[IJulia],
    sitename="IJulia",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        assets = ["assets/favicon.ico"],
    ),
    pages=[
        "Home" => "index.md",
        "Manual" => [
            "manual/installation.md",
            "manual/running.md",
            "manual/usage.md",
            "manual/troubleshooting.md",
        ],
        "Library" => [
            "library/public.md",
            "library/internals.md",
        ],
    ],
)

# Deploy docs
deploydocs(
    repo = "github.com/JuliaLang/IJulia.jl.git",
    push_preview = true,
)
