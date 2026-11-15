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
          body: MaxWidthContent(
            child: ListView(
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
                      'Demo SOS queued locally; no contact was notified.',
                      style: TextStyle(
                        color: pal.sos,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (session.simulateLoss)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Glass(
                      color: pal.none.withValues(alpha: 0.35),
                      child: const Text(
                        'Mobile data is gone. Calls may fail. This demo keeps the SOS status local; it does not send automatically.',
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: SectionHeading(
                        'Emergency contacts',
                        subtitle: 'People you can reach on this trip.',
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add emergency contact',
                      onPressed: () => _editContact(context, ref, null),
                      icon: const Icon(PhosphorIconsRegular.plus),
                    ),
                  ],
                ),
                for (final contact in session.contacts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Glass(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(PhosphorIconsRegular.user),
                        ),
                        title: Text(contact.name),
                        subtitle: Text(contact.phone),
                        trailing: contact.preferred
                            ? const SignalChip(
                                level: 'good',
                                label: 'Preferred',
                                compact: true,
                              )
                            : const Icon(
                                PhosphorIconsRegular.dotsThree,
                                size: 20,
                              ),
                        onTap: () => _contactActions(context, ref, contact),
                      ),
                    ),
                  ),
                const SectionHeading(
                  'Safety alerts',
                  subtitle: 'Known risks along the selected route.',
                ),
                for (final alert in session.catalog.alerts)
                  _alert(context, alert),
                const SectionHeading(
                  'Offline reference',
                  subtitle:
                      'Demo information only; map tiles are not downloaded.',
                ),
                Glass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last known location',
                        style: TextStyle(color: pal.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.here.latitude.toStringAsFixed(4)}, '
                        '${session.here.longitude.toStringAsFixed(4)} · Gachibowli',
                        style: dataStyle(context),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${session.origin.name} to ${session.destination.name}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      for (final line in session.catalog.instructions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                PhosphorIconsRegular.check,
                                color: pal.beacon,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(line)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SectionHeading(
                  'Emergency services',
                  subtitle: 'Useful stops along the route.',
                ),
                for (final place in session.catalog.places.where(
                  (p) =>
                      p.category == 'hospital' ||
                      p.category == 'police' ||
                      p.category == 'recovery',
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Glass(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(categoryIcon(place.category)),
                        title: Text(place.name),
                        subtitle: Text(place.subtitle),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Glass(
                  padding: EdgeInsets.zero,
                  child: ExpansionTile(
                    leading: const Icon(PhosphorIconsRegular.testTube),
                    title: const Text('Demo scenarios'),
                    subtitle: const Text('Simulated connectivity only'),
                    childrenPadding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Simulate signal loss'),
                        value: session.simulateLoss,
                        onChanged: (v) => ref
                            .read(sessionProvider.notifier)
                            .update(
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
                        onChanged: (v) => ref
                            .read(sessionProvider.notifier)
                            .update((s) => s.copyWith(simulateBlackspot: v)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
            Row(
              children: [
                SignalChip(
                  level: level,
                  label: alert.severity == 'high' ? 'High risk' : 'Caution',
                  compact: true,
                ),
                const SizedBox(width: 8),
                Icon(
                  alert.severity == 'high'
                      ? PhosphorIconsRegular.warning
                      : PhosphorIconsRegular.info,
                  color: context.palette.level(level),
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              alert.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
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
    if (target.isEmpty) {
      final addContact = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add an emergency contact'),
          content: const Text(
            'Add someone to call before using the emergency action.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add contact'),
            ),
          ],
        ),
      );
      if (addContact == true && context.mounted) {
        await _editContact(context, ref, null);
      }
      return;
    }

    final contact = target.first;
    final body =
        'SignalSafe SOS from ${session.userName}. Last location ${session.here.latitude.toStringAsFixed(4)}, ${session.here.longitude.toStringAsFixed(4)} at $stamp. Route ${session.route.name}.';
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency SOS'),
        content: Text(
          session.simulateLoss
              ? 'No signal. This demo will mark an SOS as queued locally; it will not contact anyone automatically.\n\n$body'
              : 'Open your phone app to call ${contact.name} at ${contact.phone}. '
                    'This demo cannot send an SMS or contact multiple people.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.palette.sos),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              session.simulateLoss ? 'Queue demo SOS' : 'Call ${contact.name}',
            ),
          ),
        ],
      ),
    );
    if (send != true) return;
    if (session.simulateLoss) {
      ref
          .read(sessionProvider.notifier)
          .update((s) => s.copyWith(queuedSos: true));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo SOS queued locally; no contact was notified.'),
          ),
        );
      }
      return;
    }
    final uri = Uri.parse('tel:${contact.phone.replaceAll(' ', '')}');
    final canCall = await canLaunchUrl(uri);
    final didLaunch = canCall && await launchUrl(uri);
    if (!didLaunch) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open a call to ${contact.name}.')),
        );
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone app opened to call ${contact.name}.')),
      );
    }
  }

  Future<void> _contactActions(
    BuildContext context,
    WidgetRef ref,
    EmergencyContact contact,
  ) async {
    final screenContext = context;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(PhosphorIconsRegular.phoneCall),
              title: const Text('Call contact'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final uri = Uri.parse(
                  'tel:${contact.phone.replaceAll(' ', '')}',
                );
                final canCall = await canLaunchUrl(uri);
                final didLaunch = canCall && await launchUrl(uri);
                if (!didLaunch && screenContext.mounted) {
                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Could not open a call to ${contact.name}.',
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(
                contact.preferred
                    ? PhosphorIconsFill.star
                    : PhosphorIconsRegular.star,
              ),
              title: Text(
                contact.preferred ? 'Preferred contact' : 'Make preferred',
              ),
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
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.pencilSimple),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editContact(screenContext, ref, contact);
              },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.trash),
              title: const Text('Remove'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirmed = await showDialog<bool>(
                  context: screenContext,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Remove emergency contact?'),
                    content: Text('${contact.name} will be removed.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Keep contact'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  ref
                      .read(sessionProvider.notifier)
                      .update(
                        (s) => s.copyWith(
                          contacts: s.contacts
                              .where((item) => item.id != contact.id)
                              .toList(),
                        ),
                      );
                }
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
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add contact' : 'Edit contact'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a contact name.'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a phone number.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) {
      name.dispose();
      phone.dispose();
      return;
    }
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
    name.dispose();
    phone.dispose();
  }
}
