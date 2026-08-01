-- See https://wiki.hypr.land/Configuring/Basics/Binds/ for more

local mainMod = "SUPER"
local terminal = "alacritty"

-- General
hl.bind(mainMod .. " + " .. mainMod .. "_L", hl.dsp.exec_cmd("quickshell ipc call toggle handle launcher"), { release = true })
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("quickshell ipc call toggle handle dashboard"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("quickshell ipc call toggle handle notificationCenter"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("quickshell ipc call toggle handle assistant"))
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd(terminal, { workspace = "special:scratchpad" }))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("thunar"))
hl.bind(mainMod .. " + V", hl.dsp.window.float())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + TAB", hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + TAB", hl.dsp.window.bring_to_top())
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("wayscriber --daemon-toggle"))

-- Volume control
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && quickshell ipc call osd handle volume-mute"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && quickshell ipc call osd handle volume-down"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ && quickshell ipc call osd handle volume-up"))

-- Media control
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))

-- Screenshot
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m window -o $XDG_PICTURES_DIR"))
hl.bind("CTRL + PRINT", hl.dsp.exec_cmd("hyprshot -m region -o $XDG_PICTURES_DIR"))
hl.bind("ALT + PRINT", hl.dsp.exec_cmd("hyprshot -m output -o $XDG_PICTURES_DIR"))
hl.bind(mainMod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m window --clipboard-only"))
hl.bind(mainMod .. " + CTRL + PRINT", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"))
hl.bind(mainMod .. " + ALT + PRINT", hl.dsp.exec_cmd("hyprshot -m output --clipboard-only"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

-- Scratchpad/special
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratchpad" }))
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("scratchpad"))

-- Switch workspaces with mainMod + [0-9]
for i = 1, 9 do
  hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
end
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = "10" }))

-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 9 do
  hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
end
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "10" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Cycle workspaces with keyboard
hl.bind(mainMod .. " + CTRL + right", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + CTRL + left", hl.dsp.focus({ workspace = "e-1" }))

-- Move window to adjacent workspace
hl.bind(mainMod .. " + CTRL + SHIFT + right", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mainMod .. " + CTRL + SHIFT + left", hl.dsp.window.move({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Window resizing submap
local function resize_to_monitor_fraction(ratio)
  return function()
    local win = hl.get_active_window()
    if not win or not win.monitor then
      return
    end
    local target_width = (win.monitor.width / win.monitor.scale) * ratio
    hl.dispatch(hl.dsp.window.resize({ x = target_width, y = win.size.y, relative = false }))
  end
end

hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
  hl.bind("2", resize_to_monitor_fraction(0.5))
  hl.bind("3", resize_to_monitor_fraction(1 / 3))

  -- Pixel-based manual dragging
  hl.bind("right", hl.dsp.window.resize({ x = 30, y = 0, relative = true }), { repeating = true })
  hl.bind("left", hl.dsp.window.resize({ x = -30, y = 0, relative = true }), { repeating = true })
  hl.bind("up", hl.dsp.window.resize({ x = 0, y = -30, relative = true }), { repeating = true })
  hl.bind("down", hl.dsp.window.resize({ x = 0, y = 30, relative = true }), { repeating = true })

  -- Exiting Submap Mode
  hl.bind("escape", hl.dsp.submap("reset"))
end)
