
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
import '../../features/accounting/presentation/accounting_screen.dart';
import '../../features/patients/presentation/patient_detail_screen.dart';
import '../../features/patients/presentation/patient_form_screen.dart';
import '../../features/treatments/presentation/treatment_form_screen.dart';
import '../../features/sessions/presentation/session_form_screen.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import '../../rust/db/models.dart';

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
                path: 'new',
                builder: (context, state) => const PatientFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => PatientDetailScreen(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => PatientFormScreen(id: state.pathParameters['id']),
                  ),
                ],
              ),
            ]
          ),
          GoRoute(
            path: '/sessions',
            builder: (context, state) => const SessionsScreen(),
            routes: [
              GoRoute(
                path: 'new/:patientId',
                builder: (context, state) => SessionFormScreen(
                  patientId: PlatformInt64.parse(state.pathParameters['patientId']!),
                ),
              ),
              GoRoute(
                path: 'edit/:patientId',
                builder: (context, state) => SessionFormScreen(
                  patientId: PlatformInt64.parse(state.pathParameters['patientId']!),
                  session: state.extra as Sesion,
                ),
              ),
            ]
          ),
          GoRoute(
            path: '/treatments',
            builder: (context, state) => const TreatmentsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const TreatmentFormScreen(),
              ),
              GoRoute(
                path: 'edit',
                builder: (context, state) => TreatmentFormScreen(
                  treatment: state.extra as Tratamiento,
                ),
              ),
            ]
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
          GoRoute(
            path: '/accounting',
            builder: (context, state) => const AccountingScreen(),
          ),
        ],
      ),
    ],
  );
});
