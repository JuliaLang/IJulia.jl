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
    ],
)
