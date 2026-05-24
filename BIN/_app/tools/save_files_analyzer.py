"""
Save Files Analyzer for OPERATION ETERNAL LIBERATION.

Compares two or more of your save backups and prints the bytes that changed
between them. Use it to find where a value lives inside a save file so it can
be wired up in the launcher's in-app save editor.

============================================================================
 STEP-BY-STEP GUIDE (Windows)
============================================================================

 1. PICK ONE VALUE TO TRACK
    Pick a single in-game value whose change you can describe precisely.
    Example: "I spent one Lv. Cap Increase Form, so the count went from 5
    to 4."

 2. PLAY THE GAME AND LET IT SAVE
    Trigger the change in-game and let the game save normally. The launcher
    keeps a timestamped backup of every cloud save under:

        <install folder>\\_app\\RPCS3\\portable\\tus\\NPWR04428_00\\<your account>\\backups

    You want at least one backup from BEFORE the change and one from AFTER.

 3. IDENTIFY THE SLOT NUMBER
    Each backup file is named like
        2026-05-10_182917_NPWR04428_00_00000000000000000002.tdt
    The final number ("00000000000000000002") is the SLOT NUMBER. The
    trailing digit is what you pass to this tool.
        slot 2: fuel, tickets, forms, research reports...
        slot 3: credits, upgrades...
        slot 4: penalty rank...

 4. COPY YOUR BACKUPS INTO THIS FOLDER
    Copy at least two backup files for the same slot from the backups folder
    above into this folder (the one this script lives in):

        <install folder>\\_app\\tools

 5. OPEN A COMMAND PROMPT IN THIS FOLDER
    In File Explorer, click in the address bar at the top, type
        cmd
    and press Enter. A black command-prompt window opens already pointing
    at this folder.

 6. RUN THE TOOL
    Type the following and press Enter (replace 2 with your slot number):

        ..\\python\\python.exe save_files_analyzer.py 2

    The tool prints every byte that changed between your backups and tells
    you which 4-byte-aligned offset to use. Add --snippet to also get a
    ready-to-paste line for the save editor:

        ..\\python\\python.exe save_files_analyzer.py 2 --snippet

 7. (OPTIONAL) ADD THE FIELD TO THE LAUNCHER
    Open
        <install folder>\\_app\\modules\\save_editor.py
    in a plain text editor (Notepad works). Find the line that starts with
        FIELDS = [
    and add the snippet block the tool printed, just before the closing ].
    Save the file, then restart the launcher. Your new field appears in the
    Saves > Save Editor tab.

    Even better: open an issue or PR so other players get the field too.

============================================================================
 ADVANCED USAGE
============================================================================

    python save_files_analyzer.py 2                  Compare last 4 slot 2 backups
    python save_files_analyzer.py 3 -n 6             Compare last 6 backups
    python save_files_analyzer.py 2 --find 0 1       Show only byte transitions
                                                     from 0 to 1 (filters noise)
    python save_files_analyzer.py 2 --snippet        Print a paste-ready snippet
                                                     for the save editor per diff
    python save_files_analyzer.py 2 --include-crc    Include CRC bytes (noisy;
                                                     normally hidden)
    python save_files_analyzer.py --slot-info FILE   Derive a SLOTS entry
                                                     (file_size, entry_count,
                                                     data_zone) from one file

============================================================================
"""

import argparse
import glob
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

MAGIC          = b"SAVE"
TABLE_START    = 0x18
ENTRY_SIZE     = 12
GLOBAL_CRC_OFF = 0x08
CRC_LEN        = 4


def read_save(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != MAGIC:
        sys.exit(f"{path}: missing SAVE magic")
    if len(data) < TABLE_START + ENTRY_SIZE:
        sys.exit(f"{path}: file too small ({len(data)} bytes)")
    return data


def derive_layout(data):
    """Return (file_size, entry_count, data_zone) from the file's CRC table.

    entry[0].offset == data_zone == TABLE_START + entry_count * ENTRY_SIZE,
    so the first entry's offset implies the whole header layout.
    """
    first_offset = struct.unpack_from(">I", data, TABLE_START + 4)[0]
    if first_offset < TABLE_START or (first_offset - TABLE_START) % ENTRY_SIZE != 0:
        sys.exit(f"unexpected first entry offset 0x{first_offset:04X}")
    entry_count = (first_offset - TABLE_START) // ENTRY_SIZE
    return len(data), entry_count, first_offset


def crc_byte_offsets(entry_count):
    """Byte offsets occupied by CRC fields."""
    offsets = set(range(GLOBAL_CRC_OFF, GLOBAL_CRC_OFF + CRC_LEN))
    for i in range(entry_count):
        crc_off = TABLE_START + i * ENTRY_SIZE + 8
        offsets.update(range(crc_off, crc_off + CRC_LEN))
    return offsets


def diff_files(a, b, skip):
    """Return [(offset, old_byte, new_byte)] for differing bytes outside skip,
    plus a ('size', len_a, len_b) tuple if sizes differ."""
    diffs = [
        (i, x, y) for i, (x, y) in enumerate(zip(a, b))
        if x != y and i not in skip
    ]
    if len(a) != len(b):
        diffs.append(("size", len(a), len(b)))
    return diffs


def format_diff_line(a, b, offset, old, new):
    """One-line summary of a byte change with the aligned u32 hint."""
    aligned = offset & ~0x3
    if aligned + 4 <= len(a):
        old_u32 = struct.unpack_from(">I", a, aligned)[0]
        new_u32 = struct.unpack_from(">I", b, aligned)[0]
        hint = f"u32 @ 0x{aligned:04X}: {old_u32} -> {new_u32}"
    else:
        hint = "u32: n/a (near EOF)"
    return f"    0x{offset:04X}  0x{old:02X} -> 0x{new:02X}   ({old:>3} -> {new:>3})   [{hint}]"


def print_snippet(slot, a, offset):
    """Print a paste-ready FIELDS entry rounded to the nearest u32 boundary."""
    aligned = offset & ~0x3
    print()
    print("    # u32 (most fields):")
    print(f'    dict(slot={slot}, arg="<arg-name>", label="<Label>",')
    print(f'         offset=0x{aligned:04X}, fmt="u32", max=0x7FFFFFFF),')
    if offset % 4 != 0:
        print("    # or u8 (rare; single-byte field at an odd offset):")
        print(f'    dict(slot={slot}, arg="<arg-name>", label="<Label>",')
        print(f'         offset=0x{offset:04X}, fmt="u8", max=255),')


def cmd_slot_info(path):
    data = read_save(path)
    file_size, entry_count, data_zone = derive_layout(data)
    print(f"Layout derived from {os.path.basename(path)}:")
    print(f"  file_size:    0x{file_size:04X} ({file_size} bytes)")
    print(f"  entry_count:  {entry_count}")
    print(f"  data_zone:    0x{data_zone:04X} (== 0x18 + {entry_count} * 12)")
    print()
    print("Suggested SLOTS entry (replace N with the slot number):")
    print(f"    N: dict(file_size=0x{file_size:04X},  "
          f"entry_count={entry_count},  data_zone=0x{data_zone:04X}),")


def cmd_diff(args):
    slot = args.slot or input("Slot number: ").strip()
    slot_suffix = f"{int(slot):020d}"

    pattern = os.path.join(HERE, f"*_NPWR04428_00_{slot_suffix}.tdt")
    files = sorted(glob.glob(pattern))
    if len(files) < 2:
        print(f"Need at least 2 backups for slot {slot}, found {len(files)}.")
        print(f"Drop backup files into this folder:  {HERE}")
        print("See the step-by-step guide at the top of this file for help.")
        return

    recent = files[-args.n:]
    sample = read_save(recent[0])
    _, entry_count, _ = derive_layout(sample)
    skip = set() if args.include_crc else crc_byte_offsets(entry_count)

    filter_desc = (f"  [filtering: {args.find[0]} -> {args.find[1]}]"
                   if args.find else "")
    crc_desc = "" if args.include_crc else f"  [CRC bytes filtered: {len(skip)}]"
    print(f"Slot {slot} - last {len(recent)} backups, {len(recent) - 1} diff(s)"
          f"{filter_desc}{crc_desc}:")
    print()

    for i in range(len(recent) - 1):
        a_path, b_path = recent[i], recent[i + 1]
        ts_a = os.path.basename(a_path)[:17]
        ts_b = os.path.basename(b_path)[:17]
        a = read_save(a_path)
        b = read_save(b_path)
        diffs = diff_files(a, b, skip)

        if args.find:
            old_val, new_val = args.find
            diffs = [(o, ov, nv) for o, ov, nv in diffs
                     if o != "size" and ov == old_val and nv == new_val]

        print(f"  {ts_a}  ->  {ts_b}")
        if not diffs:
            print("    (no matching changes)")
        else:
            for offset, old, new in diffs:
                if offset == "size":
                    print(f"    size: {old} -> {new} bytes")
                    continue
                print(format_diff_line(a, b, offset, old, new))
                if args.snippet:
                    print_snippet(slot, a, offset)
        print()


def main():
    parser = argparse.ArgumentParser(
        description=("Compare your OPERATION ETERNAL LIBERATION save backups "
                     "and find where a value lives in the save file. See the "
                     "step-by-step guide at the top of this script."),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("slot", nargs="?", help="Slot number (prompted if omitted)")
    parser.add_argument("-n", type=int, default=4, metavar="N",
                        help="How many recent backups to compare (default: 4)")
    parser.add_argument("--find", nargs=2, type=int, metavar=("OLD", "NEW"),
                        help="Show only byte transitions from OLD to NEW (decimal)")
    parser.add_argument("--snippet", action="store_true",
                        help="Print a paste-ready save-editor snippet for each diff")
    parser.add_argument("--include-crc", action="store_true",
                        help="Include CRC bytes in the diff (default: filtered out)")
    parser.add_argument("--slot-info", metavar="FILE",
                        help="Derive a SLOTS entry from a single .tdt file and exit")
    args = parser.parse_args()

    if args.slot_info:
        cmd_slot_info(args.slot_info)
        return
    cmd_diff(args)


if __name__ == "__main__":
    main()
