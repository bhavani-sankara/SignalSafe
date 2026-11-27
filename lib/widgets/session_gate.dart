import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session.dart';
import 'skeleton.dart';

class SessionGate extends ConsumerWidget {
  const SessionGate({super.key, required this.builder});

  final Widget Function(BuildContext context, Session session) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session == null) {
      // Shimmering placeholders instead of a spinner, so nothing jumps
      // when the data arrives.
      return const Scaffold(body: SafeArea(child: ListSkeleton()));
    }
    return builder(context, session);
  }
}
