import unittest
from .local_tools import calculate, local_reply
from .server import CompanionApplication


class LocalSkillsTests(unittest.TestCase):
    def test_arithmetic(self):
        self.assertEqual(calculate("12 * (3 + 4)"), "84")
        self.assertEqual(calculate("-3 + 2 ** 3"), "5")
        self.assertEqual(calculate("10 / 4"), "2.5")

    def test_rejects_execution_and_overflow(self):
        for expression in ["__import__('os').system('calc')", "x", "True", "2**99999", "1/0", "1e309", "(-1)**0.5", "2" * 201]:
            with self.subTest(expression=expression):
                with self.assertRaises(ValueError):
                    calculate(expression)

    def test_local_skills_never_call_a_model(self):
        def forbidden(*args):
            self.fail("Local skill attempted a provider request")
        app = CompanionApplication(token="test-token", provider_transport=forbidden)
        self.assertIn("I'm Waste", app.chat("/help", "offline", []))
        self.assertIn("local time:", app.chat("/time", "offline", []))
        self.assertEqual(app.chat("/calculate 6*7", "offline", []), "Result: 42")
        self.assertIn("not run", app.chat("/calculate 1/0", "offline", []))

    def test_open_ended_text_is_not_faked(self):
        self.assertIsNone(local_reply("Tell me a story"))


if __name__ == "__main__":
    unittest.main()
