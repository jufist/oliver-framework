import sys
import tempfile
import unittest
from pathlib import Path
import importlib.util

# Ensure local package is used even if a different version is installed globally.
PROJECT_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_DIR = PROJECT_ROOT / "python"
for path in (str(PACKAGE_DIR), str(PROJECT_ROOT)):
    if path not in sys.path:
        sys.path.insert(0, path)

# Load the logging module directly from the workspace to avoid picking up a global install.
LOGGING_PATH = PACKAGE_DIR / "utils" / "logging.py"
spec = importlib.util.spec_from_file_location("local_logging", LOGGING_PATH)
local_logging = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = local_logging
spec.loader.exec_module(local_logging)  # type: ignore[arg-type]

getlogger = local_logging.getlogger
set_log_file = local_logging.set_log_file
ol_logging = local_logging


class LoggerFormattingTest(unittest.TestCase):
    def test_gui_log_formats_tokens(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            log_path = Path(tmpdir) / "gui.log"
            previous_path = ol_logging.GUI_LOG_PATH
            try:
                set_log_file(log_path)
                logger = getlogger("command")

                logger.info(
                    "Performing mouse %s (front-end %s -> scaled x%.4f = (%.2f, %.2f))",
                    "move",
                    "client",
                    1.2345,
                    10.0,
                    20.0,
                )

                content = log_path.read_text(encoding="utf-8").strip().splitlines()[-1]
                self.assertIn("Performing mouse move (front-end client -> scaled x1.2345 = (10.00, 20.00))", content)
                self.assertNotIn("%s", content)
                self.assertNotIn("%.2f", content)
            finally:
                set_log_file(previous_path)


if __name__ == "__main__":
    unittest.main()
