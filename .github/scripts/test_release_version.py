import unittest

from release_version import metadata


class ReleaseVersionTests(unittest.TestCase):
    def test_first_tag_uses_current_build_number(self):
        self.assertEqual(metadata("v0.1.0", 1), {
            "version_name": "0.1.0", "ios_version": "0.1.0", "build_number": "1",
        })

    def test_new_runs_increment_the_shared_counter(self):
        self.assertEqual(metadata("0.2.0", 2)["build_number"], "2")
        self.assertEqual(metadata("v1.0.0", 3, 15)["build_number"], "17")

    def test_ios_uses_numeric_version_for_prereleases(self):
        result = metadata("v1.2.3-beta.2+ci", 4)
        self.assertEqual(result["version_name"], "1.2.3-beta.2+ci")
        self.assertEqual(result["ios_version"], "1.2.3")

    def test_invalid_tags_are_rejected(self):
        for tag in ("main", "v1.2", "v01.2.3", "v1.2.3-beta.01", "v1.2.3\nX=evil"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                metadata(tag, 1)

    def test_invalid_counters_are_rejected(self):
        for run, base in ((0, 1), (1, 0), (10000, 1)):
            with self.subTest(run=run, base=base), self.assertRaises(ValueError):
                metadata("v0.1.0", run, base)


if __name__ == "__main__":
    unittest.main()
