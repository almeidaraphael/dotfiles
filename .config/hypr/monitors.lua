-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

hl.monitor({
  output = "DP-1",
  mode = "2560x1440@180",
  position = "0x0",
  scale = 1,
  bitdepth = 10,
})

hl.monitor({
  output = "DP-2",
  mode = "1920x1080@120",
  position = "2560x0",
  scale = 1,
  bitdepth = 8,
})
