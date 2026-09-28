import os, subprocess
from .base import BaseTarget
from palette import Palette

class KittyTarget(BaseTarget):
    @property
    def name(self) -> str:
        return "Kitty"

    def generate(self, palette: Palette) -> None:
        target_path = os.path.expanduser("~/.config/kitty/themes/ambxst.conf")
        os.makedirs(os.path.dirname(target_path), exist_ok=True)

        content = f"""# Ambxst Palette for Kitty
foreground            {palette.foreground}
background            {palette.background}
selection_foreground  {palette.background}
selection_background  {palette.accent}
cursor                {palette.foreground}
cursor_text_color     {palette.background}
url_color             {palette.accent}
active_border_color   {palette.accent}
inactive_border_color {palette.surface}

# Black
color0 {palette.color0}
color8 {palette.color8}

# Red
color1 {palette.color1}
color9 {palette.color9}

# Green
color2 {palette.color2}
color10 {palette.color10}

# Yellow
color3 {palette.color3}
color11 {palette.color11}

# Blue
color4 {palette.color4}
color12 {palette.color12}

# Magenta
color5 {palette.color5}
color13 {palette.color13}

# Cyan
color6 {palette.color6}
color14 {palette.color14}

# White
color7 {palette.color7}
color15 {palette.color15}

# Dynamic Indexed Theme Registers (for live retroactive updates across terminal scrollback)
color255 {palette.accent}
color250 {palette.light_accent}
color252 {palette.foreground}
color239 {palette.pill_git}
color238 {palette.pill_dir}
color237 {palette.pill_os}
color236 {palette.surface}
"""
        with open(target_path, "w") as f:
            f.write(content)

    def apply(self) -> None:
        conf_path = os.path.expanduser("~/.config/kitty/themes/ambxst.conf")

        # 1. Target all active Kitty instances via their remote control abstract sockets
        try:
            import re
            sockets = set()
            if os.path.exists("/proc/net/unix"):
                with open("/proc/net/unix", "r") as f:
                    for line in f:
                        m = re.search(r"@(kitty\S+)", line)
                        if m:
                            sockets.add(m.group(1))

            for s in sockets:
                subprocess.run(
                    ["kitten", "@", "--to", f"unix:@{s}", "set-colors", "--all", "--configured", conf_path],
                    capture_output=True,
                    timeout=0.5
                )
        except Exception:
            pass

        # 2. Send SIGUSR1 so all running Kitty instances reload config as fallback
        subprocess.run(["pkill", "-SIGUSR1", "kitty"], capture_output=True)
