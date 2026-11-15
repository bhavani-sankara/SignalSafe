import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud.dart';
import '../../widgets/session_gate.dart';

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SessionGate(
      builder: (context, session) {
        final reports = session.reports.where((r) {
          if (session.operatorFilter != 'all' && r.operator != session.operatorFilter) {
            return false;
          }
          return true;
        }).toList()
          ..sort((a, b) => a.minutesAgo.compareTo(b.minutesAgo));
        return Scaffold(
          appBar: AppBar(title: const Text('Community')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _submit(context, ref, session),
            icon: const Icon(Icons.add),
            label: const Text('Report signal'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              const SourceTag(source: 'community'),
              const SizedBox(height: 8),
              Text(
                'Traveller reports are separate from tower metadata and estimated coverage.',
                style: TextStyle(color: context.palette.muted),
              ),
              const SizedBox(height: 12),
              if (reports.isEmpty)
                const Text('No reports for this operator yet.')
              else
                for (final report in reports) _card(context, ref, session, report),
            ],
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, Session session, SignalReport report) {
    final flagged = session.flaggedIds.contains(report.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: flagged ? 0.45 : 1,
        child: Glass(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SignalChip(level: report.level, compact: true),
                  const SizedBox(width: 8),
                  Text('${operatorLabel(report.operator)} · ${report.tech}'),
                  const Spacer(),
                  Text(agoLabel(report.minutesAgo), style: dataStyle(context, size: 12)),
                ],
              ),
              if (report.comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(report.comment),
              ],
              const SizedBox(height: 6),
              Text(
                flagged
                    ? 'Flagged as possibly outdated'
                    : 'Reliability ${(report.agreement * 100).round()}% agreement',
                style: TextStyle(color: context.palette.muted, fontSize: 12),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    ref.read(sessionProvider.notifier).update((s) {
                      final next = {...s.flaggedIds};
                      if (!next.add(report.id)) next.remove(report.id);
                      return s.copyWith(flaggedIds: next);
                    });
                  },
                  child: Text(flagged ? 'Unflag' : 'Flag as outdated'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref, Session session) async {
    var level = 'moderate';
    var operator = session.preferredOperator;
    var tech = '4G';
    final comment = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
          child: StatefulBuilder(
            builder: (context, setSheet) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Signal report', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Location uses your current mock position in Gachibowli.',
                    style: TextStyle(color: context.palette.muted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final item in const ['good', 'moderate', 'weak', 'none'])
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
                      DropdownMenuItem(value: 'airtel', child: Text('Airtel')),
                      DropdownMenuItem(value: 'vi', child: Text('Vi')),
                      DropdownMenuItem(value: 'bsnl', child: Text('BSNL')),
                    ],
                    onChanged: (v) => setSheet(() => operator = v ?? operator),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: tech,
                    decoration: const InputDecoration(labelText: 'Technology'),
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
                    decoration: const InputDecoration(labelText: 'Comment (optional)'),
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
        );
      },
    );
    if (ok != true) return;
    final report = SignalReport(
      id: 'r${DateTime.now().millisecondsSinceEpoch}',
      point: LatLng(session.here.latitude + 0.01, session.here.longitude + 0.01),
      level: level,
      operator: operator,
      tech: tech,
      comment: comment.text.trim(),
      minutesAgo: 0,
      agreement: 0.5,
    );
    ref.read(sessionProvider.notifier).update(
          (s) => s.copyWith(reports: [report, ...s.reports]),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report added to the community layer')),
      );
    }
  }
}
