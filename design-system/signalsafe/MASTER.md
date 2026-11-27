# Design System Master File

**Project:** SignalSafe
**Updated:** 2026-11-15
**Category:** Travel safety navigation
**Direction:** Material 3, light-first, with Google Maps-inspired clarity and SignalSafe teal.

## Global Rules

- Keep route connectivity information easy to scan and keep the interface content-first.
- Use Material 3 surfaces and controls, restrained elevation on floating elements, and 16dp screen margins.
- Use sentence case, Roboto, and the Material type scale. Do not fetch fonts at runtime.
- The default is light; the Profile screen provides a dark-theme switch.
- Keep signal quality distinct from SOS: teal is the brand, green/amber/red convey signal or risk.
- Preserve the existing OpenStreetMap tile provider and tile styling. UI iterations may update route and marker overlays, not the tile source.

## Light Theme Roles

| Role | Hex |
|---|---|
| Primary | `#00796B` |
| On primary | `#FFFFFF` |
| Primary container | `#B2EBE2` |
| Secondary container | `#CDE8E3` |
| Surface / background | `#F8FAF9` |
| Navigation surface | `#EBF0EE` |
| Highest surface container | `#E4E9E7` |
| On surface | `#191C1B` |
| On-surface variant | `#404947` |
| Outline | `#6F7977` |
| Outline variant | `#C0C9C6` |
| Error | `#B3261E` |
| Error container | `#F9DEDC` |
| Warning container | `#FFE7B3` |
| Success container | `#C9F0D5` |

The matching dark roles are defined alongside the light roles in `lib/theme/app_theme.dart`.

## Components and Interaction

- Use Material 3 navigation for the five persistent destinations: `NavigationBar` on compact widths and `NavigationRail` on expanded widths.
- Keep minimum touch targets at 48dp. Label icon-only actions with tooltips/semantics.
- Use outlined list rows and cards for supporting content, with inset dividers where appropriate; reserve elevation for floating controls.
- Signal quality must include both a signal-bars icon and a text label. Risk severity must include an icon and label.
- Keep the SOS action red and explicit about its demo behavior. Pair its foreground with the theme's `onError` role. A three-second hold opens confirmation/options; it does not send an SOS or share live location.
- Describe saved trips as an offline plan, not an offline map download. OSM tiles still require a network connection.

## Screen Guidance

- **Map:** Keep the full-bleed OSM map and existing interactions. Use light route chrome, a white route casing, amber low-signal segments and blackspot areas, accessible 48dp map controls with descriptive semantics, and keep controls clear of route filters.
- **Trips:** Lead with saved-place shortcuts and one route preview card. Show route-specific low/no-signal time on saved journeys and keep recent searches easy to clear.
- **Safety:** Make the demo status visible, keep the surrounding SOS surface neutral so red stays reserved for the action, protect SOS from accidental activation, and keep contacts and route alerts scannable.
- **Community:** Use network filter chips, flat report rows with inset dividers, agreement/status information, and one extended report action.
- **Profile:** Keep appearance controls prominent, use segmented choices for exclusive preferences, and independent switches for safety preferences.
- **Active navigation:** Keep turn guidance prominent in a compact teal banner, preserve an open OSM map as the main canvas, and dock route progress and essential drive/voice actions below it. Consolidate blackspot and recovery details at phone widths; reserve the full coverage breakdown for expanded layouts or the route-details sheet.

## Quality Bar

- Respect system text scaling, safe areas, dark mode, and reduced motion where supported.
- Keep copy concise, truthful, and action-oriented; avoid implying live coverage, emergency delivery, or downloaded maps when those features are not implemented.

## Motion (Maps-style redesign)

All timings live in `lib/theme/motion.dart`; respect reduced motion (`Motion.reduced`).

- **Sheets:** `SpringSheet` has peek / half / full detents and settles with a critically damped spring (~420 stiffness, no bounce) that keeps the fling velocity. At full height the floating search chrome slides up and fades, and the sheet header becomes the top bar.
- **Modals:** `showStagedSheet` fades the scrim in first (to ~40% black), then glides the sheet up. Every modal sheet has a round close button.
- **Directions:** stage the reveal. Skeletons first, then the camera fits the routes (~650 ms), the routes draw in, and the time/signal bubbles pop in last.
- **One filled action per surface.** Secondary actions are tonal pills (the `OutlinedButton` theme is tonal and borderless).
- **Navigation:** night-navy theme, perspective tilt and camera dive on entry, coverage warning under the turn card, Re-center after panning.
- **Loading:** shimmer skeletons, never a bare spinner. Tabs cross-fade in ~200 ms.
