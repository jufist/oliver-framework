"""Colorized logging utilities for Oliver Framework."""

from __future__ import annotations

import datetime as _dt
import logging
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import ClassVar, Dict, Iterable, Union

import colorlog
from dotenv import load_dotenv


BASE_DIR = Path.cwd()
ENV_PATH = BASE_DIR / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)

LOG_LEVEL = os.getenv("LOGGINGLEVEL", "INFO").upper()
NAMESPACE = os.getenv("NAMESPACE", "").strip()

logging.basicConfig(
    level=LOG_LEVEL,
    format="%(asctime)s - [%(levelname)s] - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

LOGGER = colorlog.getLogger("oliver")
LOGGER.setLevel(LOG_LEVEL)
LOGGER.propagate = False


def _default_log_path() -> Path:
    """Return the default path used for GUI log forwarding."""

    return BASE_DIR / "logs" / "gui.log"


GUI_LOG_PATH: Path = (
    Path(env_path)
    if (env_path := os.getenv("GUI_LOG_PATH"))
    else _default_log_path()
)


def set_log_file(log_file: Union[os.PathLike[str], str]) -> None:
    """Override the log forwarding path used by :class:`Logger`."""

    global GUI_LOG_PATH
    GUI_LOG_PATH = Path(log_file)


def _ensure_parent(path: Path) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
    except OSError:
        # Creating the directory is best-effort. The logger will surface IO errors later.
        pass


def _format_args(args: Iterable[object]) -> str:
    return "" if not args else " " + " ".join(str(arg) for arg in args)


@dataclass
class Logger:
    """Small adapter around :mod:`logging` that adds colour and prefixes."""

    department: str
    namespace: str = field(default=NAMESPACE, repr=False)
    _logger: logging.Logger = field(default=LOGGER, init=False, repr=False)
    extra: Dict[str, str] = field(init=False)
    prefix: str = field(init=False)

    department_colors: ClassVar[Dict[str, Dict[str, str]]] = {}

    def __post_init__(self) -> None:
        self.extra = {"department": self.department}
        namespace = self.namespace
        self.prefix = f"[{namespace}-{self.department}] " if namespace else f"[{self.department}] "
        if self.department not in self.department_colors:
            self.department_colors[self.department] = {
                "DEBUG": "purple",
                "INFO": "green",
                "WARNING": "yellow",
                "ERROR": "red",
                "CRITICAL": "red",
            }
        self._configure_handler()

    # Public API ---------------------------------------------------------
    def add_handler(self, handler: logging.Handler) -> None:
        self._logger.addHandler(handler)

    def debug(self, msg: str, *args: object) -> None:
        message = self._compose_message(msg, args)
        self._logger.debug(message, extra=self.extra)

    def info(self, msg: str, *args: object) -> None:
        message = self._compose_message(msg, args)
        self._write_gui_log(message)
        self._logger.info(message, extra=self.extra)

    def warning(self, msg: str, *args: object) -> None:
        message = self._compose_message(msg, args)
        self._write_gui_log(message)
        self._logger.warning(message, extra=self.extra)

    def error(self, msg: str, *args: object) -> None:
        message = self._compose_message(msg, args)
        self._write_gui_log(message)
        self._logger.error(message, extra=self.extra)

    def critical(self, msg: str, *args: object) -> None:
        message = self._compose_message(msg, args)
        self._logger.critical(message, extra=self.extra)

    # Internal helpers ---------------------------------------------------
    def _compose_message(self, msg: str, args: Iterable[object]) -> str:
        self._configure_handler()
        return f"{self.prefix}{msg}{_format_args(args)}"

    def _configure_handler(self) -> None:
        formatter = colorlog.ColoredFormatter(
            "%(log_color)s%(asctime)s - [%(levelname)s] - %(message)s%(reset)s",
            datefmt="%Y-%m-%d %H:%M:%S",
            log_colors=self.department_colors[self.department],
            reset=True,
            style="%",
        )

        default_handler = None
        handlers_to_remove = []
        for handler in self._logger.handlers:
            if getattr(handler, "_oliver_default", False):
                if default_handler is None:
                    default_handler = handler
                else:
                    handlers_to_remove.append(handler)

        for handler in handlers_to_remove:
            self._logger.removeHandler(handler)

        if default_handler is None:
            default_handler = logging.StreamHandler()
            setattr(default_handler, "_oliver_default", True)
            self._logger.addHandler(default_handler)

        default_handler.setFormatter(formatter)

    def _write_gui_log(self, msg: str) -> None:
        _ensure_parent(GUI_LOG_PATH)
        try:
            with GUI_LOG_PATH.open("a", encoding="utf-8") as file:
                current_time = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                file.write(f"{current_time} {msg}\n")
        except OSError as error:
            # Avoid infinite recursion by calling the module level logger directly.
            self._logger.warning(
                "[%s] Error writing to %s: %s",
                self.department,
                GUI_LOG_PATH,
                error,
                extra=self.extra,
            )


def getlogger(department: str) -> Logger:
    """Return a colour-aware :class:`Logger` for ``department``."""

    return Logger(department)


__all__ = ["Logger", "getlogger", "set_log_file"]
