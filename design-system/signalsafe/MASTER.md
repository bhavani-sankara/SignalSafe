# Design System Master File

**Project:** SignalSafe
**Generated:** 2026-11-09
**Category:** Travel safety navigation
**Override note:** Palette and type are product-specific (night-highway instrument), not the generic booking-blue defaults.

---

## Global Rules

Treat the map as the product. Chrome floats like a night-drive HUD. Connectivity is the distinctive layer (route ribbon). SOS is a protected red control, never the brand color.

### Color Palette

| Role | Hex | Token |
|------|-----|-------|
| Ink background | `#0B1118` | `ink` |
| Surface | `#151C26` | `surface` |
| Elevated glass | `#1C2633` | `elevated` |
| Text | `#E7EEF6` | `text` |
| Muted | `#8B9AAB` | `muted` |
| Beacon / brand | `#2FD3C5` | `beacon` |
| Route | `#6BA8FF` | `route` |
| Signal good | `#2FD3C5` | `signalGood` |
| Signal moderate | `#E0B04A` | `signalModerate` |
| Signal weak | `#E07A3A` | `signalWeak` |
| Signal none | `#4A5563` | `signalNone` |
| SOS | `#E11D2E` | `sos` |
| Border | `#2A3544` | `border` |

Light theme inverts ink/surface to `#F4F7FB` / `#FFFFFF` while keeping beacon, route, and SOS.

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
