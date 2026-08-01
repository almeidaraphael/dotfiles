-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/ for more

hl.window_rule({ match = { class = "^(org.gnome.Calculator)$" }, float = true })
hl.window_rule({ match = { title = "^(Transmission).*" }, float = true })

hl.window_rule({
  name = "thunar-float",
  match = { class = "^(thunar)$" },
  float = true,
  size = { 1024, 768 },
  center = true,
})

hl.window_rule({ match = { title = "^(nmtui)$" }, float = true })

hl.window_rule({ match = { title = "(está compartilhando sua tela.)" }, workspace = "special" })

hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-1" })
hl.workspace_rule({ workspace = "3", monitor = "DP-1" })
hl.workspace_rule({ workspace = "4", monitor = "DP-2", default = true })
hl.workspace_rule({ workspace = "5", monitor = "DP-2" })
hl.workspace_rule({ workspace = "6", monitor = "DP-2" })

-- Layer rules
hl.layer_rule({
  name = "rofi-rules",
  match = { namespace = "rofi" },
  blur = true,
  ignore_alpha = 0.2,
  dim_around = true,
  animation = "popin 80%",
})

hl.layer_rule({
  name = "ags-rules",
  match = { namespace = "gtk4-layer-shell" },
  blur = true,
  ignore_alpha = 0.05,
})

hl.layer_rule({
  name = "quickshell-rules",
  match = { namespace = "quickshell" },
  blur = true,
  ignore_alpha = 0.05,
})
