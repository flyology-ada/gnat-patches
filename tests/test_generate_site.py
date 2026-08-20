"""Tests for the website generator."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from sitegen import diffs, highlight, markdown, model, render  # noqa: E402


PATCH = """diff --git a/gcc/c-family/c-ada-spec.cc b/gcc/c-family/c-ada-spec.cc
index c7ae03223..3d452a1d2 100644
--- a/gcc/c-family/c-ada-spec.cc
+++ b/gcc/c-family/c-ada-spec.cc
@@ -10,6 +10,7 @@ dump_ada_node (pretty_printer *pp)
   case BOOLEAN_TYPE:
     if (TYPE_NAME (node))
-      pp_string (pp, "old");
+      pp_string (pp, "new");
+      pp_string (pp, "extra");
   break;
diff --git a/gcc/testsuite/g++.dg/ada-spec/demo.C b/gcc/testsuite/g++.dg/ada-spec/demo.C
new file mode 100644
index 000000000..1e51ec035
--- /dev/null
+++ b/gcc/testsuite/g++.dg/ada-spec/demo.C
@@ -0,0 +1,2 @@
+/* { dg-do compile } */
+int demo (void) { return 0; }
"""


class MarkdownTest(unittest.TestCase):
    def test_intraword_underscores_are_not_emphasis(self):
        """Ada identifiers must survive rendering."""
        rendered = markdown.render("Set C_Pass_By_Copy on External_Name entries.")
        self.assertIn("C_Pass_By_Copy", rendered)
        self.assertIn("External_Name", rendered)
        self.assertNotIn("<em>", rendered)

    def test_emphasis_and_strong(self):
        self.assertEqual(markdown.render("*one* and **two**"),
                         "<p><em>one</em> and <strong>two</strong></p>")
        self.assertEqual(markdown.render("_flanked_ emphasis"),
                         "<p><em>flanked</em> emphasis</p>")

    def test_code_span_keeps_angle_brackets(self):
        rendered = markdown.render("A `vector<int>` and a bare vector<int>.")
        self.assertIn("<code>vector&lt;int&gt;</code>", rendered)
        self.assertIn("bare vector&lt;int&gt;", rendered)

    def test_raw_html_is_refused(self):
        with self.assertRaises(markdown.MarkdownError):
            markdown.render("<div>markup</div>")

    def test_unclosed_fence_is_refused(self):
        with self.assertRaises(markdown.MarkdownError):
            markdown.render("```ada\nprocedure P;\n")

    def test_nested_and_loose_lists(self):
        self.assertEqual(
            markdown.render("- a\n- b\n  - c\n"),
            "<ul><li>a</li><li>b<ul><li>c</li></ul></li></ul>",
        )
        self.assertEqual(
            markdown.render("- a\n\n- b\n"),
            "<ul><li><p>a</p></li><li><p>b</p></li></ul>",
        )

    def test_ordered_list_continuation_keeps_every_character(self):
        rendered = markdown.render("1. first\n2. second\n\n   continued\n")
        self.assertIn("<p>continued</p>", rendered)

    def test_table(self):
        rendered = markdown.render("| a | b |\n| --- | ---: |\n| 1 | 2 |\n")
        self.assertIn('<th style="text-align:right">b</th>', rendered)
        self.assertIn("<td>1</td>", rendered)

    def test_headings_carry_identifiers(self):
        rendered = markdown.render("### Staged subjects\n")
        self.assertIn('<h3 id="staged-subjects">Staged subjects</h3>', rendered)

    def test_duplicate_headings_get_distinct_identifiers(self):
        rendered = markdown.render("# Same\n\n# Same\n")
        self.assertIn('id="same"', rendered)
        self.assertIn('id="same-1"', rendered)

    def test_heading_offset_and_strip(self):
        source = "# Title\n\n## Section\n"
        stripped = markdown.strip_first_heading(source)
        self.assertNotIn("# Title", stripped)
        rendered = markdown.render(stripped, heading_offset=1)
        self.assertIn("<h3", rendered)

    def test_link_resolver_rewrites_destinations(self):
        rendered = markdown.render(
            "[x](../../bundles/demo/README.md)", link_resolver=lambda value: "/here/"
        )
        self.assertIn('href="/here/"', rendered)

    def test_hard_break_and_escape(self):
        self.assertEqual(markdown.render("a  \nb"), "<p>a<br>b</p>")
        self.assertEqual(markdown.render("a \\* b"), "<p>a * b</p>")

    def test_first_heading(self):
        self.assertEqual(markdown.first_heading("# C++ Ada `char8_t` mapping\n"),
                         "C++ Ada char8_t mapping")

    def test_every_repository_document_renders(self):
        documents = sorted(ROOT.glob("bundles/*/README.md"))
        documents.append(ROOT / "bundles" / "README.md")
        documents.extend(sorted(ROOT.glob("panels/*/README.md")))
        for path in documents:
            with self.subTest(path=path.relative_to(ROOT)):
                self.assertTrue(markdown.render(path.read_text(encoding="utf-8")))


class HighlightTest(unittest.TestCase):
    def test_ada_tokens(self):
        rendered = highlight.highlight("ada", "with Interfaces.C; -- note")
        self.assertIn('<span class="token-keyword">with</span>', rendered)
        self.assertIn('<span class="token-type">Interfaces.C</span>', rendered)
        self.assertIn('<span class="token-comment">-- note</span>', rendered)

    def test_cpp_tokens_and_block_comment_carry(self):
        rendered = highlight.highlight("cpp", "/* open\n still */ int x;")
        self.assertEqual(rendered.count('class="token-comment"'), 2)
        self.assertIn('<span class="token-type">int</span>', rendered)

    def test_shell_tokens(self):
        rendered = highlight.highlight("shell", '# note\nif [[ $x ]]; then')
        self.assertIn('<span class="token-comment"># note</span>', rendered)
        self.assertIn('<span class="token-attribute">$x</span>', rendered)

    def test_escapes_unknown_language(self):
        self.assertEqual(highlight.highlight("text", "a < b & c"), "a &lt; b &amp; c")

    def test_language_selection(self):
        self.assertEqual(highlight.language_for_info("c++"), "cpp")
        self.assertEqual(highlight.language_for_path("gcc/x/demo.C"), "cpp")
        self.assertEqual(highlight.language_for_path("x/consumer.adb"), "ada")
        self.assertEqual(highlight.language_for_path("x/notes.txt"), "text")


class DiffTest(unittest.TestCase):
    def test_parse_counts_and_kinds(self):
        patch = diffs.parse(PATCH)
        self.assertEqual([file.path for file in patch.files],
                         ["gcc/c-family/c-ada-spec.cc", "gcc/testsuite/g++.dg/ada-spec/demo.C"])
        self.assertEqual(patch.files[0].kind, "modified")
        self.assertEqual(patch.files[1].kind, "added")
        self.assertEqual((patch.additions, patch.deletions), (4, 1))

    def test_line_numbering(self):
        hunk = diffs.parse(PATCH).files[0].hunks[0]
        context = [line for line in hunk.lines if line.kind == "context"]
        self.assertEqual(context[0].old_number, 10)
        self.assertEqual(context[0].new_number, 10)
        inserted = [line for line in hunk.lines if line.kind == "insert"]
        self.assertEqual([line.new_number for line in inserted], [12, 13])
        deleted = [line for line in hunk.lines if line.kind == "delete"]
        self.assertEqual([line.old_number for line in deleted], [12])

    def test_render_highlights_by_target_language(self):
        markup = diffs.render(diffs.parse(PATCH), identifier="demo")
        self.assertIn('id="demo-1"', markup)
        self.assertIn('class="token-string"', markup)
        self.assertIn("Removed line", markup)

    def test_malformed_patch_is_refused(self):
        with self.assertRaises(diffs.DiffError):
            diffs.parse("not a patch at all\n")
        with self.assertRaises(diffs.DiffError):
            diffs.parse("diff --git a/x b/x\n--- a/x\n+++ b/x\n")

    def test_every_repository_patch_parses(self):
        for path in sorted(ROOT.glob("bundles/*/patches/*.patch")):
            with self.subTest(path=path.relative_to(ROOT)):
                patch = diffs.parse(path.read_text(encoding="utf-8"))
                self.assertTrue(patch.files)


class LinkResolverTest(unittest.TestCase):
    def test_bundle_readme_becomes_a_bundle_page(self):
        resolve = render.link_resolver("panels/cxx-ada-spec/README.md", "../")
        self.assertEqual(resolve("../../bundles/demo/README.md"), "../bundles/demo/")

    def test_sibling_bundle_link(self):
        resolve = render.link_resolver("bundles/README.md", "../")
        self.assertEqual(resolve("demo/README.md"), "../bundles/demo/")

    def test_fragment_and_absolute_links_are_untouched(self):
        resolve = render.link_resolver("bundles/README.md", "../")
        self.assertEqual(resolve("#anchor"), "#anchor")
        self.assertEqual(resolve("https://example.com"), "https://example.com")

    def test_other_repository_paths_go_to_github(self):
        resolve = render.link_resolver("bundles/README.md", "../")
        self.assertEqual(
            resolve("../scripts/build-gnat.sh"),
            f"{model.REPOSITORY_URL}/blob/main/scripts/build-gnat.sh",
        )


class ReleaseTest(unittest.TestCase):
    def release(self, tag, *, prerelease=False, assets=()):
        return model.Release(
            tag=tag,
            name=f"name {tag}",
            url=f"https://example.com/{tag}",
            prerelease=prerelease,
            published_at="2026-01-01T00:00:00Z",
            assets=tuple(assets),
        )

    def test_exact_source_tag_wins_over_the_major_tag(self):
        releases = {
            "patchset-1.1.0-gcc-16": self.release("patchset-1.1.0-gcc-16"),
            "patchset-1.1.0-gcc-16.2.0": self.release("patchset-1.1.0-gcc-16.2.0"),
        }
        found = model.release_for(releases, "1.1.0", 16, "16.2.0")
        self.assertEqual(found["tag"], "patchset-1.1.0-gcc-16.2.0")
        self.assertEqual(found["alire_version"], "16.2.0-patchset.1.1.0")

    def test_major_tag_is_accepted_for_earlier_patchsets(self):
        releases = {"patchset-1.0.1-gcc-15": self.release("patchset-1.0.1-gcc-15")}
        self.assertEqual(
            model.release_for(releases, "1.0.1", 15, "15.3.0")["tag"],
            "patchset-1.0.1-gcc-15",
        )

    def test_absent_release_is_none(self):
        self.assertIsNone(model.release_for({}, "1.2.0", 16, "16.2.0"))

    def test_offline_reports_no_release_facts(self):
        self.assertIsNone(model.fetch_releases(offline=True))

    def test_platforms_come_from_asset_names(self):
        releases = {
            "patchset-1.1.0-gcc-13.2.0": self.release(
                "patchset-1.1.0-gcc-13.2.0",
                assets=[
                    "gnat-flyology-native-gcc-13.2.0-patchset-1.1.0-linux-x86_64.tar.gz",
                    "gnat-flyology-native-gcc-13.2.0-patchset-1.1.0-macos-aarch64.tar.gz",
                ],
            )
        }
        found = model.release_for(releases, "1.1.0", 13, "13.2.0")
        self.assertEqual(found["platforms"], ["Linux x86-64", "macOS AArch64"])


class SyntheticRepositoryTest(unittest.TestCase):
    """The generator must refuse to publish claims the repository cannot support."""

    def setUp(self):
        self.directory = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.directory)
        self.build()

    def build(self):
        root = self.directory
        (root / "sources").mkdir()
        (root / "sources" / "gcc-13.2.0.toml").write_text(
            'schema = 1\nversion = "13.2.0"\nmajor = 13\n'
            'release_tag = "releases/gcc-13.2.0"\n'
            'release_commit = "c891d8dc"\nrelease_tree = "e0036ea6"\n',
            encoding="utf-8",
        )

        bundle = root / "bundles" / "demo"
        (bundle / "patches").mkdir(parents=True)
        (bundle / "tests").mkdir()
        (bundle / "patches" / "gcc-13.patch").write_text(PATCH, encoding="utf-8")
        (bundle / "tests" / "demo.C").write_text("int demo (void) { return 0; }\n", encoding="utf-8")
        runner = bundle / "run-test.sh"
        runner.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
        runner.chmod(0o755)
        (bundle / "README.md").write_text("# Demo bundle\n\nProse.\n", encoding="utf-8")
        (root / "bundles" / "README.md").write_text("# Bundles\n\nIndex.\n", encoding="utf-8")

        self.patch_digest = model.sha256(bundle / "patches" / "gcc-13.patch")
        self.fixture_digest = model.sha256(bundle / "tests" / "demo.C")
        self.write_manifest()

        (root / "patchsets" / "1.0.0").mkdir(parents=True)
        self.write_patchset(bundles=["demo"])

    def write_manifest(self, **overrides):
        values = {
            "status": "accepted",
            "patch_sha": self.patch_digest,
            "fixture_sha": self.fixture_digest,
            "affected": '["13.2.0"]',
            "versions": '["13.2.0"]',
        }
        values.update(overrides)
        (self.directory / "bundles" / "demo" / "manifest.toml").write_text(
            f'''schema = 1
id = "demo"
status = "{values['status']}"
standalone_patch = true
introduced_in_patchset = "1.0.0"
problem = "A demonstration problem."
upstream_issue = "None."
affected_versions = {values['affected']}
known_good_versions = []
source_provenance = "Repository-authored."
files_modified = ["gcc/c-family/c-ada-spec.cc"]
regression_tests = ["gcc/testsuite/g++.dg/ada-spec/demo.C"]
repository_fixture = "bundles/demo/tests/demo.C"
fixture_sha256 = "{values['fixture_sha']}"
repository_test_runner = "bundles/demo/run-test.sh"
application_command = "patch -p1"
build_command = "./scripts/build-gnat.sh"
test_command = "./scripts/run-regressions.sh"
expected_failure_before_patch = "It fails."
expected_success_after_patch = "It passes."
upstream_submission_state = "Not filed."
licensing = "GPL-3.0-or-later."

[[variants]]
id = "gcc-13"
versions = {values['versions']}
source_flavors = ["linux"]
patch = "bundles/demo/patches/gcc-13.patch"
sha256 = "{values['patch_sha']}"
''',
            encoding="utf-8",
        )

    def write_patchset(self, *, bundles=(), controls=(), staged=()):
        (self.directory / "patchsets" / "1.0.0" / "gcc-13.toml").write_text(
            f"""schema = 1
patchset_version = "1.0.0"
gcc_major = 13
source_version = "13.2.0"
bundles = {json.dumps(list(bundles))}
control_tests = {json.dumps(list(controls))}
staged_bundles = {json.dumps(list(staged))}
""",
            encoding="utf-8",
        )

    def load(self):
        return model.load_catalog(self.directory, releases=None)

    def test_a_consistent_repository_loads(self):
        catalog = self.load()
        self.assertEqual(catalog["latest_patchset"], "1.0.0")
        self.assertEqual(catalog["bundles"][0]["title"], "Demo bundle")
        self.assertEqual(catalog["bundles"][0]["roles"]["1.0.0"]["13"]["role"], model.PATCHED)
        self.assertEqual(catalog["bundles"][0]["roles"]["1.0.0"]["13"]["variant"], "gcc-13")
        self.assertFalse(catalog["publication_checked"])

    def test_a_control_test_is_not_patched(self):
        self.write_patchset(controls=["demo"])
        catalog = self.load()
        self.assertEqual(catalog["bundles"][0]["roles"]["1.0.0"]["13"]["role"], model.CONTROL)
        self.assertIsNone(catalog["bundles"][0]["roles"]["1.0.0"]["13"]["variant"])

    def test_a_wrong_patch_checksum_stops_the_build(self):
        self.write_manifest(patch_sha="0" * 64)
        with self.assertRaisesRegex(model.CatalogError, "hashes to"):
            self.load()

    def test_a_wrong_fixture_checksum_stops_the_build(self):
        self.write_manifest(fixture_sha="0" * 64)
        with self.assertRaisesRegex(model.CatalogError, "hashes to"):
            self.load()

    def test_an_unknown_bundle_reference_stops_the_build(self):
        self.write_patchset(bundles=["demo", "absent"])
        with self.assertRaisesRegex(model.CatalogError, "unknown bundle absent"):
            self.load()

    def test_an_accepted_bundle_outside_every_patchset_stops_the_build(self):
        self.write_patchset()
        with self.assertRaisesRegex(model.CatalogError, "appears in no patchset"):
            self.load()

    def test_a_staged_bundle_a_patchset_publishes_stops_the_build(self):
        self.write_manifest(status="staged")
        with self.assertRaisesRegex(model.CatalogError, "published by a patchset"):
            self.load()

    def test_an_affected_release_without_a_variant_stops_the_build(self):
        self.write_manifest(affected='["13.2.0", "14.2.0"]')
        with self.assertRaisesRegex(model.CatalogError, "without a patch variant"):
            self.load()

    def test_a_bundle_both_patched_and_control_stops_the_build(self):
        self.write_patchset(bundles=["demo"], controls=["demo"])
        with self.assertRaisesRegex(model.CatalogError, "both patched and a control"):
            self.load()

    def test_a_missing_source_manifest_stops_the_build(self):
        (self.directory / "sources" / "gcc-13.2.0.toml").unlink()
        with self.assertRaisesRegex(model.CatalogError, "no GCC source manifests"):
            self.load()


class RepositoryCatalogTest(unittest.TestCase):
    """The real manifests must load and keep their published meaning."""

    @classmethod
    def setUpClass(cls):
        cls.catalog = model.load_catalog(ROOT, releases=None)
        cls.panels = model.load_panels(ROOT, cls.catalog["bundles"])

    def test_patchsets_are_ordered_newest_first(self):
        versions = [patchset["version"] for patchset in self.catalog["patchsets"]]
        self.assertEqual(versions, sorted(versions, key=model.version_key, reverse=True))
        self.assertTrue(self.catalog["patchsets"][0]["latest"])

    def test_a_bundle_can_be_patched_and_a_control_in_one_patchset(self):
        """The site exists to show this: a bundle is not the same on every major."""
        latest = self.catalog["latest_patchset"]
        roles = {
            bundle["id"]: {
                major: entry["role"] for major, entry in bundle["roles"][latest].items()
            }
            for bundle in self.catalog["bundles"]
        }
        mixed = [
            identifier
            for identifier, entries in roles.items()
            if model.PATCHED in entries.values() and model.CONTROL in entries.values()
        ]
        self.assertTrue(mixed, "no bundle mixes patched and control roles")

    def test_every_staged_bundle_is_staged_by_the_latest_patchset(self):
        latest = self.catalog["latest_patchset"]
        for bundle in self.catalog["bundles"]:
            if bundle["status"] != "staged":
                continue
            roles = {entry["role"] for entry in bundle["roles"][latest].values()}
            self.assertEqual(roles, {model.STAGED}, bundle["id"])

    def test_panel_evidence_resolves(self):
        self.assertTrue(self.panels)
        for panel in self.panels:
            for feature in panel["matrix"]["features"]:
                self.assertTrue(feature["evidence_references"], feature["id"])

    def test_every_panel_names_its_directory(self):
        for panel in self.panels:
            self.assertTrue((ROOT / "panels" / panel["id"] / "matrix.toml").is_file())
            self.assertTrue(panel["title"])
            self.assertTrue(panel["summary"])


class GenerationTest(unittest.TestCase):
    """The generator must produce a complete site without reaching the network."""

    @classmethod
    def setUpClass(cls):
        cls.output = Path(tempfile.mkdtemp())
        result = subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts" / "generate-site.py"),
                "--offline",
                "--output",
                str(cls.output / "site"),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        cls.result = result

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.output, ignore_errors=True)

    def site(self, *parts):
        return self.output.joinpath("site", *parts)

    def test_generation_succeeds(self):
        self.assertEqual(self.result.returncode, 0, self.result.stderr)

    def test_core_pages_exist(self):
        for page in (
            ("index.html",),
            ("patchsets", "index.html"),
            ("bundles", "index.html"),
            ("unreleased", "index.html"),
            ("panels", "index.html"),
            ("panels", "cxx-ada-spec", "index.html"),
            ("panels", "cxx-ada-spec.json"),
            ("patches.json",),
            ("llms.txt",),
            (".nojekyll",),
            ("assets", "styles", "patches.css"),
            ("flyology-logo.svg",),
        ):
            with self.subTest(page=page):
                self.assertTrue(self.site(*page).is_file())

    def test_every_bundle_has_a_page_its_patch_and_its_tests(self):
        catalog = json.loads(self.site("patches.json").read_text(encoding="utf-8"))
        for bundle in catalog["bundles"]:
            identifier = bundle["id"]
            with self.subTest(bundle=identifier):
                self.assertTrue(self.site("bundles", identifier, "index.html").is_file())
                self.assertTrue(self.site("bundles", f"{identifier}.json").is_file())
                for variant in bundle["variants"]:
                    name = Path(variant["patch"]).name
                    self.assertTrue(self.site("bundles", identifier, "patches", name).is_file())
                for test in bundle["tests"]:
                    name = Path(test).name
                    self.assertTrue(self.site("bundles", identifier, "tests", name).is_file())

    def test_hosted_patches_match_the_repository(self):
        catalog = json.loads(self.site("patches.json").read_text(encoding="utf-8"))
        for bundle in catalog["bundles"]:
            for variant in bundle["variants"]:
                hosted = self.site("bundles", bundle["id"], "patches", Path(variant["patch"]).name)
                with self.subTest(patch=variant["patch"]):
                    self.assertEqual(model.sha256(hosted), variant["sha256"])

    def test_pages_are_canonical_to_the_published_domain(self):
        home = self.site("index.html").read_text(encoding="utf-8")
        self.assertIn(f'<link rel="canonical" href="{model.CANONICAL_URL}">', home)
        bundle = self.site("bundles", "cxx-ada-char8-type", "index.html").read_text(encoding="utf-8")
        self.assertIn(
            f'<link rel="canonical" href="{model.CANONICAL_URL}bundles/cxx-ada-char8-type/">',
            bundle,
        )

    def test_offline_generation_claims_no_publication(self):
        catalog = json.loads(self.site("patches.json").read_text(encoding="utf-8"))
        self.assertFalse(catalog["publication_checked"])
        self.assertIsNone(catalog["latest_published_patchset"])
        for patchset in catalog["patchsets"]:
            for target in patchset["targets"]:
                self.assertIsNone(target["release"])
        home = self.site("index.html").read_text(encoding="utf-8")
        self.assertNotIn("alr -n toolchain", home)

    def test_pages_carry_one_canonical_url_each(self):
        seen = set()
        for page in sorted(self.site().rglob("index.html")):
            text = page.read_text(encoding="utf-8")
            self.assertIn('<html lang="en">', text)
            start = text.index('<link rel="canonical" href="') + len('<link rel="canonical" href="')
            canonical = text[start:text.index('"', start)]
            self.assertNotIn(canonical, seen, f"{page} repeats {canonical}")
            seen.add(canonical)

    def test_diff_lines_are_highlighted_in_the_language_of_their_file(self):
        page = self.site("bundles", "cxx-ada-char8-type", "index.html").read_text(encoding="utf-8")
        self.assertIn('class="diff-table"', page)
        self.assertIn('class="token-comment"', page)
        self.assertIn("diff-insert", page)


if __name__ == "__main__":
    unittest.main()
