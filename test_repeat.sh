#!/usr/bin/env bash
# Repeatedly run IJulia tests. Stops immediately if stderr contains "Spurious WAKEUP".
# Ctrl-C stops everything at any time.

run=0
while true; do
    run=$((run + 1))
    echo "=== Run $run ==="

    # fd 3 = original stdout. Pipe captures julia's stderr; stdout passes through.
    { julia --color=yes --project=@. -e "using Pkg; Pkg.test()" 2>&1 1>&3 3>&- | \
        while IFS= read -r line; do
            printf '%s\n' "$line" >&2
            if [[ "$line" == *"Spurious WAKEUP"* ]]; then
                printf '\n*** "Spurious WAKEUP" detected on run %d — stopping. ***\n' "$run" >&2
                kill -INT -- 0
            fi
        done
    } 3>&1

    exit_code=${PIPESTATUS[0]}
    if [ "$exit_code" -ne 0 ]; then
        printf '*** Tests failed on run %d (exit code %d) — stopping. ***\n' "$run" "$exit_code"
        exit "$exit_code"
    fi

    echo "Run $run passed."
done
