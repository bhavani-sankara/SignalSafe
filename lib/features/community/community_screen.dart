import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/geo.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud.dart';
import '../../widgets/session_gate.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  String _operatorFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    return SessionGate(
      builder: (context, session) {
        final reports =
            session.reports
                .where(
                  (report) =>
                      _operatorFilter == 'all' ||
                      report.operator == _operatorFilter,
                )
                .toList()
              ..sort((a, b) => a.minutesAgo.compareTo(b.minutesAgo));
        return Scaffold(
          appBar: AppBar(
            title: const Text('Community'),
            actions: [
              TextButton.icon(
                onPressed: () => _submit(context, ref, session),
                icon: const Icon(PhosphorIconsRegular.plus),
                label: const Text('Report signal'),
              ),
            ],
          ),
          body: MaxWidthContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                const SectionHeading(
                  'Traveller reports',
                  subtitle:
                      'Shared signal checks, separate from estimated coverage.',
                ),
                const SectionLabel('Network'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final option in const [
                        ('all', 'All networks'),
                        ('jio', 'Jio'),
                        ('airtel', 'Airtel'),
                        ('vi', 'Vi'),
                        ('bsnl', 'BSNL'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(option.$2),
                            selected: _operatorFilter == option.$1,
                            selectedColor: context.palette.beacon.withValues(
                              alpha: 0.18,
                            ),
                            checkmarkColor: context.palette.beacon,
                            side: BorderSide(
                              color: _operatorFilter == option.$1
                                  ? context.palette.beacon
                                  : context.palette.border,
                            ),
                            onSelected: (_) =>
                                setState(() => _operatorFilter = option.$1),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (reports.isEmpty)
                  Glass(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(PhosphorIconsRegular.broadcast),
                        const SizedBox(height: 8),
                        const Text('No reports for this network yet.'),
                        const SizedBox(height: 4),
                        Text(
                          'Share a signal check to help other travellers.',
                          style: TextStyle(color: context.palette.muted),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _submit(context, ref, session),
                          icon: const Icon(PhosphorIconsRegular.plus),
                          label: const Text('Report signal'),
                        ),
                      ],
                    ),
                  )
                else
                  for (final report in reports)
                    _card(context, ref, session, report),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card(
    BuildContext context,
    WidgetRef ref,
    Session session,
    SignalReport report,
  ) {
    final flagged = session.flaggedIds.contains(report.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Glass(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SignalChip(level: report.level, compact: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${operatorLabel(report.operator)} · ${report.tech}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  agoLabel(report.minutesAgo),
                  style: dataStyle(context, size: 12),
                ),
              ],
            ),
            if (report.comment.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                report.comment,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Reliability ${(report.agreement * 100).round()}% agreement',
              style: TextStyle(color: context.palette.muted, fontSize: 12),
            ),
            if (flagged) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.flag,
                    color: context.palette.moderate,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Flagged as possibly outdated',
                    style: TextStyle(color: context.palette.moderate),
                  ),
                ],
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  ref.read(sessionProvider.notifier).update((s) {
                    final next = {...s.flaggedIds};
                    if (!next.add(report.id)) next.remove(report.id);
                    return s.copyWith(flaggedIds: next);
                  });
                },
                icon: Icon(
                  flagged
                      ? PhosphorIconsRegular.arrowCounterClockwise
                      : PhosphorIconsRegular.flag,
                  size: 18,
                ),
                label: Text(flagged ? 'Remove flag' : 'Flag as outdated'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) async {
    var level = 'moderate';
    var operator = session.preferredOperator;
    var tech = '4G';
    final comment = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: StatefulBuilder(
              builder: (context, setSheet) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Signal report',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Location uses your current mock position in Gachibowli.',
                      style: TextStyle(color: context.palette.muted),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final item in const [
                          'good',
                          'moderate',
                          'weak',
                          'none',
                        ])
                          ChoiceChip(
                            label: Text(item == 'none' ? 'No signal' : item),
                            selected: level == item,
                            onSelected: (_) => setSheet(() => level = item),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: operator,
                      decoration: const InputDecoration(labelText: 'Operator'),
                      items: const [
                        DropdownMenuItem(value: 'jio', child: Text('Jio')),
                        DropdownMenuItem(
                          value: 'airtel',
                          child: Text('Airtel'),
                        ),
                        DropdownMenuItem(value: 'vi', child: Text('Vi')),
                        DropdownMenuItem(value: 'bsnl', child: Text('BSNL')),
                      ],
                      onChanged: (v) =>
                          setSheet(() => operator = v ?? operator),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: tech,
                      decoration: const InputDecoration(
                        labelText: 'Technology',
                      ),
                      items: const [
                        DropdownMenuItem(value: '2G', child: Text('2G')),
                        DropdownMenuItem(value: '3G', child: Text('3G')),
                        DropdownMenuItem(value: '4G', child: Text('4G')),
                        DropdownMenuItem(value: '5G', child: Text('5G')),
                      ],
                      onChanged: (v) => setSheet(() => tech = v ?? tech),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: comment,
                      decoration: const InputDecoration(
                        labelText: 'Comment (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Submit report'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
    if (ok != true) return;
    final report = SignalReport(
      id: 'r${DateTime.now().millisecondsSinceEpoch}',
      point: LatLng(
        session.here.latitude + 0.01,
        session.here.longitude + 0.01,
      ),
      level: level,
      operator: operator,
      tech: tech,
      comment: comment.text.trim(),
      minutesAgo: 0,
      agreement: 0.5,
    );
    ref
        .read(sessionProvider.notifier)
        .update((s) => s.copyWith(reports: [report, ...s.reports]));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report added to the community layer')),
      );
    }
  }
}
