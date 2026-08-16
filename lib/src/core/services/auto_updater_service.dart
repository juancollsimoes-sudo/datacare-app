import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class AutoUpdaterService {
  static Future<void> checkForUpdates(BuildContext context) async {
    if (!Platform.isWindows) return;

    try {
      final response = await http.get(Uri.parse('https://api.github.com/repos/juancollsimoes-sudo/datacare-app/releases/latest'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String latestVersion = data['tag_name'];
        final String downloadUrl = _getAssetUrl(data['assets'], 'datacare-windows.zip');

        if (_isNewerVersion(latestVersion, AppConstants.appVersion) && downloadUrl.isNotEmpty) {
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, downloadUrl);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  static String _getAssetUrl(List<dynamic> assets, String name) {
    for (var asset in assets) {
      if (asset['name'] == name) {
        return asset['browser_download_url'];
      }
    }
    return '';
  }

  static bool _isNewerVersion(String latest, String current) {
    try {
      final latestStr = latest.replaceAll('v', '');
      final currentStr = current.replaceAll('v', '');
      
      final latestParts = latestStr.split('.').map(int.parse).toList();
      final currentParts = currentStr.split('.').map(int.parse).toList();
      
      for (int i = 0; i < 3; i++) {
        int l = i < latestParts.length ? latestParts[i] : 0;
        int c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (e) {
      debugPrint('Error parsing version: $e');
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String version, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Actualización disponible'),
          content: Text('Hay una actualización disponible ($version). ¿Deseas actualizar ahora?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Más tarde'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _downloadAndInstallUpdate(context, downloadUrl);
              },
              child: const Text('Actualizar ahora'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _downloadAndInstallUpdate(BuildContext context, String url) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Text('Descargando actualización...'),
          ],
        ),
      ),
    );

    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final tempDir = Directory.systemTemp;
        final zipFile = File('${tempDir.path}\\datacare-windows.zip');
        await zipFile.writeAsBytes(response.bodyBytes);

        final extractPath = '${tempDir.path}\\datacare_update';
        final extractDir = Directory(extractPath);
        if (await extractDir.exists()) {
          await extractDir.delete(recursive: true);
        }
        await extractDir.create();

        // Extract using PowerShell
        await Process.run('powershell', [
          '-command', 
          'Expand-Archive -Path "${zipFile.path}" -DestinationPath "$extractPath" -Force'
        ]);

        final appDir = File(Platform.resolvedExecutable).parent.path;
        final batFile = File('${tempDir.path}\\update.bat');

        await batFile.writeAsString('''
@echo off
timeout /t 2 /nobreak > nul
xcopy /s /y /e "$extractPath\\*" "$appDir\\"
start "" "$appDir\\datacare.exe"
del "%~f0"
''');

        await Process.start('cmd', ['/c', batFile.path], mode: ProcessStartMode.detached);
        exit(0);
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
