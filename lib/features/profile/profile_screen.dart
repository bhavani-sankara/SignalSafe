import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
        final pal = context.palette;
        final initials = session.userName.isEmpty
            ? 'S'
            : session.userName
                .trim()
                .split(RegExp(r'\s+'))
                .take(2)
                .map((w) => w[0].toUpperCase())
                .join();

        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: MaxWidthContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
              children: [
                // ── Profile header ───────────────────────────────────
                _ProfileHeader(
                  initials: initials,
                  name: session.userName,
                  handle: session.catalog.userHandle,
                  onEdit: () => _rename(context, ref, session.userName),
                ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.04, end: 0),

                const SectionHeading('Appearance'),

                Glass(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: pal.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(PhosphorIconsRegular.moon,
                          color: pal.beacon, size: 18),
                    ),
                    title: const Text('Dark theme',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Easier on the eyes at night.',
                        style: TextStyle(color: pal.muted, fontSize: 13)),
                    value: session.darkMode,
                    onChanged: (v) => ref
                        .read(sessionProvider.notifier)
                        .update((s) => s.copyWith(darkMode: v)),
                  ),
                ).animate(delay: 60.ms).fadeIn(duration: 300.ms),

                const SectionHeading('Travel preferences'),

                Glass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionLabel('Preferred network'),
                      _segments(
                        context,
                        const ['jio', 'airtel', 'vi', 'bsnl'],
                        const ['Jio', 'Airtel', 'Vi', 'BSNL'],
                        session.preferredOperator,
                        (v) => ref.read(sessionProvider.notifier).update(
                              (s) => s.copyWith(
                                  preferredOperator: v, operatorFilter: v),
                            ),
                      ),
                      const SizedBox(height: 20),
                      SectionLabel('Travel mode'),
                      _segments(
                        context,
                        const ['car', 'bike', 'transit', 'walk'],
                        const ['Car', 'Bike', 'Transit', 'Walk'],
                        session.travelMode,
                        (v) => ref
                            .read(sessionProvider.notifier)
                            .update((s) => s.copyWith(travelMode: v)),
                      ),
                      const SizedBox(height: 20),
                      SectionLabel('Route preference'),
                      _segments(
                        context,
                        const ['connectivity', 'balanced', 'fastest'],
                        const ['Best signal', 'Balanced', 'Fastest'],
                        session.routePref,
                        (v) => ref
                            .read(sessionProvider.notifier)
                            .update((s) => s.copyWith(routePref: v)),
                      ),
                    ],
                  ),
                ).animate(delay: 80.ms).fadeIn(duration: 300.ms),

                const SectionHeading('Safety'),

                Glass(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _switchTile(
                        context,
                        ref,
                        icon: PhosphorIconsRegular.warning,
                        title: 'Avoid long blackspots',
                        subtitle: 'Prefer routes with fewer signal gaps.',
                        value: session.avoidLongBlackspots,
                        next: (v) => session.copyWith(avoidLongBlackspots: v),
                      ),
                      Divider(height: 1, color: pal.border),
                      _switchTile(
                        context,
                        ref,
                        icon: PhosphorIconsRegular.firstAid,
                        title: 'Stay near services',
                        subtitle: 'Prefer routes with fuel and hospitals.',
                        value: session.stayNearServices,
                        next: (v) => session.copyWith(stayNearServices: v),
                      ),
                    ],
                  ),
                ).animate(delay: 100.ms).fadeIn(duration: 300.ms),

                const SectionHeading('Notifications'),

                Glass(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _notifyTile(context, ref, 'Upcoming blackspots',
                          session.notify.blackspots,
                          (v) => session.notify.copyWith(blackspots: v)),
                      Divider(height: 1, color: pal.border),
                      _notifyTile(context, ref, 'Signal lost or restored',
                          session.notify.lossRestore,
                          (v) => session.notify.copyWith(lossRestore: v)),
                      Divider(height: 1, color: pal.border),
                      _notifyTile(context, ref, 'Approaching recovery points',
                          session.notify.recovery,
                          (v) => session.notify.copyWith(recovery: v)),
                      Divider(height: 1, color: pal.border),
                      _notifyTile(context, ref, 'Safety alerts',
                          session.notify.safety,
                          (v) => session.notify.copyWith(safety: v)),
                    ],
                  ),
                ).animate(delay: 120.ms).fadeIn(duration: 300.ms),

                const SectionHeading('Saved places'),

                for (final place in session.catalog.savedPlaces)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Glass(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: pal.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(PhosphorIconsRegular.mapPinLine,
                              color: pal.beacon, size: 18),
                        ),
                        title: Text(
                          place['label']!.split(' · ').first,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: place['label']!.contains(' · ')
                            ? Text(
                                place['label']!.split(' · ').last,
                                style: TextStyle(
                                    color: pal.muted, fontSize: 13),
                              )
                            : null,
                      ),
                    ),
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
            ButtonSegment(
                value: values[i],
                label: Text(labels[i],
                    style: const TextStyle(fontSize: 13))),
        ],
        selected: {current},
        onSelectionChanged: (s) => onChanged(s.first),
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? pal.onSecondaryContainer
                  : pal.muted),
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? pal.secondaryContainer
                  : pal.surface),
          side: WidgetStatePropertyAll(BorderSide(color: pal.border)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10))),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _switchTile(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Session Function(bool) next,
  }) {
    final pal = context.palette;
    return SwitchListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: pal.elevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: pal.muted, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle:
          Text(subtitle, style: TextStyle(color: pal.muted, fontSize: 13)),
      value: value,
      onChanged: (v) => ref
          .read(sessionProvider.notifier)
          .update((_) => next(v)),
    );
  }

  Widget _notifyTile(
    BuildContext context,
    WidgetRef ref,
    String title,
    bool value,
    NotifyPrefs Function(bool) next,
  ) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      value: value,
      onChanged: (v) => ref
          .read(sessionProvider.notifier)
          .update((s) => s.copyWith(notify: next(v))),
    );
  }

  Future<void> _rename(
      BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter your name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;
    ref
        .read(sessionProvider.notifier)
        .update((s) => s.copyWith(userName: controller.text.trim()));
  }
}

// ---------------------------------------------------------------------------
// Profile header
// ---------------------------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.initials,
    required this.name,
    required this.handle,
    required this.onEdit,
  });

  final String initials;
  final String name;
  final String handle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [
                    pal.elevated,
                    pal.primaryContainer.withValues(alpha: 0.5),
                  ]
                : [
                    pal.secondaryContainer.withValues(alpha: 0.5),
                    pal.surface,
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: pal.border),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    pal.beacon,
                    pal.beacon.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: pal.beacon.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(handle,
                      style: TextStyle(color: pal.muted, fontSize: 13)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit name',
              onPressed: onEdit,
              icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: pal.surface,
                foregroundColor: pal.muted,
                minimumSize: const Size(44, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
