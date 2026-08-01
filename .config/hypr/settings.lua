-- For all categories, see https://wiki.hypr.land/Configuring/Basics/Variables/

-- Qt applications - use Wayland platform
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")

hl.config({
  general = {
    layout = "dwindle",
    no_focus_fallback = false,
  },

  input = {
    kb_layout = "us",
    kb_variant = "intl",
    kb_model = "pc104",
    kb_options = "",
    kb_rules = "",

    follow_mouse = 1,

    touchpad = {
      natural_scroll = true,
    },

    sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.
  },

  binds = {
    allow_workspace_cycles = true,
  },

  dwindle = {
    preserve_split = true,
  },

  misc = {
    focus_on_activate = true,
    vrr = 1,
    mouse_move_enables_dpms = true,
    key_press_enables_dpms = true,
    disable_hyprland_logo = false,
    force_default_wallpaper = 0,
    enable_swallow = true,
    swallow_regex = "^(Alacritty|kitty|footclient)$",
  },

  debug = {
    disable_logs = false,
  },
})
