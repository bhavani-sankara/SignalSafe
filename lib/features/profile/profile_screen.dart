import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud.dart';
import '../../widgets/session_gate.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SessionGate(
      builder: (context, session) {
        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: MaxWidthContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: context.palette.beacon,
                      child: Text(
                        session.userName.isEmpty ? 'S' : session.userName[0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.userName,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            session.catalog.userHandle,
                            style: TextStyle(color: context.palette.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Edit name',
                      onPressed: () => _rename(context, ref, session.userName),
                      icon: const Icon(PhosphorIconsRegular.pencilSimple),
                      style: IconButton.styleFrom(
                        backgroundColor: context.palette.beacon.withValues(
                          alpha: 0.14,
                        ),
                        foregroundColor: context.palette.beacon,
                        minimumSize: const Size(52, 52),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const SectionHeading('Appearance'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(PhosphorIconsRegular.moon),
                  title: const Text('Dark theme'),
                  subtitle: const Text(
                    'Use a darker palette for night travel.',
                  ),
                  value: session.darkMode,
                  onChanged: (value) => ref
                      .read(sessionProvider.notifier)
                      .update((state) => state.copyWith(darkMode: value)),
                ),
                const SizedBox(height: 24),
                const SectionHeading(
                  'Travel preferences',
                  subtitle: 'Set how SignalSafe plans your journey.',
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
                const SizedBox(height: 16),
                const SectionLabel('Safety'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Avoid long blackspots'),
                  subtitle: const Text('Prefer routes with fewer signal gaps.'),
                  value: session.avoidLongBlackspots,
                  onChanged: (value) => ref
                      .read(sessionProvider.notifier)
                      .update((s) => s.copyWith(avoidLongBlackspots: value)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Stay near services'),
                  subtitle: const Text(
                    'Prefer routes with fuel and hospitals.',
                  ),
                  value: session.stayNearServices,
                  onChanged: (value) => ref
                      .read(sessionProvider.notifier)
                      .update((s) => s.copyWith(stayNearServices: value)),
                ),
                const SizedBox(height: 28),
                const SectionHeading('Saved places'),
                for (final place in session.catalog.savedPlaces)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: context.palette.elevated,
                      child: Icon(
                        PhosphorIconsRegular.mapPinLine,
                        color: context.palette.text,
                      ),
                    ),
                    title: Text(
                      place['label']!.split(' · ').first,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: place['label']!.contains(' · ')
                        ? Text(place['label']!.split(' · ').last)
                        : null,
                  ),
                const SizedBox(height: 16),
                const SectionHeading(
                  'Notifications',
                  subtitle: 'Choose which route events to hear about.',
                ),
                _switch(
                  context,
                  ref,
                  'Upcoming blackspots',
                  session.notify.blackspots,
                  (v) => session.notify.copyWith(blackspots: v),
                ),
                _switch(
                  context,
                  ref,
                  'Signal lost or restored',
                  session.notify.lossRestore,
                  (v) => session.notify.copyWith(lossRestore: v),
                ),
                _switch(
                  context,
                  ref,
                  'Approaching recovery points',
                  session.notify.recovery,
                  (v) => session.notify.copyWith(recovery: v),
                ),
                _switch(
                  context,
                  ref,
                  'Safety alerts',
                  session.notify.safety,
                  (v) => session.notify.copyWith(safety: v),
                ),
                const SizedBox(height: 12),
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
        showSelectedIcon: true,
        segments: [
          for (var i = 0; i < values.length; i++)
            ButtonSegment(value: values[i], label: Text(labels[i])),
        ],
        selected: {current},
        onSelectionChanged: (selection) => onChanged(selection.first),
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? pal.onPrimaryContainer
                : pal.muted;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? pal.primaryContainer
                : pal.surface;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: pal.border)),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
        ),
      ),
    );
  }

  Widget _switch(
    BuildContext context,
    WidgetRef ref,
    String title,
    bool value,
    NotifyPrefs Function(bool) next,
  ) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: (v) => ref
          .read(sessionProvider.notifier)
          .update((s) => s.copyWith(notify: next(v))),
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
