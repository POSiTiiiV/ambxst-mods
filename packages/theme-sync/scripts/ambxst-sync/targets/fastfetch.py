import os, re
from .base import BaseTarget
from palette import Palette

class FastfetchTarget(BaseTarget):
    @property
    def name(self) -> str:
        return "Fastfetch"

    def generate(self, palette: Palette) -> None:
        cfg_path = os.path.expanduser("~/.config/fastfetch/config.jsonc")
        if not os.path.exists(cfg_path):
            return

        with open(cfg_path, "r") as f:
            c = f.read()

        # Indexed registers for live retroactive updates in Kitty terminal buffer
        c = re.sub(r'"keys":\s*"[^"]*"', '"keys": "38;5;255"', c)
        c = re.sub(r'"title":\s*"[^"]*"', '"title": "38;5;255"', c)
        c = re.sub(r'"1":\s*"[^"]*"', '"1": "38;5;255"', c)
        c = re.sub(r'"2":\s*"[^"]*"', '"2": "38;5;250"', c)
        with open(cfg_path, "w") as f:
            f.write(c)

    def apply(self) -> None:
        # Fastfetch is a CLI tool, takes effect immediately on next run
        pass
