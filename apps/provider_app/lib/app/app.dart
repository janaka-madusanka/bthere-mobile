import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';

class BThereProviderApp extends ConsumerWidget {
  const BThereProviderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'B there Provider',
    debugShowCheckedModeBanner: false,
    theme: BThereTheme.light(),
    darkTheme: BThereTheme.dark(),
    themeMode: ThemeMode.system,
    routerConfig: ref.watch(appRouterProvider),
  );
}
