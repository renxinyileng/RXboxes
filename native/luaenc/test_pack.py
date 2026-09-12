#!/usr/bin/env python3
"""Host integration checks for packaging; requires the project's Lua and C codec.

python3 test_pack.py --lua path/to/lua --codec path/to/luaenc-test
The codec is luaenc.c compiled with -DLUAENC_TEST_MAIN.
"""
import argparse
import contextlib
import io
import os
import pathlib
import random
import subprocess
import tempfile
import unittest
from unittest import mock
import zipfile

import pack


MODULE = """
local sum = 0
for i = 1, 10 do sum = sum + i end
for _, value in ipairs({1, 2, 3}) do sum = sum + value end
local function add(x) return function(y) return x + y end end
local sorted = {9, 1, 4}
table.sort(sorted)
assert(sorted[1] == 1 and sorted[3] == 9)
assert(7 // 2 == 3 and (7 & 3) == 3)
assert(bit32.band(7, 3) == 3 and bit.bxor(3, 5) == 6)
return {answer = add(sum)(3), fraction = 3.25, label = '插件 module'}
""".encode("utf-8")


class PackagingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.key = pack.load_key()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="lua pack ")
        self.addCleanup(self.temp.cleanup)
        self.folder = pathlib.Path(self.temp.name)

    def lua(self, script, *args):
        result = pack.run_lua_helper(self.lua_exe, script, *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def verify(self, apk, lua_exe=None):
        with contextlib.redirect_stdout(io.StringIO()):
            pack.verify_apk(apk, self.key, lua_exe)

    def test_strip_compiles_without_running_source_or_lua_init(self):
        source = self.folder / "插件 source.lua"
        target = self.folder / "compiled output.luac"
        source.write_text("error('source must not run during packaging')", encoding="utf-8")
        with mock.patch.dict(os.environ, {
            "LUA_INIT": "error('LUA_INIT must be ignored')",
            "LUA_INIT_5_4": "error('LUA_INIT_5_4 must be ignored')",
        }):
            pack.strip_compile(self.lua_exe, source, target)
        self.assertTrue(target.read_bytes().startswith(b"\x1bLua"))
        self.lua("assert(loadfile(arg[1]))", target)

    def test_invalid_source_fails_compilation(self):
        source = self.folder / "invalid.lua"
        target = self.folder / "invalid.luac"
        source.write_bytes(b"return function(")
        with self.assertRaisesRegex(SystemExit, "strip"):
            pack.strip_compile(self.lua_exe, source, target)
        self.assertFalse(target.exists())

    def test_compiled_module_keeps_behavior_after_encryption(self):
        source = self.folder / "source.lua"
        binary = self.folder / "compiled.luac"
        encrypted = self.folder / "sample.lua"
        source.write_bytes(MODULE)
        pack.strip_compile(self.lua_exe, source, binary)
        encrypted.write_bytes(pack.encrypt(binary.read_bytes(), self.key))
        self.lua("""
local function check(module)
  assert(module.answer == 64 and module.fraction == 3.25)
  assert(module.label == '插件 module')
end
check(assert(loadfile(arg[1]))())
check(assert(loadfile(arg[2]))())
package.path = arg[3] .. '/?.lua'
check(require('sample'))
local handle = assert(io.open(arg[1], 'rb'))
local bytes = assert(handle:read('a'))
assert(handle:close())
check(assert(load(bytes, 'binary module', 'b'))())
""", binary, encrypted, self.folder)

    def test_python_and_c_encryption_agree(self):
        generator = random.Random(0)
        nonce = bytes(range(1, 9))  # fixed nonce used by LUAENC_TEST_MAIN
        for size in (0, 1, 31, 32, 33, 100, 4096, 100000):
            with self.subTest(size=size):
                plain = bytes(generator.getrandbits(8) for _ in range(size))
                c_encrypted = subprocess.run(
                    [self.codec_exe, "enc"], input=plain,
                    capture_output=True, check=True).stdout
                self.assertEqual(c_encrypted, pack.encrypt(plain, self.key, nonce))
                self.assertEqual(pack.decrypt(c_encrypted, self.key), plain)
                c_plain = subprocess.run(
                    [self.codec_exe, "dec"], input=pack.encrypt(plain, self.key),
                    capture_output=True, check=True).stdout
                self.assertEqual(c_plain, plain)

    def test_apk_rewrite_preserves_other_entries_and_is_idempotent(self):
        source = self.folder / "input.apk"
        encrypted = self.folder / "output.apk"
        second = self.folder / "second.apk"
        pre_encrypted = pack.encrypt(b"return 7", self.key)
        with zipfile.ZipFile(source, "w") as archive:
            archive.writestr("assets/sample.lua", MODULE, zipfile.ZIP_DEFLATED)
            archive.writestr("assets/already.lua", pre_encrypted)
            archive.writestr("lib/arm64-v8a/libexample.so", b"native bytes", zipfile.ZIP_STORED)
        self.assertEqual(pack.enc_apk(source, encrypted, self.key, self.lua_exe), 1)
        self.verify(encrypted, self.lua_exe)
        with zipfile.ZipFile(encrypted) as archive:
            self.assertEqual(archive.read("assets/already.lua"), pre_encrypted)
            self.assertTrue(pack.decrypt(archive.read("assets/sample.lua"), self.key)
                            .startswith(b"\x1bLua"))
            self.assertEqual(archive.read("lib/arm64-v8a/libexample.so"), b"native bytes")
            self.assertEqual(archive.getinfo("lib/arm64-v8a/libexample.so").compress_type,
                             zipfile.ZIP_STORED)
        self.assertEqual(pack.enc_apk(encrypted, second, self.key, self.lua_exe), 0)
        with zipfile.ZipFile(encrypted) as first, zipfile.ZipFile(second) as repeat:
            self.assertEqual(first.namelist(), repeat.namelist())
            for name in first.namelist():
                self.assertEqual(first.read(name), repeat.read(name))

    def test_verify_parses_but_does_not_execute(self):
        apk = self.folder / "compile-only.apk"
        with zipfile.ZipFile(apk, "w") as archive:
            archive.writestr("assets/main.lua", pack.encrypt(b"error('must not run')", self.key))
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(pack.main([
                "pack.py", "verify-apk", str(apk), "--lua", self.lua_exe]), 0)

    def test_verify_rejects_invalid_content_even_with_valid_envelope(self):
        apk = self.folder / "invalid.apk"
        with zipfile.ZipFile(apk, "w") as archive:
            archive.writestr("assets/main.lua", pack.encrypt(b"return function(", self.key))
        self.verify(apk)  # envelope-only mode deliberately makes no syntax claim
        with self.assertRaisesRegex(SystemExit, "assets/main.lua"):
            self.verify(apk, self.lua_exe)

    def test_verify_rejects_plaintext_and_missing_scripts(self):
        apk = self.folder / "not-encrypted.apk"
        for entries in ({"assets/main.lua": b"return 1"}, {"file.txt": b"no scripts"}):
            with self.subTest(entries=entries):
                with zipfile.ZipFile(apk, "w") as archive:
                    for name, data in entries.items():
                        archive.writestr(name, data)
                with self.assertRaises(SystemExit):
                    self.verify(apk, self.lua_exe)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", required=True, help="Lua built from this repository")
    parser.add_argument("--codec", required=True, help="luaenc.c with LUAENC_TEST_MAIN")
    arguments = parser.parse_args()
    PackagingTests.lua_exe = str(pathlib.Path(arguments.lua).resolve())
    PackagingTests.codec_exe = str(pathlib.Path(arguments.codec).resolve())
    unittest.main(argv=[__file__], verbosity=2)
