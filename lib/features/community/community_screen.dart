import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../core/geo.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
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
    return SessionGate(
      builder: (context, session) {
        final pal = context.palette;
        final reports = session.reports
            .where((r) =>
                _operatorFilter == 'all' || r.operator == _operatorFilter)
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
              const SizedBox(width: 4),
            ],
          ),
          body: MaxWidthContent(
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    // ── Operator filter chips ──────────────────────────
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        children: [
                          for (final option in const [
                            ('all', 'All'),
                            ('jio', 'Jio'),
                            ('airtel', 'Airtel'),
                            ('vi', 'Vi'),
                            ('bsnl', 'BSNL'),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _operatorFilter = option.$1),
                                child: AnimatedContainer(
                                  duration: Motion.quick,
                                  curve: Motion.enter,
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 3),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _operatorFilter == option.$1
                                        ? pal.secondaryContainer
                                        : pal.surface,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: _operatorFilter == option.$1
                                        ? null
                                        : softShadow(context),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_operatorFilter == option.$1) ...[
                                        Icon(PhosphorIconsBold.check,
                                            size: 14,
                                            color: pal.onSecondaryContainer),
                                        const SizedBox(width: 5),
                                      ],
                                      Text(
                                        option.$2,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _operatorFilter == option.$1
                                              ? pal.onSecondaryContainer
                                              : pal.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    Text(
                      'Traveller reports, separate from estimated coverage',
                      style: TextStyle(color: pal.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 14),

                    // ── Empty state ────────────────────────────────────
                    if (reports.isEmpty)
                      _emptyState(context, pal)
                          .animate()
                          .fadeIn(duration: 350.ms),

                    // ── Report cards ───────────────────────────────────
                    for (var i = 0; i < reports.length; i++) ...[
                      _reportCard(context, session, reports[i])
                          .animate(delay: (i * 50).ms)
                          .fadeIn(duration: 280.ms)
                          .slideY(
                              begin: 0.04,
                              end: 0,
                              duration: 300.ms,
                              curve: Curves.easeOut),
                      if (i < reports.length - 1)
                        Divider(height: 1, color: pal.border),
                    ],
                  ],
                ),

                // ── FAB ────────────────────────────────────────────────
                Positioned(
                  right: 0,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    child: FloatingActionButton.extended(
                      backgroundColor: pal.beacon,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      onPressed: () => _submit(context, session),
                      icon: const Icon(PhosphorIconsRegular.plus, size: 18),
                      label: const Text(
                        'Report signal',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(
                        begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOut),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context, SignalPalette pal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: pal.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(PhosphorIconsRegular.broadcast,
                color: pal.beacon, size: 28),
          ),
          const SizedBox(height: 16),
          Text('No reports for this network yet.',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Share a signal check to help other travellers.',
            textAlign: TextAlign.center,
            style: TextStyle(color: pal.muted),
          ),
        ],
      ),
    );
  }

  Widget _reportCard(
      BuildContext context, Session session, SignalReport report) {
    final flagged = session.flaggedIds.contains(report.id);
    final pal = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Signal level avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: pal.levelContainer(report.level),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: SignalBars(level: report.level)),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${operatorLabel(report.operator)} · ${report.tech}',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      agoLabel(report.minutesAgo),
                      style: TextStyle(color: pal.muted, fontSize: 12),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Report options',
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: Icon(PhosphorIconsRegular.dotsThreeVertical,
                          color: pal.muted, size: 18),
                      onSelected: (_) =>
                          _toggleFlag(report, flagged),
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'flag',
                          child: Text(
                              flagged ? 'Remove flag' : 'Flag as outdated'),
                        ),
                      ],
                    ),
                  ],
                ),

                if (report.comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(report.comment,
                      style: TextStyle(
                          color: pal.text, height: 1.4, fontSize: 14)),
                ],

                const SizedBox(height: 8),

                // Mini signal strip (shows signal distribution context)
                Row(
                  children: [
                    SignalChip(level: report.level, compact: true),
                    const SizedBox(width: 10),
                    Text(
                      '${(report.agreement * 100).round()}% agree',
                      style: TextStyle(color: pal.muted, fontSize: 12),
                    ),
                  ],
                ),

                if (flagged) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(PhosphorIconsRegular.flag,
                          color: pal.moderate, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        'Flagged as possibly outdated',
                        style: TextStyle(
                            color: pal.moderate,
                            fontSize: 12,
                            fontStyle: FontStyle.italic),
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

  void _toggleFlag(SignalReport report, bool flagged) {
    ref.read(sessionProvider.notifier).update((s) {
      final next = {...s.flaggedIds};
      flagged ? next.remove(report.id) : next.add(report.id);
      return s.copyWith(flaggedIds: next);
    });
  }

  Future<void> _submit(BuildContext context, Session session) async {
    var level = 'moderate';
    var operator = session.preferredOperator;
    var tech = '4G';
    final comment = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
            child: StatefulBuilder(
              builder: (ctx, setSheet) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Report signal',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Location uses your current mock position in Gachibowli.',
                    style: TextStyle(
                        color: context.palette.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  SectionLabel('Signal level'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in const [
                        'good',
                        'moderate',
                        'weak',
                        'none'
                      ])
                        GestureDetector(
                          onTap: () => setSheet(() => level = item),
                          child: AnimatedContainer(
                            duration: 150.ms,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: level == item
                                  ? context.palette.levelContainer(item)
                                  : context.palette.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: level == item
                                    ? context.palette.level(item)
                                    : context.palette.border,
                                width: level == item ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              item == 'none' ? 'No signal' : item,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: level == item
                                    ? context.palette
                                        .onLevelContainer(item)
                                    : context.palette.text,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: operator,
                    decoration:
                        const InputDecoration(labelText: 'Operator'),
                    items: const [
                      DropdownMenuItem(value: 'jio', child: Text('Jio')),
                      DropdownMenuItem(
                          value: 'airtel', child: Text('Airtel')),
                      DropdownMenuItem(value: 'vi', child: Text('Vi')),
                      DropdownMenuItem(value: 'bsnl', child: Text('BSNL')),
                    ],
                    onChanged: (v) =>
                        setSheet(() => operator = v ?? operator),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: tech,
                    decoration:
                        const InputDecoration(labelText: 'Technology'),
                    items: const [
                      DropdownMenuItem(value: '2G', child: Text('2G')),
                      DropdownMenuItem(value: '3G', child: Text('3G')),
                      DropdownMenuItem(value: '4G', child: Text('4G')),
                      DropdownMenuItem(value: '5G', child: Text('5G')),
                    ],
                    onChanged: (v) => setSheet(() => tech = v ?? tech),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: comment,
                    decoration: const InputDecoration(
                        labelText: 'Comment (optional)'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Submit report'),
                    ),
                  ),
                ],
              ),
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
