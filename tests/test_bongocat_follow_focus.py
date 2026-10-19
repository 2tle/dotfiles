"""Run with python3 -m unittest discover -s tests."""
import ast
from pathlib import Path
import struct
import tempfile
import textwrap
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "modules/nixos/bongocat-follow-focus.nix"
script = textwrap.dedent(SOURCE.read_text().split("''\n", 1)[1].rsplit("''", 1)[0])
tree = ast.parse(script)
# Load helpers without starting the service or requiring a Wayland session.
tree.body = [node for node in tree.body if isinstance(
    node, (ast.Import, ast.ImportFrom, ast.FunctionDef, ast.Assign)
)]
module = {}
exec(compile(tree, str(SOURCE), "exec"), module)


class KeyboardDetectionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def device(self, event, *keys):
        bits = sum(1 << key for key in set(keys))
        width = struct.calcsize("L") * 8
        words = []
        while bits:
            words.append(format(bits & ((1 << width) - 1), "x"))
            bits >>= width
        path = self.root / event / "device/capabilities/key"
        path.parent.mkdir(parents=True)
        path.write_text(" ".join(reversed(words)) or "0")

    def detect(self):
        return module["keyboard_devices"](self.root, "/dev/input")

    def test_arbitrary_keyboards_and_keypad_without_names(self):
        self.device("event0", 30)  # A: built-in, USB, Bluetooth, or virtual
        self.device("event7", 28)  # Enter-only device
        self.device("event8", 79)  # Numeric keypad
        self.assertEqual(self.detect(), ["/dev/input/event0", "/dev/input/event7", "/dev/input/event8"])

    def test_mouse_and_gamepad_buttons_are_not_keyboard_keys(self):
        self.device("event1", 272, 273)
        self.device("event2", 304)
        self.device("event3", 0)  # KEY_RESERVED
        self.assertEqual(self.detect(), [])

    def test_mixed_high_buttons_and_keyboard_keys(self):
        self.device("event4", 30, 272, 767)
        self.assertEqual(self.detect(), ["/dev/input/event4"])

    def test_hotplug_and_unplug(self):
        self.assertEqual(self.detect(), [])
        self.device("event5", 30)
        self.assertEqual(self.detect(), ["/dev/input/event5"])
        (self.root / "event5/device/capabilities/key").unlink()
        self.assertEqual(self.detect(), [])

    def test_missing_and_invalid_capabilities(self):
        self.device("event6", 30)
        (self.root / "event6/device/capabilities/key").write_text("invalid")
        (self.root / "event9").mkdir()
        self.assertEqual(self.detect(), [])

    def test_render_uses_paths_without_name_filter(self):
        module["pick_target"] = lambda: ("eDP-1", 0)
        original = module["keyboard_devices"]
        try:
            module["keyboard_devices"] = lambda: ["/dev/input/event7", "/dev/input/event42"]
            _, config = module["render_config"]()
            self.assertIn("keyboard_device=/dev/input/event7\n", config)
            self.assertIn("keyboard_device=/dev/input/event42\n", config)
            self.assertNotIn("keyboard_name=", config)
            module["keyboard_devices"] = lambda: []
            _, config = module["render_config"]()
            self.assertIn("keyboard_device=/dev/input/bongocat-no-keyboards", config)
        finally:
            module["keyboard_devices"] = original


if __name__ == "__main__":
    unittest.main()
