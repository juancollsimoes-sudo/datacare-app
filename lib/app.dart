import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'src/core/router/app_router.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/constants/app_constants.dart';

class DataCareApp extends ConsumerWidget {
  const DataCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return SystemThemeBuilder(
      builder: (context, accent) {
        return MaterialApp.router(
          title: AppConstants.appName,
          theme: AppTheme.getLightTheme(accent.accent),
          darkTheme: AppTheme.getDarkTheme(accent.accent),
          themeMode: ThemeMode.system,
          routerConfig: router,
        );
      },
    );
  }
}
