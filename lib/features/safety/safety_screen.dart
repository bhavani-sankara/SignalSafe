import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud.dart';
import '../../widgets/session_gate.dart';

class SafetyScreen extends ConsumerWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SessionGate(
      builder: (context, session) {
        final pal = context.palette;
        final stamp = DateFormat('d MMM, HH:mm').format(DateTime.now());
        return Scaffold(
          appBar: AppBar(title: const Text('Safety')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              SizedBox(
                height: 64,
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: pal.sos,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _sos(context, ref, session, stamp),
                  icon: const Icon(PhosphorIconsFill.siren),
                  label: const Text('Emergency SOS'),
                ),
              ),
              if (session.queuedSos)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'An SOS message is waiting for signal.',
                    style: TextStyle(color: pal.sos, fontWeight: FontWeight.w600),
                  ),
                ),
              if (session.simulateLoss)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Glass(
                    color: pal.none.withValues(alpha: 0.35),
                    child: const Text(
                      'Mobile data is gone. Calls may fail. The queued message sends at the next recovery point.',
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: SectionLabel('Emergency contacts')),
                  IconButton(
                    tooltip: 'Add contact',
                    onPressed: () => _editContact(context, ref, null),
                    icon: const Icon(PhosphorIconsRegular.plus),
                  ),
                ],
              ),
              for (final contact in session.contacts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(contact.name),
                  subtitle: Text(contact.phone),
                  trailing: contact.preferred
                      ? const SignalChip(level: 'good', label: 'Preferred', compact: true)
                      : null,
                  onTap: () => _contactActions(context, ref, contact),
                ),
              const SectionLabel('Safety alerts'),
              for (final alert in session.catalog.alerts) _alert(context, alert),
              const SectionLabel('Offline pack'),
              Text('Last known location', style: TextStyle(color: pal.muted, fontSize: 12)),
              Text(
                '${session.here.latitude.toStringAsFixed(4)}, ${session.here.longitude.toStringAsFixed(4)} · Gachibowli',
                style: dataStyle(context),
              ),
              const SizedBox(height: 8),
              Text(
                '${session.origin.name} → ${session.destination.name}',
              ),
              const SizedBox(height: 8),
              for (final line in session.catalog.instructions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $line'),
                ),
              const SectionLabel('Saved services'),
              for (final place in session.catalog.places.where(
                (p) => p.category == 'hospital' || p.category == 'police' || p.category == 'recovery',
              ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(categoryIcon(place.category)),
                  title: Text(place.name),
                  subtitle: Text(place.subtitle),
                ),
              const SectionLabel('Demo connectivity'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Simulate signal loss'),
                value: session.simulateLoss,
                onChanged: (v) => ref.read(sessionProvider.notifier).update(
                      (s) => s.copyWith(
                        simulateLoss: v,
                        queuedSos: v ? s.queuedSos : false,
                      ),
                    ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Simulate a blackspot'),
                value: session.simulateBlackspot,
                onChanged: (v) => ref.read(sessionProvider.notifier).update(
                      (s) => s.copyWith(simulateBlackspot: v),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _alert(BuildContext context, SafetyAlert alert) {
    final level = alert.severity == 'high' ? 'weak' : 'moderate';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Glass(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SignalChip(level: level, label: alert.severity, compact: true),
            const SizedBox(height: 6),
            Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(alert.body),
          ],
        ),
      ),
    );
  }

  Future<void> _sos(
    BuildContext context,
    WidgetRef ref,
    Session session,
    String stamp,
  ) async {
    final preferred = session.contacts.where((c) => c.preferred).toList();
    final target = preferred.isEmpty ? session.contacts : preferred;
    final body =
        'SignalSafe SOS from ${session.userName}. Last location ${session.here.latitude.toStringAsFixed(4)}, ${session.here.longitude.toStringAsFixed(4)} at $stamp. Route ${session.route.name}.';
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send emergency message'),
        content: Text(
          session.simulateLoss
              ? 'No signal. This message queues until connectivity returns.\n\n$body'
              : 'Notify ${target.map((c) => c.name).join(', ')}.\n\n$body',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.palette.sos),
            onPressed: () => Navigator.pop(context, true),
            child: Text(session.simulateLoss ? 'Queue message' : 'Notify contacts'),
          ),
        ],
      ),
    );
    if (send != true) return;
    if (session.simulateLoss) {
      ref.read(sessionProvider.notifier).update((s) => s.copyWith(queuedSos: true));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS queued until signal returns')),
        );
      }
      return;
    }
    if (target.isNotEmpty) {
      final uri = Uri.parse('tel:${target.first.phone.replaceAll(' ', '')}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message prepared for ${target.map((c) => c.name).join(', ')}')),
      );
    }
  }

  Future<void> _contactActions(
    BuildContext context,
    WidgetRef ref,
    EmergencyContact contact,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Call'),
              onTap: () async {
                Navigator.pop(context);
                final uri = Uri.parse('tel:${contact.phone.replaceAll(' ', '')}');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
            ListTile(
              title: Text(contact.preferred ? 'Preferred contact' : 'Make preferred'),
              onTap: () {
                ref.read(sessionProvider.notifier).update((s) {
                  return s.copyWith(
                    contacts: [
                      for (final item in s.contacts)
                        item.id == contact.id
                            ? item.copyWith(preferred: true)
                            : item.copyWith(preferred: false),
                    ],
                  );
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editContact(context, ref, contact);
              },
            ),
            ListTile(
              title: const Text('Remove'),
              onTap: () {
                ref.read(sessionProvider.notifier).update(
                      (s) => s.copyWith(
                        contacts: s.contacts.where((c) => c.id != contact.id).toList(),
                      ),
                    );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editContact(
    BuildContext context,
    WidgetRef ref,
    EmergencyContact? existing,
  ) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add contact' : 'Edit contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    ref.read(sessionProvider.notifier).update((s) {
      if (existing == null) {
        return s.copyWith(
          contacts: [
            ...s.contacts,
            EmergencyContact(
              id: 'c${DateTime.now().millisecondsSinceEpoch}',
              name: name.text.trim(),
              phone: phone.text.trim(),
              preferred: s.contacts.isEmpty,
            ),
          ],
        );
      }
      return s.copyWith(
        contacts: [
          for (final item in s.contacts)
            if (item.id == existing.id)
              item.copyWith(name: name.text.trim(), phone: phone.text.trim())
            else
              item,
        ],
      );
    });
  }
}
