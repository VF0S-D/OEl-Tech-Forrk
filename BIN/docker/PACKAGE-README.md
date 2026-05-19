# OPERATION ETERNAL LIBERATION - Docker package

Source bundle for hosting the game server and RPCN on a Linux machine. Docker builds both images locally on first start.

## Requirements

- Linux with Docker installed.

## Start

```
cd BIN
docker compose up -d --build
```

First start takes a few minutes while Docker builds the RPCN image. Subsequent starts reuse the layer cache.

## Open the ports

Allow these on your VPS firewall, plus any cloud-provider firewall in front of it:

- `8000` TCP (game server HTTP)
- `8001` TCP (game server HTTPS)
- `31313` TCP (RPCN login and matchmaking)
- `31315` TCP (RPCN TSS HTTP)
- `3657` UDP (RPCN signaling)

## Add TSS files

After first start, the RPCN container creates a `tss_data/<comm_id>/` subdirectory under `BIN/_app/rpcn/`. Copy your 15 TSS files there, then:

```
cd BIN
docker compose restart rpcn
```

## Connect from the launcher

On the **Play** tab:

- **RPCN Server**: pick **Custom** and enter your server's host.
- **Game Server**: pick **Remote** and enter `<host_ip>:8000:8001`.

## Logs

The game server writes its log file and rotated archives to `BIN/logs/gameserver/`. For RPCN, use `docker compose logs rpcn` from inside `BIN`.

## Updating

Extract a newer bundle over this folder (`BIN/_app/rpcn/` and `BIN/logs/` are runtime data, leave them in place) and run the start command again.
