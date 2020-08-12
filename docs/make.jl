using Documenter, IJulia


makedocs(
    modules=[IJulia],
    sitename="IJulia",
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


deploydocs(
    repo = "github.com/JuliaLang/IJulia.jl.git",
    push_preview = true,
)
