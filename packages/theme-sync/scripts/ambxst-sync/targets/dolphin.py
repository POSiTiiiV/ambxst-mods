import os
import sys
import subprocess
from .base import BaseTarget
from palette import Palette
from settings import load_settings

APPLY_SCRIPT = os.path.expanduser("~/.local/bin/dolphin-apply-color.py")


class DolphinTarget(BaseTarget):
    def __init__(self):
        self._accent = None
        self._bg = None
        self._fg = None
        self._surface = None

    @property
    def name(self) -> str:
        return "Dolphin"

    def generate(self, palette: Palette) -> None:
        self._accent = palette.accent
        self._bg = palette.background
        self._fg = palette.foreground
        self._surface = palette.surface

    def apply(self) -> None:
        if not self._accent:
            return
        if not os.path.exists(APPLY_SCRIPT):
            raise FileNotFoundError(f"Dolphin apply script not found at {APPLY_SCRIPT}")

        icon_theme = load_settings().get("dolphinIconTheme", "breeze-dark")

        cmd = [sys.executable, APPLY_SCRIPT, self._accent, "--icon-theme", icon_theme]
        if self._bg:
            cmd.extend(["--bg", self._bg])
        if self._fg:
            cmd.extend(["--fg", self._fg])
        if self._surface:
            cmd.extend(["--surface", self._surface])

        res = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=15,
        )
        if res.returncode != 0:
            raise RuntimeError(f"Failed to apply Dolphin color scheme: {res.stderr.strip()}")
