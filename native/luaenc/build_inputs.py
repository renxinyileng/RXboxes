#!/usr/bin/env python3
"""Encrypt Gradle artifact inputs before Android packaging and signing."""
import argparse
import json
import pathlib
import tempfile
import zipfile

import pack


def transform(manifest, output, kind, lua_exe=None):
    key = pack.load_key()
    entries = {}

    def add(name, data):
        path = pathlib.PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts or "\\" in name or ":" in name:
            raise ValueError(f"Unsafe resource path: {name}")
        if name in entries and entries[name] != data:
            raise ValueError(f"Conflicting resource: {name}")
        entries[name] = data

    for directory in manifest["directories"]:
        root = pathlib.Path(directory)
        for path in sorted(root.rglob("*")):
            if path.is_file():
                add(path.relative_to(root).as_posix(), path.read_bytes())
    for jar in manifest["jars"]:
        with zipfile.ZipFile(jar) as archive:
            pack._check_archive(archive)
            for item in archive.infolist():
                if not item.is_dir():
                    add(item.filename, archive.read(item))

    count = 0
    with tempfile.TemporaryDirectory(prefix="luaenc-build-") as temporary:
        source = pathlib.Path(temporary) / "input.lua"
        compiled = pathlib.Path(temporary) / "output.luac"
        for name, data in entries.items():
            if not name.endswith(".lua"):
                continue
            if lua_exe and not data.startswith(pack.PREFIX):
                source.write_bytes(pack.decrypt(data, key))
                pack.strip_compile(lua_exe, source, compiled)
                data = compiled.read_bytes()
            encrypted = pack.encrypt(data, key)
            pack._verify_v2(encrypted, key)
            entries[name] = encrypted
            count += 1

    output = pathlib.Path(output)
    if kind == "directory":
        output.mkdir(parents=True, exist_ok=True)
        for name, data in entries.items():
            target = output / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
            for name, data in sorted(entries.items()):
                archive.writestr(name, data)
    print(f"luaenc: encrypted and authenticated {count} Lua inputs")
    return count


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=pathlib.Path)
    parser.add_argument("output")
    parser.add_argument("--kind", choices=("directory", "jar"), required=True)
    parser.add_argument("--lua")
    args = parser.parse_args()
    transform(json.loads(args.manifest.read_text(encoding="utf-8")),
              args.output, args.kind, args.lua)
