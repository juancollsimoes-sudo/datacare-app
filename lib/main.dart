import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:datacare/src/rust/frb_generated.dart';
import 'package:datacare/app.dart';
import 'package:system_theme/system_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemTheme.accentColor.load();
  await RustLib.init();
  runApp(const ProviderScope(child: DataCareApp()));
}
