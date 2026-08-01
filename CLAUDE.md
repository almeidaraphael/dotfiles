# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@.capy/AGENTS.md

## What this repo is

Personal Arch Linux + Hyprland dotfiles, deployed via GNU Stow. The repo root mirrors `$HOME` — e.g. `.config/hypr/hyprland.lua` in the repo becomes `~/.config/hypr/hyprland.lua`. The most actively developed part is the Quickshell-based desktop shell in `.config/quickshell/`.

## Applying dotfiles

```sh
stow --no-folding -t "$HOME" \
    --ignore='^\.git$' --ignore='^\.claude$' --ignore='^docs$' --ignore='^\.oh-my-zsh$' \
    .
```

This is what `post-install.sh` runs. A few files are intentionally excluded from stow entirely (see `.stow-local-ignore`) because they're either machine-generated or symlinked manually:

- `hyprland.lua` — symlinked directly by `post-install.sh` (not stowed) since it's the top-level Hyprland entrypoint. Hyprland moved its config format from hyprlang (`.conf`) to Lua as of 0.55; `hyprland.lua` sources the other `.config/hypr/*.lua` files via `require()`.
- `active-theme.conf` / `active-theme.lua` / `active-theme.toml` — written at runtime by `scripts/theme-apply.sh`, not tracked as static config.
- `settings.local.json`, `btop.log` — local/generated state.

`post-install.sh` is the full machine bootstrap (pacman/AUR packages from `.packages`/`.aur_packages`, oh-my-zsh, stow, systemd services). Only re-run pieces of it manually when setting up a new machine — it's not idempotent tooling for iterative dotfile changes.

## Theming

Themes span multiple independent config formats that must be kept in sync:

- `.config/hypr/themes/<name>.conf` — hyprlang color variables, sourced by `hyprlock.conf`/`hypridle.conf` (those two are still on the pre-0.55 hyprlang format)
- `.config/hypr/themes/<name>.lua` — same colors as a Lua module (`return { purple = "rgb(...)", ... }`), `require()`d by `theme.lua` for the main Hyprland config
- `.config/alacritty/themes/<name>.toml`
- `.config/btop/themes/*`, `.config/bat/themes/*`, `.config/micro/colorschemes/*`
- `.config/quickshell/themes/<Name>Theme.qml` — QML singletons implementing the `Theme.qml` interface (Dracula, Nord, TokyoNight)

`scripts/theme-apply.sh <theme>` is the single entrypoint that fans a theme name out to Hyprland, Alacritty, btop, bat, and micro (installed to `~/.local/bin/theme-apply.sh`). It writes both `active-theme.conf` (hyprlock/hypridle) and `active-theme.lua` (hyprland.lua's `theme.lua`). Quickshell's `ThemeManager.qml` calls this script on theme change and additionally pushes live border colors to Hyprland via `hyprctl keyword` (that IPC command still takes the old `category:field = value` syntax regardless of the static config format). Adding a new theme means adding a case to `theme-apply.sh`'s per-tool `case` blocks, a new `.conf` + `.lua` theme file pair for Hyprland, a new theme file for each other tool, and a new `*Theme.qml` + a case in `ThemeManager.setTheme()`.

## Quickshell shell architecture (`.config/quickshell/`)

Entry point is `shell.qml`, which instantiates one `Sidebar` per configured monitor (`ConfigService.sidebarMonitors`, empty = all monitors) plus global singleton panels (Dashboard, MediaPanel, ClipboardPanel, AudioDevicesPanel, PowerMenu, NotificationToast, OSD, AppLauncher).

State is centralized in singletons registered in `qmldir` (module `Quickshell.Rice`): `ConfigService`, `ThemeManager`, `PanelManager`, and per-domain services in `services/` (`HyprlandService`, `MediaService`, `NotificationService`, `OsdService`, `SystemService`, `WallpaperService`, `WeatherService`, `ClipboardService`, `SystemHealthService`). Components read/write these singletons rather than passing props through the tree.

- **`ConfigService`** loads/saves `~/.config/quickshell/config.json` synchronously (blocking `XMLHttpRequest` on load, a detached `Process` writing JSON on save). All user-facing settings (active theme, per-monitor wallpapers, clock format, weather location, etc.) live here.
- **`PanelManager`** is a single `activePanel` string toggle — only one non-sidebar panel can be open at a time. Panels read `PanelManager.activePanel` to decide visibility rather than owning their own open/close state. `ConfigService.sidebarPillBottomY` / `sidebarPillRightEdge` / `sidebarVolumeRowY` are pushed by `Sidebar.qml` so popovers (PowerMenu, AudioDevicesPanel) can anchor near the triggering sidebar control instead of using hardcoded offsets.
- **External process control (toggling panels, OSD) is via Quickshell's `IpcHandler`**, registered in `shell.qml` (targets `"toggle"` and `"osd"`). This is how Hyprland keybinds (`.config/hypr/binds.lua`) drive the shell — via `qs ipc call <target> <function> <args>`, not direct QML signals.

## Tests

A few pure-JS logic modules used by QML components have colocated Node test-runner tests (`*.test.js` next to `*.js`, using `node:test` + `node:assert/strict`, no framework/package.json):

```sh
node --test .config/quickshell/components/launcher/fuzzy.test.js
node --test .config/quickshell/components/launcher/desktopEntries.test.js
node --test .config/quickshell/components/notifications/notificationLogic.test.js

# run all at once
node --test .config/quickshell/components/**/*.test.js
```

QML files themselves (`.qml`) have no automated test coverage — verify changes by reloading Quickshell (`qs -c ~/.config/quickshell` or triggering a Quickshell reload) and observing behavior.

## Planning artifacts

`docs/superpowers/plans/` and `docs/superpowers/specs/` hold dated plan/design docs from past feature work (per-monitor wallpaper, rich notifications, panel keyboard nav, sidebar quick controls). These are historical planning records for the superpowers workflow, not living documentation — check them for prior design rationale on a feature before re-deriving it, but don't expect them to reflect current code state.
