import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:datacare/src/rust/frb_generated.dart';
import 'package:datacare/app.dart';
import 'package:system_theme/system_theme.dart';
import 'package:datacare/src/rust/api/db_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemTheme.accentColor.load();
  await RustLib.init();
  
  // Initialize Database
  final home = Platform.environment['HOME'] ?? '';
  final dbDir = Directory('$home/.local/share/datacare');
  if (!await dbDir.exists()) {
    await dbDir.create(recursive: true);
  }
  await initDatabase(dbPath: '${dbDir.path}/datacare.db');

  runApp(const ProviderScope(child: DataCareApp()));
}
