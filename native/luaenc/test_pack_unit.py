#!/usr/bin/env python3
"""Packaging regressions that need only Python, no host Lua or Android SDK."""
import contextlib
import io
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

import pack
import build_inputs


class PackagingUnitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.key = pack.load_key()

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="lua encryption ")
        self.addCleanup(temporary.cleanup)
        self.folder = pathlib.Path(temporary.name)
        self.source = self.folder / "source.lua"
        self.target = self.folder / "target.lua"
        self.source.write_bytes(b"return 42")
        self.target.write_bytes(b"existing destination")

    def assert_preserved(self):
        self.assertEqual(self.source.read_bytes(), b"return 42")
        self.assertEqual(self.target.read_bytes(), b"existing destination")
        self.assertEqual(list(self.folder.glob("*.tmp")), [])

    def test_file_roundtrip_and_in_place_idempotence(self):
        pack.enc_file(self.source, self.target, self.key)
        encrypted = self.target.read_bytes()
        self.assertEqual(pack.decrypt(encrypted, self.key), b"return 42")
        pack.enc_file(self.target, self.target, self.key)
        self.assertEqual(self.target.read_bytes(), encrypted)
        self.assertEqual(self.source.read_bytes(), b"return 42")

    def test_file_replace_failure_preserves_both_files(self):
        for target in (self.source, self.target):
            with self.subTest(target=target), mock.patch.object(
                    pack.os, "replace", side_effect=OSError("replace failed")):
                with self.assertRaises(OSError):
                    pack.enc_file(self.source, target, self.key)
                self.assert_preserved()

    def test_file_flush_failure_preserves_both_files(self):
        with mock.patch.object(pack.os, "fsync", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                pack.enc_file(self.source, self.target, self.key)
        self.assert_preserved()

    def test_file_corrupted_output_is_never_published(self):
        with mock.patch.object(pack, "encrypt", return_value=pack.MAGIC + b"broken"):
            with self.assertRaises(ValueError):
                pack.enc_file(self.source, self.target, self.key)
        self.assert_preserved()

    def test_file_damaged_input_preserves_destination(self):
        damaged = pack.encrypt(b"return 42", self.key)[:-1]
        self.source.write_bytes(damaged)
        with self.assertRaises(ValueError):
            pack.enc_file(self.source, self.target, self.key)
        self.assertEqual(self.source.read_bytes(), damaged)
        self.assertEqual(self.target.read_bytes(), b"existing destination")
        self.assertEqual(list(self.folder.glob("*.tmp")), [])

    def archive(self, entries):
        apk = self.folder / "input.apk"
        with zipfile.ZipFile(apk, "w") as archive:
            for name, data in entries.items():
                archive.writestr(name, data)
        return apk

    def test_conflicting_nonce_is_rejected_even_with_valid_tags(self):
        nonce = bytes(range(pack.NONCE_LEN))
        apk = self.archive({
            "assets/first.lua": pack.encrypt(b"return 1", self.key, nonce),
            "assets/second.lua": pack.encrypt(b"return 2", self.key, nonce),
        })
        with self.assertRaisesRegex(SystemExit, "复用 nonce"):
            pack.verify_apk(apk, self.key)
        original = apk.read_bytes()
        with self.assertRaisesRegex(SystemExit, "复用 nonce"):
            pack.enc_apk(apk, apk, self.key)
        self.assertEqual(apk.read_bytes(), original)
        self.assertEqual(list(self.folder.glob("*.tmp")), [])

    def test_random_nonce_failure_cannot_publish_unsafe_apk(self):
        apk = self.archive({"first.lua": b"return 1", "second.lua": b"return 2"})
        original = apk.read_bytes()
        with mock.patch.object(pack.os, "urandom", return_value=bytes(pack.NONCE_LEN)):
            with self.assertRaisesRegex(SystemExit, "复用 nonce"):
                pack.enc_apk(apk, apk, self.key)
        self.assertEqual(apk.read_bytes(), original)
        self.assertEqual(list(self.folder.glob("*.tmp")), [])

    def test_identical_encrypted_copies_are_allowed(self):
        data = pack.encrypt(b"return 1", self.key)
        apk = self.archive({"first.lua": data, "second.lua": data})
        with contextlib.redirect_stdout(io.StringIO()):
            pack.verify_apk(apk, self.key)
            self.assertEqual(pack.enc_apk(apk, apk, self.key), 0)

    def test_fresh_nonces_and_archive_roundtrip(self):
        apk = self.archive({"first.lua": b"return 1", "second.lua": b"return 2"})
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(pack.enc_apk(apk, apk, self.key), 2)
        with zipfile.ZipFile(apk) as archive:
            first, second = archive.read("first.lua"), archive.read("second.lua")
        self.assertNotEqual(first[8:20], second[8:20])
        self.assertEqual(pack.decrypt(first, self.key), b"return 1")
        self.assertEqual(pack.decrypt(second, self.key), b"return 2")

    def test_helper_decodes_utf8_independent_of_windows_locale(self):
        helper = self.folder / "helper.py"
        helper.write_text("import sys\nsys.stdout.buffer.write('插件'.encode('utf-8'))\n",
                          encoding="utf-8")
        # Python accepts the same -E - stdin convention as the Lua helper.
        result = pack.run_lua_helper(sys.executable, helper.read_text(encoding="utf-8"))
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "插件")

    def test_helper_timeout_preserves_apk_and_cleans_temp(self):
        apk = self.archive({"first.lua": b"return 1"})
        original = apk.read_bytes()
        with mock.patch.object(pack.subprocess, "run",
                               side_effect=subprocess.TimeoutExpired("lua", 60)):
            with self.assertRaises(subprocess.TimeoutExpired):
                pack.enc_apk(apk, apk, self.key, "lua")
        self.assertEqual(apk.read_bytes(), original)
        self.assertEqual(list(self.folder.glob("*.tmp")), [])

    def test_build_directory_encrypts_lua_and_preserves_assets(self):
        source = self.folder / "assets"
        source.mkdir()
        (source / "main.lua").write_bytes(b"return 42")
        (source / "icon.png").write_bytes(b"image bytes")
        output = self.folder / "encrypted"
        manifest = {"directories": [str(source)], "jars": []}
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(build_inputs.transform(manifest, output, "directory"), 1)
        self.assertEqual(pack.decrypt((output / "main.lua").read_bytes(), self.key), b"return 42")
        self.assertEqual((output / "icon.png").read_bytes(), b"image bytes")
        self.assertEqual((source / "main.lua").read_bytes(), b"return 42")

    def test_build_java_resources_merge_and_encrypt(self):
        resources = self.folder / "resources"
        resources.mkdir()
        (resources / "local.lua").write_bytes(b"return 1")
        jar = self.archive({"lua/library.lua": b"return 2", "config.txt": b"config"})
        output = self.folder / "encrypted.jar"
        with contextlib.redirect_stdout(io.StringIO()):
            count = build_inputs.transform(
                {"directories": [str(resources)], "jars": [str(jar)]}, output, "jar")
        self.assertEqual(count, 2)
        with zipfile.ZipFile(output) as archive:
            self.assertEqual(pack.decrypt(archive.read("local.lua"), self.key), b"return 1")
            self.assertEqual(pack.decrypt(archive.read("lua/library.lua"), self.key), b"return 2")
            self.assertEqual(archive.read("config.txt"), b"config")

    def test_build_inputs_reject_traversal_and_conflicting_resources(self):
        for name in ("../escape.lua", "/absolute.lua", "C:/absolute.lua", "..\\escape.lua"):
            with self.subTest(name=name):
                jar = self.archive({name: b"return 1"})
                with self.assertRaisesRegex(ValueError, "Unsafe"):
                    build_inputs.transform({"directories": [], "jars": [str(jar)]},
                                           self.folder / "output", "directory")
        jar = self.archive({"source.lua": b"return 99"})
        with self.assertRaisesRegex(ValueError, "Conflicting"):
            build_inputs.transform({"directories": [str(self.folder)], "jars": [str(jar)]},
                                   self.folder / "output.jar", "jar")


if __name__ == "__main__":
    unittest.main(verbosity=2)
