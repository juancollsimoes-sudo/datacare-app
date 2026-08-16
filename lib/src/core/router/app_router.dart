import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/app_shell.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/patients/presentation/patients_screen.dart';
import '../../features/sessions/presentation/sessions_screen.dart';
import '../../features/treatments/presentation/treatments_screen.dart';
import '../../features/import/presentation/import_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/backup/presentation/backup_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/patients/presentation/patient_detail_screen.dart'; // We'll mock this

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/patients',
            builder: (context, state) => const PatientsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => PatientDetailScreen(id: state.pathParameters['id']!),
              ),
            ]
          ),
          GoRoute(
            path: '/sessions',
            builder: (context, state) => const SessionsScreen(),
          ),
          GoRoute(
            path: '/treatments',
            builder: (context, state) => const TreatmentsScreen(),
          ),
          GoRoute(
            path: '/import',
            builder: (context, state) => const ImportScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/backup',
            builder: (context, state) => const BackupScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
