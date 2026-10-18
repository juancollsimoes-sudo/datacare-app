import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class AutoUpdaterService {
  static const String _releasesUrl =
      'https://api.github.com/repos/juancollsimoes-sudo/datacare-app/releases/latest';

  static Future<void> checkForUpdates(
    BuildContext context, {
    bool manualCheck = false,
  }) async {
    if (kIsWeb || (!Platform.isWindows && !manualCheck)) return;

    try {
      final response = await http.get(
        Uri.parse(_releasesUrl),
        headers: const {
          'User-Agent': 'DataCare-AutoUpdater',
          'Accept': 'application/vnd.github+json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String latestVersion = (data['tag_name'] ?? '').toString();
        final List<dynamic> assets = (data['assets'] as List<dynamic>?) ?? [];
        final String downloadUrl = getAssetUrl(assets, 'datacare-windows.zip');

        if (isNewerVersion(latestVersion, AppConstants.appVersion) &&
            downloadUrl.isNotEmpty) {
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, downloadUrl);
          }
        } else if (manualCheck && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Estás en la versión más reciente (${AppConstants.appVersion}).',
              ),
            ),
          );
        }
      } else if (manualCheck && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo verificar actualizaciones (código ${response.statusCode}).',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      if (manualCheck && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al verificar actualizaciones: $e')),
        );
      }
    }
  }

  static String getAssetUrl(List<dynamic> assets, String preferredName) {
    for (final asset in assets) {
      if (asset is Map && asset['name'] == preferredName) {
        return (asset['browser_download_url'] ?? '').toString();
      }
    }
    for (final asset in assets) {
      if (asset is Map) {
        final name = (asset['name'] ?? '').toString().toLowerCase();
        if (name.startsWith('datacare-windows-portable') &&
            name.endsWith('.zip')) {
          return (asset['browser_download_url'] ?? '').toString();
        }
      }
    }
    return '';
  }

  static bool isNewerVersion(String latest, String current) {
    try {
      final latestStr = latest.trim().replaceAll(RegExp(r'^[vV]'), '').split('+').first;
      final currentStr = current.trim().replaceAll(RegExp(r'^[vV]'), '').split('+').first;

      final latestParts = latestStr.split('.').map(int.parse).toList();
      final currentParts = currentStr.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final int l = i < latestParts.length ? latestParts[i] : 0;
        final int c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (e) {
      debugPrint('Error parsing version: $e');
    }
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String version,
    String downloadUrl,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Actualización disponible'),
          content: Text(
            'Hay una nueva versión disponible ($version). Tu versión actual es ${AppConstants.appVersion}.\n\n¿Deseas descargar e instalar la actualización ahora?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Más tarde'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                if (!kIsWeb && Platform.isWindows) {
                  _downloadAndInstallUpdate(context, downloadUrl);
                }
              },
              child: const Text('Actualizar ahora'),
            ),
          ],
        );
      },
    );
  }

  static Future<bool> _canWriteToDirectory(String dirPath) async {
    try {
      final testFile = File('$dirPath\\.datacare_write_test');
      await testFile.writeAsString('ok');
      if (await testFile.exists()) {
        await testFile.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _downloadAndInstallUpdate(
    BuildContext context,
    String url,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Expanded(child: Text('Descargando e instalando actualización...')),
          ],
        ),
      ),
    );

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: const {'User-Agent': 'DataCare-AutoUpdater'},
      );

      if (response.statusCode == 200) {
        final tempDir = Directory.systemTemp;
        final zipFile = File('${tempDir.path}\\datacare-windows.zip');
        await zipFile.writeAsBytes(response.bodyBytes);

        final extractPath = '${tempDir.path}\\datacare_update';
        final extractDir = Directory(extractPath);
        if (await extractDir.exists()) {
          await extractDir.delete(recursive: true);
        }
        await extractDir.create(recursive: true);

        // Extract using PowerShell with LiteralPath to support spaces in user paths
        final psResult = await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          "Expand-Archive -LiteralPath '${zipFile.path}' -DestinationPath '$extractPath' -Force",
        ]);

        if (psResult.exitCode != 0) {
          throw Exception(
            'Error al descomprimir actualización: ${psResult.stderr}',
          );
        }

        final appDir = File(Platform.resolvedExecutable).parent.path;
        final batFile = File('${tempDir.path}\\update_datacare.bat');

        await batFile.writeAsString('''
@echo off
:waitloop
tasklist /FI "IMAGENAME eq datacare.exe" 2>NUL | find /I /N "datacare.exe">NUL
if "%ERRORLEVEL%"=="0" (
    timeout /t 1 /nobreak > nul
    goto waitloop
)
robocopy "$extractPath" "$appDir" /E /IS /IT /R:5 /W:1 > nul
if %ERRORLEVEL% GEQ 8 (
    xcopy /s /y /e /i "$extractPath\\*" "$appDir\\" > nul
)
start "" "$appDir\\datacare.exe"
del "%~f0"
''');

        final writable = await _canWriteToDirectory(appDir);
        if (writable) {
          await Process.start(
            'cmd',
            ['/c', batFile.path],
            mode: ProcessStartMode.detached,
          );
        } else {
          // Request UAC elevation when installed in C:\Program Files
          await Process.start(
            'powershell',
            [
              '-NoProfile',
              '-NonInteractive',
              '-ExecutionPolicy',
              'Bypass',
              '-Command',
              "Start-Process cmd.exe -ArgumentList '/c \"\"${batFile.path}\"\"' -Verb RunAs -WindowStyle Hidden",
            ],
            mode: ProcessStartMode.detached,
          );
        }
        exit(0);
      } else {
        throw Exception('Descarga fallida (HTTP ${response.statusCode})');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    }
  }
}
