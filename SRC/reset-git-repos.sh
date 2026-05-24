#!/usr/bin/env bash
# Reset RPCS3 and RPCN submodules to the pinned baseline.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"

cat <<'EOF'
============================================================
 ACI-RPCS3 -- Reset source repos to patch baseline
============================================================

WARNING: This will discard all local modifications and any
         applied patches in both repos.
EOF
read -r -p "Press Enter to continue or Ctrl+C to abort..."

echo "[1/2] Resetting RPCS3..."
( cd "$SRC/GIT/rpcs3" && git reset --hard HEAD && git clean -ffdx )
echo "Done."
echo

echo "[2/2] Resetting RPCN..."
( cd "$SRC/GIT/rpcn" && git reset --hard HEAD && git clean -ffdx )
echo "Done."
echo

echo "============================================================"
echo " Both repos reset. Ready to run apply-patches.sh."
echo "============================================================"
