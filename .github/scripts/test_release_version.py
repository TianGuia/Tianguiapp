import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from release_version import allocate, current_build, git, higher_pubspec, metadata, pubspec_metadata, register_pubspec, reserve, update_pubspec


class ReleaseVersionTests(unittest.TestCase):
    def test_metadata_uses_assigned_build_number(self):
        self.assertEqual(metadata("v0.1.0", 1), {
            "version_name": "0.1.0", "ios_version": "0.1.0", "build_number": "1",
        })

    def test_new_tags_increment_the_persisted_counter(self):
        values, pubspec, releases = allocate("v0.0.1-beta.3", "version: 0.0.1-beta.2+2\n", {})
        self.assertEqual(values["build_number"], "3")
        self.assertEqual(pubspec, "version: 0.0.1-beta.3+3\n")
        self.assertEqual(releases, {"v0.0.1-beta.3": 3})
        self.assertEqual(allocate("v0.0.1-beta.4", pubspec, releases)[0]["build_number"], "4")

    def test_retries_reuse_number_without_rolling_back_pubspec(self):
        pubspec = "version: 0.2.0+4\n"
        state = {"v0.1.0": 3, "v0.2.0": 4}
        values, updated, releases = allocate("v0.1.0", pubspec, state)
        self.assertEqual(values["build_number"], "3")
        self.assertEqual(updated, pubspec)
        self.assertEqual(releases, state)

    def test_counter_never_reuses_a_number_if_pubspec_was_lowered(self):
        self.assertEqual(allocate("v1.0.0", "version: 0.1.0+2\n", {"v0.2.0": 6})[0]["build_number"], "7")

    def test_pubspec_update_preserves_other_fields_and_comments(self):
        original = 'name: app\nversion: 0.1.0+1 # release\nassets:\n  - logo.png\n'
        result = update_pubspec(original, metadata("v0.2.0-beta.1", 2))
        self.assertEqual(result, original.replace("0.1.0+1", "0.2.0-beta.1+2"))

    def test_ios_uses_numeric_version_for_prereleases(self):
        result = metadata("v1.2.3-beta.2", 4)
        self.assertEqual(result["version_name"], "1.2.3-beta.2")
        self.assertEqual(result["ios_version"], "1.2.3")

    def test_invalid_tags_are_rejected(self):
        for tag in ("main", "v1.2", "v01.2.3", "v1.2.3-beta.01", "v1.2.3+ci", "v1.2.3\nX=evil"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                metadata(tag, 1)

    def test_invalid_counters_are_rejected(self):
        for number in (0, -1, 10000):
            with self.subTest(number=number), self.assertRaises(ValueError):
                metadata("v0.1.0", number)
        with self.assertRaises(ValueError):
            allocate("v1.0.0", "version: 0.1.0+9999\n", {})

    def test_invalid_pubspec_is_rejected(self):
        for pubspec in ("name: app\n", "version: 0.1.0\n", "version: 0.1.0+1\nversion: 0.2.0+2\n"):
            with self.subTest(pubspec=pubspec), self.assertRaises(ValueError):
                current_build(pubspec)

    def test_pubspec_triggers_only_for_increased_codes(self):
        previous = "version: 0.0.1-beta.2+2\n"
        for current in (previous, "version: 1.0.0+2\n", "version: 1.0.0+1\n", previous + "description: updated\n"):
            with self.subTest(current=current):
                self.assertIsNone(higher_pubspec(previous, current))
        self.assertEqual(higher_pubspec(previous, "version: 0.0.1-beta.2+3\n")["build_number"], "3")
        self.assertEqual(higher_pubspec(previous, "version: 0.0.2+10\n")["build_number"], "10")

    def test_initial_push_and_numeric_release_tag(self):
        values = higher_pubspec(None, "version: 0.0.1-beta.2+2\n")
        self.assertEqual(values, metadata("v0.0.1-beta.2+2", 2))
        with self.assertRaises(ValueError):
            metadata("v0.0.1-beta.2+3", 2)

    def test_explicit_release_retries_in_the_tag_flow(self):
        values, pubspec, state = allocate("v0.0.1-beta.2+2", "version: 0.0.1-beta.3+3\n", {"v0.0.1-beta.2+2": 2})
        self.assertEqual(values["build_number"], "2")
        self.assertEqual(pubspec, "version: 0.0.1-beta.3+3\n")


class ReservationIntegrationTests(unittest.TestCase):
    def test_persistence_retries_and_competing_push(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            remote, worker, competitor = (root / name for name in ("remote.git", "worker", "competitor"))
            subprocess.run(["git", "init", "--bare", str(remote)], check=True, capture_output=True)
            subprocess.run(["git", "clone", str(remote), str(worker)], check=True, capture_output=True)
            git(worker, "checkout", "-b", "main")
            git(worker, "config", "user.name", "Test")
            git(worker, "config", "user.email", "test@example.com")
            (worker / "pubspec.yaml").write_text("name: app\nversion: 0.0.1-beta.2+2\n", encoding="utf-8")
            (worker / "other.txt").write_text("keep me", encoding="utf-8")
            git(worker, "add", ".")
            git(worker, "commit", "-m", "Initial")
            git(worker, "push", "origin", "HEAD:main")
            subprocess.run(["git", "clone", "--branch", "main", str(remote), str(competitor)], check=True, capture_output=True)
            self.assertEqual(reserve(worker, "main", "v0.0.1-beta.3")["build_number"], "3")
            commit = git(worker, "rev-parse", "HEAD").stdout
            self.assertEqual(reserve(worker, "main", "v0.0.1-beta.3")["build_number"], "3")
            self.assertEqual(git(worker, "rev-parse", "HEAD").stdout, commit)
            raced = False

            def race(repo, *args, **kwargs):
                nonlocal raced
                if args[0] == "push" and not raced:
                    raced = True
                    self.assertEqual(reserve(competitor, "main", "v0.0.1-beta.4")["build_number"], "4")
                return git(repo, *args, **kwargs)

            with patch("release_version.git", side_effect=race):
                self.assertEqual(reserve(worker, "main", "v0.0.1-beta.5")["build_number"], "5")
            self.assertTrue(raced)
            state = json.loads((worker / ".github/release-versions.json").read_text(encoding="utf-8"))
            self.assertEqual(state, {"v0.0.1-beta.3": 3, "v0.0.1-beta.4": 4, "v0.0.1-beta.5": 5})
            self.assertEqual((worker / "pubspec.yaml").read_text(encoding="utf-8"), "name: app\nversion: 0.0.1-beta.5+5\n")
            self.assertEqual((worker / "other.txt").read_text(encoding="utf-8"), "keep me")

            # A pubspec push uses exactly the user's number, and creates a tag
            # pointing at the application commit, not the ledger-only commit.
            spec_path = worker / "pubspec.yaml"
            spec_path.write_text("name: app\nversion: 0.0.1-beta.5+6\n", encoding="utf-8")
            git(worker, "add", "pubspec.yaml")
            git(worker, "commit", "-m", "Bump build code")
            git(worker, "push", "origin", "HEAD:main")
            source_sha = git(worker, "rev-parse", "HEAD").stdout.strip()
            values = pubspec_metadata(spec_path.read_text(encoding="utf-8"))
            release = register_pubspec(worker, "main", values, source_sha)
            self.assertEqual(release["release_tag"], "v0.0.1-beta.5+6")
            self.assertEqual(git(worker, "ls-remote", "origin", "refs/tags/v0.0.1-beta.5+6").stdout.split()[0], source_sha)
            commit = git(worker, "rev-parse", "HEAD").stdout
            self.assertEqual(register_pubspec(worker, "main", values, source_sha), release)
            self.assertEqual(git(worker, "rev-parse", "HEAD").stdout, commit)
            self.assertIsNone(register_pubspec(worker, "main", metadata("0.1.0", 5), source_sha))
            with self.assertRaises(ValueError):
                register_pubspec(worker, "main", values, commit.strip())
            self.assertEqual(reserve(competitor, "main", "v0.0.1-beta.6")["build_number"], "7")

            # A competing tag can claim a later code while a pubspec build is
            # being registered. Atomic push rejects the stale reservation/tag.
            git(worker, "fetch", "origin", "main")
            git(worker, "checkout", "--detach", "--force", "FETCH_HEAD")
            spec_path.write_text("name: app\nversion: 0.0.1-beta.7+8\n", encoding="utf-8")
            git(worker, "add", "pubspec.yaml")
            git(worker, "commit", "-m", "Bump again")
            git(worker, "push", "origin", "HEAD:main")
            source_sha = git(worker, "rev-parse", "HEAD").stdout.strip()
            raced = False

            def registration_race(repo, *args, **kwargs):
                nonlocal raced
                if args[0] == "push" and not raced:
                    raced = True
                    self.assertEqual(reserve(competitor, "main", "v0.0.1-beta.8")["build_number"], "9")
                return git(repo, *args, **kwargs)

            with patch("release_version.git", side_effect=registration_race):
                self.assertIsNone(register_pubspec(worker, "main", metadata("0.0.1-beta.7", 8), source_sha))
            self.assertEqual(git(worker, "ls-remote", "origin", "refs/tags/v0.0.1-beta.7+8").stdout, "")


if __name__ == "__main__":
    unittest.main()
