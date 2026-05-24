#!/usr/bin/env bash
# Standalone game-server first-time setup. Mirrors setup.bat for Linux/macOS.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PYDIR="$HERE/python"

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 not found. Install Python 3.10 or newer:"
    echo "  Debian/Ubuntu:  sudo apt install python3 python3-venv python3-pip"
    echo "  Fedora:         sudo dnf install python3 python3-pip"
    echo "  Arch:           sudo pacman -S python python-pip"
    exit 1
fi

if [ ! -x "$PYDIR/bin/python3" ]; then
    echo "Creating Python virtual environment at $PYDIR..."
    if ! python3 -m venv "$PYDIR"; then
        echo
        echo "ERROR: venv creation failed."
        echo "On Debian/Ubuntu install python3-venv:  sudo apt install python3-venv"
        exit 1
    fi
fi

echo "Installing dependencies..."
"$PYDIR/bin/python3" -m pip install --quiet --upgrade pip
"$PYDIR/bin/python3" -m pip install --quiet cryptography

echo
echo "Setup complete."
