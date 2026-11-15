# SignalSafe Progress

**Reviewed:** 2026-11-15

## Planning documents reviewed

- `README.md` contains the default Flutter starter-project guidance; it has no implementation plan.
- `design-system/signalsafe/MASTER.md` defines visual and interaction rules, but has no milestones, task list, or acceptance criteria.

No implementation roadmap or plan-specific backlog was found, so there were no defined remaining tasks to execute.

## Current implementation

The app has a working Flutter demo covering:

- A map with route connectivity overlays, route selection, points of interest, and community reports.
- Route comparison, trip details, pre-trip reporting, and simulated turn-by-turn navigation.
- Safety contacts, emergency-message confirmation, and an in-app queued SOS state during simulated signal loss.
- Community reporting, profile preferences, and light/dark themes.

The interface uses Phosphor icons, touch-sized controls, map HUD components, and a distinct red SOS treatment. The design system and typography were updated again in the Material 3 iteration below.

## Design review

Reviewed the main app screens in a browser at phone and desktop sizes. The existing night-drive style remains intact, with these focused improvements:

- Constrained text-heavy screens and desktop map/navigation HUDs to keep content readable on wide displays.
- Kept the map route summary in sync with the selected route, reduced marker visuals while retaining 48dp hit areas, and clarified marker semantics.
- Removed duplicate presentation of journeys that are both saved and prepared offline.
- Removed a repeated Community heading and moved its report action out of the feed overlay on mobile.

OpenStreetMap tiles loaded during some checks but failed to load reliably during the final browser pass; the map therefore depends on network tile availability.

### Non-map UI/UX pass

The follow-up audit focused on making the non-map flows easier to scan and act on without changing the map canvas:

- Added consistent section headings, clearer content grouping, stronger route summaries, and more contextual Phosphor icons across Trips, Compare, Profile, Community, Safety, Search, and pre-trip reporting.
- Clarified selected and ranked route states, labelled signal distribution bars, and added network filters and empty-state guidance to Community and Search.
- Improved navigation HUD scrolling and anchored its controls; this changes the overlay layout, not the map visuals.
- Reworked Safety contact and alert sections, validated contact input, added removal confirmation, and clarified that queued SOS behavior is simulated.
- Replaced nonfunctional report checkboxes with static reminders, kept primary actions reachable, and clarified that offline-ready behavior does not download map tiles.

Browser review covered Safety, Compare, Report, Community, Profile, Search, and Navigation. The refreshed layouts remained readable at the reviewed viewport; long forms and lists continue vertically, with persistent actions available where needed.

### Reference-led visual refresh

The supplied light mobile references now guide the default appearance:

- Set the default theme to a pale neutral canvas, white surfaces, dark readable text, teal selection, distinct signal colors, and a restrained red SOS treatment. The night-drive theme remains optional.
- Reworked the Map route selector, category chips, signal strip, and journey action sheet while retaining OSM tiles and existing route/map interactions.
- Made the route summary's weak/no-signal estimate follow the selected route and operator rather than a fixed blackspot duration and recovery point.
- Added illustrated route previews and saved-place shortcuts on Trips, redesigned Safety contacts/alerts around the honest demo state, simplified Community into report rows with a floating action, and changed Profile preferences to segmented controls.
- Kept a visible warning that map downloads, live-location sharing, and automatic SOS delivery are not available in this demo.

Browser review covered the Map, Trips, Safety, Community, and Profile references. The route preview, light palette, and section layouts rendered as intended; longer pages remain scrollable.

### Material 3 iteration

The latest pass aligns the app with the supplied Material 3 / Google Maps-style reference while retaining the existing features, five tabs, and OpenStreetMap tile source:

- Centralized light and dark Material 3 color roles, switched UI typography to Roboto, and removed runtime Google Fonts configuration.
- Added a prominent Dark theme switch in Profile and changed route-safety settings to independent switches for avoiding long blackspots and staying near services.
- Refined shared surfaces, navigation, chips, segmented choices, route previews, contact rows, alert cards, and Community report rows.
- Updated Map route/callout/control chrome only; the OSM tile provider remains unchanged.
- Added a cancellable three-second SOS hold with progress and haptic feedback. Completion opens the existing demo-safe options; screen-reader activation also opens those options. No SMS or live location is sent.
- Kept saved-trip messaging honest: “Offline plan · demo” does not claim that map tiles have been downloaded.

Browser review covered Map, Trips, Safety, Community, and Profile at a phone-sized viewport. The OSM tiles were unavailable during this preview, so visual review of tile rendering was limited to the route and marker overlays. The Trips metadata now uses plain-language “to” wording for compatibility with the Flutter web font fallback.

### Active navigation reference pass

The active-navigation screen was reshaped around the supplied navigation reference:

- Added a prominent teal next-turn banner with a concise “Then” instruction.
- Made the route map the primary canvas, with an estimated signal summary, upcoming blackspot/recovery details, and floating speed, zoom, and full-route controls.
- Replaced the previous navigation footer with a docked route summary and persistent Drive/Pause, voice, and additional-options actions.
- Preserved route progress, voice guidance, route-change demo, signal simulation, and the OpenStreetMap tile source.
- Made End navigation return to the prior screen or fall back to Map when navigation is opened directly.
- Added a focused portrait widget test for navigation guidance, expanded connectivity details, and Drive/Pause interaction.

The refreshed screen rendered in the phone-sized browser preview after reloading the running Flutter web app. A landscape browser resize showed a blank preview, and a landscape widget-test attempt stalled in the test harness; landscape rendering remains unverified.

## Verification

- `flutter analyze` — passed with no issues after the active-navigation pass.
- `flutter test` — passed (7 tests), including navigation, held-SOS confirmation, and Profile theme/preference controls.
- `git diff --check` — passed after formatting the navigation files.

## Remaining gaps

These are observations, not tasks from an existing plan:

- The optional dark theme has not had a fresh device-level contrast review; browser review covered the light theme.
- No explicit reduced-motion preference handling was found in the app code.
- The project is currently a demo: connectivity and reports use mock data, signal loss is simulated, and SOS handling does not send an SMS or notify multiple contacts. Map tiles come from the network, so offline map downloads are not implemented.
- `README.md` still describes a generic Flutter starter rather than SignalSafe.
- The browser review did not validate real-device assistive technology or physical touch behavior.

## Outcome

No plan-defined feature work was left to continue. The gaps above are recorded for prioritization rather than treated as approved requirements. This report does not imply the demo is production-ready for real-world emergency use.
