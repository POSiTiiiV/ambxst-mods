import json
import os
from .base import BaseTarget
from palette import Palette, blend


class SonoraTarget(BaseTarget):
    @property
    def name(self) -> str:
        return "Sonora"

    def generate(self, palette: Palette) -> None:
        settings_path = os.path.expanduser("~/.config/sonora/settings.json")
        if not os.path.exists(settings_path):
            return

        try:
            with open(settings_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            return

        appearance = data.setdefault("appearance", {})
        appearance["theme"] = "dark"
        # Turn off song artwork adaptive theming so Sonora follows the wallpaper palette
        appearance["adaptive_theme"] = False

        overrides = appearance.setdefault("theme_overrides", {})
        overrides["background"] = palette.background
        overrides["foreground"] = palette.foreground
        overrides["border"] = palette.border
        overrides["muted"] = palette.surface
        overrides["overlay"] = blend(palette.background, "#000000", 0.5)
        overrides["overlay_foreground"] = palette.foreground
        overrides["muted_foreground"] = palette.dim_fg
        overrides["secondary"] = palette.card
        overrides["secondary_hover"] = blend(palette.card, palette.foreground, 0.08)
        overrides["secondary_active"] = blend(palette.card, palette.accent, 0.15)
        overrides["primary"] = palette.accent
        overrides["primary_foreground"] = palette.background
        overrides["primary_hover"] = palette.light_accent
        overrides["danger"] = palette.color1
        overrides["danger_foreground"] = "#ffffff"
        overrides["danger_hover"] = palette.color9
        overrides["popover"] = palette.surface
        overrides["popover_foreground"] = palette.foreground
        overrides["progress_bar"] = palette.accent
        overrides["selection"] = blend(palette.surface, palette.accent, 0.4)
        overrides["sidebar"] = blend(palette.background, "#000000", 0.25)
        overrides["sidebar_accent"] = blend(palette.surface, palette.accent, 0.15)
        overrides["sidebar_border"] = palette.border
        overrides["title_bar_border"] = palette.border
        overrides["table_head"] = palette.surface
        overrides["table_head_foreground"] = palette.dim_fg
        overrides["table_row_border"] = blend(palette.border, palette.background, 0.5)
        overrides["table_hover"] = blend(palette.surface, palette.accent, 0.08)
        overrides["table_active"] = blend(palette.surface, palette.accent, 0.15)
        overrides["table_active_border"] = palette.accent

        with open(settings_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)

    def apply(self) -> None:
        # Sonora uses inotify via the Rust notify crate to monitor ~/.config/sonora/
        # and reloads settings.json with a smooth fade in-place upon disk write.
        pass
