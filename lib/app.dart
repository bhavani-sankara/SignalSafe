import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/session.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class SignalSafeApp extends ConsumerWidget {
  const SignalSafeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final dark = session?.darkMode ?? true;
    return MaterialApp.router(
      title: 'SignalSafe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(Brightness.light),
      darkTheme: AppTheme.of(Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
