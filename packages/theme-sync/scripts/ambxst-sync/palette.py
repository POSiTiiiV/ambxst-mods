import json, os, re
from dataclasses import dataclass
from typing import Tuple

def hex_to_rgb(hex_str: str) -> Tuple[int, int, int]:
    h = hex_str.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

def rgb_to_hex(r: int, g: int, b: int) -> str:
    return f"#{max(0, min(255, r)):02x}{max(0, min(255, g)):02x}{max(0, min(255, b)):02x}"

def blend(hex1: str, hex2: str, weight: float) -> str:
    r1, g1, b1 = hex_to_rgb(hex1)
    r2, g2, b2 = hex_to_rgb(hex2)
    return rgb_to_hex(
        int(r1 * (1 - weight) + r2 * weight),
        int(g1 * (1 - weight) + g2 * weight),
        int(b1 * (1 - weight) + b2 * weight)
    )

def luminance(hex_str: str) -> float:
    try:
        r, g, b = hex_to_rgb(hex_str)
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
    except Exception:
        return 0.5

@dataclass
class Palette:
    background: str       # #090d0d
    foreground: str       # #dde4e4
    accent: str           # #80d4db
    surface: str          # #161d1d
    card: str             # #202727
    border: str           # #333838
    dim_fg: str           # #899393
    
    # ANSI colors
    color0: str
    color1: str
    color2: str
    color3: str
    color4: str
    color5: str
    color6: str
    color7: str
    color8: str
    color9: str
    color10: str
    color11: str
    color12: str
    color13: str
    color14: str
    color15: str

    @property
    def accent_rgb(self) -> Tuple[int, int, int]:
        return hex_to_rgb(self.accent)

    @property
    def bg_rgb(self) -> Tuple[int, int, int]:
        return hex_to_rgb(self.background)

    @property
    def fg_rgb(self) -> Tuple[int, int, int]:
        return hex_to_rgb(self.foreground)

    @property
    def light_accent(self) -> str:
        return blend(self.accent, "#ffffff", 0.2)

    @property
    def dim_accent(self) -> str:
        return blend(self.accent, self.background, 0.3)

    @property
    def pill_os(self) -> str:
        return blend(self.background, self.accent, 0.15)

    @property
    def pill_dir(self) -> str:
        return blend(self.background, self.accent, 0.25)

    @property
    def pill_git(self) -> str:
        return blend(self.background, self.accent, 0.35)


def load_palette() -> Palette:
    cache_json = os.path.expanduser("~/.cache/ambxst/colors.json")
    gtk3_css = os.path.expanduser("~/.config/gtk-3.0/gtk.css")
    
    # 1. Preferred: Ambxst's native colors.json
    if os.path.exists(cache_json):
        try:
            with open(cache_json, "r") as f:
                d = json.load(f)
            bg = d.get("background", "#090d0d")
            fg = d.get("overBackground", "#dde4e4")
            accent = d.get("primary", "#80d4db")
            surface = d.get("surfaceContainerLow", d.get("surface", "#161d1d"))
            card = d.get("surfaceContainer", d.get("surfaceVariant", "#202727"))
            border = d.get("surfaceBright", d.get("outline", "#333838"))
            dim_fg = d.get("outline", "#899393")

            # Red
            c1 = d.get("red", d.get("error", "#ffb595"))

            # Green: if too washed out (luminance > 0.8), blend with overGreen to keep it rich and visible
            raw_green = d.get("green", "#95d5a7")
            c2 = blend(raw_green, d.get("overGreen", "#253600"), 0.4) if luminance(raw_green) > 0.8 else raw_green

            # Yellow: if yellow is near white or clamped, use the wallpaper's tertiary accent
            raw_yellow = d.get("yellow", "")
            c3 = d.get("tertiary", "#d0cb52") if (not raw_yellow or luminance(raw_yellow) > 0.85) else raw_yellow

            # Blue: use wallpaper's blue or accent
            raw_blue = d.get("blue", accent)
            c4 = blend(raw_blue, d.get("overBlue", "#132f60"), 0.2) if luminance(raw_blue) > 0.85 else raw_blue

            # Magenta: use wallpaper's magenta
            raw_magenta = d.get("magenta", "#e4b7f3")
            c5 = blend(raw_magenta, d.get("overMagenta", "#4e1e44"), 0.2) if luminance(raw_magenta) > 0.85 else raw_magenta

            # Cyan: if cyan is near white, use cyanContainer blended with overCyan, or harmonized teal
            raw_cyan = d.get("cyan", "")
            if not raw_cyan or luminance(raw_cyan) > 0.85:
                raw_cyan_container = d.get("cyanContainer", "#4cfcdf")
                c6 = blend(raw_cyan_container, d.get("overCyan", "#00382f"), 0.35)
            else:
                c6 = raw_cyan

            # Color 7: Standard text MUST be fg for crisp, perfect contrast!
            c7 = fg

            # Color 8: Muted comment / subtle element
            c8 = blend(border, dim_fg, 0.7)

            # Bright variants (9-15)
            c9 = d.get("lightRed", blend(c1, "#ffffff", 0.25))
            raw_lgreen = d.get("lightGreen", "")
            c10 = blend(c2, "#ffffff", 0.35) if (not raw_lgreen or luminance(raw_lgreen) > 0.9) else raw_lgreen
            c11 = d.get("tertiaryFixed", blend(c3, "#ffffff", 0.25))
            c12 = d.get("lightBlue", blend(c4, "#ffffff", 0.25))
            c13 = d.get("lightMagenta", blend(c5, "#ffffff", 0.25))
            c14 = blend(c6, "#ffffff", 0.25)
            c15 = blend(fg, "#ffffff", 0.3)

            return Palette(
                background=bg,
                foreground=fg,
                accent=accent,
                surface=surface,
                card=card,
                border=border,
                dim_fg=dim_fg,
                color0=surface,
                color1=c1,
                color2=c2,
                color3=c3,
                color4=c4,
                color5=c5,
                color6=c6,
                color7=c7,
                color8=c8,
                color9=c9,
                color10=c10,
                color11=c11,
                color12=c12,
                color13=c13,
                color14=c14,
                color15=c15,
            )
        except Exception as e:
            print(f"[palette] Error reading {cache_json}: {e}")

    # 2. Fallback: GTK-3.0 css
    accent = "#ffb695"
    bg = "#120c0a"
    fg = "#f1dfd8"
    surface = "#28211f"
    if os.path.exists(gtk3_css):
        with open(gtk3_css, "r") as f:
            c = f.read()
        m_acc = re.search(r"@define-color\s+accent_color\s+#([0-9a-fA-F]{6})", c)
        if m_acc: accent = f"#{m_acc.group(1).lower()}"
        m_bg = re.search(r"@define-color\s+window_bg_color\s+rgba\((\d+),\s*(\d+),\s*(\d+)", c)
        if m_bg: bg = f"#{int(m_bg.group(1)):02x}{int(m_bg.group(2)):02x}{int(m_bg.group(3)):02x}"
        m_fg = re.search(r"@define-color\s+window_fg_color\s+#([0-9a-fA-F]{6})", c)
        if m_fg: fg = f"#{m_fg.group(1).lower()}"
        m_surf = re.search(r"@define-color\s+popover_bg_color\s+#([0-9a-fA-F]{6})", c)
        if m_surf: surface = f"#{m_surf.group(1).lower()}"

    return Palette(
        background=bg, foreground=fg, accent=accent, surface=surface,
        card=surface, border=surface, dim_fg="#a08d85",
        color0=surface, color1="#ffb4ab", color2="#d1c88f", color3=accent,
        color4=accent, color5=fg, color6="#d1c88f", color7=fg,
        color8=blend(surface, "#a08d85", 0.7), color9="#ff5449", color10="#e8dfa3", color11=accent,
        color12=accent, color13="#ffffff", color14="#e8dfa3", color15="#ffffff",
    )
