local theme = require("active-theme")

-- gaps/rounding/animations here are hand-synced with
-- .config/quickshell/Tokens.qml (spacing/radius/motion) — no shared runtime
-- between Hyprland and Quickshell, keep both files in mind when changing either.

hl.config({
  general = {
    -- See https://wiki.hypr.land/Configuring/Basics/Variables/ for more
    gaps_in = 5,
    gaps_out = 8,
    border_size = 2,

    ["col.active_border"] = { colors = { theme.purple, theme.pink }, angle = 45 },
    ["col.inactive_border"] = theme.dark,
    resize_on_border = true,
    extend_border_grab_area = 15,
    hover_icon_on_border = true,
  },

  decoration = {
    -- See https://wiki.hypr.land/Configuring/Basics/Variables/ for more
    -- rounding diverges from Tokens.qml radiusLg (12) on purpose — window corners
    -- and Quickshell panels are different chrome layers, not meant to match 1:1

    rounding = 5,
    rounding_power = 2.0,

    active_opacity = 1.0,
    inactive_opacity = 0.88,

    dim_inactive = false,
    dim_around = 0.5,

    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      xray = false,
      noise = 0.01,
      contrast = 1.2,
      brightness = 0.8,
      vibrancy = 0.45,
      vibrancy_darkness = 0.0,
    },

    shadow = {
      enabled = true,
      range = 12,
      render_power = 4,
      color = "rgba(00000080)",
    },
  },

  animations = {
    enabled = true,
  },
})

-- springy overshoot here vs flat cubic easing in Tokens.qml — Quickshell
-- panels intentionally don't borrow this curve, see Tokens.qml comment
hl.curve("spring", { type = "bezier", points = { { 0.155, 1.105 }, { 0.2, 1.031 } } })
hl.curve("smoothIn", { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 } } })
hl.curve("smoothOut", { type = "bezier", points = { { 0.36, 0 }, { 0.66, -0.56 } } })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "spring", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "smoothOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "spring" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "linear", style = "loop" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "smoothIn" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "spring", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "spring", style = "slidevert" })
