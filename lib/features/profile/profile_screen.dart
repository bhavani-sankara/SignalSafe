import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud.dart';
import '../../widgets/ios.dart';
import '../../widgets/session_gate.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SessionGate(
      builder: (context, session) {
        final pal = context.palette;
        void notify(NotifyPrefs n) => ref
            .read(sessionProvider.notifier)
            .update((s) => s.copyWith(notify: n));
        return Scaffold(
          appBar: iosLargeAppBar(context, 'Profile'),
          body: MaxWidthContent(
            maxWidth: 680,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
              children: [
                // Account card, like the Apple ID row in Settings.
                IosSection(
                  children: [
                    InkWell(
                      onTap: () => _rename(context, ref, session.userName),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [pal.route, const Color(0xFF07463F)],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                session.userName.isEmpty
                                    ? 'S'
                                    : session.userName[0],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 26,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.userName,
                                    style: TextStyle(
                                      color: pal.text,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${session.catalog.userHandle} · Edit name',
                                    style: TextStyle(
                                      color: pal.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Semantics(
                              label: 'Edit name',
                              button: true,
                              child: Icon(
                                PhosphorIconsBold.caretRight,
                                size: 14,
                                color: pal.outline.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                IosSection(
                  header: 'Appearance',
                  dividerIndent: 60,
                  children: [
                    IosSwitchRow(
                      leading: const IosIconTile(
                        icon: PhosphorIconsFill.moon,
                        color: Color(0xFF5856D6),
                      ),
                      title: 'Dark theme',
                      subtitle: 'Use a darker palette for night travel.',
                      value: session.darkMode,
                      onChanged: (value) => ref
                          .read(sessionProvider.notifier)
                          .update((state) => state.copyWith(darkMode: value)),
                    ),
                  ],
                ),
                const SectionLabel('Preferred network'),
                _segments(
                  context,
                  const ['jio', 'airtel', 'vi', 'bsnl'],
                  const ['Jio', 'Airtel', 'Vi', 'BSNL'],
                  session.preferredOperator,
                  (value) => ref
                      .read(sessionProvider.notifier)
                      .update(
                        (s) => s.copyWith(
                          preferredOperator: value,
                          operatorFilter: value,
                        ),
                      ),
                ),
                const SizedBox(height: 16),
                const SectionLabel('Travel mode'),
                _segments(
                  context,
                  const ['car', 'bike', 'transit', 'walk'],
                  const ['Car', 'Bike', 'Transit', 'Walk'],
                  session.travelMode,
                  (value) => ref
                      .read(sessionProvider.notifier)
                      .update((s) => s.copyWith(travelMode: value)),
                ),
                const SizedBox(height: 16),
                const SectionLabel('Route preference'),
                _segments(
                  context,
                  const ['connectivity', 'balanced', 'fastest'],
                  const ['Best signal', 'Balanced', 'Fastest'],
                  session.routePref,
                  (value) => ref
                      .read(sessionProvider.notifier)
                      .update((s) => s.copyWith(routePref: value)),
                ),
                const SizedBox(height: 28),
                IosSection(
                  header: 'Route safety',
                  footer: 'SignalSafe uses these when ranking routes.',
                  dividerIndent: 60,
                  children: [
                    IosSwitchRow(
                      leading: const IosIconTile(
                        icon: PhosphorIconsFill.wifiSlash,
                        color: Color(0xFFFF9500),
                      ),
                      title: 'Avoid long blackspots',
                      subtitle: 'Prefer routes with fewer signal gaps.',
                      value: session.avoidLongBlackspots,
                      onChanged: (value) => ref
                          .read(sessionProvider.notifier)
                          .update(
                            (s) => s.copyWith(avoidLongBlackspots: value),
                          ),
                    ),
                    IosSwitchRow(
                      leading: const IosIconTile(
                        icon: PhosphorIconsFill.firstAid,
                        color: Color(0xFFFF3B30),
                      ),
                      title: 'Stay near services',
                      subtitle: 'Prefer routes with fuel and hospitals.',
                      value: session.stayNearServices,
                      onChanged: (value) => ref
                          .read(sessionProvider.notifier)
                          .update((s) => s.copyWith(stayNearServices: value)),
                    ),
                  ],
                ),
                IosSection(
                  header: 'Saved places',
                  dividerIndent: 60,
                  children: [
                    for (final place in session.catalog.savedPlaces)
                      IosRow(
                        leading: IosIconTile(
                          icon: place['label']!.toLowerCase().startsWith('home')
                              ? PhosphorIconsFill.houseLine
                              : PhosphorIconsFill.mapPin,
                          color:
                              place['label']!.toLowerCase().startsWith('home')
                              ? const Color(0xFF007AFF)
                              : const Color(0xFFFF2D55),
                        ),
                        title: place['label']!.split(' · ').first,
                        value: place['label']!.contains(' · ')
                            ? place['label']!.split(' · ').last
                            : null,
                        chevron: false,
                      ),
                  ],
                ),
                IosSection(
                  header: 'Notifications',
                  footer: 'Choose which route events to hear about.',
                  dividerIndent: 60,
                  children: [
                    IosSwitchRow(
                      leading: const IosIconTile(
                        icon: PhosphorIconsFill.warning,
                        color: Color(0xFFFF9500),
                      ),
                      title: 'Upcoming blackspots',
                      value: session.notify.blackspots,
                      onChanged: (v) =>
                          notify(session.notify.copyWith(blackspots: v)),
                    ),
                    IosSwitchRow(
                      leading: const IosIconTile(
                        icon: PhosphorIconsFill.cellSignalHigh,
                        color: Color(0xFF34C759),
                      ),
                      title: 'Signal lost or restored',
                      value: session.notify.lossRestore,
                      onChanged: (v) =>
                          notify(session.notify.copyWith(lossRestore: v)),
                    ),
                    IosSwitchRow(
                      leading: const IosIconTile(
                        icon: PhosphorIconsFill.wifiHigh,
                        color: Color(0xFF30B0C7),
                      ),
                      title: 'Approaching recovery points',
                      value: session.notify.recovery,
                      onChanged: (v) =>
                          notify(session.notify.copyWith(recovery: v)),
                    ),
                    IosSwitchRow(
                      leading: const IosIconTile(
                        icon: PhosphorIconsFill.shieldChevron,
                        color: Color(0xFFFF3B30),
                      ),
                      title: 'Safety alerts',
                      value: session.notify.safety,
                      onChanged: (v) =>
                          notify(session.notify.copyWith(safety: v)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _segments(
    BuildContext context,
    List<String> values,
    List<String> labels,
    String current,
    ValueChanged<String> onChanged,
  ) {
    final pal = context.palette;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          for (var i = 0; i < values.length; i++)
            ButtonSegment(value: values[i], label: Text(labels[i])),
        ],
        selected: {current},
        onSelectionChanged: (selection) => onChanged(selection.first),
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected) ? pal.text : pal.muted;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? pal.surface
                : pal.elevated;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: pal.elevated, width: 2),
          ),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
        ),
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;
    ref
        .read(sessionProvider.notifier)
        .update((s) => s.copyWith(userName: controller.text.trim()));
  }
}
