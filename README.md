# Ambxst Mods by POSiTiiiV

A curated collection of declarative modifications and shell enhancements for [Ambxst](https://github.com/Axenide/Ambxst), powered by Ambxst's native modification manager.

---

## 📦 Available Packages

| Package | Name | Description | Status |
| :--- | :--- | :--- | :--- |
| [`wallpaper-transitions`](packages/wallpaper-transitions) | **Wallpaper Transitions** | Smooth animated wallpaper transitions (Crossfade, Iris In/Out, Slides, Zoom & Fade, Pulse), dedicated in-tab settings panel, and comprehensive keyboard navigation. | ✅ Ready (`v1.0.3`) |

---

## 🚀 Quick Install

### Install Any Package via CLI

To install a specific package directly from this repository:

```bash
# Example: Wallpaper Transitions
ambxst mods install https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/wallpaper-transitions
ambxst mods enable positive.wallpaper-transitions
ambxst reload
```

### Install via Ambxst GUI (Settings)

1. Open **Ambxst Settings** (`SUPER + S` or via Dashboard).
2. Go to **Mods** in the left sidebar.
3. Paste the package URL into the **Package source** field:
   ```text
   https://github.com/POSiTiiiV/ambxst-mods/tree/main/packages/<package-name>
   ```
4. Click **Install**, then select the mod in the list and click **Enable**.

### Local Clone & Development

```bash
git clone https://github.com/POSiTiiiV/ambxst-mods.git
ambxst mods install ./ambxst-mods/packages/<package-name>
ambxst mods enable <mod-id>
ambxst reload
```

---

## 📁 Repository Structure

Following the official Ambxst mod manager specification:

```text
ambxst-mods/
├── README.md
├── LICENSE
└── packages/
    └── wallpaper-transitions/
        ├── ambxst.mod.json
        ├── README.md
        ├── LICENSE
        ├── payload/
        │   ├── TransitionWallpaper.qml
        │   └── WallpaperSettingsView.qml
        └── patches/
            └── wallpaper-transitions.patch
```

---

## 📜 License

All packages in this repository are licensed under the [MIT License](LICENSE) unless explicitly specified otherwise within the package directory.
