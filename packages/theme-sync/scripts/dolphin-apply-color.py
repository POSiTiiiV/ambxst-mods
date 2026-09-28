#!/usr/bin/env python3
"""
dolphin-apply-color.py — Zero-restart dynamic KDE/Dolphin color bridge.

Uses breeze-dark SVG icon theme + AccentColor to make folder icons recolor
live in-place via KIconLoader's palette-change hook.

Atomic writes + ping-pong flip + fcntl debounce lock.
Usage: dolphin-apply-color.py <#rrggbb> [--light]
"""
import sys
import os
import time
import subprocess
import argparse
import fcntl
import configparser


KDEGLOBALS = os.path.expanduser("~/.config/kdeglobals")
ICON_THEME = "breeze-dark"


def hex_to_rgb(hex_str):
    hex_str = hex_str.lstrip("#")
    return tuple(int(hex_str[i:i+2], 16) for i in (0, 2, 4))


def rgb_to_hex(r, g, b):
    return f"#{int(r):02x}{int(g):02x}{int(b):02x}"


def blend(c1, c2, factor):
    return rgb_to_hex(
        c1[0] * (1 - factor) + c2[0] * factor,
        c1[1] * (1 - factor) + c2[1] * factor,
        c1[2] * (1 - factor) + c2[2] * factor,
    )


def generate_kde_scheme(primary_hex, dark=True, bg=None, fg=None, surface=None):
    p_rgb = hex_to_rgb(primary_hex)
    r, g, b = p_rgb
    accent_rgb_str = f"{r},{g},{b}"

    if dark:
        if bg:
            bg_view = bg
            bg_window = surface if surface else blend(p_rgb, hex_to_rgb(bg), 0.7)
            bg_button = blend(p_rgb, hex_to_rgb(bg_window), 0.7)
        else:
            bg_window = blend(p_rgb, (24, 24, 27), 0.88)
            bg_view   = blend(p_rgb, (15, 15, 18), 0.94)
            bg_button = blend(p_rgb, (39, 39, 42), 0.85)

        fg_normal   = fg if fg else "#e4e4e7"
        fg_inactive = "#71717a"
        fg_link     = "#60a5fa"
        accent  = primary_hex
        sel_bg  = primary_hex
        luminance = r * 0.299 + g * 0.587 + b * 0.114
        sel_fg  = "#000000" if luminance > 150 else "#ffffff"
    else:
        if bg:
            bg_view = bg
            bg_window = surface if surface else blend(p_rgb, hex_to_rgb(bg), 0.7)
            bg_button = blend(p_rgb, hex_to_rgb(bg_window), 0.7)
        else:
            bg_window = blend(p_rgb, (244, 244, 245), 0.90)
            bg_view   = "#ffffff"
            bg_button = blend(p_rgb, (228, 228, 231), 0.85)

        fg_normal   = fg if fg else "#18181b"
        fg_inactive = "#a1a1aa"
        fg_link     = "#2563eb"
        accent  = primary_hex
        sel_bg  = primary_hex
        luminance = r * 0.299 + g * 0.587 + b * 0.114
        sel_fg  = "#ffffff" if luminance <= 150 else "#000000"

    # AccentColor in [General] is what tells Breeze SVGs which color to tint
    # folder icons. Without it, even with breeze-dark set, folders stay grey.
    return f"""[ColorEffects:Disabled]
Color={bg_window}
ColorAmount=0.5
ColorEffect=3

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color={bg_window}
ColorAmount=0.025
Enable=true

[Colors:Button]
BackgroundAlternate={bg_window}
BackgroundNormal={bg_button}
DecorationFocus={accent}
DecorationHover={accent}
ForegroundNormal={fg_normal}
ForegroundInactive={fg_inactive}
ForegroundLink={fg_link}

[Colors:Complementary]
BackgroundAlternate={bg_button}
BackgroundNormal={bg_window}
DecorationFocus={accent}
DecorationHover={accent}
ForegroundNormal={fg_normal}
ForegroundInactive={fg_inactive}
ForegroundLink={fg_link}

[Colors:Header]
BackgroundAlternate={bg_button}
BackgroundNormal={bg_window}
DecorationFocus={accent}
DecorationHover={accent}
ForegroundNormal={fg_normal}
ForegroundInactive={fg_inactive}

[Colors:Header][Inactive]
BackgroundAlternate={bg_button}
BackgroundNormal={bg_window}
DecorationFocus={accent}
DecorationHover={accent}
ForegroundNormal={fg_inactive}
ForegroundInactive={fg_inactive}

[Colors:Selection]
BackgroundNormal={sel_bg}
ForegroundNormal={sel_fg}
DecorationFocus={accent}

[Colors:Tooltip]
BackgroundAlternate={bg_button}
BackgroundNormal={bg_window}
DecorationFocus={accent}
DecorationHover={accent}
ForegroundNormal={fg_normal}
ForegroundInactive={fg_inactive}
ForegroundLink={fg_link}

[Colors:View]
BackgroundNormal={bg_view}
BackgroundAlternate={bg_window}
DecorationFocus={accent}
DecorationHover={accent}
ForegroundNormal={fg_normal}
ForegroundInactive={fg_inactive}
ForegroundLink={fg_link}

[Colors:Window]
BackgroundNormal={bg_window}
BackgroundAlternate={bg_button}
DecorationFocus={accent}
DecorationHover={accent}
ForegroundNormal={fg_normal}
ForegroundInactive={fg_inactive}
ForegroundLink={fg_link}

[General]
AccentColor={accent_rgb_str}
ColorScheme=DynamicRice
Name=Dynamic Rice Theme
shadeSortColumn=true

[Icons]
Theme={ICON_THEME}

[KDE]
contrast=4

[WM]
activeBackground={bg_window}
activeForeground={fg_normal}
inactiveBackground={bg_window}
inactiveForeground={fg_inactive}
"""



def atomic_write(filepath, content):
    """Write atomically to prevent Dolphin reading partially written files."""
    tmp_path = filepath + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        f.write(content)
    os.replace(tmp_path, filepath)


def update_kdeglobals_accent(hex_val):
    """
    Write AccentColor + Icons.Theme into ~/.config/kdeglobals so that
    KIconLoader's SVG palette-change hook recolors breeze-dark folder icons.
    Uses configparser with atomic replace to avoid corruption.
    """
    r, g, b = hex_to_rgb(hex_val)
    accent_rgb_str = f"{r},{g},{b}"

    cfg = configparser.RawConfigParser()
    cfg.optionxform = str  # preserve key case

    if os.path.exists(KDEGLOBALS):
        cfg.read(KDEGLOBALS)

    if "General" not in cfg:
        cfg.add_section("General")
    cfg["General"]["AccentColor"] = accent_rgb_str
    cfg["General"]["LastUsedCustomAccentColor"] = accent_rgb_str

    if "Icons" not in cfg:
        cfg.add_section("Icons")
    cfg["Icons"]["Theme"] = ICON_THEME

    tmp = KDEGLOBALS + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        cfg.write(f, space_around_delimiters=False)
    os.replace(tmp, KDEGLOBALS)


DOLPHINRC = os.path.expanduser("~/.config/dolphinrc")


def sanitize_dolphinrc():
    """Ensure dolphinrc doesn't contain a fixed ColorScheme override that breaks live theming."""
    if not os.path.exists(DOLPHINRC):
        return
    try:
        with open(DOLPHINRC, "r", encoding="utf-8") as f:
            lines = f.readlines()
        new_lines = [l for l in lines if not l.strip().startswith("ColorScheme=")]
        if len(new_lines) != len(lines):
            tmp = DOLPHINRC + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                f.writelines(new_lines)
            os.replace(tmp, DOLPHINRC)
    except Exception:
        pass


def refresh_dolphin_views():
    """Trigger view_redisplay on all running Dolphin instances to refresh cached item delegates and preview panel."""
    try:
        res = subprocess.run(
            ["busctl", "--user", "list"],
            capture_output=True,
            text=True,
            timeout=2,
        )
        for line in res.stdout.splitlines():
            parts = line.split()
            if parts and parts[0].startswith("org.kde.dolphin-"):
                service = parts[0]
                tree_res = subprocess.run(
                    ["busctl", "--user", "tree", service],
                    capture_output=True,
                    text=True,
                    timeout=2,
                )
                for tline in tree_res.stdout.splitlines():
                    if "actions/view_redisplay" in tline:
                        path = tline.strip().split()[-1]
                        subprocess.run(
                            ["busctl", "--user", "call", service, path, "org.qtproject.Qt.QAction", "trigger"],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                            timeout=1,
                        )
    except Exception:
        pass


def notify_kconfig_changed():
    """Emit org.kde.kconfig.notify ConfigChanged on /kdeglobals so KConfigWatcher reparses and refreshes toolbars."""
    try:
        import dbus
        bus = dbus.SessionBus()
        msg = dbus.lowlevel.SignalMessage('/kdeglobals', 'org.kde.kconfig.notify', 'ConfigChanged')
        data = dbus.Dictionary({
            dbus.String('Colors:Header'): dbus.Array([
                dbus.ByteArray(b'BackgroundNormal')
            ], signature='ay')
        }, signature='saay')
        msg.append(data, signature='a{saay}')
        bus.send_message(msg)
    except Exception:
        pass


def main():
    parser = argparse.ArgumentParser(description="Live KDE/Dolphin Color Scheme Applicator")
    parser.add_argument("color", help="Primary accent hex color (e.g. #3b82f6 or 3b82f6)")
    parser.add_argument("--light", action="store_true", help="Apply light mode")
    parser.add_argument("--bg", help="Optional background hex color")
    parser.add_argument("--fg", help="Optional foreground hex color")
    parser.add_argument("--surface", help="Optional surface hex color")
    parser.add_argument("--icon-theme", default="breeze-dark", help="Icon theme to set in kdeglobals (default: breeze-dark)")
    args = parser.parse_args()

    global ICON_THEME
    ICON_THEME = args.icon_theme

    hex_val = args.color if args.color.startswith("#") else f"#{args.color}"
    is_dark = not args.light

    # Ensure dolphinrc doesn't contain a fixed override
    sanitize_dolphinrc()

    # Debounce lock: if another instance is already running (rapid wallpaper scroll),
    # exit immediately rather than queuing concurrent palette events that crash Dolphin.
    lock_fd = open("/tmp/dolphin_theme_switch.lock", "w")
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)

    scheme_dir = os.path.expanduser("~/.local/share/color-schemes")
    os.makedirs(scheme_dir, exist_ok=True)

    content = generate_kde_scheme(
        hex_val,
        dark=is_dark,
        bg=args.bg,
        fg=args.fg,
        surface=args.surface,
    )
    scheme1 = os.path.join(scheme_dir, "DynamicRice.colors")
    scheme2 = os.path.join(scheme_dir, "DynamicRice2.colors")

    # Write both scheme files atomically
    atomic_write(scheme1, content)
    atomic_write(scheme2, content)

    # Write AccentColor + icon theme into kdeglobals BEFORE applying the scheme
    # so KIconLoader reads the new accent on its first palette-change event.
    update_kdeglobals_accent(hex_val)

    # Ping-Pong sequential application — MUST be sequential (not &) to avoid
    # concurrent QEvent::ApplicationPaletteChange events crashing Dolphin.
    #
    # Run the round-trip twice. There's no plasmashell daemon on this Hyprland
    # session to coordinate the theme-changed broadcast, so the manual
    # busctl signals below are Dolphin's only notification path — and a
    # single round-trip sometimes doesn't land (observed: switching to a
    # different wallpaper and back reliably "fixes" a wallpaper whose first
    # sync silently didn't visually apply; that's really just a second
    # round-trip happening for free). Doing it twice here removes the need
    # for that manual workaround.
    for _ in range(2):
        subprocess.run(
            ["plasma-apply-colorscheme", "DynamicRice2"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(0.08)  # Allow D-Bus queue and KSharedConfig to settle
        subprocess.run(
            ["plasma-apply-colorscheme", "DynamicRice"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(0.08)

    # Broadcast iconChanged(0) BEFORE notifyChange so KIconLoader flushes its
    # rasterized SVG pixmap cache before Qt triggers a repaint.
    subprocess.run(
        ["busctl", "--user", "emit", "/KIconLoader",
         "org.kde.KIconLoader", "iconChanged", "i", "0"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    # Broadcast KGlobalSettings notifyChange for Qt palette update
    subprocess.run(
        ["busctl", "--user", "emit", "/KGlobalSettings",
         "org.kde.KGlobalSettings", "notifyChange", "ii", "0", "0"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    # Notify KConfigWatcher so Darkly reloads Header / ToolBar colors live
    notify_kconfig_changed()

    # Force any open Dolphin instances to immediately refresh item views & preview panels
    refresh_dolphin_views()

    r, g, b = hex_to_rgb(hex_val)
    print(f"Applied dynamic palette {hex_val} (AccentColor={r},{g},{b}) icon-theme={ICON_THEME}")


if __name__ == "__main__":
    main()
