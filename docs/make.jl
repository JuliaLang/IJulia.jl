using Documenter, IJulia


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
    warnonly=true,
)

# Deploy docs
deploydocs(
    repo = "github.com/JuliaLang/IJulia.jl.git",
    push_preview = true,
)
