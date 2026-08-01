#!/usr/bin/env bash
set -euo pipefail

THEME="${1:-dracula}"

# sed -i renames a temp file over the target, which unlinks stow symlinks.
# This edits through the symlink instead, so the write lands in the repo.
sed_inplace() {
  local pattern="$1"; shift
  local tmp
  for f in "$@"; do
    tmp=$(mktemp)
    sed "$pattern" "$f" > "$tmp"
    cat "$tmp" > "$f"
    rm "$tmp"
  done
}

case "$THEME" in
  dracula|nord|tokyonight) ;;
  *) echo "Unknown theme: $THEME" >&2; exit 1 ;;
esac

# Hyprland: copy theme vars (cp preserves inode, keeping hard links intact)
# .conf variant is consumed by hyprlock.conf/hypridle.conf (still hyprlang);
# .lua variant is required by hyprland.lua's theme.lua (Lua config, since 0.55)
cp "$HOME/.config/hypr/themes/${THEME}.conf" "$HOME/.config/hypr/active-theme.conf"
cp "$HOME/.config/hypr/themes/${THEME}.lua" "$HOME/.config/hypr/active-theme.lua"

# Alacritty: copy theme colors (auto hot-reloads on file change)
cp "$HOME/.config/alacritty/themes/${THEME}.toml" "$HOME/.config/alacritty/active-theme.toml"

# Micro: update colorscheme in settings.json (in-place via python3 to preserve inode)
python3 -c "
import json
path = '$HOME/.config/micro/settings.json'
with open(path) as f:
    d = json.load(f)
d['colorscheme'] = '$THEME'
with open(path, 'w') as f:
    json.dump(d, f, indent=4)
    f.write('\n')
"

# btop: update color_theme path, reload if running
case "$THEME" in
  dracula)    BTOP_THEME="/usr/share/btop/themes/dracula.theme" ;;
  nord)       BTOP_THEME="/usr/share/btop/themes/nord.theme" ;;
  tokyonight) BTOP_THEME="/usr/share/btop/themes/tokyo-night.theme" ;;
esac
sed_inplace "s|color_theme = .*|color_theme = \"$BTOP_THEME\"|" "$HOME/.config/btop/btop.conf"
pkill -USR1 btop 2>/dev/null || true

# bat: update --theme line
case "$THEME" in
  dracula)    BAT_THEME="Dracula" ;;
  nord)       BAT_THEME="Nord" ;;
  tokyonight) BAT_THEME="TokyoNight" ;;
esac
sed_inplace "s|--theme=.*|--theme=\"$BAT_THEME\"|" "$HOME/.config/bat/config"

# GTK: update gtk-theme-name in settings.ini, push live via gsettings
case "$THEME" in
  dracula)    GTK_THEME="Dracula" ;;
  nord)       GTK_THEME="Nordic" ;;
  tokyonight) GTK_THEME="Tokyonight-Dark" ;;
esac
sed_inplace "s|gtk-theme-name=.*|gtk-theme-name=$GTK_THEME|" "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
