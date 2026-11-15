import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
              IconButton(
                tooltip: 'Search places',
                onPressed: () => context.push('/search'),
                icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: MaxWidthContent(
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final option in const [
                            ('all', 'All'),
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
                                selectedColor: context.palette.beacon
                                    .withValues(alpha: 0.18),
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
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Text(
                        'Traveller reports, separate from estimated coverage',
                        style: TextStyle(
                          color: context.palette.muted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Divider(indent: 56, height: 1),
                    const SizedBox(height: 4),
                    if (reports.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          children: [
                            Icon(
                              PhosphorIconsRegular.broadcast,
                              size: 32,
                              color: context.palette.muted,
                            ),
                            const SizedBox(height: 12),
                            const Text('No reports for this network yet.'),
                            const SizedBox(height: 4),
                            Text(
                              'Share a signal check to help other travellers.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.palette.muted),
                            ),
                          ],
                        ),
                      )
                    else
                      for (var i = 0; i < reports.length; i++) ...[
                        _card(context, ref, session, reports[i]),
                        if (i < reports.length - 1)
                          const Divider(indent: 56, height: 1),
                      ],
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: 20,
                  child: SafeArea(
                    top: false,
                    child: FloatingActionButton.extended(
                      backgroundColor: context.palette.primaryContainer,
                      foregroundColor: context.palette.onPrimaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onPressed: () => _submit(context, ref, session),
                      icon: const Icon(PhosphorIconsRegular.plus),
                      label: const Text('Report signal'),
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

  Widget _card(
    BuildContext context,
    WidgetRef ref,
    Session session,
    SignalReport report,
  ) {
    final flagged = session.flaggedIds.contains(report.id);
    final pal = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: pal.levelContainer(report.level),
            child: SignalBars(level: report.level),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${operatorLabel(report.operator)} · ${report.tech}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      agoLabel(report.minutesAgo),
                      style: TextStyle(color: pal.muted, fontSize: 13),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Report options',
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        PhosphorIconsRegular.dotsThreeVertical,
                        color: pal.muted,
                      ),
                      onSelected: (_) => _toggleFlag(ref, report, flagged),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'flag',
                          child: Text(
                            flagged ? 'Remove flag' : 'Flag as outdated',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (report.comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    report.comment,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SignalChip(level: report.level, compact: true),
                    Text(
                      '${(report.agreement * 100).round()}% of travellers agree',
                      style: TextStyle(color: pal.muted),
                    ),
                  ],
                ),
                if (flagged) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.flag,
                        color: pal.moderate,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Flagged as possibly outdated',
                        style: TextStyle(color: pal.moderate),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFlag(WidgetRef ref, SignalReport report, bool flagged) {
    ref.read(sessionProvider.notifier).update((s) {
      final next = {...s.flaggedIds};
      if (flagged) {
        next.remove(report.id);
      } else {
        next.add(report.id);
      }
      return s.copyWith(flaggedIds: next);
    });
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
