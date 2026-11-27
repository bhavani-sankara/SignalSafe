import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
          appBar: AppBar(
            title: const Text('Safety'),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: pal.warningContainer,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: pal.onWarningContainer,
                        shape: BoxShape.circle,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .fadeIn(duration: 700.ms)
                        .then()
                        .fadeOut(duration: 700.ms),
                    const SizedBox(width: 6),
                    Text(
                      'Demo mode',
                      style: TextStyle(
                        color: pal.onWarningContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: MaxWidthContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
              children: [
                // ── SOS card ────────────────────────────────────────────
                _SosCard(
                  session: session,
                  onActivate: () => _sos(context, ref, session, stamp),
                ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),

                // ── Queued SOS notice ──────────────────────────────────
                if (session.queuedSos)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: pal.errorContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(PhosphorIconsRegular.warning,
                              color: pal.onErrorContainer, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Demo SOS queued locally — no contact was notified.',
                              style: TextStyle(
                                color: pal.onErrorContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms),

                if (session.simulateLoss)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: pal.elevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: pal.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(PhosphorIconsRegular.wifiSlash,
                              color: pal.muted, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Mobile data is gone. Calls may fail. This demo keeps the SOS local — it does not send automatically.',
                              style: TextStyle(color: pal.text, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms),

                // ── Emergency contacts ─────────────────────────────────
                Row(
                  children: [
                    const Expanded(
                        child: SectionHeading('Emergency contacts')),
                    TextButton.icon(
                      onPressed: () => _editContact(context, ref, null),
                      icon: const Icon(PhosphorIconsRegular.plus, size: 16),
                      label: const Text('Add'),
                    ),
                  ],
                ),

                if (session.contacts.isEmpty)
                  _emptyContacts(context, ref)
                else
                  for (var i = 0; i < session.contacts.length; i++)
                    _contactCard(context, ref, session, session.contacts[i])
                        .animate(delay: (i * 50).ms)
                        .fadeIn(duration: 280.ms)
                        .slideX(begin: 0.04, end: 0),

                // ── Safety alerts ──────────────────────────────────────
                const SectionHeading('Safety alerts on this route'),
                for (var i = 0; i < session.catalog.alerts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _alertCard(context, session.catalog.alerts[i]),
                  )
                      .animate(delay: (i * 60).ms)
                      .fadeIn(duration: 300.ms),

                // ── Offline reference ──────────────────────────────────
                const SectionHeading(
                  'Offline reference',
                  subtitle:
                      'Demo only — map tiles are not downloaded.',
                ),
                Glass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(
                        context,
                        icon: PhosphorIconsRegular.mapPin,
                        label: 'Last known location',
                        value:
                            '${session.here.latitude.toStringAsFixed(4)}, ${session.here.longitude.toStringAsFixed(4)} · Gachibowli',
                      ),
                      const SizedBox(height: 10),
                      _infoRow(
                        context,
                        icon: PhosphorIconsRegular.path,
                        label: 'Route',
                        value:
                            '${session.origin.name} → ${session.destination.name}',
                      ),
                      const SizedBox(height: 14),
                      for (final line in session.catalog.instructions.where(
                        (l) => !l.toLowerCase().contains('queued sos'),
                      ))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: context.palette.beacon
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(PhosphorIconsRegular.check,
                                    color: context.palette.beacon, size: 11),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(line,
                                      style: TextStyle(
                                          height: 1.4, fontSize: 14))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Emergency services ─────────────────────────────────
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: context.palette.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(categoryIcon(place.category),
                              color: context.palette.beacon, size: 18),
                        ),
                        title: Text(place.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(place.subtitle,
                            style: TextStyle(
                                color: context.palette.muted, fontSize: 13)),
                      ),
                    ),
                  ),

                // ── Demo scenarios ─────────────────────────────────────
                const SectionHeading('Demo scenarios'),
                Glass(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        secondary: Icon(PhosphorIconsRegular.wifiSlash,
                            color: context.palette.muted, size: 20),
                        title: const Text('Simulate signal loss'),
                        subtitle: Text('Triggers offline SOS flow',
                            style:
                                TextStyle(color: context.palette.muted, fontSize: 12)),
                        value: session.simulateLoss,
                        onChanged: (v) =>
                            ref.read(sessionProvider.notifier).update(
                                  (s) => s.copyWith(
                                    simulateLoss: v,
                                    queuedSos: v ? s.queuedSos : false,
                                  ),
                                ),
                      ),
                      Divider(height: 1, color: context.palette.border),
                      SwitchListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        secondary: Icon(PhosphorIconsRegular.warning,
                            color: context.palette.muted, size: 20),
                        title: const Text('Simulate a blackspot'),
                        value: session.simulateBlackspot,
                        onChanged: (v) =>
                            ref.read(sessionProvider.notifier).update(
                                (s) => s.copyWith(simulateBlackspot: v)),
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

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final pal = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: pal.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: pal.muted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyContacts(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    return Glass(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: pal.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(PhosphorIconsRegular.user, color: pal.beacon, size: 22),
          ),
          const SizedBox(height: 12),
          Text('No contacts added',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Add someone to call in an emergency.',
            style: TextStyle(color: pal.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _editContact(context, ref, null),
            icon: const Icon(PhosphorIconsRegular.plus, size: 16),
            label: const Text('Add contact'),
          ),
        ],
      ),
    );
  }

  Widget _contactCard(
    BuildContext context,
    WidgetRef ref,
    Session session,
    EmergencyContact contact,
  ) {
    final pal = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: pal.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: pal.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () => _contactActions(context, ref, contact),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: contact.preferred
                            ? [
                                pal.beacon,
                                pal.beacon.withValues(alpha: 0.7),
                              ]
                            : [
                                pal.elevated,
                                pal.elevated,
                              ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        _initials(contact.name),
                        style: TextStyle(
                          color: contact.preferred ? Colors.white : pal.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              contact.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            if (contact.preferred) ...[
                              const SizedBox(width: 6),
                              Icon(PhosphorIconsFill.star,
                                  size: 13, color: pal.beacon),
                            ],
                          ],
                        ),
                        Text(
                          contact.phone,
                          style:
                              TextStyle(color: pal.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Call ${contact.name}',
                    onPressed: () => _callContact(context, contact),
                    icon: const Icon(PhosphorIconsRegular.phoneCall, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: pal.beacon.withValues(alpha: 0.12),
                      foregroundColor: pal.beacon,
                      minimumSize: const Size(44, 44),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _alertCard(BuildContext context, SafetyAlert alert) {
    final pal = context.palette;
    final isHigh = alert.severity == 'high';
    final bg = isHigh ? pal.errorContainer : pal.warningContainer;
    final fg = isHigh ? pal.onErrorContainer : pal.onWarningContainer;

    final dark = Theme.of(context).brightness == Brightness.dark;
    // Tinted card instead of hard borders: soft red for high risk, soft
    // peach for caution.
    return Container(
      decoration: BoxDecoration(
        color: dark
            ? Color.alphaBlend(
                (isHigh ? pal.sos : pal.moderate).withValues(alpha: 0.12),
                pal.surface,
              )
            : (isHigh ? const Color(0xFFFDEEEE) : const Color(0xFFFFF3E6)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsRegular.warning, size: 13, color: fg),
                  const SizedBox(width: 5),
                  Text(
                    isHigh ? 'High risk' : 'Caution',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              alert.title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(alert.body,
                style: TextStyle(color: pal.muted, height: 1.4, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── SOS logic (unchanged behaviour) ──────────────────────────────────

  Future<void> _sos(
    BuildContext context,
    WidgetRef ref,
    Session session,
    String stamp,
  ) async {
    final preferred = session.contacts.where((c) => c.preferred).toList();
    final target = preferred.isEmpty ? session.contacts : preferred;
    if (target.isEmpty) {
      final add = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add an emergency contact'),
          content: const Text(
              'Add someone to call before using the emergency action.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not now')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add contact')),
          ],
        ),
      );
      if (add == true && context.mounted) await _editContact(context, ref, null);
      return;
    }

    final contact = target.first;
    final body =
        'SignalSafe SOS from ${session.userName}. Last location ${session.here.latitude.toStringAsFixed(4)}, '
        '${session.here.longitude.toStringAsFixed(4)} at $stamp. Route ${session.route.name}.';
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emergency SOS'),
        content: Text(
          session.simulateLoss
              ? 'No signal. This demo will mark an SOS as queued locally; it will not contact anyone automatically.\n\n$body'
              : 'Open your phone app to call ${contact.name} at ${contact.phone}. '
                  'This demo cannot send an SMS or contact multiple people.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: context.palette.sos),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(session.simulateLoss
                ? 'Queue demo SOS'
                : 'Call ${contact.name}'),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Demo SOS queued locally; no contact was notified.')));
      }
      return;
    }

    final uri = Uri.parse('tel:${contact.phone.replaceAll(' ', '')}');
    final canCall = await canLaunchUrl(uri);
    final didLaunch = canCall && await launchUrl(uri);
    if (!context.mounted) return;
    if (!didLaunch) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open a call to ${contact.name}.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone app opened to call ${contact.name}.')));
  }

  Future<void> _contactActions(
    BuildContext context,
    WidgetRef ref,
    EmergencyContact contact,
  ) async {
    final ctx = context;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(contact.name,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.phoneCall),
              title: const Text('Call contact'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _callContact(ctx, contact);
              },
            ),
            ListTile(
              leading: Icon(contact.preferred
                  ? PhosphorIconsFill.star
                  : PhosphorIconsRegular.star),
              title: Text(
                  contact.preferred ? 'Preferred contact' : 'Make preferred'),
              onTap: () {
                ref.read(sessionProvider.notifier).update((s) => s.copyWith(
                      contacts: [
                        for (final c in s.contacts)
                          c.id == contact.id
                              ? c.copyWith(preferred: true)
                              : c.copyWith(preferred: false),
                      ],
                    ));
                Navigator.pop(sheetCtx);
              },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.pencilSimple),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _editContact(ctx, ref, contact);
              },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.trash),
              title: const Text('Remove'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final confirmed = await showDialog<bool>(
                  context: ctx,
                  builder: (d) => AlertDialog(
                    title: const Text('Remove emergency contact?'),
                    content: Text('${contact.name} will be removed.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(d, false),
                          child: const Text('Keep')),
                      FilledButton(
                          onPressed: () => Navigator.pop(d, true),
                          child: const Text('Remove')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  ref.read(sessionProvider.notifier).update((s) => s.copyWith(
                        contacts: s.contacts
                            .where((c) => c.id != contact.id)
                            .toList(),
                      ));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callContact(
      BuildContext context, EmergencyContact contact) async {
    final uri = Uri.parse('tel:${contact.phone.replaceAll(' ', '')}');
    final canCall = await canLaunchUrl(uri);
    final didLaunch = canCall && await launchUrl(uri);
    if (!context.mounted) return;
    if (!didLaunch) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open a call to ${contact.name}.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone app opened to call ${contact.name}.')));
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
      builder: (ctx) => AlertDialog(
        title:
            Text(existing == null ? 'Add contact' : 'Edit contact'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a name.' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a number.' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
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
        return s.copyWith(contacts: [
          ...s.contacts,
          EmergencyContact(
            id: 'c${DateTime.now().millisecondsSinceEpoch}',
            name: name.text.trim(),
            phone: phone.text.trim(),
            preferred: s.contacts.isEmpty,
          ),
        ]);
      }
      return s.copyWith(contacts: [
        for (final c in s.contacts)
          if (c.id == existing.id)
            c.copyWith(name: name.text.trim(), phone: phone.text.trim())
          else
            c,
      ]);
    });
    name.dispose();
    phone.dispose();
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

// ---------------------------------------------------------------------------
// SOS card widget
// ---------------------------------------------------------------------------

class _SosCard extends StatelessWidget {
  const _SosCard({required this.session, required this.onActivate});

  final Session session;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: pal.sos.withValues(alpha: 0.28), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: pal.sos.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(PhosphorIconsFill.shieldWarning,
                      color: pal.sos, size: 26),
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
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Call a contact when you have service. '
                        'This demo does not share live location or send messages.',
                        style: TextStyle(
                            color: pal.muted, height: 1.4, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _HoldSosButton(onActivate: onActivate),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hold-to-activate SOS button
// ---------------------------------------------------------------------------

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
        vsync: this, duration: const Duration(seconds: 3));
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 54,
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
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                    ),
                    child!,
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIconsFill.siren,
                        color: Theme.of(context).colorScheme.onError,
                        size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Press and hold for SOS options',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onError,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
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
