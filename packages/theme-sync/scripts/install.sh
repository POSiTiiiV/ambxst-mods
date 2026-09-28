#!/usr/bin/env bash
# Installs the companion pieces for the positive.theme-sync Ambxst mod that
# can't be installed through Ambxst's own mod system: a systemd user service
# that watches ~/.cache/ambxst/colors.json and syncs Kitty/btop/Starship/
# Fastfetch/Spicetify/Fuzzel/Sonora/Dolphin whenever the wallpaper's palette
# changes.
#
# Safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Checking prerequisites"
missing=()
for cmd in python3 plasma-apply-colorscheme busctl; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if [ "${#missing[@]}" -gt 0 ]; then
    echo "    Missing: ${missing[*]}"
    echo "    plasma-apply-colorscheme/busctl come from KDE Frameworks (plasma-workspace / kconfig)."
    echo "    Install them with your distro's package manager, then re-run this script."
    exit 1
fi
echo "    OK"

echo "==> Installing ambxst-sync coordinator to ~/.config/ambxst-sync"
mkdir -p "$HOME/.config/ambxst-sync"
cp -r "$SCRIPT_DIR/ambxst-sync/." "$HOME/.config/ambxst-sync/"
find "$HOME/.config/ambxst-sync" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

echo "==> Installing dolphin-apply-color.py to ~/.local/bin"
mkdir -p "$HOME/.local/bin"
cp "$SCRIPT_DIR/dolphin-apply-color.py" "$HOME/.local/bin/dolphin-apply-color.py"
chmod +x "$HOME/.local/bin/dolphin-apply-color.py"

echo "==> Linking ~/.local/bin/ambxst-theme-sync -> ~/.config/ambxst-sync/coordinator.py"
ln -sf "$HOME/.config/ambxst-sync/coordinator.py" "$HOME/.local/bin/ambxst-theme-sync"
chmod +x "$HOME/.config/ambxst-sync/coordinator.py"

echo "==> Seeding default settings at ~/.config/ambxst/mods/positive.theme-sync.json (only if missing)"
mkdir -p "$HOME/.config/ambxst/mods"
SETTINGS_FILE="$HOME/.config/ambxst/mods/positive.theme-sync.json"
if [ ! -f "$SETTINGS_FILE" ]; then
    cat > "$SETTINGS_FILE" <<'EOF'
{
  "syncKitty": true,
  "syncBtop": true,
  "syncStarship": true,
  "syncFastfetch": true,
  "syncSpicetify": true,
  "syncFuzzel": true,
  "syncSonora": true,
  "syncDolphin": true,
  "dolphinIconTheme": "breeze-dark",
  "dolphinOpacity": 89,
  "dolphinBlur": true
}
EOF
    echo "    Wrote defaults (edit these later from Ambxst Settings -> Mods -> Theme Sync)"
else
    echo "    Already exists, left untouched"
fi

echo "==> Configuring Kitty terminal (~/.config/kitty/kitty.conf)"
KITTY_CONF="$HOME/.config/kitty/kitty.conf"
mkdir -p "$HOME/.config/kitty"
touch "$KITTY_CONF"

if ! grep -q "include themes/ambxst.conf" "$KITTY_CONF"; then
    echo -e "\n# Ambxst Dynamic Theme\ninclude themes/ambxst.conf" >> "$KITTY_CONF"
    echo "    Added 'include themes/ambxst.conf'"
fi

if ! grep -q "background_opacity" "$KITTY_CONF"; then
    cat >> "$KITTY_CONF" <<'EOF'

# Ambxst Rice Styling
background_opacity          0.82
dynamic_background_opacity yes
window_padding_width        20
allow_remote_control        yes
listen_on                   unix:@kitty
EOF
    echo "    Added frosted opacity and remote-control flags"
fi

echo "==> Configuring Qt / KDE dark theme preferences"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Darkly 2>/dev/null || true
elif command -v kwriteconfig5 >/dev/null 2>&1; then
    kwriteconfig5 --file kdeglobals --group KDE --key widgetStyle Darkly 2>/dev/null || true
fi

echo "==> Checking Hyprland Dolphin & Kitty window rules"
HYPR_RULES="$HOME/.config/hypr/lua/custom/custom_rules.lua"
if [ -f "$HYPR_RULES" ]; then
    if ! grep -q "dolphin-glass" "$HYPR_RULES"; then
        echo "    Injecting frosted glass rules and Kawase blur into $HYPR_RULES"
        cat >> "$HYPR_RULES" <<'EOF'

-- Auto-injected by positive.theme-sync
local dolphin_rice_defaults = { dolphinOpacity = "0.89 0.83 1.0", dolphinXray = false }
local dolphin_rice_path = os.getenv("HOME") .. "/.config/hypr/lua/generated/theme-sync-rice.lua"
local dolphin_rice_ok, dolphin_rice = pcall(dofile, dolphin_rice_path)
if not dolphin_rice_ok or type(dolphin_rice) ~= "table" then
    dolphin_rice = dolphin_rice_defaults
end

hl.window_rule({
    name    = "dolphin-glass",
    match   = { class = "^(org\\.kde\\.dolphin)$" },
    opacity = dolphin_rice.dolphinOpacity,
    xray    = dolphin_rice.dolphinXray,
})

hl.window_rule({
    name    = "kitty-glass",
    match   = { class = "^(kitty)$" },
    xray    = false,
})
EOF
        hyprctl reload config-only 2>/dev/null || true
    else
        echo "    Dolphin glass rule already present in $HYPR_RULES"
    fi
else
    echo "    $HYPR_RULES not found (skip auto-inject; add dolphin-glass manually if on custom path)"
fi

echo "==> Installing systemd user units"
mkdir -p "$HOME/.config/systemd/user"
cp "$SCRIPT_DIR/systemd/ambxst-theme-sync.path" "$HOME/.config/systemd/user/"
cp "$SCRIPT_DIR/systemd/ambxst-theme-sync.service" "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now ambxst-theme-sync.path

echo "==> Running an initial sync"
"$HOME/.local/bin/ambxst-theme-sync" || true

echo ""
echo "==> All set! Kitty, Dolphin, and desktop apps are fully configured for live dynamic theming."
echo "    If Kitty is running, reload it with Ctrl+Shift+F5 (or restart Kitty) to activate new opacity/padding."

