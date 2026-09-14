"""Regression tests for historical patchset page bundle scope."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUNDLE_LINK = re.compile(r'href="../../bundles/([^/"]+)/"')
ROLE_TABLE = re.compile(r'<table class="role-table">(.*?)</table>', re.DOTALL)
MEMBERSHIP_FIELDS = ("bundles", "control_tests", "staged_bundles")


class PatchsetSiteScopeTest(unittest.TestCase):
    """Each patchset page must reflect only that patchset's bundle membership."""

    @classmethod
    def setUpClass(cls):
        cls.output = Path(tempfile.mkdtemp())
        cls.site = cls.output / "site"
        cls.result = subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts" / "generate-site.py"),
                "--offline",
                "--output",
                str(cls.site),
            ],
            capture_output=True,
            text=True,
            check=False,
        )

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.output, ignore_errors=True)

    def patchset(self, version: str) -> dict:
        path = self.site / "patchsets" / f"{version}.json"
        return json.loads(path.read_text(encoding="utf-8"))["patchset"]

    def role_table_bundle_ids(self, version: str) -> set[str]:
        path = self.site / "patchsets" / version / "index.html"
        page = path.read_text(encoding="utf-8")
        table = ROLE_TABLE.search(page)
        self.assertIsNotNone(table)
        return set(BUNDLE_LINK.findall(table.group(1)))

    @staticmethod
    def membership(patchset: dict) -> set[str]:
        return {
            identifier
            for target in patchset["targets"]
            for field in MEMBERSHIP_FIELDS
            for identifier in target[field]
        }

    def test_historical_and_later_pages_show_only_their_own_bundles(self):
        self.assertEqual(self.result.returncode, 0, self.result.stderr)

        earlier = self.patchset("1.1.1")
        later = self.patchset("1.2.0")
        earlier_members = self.membership(earlier)
        later_members = self.membership(later)
        later_only = later_members - earlier_members

        self.assertTrue(later_only)
        with self.subTest(version="1.1.1"):
            self.assertEqual(self.role_table_bundle_ids("1.1.1"), earlier_members)
        with self.subTest(version="1.2.0"):
            self.assertEqual(self.role_table_bundle_ids("1.2.0"), later_members)

    def test_historical_json_remains_scoped_to_its_manifest_membership(self):
        self.assertEqual(self.result.returncode, 0, self.result.stderr)
        self.assertEqual(
            self.membership(self.patchset("1.1.1")),
            {"protected-duration-validity", "storage-model-actuals"},
        )


if __name__ == "__main__":
    unittest.main()
