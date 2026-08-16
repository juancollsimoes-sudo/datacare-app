import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:datacare/src/rust/frb_generated.dart';
import 'package:datacare/app.dart';
import 'package:system_theme/system_theme.dart';
import 'package:datacare/src/rust/api/db_api.dart';
import 'package:datacare/src/rust/api/server_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:datacare/src/core/theme/theme_provider.dart';
import 'package:flutter/foundation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb) {
    await SystemTheme.accentColor.load();
    await RustLib.init();
    
    // Initialize Database
    final home = Platform.environment['HOME'] ?? '';
    final dbDir = Directory('$home/.local/share/datacare');
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    await initDatabase(dbPath: '${dbDir.path}/datacare.db');

    try {
      startLocalServer(port: 8080);
      debugPrint('Local server started on port 8080');
    } catch (e) {
      debugPrint('Failed to start local server: $e');
    }
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const DataCareApp(),
    ),
  );
}
