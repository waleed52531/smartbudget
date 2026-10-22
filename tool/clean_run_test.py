import unittest
from clean_run import clean_environment, redact


class CleanRunTest(unittest.TestCase):
    def test_service_credentials_and_debug_are_not_inherited(self):
        self.assertEqual(clean_environment({"PATH": "/bin", "HOME": "/example",
            "GEMINI_API_KEY": "synthetic", "DEBUG": "release",
            "UNRELATED_SERVICE_TOKEN": "synthetic"}), {"PATH": "/bin", "HOME": "/example"})

    def test_known_value_and_bearer_are_redacted(self):
        self.assertEqual(redact("synthetic-secret Bearer synthetic.jwt.token", "synthetic-secret"),
                         "[REDACTED] Bearer [REDACTED]")

    def test_reset_links_and_json_credentials_are_redacted(self):
        self.assertEqual(redact('http://localhost/action?oobCode=synthetic&mode=reset', ''),
                         'http://localhost/action?oobCode=[REDACTED]&mode=reset')
        self.assertEqual(redact('{"idToken":"synthetic","password":"synthetic"}', ''),
                         '{"idToken":"[REDACTED]","password":"[REDACTED]"}')


if __name__ == "__main__":
    unittest.main()
