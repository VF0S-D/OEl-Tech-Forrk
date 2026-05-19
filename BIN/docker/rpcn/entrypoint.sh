#!/bin/sh
# Seed default cfg/pem files into the /rpcn bind mount on first run,
# generate the TLS certificate if missing, then exec the RPCN binary.
# Existing files on the host are preserved.
set -e

cd /rpcn

for f in /defaults/*.cfg /defaults/*.pem; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    if [ ! -e "/rpcn/$name" ]; then
        echo "[entrypoint] seeding /rpcn/$name from image defaults"
        cp "$f" "/rpcn/$name"
    fi
done

mkdir -p /rpcn/tss_data/NPWR04428_00

if [ ! -e /rpcn/cert.pem ]; then
    echo "[entrypoint] generating cert.pem via rpcn --cert-gen"
    /usr/local/bin/rpcn --cert-gen
fi

exec "$@"
