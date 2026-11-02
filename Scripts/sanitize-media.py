#!/usr/bin/env python3
"""Remove textual/EXIF PNG metadata while preserving all image-data chunks exactly."""
import struct
import sys
from pathlib import Path

for name in sys.argv[1:]:
    path = Path(name)
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise SystemExit("Expected PNG: " + path.name)
    result = bytearray(data[:8])
    offset = 8
    removed = 0
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        chunk = data[offset:offset + 12 + length]
        if data[offset + 4:offset + 8] in {b"tEXt", b"zTXt", b"iTXt", b"eXIf", b"tIME"}:
            removed += 1
        else:
            result.extend(chunk)
        offset += 12 + length
    path.write_bytes(result)
    print(f"{path.name}: removed {removed} metadata chunk(s); pixels unchanged")
