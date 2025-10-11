import Changelog
using Documenter, IJulia

if isdefined(Main, :Revise)
    Revise.revise()
end

# Build the changelog
Changelog.generate(
    Changelog.Documenter(),
    joinpath(@__DIR__, "src/_changelog.md"),
    joinpath(@__DIR__, "src/changelog.md"),
    repo="JuliaLang/IJulia.jl"
)

# Make docs to `docs/build` directory
makedocs(;
    repo=Remotes.GitHub("JuliaLang", "IJulia.jl"),
    modules=[IJulia],
    sitename="IJulia",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        assets = ["assets/favicon.ico", "assets/custom.css"],
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
        "changelog.md"
    ]
)

# Deploy docs
deploydocs(
    repo = "github.com/JuliaLang/IJulia.jl.git",
    push_preview = true,
)
