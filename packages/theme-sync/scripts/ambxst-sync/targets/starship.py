import os
from .base import BaseTarget
from palette import Palette

class StarshipTarget(BaseTarget):
    @property
    def name(self) -> str:
        return "Starship"

    def generate(self, palette: Palette) -> None:
        starship_path = os.path.expanduser("~/.config/starship.toml")

        os_bg = palette.pill_os
        dir_bg = palette.pill_dir
        git_bg = palette.pill_git
        surf_bg = palette.surface
        accent = palette.accent
        light_accent = palette.light_accent
        fg = palette.foreground
        warn = palette.color3
        err = palette.color1

        content = f"""# Ambxst Theme for Starship - dynamically synced from wallpaper
"$schema" = 'https://starship.rs/config-schema.json'

format = \"\"\"
$os\\
$directory\\
$git_branch\\
$git_status\\
$package\\
$python\\
$nodejs\\
$rust\\
$cmd_duration\\
$line_break\\
$character\"\"\"

add_newline = true

[os]
disabled = false
style = "bg:237 fg:255"
format = "[](237)[$symbol ]($style)[ ](fg:237)"

[os.symbols]
Arch = "󰣇"
CachyOS = "󰣇"
Linux = "󰌽"

[directory]
style = "bg:238 fg:252"
format = "[](238)[$path]($style)[$read_only]($read_only_style)[ ](fg:238)"
read_only = " 󰌾"
truncation_length = 3
truncate_to_repo = true
home_symbol = " ~"

[directory.substitutions]
"Documents" = "󰈙 Documents"
"Downloads" = " Downloads"
"Music" = " Music"
"Pictures" = " Pictures"
"Videos" = " Videos"

[git_branch]
style = "bg:239 fg:255"
format = "[](239)[$symbol$branch]($style)"
symbol = " "

[git_status]
style = "bg:239 fg:250"
format = '([ $all_status$ahead_behind]($style))[ ](fg:239)'

[cmd_duration]
style = "bg:236 fg:3"
min_time = 2_000
format = "[](236)[took $duration]($style)[ ](fg:236)"

[character]
success_symbol = "[❯](bold 255)"
error_symbol = "[❯](bold 1)"
vimcmd_symbol = "[❮](bold 3)"

[python]
style = "bg:236 fg:250"
format = "[](236)[${{symbol}}${{version}}]($style)[ ](fg:236)"
symbol = "󰌠 "

[nodejs]
style = "bg:236 fg:255"
format = "[](236)[${{symbol}}${{version}}]($style)[ ](fg:236)"
symbol = "󰎙 "

[rust]
style = "bg:236 fg:255"
format = "[](236)[${{symbol}}${{version}}]($style)[ ](fg:236)"
symbol = "󱘗 "

[package]
style = "bg:236 fg:3"
format = "[](236)[$symbol$version]($style)[ ](fg:236)"
symbol = "󰏗 "
"""
        with open(starship_path, "w") as f:
            f.write(content)

    def apply(self) -> None:
        # Starship evaluates config on next command prompt
        pass
