"""Offline regression coverage: never contacts GitHub or CurseForge."""
import copy
from email.parser import BytesParser
from email.policy import default
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch
import urllib.error
import zipfile

SPEC = importlib.util.spec_from_file_location(
    "curseforge_release", Path(__file__).resolve().parents[1] / "scripts/curseforge_release.py")
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        # All HTTP is mocked below; keep simulated success messages out of CI logs.
        stdout = patch("sys.stdout", new_callable=io.StringIO)
        stdout.start()
        self.addCleanup(stdout.stop)
        # File-command paths are real runner files, even when HTTP is mocked.
        # Never let simulated uploads contaminate the job summary/environment.
        actors = patch.dict(os.environ, {"GITHUB_ACTOR": "DoctorB", "GITHUB_TRIGGERING_ACTOR": "DoctorB",
                                        "GITHUB_STEP_SUMMARY": "", "GITHUB_OUTPUT": "",
                                        "GITHUB_ENV": "", "GITHUB_PATH": "", "CF_API_TOKEN": ""})
        actors.start()
        self.addCleanup(actors.stop)
        self.temp = tempfile.TemporaryDirectory(prefix="hcob-release-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.output = self.root / "artifacts"
        self.version = "1.29.2"
        self.event = {
            "repository": {"full_name": release.REPOSITORY}, "action": "published",
            "sender": {"login": "DoctorB", "type": "User"},
            "release": {"id": 123, "tag_name": "v1.29.2", "draft": False, "prerelease": False,
                        "body": '# Release\n\n**Novità** — sì!\n`$(echo not-executed)`\n'},
        }
        self.fixture()

    def put(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")

    def fixture(self):
        self.put("HCOneButton/HCOneButton.toc", f"## Version: {self.version}\n## Interface: 11509\n"
                 "Core/Init.lua\nCore/State.lua\nBindings.xml\n")
        self.put("HCOneButton/Core/Init.lua", f'HCOB.VERSION = "{self.version}"\n')
        self.put("HCOneButton/Core/State.lua", f'VERSION = HCOB.VERSION or "{self.version}"\n')
        self.put("HCOneButton/Bindings.xml", "<Bindings/>\n")
        for name, text in {
            "README.md": f"Current version:** `{self.version}`\n",
            "CHANGELOG.md": f"The current release is `{self.version}`.\n\n"
                            f"## {self.version} — today\n\nCurrent changes.\n\n## 1.0.0\nOld changes.\n",
            "LICENSE": "MIT\n",
        }.items():
            self.put(name, text)
            self.put("HCOneButton/" + name, text)

    def prepare(self):
        return release.prepare(self.root, self.output, self.event, "release")

    def test_package_exact_manifest_notes_and_reproducibility(self):
        self.put("HCOneButton/local-secret.txt", "must never ship")
        self.put("tests/local.lua", "must never ship")
        manifest = self.prepare()
        self.assertEqual(manifest["gameVersion"], "1.15.9")
        self.assertEqual(manifest["projectId"], 1666468)
        self.assertEqual((self.output / manifest["notes"]).read_text(encoding="utf-8"), self.event["release"]["body"])
        with zipfile.ZipFile(self.output / manifest["zip"]) as archive:
            self.assertEqual(len(archive.namelist()), 7)
            self.assertTrue(all(name.startswith("HCOneButton/") for name in archive.namelist()))
            self.assertFalse(any("local" in name for name in archive.namelist()))
        second = release.prepare(self.root, self.root / "second", self.event, "release")
        self.assertEqual(manifest["sha256"], second["sha256"])
        with self.assertRaises(FileExistsError):
            self.prepare()

    def test_actual_repository_packages_all_current_addon_files(self):
        root = Path(__file__).resolve().parents[1]
        version, _, entries = release.toc_metadata(root)
        files = release.package_files(root, entries)
        actual = {path.relative_to(root).as_posix() for path in (root / "HCOneButton").rglob("*") if path.is_file()}
        self.assertEqual(set(files), actual)
        self.assertTrue(version)

    def test_license_allows_windows_newlines_without_changing_archive_bytes(self):
        (self.root / "HCOneButton/LICENSE").write_bytes(b"MIT\r\n")
        manifest = self.prepare()
        with zipfile.ZipFile(self.output / manifest["zip"]) as archive:
            self.assertEqual(archive.read("HCOneButton/LICENSE"), b"MIT\r\n")

    def test_bad_events_cannot_prepare_upload(self):
        variants = [("tag_name", "v9.9.9"), ("tag_name", "../../wrong"),
                    ("body", "  \n"), ("body", None), ("draft", True), ("id", None), ("prerelease", None)]
        for key, value in variants:
            event = copy.deepcopy(self.event)
            event["release"][key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                release.release_context(event, "release", self.version)
        for event_name in ("push", "pull_request", "workflow_run"):
            with self.assertRaises(ValueError):
                release.release_context(self.event, event_name, self.version)
        for field, value in (("action", "edited"), ("repository", {"full_name": "other/fork"})):
            event = {**self.event, field: value}
            with self.assertRaises(ValueError):
                release.release_context(event, "release", self.version)

    def test_only_two_exact_github_logins_can_authorize(self):
        for actor in ("DoctorB", "DoctorCalibano", "doctorb", "DOCTORCALIBANO"):
            for triggering in ("DoctorB", "DoctorCalibano"):
                event = copy.deepcopy(self.event)
                event["sender"]["login"] = actor
                # Draft author is not the person who authorizes publication.
                event["release"]["author"] = {"login": "UnrelatedDraftAuthor"}
                with patch.dict(os.environ, {"GITHUB_ACTOR": actor, "GITHUB_TRIGGERING_ACTOR": triggering}):
                    self.assertTrue(release.release_context(event, "release", self.version)["publish"])
                    self.assertFalse(release.release_context(event, "workflow_dispatch", self.version)["publish"])

    def test_unauthorized_actor_or_rerunner_cannot_access_upload(self):
        self.prepare()
        invalid = ("AnotherUser", "github-actions[bot]", "DoctorB-extra", "DoctorCalibano2", "", " DoctorB")
        with patch.object(release, "request_json") as request:
            for variable in ("GITHUB_ACTOR", "GITHUB_TRIGGERING_ACTOR"):
                for value in invalid:
                    with self.subTest(variable=variable, value=value), patch.dict(os.environ, {variable: value}):
                        for event_name in ("release", "workflow_dispatch"):
                            with self.assertRaises(ValueError):
                                release.release_context(self.event, event_name, self.version)
                        with self.assertRaises(ValueError):
                            release.upload(self.output, self.event, "release", "dummy", "1")
            request.assert_not_called()

    def test_missing_bot_or_inconsistent_sender_is_rejected(self):
        for sender in (None, {}, {"login": "AnotherUser", "type": "User"},
                       {"login": "DoctorB", "type": "Bot"}, {"login": "DoctorCalibano", "type": "User"}):
            event = {**self.event, "sender": sender}
            with self.subTest(sender=sender), self.assertRaises(ValueError):
                release.release_context(event, "release", self.version)

    def test_release_types_and_prerelease_consistency(self):
        self.assertEqual(release.release_context(self.event, "release", self.version)["releaseType"], "release")
        self.event["release"]["prerelease"] = True
        self.assertEqual(release.release_context(self.event, "release", self.version)["releaseType"], "beta")
        for kind in ("alpha", "beta"):
            version = "1.30.0-" + kind + ".1"
            self.event["release"]["tag_name"] = "v" + version
            self.assertEqual(release.release_context(self.event, "release", version)["releaseType"], kind)
        self.event["release"]["prerelease"] = False
        with self.assertRaises(ValueError):
            release.release_context(self.event, "release", version)

    def test_manual_run_builds_only_current_changelog_and_never_uploads(self):
        summary = self.root / "dry-run-summary.md"
        with patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": str(summary)}):
            manifest = release.prepare(self.root, self.output, self.event, "workflow_dispatch")
        self.assertIn("Validation only: no upload to CurseForge", summary.read_text())
        self.assertNotIn("accepted file", summary.read_text())
        self.assertFalse(manifest["publish"])
        notes = (self.output / manifest["notes"]).read_text(encoding="utf-8")
        self.assertIn("Current changes", notes)
        self.assertNotIn("Old changes", notes)
        with patch.object(release, "request_json") as request:
            with self.assertRaises(ValueError):
                release.upload(self.output, self.event, "workflow_dispatch", "dummy", "1")
            with self.assertRaises(ValueError):
                release.upload(self.output, self.event, "release", "dummy", "1")
            request.assert_not_called()

    def test_versions_and_docs_must_match(self):
        self.put("HCOneButton/Core/State.lua", 'VERSION = HCOB.VERSION or "0.0.0"')
        with self.assertRaises(ValueError):
            self.prepare()
        self.fixture()
        self.put("HCOneButton/README.md", "mismatch")
        with self.assertRaises(ValueError):
            self.prepare()
        self.fixture()
        path = self.root / "HCOneButton/HCOneButton.toc"
        path.write_text(path.read_text().replace("11509", "120001"))
        with self.assertRaises(ValueError):
            self.prepare()

    def test_unsafe_missing_and_duplicate_package_paths(self):
        for entries in (("../secret",), ("/absolute",), ("C:/absolute",),
                        (".env",), ("missing.lua",), ("Bindings.xml", "Bindings.xml")):
            with self.subTest(entries=entries), self.assertRaises(ValueError):
                release.package_files(self.root, list(entries))

    def test_exact_classic_catalog_match_only(self):
        catalog = [{"id": 42, "gameVersionTypeID": 67408, "name": "1.15.9"},
                   {"id": 77, "gameVersionTypeID": 517, "name": "1.15.9"}]
        self.assertEqual(release.game_version_id(catalog, "1.15.9"), 42)
        for data in ({}, [], catalog[1:], catalog[:1] * 2):
            with self.assertRaises(ValueError):
                release.game_version_id(data, "1.15.9")
        with self.assertRaises(ValueError):
            release.game_version_id(catalog, "1.15.10")

    def test_upload_metadata_multipart_and_receipt(self):
        self.event["release"]["name"] = "A custom GitHub title must not become the CurseForge display name"
        manifest = self.prepare()
        catalog = [{"id": 42, "gameVersionTypeID": 67408, "name": "1.15.9"}]
        with patch.object(release, "request_json", side_effect=[catalog, {"id": 999}]) as request:
            receipt = release.upload(self.output, self.event, "release", "dummy-test-token", "1")
        self.assertEqual(request.call_count, 2)
        path, token, body, content_type = request.call_args.args
        self.assertEqual(path, "/projects/1666468/upload-file")
        self.assertEqual(token, "dummy-test-token")
        self.assertNotIn(token.encode(), body)
        message = BytesParser(policy=default).parsebytes(f"Content-Type: {content_type}\r\n\r\n".encode() + body)
        metadata_part, file_part = list(message.iter_parts())
        metadata = json.loads(metadata_part.get_payload(decode=True))
        self.assertEqual(metadata["changelog"], self.event["release"]["body"])
        self.assertEqual(metadata["changelogType"], "markdown")
        self.assertEqual(metadata["gameVersions"], [42])
        self.assertEqual(metadata["releaseType"], "release")
        self.assertEqual(metadata["displayName"], "HCOneButton v1.29.2")
        self.assertEqual(file_part.get_payload(decode=True), (self.output / manifest["zip"]).read_bytes())
        self.assertEqual(receipt["fileId"], 999)
        self.assertEqual(receipt["actor"], "DoctorB")
        self.assertEqual(receipt["triggeringActor"], "DoctorB")
        self.assertEqual(release.read_json(self.output / "curseforge-receipt.json"), receipt)
        with patch.object(release, "request_json") as request:
            with self.assertRaises(ValueError):
                release.upload(self.output, self.event, "release", "dummy", "1")
            request.assert_not_called()

    def test_missing_secret_reruns_and_modified_artifacts_stop_before_network(self):
        manifest = self.prepare()
        with patch.object(release, "request_json") as request:
            for token, attempt in ((None, "1"), ("", "1"), ("dummy", "2"), ("dummy", "")):
                with self.assertRaises(ValueError):
                    release.upload(self.output, self.event, "release", token, attempt)
            self.event["release"]["body"] = "changed after packaging"
            with self.assertRaises(ValueError):
                release.upload(self.output, self.event, "release", "dummy", "1")
            (self.output / manifest["zip"]).write_bytes(b"corrupt ZIP")
            with self.assertRaises(ValueError):
                release.upload(self.output, self.event, "release", "dummy", "1")
            request.assert_not_called()

    def test_real_upload_summary_requires_successful_response(self):
        summary = self.root / "upload-summary.md"
        catalog = [{"id": 42, "gameVersionTypeID": 67408, "name": "1.15.9"}]
        with patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": str(summary)}):
            self.prepare()
            self.assertIn("upload has not run yet", summary.read_text())
            self.assertNotIn("accepted file", summary.read_text())
            with patch.object(release, "request_json", side_effect=[catalog, {"id": 999}]):
                release.upload(self.output, self.event, "release", "dummy", "1")
            self.assertEqual(summary.read_text().count("CurseForge accepted file 999"), 1)

    def test_ambiguous_upload_is_not_retried(self):
        self.prepare()
        catalog = [{"id": 42, "gameVersionTypeID": 67408, "name": "1.15.9"}]
        with patch.object(release, "request_json", side_effect=[catalog, {}]) as request:
            with self.assertRaises(ValueError):
                release.upload(self.output, self.event, "release", "dummy", "1")
        self.assertEqual(request.call_count, 2)  # one GET, one POST
        self.assertFalse((self.output / "curseforge-receipt.json").exists())

    def test_network_errors_do_not_echo_secrets_or_follow_redirects(self):
        secret = "dummy-private-token"
        with patch.object(release.urllib.request, "build_opener") as factory:
            factory.return_value.open.side_effect = urllib.error.URLError(secret)
            with self.assertRaises(ValueError) as raised:
                release.request_json("/game/wow/versions", secret)
            self.assertNotIn(secret, str(raised.exception))
            self.assertEqual(factory.return_value.open.call_count, 1)
        self.assertIsNone(release.NoRedirect().redirect_request(None, None, 302, "", {}, "https://other.example"))

    def test_workflow_is_release_or_dry_run_only_and_secret_is_upload_scoped(self):
        workflow = (Path(__file__).resolve().parents[1] / ".github/workflows/curseforge-release.yml").read_text()
        self.assertIn("types: [published]", workflow)
        self.assertIn("workflow_dispatch:", workflow)
        self.assertNotIn("  push:", workflow)
        self.assertNotIn("  pull_request:", workflow)
        self.assertEqual(workflow.count("secrets.CF_API_TOKEN"), 1)
        upload_step = workflow.split("- name: Upload to CurseForge", 1)[1].split("- name:", 1)[0]
        self.assertIn("if: github.event_name == 'release'", upload_step)
        self.assertIn("secrets.CF_API_TOKEN", upload_step)
        self.assertIn("persist-credentials: false", workflow)
        job_guard = workflow.split("jobs:", 1)[1].split("runs-on:", 1)[0]
        for field in ("github.actor", "github.triggering_actor"):
            self.assertIn(f"({field} == 'DoctorB' || {field} == 'DoctorCalibano')", job_guard)
        self.assertIn("github.repository == 'DoctorB/hc-one-button' &&", job_guard)
        self.assertTrue(all(re.fullmatch(r"[0-9a-f]{40}", ref)
                            for ref in re.findall(r"uses: [^@\s]+@([^\s]+)", workflow)))


class RunnerIsolationTests(unittest.TestCase):
    def test_mock_upload_cannot_write_inherited_runner_summary(self):
        # Reproduce the original CI-only bug, outside ReleaseTests.setUp.
        with tempfile.TemporaryDirectory(prefix="hcob-runner-test-") as directory:
            summary = Path(directory) / "real-job-summary.md"
            summary.write_text("Real job\n", encoding="utf-8")
            with patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": str(summary)}):
                result = unittest.TestResult()
                ReleaseTests("test_upload_metadata_multipart_and_receipt").run(result)
                self.assertTrue(result.wasSuccessful(), result.errors or result.failures)
                self.assertEqual(os.environ["GITHUB_STEP_SUMMARY"], str(summary))
            self.assertEqual(summary.read_text(encoding="utf-8"), "Real job\n")


if __name__ == "__main__":
    unittest.main()
