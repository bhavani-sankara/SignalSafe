import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session.dart';
import '../theme/app_theme.dart';

class SessionGate extends ConsumerWidget {
  const SessionGate({super.key, required this.builder});

  final Widget Function(BuildContext context, Session session) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: context.palette.beacon),
        ),
      );
    }
    return builder(context, session);
  }
}
