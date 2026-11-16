import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud.dart';
import '../../widgets/ios.dart';
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
          appBar: iosLargeAppBar(
            context,
            'Safety',
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: Icon(
                    PhosphorIconsFill.circle,
                    size: 10,
                    color: pal.onWarningContainer,
                  ),
                  label: Text(
                    'Demo mode',
                    style: TextStyle(color: pal.onWarningContainer),
                  ),
                  backgroundColor: pal.warningContainer,
                  side: BorderSide.none,
                ),
              ),
            ],
          ),
          body: MaxWidthContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  color: pal.errorContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: pal.sos,
                              child: const Icon(
                                PhosphorIconsFill.siren,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Emergency SOS',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: pal.sos,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Call a contact when you have service. '
                                    'This demo does not share live location or '
                                    'send messages.',
                                    style: TextStyle(
                                      color: pal.onErrorContainer,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _HoldSosButton(
                          onActivate: () => _sos(context, ref, session, stamp),
                        ),
                      ),
                    ],
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
                    const Expanded(child: SectionHeading('Emergency contacts')),
                    TextButton.icon(
                      onPressed: () => _editContact(context, ref, null),
                      icon: const Icon(PhosphorIconsRegular.plus, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                for (final contact in session.contacts)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 2),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: contact.preferred
                          ? pal.beacon.withValues(alpha: 0.18)
                          : pal.elevated,
                      child: Text(
                        _initials(contact.name),
                        style: TextStyle(
                          color: pal.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(
                      contact.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${contact.preferred ? 'Preferred · ' : ''}${contact.phone}',
                      style: TextStyle(color: pal.muted),
                    ),
                    trailing: IconButton.filledTonal(
                      tooltip: 'Call ${contact.name}',
                      onPressed: () => _callContact(context, contact),
                      icon: const Icon(PhosphorIconsRegular.phoneCall),
                      style: IconButton.styleFrom(
                        backgroundColor: pal.beacon.withValues(alpha: 0.14),
                        foregroundColor: pal.beacon,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                    onTap: () => _contactActions(context, ref, contact),
                  ),
                const SectionHeading('Safety alerts on this route'),
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
                      for (final line in session.catalog.instructions.where(
                        (line) => !line.toLowerCase().contains(
                          'queued sos messages send automatically',
                        ),
                      ))
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
                      SwitchListTile.adaptive(
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
                      SwitchListTile.adaptive(
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
    final pal = context.palette;
    final isHighRisk = alert.severity == 'high';
    final background = isHighRisk ? pal.errorContainer : pal.warningContainer;
    final foreground = isHighRisk
        ? pal.onErrorContainer
        : pal.onWarningContainer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        color: pal.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: pal.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Chip(
                avatar: Icon(
                  PhosphorIconsRegular.warning,
                  color: foreground,
                  size: 18,
                ),
                label: Text(isHighRisk ? 'High risk' : 'Caution'),
                backgroundColor: background,
                side: BorderSide.none,
                labelStyle: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                alert.title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(alert.body, style: TextStyle(color: pal.muted, height: 1.4)),
            ],
          ),
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
                await _callContact(screenContext, contact);
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

  Future<void> _callContact(
    BuildContext context,
    EmergencyContact contact,
  ) async {
    final uri = Uri.parse('tel:${contact.phone.replaceAll(' ', '')}');
    final canCall = await canLaunchUrl(uri);
    final didLaunch = canCall && await launchUrl(uri);
    if (!context.mounted) return;
    if (!didLaunch) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open a call to ${contact.name}.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Phone app opened to call ${contact.name}.')),
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

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

class _HoldSosButton extends StatefulWidget {
  const _HoldSosButton({required this.onActivate});

  final VoidCallback onActivate;

  @override
  State<_HoldSosButton> createState() => _HoldSosButtonState();
}

class _HoldSosButtonState extends State<_HoldSosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  Timer? _holdTimer;
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  void _startHold() {
    _holdTimer?.cancel();
    _activated = false;
    unawaited(HapticFeedback.selectionClick());
    _progress.forward(from: 0);
    _holdTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _activated = true;
      unawaited(HapticFeedback.mediumImpact());
      widget.onActivate();
      _progress.reverse();
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    if (!_activated) _progress.reverse();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Semantics(
      button: true,
      label: 'Emergency SOS',
      hint: 'Press and hold for three seconds to open SOS options.',
      onTap: widget.onActivate,
      child: ExcludeSemantics(
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _startHold(),
          onPointerUp: (_) => _cancelHold(),
          onPointerCancel: (_) => _cancelHold(),
          child: Material(
            color: pal.sos,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, child) => Stack(
                  fit: StackFit.expand,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _progress.value,
                        heightFactor: 1,
                        child: ColoredBox(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                    child!,
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(PhosphorIconsFill.siren, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Press and hold for SOS options',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
