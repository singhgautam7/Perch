# Perch — app icon

**Final variant:** A (`variants/perch_a.svg`)

## Construction
- Grid: 108 × 108 dp adaptive canvas, 72 dp visible viewport, 66 dp safe zone.
- Stroke: **9 dp on 108 dp = 0.0833 of the canvas** (42.7 px on the 512 px Play icon). Round caps, round joins. Same for every icon in the family.
- Glyph: Two face-on chain links, stacked vertically. The top link is dark, the bottom link mid. They genuinely interlock: the mid link crosses over the dark one on the left, and the dark link is redrawn over the mid one on the right (clipped redraw, so there is no seam).
- Accent: None. The interlock is the detail.
- Glyph box: 35.0 × 55.0 dp. Furthest ink from centre: 27.8 dp (safe-zone limit 33 dp). Ink coverage: 11.9% of the canvas.
- Draw order: dark stroke(s) first, mid stroke(s) on top. No gradients, shadows or outlines.

## Colours
| Role | Value |
|---|---|
| Dark (base stroke) | #4C2979 |
| Mid (overlapping stroke) | #8B5DCE |
| Background (pale tint) | #EAE1FE |
| Splash background, light | #EAE1FE |
| Splash background, dark | #1D1728 |
| Splash glyph, dark mode (base / top) | #9769DC / #D2BFF8 |

OKLCH hue: 300.

## Files
- `ic_launcher_foreground.svg` — glyph, 108 dp, transparent
- `ic_launcher_background.svg` — solid pale tint, 108 dp
- `ic_launcher_monochrome.svg` — single-colour glyph for Android 13+ themed icons (system tints it)
- `ic_launcher_preview.svg` — composited 72 dp viewport, for previews only
- `splash_icon.svg` / `splash_icon_night.svg` — 288 dp canvas; glyph sits inside the 192 dp circle (max radius 74.1 dp of 96)
- `play_store_512.png` (+ `play_store_source.svg`) — full 108 dp canvas at 512 px, same framing as the existing Kuber / PostPurush / Unfurl Play icons
- `ic_stat_notification.svg` / `ic_stat_notification_96.png` — white silhouette, 24 dp, glyph scaled to 0.4 (stroke 3.6 dp)
- `variants/` — variant sources

To import: Android Studio → New → Vector Asset for each SVG, then reference them from `mipmap-anydpi-v26/ic_launcher.xml` (`<foreground>`, `<background>`, `<monochrome>`).

## Variants
- **A** — Vertical interlock. Final. (35.0×55.0 dp, ink 11.9%)
