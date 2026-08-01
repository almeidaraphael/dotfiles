# Composition Spec

Per-surface design decisions for the Quickshell desktop shell. Companion to `.ui-craft/brief.md` — the brief anchors principles, this records how those principles translated into specific compositions. Append-mostly; new surfaces add a new `## Surface:` section, existing sections are only edited when a composition decision changes.

---

## Surface: TopBar

### Composition

**Replaces:** the current vertical left `Sidebar.qml` floating pill.
**Decision:** horizontal top bar, floating pill (inset with margin, not edge-to-edge), large convex "squircle" radius — no screen-edge-connecting shader/fillet.
**Why:** Orientation — brief principle 3 ("chrome recedes for the terminal"): a thin horizontal strip at the top costs less of the side-by-side terminal/editor screen real estate than a full-height vertical strip competing with window layout. Shape — tried to replicate Caelestia's border-merging effect; concluded it needs custom shader work not worth the cost. Settled on a plain large-radius floating pill instead (confirmed against a reference screenshot: outer container ~40px radius, nested cards ~20px radius — same shape family at two scales). This nested-radius pattern is the surface's signature detail (brief principle "motion earns its place" / craft rule "vary radius by scale").

### Layout skeleton

```
Compact (topbar, floating, inset from top edge — NOT edge-to-edge)
┌──────────────────────────────────────────────────────────────┐
│   ┌────────────────────────────────────────────────────────┐ │
│   │ 1🌐 2🦊 4📄 5📄        18:02        🔊 🎙 🔕 🔔        │ │
│   └────────────────────────────────────────────────────────┘ │
│         ↑ left cluster       ↑ center       ↑ right cluster   │
└────────────────────────────────────────────────────────────────┘
```

Each workspace item is number + icons **side by side** (not stacked — an earlier revision stacked them, which nearly doubled bar height; reverted per live feedback, "taking a big chunk of the screen"). Clock shows **time only, no date** (dropped per live feedback — bar reads cleaner and stays slim).

Left cluster = workspace indicator (variable width). Center = clock (independently centered, click/Enter/Space → open Dashboard tab). Right cluster = output volume, input volume, keep-awake, DND — **no power button** (dropped, see below).

No mobile/touch variant — out of scope per brief §5. Real variant axis is dual-monitor (DP-1 2560px / DP-2 1920px) — same composition, self-centers per screen independently.

**Revised mid-build:** PowerMenu and the audio-device-picker (`AudioDevicesPanel`) were dropped from TopBar entirely — user judgment call that they no longer belong on this surface. Placement is undecided (likely Settings tab). Both are decoupled from bar-geometry anchoring (generic top-center slide-down, same pattern as Dashboard) and reachable via new keybinds (`Super+Shift+P`, `Super+Shift+A`) in the meantime. `VolumeControl`'s right-click still opens the audio picker as a secondary path.

### Component inventory

| Region | Component | Notes |
|---|---|---|
| left cluster | WorkspaceIndicator | ported from vertical to horizontal layout; per-workspace pill w/ running-app icons |
| center | Clock | opens Dashboard→Overview tab (was: Home); time only, no date (dropped per live feedback) |
| right cluster | VolumeControl ×2 (output/input) | unchanged behavior |
| right cluster | KeepAwakeButton, DndButton | unchanged behavior |
| ~~right cluster~~ | ~~PanelToggleButton (power)~~ | **dropped** — see "Revised mid-build" above |
| shared container | Morph host | **built** — `TopBar.qml` is now the single `PanelWindow`; `Dashboard.qml` converted from a standalone `PanelWindow` to a plain `Item` (screen/visibility/geometry passed in from the host) and embedded directly. Only the topbar on `PanelManager.activeScreen` ever morphs open; other monitors stay compact. Media/Clipboard/Audio/PowerMenu remain separate `PanelWindow`s — not yet folded in. |

### State lattice

| State | Required / Optional / N-A | Notes |
|---|---|---|
| idle | Required | default — all backing services reporting |
| loading | N-A | local IPC services (Hyprland, PipeWire), no meaningful loading state |
| empty | Optional (why: workspace count is always ≥1 in Hyprland) | no design needed |
| error | Required | Hyprland IPC / audio service unreachable → degrade that cluster's icon to a muted/disabled glyph, never a blank gap (extend the existing `resolveIcon` silent-fallback contract from `WorkspaceIndicator` to volume/power) |
| partial | Required | each cluster fails independently — one cluster erroring must never blank the whole bar |
| conflict | N-A | single-user local state |
| offline | N-A | no network dependency in this surface |
| success | N-A | ambient nav, no submit-style action |

### Motion shape

- Entrance: pill fades + slides 8px down from top margin, 200ms, on shell start only (not on every toggle).
- Workspace switch: focused-workspace background color-anims to accent, 100–150ms (reuse existing `Behavior on color` pattern from `PanelToggleButton`/`DndButton`).
- Compact→open (morph): shared window animates geometry from topbar bounds to panel bounds in one continuous resize, ~250ms. Topbar clusters fade out ~100ms into the resize; panel content fades in over the last ~150ms. Radius stays the same convex family throughout — no snapping.
- Open→compact: reverse, ~200ms (exit faster than enter).
- Mute/DND/keep-awake toggle: instant glyph swap, no cross-fade — high-frequency, speed is the feature.

### Acceptance bar

- [x] Topbar renders as a floating, inset pill (not edge-to-edge) on both DP-1 and DP-2 independently — verified via `grim` screenshot on each output
- [x] Left/center/right clusters match the content inventory above (power button intentionally dropped, see revision note)
- [x] Compact↔open is a single shared `PanelWindow` geometry morph — **built for Dashboard**, verified live: opened via `qs ipc call toggle handle dashboard`, confirmed via `hyprctl layers` (464×46 compact → 1574×918 open on DP-2, i.e. `screenW*0.82 × screenH*0.85` — matches Dashboard's original sizing formula exactly) and via screenshot (full calendar/media/system-health/performance content rendering correctly inside the same window). Close verified too (settles back to 464×46). **Media/Clipboard/Audio/PowerMenu still separate `PanelWindow`s** — same pattern not yet extended to them.
  - **Superseded 2026-07-07 (`/critique` finding):** `screenW*0.82 × screenH*0.85` made the open panel balloon to ~70% of screen area (2099×1224 on DP-1) and grow further on bigger displays — read as a maximized window, not a floating glance panel, contradicting brief principle 4 ("less is more") and this section's own real-estate rationale. `Dashboard.qml`'s `implicitWidth`/`implicitHeight` are now fixed at **680×640**, independent of screen size — matches the fixed-width convention every cited reference (Caelestia, DankMaterialShell, macOS/Windows utility panels) uses. Re-verified live across all 5 tabs at the new size via `quickshell ipc call toggle openTab <tab>` — Settings' rail+icon+label+description+control row was the tightest fit measured and still renders clean with margin.
- [~] Every cluster degrades independently on backing-service error — code preserves the original silent-fallback icon pattern, but failure was not actually simulated/tested this pass
- [x] Tab order (keyboard) reads left→right — matches RowLayout source order (workspace → clock → volume/keep-awake/DND); not manually driven with a real Tab key-press test
- [x] Outer radius stays visually continuous — verified: capsule at compact height, locks to `radiusXl` when open, animates smoothly between via `shape.frameRadius`

**Architecture note, revised after first live test:** the first version animated the `PanelWindow`'s own `implicitWidth`/`implicitHeight` directly — janky (every frame forced a real Wayland layer-shell surface reconfigure) and, separately, broke floating (default exclusion zone grew with the open size, shoving every tiled window aside) and doubled the border (Dashboard kept its own `GlassPanel` stacked under the host's). Fixed by:
- Pinning the real surface at a fixed, generously-large size (`screen.width × screen.height`) always — it never resizes. Only an inner `Item` (`shape`)'s local `x/y/width/height` animate now (pure GPU compositing).
- `mask: Region { item: shape }` so the now-oversized invisible surface still passes clicks through to windows underneath everywhere except `shape`'s current bounds.
- `exclusionMode: Normal` + explicit `exclusiveZone` number (compact height) instead of `Auto`, since `Auto` infers the zone from the window's own (now huge) geometry.
- Removed Dashboard's own `GlassPanel` (→ plain `Item`) — the host's `shape` is now the one shared glass surface for both states.
- `dashboardContent` sizes to its own natural `implicitWidth/Height` (not `anchors.fill`) so its bento grid never reflows at intermediate animated sizes — `shape.clip: true` crops it during the transition instead.

**Second live-test round — pin-to-top, edge fusion, constant reservation:**
- `targetY` was centering the shape vertically when open; changed to a flat `0` so both compact bar and open dashboard always anchor to the same top edge, never drift to mid-screen.
- `exclusiveZone` was `0` when open (`Ignore` mode) and `compactHeight + spaceMd` when compact — the drop to `0` let tiled windows reflow into the freed strip, then jump back on close. Changed to a single constant `compactHeight` in both states, `exclusionMode` always `Normal`. The open panel now floats *over* that reserved strip rather than releasing it.
- `margins.top` was `Tokens.spaceMd` (12px floating gap) — the visible gap was breaking the "fused to the screen edge" read the reference image wanted. Changed to `0`. A concave "carve into the edge" shape was considered (per the reference screenshot's corner) but rejected: that trick only works when there's solid backing material behind the seam to carve into (e.g. a solid menu-bar strip, à la the macOS-notch technique) — ours sits over arbitrary transparent wallpaper, nothing to carve. Zero-gap + the existing uniform convex corner radius achieves the same "merged with the edge" look for free, verified via zoomed-in `grim` crop of the corner.

**Bonus fixes, out of original scope:**
- Found and fixed a pre-existing, repo-wide bug — `enabled: !ConfigService.reduceMotion` was set on the inner `Animation` instead of the outer `Behavior` in 16 places across 10 files (`Animation` has no `enabled` property; `Behavior` does). This silently broke the *entire* shell from loading on any fresh restart — unrelated to TopBar, but blocking, so fixed project-wide rather than only in the new files.
- Found and fixed a real layout bug post-build: the three cluster wrapper `Item`s in `TopBar.qml` had `Layout.fillHeight: true` but no `implicitHeight` of their own, so `RowLayout` computed the row's height as ~0 and the window surface hard-clipped all content to a sliver (clock/workspace text showing only bottom pixels). Fixed by binding each wrapper's `implicitHeight` to its child's.
- Fixed focused-workspace highlight radius (`Tokens.radiusMd`, flat 8px) to `height/2` (full capsule) — was breaking the "one shape family" signature bet by sitting square-cornered inside the pill's smooth capsule ends.

---

## Surface: PanelTabs

### Composition

**Decision:** the shared morph-window's open state is a tabbed panel — Overview / Media / Theme / System / Settings — addressable directly via IPC + keybind, not just opened to a default tab.
**Why:** Principle 5 ("keyboard-oriented, and it shows") — a keybind opening straight to a tab requires tabs to be real addressable states, not UI-only navigation. This spec section scaffolds the tab **names, order, and keybind contract** only. Per-tab content redesign (Media waveform, Theme/wallpaper picker, Settings taxonomy) is explicitly deferred to separate future `/shape` passes — noted below, not designed here.

### Layout skeleton

```
Open (shared window, tabbed)
┌──────────────────────────────────────────────────────────────┐
│  Overview   Media   Theme   System   Settings            [×] │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│                    <active tab content>                      │
│                                                                │
└──────────────────────────────────────────────────────────────┘
```

Settings tab only, per DankMaterialShell reference — nested left-rail sub-nav:
```
┌───────────────────┬────────────────────────────────────────┐
│ [rail: icon+label  │  <grouped cards: icon + label +        │
│  nav items]        │   description + control per row>      │
└───────────────────┴────────────────────────────────────────┘
```

### Component inventory

| Tab | Scope now | Status |
|---|---|---|
| Overview | Calendar + Clock + Weather | mostly exists (current Dashboard "Home"), drops Media/system-info cards that move to their own tabs |
| Media | Player controls + waveform | waveform is new content — needs its own `/shape` pass |
| Theme | Theme picker + wallpaper | flagged "needs love" — separate `/shape` pass, do not build off current swatch-dot design (critique finding: dots don't preview actual blur/outfit) |
| System | System info + health (CPU/MEM/GPU/Disk/Network) | backing data exists (`SystemHealthService`, `SystemService`) — layout/viz still needs its own shape |
| Settings | Config fields/dials, nested left-rail sub-nav (icon + label rail; right pane = grouped cards, each row = icon + label + description + control) | flagged "needs love" — nested-sidebar pattern adopted now as the layout convention; exact section taxonomy is a separate `/shape` pass (ours won't mirror Dank's Dock/Displays/Launcher 1:1) |

**Backlog, not yet assigned:** Clipboard history + notification center have no tab. Options noted but undecided: fold into a future 6th "Activity" tab, or keep as standalone anchored quick-access panels (closer to current `ClipboardPanel` behavior) outside the tab system entirely.

### State lattice

Same as TopBar surface — each tab's content states (idle/error/partial) are deferred to that tab's own `/shape` pass; only the tab-switching mechanism itself is in scope here (idle: required: default tab renders; error: required: a tab whose backing service is down shows an inline error, not a blank tab).

### Acceptance bar

- [x] `PanelManager` exposes an `activeTab` alongside `activePanel`, settable directly (not defaulted-then-clicked) — plus `openTab(tab)`/`toggleTab(tab)` helpers
- [x] IPC contract: `qs ipc call toggle openTab <tab>` opens directly to the named tab (separate function, not an optional 2nd param on `handle` — Quickshell's IPC marshaling requires concrete-typed params, and an optional param broke IPC entirely; see `shell.qml`)
- [x] Keyboard focus lands on the target tab immediately on keybind-open — number keys 1-5 switch tabs directly while the panel has focus (`Dashboard.qml`'s `Keys.onPressed`)
- [ ] Tab strip order matches: Overview, Media, Theme, System, Settings
- [ ] Settings tab scaffolds the nested left-rail sub-nav pattern (content taxonomy TBD, layout convention locked)
- [ ] Clipboard/notification-center placement remains explicitly unassigned (not silently decided by the builder)

---

## Surface: Panels

### Composition

**Decision:** resolves the "Backlog, not yet assigned" item at the end of the PanelTabs section above. Architecture-only pass — locks *where* each panel's content lives; per-tab content redesign (Media player layout, Theme picker, System viz, Settings taxonomy, Notification Center visual detail) is explicitly deferred to separate future `/shape` passes, one per panel, per user direction ("We shall have separate /shape passes for each panel").
**Why:** discovery during this pass found `Dashboard.qml`'s live "Home" tab is a flat, monolithic bento grid (Clock, Weather, System info, System health, Calendar, Media, Performance, Clipboard, Notifications all in one screen) — a direct violation of brief principle 4 ("less is more... rules out one big dashboard showing everything at once"). The 5-tab split (Overview/Media/Theme/System/Settings) planned in the PanelTabs section above was never actually built. This pass commits to building that split now rather than patching the monolith further.

### Placement decisions

| Content | Was | Now |
|---|---|---|
| Audio (`AudioDevicesPanel.qml`) | standalone `PanelWindow`, top-anchored, undecided placement | dissolved — moves into **Settings** tab as a new section |
| Clipboard (`ClipboardPanel.qml` + Home-tab bento card) | standalone `PanelWindow` **and** duplicated as a bento card in Home tab | **both deleted** — launcher's clipboard functionality is now the one clipboard surface |
| Media (`MediaPanel.qml` full player + waveform, **and** a separate compact bento card in Home tab) | standalone `PanelWindow` **and** duplicated as a bento card | standalone panel deleted, compact bento card deleted — content consolidates into the **Media** tab |
| Notifications (Home-tab bento card + transient `NotificationToast.qml`) | bento card (full list, clear-all) duplicating a still-to-be-built standalone panel | bento card **deleted**; replaced by a new standalone **Notification Center**, right-anchored panel (first standalone panel not top-anchored — matches TopBar's right cluster side). Toast (`NotificationToast.qml`) is unaffected — stays the transient top-right popup, separate concern from history. |
| Clock, Weather, Calendar | Home-tab bento cards | stay — land in **Overview** tab |
| System info, System health, Performance gauges | Home-tab bento cards | move to **System** tab (corrected mid-pass — first draft mis-assigned these to Overview) |
| Theme swatches, wallpaper picker | currently in flat Settings tab | move to **Theme** tab (relocation only — swatch-dot redesign flagged in the PanelTabs section above stays a separate `/shape` pass) |

### Tab content map (post-split)

| Tab | Content |
|---|---|
| Overview | Clock, Weather, Calendar |
| Media | Full player w/ waveform (promoted from `MediaPanel.qml`) |
| Theme | Theme swatches + wallpaper picker (relocated, not redesigned) |
| System | System info, System health, Performance gauges |
| Settings | Existing rows (weather location, temp unit, clock format, notification timeout, wallpaper mode, topbar monitors) + new Audio section |

### State lattice

Same as PanelTabs section above — only the tab-switching/placement mechanism is in scope here; each tab's own idle/error/partial states are that tab's future `/shape` pass.

### Acceptance bar

- [x] `Dashboard.qml`'s Home tab bento grid is broken into the 5 tabs above — no single tab contains more than the content map assigns it
- [x] `AudioDevicesPanel.qml` deleted; audio sink/source picker exists as a Settings-tab section instead
- [x] `ClipboardPanel.qml` deleted; Home-tab bento Clipboard card deleted; no clipboard UI remains outside the launcher
- [x] `MediaPanel.qml` deleted; Home-tab bento Media card deleted; Media tab is the one surface for player content
- [x] Home-tab bento Notifications card deleted
- [x] New standalone Notification Center panel exists, right-anchored, backed by `NotificationService.notifications`, `Super+N` keybind, unread accent-dot + `seen`/`markAllSeen()`, read-only DND status line
- [x] `NotificationToast.qml` unchanged — still the transient top-right popup
- [x] Each panel's content-level design (Media, Theme, System, Settings taxonomy, Notification Center visuals) has its own `/shape` pass — not designed in this architecture-only pass

**Build note (2026-07-07):** all 5 tab bodies (`OverviewTabBody`/`MediaTabBody`/`ThemeTabBody`/`SystemTabBody`/`SettingsTabBody`) and the `Divider`/`SectionLabel`/`SegCtrl` primitives are inlined as QML `component` declarations directly inside `Dashboard.qml`, rather than living in separate files under `components/tabs/` + `components/shared/` as originally structured during `/craft`. Root cause: Quickshell 0.3.0's `qmlscanner` has a confirmed, reproducible, **non-deterministic** bug where a directory containing multiple plain (non-singleton) component files, reachable only via a nested relative import (not a top-level project import), randomly drops a subset of its types on a cold scan — verified across 20+ restart cycles, different type missing each time, never the same twice. `components/shared/`'s other consumers (`GlassCard`/`GlassButton`/`GlassComboBox`/`GlassPanel`/`PanelHeader`, used shell-wide) were never observed dropping — only `Divider`/`SectionLabel`/`SegCtrl` (Dashboard's own primitives) and the tab bodies. Inlining eliminates the racy directory-resolution path entirely; verified clean across 5+ consecutive cold restarts with `rm -rf ~/.cache/quickshell/qmlcache` between each. Real, load-bearing constraint for this Quickshell version — not a style preference. Revisit if/when Quickshell ships a fix upstream.

### Cross-cutting rules (apply to every panel shape from here on)

**No double-background nesting.** A `GlassCard`/`GlassPanel` must never contain another `GlassCard`/`GlassPanel` unless the inner one is a genuinely distinct, individually-selectable item within a list (e.g. a launcher result row, a notification-history item) — host-frame-plus-list-item is fine, card-wrapping-an-identical-card is not. Full audit (2026-07-07): only real violation was Dashboard's old Performance row (outer `GlassCard` wrapping 5× `MetricCard`-as-`GlassCard`) — already fixed in the System-tab spec by dropping to a flat bar list with no card chrome at any level. Two more instances (Clipboard and Notifications bento cells wrapping their own item delegates) are moot — both cards are deleted per the placement decisions above. Everything else audited clean (`AppLauncher`, `TopBar`, `AudioDevicesPanel`, `MediaPanel`, `PowerMenu`, `OSD`). **Applies to the still-unshaped Notification Center:** use the `GlassPanel`-host + plain-`Rectangle`-row pattern (same as `ClipboardPanel` used), not `GlassCard`-in-`GlassCard`.

**Bento layout for 3+-component panels, with exceptions.** A panel/tab holding 3 or more distinct peer components should compose them as an asymmetric bento grid (one hero + smaller companions, varied sizing) rather than a uniform list or grid — no information lost in the reflow, only spatial reorganization. Applies: Overview (Calendar hero + Clock/Weather companions — already compliant) and System (Performance wide row + Info/Health below — already compliant). Exempted: Media (one cohesive player widget, not independent peer cards — art/text/progress/controls are parts of a single thing) and Theme (carousel rows, not a grid). Settings is the one real conflict — it has 7+ components but spec.md already locked "nested left-rail sub-nav" as its convention before this rule existed; **resolved 2026-07-07: left-rail sub-nav wins for Settings** — form/input rows fit a sidebar-nav pattern better than bento (which suits glanceable read-only data), and it scales better as settings accumulate.

**Semantic type roles — apply narrowly, don't force-fit.** `/tokens` audit (2026-07-07) added `Tokens.typeDisplay`/`typeHeadline`/`typeBody`/`typeLabel` as role aliases over the existing raw size scale. Applied where a size genuinely matches a role's definition: Overview's Clock (`typeDisplay`), Media's title and Settings' category header (`typeHeadline` — both are literal panel/section titles, same class as Dashboard's own header which set the precedent). **Deliberately left as raw tokens, not roles:** Theme's card name (`textMd` — a compact card label, too small for `typeHeadline`'s 20px, not a fit for `typeLabel`'s 8px either), System's metric row labels (`textSm` — inline data labels, would shrink illegibly at `typeLabel`), Settings' rail-item and row labels (`textSm`/`textMd` — nav/form text, not titles or section labels), and Notification Center's reused `NotificationContent` component (existing code, out of scope for this round). Four roles don't have to cover every text instance — per `tokens.md`'s own guidance, don't add a layer to prove the system exists where it doesn't fit.

---

## Surface: Overview

### Composition

**Decision:** Calendar leads as the large centerpiece; Clock and Weather sit as two smaller companion cards beside it. No primary CTA — pure glance surface.
**Why:** Overview drops from the old Home tab's 9 bento widgets to 3 (System/Performance moved to System tab, Media/Clipboard/Notifications moved out per the Panels surface above). Brief principle 4 ("less is more") means the layout should read as deliberately spacious, not a sparse leftover of the old dense grid.

### Layout skeleton

```
Desktop (Calendar leads, Clock + Weather as companions)
┌──────────────────────────────────────────────────────────────┐
│  ┌──────────────────────────┐   ┌─────────────────────────┐  │
│  │                          │   │                         │  │
│  │                          │   │        Clock            │  │
│  │        Calendar          │   │     (hero-scale time)   │  │
│  │   ‹ Month yyyy ›  [Today]│   │        date below       │  │
│  │                          │   │                         │  │
│  │   Su Mo Tu We Th Fr Sa   │   └─────────────────────────┘  │
│  │   1  2  3  4  5  6  7    │   ┌─────────────────────────┐  │
│  │   ...   (today ●)   ...  │   │                         │  │
│  │                          │   │        Weather          │  │
│  │                          │   │   icon · temp · cond.   │  │
│  └──────────────────────────┘   └─────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

No mobile variant — desktop-only per brief §5.

### Component inventory

| Region | Component | Notes |
|---|---|---|
| left, hero | Calendar | month grid, today-highlight (existing), prev/next nav (existing, gets directional slide transition), new "Today" button — visible only when viewing a non-current month |
| right, top | Clock | hero-scale time (`Tokens.typeDisplay`, top of the semantic type-role layer added during the `/tokens` audit — same value as `text4xl`, no new size introduced; hero feel from tighter tracking + more surrounding whitespace, not a bigger raw size), date subtext below |
| right, bottom | Weather | icon + temp + condition; offline/error state reuses the exact same skeleton (icon/temp/condition slots, same card size) — icon → offline glyph, temp → "—°", condition → "Weather unavailable" in `subtext` color, no layout jump, no retry action (matches no-CTA decision) |

### State lattice

| State | Required / Optional / N-A | Notes |
|---|---|---|
| idle | Required | default — all three cards populated |
| loading | Required (Weather only) | existing `WeatherService.loading` → "Loading…"; Clock/Calendar always instant (local compute) |
| empty | N-A | Clock/Calendar always have data by construction |
| error | Required (Weather only) | offline/error placeholder described above — same skeleton, no dead-end "stuck loading" |
| partial | Required | each card fails independently — Weather down never blanks Clock or Calendar |
| conflict | N-A | single-user local state |
| offline | Required | same contract as error — Weather needs network, Clock/Calendar don't |
| success | N-A | no submit-style action on this tab |

### Motion shape

- Entrance: fades in over the last ~150ms of the shared compact→open morph. Stagger: Calendar first, Clock + Weather ~40ms after — inside the existing ~250ms open budget, no separate entrance timeline.
- Month nav (prev/next): **directional slide**, ~150ms, day-grid slides opposite the nav direction (medium-UI motion budget); exit faster than enter.
- "Today" button: instant show/hide (no cross-fade) when leaving/returning to the current month — high-frequency-adjacent, speed is the feature.
- Weather icon/temp updates: instant swap, no animation — infrequent, not communicating a state change worth animating.
- Per-tab panel resize: reuses TopBar's fixed-real-surface technique (surface pinned at max size any tab needs; only an inner `Item`'s bounds animate between tabs, `mask: Region` for click-through) — avoids the geometry-reconfigure jank TopBar's own postmortem already documented. Exact per-tab target sizes still TBD across the other tab shapes.

### Acceptance bar

- [x] Overview renders exactly 3 widgets (Calendar, Clock, Weather) — no leftover System/Performance/Media/Clipboard/Notifications content — verified live via `grim` screenshot on DP-1 (opened via `qs ipc call toggle handle dashboard`)
- [x] Calendar is the visual centerpiece (largest card); Clock + Weather are companions, not equal-weight grid siblings — `Layout.preferredWidth` 60/40 split confirmed in code and screenshot
- [x] Month prev/next has a directional slide transition — `dayGrid.x` `Behavior`/`NumberAnimation` driven by `calendarCard.navigate(direction)`, not code-reviewed as instant swap (not re-verified via live click — no input-simulation tool available in this environment)
- [x] "Today" button appears only when viewing a non-current month, hidden/disabled on the current month — `visible: !calendarCard.isCurrentMonth`, confirmed hidden live while viewing July 2026 (current month)
- [x] Weather offline/error state uses the same icon/temp/condition skeleton as the working state — no layout jump, no dead "Loading…" — code confirms shared skeleton with `WeatherService.error`/`.loading` ternaries
- [x] Each card degrades independently (Weather down ≠ blank Clock/Calendar) — Weather's error branch is local to `weatherCard`, no shared state with `clockCard`/`calendarCard`
- [x] Clock uses `Tokens.typeDisplay` (no new type-scale token introduced) — confirmed at `Dashboard.qml:353`, live screenshot shows 15:28 in hero scale

---

## Surface: Theme

### Composition

**Decision:** merges the old flat-Settings theme swatches and wallpaper picker into one Theme tab, adapted from HyDE's card language (github.com/HyDE-Project/HyDE): a theme-selector row of split-cards (art snippet + solid color block + name) over a wallpaper filmstrip (portrait thumbnails, no captions) scoped to the active theme's folder. Backdrop for the whole tab is a blurred/dimmed render of the active wallpaper, replacing the flat `GlassPanel` convention used elsewhere in the shell — an intentional, scoped exception.
**Why:** spec.md's earlier critique of the swatch-dot design ("dots don't preview actual blur/outfit") is resolved two ways: (1) real wallpaper thumbnails replace color dots, (2) each theme card's own surface material is rendered frosted or flat according to that theme's `blur` property — the card *demonstrates* the outfit rather than describing it with a badge. Ties directly to brief principles 1 ("a theme is an outfit") and 2 ("transparent, not solid").

### New behavior (not just layout)

- Switching theme (Row 1) auto-assigns the first *N* alphabetical wallpapers from that theme's folder across all monitors, *N* = monitor count, in `Quickshell.screens` order, cycling if the folder has fewer images than monitors.
- If the newly selected theme's folder is empty: monitors keep their current wallpaper rather than being blanked.
- Each theme card's surface material (frosted/translucent vs flat/opaque) is driven by that theme's `blur: bool` — no separate badge/glyph.
- **Both rows are navigable carousels**, not static/overflow-scroll rows: `‹ ›` arrow buttons (reuse the existing Calendar/old-wallpaper-picker pattern) flank each row, Left/Right arrow keys step the carousel when that row has focus, current/selected item is the reference point for centering, and both carousels wrap at the ends (5 themes and typically small-ish wallpaper sets don't need a hard stop). Off-screen items peek partially at the row edges to signal there's more to scroll, same affordance idea as the filmstrip's horizontal scroll but now with explicit stepper controls instead of relying on a bare scroll gesture.
- **Wallpaper Mode (manual/random auto-cycle) relocates here from Settings** (resolved during the Settings `/shape` pass) — sits alongside the wallpaper carousel it controls (e.g. near the `[Random]` button in Row 2) instead of split into a separate tab. `ConfigService.wallpaperMode` and `WallpaperService._cycleTimer` are unchanged, only the control's tab placement moves.

### Layout skeleton

```
Desktop — backdrop is a full-bleed blurred/dimmed render of the active
wallpaper (reuses MediaPanel.qml's existing Image + MultiEffect blur
pattern), not the flat GlassPanel used elsewhere

┌──────────────────────────────────────────────────────────────┐
│ ░░░░░░░░░░░░░░░ blurred active wallpaper, dimmed ░░░░░░░░░░░░ │
│                                                                │
│  [‹] ┌───────────┐┌───────────┐┌───────────┐┌──────────┐ [›] │
│      │[art]│Name ││[art]│Name ││[art]│Name ││[art]│Name│      │
│      │frost│     ││flat │     ││frost│     ││frost│    │      │ ← card
│      └───────────┘└───────────┘└───────────┘└──────────┘      │   material
│              ↑ selected (accent ring)   peek →│ demos blur     │
│                                                                │
│  ── wallpaper carousel (active theme's set) ──                  │
│   [DP-1] [DP-2]                                    [Random]   │
│  [‹] ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ [›]              │
│      │     │ │▪DP-1│ │     │ │▪DP-2│ │     │                  │
│      │     │ │ ring│ │     │ │ ring│ │     │  (no captions)   │
│      └─────┘ └─────┘ └─────┘ └─────┘ └─────┘                  │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
└──────────────────────────────────────────────────────────────┘
```

Both rows wrap at the ends; Left/Right arrow keys step the focused row; off-screen items peek at row edges.

No mobile variant — desktop-only per brief §5.

### Component inventory

| Region | Component | Notes |
|---|---|---|
| Row 1 | Theme card ×5, carousel | split layout: art snippet (~60-65% width) + solid theme-color block with name (~35-40%); card surface itself renders frosted or flat per that theme's `blur` property — no separate badge; `‹ ›` steppers + wraparound + Left/Right key nav |
| Row 2 | Monitor-target pills | only when >1 screen; determines which monitor the next filmstrip click assigns to |
| Row 2 | Wallpaper filmstrip, carousel | portrait thumbnail cards, theme-scoped (`WallpaperService.wallpapers`), no filename captions (hidden per direction); `‹ ›` steppers + wraparound + Left/Right key nav |
| Row 2 | Random button | existing, kept, implicitly theme-scoped |
| backdrop | Blurred wallpaper | full-panel, reuses `MediaPanel.qml`'s `Image` + `MultiEffect` blur pattern |

### State lattice

| State | Required / Optional / N-A | Notes |
|---|---|---|
| idle | Required | 5 theme cards + active theme's filmstrip render |
| loading | Required | async thumbnail loads in both rows — cards reserve shape (fixed size, `overlay`-color placeholder), no layout jump |
| empty | Required | theme folder has 0 images — filmstrip shows "No wallpapers in this set"; auto-assign-on-switch leaves monitors' current wallpaper unchanged rather than blanking |
| error | N-A (flagged gap) | `WallpaperService._apply()` is fire-and-forget (`startDetached`), no exit-code check — pre-existing gap, not fixed in this pass |
| partial | Required | multi-monitor auto-assign loops per-monitor independently (same pattern as existing `setRandom`) — one monitor's apply failing must not block others |
| conflict | N-A | single-user |
| offline | N-A | no network dependency |
| success | Optional | accent-ring pulse on the applied filmstrip card is the feedback signal, no toast |

### Motion shape

- Theme card select: accent border-ring animates in ~150ms (existing `Behavior on border.color` pattern) + panel backdrop cross-fades to the new theme's first wallpaper, ~250-300ms.
- Carousel step (either row, `‹ ›` click or arrow key): directional slide ~150ms — same signature motif as Overview's calendar month-nav and this tab's own wallpaper-picker precursor, deliberately reused.
- Filmstrip content swap on theme change: cross-fade ~200ms (folder contents are fully different images).
- Filmstrip select: accent-ring pulse ~150ms.
- Monitor-target pills: instant toggle, high-frequency-adjacent.

**Typography:** theme name on the split-card's solid-color half — `textMd` bold (guaranteed contrast, sits on flat theme color not a photo). No filmstrip captions.

### Acceptance bar

- [ ] Theme selector shows 5 split-cards (art + solid color block + name), each card's own material frosted or flat per that theme's `blur` property — no separate badge/glyph
- [ ] Wallpaper filmstrip is theme-scoped, no filename captions
- [ ] Selecting a theme auto-assigns the first *N* alphabetical wallpapers (N = monitor count) across all monitors in `Quickshell.screens` order, cycling if the folder has fewer images than monitors
- [ ] Empty theme folder never blanks a monitor's existing wallpaper
- [ ] Currently-applied filmstrip card(s) show accent ring + monitor pill when more than one monitor has a different image
- [ ] Backdrop is a blurred render of the active wallpaper, reusing `MediaPanel.qml`'s existing blur technique — no new blur implementation
- [ ] Monitor-target pills only render when >1 screen
- [ ] Both the theme row and wallpaper row are navigable carousels: `‹ ›` steppers, Left/Right key nav on the focused row, wraparound at both ends, off-screen items peek at row edges

---

## Surface: Media

### Composition

**Decision:** straight port of `MediaPanel.qml`'s existing content into the Media tab body, scaled up to fill the larger space — no redesign, no new widgets. Album art stays a supporting anchor (~180-200px, up from 100px); the waveform stays the tab's signature visual, and dominates over art rather than competing with it.
**Why:** the waveform (5 distinct per-theme paint styles) is Media's one truly unique visual bet in the shell — letting album art balloon into a full hero would dilute that. The existing blurred-album-art backdrop technique already scales the "big" visual presence for free as the canvas grows, without the foreground thumbnail needing to grow disproportionately.

### Layout skeleton

```
Desktop
┌──────────────────────────────────────────────────────────────┐
│ ~ ~ ~ ~ ~ waveform, ambient full-width background ~ ~ ~ ~ ~ ~ │
│                                                                │
│  ┌────────────┐                                              │
│  │            │   Title (text2xl)                            │
│  │  Album Art │   Artist (textLg)                             │
│  │ ~180-200px │   Album (textMd)                              │
│  │            │   [Player A] [Player B]  ← multi-player pills │
│  └────────────┘     (hidden at 1 player, unchanged behavior)  │
│                                                                │
│  0:42 ──────────●───────────────────────────────────── 3:15  │
│                                                                │
│              [ ⏮ ]      [ ⏯ ]      [ ⏭ ]                     │
│                                                                │
│ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ │
└──────────────────────────────────────────────────────────────┘

Empty state ("nothing playing")
┌──────────────────────────────────────────────────────────────┐
│ ─────────────────── flatlined waveform, theme-colored,        │
│                       low opacity — same visual language ──── │
│                                                                │
│                    ♪ (muted mono glyph,                       │
│                       subtext color, not accent)               │
│                                                                │
│                    "Nothing playing"                          │
│                    (no CTA — nothing in-panel to click)        │
└──────────────────────────────────────────────────────────────┘
```

No mobile variant — desktop-only per brief §5.

### Component inventory

| Region | Component | Notes |
|---|---|---|
| backdrop | Waveform canvas | ambient, full-width, existing 5 per-theme paint styles unchanged; empty state reuses this exact canvas rendering a flatlined single line at low opacity instead of the reactive spectrum |
| left | Album art | scaled to ~180-200px (from 100px); empty state replaces it with a muted mono music-note glyph, `subtext` color |
| right of art | Title / Artist / Album | title `textLg`→`Tokens.typeHeadline` (matches the "tab's clear focal text" role, same value as `text2xl`), artist `textMd`→`textLg`, album `textSm`→`textMd` — artist/album stay raw sizes, not roles (neither is a title or a section label) |
| right of art | Multi-player pills | unchanged structurally — existing content-hugging width (`pillRow.implicitWidth + spaceMd`), only icon/padding scaled slightly; no overflow/wrap handling added for the rare 3rd-player case |
| below | Progress bar + time labels | unchanged, existing `Behavior NumberAnimation` at `durationSlower`; time labels stay `textXs` mono/`tabular-nums` |
| below | Playback controls | unchanged (prev/play-pause/next) |

### State lattice

| State | Required / Optional / N-A | Notes |
|---|---|---|
| idle | Required | player active, all fields populated |
| loading | N-A | local MPRIS/IPC, no meaningful loading state |
| empty | **Required** | "Nothing playing" — flatlined waveform + muted glyph + copy, no CTA (see layout above) |
| error | N-A | no failure mode beyond "no player," which is the empty state |
| partial | N-A | single data source (`MediaService`); waveform already no-ops correctly when not playing |
| conflict | N-A | single-user |
| offline | N-A | no network dependency |
| success | N-A | ambient control, no submit-style action |

### Motion shape

- Entrance: fades in during the last ~150ms of tab-open/tab-switch.
- Track change: album art + title/artist cross-fade ~200ms (was an instant pop — smoothed now that art is bigger and a jarring swap is more visible).
- Play/pause icon swap: instant, no cross-fade — unchanged, high-frequency.
- Progress bar / scrub dot: unchanged existing `Behavior`.
- Waveform: continuous reactive paint; transitioning into/out of the empty state's flatlined version cross-fades ~200ms rather than snapping.
- Player-switch pill: unchanged existing active-state color animation.

### Acceptance bar

- [ ] Album art renders at ~180-200px, left-anchored — not a full hero, waveform remains the tab's dominant visual
- [ ] Blurred-album-art backdrop technique (existing) fills the larger tab canvas without new implementation
- [ ] Empty state: flatlined waveform (same canvas, low-opacity single line) + muted mono glyph + "Nothing playing" copy, no CTA
- [ ] Title/artist/album text sizes bump one step each per the component inventory
- [ ] Multi-player pill row structurally unchanged — content-hugging width, no overflow/wrap added for 3-player case
- [ ] Track change (art + title/artist) cross-fades instead of popping instantly

---

## Surface: System

### Composition

**Decision:** promotes System info, System health, and Performance metrics from the old Home-tab bento row into their own full tab. Performance metrics switch from radial-ring gauges to **horizontal bars**, stacked as list rows (not side-by-side cards), each with a rolling sparkline beneath. All three sections (Performance, System info, System health) drop their individual `GlassCard` backgrounds — the tab's single panel background is the only chrome layer, sections separated by `Divider {}`, matching the existing Settings tab's grouped-row convention. Health counts and info block stay read-only, counts-only — no drill-down, no remediation actions.
**Why:** (1) double-background fix — each metric previously nested its own `GlassCard` inside an outer bento-cell `GlassCard`, the exact bug class `Dashboard.qml`'s own comments already flag ("a second nested GlassPanel here was double-stacking and muddying the border definition") recurring one level down; removing it and reusing the Settings tab's Divider-separated-rows pattern is consistency, not invention. (2) bars over gauges — a radial ring encodes value as angle (arc sweep); a bar encodes it as length along a shared baseline. Cleveland-McGill ranks length above angle for perceptual accuracy, which matters when eyeballing 5 metrics at once. Bars also pair naturally with the sparkline beneath (same horizontal axis), where a ring-over-rectangle was a visual mismatch. (3) rows, not side-by-side bars — CPU/RAM/GPU/Disk share a 0-100% scale but Net (KB/s) doesn't; stacking as independent rows avoids implying false cross-metric comparability that side-by-side bars would suggest.

### Layout skeleton

```
Desktop — single panel background throughout, Dividers between sections,
no per-metric/per-section card chrome

┌──────────────────────────────────────────────────────────────┐
│  PERFORMANCE                                                   │
│  CPU   ████████████░░░░░░░░  62%   ∿∿∿∿∿∿∿∿∿∿∿∿∿∿ (sparkline)  │
│  RAM   ██████░░░░░░░░░░░░░░  31%   ∿∿∿∿∿∿∿∿∿∿∿∿∿∿              │
│  GPU   ███░░░░░░░░░░░░░░░░░  14%   ∿∿∿∿∿∿∿∿∿∿∿∿∿∿              │
│  NET   ↓ 2.1 MB/s  ↑ 340 KB/s      ∿∿∿∿∿∿∿∿∿∿∿∿∿∿              │
│  DISK  ██████████████░░░░░  71%   ∿∿∿∿∿∿∿∿∿∿∿∿∿∿              │
│  ────────────────────────────────────────────────────────      │
│  SYSTEM INFO                    SYSTEM HEALTH                  │
│  [avatar] user                  UPDATES 3    ORPHANS 0         │
│  OS name                        FAILED  0    CRASHES 1         │
│  WM · SESSION · UPTIME          (counts only)                  │
└──────────────────────────────────────────────────────────────┘
```

No mobile variant — desktop-only per brief §5.

### Component inventory

| Region | Component | Notes |
|---|---|---|
| top, list | Performance rows ×5 (CPU/RAM/GPU/NET/DISK) | horizontal bar (length-encoded fill, existing `metricCpu`/`metricRam`/etc. theme colors) + value/detail text + sparkline beneath — **no card wrapper**, rows separated by label/spacing only; rolling sparkline buffer kept in the tab's own local state, no `SystemService` changes |
| below divider, left | System info | unchanged content (avatar, username, OS name, WM, session type, uptime) — **no card wrapper**, sits directly on panel background |
| below divider, right | System health | unchanged content (Updates/Orphans/Failed/Crashes counts) — **no card wrapper**, counts only, no drill-down |

### State lattice

| State | Required / Optional / N-A | Notes |
|---|---|---|
| idle | Required | all 5 bars + info + health populated |
| loading | **Required** | first ~1.5s before the initial poll resolves — bars/sparklines must show a skeleton/placeholder state, not a `0%` that looks like real data |
| empty | N-A | sparkline buffer starting empty is covered by the loading state above, not a distinct empty case |
| error | Optional (why: hardware absence, e.g. no discrete GPU, currently reads as a silent `0%` — indistinguishable from "0% busy." Flagged as an open question below, not committed to a fix here) | |
| partial | Required | the 5 metric polls run as independent shell commands (`_pollCpu`, `_pollRam`, etc.) — one failing must not blank the others, matches the shell's existing independent-failure principle |
| conflict | N-A | single-user |
| offline | N-A | no network dependency |
| success | N-A | read-only monitoring, no submit action |

### Motion shape

- Entrance: Performance rows fade in first (primary visual), System info + health ~40ms after — inside the existing ~150ms tab-open fade budget.
- Sparkline updates: continuous `Canvas` redraw as new samples accumulate, same technique as Media's waveform — no separate transition framework.
- Bar fill value change: add `Behavior on width { NumberAnimation }` tween between old/new percentage — currently the ring snapped instantly, worth carrying the same smoothing over to the bar's fill width since values update every 1.5s (noticeably more often than health counts).
- Health count changes: instant swap, no animation — infrequent (15min poll interval), no motion budget justified.

**Typography:** metric labels (CPU/RAM/GPU/NET/DISK) `textSm` bold, unchanged. Value/detail readout stays mono `tabular-nums`, right-aligned at the bar's end. Health count values bump to `textLg` bold mono (was cramped in the old quad card); health labels stay `text2xs` `subtext`.

### Open questions

- Sparkline buffer size / time window — concrete sample count and interval (e.g. last 60 samples × 1.5s ≈ 90s) needs picking at build time.
- Silent-zero vs explicit "N/A" for absent hardware (e.g. no discrete GPU shows `0%`, indistinguishable from "present but idle") — worth distinguishing, or accept the ambiguity?
- `SystemService._visible` currently gates polling on `PanelManager.activePanel === "dashboard" || "performance"` — this predates the tab split and needs updating to the new `activeTab`-based model, or the 1.5s poll timer runs continuously whenever Dashboard is open regardless of which tab is active, wasting cycles on Overview/Theme/Media/Settings. Real bug risk if missed during build, not just a style note.
- Exact bar track styling (track color/opacity to read clearly with no card background behind it) — TBD at build time.

### Acceptance bar

- [ ] Performance section renders 5 horizontal-bar rows (not radial rings, not side-by-side cards), each with a sparkline beneath
- [ ] No section (Performance, System info, System health) has its own `GlassCard`/card background — single panel background only, `Divider {}` between sections
- [ ] Sparkline data is a local rolling buffer — no `SystemService`/`SystemHealthService` backend changes
- [ ] System info and System health render unchanged content, counts-only, no drill-down, no remediation actions
- [ ] Loading state (first ~1.5s) shows a skeleton, not a `0%` that reads as real data
- [ ] Each of the 5 performance polls fails independently — one metric erroring never blanks the others
- [ ] `SystemService._visible` gate updated to the tab-based model so polling only runs while the System tab is actually active

---

## Surface: Settings

### Composition

**Decision:** nested left-rail sub-nav (locked in the PanelTabs section and reconfirmed as the winner over bento in the Panels cross-cutting rules). Left rail: **Audio / Display / Weather / General**, 4 categories for ~7 total settings items. Right pane: grouped rows, each `icon + label + description + control`, matching the existing Settings-row convention already in `Dashboard.qml`. Audio's device picker uses the existing, currently-unused `GlassComboBox` component (2 rows: Output Device, Input Device) rather than porting `AudioDevicesPanel.qml`'s full expandable list — keeps every category's detail pane structurally consistent (one control per row), no exception category.
**Why:** taxonomy balances category count against item count — 4 categories for 7 items avoids both a single giant flat list and over-fragmenting into one-item categories. `GlassComboBox` already exists and was unused anywhere in the shell; reusing it for Audio is both the more consistent choice (fits the atomic row pattern every other setting uses) and avoids building a second, structurally different picker UI. Wallpaper Mode is *not* here — it relocated to the Theme tab (see that surface's amendment above) since Theme now owns the wallpaper carousel it controls.

### Layout skeleton

```
Desktop
┌──────────────────────────────────────────────────────────────┐
│  ┌──────────┐  Audio                                          │
│  │ 󰕾 Audio  │  ──────────────────────────────────────────    │
│  │  Display │  Output Device        [Speakers        ▾]      │
│  │  Weather │  Input Device         [Microphone       ▾]      │
│  │  General │                                                 │
│  └──────────┘                                                 │
│      ↑ rail, icon+label, accent-highlighted selected item     │
└──────────────────────────────────────────────────────────────┘

Display category:
  Topbar Monitors        [DP-1 DP-2            ]  (text input, space-separated)

Weather category:
  Weather Location       [auto                 ]  (text input, city or lat,lon)
  Temperature Unit       [ C | F ]              (segmented control)

General category:
  Clock Format           [ 24h | 12h ]          (segmented control)
  Notification Timeout   [ − 3.0s + ]           (stepper)
```

No mobile variant — desktop-only per brief §5.

### Component inventory

| Region | Component | Notes |
|---|---|---|
| left | Rail | 4 items (Audio/Display/Weather/General), icon + label, accent-highlighted selected state |
| right, Audio | 2 rows | Output Device, Input Device — each a `GlassComboBox` populated from `AudioDevicesPanel.qml`'s existing sink/source scan + friendly-name logic (`friendlyDeviceName()`), reused not reinvented |
| right, Display | 1 row | Topbar Monitors — existing text-input row, unchanged |
| right, Weather | 2 rows | Weather Location, Temperature Unit — existing rows, unchanged |
| right, General | 2 rows | Clock Format, Notification Timeout — existing rows, unchanged |

### State lattice

| State | Required / Optional / N-A | Notes |
|---|---|---|
| idle | Required | rail + selected category's rows render, all controls reflect current `ConfigService` values |
| loading | N-A | local config loads synchronously (`ConfigService`'s existing blocking XHR load) |
| empty | Required (Audio only) | zero sinks/sources found (audio service down) — `GlassComboBox` must show a clear disabled/placeholder state, not a blank dropdown |
| error | N-A | no meaningful failure mode beyond Audio's empty case above |
| partial | Required | Audio's device scan can fail/be empty independently without affecting Display/Weather/General rows — same independent-failure principle used everywhere else in the shell |
| conflict | N-A | single-user |
| offline | N-A | no network dependency (Weather Location is just a text field here, not a live fetch) |
| success | Optional | each control's own state change (segmented highlight, dropdown selection) is the feedback, no separate toast |

### Motion shape

- Entrance: rail + first category's rows fade in with tab-open, ~150ms, consistent with other tabs.
- Category switch (rail click): right pane content cross-fades ~150-200ms — crossfade, not a directional slide, since rail categories are a flat list with no sequential/next-prev relationship (unlike Theme's carousels or Overview's calendar).
- Rail selection indicator: accent highlight moves to the new item, ~150ms — same `Behavior on color` pattern already used shell-wide.
- Row controls (dropdown, segmented toggle, stepper): unchanged existing per-control motion.

**Typography:** rail item label `textSm` (raw — nav-item text, not a title, doesn't fit `typeLabel`'s 8px without hurting legibility). Category header (right pane top) `Tokens.typeHeadline` (was `textLg`, bumped to match Dashboard's own panel-header precedent — same "panel/section title" role). Row label `textMd` bold, row description `textSm` `subtext` — both raw, matches the existing pattern already used for e.g. "Weather Location" / "City name or lat,lon".

### Open questions

- Rail icon glyphs per category (Audio/Display/Weather/General) — pick specific mono icon-font symbols at build time.
- Default category on tab open — always Audio (first item), or remember last-visited category (needs new `ConfigService` persistence, doesn't exist today)?
- Long-term scalability of the "General" catch-all (Clock Format + Notification Timeout) as more settings accumulate — not blocking now, worth revisiting if it grows past ~4-5 items.

### Acceptance bar

- [ ] Left rail shows exactly 4 categories: Audio, Display, Weather, General
- [ ] Audio category uses 2 `GlassComboBox` rows (Output/Input), not the ported full list picker
- [ ] Every row across all 4 categories follows the same `icon + label + description + control` pattern — no structural exception category
- [ ] Wallpaper Mode does **not** appear in Settings — confirmed relocated to Theme tab
- [ ] Audio empty state (no sinks/sources) shows a clear placeholder, not a blank dropdown
- [ ] Category switch cross-fades the right pane, no directional slide
- [ ] All existing settings values (`ConfigService`) read/write unchanged — only presentation/grouping changes

---

## Surface: Notification Center

### Composition

**Decision:** new standalone panel, full-height right rail (not a compact popup like the deleted Audio/Clipboard panels), first standalone panel anchored right instead of top. Per-item content reuses `NotificationContent.qml` as-is (already built for `NotificationToast`) rather than reimplementing icon/summary/body/actions — this panel composes around it, adding timestamp, dismiss, and an unread dot. Trigger is `Super+N` (confirmed unused in `binds.conf`) — the shell's first standalone panel to actually get a wired keybind; the old "Super+Shift+A/P" comments on Audio/PowerMenu were aspirational and never implemented.
**Why:** reusing `NotificationContent.qml` avoids duplicating icon-fallback/body-clamp/action-button logic that already exists and is shared with the toast — same content, two surfaces (transient vs history). Right-anchored full-height distinguishes this from the compact top-anchored panels being deleted, and suits a scrollable history list better than a short popup. `GlassPanel` host + `GlassCard` per item follows the cross-cutting no-double-background rule's own named exception (host-frame-plus-distinct-list-item is legitimate, unlike the Performance-row bug that rule was written to catch).

### New behavior (not just layout)

- `NotificationService` gains a small addition: per-entry `seen: bool` (defaults `false` on creation) + a `markAllSeen()` function, called when the panel opens. Scoped intra-panel only this pass — no TopBar bell/badge (declined; that's separate, undone scope).
- Unread items show a small accent dot (not a colored border — anti-slop names "thick colored left/top border on cards" as a Major violation). Dot fades out ~150ms as the panel marks items seen on open.
- DND status shown read-only inside the panel when active (explains why nothing's arriving) — no duplicate interactive DND control; `TopBar`'s `DndButton` stays the only one.

### Layout skeleton

```
Desktop — full-height right rail, width matches NotificationToast (360-420px)
for visual consistency between the two surfaces sharing NotificationContent

                                          ┌────────────────────────┐
                                          │ Notifications      [×] │
                                          │ (DND active — muted)   │  ← only
                                          ├────────────────────────┤     when on
                                          │ ● ┌────────────────────┐│
                                          │   │▎App · 2m ago        ││ ← unread
                                          │   │ Summary          [×]││   dot
                                          │   │ Body, 2 lines…       ││
                                          │   │ [Action] [Action]    ││
                                          │   └────────────────────┘│
                                          │   ┌────────────────────┐│
                                          │   │▎App · 14m ago    [×]││
                                          │   │ …                    ││
                                          │   └────────────────────┘│
                                          │           ⋮              │
                                          │      [Clear all]         │
                                          └────────────────────────┘

Empty state
                                          ┌────────────────────────┐
                                          │ Notifications      [×] │
                                          ├────────────────────────┤
                                          │                        │
                                          │   No notifications     │
                                          │                        │
                                          └────────────────────────┘
```

No mobile variant — desktop-only per brief §5.

### Component inventory

| Region | Component | Notes |
|---|---|---|
| header | Title + close, DND status line | DND line only rendered when `NotificationService.doNotDisturb` is true |
| list | `GlassCard` per item, wrapping `NotificationContent` | adds: timestamp (`textXs` `subtext`), dismiss `×`, unread accent dot — `NotificationContent` itself unchanged, reused as-is |
| footer | Clear all | calls `NotificationService.dismissAll()`, existing function, unchanged |
| empty | Placeholder | "No notifications" — doubles as first-run and post-clear-all |

### State lattice

| State | Required / Optional / N-A | Notes |
|---|---|---|
| idle | Required | list populated from `NotificationService.notifications` |
| loading | N-A | local, synchronous |
| empty | Required | doubles as first-run and post-clear-all |
| error | N-A | local DBus, no meaningful failure mode |
| partial | Optional (why: a single notif missing icon/image already falls back via existing `NotifLogic.resolveNotificationIcon`) | |
| conflict | N-A | single-user |
| offline | N-A | no network dependency |
| success | Optional | dismiss/unread-clear is self-evident (item leaves list / dot fades), no toast |

### Motion shape

- Entrance: slide in from the right edge + fade, `Tokens.durationNormal` (200ms), `Easing.OutCubic` — same `Behavior on offsetScale` pattern as other panels, axis flipped (x instead of y), first right-anchored panel in the shell.
- Item dismiss: height-collapse + fade, ~150ms, list reflows underneath.
- Clear all: stagger-out top-to-bottom, ~40ms stagger, capped at ~300ms total.
- Unread dot: fades ~150ms when the panel opens and marks items seen.
- Close: reverse of entrance, ~150ms (exit-faster-than-enter).

**Typography:** reuses `NotificationContent`'s existing scale unchanged. New additions: timestamp `textXs` `subtext`, unread dot ~`Tokens.spaceXs` (8px), DND status label `textXs` `subtext`.

### Open questions

- Exact panel width within the 360-420px range — pick a single value at build time.

### Acceptance bar

- [ ] Panel is full-height, right-anchored — first right-anchored panel in the shell
- [ ] Opens via `Super+N` (newly wired, confirmed unused beforehand)
- [ ] Per-item content reuses `NotificationContent.qml` unchanged — no duplicated icon/body/action logic
- [ ] `NotificationService` gains `seen: bool` per entry + `markAllSeen()`, called on panel open
- [ ] Unread indicator is a small accent dot, not a colored border (anti-slop compliance)
- [ ] DND status shown read-only when active — no second interactive DND control
- [ ] Empty state and Clear all present, reusing existing `NotificationService.dismissAll()`
- [ ] `GlassPanel` host + `GlassCard` per item — no additional nesting beyond that one legitimate level

## Surface: Assistant Panel

### Composition

**Decision:** new standalone panel, full-height **left** rail — deliberate mirror of Notification Center (full-height right rail), same host pattern (`PanelWindow` + `GlassPanel`, `offsetScale`/margins slide), axis and edge flipped. Two sub-views inside one panel, list-view default and chat-view on selecting a conversation, toggled by a local `state` property rather than two separate panels — keeps `PanelManager.activePanel` a single `"assistant"` entry. Trigger `Super+A` (confirmed unused in `binds.lua`). Backend is a new `OllamaService.qml` singleton (real HTTP calls to `localhost:11434`, `/api/chat` streaming + `/api/embeddings`), following the existing `services/` pattern (`NotificationService`, `MediaService`, etc.) — not mocked.
**Why:** list+chat as one panel with an internal view toggle follows brief principle 4 ("less is more" — show as little as possible; a separate always-visible conversation sidebar would violate that on a 420px-wide panel). Left-anchoring gives the shell its second axis (after Notification Center's right), keeping a visual left/right split between "things that happen to you" (notifications, right) and "things you ask for" (assistant, left). RAG is scoped per-conversation (embed on attach, discard on delete) — no persistent vector store to build/maintain, consistent with principle 4's minimalism and avoiding a second durable-storage subsystem this pass.

### New behavior (not just layout)

- New `OllamaService.qml`: conversation list (id, title, messages, attachments), streaming chat via `/api/chat`, attachment chunking + `/api/embeddings` per attachment, connection/model status polling. This is new backend surface, not reuse — no existing service covers LLM or file-embedding.
- New `AttachmentChip` pattern in the composer: filename + status (queued/embedding/ready/failed), removable. Failed embedding is a **partial** state, not a panel-level error — rest of the conversation stays usable.
- RAG citations render as an expandable `▸ source: <file>` line under an assistant message when the response drew on an attached-file chunk — click reveals the source snippet inline, no separate panel.

### Layout skeleton

```
Desktop — full-height left rail, width 420px (wider than Notification Center's
380px — chat bubbles need more room than notification cards)

┌────────────────────────┐
│ Assistant       [+][×] │
├────────────────────────┤
│ ● ollama · llama3.1 ·  │  ← status line, always visible
│   connected             │
├────────────────────────┤
│ ┌──────────────────────┐│
│ │ Conversation title    ││
│ │ last message…    2h   ││
│ └──────────────────────┘│
│ ┌──────────────────────┐│
│ │ Conversation title 2  ││
│ │ last message…    1d   ││
│ └──────────────────────┘│
│           ⋮ (ListView)  │
└────────────────────────┘

Chat view (same panel, state toggled)
┌────────────────────────┐
│ [←] Conv. title    [×] │
├────────────────────────┤
│ ● ollama · llama3.1 ·  │
│   connected             │
├────────────────────────┤
│ user: message           │
│                          │
│        assistant: resp  │
│        [▸ source: x.md] │
│           ⋮ (ListView)  │
├────────────────────────┤
│ [📎 notes.md ✓][📎 x.py⋯]│
│ ┌────────────────────┐[↑]│
│ │ type message…       │  │
│ └────────────────────┘  │
└────────────────────────┘

Empty state
┌────────────────────────┐
│ Assistant       [+][×] │
├────────────────────────┤
│                          │
│   No conversations yet   │
│   Start one, attach a    │
│   file for grounded      │
│   answers.                │
│                          │
└────────────────────────┘
```

No mobile variant — desktop-only per brief §5.

### Component inventory

| Region | Component | Notes |
|---|---|---|
| header | Title (or back + conv. title in chat view) + close | back button only rendered in chat view |
| status | Connection/model line | `● ollama · <model> · connected\|down`, `text2xs` tracked label |
| list | `GlassCard` per conversation | title `textMd` semibold, preview + relative time `textXs` `subtext` |
| chat | Message bubbles, `ListView` | user right-ish/plain, assistant plain — no chat-bubble-color slop, plain text blocks differentiated by alignment + subtle bg tint on assistant only |
| citation | Expandable `▸ source:` row under assistant message | only rendered when response cites an attachment chunk |
| composer | Attach button, `AttachmentChip` row, text input, send | chips show queued/embedding/ready/failed |
| empty | Placeholder | "No conversations yet" — doubles as first-run onboarding |

### State lattice

| State | Required / Optional / N-A | Notes |
|---|---|---|
| idle | Required | list populated, or chat view with messages |
| loading | Required | streaming response — input disabled, stop control shown, no per-token animation (high-frequency per Motion Decision Ladder) |
| empty | Required | zero conversations, doubles as onboarding copy |
| error | Required | Ollama unreachable or model missing — specific cause + retry action, no generic "something went wrong" |
| partial | Required | one attachment fails to embed; conversation and other attachments stay usable, chip shows failed state |
| conflict | N-A | single local user |
| offline | Folded into error | "Ollama down" is a local HTTP failure, not a sync surface — no queue/reconcile needed |
| success | Optional | turn completing returns to idle silently; chip reaching "ready" is a quiet state change, no toast |

### Motion shape

- Entrance: slide in from the **left** edge + fade, `Tokens.durationNormal` (200ms), `Easing.OutCubic` — same `offsetScale`/margins pattern as Notification Center, axis and edge flipped (`margins.left` instead of `margins.right`).
- List → chat transition: crossfade + 8px slide, ~150ms, within the same panel (no new `PanelWindow`).
- New message: fade + 8px-up on arrival. Streaming tokens themselves: no animation (high-frequency).
- Attachment chip: fade in on attach, ~120ms; status changes (queued→embedding→ready) are instant color/label swaps, not animated.
- Close/back: reverse of entrance, ~150ms (exit-faster-than-enter).

**Typography:** panel title `typeHeadline`, conversation-list title `textMd` semibold, message body `textSm`, timestamps/meta `textXs` `subtext`, status line `text2xs` with positive tracking (small tracked label — the caps-rule exception).

### Open questions

- Exact Ollama model default (`llama3.1` used as placeholder above) — pick at build time based on what's already pulled locally.
- Chunk size/overlap for attachment embedding — pick a reasonable default (e.g. ~500 tokens, 50 overlap) at build time, not user-configurable v1.

### Acceptance bar

- [ ] Panel is full-height, **left**-anchored — second axis in the shell after Notification Center's right
- [ ] Opens via `Super+A` (newly wired, confirmed unused beforehand)
- [ ] List view and chat view are one panel with an internal toggle, not two separate `PanelWindow`s
- [ ] New `OllamaService.qml` handles real `/api/chat` streaming + `/api/embeddings` — not mocked
- [ ] Attachments limited to text/code/markdown v1; embedding failure is a per-chip partial state, not a panel-level error
- [ ] RAG citations are expandable, only rendered when a response actually cites an attachment
- [ ] Empty state present, doubles as onboarding
- [ ] Enter sends / Shift+Enter newline / Escape → back-then-close, matching existing panel keyboard conventions
- [ ] `GlassPanel` host, `GlassCard` per conversation/message region — no double-glass nesting
- [ ] Status line always visible, shows connection + active model, `down` state routes to the error state with a retry action

---

## Surface: hyprlock

### Composition

**Decision:** replace the current flat/solid lock screen (top-right clock+date floating on a sharp static image, circular avatar, bare `input-field` with only a decorative accent border) with a single frosted **glass panel** (hyprlock's `shape` widget, supported since ~0.7, confirmed on installed v0.9.6) centered on screen, grouping clock + date + password input into one cohesive block. Background wallpaper is blurred (`blur_passes = 2, blur_size = 7`) and sourced from the same wallpaper Quickshell's `WallpaperService` currently has active, via a generated `active-wallpaper.conf` (see "New behavior" below) instead of a separate hardcoded `~/Pictures/lockscreen/background-N.png`. Avatar photo is cut.
**Why:** ties directly to brief principle 1 ("a theme is an outfit, not a tint" — lock screen currently doesn't participate in the per-theme outfit at all, hardcoded Dracula purple border regardless of active theme) and principle 2 ("transparent, not solid" — the shell's default surface treatment should extend to hyprlock, not stop at Quickshell's window boundary). Avatar cut follows principle 4 ("less is more" — sole-user machine, a photo confirms nothing the user doesn't already know) and brief §5 scope (no multi-user UI, so no identity-picker role for the photo either).
**Correction (post-build, user feedback):** the initial pass shipped with `blur_passes = 0` (crisp background), reasoning that a sharp backdrop would keep panel-vs-backdrop contrast high. This was wrong in practice — hyprlock's `shape` widget has **no blur field at all** (checked directly against its config schema); background blur is the *only* blur mechanism this ecosystem exposes. With the background crisp, the panel was structurally incapable of reading as "glass" — it rendered as a flat tinted box, not frosted. Background blur is now on.
**Dead end, don't re-attempt — localized blur:** tried layering a second `image` widget (a blurred crop of the wallpaper, sized/positioned to exactly match the panel) on top of a crisp `background`, to get *only* the panel-region blurred while the rest of the wallpaper stays sharp. Confirmed by direct testing (not guessed) that this doesn't work on installed hyprlock v0.9.6: `image`'s `size` field is square-only (a single int — `"380, 250" cannot parse as an int`), and `image` has **no** `blur_passes`/`blur_size` property at all (`config option <image:blur_passes> does not exist`). No widget in this version can blur an arbitrary rectangle — only fullscreen `background` blurs. User was given the real tradeoff (accept fullscreen blur vs. build a pre-baked-composite-image pipeline via ImageMagick outside hyprlock entirely) and chose fullscreen blur — same behavior as macOS/GNOME/Windows lock screens.

### New behavior (not just layout)

- The lock screen's wallpaper is kept in sync via a generated `~/.config/hypr/active-wallpaper.conf` (`$lockWallpaper` var, same pattern as `active-theme.conf`), written by `WallpaperService.qml` on every `set()` and at Quickshell startup — not hyprlock's own `reload_cmd` (that path has known crash reports, hyprwm/hyprlock#733). See Acceptance bar for detail.
- Single `background`/`shape` pair with `monitor =` left blank, same universal-across-monitors behavior as the current file — no per-monitor wallpaper differentiation in the lock screen (that stays a Quickshell-only, unlocked-session feature).
- All colors (`$purple`, `$background`, `$dark`, `$light`) continue to resolve via `source = active-theme.conf`, so switching theme (`theme-apply.sh`) re-colors the glass panel border, fail/capslock/check states, and text together — no hyprlock-specific values hardcoded outside the theme var file.

### Layout skeleton

```
Desktop (hyprlock has no responsive breakpoints — fixed absolute
positions per monitor resolution, single layout, no mobile variant)

┌────────────────────────────────────────────────────┐
│ ▒▒▒▒▒▒▒▒▒▒▒ blurred wallpaper (WallpaperService's) ▒│
│                                                      │
│              ┌────────────────────────┐             │
│              │                        │  ← margin   │
│              │        HH:MM           │    (36px)   │
│              │  Weekday, DD Month     │  ← glass    │
│              │                        │    panel    │
│              │  [●●○○○○○○  ......]    │    (shape   │
│              │  Logged in as $USER    │    widget)  │
│              │                        │  ← margin   │
│              └────────────────────────┘             │
│                                                      │
│ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │
└────────────────────────────────────────────────────┘
```

No mobile variant — desktop-only per brief §5.

### Component inventory

| Region | Component | Notes |
|---|---|---|
| backdrop | `background` widget | blurred (`blur_passes = 2, blur_size = 7`) — required for the panel to read as glass at all, since `shape` has no blur field of its own; path kept in sync via `active-wallpaper.conf` (see New behavior) |
| panel | `shape` widget | 380×250, rounded rect, translucent fill (reuses `GlassCard`'s 0.30-opacity precedent from the brief's Liquid Glass rule 2), `$purple`-ish accent border via theme var, centered, 36px margin top/bottom to its content group |
| panel content | `label` (clock) | P0, 60px (down from an initial 88px — read as oversized with no breathing room), inside panel — was top-right floating, now panel-centered |
| panel content | `label` (date) | P0, secondary size, inside panel |
| panel content | `input-field` | P0, dots style kept, `outer_color`/`fail_color`/`capslock_color`/`check_color` unchanged (native state signals, theme-driven) |
| panel content | placeholder/fail text | P1, native pango markup, shown conditionally (fail only on wrong attempt) |
| — | avatar `image` | **cut** — removed entirely |

### State lattice

| State | Required / Optional / N-A | Notes |
|---|---|---|
| idle | Required | panel + clock/date + empty input, placeholder visible (`fade_on_empty = false`, unchanged) |
| input-active | Required | native dot growth as `$PASSWORD` typed, no custom animation needed |
| error (fail) | Required | native `fail_color` outline + `fail_text` (`$FAIL ($ATTEMPTS)`), unchanged from current config |
| capslock-on | Required | native `capslock_color` outline flash, unchanged |
| success (check) | Required | native `check_color` flash before hyprlock exits/session unlocks — no custom success UI |
| loading | N-A | PAM check is local/synchronous enough that no skeleton state applies; native `disable_loading_bar` decorative bar untouched |
| empty | N-A | screen is always fully populated at lock, no first-run/no-data variant |
| partial | N-A | single content source (one background, one panel), nothing to partially fail |
| conflict | N-A | single-user machine, no collaborative edit surface |
| offline | N-A | local auth only, no network dependency |

### Motion shape

**Correction from initial shape pass:** hyprlock *does* have a native `animations` block (`fadeIn`/`fadeOut`/`inputFieldDots`, bezier-curve driven) — the original assumption that it had no configurable transition system was wrong, confirmed by a real `hyprlock` test run against the built config. Built: `animations { enabled = true; bezier = smoothIn, 0.25, 1, 0.5, 1; animation = fadeIn, 1, 4, smoothIn; animation = fadeOut, 1, 3, smoothIn; animation = inputFieldDots, 1, 2, smoothIn }` — reuses the exact `smoothIn` curve values already defined in `hypr/theme.lua` (cross-tool consistency, not a new easing family). Fade-out is faster than fade-in (~75%, "exit faster than enter"). "Motion earns its place" is satisfied by these three purposeful transitions (lock/unlock signal, typing feedback) plus the pre-existing native state-color signals (`fail_color`, `capslock_color`, `check_color`) — no decorative motion added beyond that.

**Typography:** clock — 60px (down from an initial 88px, which read as oversized with no breathing room per user feedback). Single weight (hyprlock has no letter-spacing control, native constraint). Date — 18px (down from an initial 22px). Placeholder/fail text — micro size (~13-14px) via existing pango `<span>`/`<b>`/`<i>` markup, unchanged. One font family (`$font`, currently FiraCode Nerd Font) — no second typeface introduced. Vertical rhythm: 36px panel margin top/bottom, ~14-20px gaps between clock/date/input, recentered as a group so top and bottom panel margins match.

### Acceptance bar

- [x] Single centered `shape` widget (glass panel) hosts clock + date + input-field — no more top-right-floating clock/date and center-floating input as three disconnected elements
- [x] Panel background uses translucent fill matching `GlassCard`'s 0.30-opacity precedent, not opaque — `$glassFill` token added to all three theme `.conf` files as `rgba(RRGGBBAA)` (this ecosystem's actual color syntax — a single hex token, not CSS-style comma decimals; the first attempt used the wrong format and was caught by a real `hyprlock` config-parse error before shipping)
- [x] Panel border/accent color resolves from `active-theme.conf` (`$purple`) — not hardcoded
- [x] Avatar `image` widget removed entirely
- [x] Background wallpaper reused from `WallpaperService` — **not** via hyprlock's own `reload_cmd` (that path has known crash reports, hyprwm/hyprlock#733). Instead `WallpaperService.qml` writes `$lockWallpaper` into a new generated `~/.config/hypr/active-wallpaper.conf` (same pattern as `active-theme.conf`) on every `set()` and at Quickshell startup; `hyprlock.conf` sources it directly. File added to `.stow-local-ignore` and seeded with the current wallpaper.
- [x] `background.blur_passes = 2, blur_size = 7` — **revised from the initial `0`**. Crisp background made the panel structurally incapable of reading as glass (no widget can do a localized blur on this hyprlock version — see the dead-end note above). Fullscreen blur is the accepted tradeoff, matching macOS/GNOME/Windows lock-screen behavior; a pre-baked-composite-image pipeline (crisp everywhere except the panel region) was offered and declined as out of scope.
- [x] `fail_color` / `capslock_color` / `check_color` / `fail_text` / placeholder markup all unchanged and still theme-driven
- [x] Clock/date sized and spaced with real breathing room (60px/18px, 36px panel margins, 14-20px inter-element gaps) — not guessed, verified via real render
- [x] Verified via four real `hyprlock` test runs across two iterations, not guessed — round 1 caught two config errors (`general.disable_loading_bar` doesn't exist on v0.9.6, `$glassFill` rgba format); round 2 (post-feedback: blur + resize) parsed clean; a third attempt at localized blur via a second `image` widget failed with two more real config errors (documented in the dead-end note) and was reverted; final config parses clean with correct `round: 28` on both monitors (2560×1440 + 1920×1080)

**Correction (multi-monitor scope):** identity/auth block (clock, avatar, username, password, status) was `monitor =` blank, duplicating identically on DP-1 (2560×1440) and DP-2 (1920×1080). User asked directly whether this should instead only appear on the primary monitor — answer was yes, and not a close call: two visible password pills for one shared auth buffer is pure redundancy with zero functional gain, the fixed-pixel block rendered as a resized clone on the smaller DP-2 canvas, and it directly violates brief principle 4 ("less is more"). Matches macOS/Windows/GNOME convention of one auth focal point, other displays ambient. **Built:** clock/date/avatar/username/password/status all scoped to `monitor = DP-1`. DP-2 keeps the shared blurred `background` (still `monitor =` blank) plus a new small corner-anchored ambient block — a 32px clock + date, corner-anchored not centered so it doesn't read as "the big clock failed to load here" — and the now-playing/quote status line (`lock-status.sh`) moved from DP-1 to DP-2, giving the secondary screen its own distinct job instead of a shrunk duplicate. Verified via a real `hyprlock -c ... --immediate-render --no-fade-in` test run under a `timeout` guard (auto-killed after 2s, output captured and grepped for error/fail/invalid patterns — none found), then confirmed the session was actually unlocked afterward (`hyprctl activewindow`, `pgrep hyprlock`).

## Surface: sddm-login

### Composition

**Decision:** apply the same DP-1-only scoping to the SDDM greeter (`sddm-theme/rice/Main.qml`) that was just applied to hyprlock — same "one auth focal point, other displays ambient" reasoning, raised by the user in the same question ("our case, DP-1 or whichever's first active"). SDDM instantiates this same `Main.qml` once per connected screen (the same duplicate-everywhere default hyprlock had before the fix), so without scoping, the avatar/username/password block and power controls would render identically on both DP-1 and DP-2.
**Why:** brief principle 4 ("less is more"), consistency with the hyprlock decision above — both are the machine's two auth surfaces and should behave the same way at the monitor boundary rather than one being scoped and the other not.

### New behavior (not just layout)

- Added `readonly property bool isPrimary: Screen.name === "DP-1"` at root (`import QtQuick.Window 2.15` for the `Screen` attached property) — same hardcoded output name convention hyprlock/hypr already use (`monitors.lua`, `rules.lua`), not a portable multi-machine abstraction.
- Avatar/username/password/clock/power-controls block extracted into a `Component { id: primaryContent }`, only instantiated via `Loader { sourceComponent: root.isPrimary ? primaryContent : secondaryContent }` — a real `Loader`, not `visible: false`, so the input fields, focus-chain wiring (`usernamePill`/`passwordPill` `Keys.onReturnPressed` etc.), and `sddm.onLoginFailed` handler don't exist at all on DP-2. Matches hyprlock's "cut entirely" treatment of its DP-1-only widgets, not merely hidden-but-present.
- New `secondaryContent` component: small corner-anchored clock (32px) + date, top-left, 48px margins — same ambient-block pattern as hyprlock's new DP-2 treatment, so both auth surfaces read as one consistent system rather than two different multi-monitor conventions.
- Username/password focus wiring and the `sddm.login()` call moved from root `Component.onCompleted` into `primaryContent`'s own `Component.onCompleted`, since those items no longer exist at the root level.

### Component inventory

| Region | Component | Notes |
|---|---|---|
| backdrop | `Image` + `GaussianBlur` + dim `Rectangle` | unchanged, still root-level, renders on every screen (same role as hyprlock's `background` widget) |
| primary-only | `Component: primaryContent` → avatar, `usernamePill`/`passwordPill` (`InputPill`), `errorText`, hero clock/date, power `IconButton`s | only instantiated when `isPrimary` is true |
| secondary-only | `Component: secondaryContent` → 32px clock + date, corner-anchored | only instantiated when `isPrimary` is false |

### Acceptance bar

- [x] `isPrimary` derived from `Screen.name === "DP-1"`, not a guessed screen index or size heuristic
- [x] Primary-only content built as a `Loader`-gated `Component`, not `visible: false` — confirmed the focus-chain/login wiring lives inside `primaryContent`'s own `Component.onCompleted`, not root's, so it can't run against nonexistent items on DP-2
- [x] DP-2 gets a distinct ambient block (corner clock + date), not a blank screen or a shrunk duplicate
- [x] `qmllint` run against the file post-edit — clean, no warnings or errors
- [x] Brace balance checked (61/61) as a mechanical syntax sanity check alongside `qmllint`
- [x] Verified via `sddm-greeter-qt6 --test-mode --theme <path>` (a normal windowed process, not a real session lock — safe to run directly, unlike hyprlock) plus an isolated `qml`/`grim` render test for the avatar mask specifically. Three real, log-confirmed bugs found and fixed this pass, none guessed:

**Bug 1 — `QtGraphicalEffects` not installed.** The original file's `import QtGraphicalEffects 1.0` (present since before this surface's DP-1 scoping work, not introduced by it) silently failed on this system — `qt6-5compat` was never installed — and SDDM fell back to its embedded default theme every time, meaning the custom theme had likely never actually rendered correctly in production. Confirmed via test-mode log: `module "QtGraphicalEffects" is not installed ... Fallback to embedded theme`. **Fix:** replaced with `QtQuick.Effects`' `MultiEffect` (ships with `qt6-declarative` itself — confirmed present on disk at `/usr/lib/qt6/qml/QtQuick/Effects`, no new package needed). `GaussianBlur` → `MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }`, `OpacityMask` → `MultiEffect { maskEnabled: true; maskSource: ... }`.

**Bug 2 — synchronous XHR blocked by default.** Same Qt6 default-security restriction already known from this project's Quickshell work (see brief/memory on `QML_XHR_ALLOW_FILE_*`). `Component.onCompleted`'s synchronous `xhr.open("GET", "file:///etc/theme-assets/theme.json", false)` threw `Error: Invalid state`. **Fix (not yet applied as of this entry — pending user action):** add `GreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1` under `[General]` in `/etc/sddm.conf.d/theme.conf`, since the greeter runs as the `sddm` system user with its own environment — the shell env used for test-mode doesn't reach the real production greeter.

**Bug 3 (superseded — see Bug 4) — `MultiEffect` mask defaults hid the entire avatar.** Initial fix attempt was `maskThresholdMin: 0.0; maskSpreadAtMin: 1.0`, confirmed visible via one screenshot. This did **not** hold up under further testing — see Bug 4. Left here for the trail, not as guidance.

**Bug 4 (misdiagnosed — see Bug 5) — believed transparency itself didn't composite for this greeter's QML runtime.** After the avatar was reported still broken despite the Bug 3 fix, a series of isolated `qml`/`grim` tests (removing the competing background-blur `MultiEffect`, removing `Column`/`Component`/`Loader` nesting one layer at a time, root `Rectangle` vs `Window`, even a plain `Image` with zero effects showing a pre-cropped genuine-RGBA PNG) all still rendered a plain opaque square. This was wrongly concluded to mean alpha compositing was fundamentally broken for this client, and the avatar was reverted to a plain square with no mask as a result. **This conclusion was wrong** — see Bug 5. The real bug was never checked against this project's own working reference implementation first, which is the actual process failure here: hours of blind trial-and-error instead of five minutes reading `Dashboard.qml`.

**Bug 5 — the real fix: missing `layer.enabled: true`.** Quickshell's `Dashboard.qml` (~line 1747) already has a working `Image` + `Rectangle` mask + `MultiEffect` avatar treatment — same source, same mask pattern — with one difference from every attempt made here: `layer.enabled: true` set explicitly on **both** the source `Image` and the mask `Rectangle`. Without it, `MultiEffect`'s `source`/`maskSource` grab doesn't composite correctly in this greeter's QML runtime (matching every "broken" result above, including the plain-`Image` test — that test never had `layer.enabled` either, so it was never actually evidence of a transparency-level bug). **Fix:** added `layer.enabled: true` to both `avatarImg` and `avatarMask`, restored the live `MultiEffect` mask, matched `visible: avatarImg.status === Image.Ready` guards from the Dashboard version. Confirmed circular, clean edges, no square artifact via the same `qml`+`grim` repro loop.
**Standing rule:** before concluding a QML rendering bug is environmental/unfixable, check this project's other QML surfaces (Quickshell components) for a working reference pattern first — do not blind-iterate for hours on a problem this codebase has already solved elsewhere.

**Dead end, don't re-attempt — `qmlscene` for Qt6 testing:** this system's `/usr/bin/qmlscene` links `libQt5Quick.so.5` — it is Qt5 and cannot load Qt6-only modules like `QtQuick.Effects`, producing a misleading `Library import requires a version` error unrelated to the actual QML. Use `/usr/lib/qt6/bin/qml` for any standalone Qt6 QML render test on this machine — it reproduces sddm-greeter-qt6 rendering bugs directly, no sddm/hyprlock process needed, and is far faster to iterate on.
- [x] `GreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1` applied to `/etc/sddm.conf.d/theme.conf` by the user; theme.json colors confirmed loading.
- [x] `/usr/share/sddm/themes/rice/Main.qml` re-copied by the user via `sudo cp`; user confirmed circular avatar + full greeter "finally working" via real test-mode render.
- [x] `theme-apply.sh` and `~/.local/bin/theme-apply.sh` both updated (user-owned path, no sudo needed) to pre-blur `background.png` via ImageMagick at theme-apply time instead of live QML effect; re-run against the `dracula` theme and confirmed clean exit, new file written.

**DP-2 quote line added** (post-fix follow-up): mirrors hyprlock's DP-2 status line — same `lock-quotes.txt`, mirrored to `/etc/theme-assets/lock-quotes.txt` by `theme-apply.sh` (world-readable, same reasoning as `theme.json`/`background.png`). No now-playing branch (unlike hyprlock's `lock-status.sh`) since nothing plays before login. `root.quote` read via the same synchronous-XHR-in-`Component.onCompleted` pattern already used for `theme.json`, one random line picked per greeter process, bottom-anchored in `secondaryContent` (italic, 14px, 0.85 opacity, word-wrapped). Verified via an isolated `qml` test of just the XHR-read-and-display logic (real quote text rendered correctly) — full end-to-end DP-2 render wasn't re-screenshotted after this addition specifically (repeated attempts to land the floating `qml` test window on DP-2 kept landing on DP-1 or a workspace with other real windows instead; whole-output `grim` captures were tried once each and immediately discarded — they exposed unrelated desktop content, including a browser tab with a deploy-tokens page, so that approach was abandoned rather than repeated). User re-copy + `theme-apply.sh` re-run still needed for this to reach the real greeter.
