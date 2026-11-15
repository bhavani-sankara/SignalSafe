import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: context.palette.beacon,
                    child: Text(
                      session.userName.isEmpty ? 'S' : session.userName[0],
                      style: const TextStyle(
                        color: Color(0xFF06201C),
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.userName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          session.catalog.userHandle,
                          style: TextStyle(color: context.palette.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit name',
                    onPressed: () => _rename(context, ref, session.userName),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionLabel('Preferred network'),
              Wrap(
                spacing: 8,
                children: [
                  for (final op in const ['jio', 'airtel', 'vi', 'bsnl'])
                    ChoiceChip(
                      label: Text(operatorLabel(op)),
                      selected: session.preferredOperator == op,
                      onSelected: (_) => ref.read(sessionProvider.notifier).update(
                            (s) => s.copyWith(
                              preferredOperator: op,
                              operatorFilter: op,
                            ),
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const SectionLabel('Travel mode'),
              _choice(
                context,
                const ['car', 'bike', 'transit', 'walk'],
                const ['Car', 'Bike', 'Transit', 'Walk'],
                session.travelMode,
                (v) => ref.read(sessionProvider.notifier).update(
                      (s) => s.copyWith(travelMode: v),
                    ),
              ),
              const SectionLabel('Route preference'),
              _choice(
                context,
                const ['connectivity', 'fastest', 'balanced'],
                const ['Best signal', 'Fastest', 'Balanced'],
                session.routePref,
                (v) => ref.read(sessionProvider.notifier).update(
                      (s) => s.copyWith(routePref: v),
                    ),
              ),
              const SectionLabel('Safety preference'),
              _choice(
                context,
                const ['avoidBlackspots', 'nearServices'],
                const ['Avoid long blackspots', 'Stay near services'],
                session.safetyPref,
                (v) => ref.read(sessionProvider.notifier).update(
                      (s) => s.copyWith(safetyPref: v),
                    ),
              ),
              const SectionLabel('Saved places'),
              for (final place in session.catalog.savedPlaces)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(place['label']!),
                ),
              const SectionLabel('Notifications'),
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dark map'),
                value: session.darkMode,
                onChanged: (v) => ref.read(sessionProvider.notifier).update(
                      (s) => s.copyWith(darkMode: v),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _choice(
    BuildContext context,
    List<String> values,
    List<String> labels,
    String current,
    ValueChanged<String> onPick,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < values.length; i++)
            ChoiceChip(
              label: Text(labels[i]),
              selected: current == values[i],
              onSelected: (_) => onPick(values[i]),
            ),
        ],
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
      onChanged: (v) => ref.read(sessionProvider.notifier).update(
            (s) => s.copyWith(notify: next(v)),
          ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;
    ref.read(sessionProvider.notifier).update(
          (s) => s.copyWith(userName: controller.text.trim()),
        );
  }
}
