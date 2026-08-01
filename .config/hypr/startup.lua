hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
  hl.exec_cmd("dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP")
  hl.exec_cmd("systemctl --user start hyprland-session.target")
  hl.exec_cmd("systemctl --user start xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-desktop-portal")
  hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd('liquidctl -v -m "Node" set sync color off')
  hl.exec_cmd("env QML_XHR_ALLOW_FILE_READ=1 QML_XHR_ALLOW_FILE_WRITE=1 quickshell -p ~/.config/quickshell")
  hl.exec_cmd("hypridle")

  -- Wallpaper daemon
  hl.exec_cmd("awww-daemon")
end)
