#!/usr/bin/env bash
# Launches the OEL launcher. Triggers first-run setup if needed.
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -x "_app/python/bin/python3" ]; then
    bash "_app/setup.sh"
    if [ ! -x "_app/python/bin/python3" ]; then
        echo "Setup failed. See above for details." >&2
        exit 1
    fi
fi

exec "_app/python/bin/python3" "_app/launcher.py" "$@"
