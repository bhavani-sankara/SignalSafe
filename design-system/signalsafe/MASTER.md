# Design System Master File

**Project:** SignalSafe
**Updated:** 2026-11-15
**Category:** Travel safety navigation
**Direction:** Reference-led, light-first travel safety UI with a quiet teal signal accent.

---

## Global Rules

Make the selected route and its connectivity story easy to read at a glance. Use light, low-noise map chrome and white surfaces; keep signal levels distinct and SOS a protected red control, never the brand color. The night-drive palette remains an optional theme.

### Default Light Palette

| Role | Hex | Token |
|------|-----|-------|
| Page background | `#F6F8F7` | `ink` |
| Surface | `#FFFFFF` | `surface` |
| Elevated surface | `#EDF3F1` | `elevated` |
| Text | `#1F2926` | `text` |
| Muted | `#59645F` | `muted` |
| Beacon / brand | `#007F70` | `beacon` |
| Route | `#3E7BCC` | `route` |
| Signal good | `#16845B` | `signalGood` |
| Signal moderate | `#A96600` | `signalModerate` |
| Signal weak | `#C55D00` | `signalWeak` |
| Signal none | `#68736F` | `signalNone` |
| SOS | `#B3261E` | `sos` |
| Border | `#CBD4D1` | `border` |

The optional dark theme uses the night-drive palette from the previous design revision.

### Typography

- **UI:** Outfit (geometric wayfinding)
- **Data (km, ETA, dBm):** IBM Plex Sans
- No Inter, no Playfair, no emoji icons

### Spacing

8dp rhythm. Touch targets 48dp. Safe-area padding on every fixed chrome layer.

### Motion

180–280ms for HUD sheets. Respect `disableAnimations` / reduced motion.

### Icons

Phosphor, outline at rest, fill for selected tab. Never emoji.

## Non-map Screens

- Trips: surface saved places first, show a compact route preview, and keep recent searches easy to clear.
- Safety: give SOS a distinct red surface and state demo limitations plainly; never claim live sharing or automatic delivery unless implemented.
- Community: use readable report rows, compact network filters, and a clear report action.
- Profile: use full-width segmented choices for mutually exclusive preferences and preserve the optional dark theme.
- Use explicit labels for signal levels and selected states; never rely on color alone.
- Give route summaries and primary actions stronger hierarchy than supporting metrics.
- Keep actions at least 48dp high, preserve safe areas, and allow long content to scroll clear of fixed navigation.
