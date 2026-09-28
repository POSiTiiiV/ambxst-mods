#!/usr/bin/env python3
import sys, os, time, argparse
from concurrent.futures import ThreadPoolExecutor

# Add package directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from settings import load_settings
from palette import load_palette
from targets.kitty import KittyTarget
from targets.btop import BtopTarget
from targets.starship import StarshipTarget
from targets.fastfetch import FastfetchTarget
from targets.spicetify import SpicetifyTarget
from targets.hyprland import HyprlandTarget
from targets.dolphin import DolphinTarget
from targets.fuzzel import FuzzelTarget
from targets.sonora import SonoraTarget
from hyprland_rice import apply_hyprland_rice

TARGETS = [
    KittyTarget(),
    BtopTarget(),
    StarshipTarget(),
    FastfetchTarget(),
    SpicetifyTarget(),
    HyprlandTarget(),
    DolphinTarget(),
    FuzzelTarget(),
    SonoraTarget(),
]

# Maps each target's display name to the positive.theme-sync settings key
# that enables/disables it. A target with no entry here is always active.
SYNC_KEY_BY_NAME = {
    "Kitty": "syncKitty",
    "btop": "syncBtop",
    "Starship": "syncStarship",
    "Fastfetch": "syncFastfetch",
    "Spicetify": "syncSpicetify",
    "Dolphin": "syncDolphin",
    "Fuzzel": "syncFuzzel",
    "Sonora": "syncSonora",
}

def sync_all():
    print(f"=== [ambxst-sync] Synchronizing Desktop Palette ===")
    t_start = time.time()

    settings = load_settings()

    # 0. Dolphin opacity/blur is a compositing preference, independent of
    # whether Dolphin's colors are synced below.
    try:
        apply_hyprland_rice()
    except Exception as e:
        print(f"  ✗ [Hyprland rice] failed: {e}")

    # 1. Load Canonical Palette
    palette = load_palette()
    print(f"  • Source Palette: accent={palette.accent}, bg={palette.background}, fg={palette.foreground}")

    # 2. Dispatch to enabled targets in parallel
    active_targets = [
        t for t in TARGETS
        if settings.get(SYNC_KEY_BY_NAME.get(t.name, ""), True)
    ]
    with ThreadPoolExecutor(max_workers=max(1, len(active_targets))) as executor:
        futures = [executor.submit(target.update, palette) for target in active_targets]
        results = [f.result() for f in futures]

    total_time = (time.time() - t_start) * 1000
    succeeded = sum(1 for r in results if r)
    print(f"=== [ambxst-sync] Complete: {succeeded}/{len(active_targets)} targets synced in {total_time:.1f}ms ===\n")

def main():
    parser = argparse.ArgumentParser(description="Ambxst Desktop Theme Coordinator")
    parser.add_argument("--sync", action="store_true", default=True, help="Synchronize all desktop targets")
    args = parser.parse_args()

    # Debounce slightly to ensure all file writes are flushed
    time.sleep(0.15)
    sync_all()

if __name__ == "__main__":
    main()
