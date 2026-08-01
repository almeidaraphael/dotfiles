# Design Brief

## 1. Product purpose

Personal Hyprland desktop shell (Quickshell-based) for a solo Arch Linux dev workstation — moving from a flat, solid-fill, single-theme (Dracula) look to a modern frosted-glass aesthetic with genuine per-theme diversity.

## 2. Primary user

Sole user of the machine, a developer who lives inside this desktop all day (mostly SSH'd in from a work laptop for dev work), switching to Windows only for gaming.

## 3. Principles

Ranked — when two apply to the same decision, the higher one wins.

1. **"A theme is an outfit, not a tint"** — switching theme changes blur, accent, wallpaper, and font together to match a mood, not just recolor one accent var on a fixed Dracula skeleton. *Rules out:* themes as single-variable swaps.
2. **"Transparent, not solid"** — frosted translucency is the default surface treatment everywhere; solid opaque panels are the exception. *Rules out:* "solid is more legible" as a default excuse.
3. **"Motion earns its place"** — animation communicates a state change with intent; nothing ships "just because motion feels nice." *Rules out:* uniform animation-everywhere for its own sake.
4. **"Less is more"** — show as little as possible at any moment; every widget/panel must justify its presence. *Rules out:* one big dashboard showing everything at once.
5. **"Keyboard-oriented, and it shows"** — every action reachable via keyboard, UI visually signals that it is. *Rules out:* "power users will find the shortcuts anyway."

## 4. Success metric for the surface

A theme switch (`theme-apply.sh`) produces a cohesive frosted-glass look — blur, accent, wallpaper reading as one deliberate outfit — that holds up next to Caelestia or DankMaterialShell in a side-by-side glance, with no panel reading as a leftover solid default.

## 5. Out of scope

- Does not support multi-user / multi-account UI
- Does not support touch/mobile layout (desktop only, keyboard-first + mouse)
- Does not include gaming features/overlays

## 6. Learned constraints

_(empty — appended over time as design corrections happen)_

---

## References

Rices the user is drawing inspiration from:

- [Caelestia dots](https://github.com/caelestia-dots/shell) — quickshell, frosted glass, restrained motion
- [HyDE](https://github.com/HyDE-Project/HyDE) — broad Hyprland theming framework
- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) — quickshell, Material-inspired
- [Apple Liquid Glass](https://developer.apple.com/design/human-interface-guidelines/materials) — formal design-system reference (not a component kit — QML can't import it), added 2026-07-07 as the rulebook to check `GlassCard`/`GlassPanel` decisions against
- [Fluent 2 (Microsoft)](https://fluent2.microsoft.design/) — formal design-system reference (not imported — QML can't consume React/Web Components), added 2026-07-07 as the **component-anatomy** rulebook (Liquid Glass covers material/depth; Fluent 2 covers spacing ramp, elevation, and per-component state contracts). Its Acrylic material is also the closest existing precedent to "frosted glass as the everywhere-default surface," unlike Apple's nav-only restriction.

### Liquid Glass rules extracted (2026-07-07)

Checkable against any future glass-material change:

1. **Never stack two glass materials.** Apple: "avoid applying the material to both layers... use fills, transparency, and vibrancy for the top elements instead." Same rule this project independently derived as "no double-background nesting" (see `.ui-craft/spec.md` → Panels cross-cutting rules) — external validation, not a coincidence.
2. **Two variants, never mixed: Regular (adaptive, default-everywhere, always legible) vs. Clear (more transparent, restricted to media-rich backdrops with bold foreground content — not a default).** This project's `GlassPanel` (0.45 opacity) maps to Regular. `GlassCard` was closer to Clear's transparency (0.18) while being used as the general-purpose everywhere-card, not restricted to media-rich contexts — **fixed 2026-07-07, bumped to 0.30** to improve legibility in plain-text contexts (Settings rows, System stats) that aren't "media-rich."
3. **Adaptive real-time tinting/light-dark-flipping based on live content behind each glass element — deliberately NOT adopted.** This project's per-theme static color+wallpaper "outfit" (brief principle 1) is a simpler, curated alternative appropriate for a themed rice shell, not a live-content-sampling OS. Different tradeoff, not a gap to close.
4. **Apple reduced default transparency in a later revision after real legibility complaints** (direct sunlight, low contrast) and added a **user-facing "reduce transparency" toggle** — one of a canonical trio (see #7 below).

### Liquid Glass rules extracted, round 2 — deeper research (2026-07-07)

5. **CRITICAL — direct conflict with principle 1 above, deliberately kept.** Apple's HIG: *"Liquid Glass is best reserved for the navigation layer that floats above content... avoid it for content layers, full-screen backgrounds, scrollable content."* Glass is chrome, reserved for nav/toolbars/floating controls; content stays solid. This project's principle 1 says the opposite — frosted translucency is the *default* surface treatment, including for content (metric cards, calendar, notification items, clipboard rows all use `GlassCard` as the content surface itself, not just floating chrome above it). **Resolution (2026-07-07): principle 1 stands as-is.** This is a personal rice — "more glass" as the default look is the deliberate point, not an oversight. Logged so the tension isn't forgotten, not because it's being fixed.
6. **HIGH, backlog — text-on-glass legibility.** Apple: *"text always remains on solid layers, never directly on glass."* This shell puts text directly on `GlassCard`'s translucent fill everywhere (clock numbers, notification summaries, metric labels) with no solid backing scrim under the text itself — the 0.18→0.30 opacity bump (rule 2 above) helps generally but doesn't address this specific rule. **Not fixed this pass** — real finding, but auditing every text instance across every panel for a solid-backing treatment is bigger than one session. Flagged as backlog, not lost.
7. **HIGH — the accessibility toggle is a trio, not one.** Apple names Reduced Transparency, Reduced Motion, and High Contrast together as the three system settings glass must honor. This project has `ConfigService.reduceMotion` only. **Both Reduced Transparency and High Contrast are missing**, not just transparency as noted in point 4 above.
8. **HIGH, flag for build phase — concentricity is a formula, not hand-picked tokens.** Apple's system computes nested-shape corner radius as *parent radius minus padding* (their "concentric shape" type), specifically to avoid "pinched or flared corners" in nested containers. `TopBar` already hand-discovered this exact relationship (~40px outer / ~20px inner, "same shape family at two scales" — see PanelTabs section of spec.md) but as independently-chosen `Tokens.qml` values, not a computed formula. No QML helper built for this — **when building any surface with `GlassCard`-in-`GlassPanel` nesting, visually check for corner tension** at the actual margin/radius combination in use; retrofit a formula-based helper only if tension is actually observed, not preemptively.
9. **Reinforces the existing no-double-background rule with a technical reason, not just aesthetic.** Apple's rationale: *"glass cannot sample other glass"* — the rendering technique breaks (not just looks muddy) when a glass layer tries to refract/blur another glass layer behind it. Same rule this project already has (see spec.md → Panels cross-cutting rules), now with real grounding for *why* rather than just *that*.
10. **Confirmed fine, no action needed** — Apple's "≤4 compositing layers" performance budget doesn't meaningfully apply here. `GlassCard` doesn't do real-time blur compositing at all (translucency + border = cheap alpha blend, not a blur shader). Only `MediaPanel`'s album-art backdrop and Theme's planned backdrop use actual `MultiEffect` blur, and never simultaneously stacked.
11. **Not adopted, logged for completeness — real-time dynamic shadow opacity** (Apple's shadows increase opacity over text, decrease over solid light backgrounds, with light "bleeding" into shadow based on live backdrop sampling). Requires runtime luminance sampling this project doesn't have infrastructure for; consistent with the already-established choice of border-ring-over-shadow as the depth signal (see round-1 rule 1 above). Different tradeoff, not a gap.
12. **Nice-to-have, unscheduled — Scroll Edge Effects.** Apple dissolves/lifts glass above scrolled content at scroll boundaries to maintain legibility during scroll. Relevant to this shell's scrollable-content-under-fixed-header surfaces (Notification Center's list, Settings' Flickable panes, AppLauncher/ClipboardPanel's ListViews) — none currently have this treatment, content just clips at the `Flickable` boundary. Future polish idea, not a current gap.

### Fluent 2 rules extracted — component anatomy (2026-07-07)

Checkable against any future shared-component change (`components/shared/`):

1. **HIGH, backlog — canonical interactive state set is 5, this project ships 2-3.** Fluent defines Rest / Hover / Pressed / Disabled / Focused as the required state contract for every interactive component. `GlassButton.qml` implements `hovered` + `active` only — no visual `Pressed` (mouse-down) feedback and no `Disabled` treatment at all (any consumer that needs a disabled button today has to hand-roll opacity/mouseArea.enabled locally). `GlassComboBox.qml` has `activeFocus` but the same Pressed/Disabled gap. **Not fixed this pass** — real gap, but a `GlassButton`/`GlassComboBox` state-contract pass touches every call site's expectations; flagged for a dedicated pass, not folded into whatever surface happens to need a disabled button first.
2. **HIGH, backlog — Card anatomy is undefined here; Fluent's is a named slot contract.** Fluent's `Card` composes optional `CardPreview` / `CardHeader` / `CardBody` / `CardFooter` slots so every card in the system lays out title/media/actions the same way. This project's `GlassCard.qml` is a bare `Rectangle` — every consumer (Dashboard's metric cards, Theme's split-cards, Settings rows) invents its own internal `ColumnLayout`/`RowLayout` from scratch, which is exactly the "opinionated, standardized guide" gap the user flagged this session. **Not built this pass** — logged as the most direct candidate for a `.ui-craft/patterns.md` card-anatomy convention (header/body/footer slots layered inside the existing `GlassCard` shell) next time a card-heavy surface ships.
3. **Reinforces no-double-glass with a new specific case: edge-to-edge seams.** Fluent: *"avoid placing multiple pieces of acrylic edge-to-edge — it creates a striping/seam effect,"* distinct from the already-logged stacking case (Apple round-2 rule 9, Liquid-Glass round-1 rule 1). Worth checking on bento-grid surfaces (System, Overview) where adjacent `GlassCard`s sit flush against each other inside a `GlassPanel` — visually confirm no seam artifact when those ship, same treatment as the concentricity check (Liquid Glass round-2 rule 8).
4. **Confirms existing spacing scale, no action.** Fluent's 4px base ramp (with 2/6/10 exceptions for icon-padding alignment) matches this project's `Tokens.qml` spacing scale (4/8/12/16/20/24/32/48) — independent convergence, not a gap.
5. **Not adopted, logged for completeness — Fluent's shadow-ramp elevation system** (key + ambient shadow pairs, luminosity-adjusted per surface color). Same tradeoff already made in favor of border-ring-over-shadow (Liquid Glass round-1 rule 1, round-2 rule 11) — third independent design system converging on "shadows for elevation," still not adopted here, deliberately.
6. **Reinforces the accessibility-trio gap with a concrete precedent.** Windows disables Acrylic under Reduced Transparency, High Contrast, and low-power/Battery-Saver conditions — same trio already flagged missing except `reduceMotion` (Liquid Glass round-2 rule 7). Battery-Saver-triggered disable specifically doesn't apply (this shell runs on a plugged-in desktop), but Reduced Transparency + High Contrast remain the real gap, now corroborated by a second design system.
7. **Direct tension with principle 2, same shape as the Liquid Glass conflict — logged, not resolved.** Fluent: *"for permanent vertical panes, prefer an opaque background over Acrylic; only panes that open on top of content should use in-app Acrylic."* This project's persistent surfaces (Sidebar, standalone panels) use glass by default per principle 2. Same resolution as Liquid Glass round-2 rule 5: principle 2 stands, tension logged for awareness, not treated as a defect.

## Open execution questions (not principles — resolve in `/shape` or `/craft` per-surface)

- Sidebar vs. top bar
- Pill-shaped vs. full-width layout
- Sidebar/pane interaction model
- Tabbed multi-panel dashboard vs. single dense view (principle 4 already leans toward tabbed/focused)
- Wallpaper set still TBD — plans to remix existing + new wallpapers per theme's colors
