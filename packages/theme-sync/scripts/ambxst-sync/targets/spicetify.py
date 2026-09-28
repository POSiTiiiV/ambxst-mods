import os, re, subprocess
from .base import BaseTarget
from palette import Palette

class SpicetifyTarget(BaseTarget):
    @property
    def name(self) -> str:
        return "Spicetify"

    def generate(self, palette: Palette) -> None:
        color_ini = os.path.expanduser("~/.config/spicetify/Themes/text/color.ini")
        if not os.path.exists(color_ini):
            return

        with open(color_ini, "r") as f:
            content = f.read()

        acc = palette.accent.lstrip("#")
        bg = palette.background.lstrip("#")
        fg = palette.foreground.lstrip("#")
        surf = palette.surface.lstrip("#")

        ambxst_block = f"""[Ambxst]
accent             = {acc}
accent-active      = {acc}
accent-inactive    = {bg}
banner             = {acc}
border-active      = {acc}
border-inactive    = {surf}
header             = {surf}
highlight          = {surf}
main               = {bg}
notification       = {acc}
notification-error = ff5449
subtext            = c5b3ac
text               = {fg}"""

        if "[Ambxst]" in content:
            content = re.sub(r"\[Ambxst\][^\[]*", ambxst_block + "\n\n", content)
        else:
            content = content.rstrip() + "\n\n" + ambxst_block + "\n"

        with open(color_ini, "w") as f:
            f.write(content)

    def apply(self) -> None:
        # Fast non-blocking refresh of theme assets without restarting Spotify
        subprocess.run(["spicetify", "config", "current_theme", "text", "color_scheme", "Ambxst"], capture_output=True)
        res = subprocess.run(["spicetify", "-n", "refresh"], capture_output=True, text=True)
        if res.returncode != 0:
            # Fallback to apply with -n (no-restart)
            subprocess.run(["spicetify", "-n", "apply"], capture_output=True, text=True)
