#!/usr/bin/env bash
# Install Qt for the RPCS3 Linux build via aqtinstall.
# Match the version to SRC/GIT/rpcs3/.github/workflows/rpcs3.yml.
# Safe to re-run; skips if Qt is already extracted.
set -euo pipefail

# Pinned versions. Bump these to update.
QT_VER="6.11.0"
QT_HOST="linux"
QT_TARGET="desktop"
QT_ARCH="linux_gcc_64"
INSTALL_ROOT="/opt/Qt"

QT_DIR="$INSTALL_ROOT/$QT_VER/gcc_64"

if [ -x "$QT_DIR/bin/qmake" ] || [ -x "$QT_DIR/bin/qmake6" ]; then
    echo "Qt $QT_VER already installed at $QT_DIR, skipping."
    exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 required for aqtinstall. Run ci/install-prereqs.sh first." >&2
    exit 1
fi

SUDO=""
if [ "$EUID" -ne 0 ]; then SUDO="sudo"; fi

$SUDO mkdir -p "$INSTALL_ROOT"
$SUDO chown "$(id -u):$(id -g)" "$INSTALL_ROOT"

# Use a venv so aqtinstall doesn't fight system-managed python packages.
VENV="$(mktemp -d)/aqt-venv"
python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet aqtinstall

echo "Installing Qt $QT_VER to $INSTALL_ROOT..."
"$VENV/bin/aqt" install-qt "$QT_HOST" "$QT_TARGET" "$QT_VER" "$QT_ARCH" \
    --outputdir "$INSTALL_ROOT" \
    --modules qtmultimedia qtsvg qtdeclarative qttools qttranslations

rm -rf "$(dirname "$VENV")"

echo
echo "Qt $QT_VER installed to $QT_DIR"
echo "Export this in your shell (or add to ~/.profile) before running build-all.sh:"
echo "  export QTDIR=$QT_DIR"
echo "  export PATH=\$QTDIR/bin:\$PATH"
