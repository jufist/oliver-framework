import sys
import tempfile
import unittest
from pathlib import Path
import importlib.util
from unittest.mock import Mock

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
set_gui_log_disabled = local_logging.set_gui_log_disabled
ol_logging = local_logging


class LoggerFormattingTest(unittest.TestCase):
    def test_gui_log_formats_tokens(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            log_path = Path(tmpdir) / "gui.log"
            previous_path = ol_logging.GUI_LOG_PATH
            previous_disabled = ol_logging.GUI_LOG_DISABLED
            try:
                set_log_file(log_path)
                set_gui_log_disabled(False)
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
                set_gui_log_disabled(previous_disabled)
                set_log_file(previous_path)

    def test_gui_log_disabled_flag_skips_file_write(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            log_path = Path(tmpdir) / "gui.log"
            previous_path = ol_logging.GUI_LOG_PATH
            previous_disabled = ol_logging.GUI_LOG_DISABLED
            try:
                set_log_file(log_path)
                set_gui_log_disabled(True)
                logger = getlogger("command")
                logger.info("Should not be written")
                self.assertFalse(log_path.exists())
            finally:
                set_gui_log_disabled(previous_disabled)
                set_log_file(previous_path)

    def test_gui_log_write_error_disables_future_writes(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            unwritable_path = Path(tmpdir)
            previous_path = ol_logging.GUI_LOG_PATH
            previous_disabled = ol_logging.GUI_LOG_DISABLED
            try:
                set_log_file(unwritable_path)
                set_gui_log_disabled(False)
                logger = getlogger("command")

                original_warning = logger._logger.warning
                warning_spy = Mock(wraps=logger._logger.warning)
                logger._logger.warning = warning_spy

                logger.info("First write fails")
                logger.info("Second write skipped")

                self.assertTrue(ol_logging.GUI_LOG_DISABLED)
                self.assertEqual(warning_spy.call_count, 1)
            finally:
                if "logger" in locals() and "original_warning" in locals():
                    logger._logger.warning = original_warning
                set_gui_log_disabled(previous_disabled)
                set_log_file(previous_path)


if __name__ == "__main__":
    unittest.main()
