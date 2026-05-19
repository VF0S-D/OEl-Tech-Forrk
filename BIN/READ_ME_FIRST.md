# OPERATION ETERNAL LIBERATION

A community kit for playing online via RPCS3 and an RPCN server.

## Quick start

Open the desktop shortcut **Play OPERATION ETERNAL LIBERATION**. First run downloads an embedded Python runtime and the GUI dependencies.

You provide:

1. PS3 firmware. When RPCS3 prompts, point it at your `PS3UPDAT.PUP`.
2. The game at version 2.11. In RPCS3, *File > Install Packages/Raps*, then install your game files.
3. The 15 TSS files. Drop them into `BIN\TSS\`.

Always launch the game from the launcher, not directly from RPCS3, so the network config matches your current LAN IP.

## Server settings

The **Play** tab has two server groups. They are independent and any combination works.

**RPCN Server** controls login and matchmaking:

- *Official*: the community RPCN at np.rpcs3.net.
- *Self-Hosted*: runs an RPCN server on your machine.
- *Custom*: any other RPCN server (enter its host).

**Game Server** controls the backend that answers the game's HTTP calls:

- *Self-Hosted*: runs on your machine. Works both for singleplayer and multiplayer (the multiplayer matchmaking and netcode is handled by RPCN).
- *Remote*: a game server hosted elsewhere. Enter the address as `host:http_port:https_port`, for example `<host_ip>:8000:8001`.

## Saves

The **Saves** tab has three things:

- A save editor for credits, fuel, tickets, and other fields.
- A backup browser. RPCS3 writes a local copy of every cloud save, so you can roll back any time.
- A "new game" override that makes the game offer a fresh start without deleting your cloud data.

## Updates

Running a newer installer over an existing install preserves your RPCS3 portable data, RPCN config, launcher settings, and `BIN\TSS\` folder. Everything else is overwritten.

## Troubleshooting

- **"Failed to connect to Playstation Network".** Click the RPCN icon in RPCS3 to confirm you are logged in. Check that all 15 TSS files show as present on the **TSS Files** tab.
- **"Failed to connect to game server".** If self-hosted, the game server CMD window should be open. If remote, check the address and that the server is reachable.
- **RPCN login fails (self-hosted).** Make sure `rpcn.exe` is running and Windows Firewall allows TCP 31313 and 31315.
- **Can't host or join rooms.** In RPCS3, right-click the game, open *Custom Configuration > Network*, enable **UPnP**.

## Hosting your own server

The kit ships with a Docker setup that runs the game server and RPCN together on a Linux machine. A small VPS works fine.

You need:

- A Linux box with Docker installed.
- The full project source, cloned with `git clone --recurse-submodules`.

### Build the images

From the `BIN` directory of the cloned repo:

```
docker compose build
docker save oel-gameserver:latest oel-rpcn:latest | gzip > oel-images.tar.gz
```

If your build host's CPU architecture differs from your server's, prefix the build with `DOCKER_DEFAULT_PLATFORM=linux/amd64`.

### Copy to the server

```
scp oel-images.tar.gz docker-compose.yml user@your-vps:~/
```

### Load and start

```
mkdir -p ~/oel/_app/rpcn && cd ~/oel
mv ~/docker-compose.yml .
docker load < ~/oel-images.tar.gz
docker compose up -d
```

### Open the ports

Allow these on your VPS firewall, plus any cloud-provider firewall in front of it:

- `8000` TCP (game server HTTP)
- `8001` TCP (game server HTTPS)
- `31313` TCP (RPCN login and matchmaking)
- `31315` TCP (RPCN TSS HTTP)
- `3657` UDP (RPCN signaling)

### Add TSS files

After first start, the RPCN container creates a `tss_data/<comm_id>/` subdirectory. Copy your 15 TSS files there, then:

```
docker compose restart rpcn
```

### Connect from the launcher

On the **Play** tab:

- **RPCN Server**: pick **Custom** and enter your server's host.
- **Game Server**: pick **Remote** and enter `<host_ip>:8000:8001`.

### Logs

The game server writes its log file and rotated archives to `~/oel/logs/gameserver/` on the host. For RPCN, use `docker compose logs rpcn`.

### Updating the server

Rebuild locally, ship a new tarball, then on the server:

```
docker load < ~/oel-images.tar.gz
docker compose up -d
```

The bind-mounted `_app/rpcn/` data is preserved across updates.
