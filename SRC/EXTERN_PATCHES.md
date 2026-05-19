# External patches

This project carries two patches against upstream source trees, applied by
`SRC\apply-patches.bat`:

- `SRC\PATCH\RPCS3\tss-support.patch` against [RPCS3](https://github.com/RPCS3/rpcs3)
- `SRC\PATCH\RPCN\tss-server.patch` against [rpcn](https://github.com/RipleyTom/rpcn)

The kit modifies upstream because the game depends on
two PSN features that aren't otherwise available in an offline or community-RPCN
setup:

- **Title Small Storage (TSS).** The game is online-only and pulls server-side
  TSS blobs to complete its login phase. Without them, login fails with
  "Failed to connect to Playstation Network".
- **Title User Storage (TUS).** Saves live exclusively in the cloud. The game's
  save format is fragile, and the game has its own server-side recovery
  routines whose protocol we haven't reverse-engineered. A corrupted cloud save
  leaves the player stuck with no way to fix it. We work around that by
  mirroring every cloud-save write to local disk so the launcher can put a
  known-good copy back.

## RPCS3: `tss-support.patch`

Modifies `rpcs3/Emu/Cell/Modules/sceNpTus.cpp` and `rpcs3/Emu/NP/np_requests.cpp`.

### TSS file serving

`sceNpTssGetData` and `sceNpTssGetDataAsync` previously returned the stub
"no file" response. The game treats this as a fatal error and login fails with
"Failed to connect to Playstation Network". The patch replaces the stubs with a
real implementation (`scenp_tss_serve_file`):

1. Read from `<config_dir>/tss/<titleId>-<slot>.tss` if present.
2. Otherwise fetch over HTTP from
   `http://<rpcn_host>:<rpcn_port + 2>/tss/<titleId>/<titleId>-<slot>.tss`
   via libcurl (`scenp_tss_fetch_from_rpcn`).
3. If neither yields a file, fall through to the original stub.

The two-source design is for decentralization. TSS files can be distributed
locally with each install, or hosted once on the community RPCN server and
fetched on demand. Neither path is privileged. Range parameters (`offset`,
`lastByte`) are honoured; `ifParam` is logged but ignored.

The PSN online check at the top of both functions was removed. TSS data here
comes from the local filesystem or RPCN, never the real PSN, so the check would
only prevent legitimate offline use.

### World list allocation fix and padding

In `np::reply_get_world_list` (`np_requests.cpp`), two changes:

- The `SceNpMatching2World` array allocation was inside an
  `if (!world_list.empty())` branch, leaving `world_info->world` as a null
  pointer when RPCN returned no worlds. The allocation is now unconditional.
- The world list is padded with `worldId = 65537` until its length is at least
  10.

The padding works around a game-side assumption: the game reads
past the end of the returned list and crashes when the list is too short. The
proper fix would be on the game side, which we can't touch. The actual
workaround lives in our fork of RPCN: `servers.cfg` registers 5 worlds for
the game's community ID (see below), which is enough to avoid the crash. The client-side
padding to 10 entries here is an additional safety net.

### TUS restore via one-shot local files

`scenp_tus_serve_restore` (called from `scenp_tus_get_data` before the normal
RPCN path) checks for a file at
`<config_dir>/tus/<commId>/<npId>/<slot20d>.tdt.restore`:

- Empty file: report `SCE_NP_COMMUNITY_SERVER_ERROR_USER_STORAGE_DATA_NOT_FOUND`,
  matching RPCN's own "no data" response. The game treats this as a fresh
  account.
- Non-empty file: serve its contents as the TUS payload.

The file is deleted after the read regardless, so the next `GetData` falls
through to RPCN normally. This is the hook the launcher's "Backup / Restore"
and "New Game" features use to take effect on the next game boot.

### Automatic TUS backup on SetData

In `np::reply_tus_set_data` (`np_requests.cpp`), the patch writes a timestamped
local copy of the outgoing TUS payload before forwarding it to RPCN:

```
<config_dir>/tus/<commId>/<npId>/backups/YYYY-MM-DD_HHMMSS_<commId>_<slot20d>.tdt
```

The game's save format is fragile and the game's own server-side recovery
routines use a protocol we haven't reverse-engineered, so a corrupted cloud
save can't be fixed through normal game flow. The local mirror is a workaround:
every cloud-save write is dumped to disk, and the launcher's restore flow
hands a known-good copy back through the one-shot file path above.

## rpcn: `tss-server.patch`

Modifies `src/server.rs` and `servers.cfg`, and adds `src/server/tss_server.rs`.

### TSS HTTP server module

The new file `src/server/tss_server.rs` defines a small `hyper`-based HTTP
server bound to `<host>:<rpcn_port + 2>` (same offset convention as the stat
server, which uses `port + 1`). It serves:

```
GET /tss/<com_id>/<filename>
```

from `tss_data/<com_id>/` on disk. Path-traversal characters (`..`, `/`, `\`)
in either segment return 400. Missing files return 404. Non-GET methods return
405. Started from `Server::start_tss_server`, called between the UDP and stat
servers in `Server::start`. Uses the existing `TerminateWatch` channel for
shutdown.

### `servers.cfg` entries

Five lines added for the game's community ID, registering worlds 1 through 5 each at
`worldId = 65537`. These satisfy the game's matchmaking world-list request.
Combined with the RPCS3-side padding above, the game sees the minimum list
length it expects.

## Applying and resetting

```
SRC\apply-patches.bat
```

Runs `git apply` against both submodules. Fails if either working tree isn't
clean.

```
SRC\reset-git-repos.bat
```

Runs `git reset --hard HEAD` and `git clean -ffdx` on both submodules,
restoring them to the pinned commits and removing patch-introduced files
(including the new `tss_server.rs`).
