import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/local_settings_repository.dart';
import 'router.dart';
import 'theme.dart';

class ShryneApp extends ConsumerWidget {
  const ShryneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final themes = buildAppThemes(
          useDynamicColor: settings.useDynamicColor,
          lightDynamicScheme: lightDynamic,
          darkDynamicScheme: darkDynamic,
          fontScale: settings.fontScale,
        );

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Shryne Chat',
          theme: themes.lightTheme,
          darkTheme: themes.darkTheme,
          themeMode: settings.themeMode,
          routerConfig: ref.watch(appRouterProvider),
        );
      },
    );
  }
}
