#!/usr/bin/env bash
# Build the source and Docker release archives on Linux.
# The Windows installer (.exe) is built by package.bat under InnoSetup on
# Windows; that step is skipped here.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

# Pull AppVersion out of OEL.iss (same source of truth as package.bat).
VERSION="$(awk -F'"' '/^#define AppVersion/ {print $2; exit}' "$ROOT/OEL.iss")"
if [ -z "$VERSION" ]; then
    echo "ERROR: could not parse AppVersion from $ROOT/OEL.iss" >&2
    exit 1
fi

echo "============================================================"
echo " ACI-RPCS3 - Package builder (Linux)"
echo "============================================================"
echo "Output: $ROOT  (version $VERSION)"
echo

# 1. SRC archive
echo "[1/2] Packaging SRC..."
SRC_TAR="$ROOT/OEL-SRC-$VERSION.tar.xz"
rm -f "$SRC_TAR"
tar -C "$ROOT" -cJf "$SRC_TAR" \
    SRC/README.md \
    SRC/PATCH \
    SRC/apply-patches.bat \
    SRC/apply-patches.sh \
    SRC/clone-git-repos.bat \
    SRC/clone-git-repos.sh \
    SRC/reset-git-repos.bat \
    SRC/reset-git-repos.sh \
    SRC/pinned-commits.env
echo "Done."
echo

# 2. Docker source bundle
echo "[2/2] Bundling Docker source..."
DSTAGE="$(mktemp -d)"
trap 'rm -rf "$DSTAGE"' EXIT
BUNDLE="$DSTAGE/OEL-DOCKER-$VERSION"
mkdir -p \
    "$BUNDLE/BIN/docker/gameserver" \
    "$BUNDLE/BIN/docker/rpcn" \
    "$BUNDLE/BIN/_app/gameserver" \
    "$BUNDLE/BIN/_app/assets" \
    "$BUNDLE/SRC/PATCH/RPCN"
cp "$ROOT/BIN/docker-compose.yml"                       "$BUNDLE/BIN/"
cp "$ROOT/BIN/docker/gameserver/Dockerfile"             "$BUNDLE/BIN/docker/gameserver/"
cp "$ROOT/BIN/docker/rpcn/Dockerfile"                   "$BUNDLE/BIN/docker/rpcn/"
cp "$ROOT/BIN/docker/rpcn/entrypoint.sh"                "$BUNDLE/BIN/docker/rpcn/"
cp "$ROOT/BIN/_app/gameserver/opeternal_listener.py"    "$BUNDLE/BIN/_app/gameserver/"
cp "$ROOT/BIN/_app/assets/ascii.txt"                    "$BUNDLE/BIN/_app/assets/"
cp "$ROOT/SRC/PATCH/RPCN/tss-server.patch"              "$BUNDLE/SRC/PATCH/RPCN/"
cp "$ROOT/BIN/docker/PACKAGE-README.md"                 "$BUNDLE/README.md"

DOCKER_TAR="$ROOT/OEL-DOCKER-$VERSION.tar.xz"
rm -f "$DOCKER_TAR"
tar -C "$DSTAGE" -cJf "$DOCKER_TAR" "OEL-DOCKER-$VERSION"
echo "Done."
echo

cat <<EOF
============================================================
 Packaging complete:
   OEL-SRC-$VERSION.tar.xz       - source and patches (for DIY builders)
   OEL-DOCKER-$VERSION.tar.xz    - Docker source bundle (for Linux self-hosting)

 The Windows installer (OP-ETERNAL-Setup-$VERSION.exe) is produced
 only by package.bat on Windows with InnoSetup.

 TSS files are not bundled. Users must obtain them separately.
============================================================
EOF
