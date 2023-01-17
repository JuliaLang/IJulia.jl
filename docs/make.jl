using Documenter, IJulia

# Copy assets from `deps` directory
mkpath(joinpath(@__DIR__, "src/assets"))
cp(joinpath(@__DIR__, "../deps/ijuliafavicon.ico"), joinpath(@__DIR__, "src/assets/favicon.ico"), force=true)
cp(joinpath(@__DIR__, "../deps/ijulialogo.svg"), joinpath(@__DIR__, "src/assets/logo.svg"), force=true)

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
