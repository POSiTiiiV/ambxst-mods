import json, os

SETTINGS_PATH = os.path.expanduser("~/.config/ambxst/mods/positive.theme-sync.json")

DEFAULTS = {
    "syncKitty": True,
    "syncBtop": True,
    "syncStarship": True,
    "syncFastfetch": True,
    "syncSpicetify": True,
    "syncFuzzel": True,
    "syncSonora": True,
    "syncDolphin": True,
    "dolphinIconTheme": "breeze-dark",
    "dolphinOpacity": 89,
    "dolphinBlur": True,
}


def load_settings() -> dict:
    """Read the positive.theme-sync mod's settings, falling back to defaults
    for anything missing (fresh install, or a friend's older settings file)."""
    settings = dict(DEFAULTS)
    if os.path.exists(SETTINGS_PATH):
        try:
            with open(SETTINGS_PATH, "r") as f:
                data = json.load(f)
            settings.update({k: v for k, v in data.items() if k in DEFAULTS})
        except Exception:
            pass
    return settings
