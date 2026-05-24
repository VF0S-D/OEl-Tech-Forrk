#!/usr/bin/env bash
# Install RPCS3 + RPCN build prerequisites on Debian/Ubuntu.
# Safe to re-run; apt skips already-installed packages.
# For other distros, install the equivalents listed at the bottom.
set -euo pipefail

# Pinned versions.
PROTOC_VER="28.3"          # RPCN build.rs uses prost_build / protoc

if ! command -v apt-get >/dev/null 2>&1; then
    cat <<'EOF' >&2
ERROR: this helper only knows apt-get. For other distros install:
  - C++ toolchain (gcc 13+ or clang 17+), cmake, ninja, pkg-config
  - Qt 6 (handled by ci/install-qt.sh)
  - Vulkan: libvulkan-dev vulkan-tools vulkan-validationlayers
  - LLVM 19 development headers
  - Multimedia: libsdl2-dev libpulse-dev libasound2-dev libopenal-dev
                libevdev-dev libudev-dev libegl-dev libglew-dev libgtk-3-dev
                libavformat-dev libavcodec-dev libavutil-dev libswscale-dev
  - Rust toolchain (rustup), protoc
EOF
    exit 1
fi

if [ "$EUID" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: run as root or install sudo." >&2
    exit 1
fi

SUDO=""
if [ "$EUID" -ne 0 ]; then SUDO="sudo"; fi

echo "============================================================"
echo " Installing build prerequisites via apt..."
echo "============================================================"

$SUDO apt-get update
$SUDO apt-get install -y --no-install-recommends \
    build-essential cmake ninja-build pkg-config git curl ca-certificates \
    libsdl2-dev libpulse-dev libasound2-dev libopenal-dev \
    libevdev-dev libudev-dev libegl-dev libglew-dev libgtk-3-dev \
    libxxf86vm-dev libwayland-dev \
    libavformat-dev libavcodec-dev libavutil-dev libswscale-dev \
    libvulkan-dev vulkan-tools vulkan-validationlayers \
    llvm-19-dev libclang-19-dev clang-19 \
    ccache unzip xz-utils \
    python3 python3-pip python3-venv

# Rust toolchain via rustup (system rustc on Debian/Ubuntu lags upstream).
if ! command -v rustup >/dev/null 2>&1; then
    echo "Installing rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
    # shellcheck disable=SC1091
    source "$HOME/.cargo/env"
fi
rustup default stable
rustup target add x86_64-unknown-linux-gnu

# protoc. Distro versions can be too old for prost_build; pull the release zip.
PROTOC_ROOT="/opt/protoc-$PROTOC_VER"
if [ ! -x "$PROTOC_ROOT/bin/protoc" ]; then
    echo "Installing protoc $PROTOC_VER..."
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64)  PROTOC_ARCH="linux-x86_64" ;;
        aarch64) PROTOC_ARCH="linux-aarch_64" ;;
        *) echo "Unsupported arch $ARCH"; exit 1 ;;
    esac
    TMP="$(mktemp -d)"
    curl -fL -o "$TMP/protoc.zip" \
        "https://github.com/protocolbuffers/protobuf/releases/download/v$PROTOC_VER/protoc-$PROTOC_VER-$PROTOC_ARCH.zip"
    $SUDO unzip -q "$TMP/protoc.zip" -d "$PROTOC_ROOT"
    $SUDO ln -sf "$PROTOC_ROOT/bin/protoc" /usr/local/bin/protoc
    rm -rf "$TMP"
fi

echo
echo "Prereqs installed. Next: ci/install-qt.sh"
