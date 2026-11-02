#!/usr/bin/env python3
"""Inspect publishable files and release archives without printing matched secrets."""
from __future__ import annotations

import argparse
import re
import struct
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PATTERNS = {
    "private key": rb"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----",
    "GitHub token": rb"(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,})",
    "API credential": rb"(?:sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{24,}|AIza[0-9A-Za-z_-]{30,})",
    "cloud credential": rb"(?:AKIA|ASIA)[0-9A-Z]{16}",
    "personal home path": rb"/Users/[A-Za-z0-9_.-]+/",
    "Windows home path": rb"[A-Z]:\\Users\\[A-Za-z0-9_.-]+\\",
}
TEXT_SUFFIXES = {".swift", ".md", ".txt", ".py", ".sh", ".command", ".plist", ".svg", ".json", ".yml", ".yaml"}
FORBIDDEN_NAMES = {".DS_Store", ".env", "id_rsa", "id_ed25519", "credentials.json"}
PRIVATE_PNG_CHUNKS = {b"tEXt", b"zTXt", b"iTXt", b"eXIf"}


def candidates() -> list[Path]:
    if (ROOT / ".git").exists():
        output = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
        return [ROOT / name.decode() for name in output.split(b"\0") if name]
    roots = ["Sources", "Tests", "Scripts", "ThirdParty", "docs", ".github"]
    files = [p for name in roots for p in (ROOT / name).rglob("*") if p.is_file()]
    files += [p for p in ROOT.iterdir() if p.is_file() and not p.name.startswith(".DS")]
    return sorted(set(files))


def inspect(label: str, data: bytes, forbidden: list[str], is_text: bool) -> list[str]:
    findings = []
    for value in forbidden:
        if any(value.encode(encoding) in data for encoding in ("utf-8", "utf-16-le", "utf-16-be")):
            findings.append(f"{label}: forbidden private identifier")
            break
    if is_text:
        findings += [f"{label}: {name}" for name, pattern in PATTERNS.items() if re.search(pattern, data)]
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        offset = 8
        while offset + 12 <= len(data):
            length = struct.unpack(">I", data[offset:offset + 4])[0]
            kind = data[offset + 4:offset + 8]
            if kind in PRIVATE_PNG_CHUNKS:
                findings.append(f"{label}: PNG metadata requires review")
            offset += 12 + length
    return findings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--forbid", action="append", default=[], help="Private text to reject; never printed")
    parser.add_argument("--archive", action="append", type=Path, default=[])
    parser.add_argument("--binary", action="append", type=Path, default=[])
    args = parser.parse_args()
    findings = []
    files = candidates()
    for path in files:
        name = path.relative_to(ROOT).as_posix()
        if "artifacts.nosync" in path.parts or any(p in FORBIDDEN_NAMES or p.startswith(".env") for p in path.parts):
            findings.append(f"{name}: excluded file is tracked")
        findings += inspect(name, path.read_bytes(), args.forbid, path.suffix in TEXT_SUFFIXES or path.name in {"LICENSE", ".gitignore"})
    for archive in args.archive:
        with zipfile.ZipFile(archive) as release:
            for item in release.infolist():
                parts = Path(item.filename).parts
                if item.filename.startswith("/") or ".." in parts or any(p in FORBIDDEN_NAMES or p.startswith(".env") or p == "__MACOSX" for p in parts):
                    findings.append("release archive: unexpected private or unsafe entry")
                if item.is_dir():
                    continue
                findings += inspect("release/" + item.filename, release.read(item), args.forbid, Path(item.filename).suffix in TEXT_SUFFIXES)
    for binary in args.binary:
        data = binary.read_bytes()
        findings += inspect("release executable", data, args.forbid, False)
        findings += ["release executable: embedded personal home path"] if re.search(PATTERNS["personal home path"], data) else []
    if findings:
        print("PUBLICATION AUDIT FAILED")
        for finding in findings:
            print("- " + finding)
        return 1
    print(f"PUBLICATION AUDIT PASSED: {len(files)} public files, {len(args.archive)} archive(s), {len(args.binary)} executable(s)")
    print("Checked credential patterns, private identifiers, home paths, archive entries and PNG metadata.")
    print("This pattern-based check does not replace manual image and code review.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
