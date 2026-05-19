"""TUS save backup and restore — ported from clear/restore_tus_save.ps1.

Backup files live at:
    <tus_root>/<comm_id>/<npid>/backups/YYYY-MM-DD_HHMMSS_<comm_id>_<slot20d>.tdt

Restore sentinels are written to:
    <tus_root>/<comm_id>/<npid>/<slot20d>.tdt.restore
"""
import os
import re
from dataclasses import dataclass
from pathlib import Path


@dataclass
class BackupEntry:
    date: str       # "YYYY-MM-DD"
    time: str       # "HH:MM:SS"
    session: str    # "YYYY-MM-DD_HHMM"  (groups same-minute saves)
    slot: str       # 20-digit zero-padded slot ID
    size_kb: int
    file_path: str
    slot_dir: str   # directory that receives the .tdt.restore sentinel


def list_backups(tus_root: str) -> list[BackupEntry]:
    """Scan tus_root for all timestamped backup .tdt files."""
    entries: list[BackupEntry] = []
    root = Path(tus_root)
    if not root.exists():
        return entries

    for f in sorted(root.rglob("*.tdt")):
        if f.parent.name != "backups":
            continue
        n = f.stem  # e.g. 2026-05-10_182917_<comm_id>_00000000000000000002
        parts = n.split("_")
        # Minimum: date(1) + time(1) + comm_id parts + slot(1)
        if len(parts) < 4:
            continue
        slot = parts[-1]
        if not re.fullmatch(r"\d{20}", slot):
            continue

        date    = parts[0]           # YYYY-MM-DD
        raw_t   = parts[1]           # HHMMSS
        time_s  = f"{raw_t[0:2]}:{raw_t[2:4]}:{raw_t[4:6]}" if len(raw_t) >= 6 else raw_t
        session = f"{date}_{raw_t[0:4]}"

        entries.append(BackupEntry(
            date=date,
            time=time_s,
            session=session,
            slot=slot,
            size_kb=max(1, (f.stat().st_size + 1023) // 1024),
            file_path=str(f),
            slot_dir=str(f.parent.parent),  # strip /backups
        ))

    return entries


def stage_restore(entry: BackupEntry) -> str | None:
    """Copy backup .tdt to its .tdt.restore sentinel.

    Returns None on success or an error string on failure.
    """
    sentinel = os.path.join(entry.slot_dir, f"{entry.slot}.tdt.restore")
    try:
        import shutil
        shutil.copy2(entry.file_path, sentinel)
        return None
    except OSError as e:
        return str(e)


def stage_new_game(tus_root: str) -> tuple[int, list[str]]:
    """Write a zero-byte .tdt.restore sentinel for every known slot.

    Scans both existing backups and any already-staged .tdt.restore files to
    build the slot list — mirrors the PowerShell script's logic exactly.

    Returns (count_staged, [error_strings]).
    """
    root = Path(tus_root)
    if not root.exists():
        return 0, [f"TUS folder not found: {tus_root}"]

    # Collect (slot_dir, slot_id) pairs
    slots: dict[str, str] = {}  # key = "dir|slot"

    for f in root.rglob("*.tdt"):
        if f.parent.name != "backups":
            continue
        n = f.stem
        parts = n.split("_")
        if not parts:
            continue
        slot = parts[-1]
        if not re.fullmatch(r"\d{20}", slot):
            continue
        slot_dir = str(f.parent.parent)
        slots[f"{slot_dir}|{slot}"] = (slot_dir, slot)

    for f in root.rglob("*.tdt.restore"):
        base = f.name
        if base.endswith(".tdt.restore"):
            slot = base[: -len(".tdt.restore")]
            if re.fullmatch(r"\d{20}", slot):
                slot_dir = str(f.parent)
                slots[f"{slot_dir}|{slot}"] = (slot_dir, slot)

    staged = 0
    errors: list[str] = []
    for slot_dir, slot in slots.values():
        sentinel = os.path.join(slot_dir, f"{slot}.tdt.restore")
        try:
            Path(sentinel).write_bytes(b"")
            staged += 1
        except OSError as e:
            errors.append(f"Could not write {sentinel}: {e}")

    return staged, errors


def cleanup_restore_sentinels(tus_root: str) -> int:
    """Delete all dangling .tdt.restore sentinels under tus_root.

    Returns the number of files removed.
    """
    root = Path(tus_root)
    if not root.exists():
        return 0
    count = 0
    for f in root.rglob("*.tdt.restore"):
        try:
            f.unlink()
            count += 1
        except OSError:
            pass
    return count
