import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:datacare/src/core/api/api_client.dart';
import 'package:datacare/src/core/api/api_provider.dart';
import 'package:datacare/src/core/services/auto_updater_service.dart';
import 'package:datacare/src/features/accounting/presentation/accounting_screen.dart';
import 'package:datacare/src/rust/db/models.dart';

PlatformInt64 _id(int v) => PlatformInt64Util.from(v);

class FakeAccountingApiClient implements ApiClient {
  final List<Gasto> gastos;
  final List<Sesion> ingresos;
  final List<Paciente> pacientes;
  int pdfReportCalls = 0;

  FakeAccountingApiClient({
    required this.gastos,
    required this.ingresos,
    required this.pacientes,
  });

  @override
  Future<List<Gasto>> listGastos() async => List.of(gastos);

  @override
  Future<List<Sesion>> listIngresos() async => List.of(ingresos);

  @override
  Future<PlatformInt64> createGasto({required NuevoGasto gasto}) async {
    final newId = _id(gastos.length + 100);
    gastos.add(
      Gasto(
        id: newId,
        nombre: gasto.nombre,
        descripcion: gasto.descripcion,
        categoria: gasto.categoria,
        monto: gasto.monto,
        fecha: gasto.fecha,
      ),
    );
    return newId;
  }

  @override
  Future<void> updateGasto({required Gasto gasto}) async {
    final idx = gastos.indexWhere((g) => g.id == gasto.id);
    if (idx >= 0) gastos[idx] = gasto;
  }

  @override
  Future<void> deleteGasto({required PlatformInt64 id}) async {
    gastos.removeWhere((g) => g.id == id);
  }

  @override
  Future<Uint8List> generateAccountingReportBytes({
    required int year,
    required int month,
  }) async {
    pdfReportCalls++;
    return Uint8List.fromList('%PDF-1.4 fake pdf'.codeUnits);
  }

  @override
  Future<Uint8List> generateExpensesExcelBytes({
    required int year,
    required int month,
  }) async {
    return Uint8List.fromList('PK\x03\x04 fake xlsx'.codeUnits);
  }

  @override
  Future<Uint8List> generatePatientReportBytes({
    required PlatformInt64 pacienteId,
  }) async {
    return Uint8List.fromList('%PDF-1.4 patient pdf'.codeUnits);
  }

  @override
  Future<PaginatedPacientes> listPacientes({
    String? search,
    required int page,
    required int pageSize,
  }) async {
    return PaginatedPacientes(
      items: pacientes,
      total: _id(pacientes.length),
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Paciente?> getPaciente({required PlatformInt64 id}) async {
    for (final p in pacientes) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<PlatformInt64> createPaciente({required NuevoPaciente paciente}) async => _id(1);

  @override
  Future<void> updatePaciente({required ActualizarPaciente paciente}) async {}

  @override
  Future<void> deactivatePaciente({required PlatformInt64 id}) async {}

  @override
  Future<PlatformInt64> createTratamiento({required NuevoTratamiento tratamiento}) async => _id(1);

  @override
  Future<List<Tratamiento>> listTratamientos() async => [];

  @override
  Future<void> updateTratamiento({required ActualizarTratamiento tratamiento}) async {}

  @override
  Future<PlatformInt64> createSesion({required NuevaSesion sesion}) async => _id(1);

  @override
  Future<PaginatedSesiones> listSesionesByPaciente({
    required PlatformInt64 pacienteId,
    required int page,
    required int pageSize,
  }) async {
    return PaginatedSesiones(items: [], total: _id(0), page: page, pageSize: pageSize);
  }

  @override
  Future<Sesion?> getSesion({required PlatformInt64 id}) async => null;

  @override
  Future<void> updateSesion({required ActualizarSesion sesion}) async {}

  @override
  Future<List<Sesion>> getSesionesCorporales({required PlatformInt64 pacienteId}) async => [];

  @override
  Future<DashboardStats> getDashboardStats() async => DashboardStats(
        totalPacientesActivos: _id(1),
        sesionesEsteMes: _id(1),
        tratamientosRegistrados: _id(1),
      );

  @override
  Future<FotoSesion> saveSessionPhoto({
    required PlatformInt64 pacienteId,
    required PlatformInt64 sesionId,
    required String inputPath,
    String? tipo,
    String? descripcion,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deletePhoto({required PlatformInt64 fotoId}) async {}

  @override
  Future<List<FotoSesion>> listPhotosBySession({required PlatformInt64 sesionId}) async => [];

  @override
  Future<List<FotoSesion>> listPhotosByPatient({required PlatformInt64 pacienteId}) async => [];
}

void main() {
  group('Contaduría - Requerimientos del Cliente', () {
    late FakeAccountingApiClient fakeApi;
    late String currentMonthDate;

    setUp(() {
      final now = DateTime.now();
      final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      currentMonthDate = '$ym-15';

      fakeApi = FakeAccountingApiClient(
        pacientes: [
          Paciente(
            id: _id(10),
            nombre: 'Carolina',
            apellido: 'Herrera',
            fechaRegistro: '$ym-01',
            activo: true,
          ),
        ],
        ingresos: [
          Sesion(
            id: _id(1544),
            pacienteId: _id(10),
            fecha: currentMonthDate,
            notasSesion: 'Tratamiento Rejuvenecimiento Facial',
            precioCobrado: 200.0,
            pagado: true,
            createdAt: currentMonthDate,
            tipo: 'facial',
            pacienteNombre: 'Carolina Herrera',
          ),
        ],
        gastos: [
          Gasto(
            id: _id(1),
            nombre: 'Ampollas Vitamina C',
            descripcion: 'Compra de insumos',
            categoria: 'Producto',
            monto: 50.0,
            fecha: currentMonthDate,
          ),
          Gasto(
            id: _id(2),
            nombre: 'Almuerzo Ejecutivo',
            descripcion: 'Gasto personal Susana',
            categoria: 'Gastos Personales',
            monto: 20.0,
            fecha: currentMonthDate,
          ),
          Gasto(
            id: _id(3),
            nombre: 'Farmacia Personal',
            descripcion: 'Medicamentos personales',
            categoria: 'Gastos Personales',
            monto: 15.0,
            fecha: currentMonthDate,
          ),
        ],
      );
    });

    testWidgets(
      '1. Muestra el nombre del paciente en vez de "Sesión (ID: 1544)"',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(fakeApi),
            ],
            child: const MaterialApp(
              home: AccountingScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Carolina Herrera'), findsWidgets);
        expect(find.text('Sesión (ID: 1544)'), findsNothing);
      },
    );

    testWidgets(
      '2. Muestra renglón de gastos personales y los totaliza e incorpora a la contabilidad',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(fakeApi),
            ],
            child: const MaterialApp(
              home: AccountingScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verifica que existe el renglón de Gastos Personales
        expect(find.textContaining('Gastos Personales'), findsWidgets);
        expect(find.text('Almuerzo Ejecutivo'), findsWidgets);
        expect(find.text('Farmacia Personal'), findsWidgets);

        // Ingresos: $200.00
        // Gastos Operativos: $50.00
        // Gastos Personales Totalizados: $35.00 ($20 + $15)
        // Total Gastos Incorporados: $85.00 ($50 + $35)
        // Saldo Neto: $115.00 ($200 - $85)
        expect(find.textContaining('\$200.00'), findsWidgets);
        expect(find.textContaining('\$50.00'), findsWidgets);
        expect(find.textContaining('\$35.00'), findsWidgets);
        expect(find.textContaining('\$85.00'), findsWidgets);
        expect(find.textContaining('\$115.00'), findsWidgets);
      },
    );

    testWidgets(
      '3. Permite abrir el Cierre Contable de fin de mes con totales desglosados para guardar en PDF',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(fakeApi),
            ],
            child: const MaterialApp(
              home: AccountingScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final cierreButton = find.byKey(const Key('btn_cierre_contable_pdf'));
        expect(cierreButton, findsOneWidget);

        await tester.tap(cierreButton);
        await tester.pumpAndSettle();

        expect(find.textContaining('Cierre Contable'), findsWidgets);
        expect(find.textContaining('Guardar Cierre en PDF'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Permite anexar un nuevo Gasto Personal y actualiza los totales de contabilidad',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(fakeApi),
            ],
            child: const MaterialApp(
              home: AccountingScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_add_personal_expense')));
        await tester.pumpAndSettle();

        expect(find.text('Nuevo Gasto Personal'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Concepto / Nombre'),
          'Compra Supermercado',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Monto (\$)'),
          '25.00',
        );

        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();

        // Verifica que se agregó al renglón de gastos personales y se actualizó la totalización:
        // Gastos Personales: $35 + $25 = $60.00
        // Total Gastos: $50 + $60 = $110.00
        // Saldo Neto: $200 - $110 = $90.00
        expect(find.text('Compra Supermercado'), findsOneWidget);
        expect(find.textContaining('\$60.00'), findsWidgets);
        expect(find.textContaining('\$110.00'), findsWidgets);
        expect(find.textContaining('\$90.00'), findsWidgets);
      },
    );

    testWidgets(
      '5. Resuelve el nombre del paciente desde la lista de pacientes cuando pacienteNombre es null',
      (WidgetTester tester) async {
        final fallbackApi = FakeAccountingApiClient(
          pacientes: fakeApi.pacientes,
          ingresos: [
            Sesion(
              id: _id(1544),
              pacienteId: _id(10),
              fecha: currentMonthDate,
              notasSesion: 'Sesión sin campo join',
              precioCobrado: 100.0,
              pagado: true,
              createdAt: currentMonthDate,
              tipo: 'facial',
              pacienteNombre: null,
            ),
          ],
          gastos: [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(fallbackApi),
            ],
            child: const MaterialApp(
              home: AccountingScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Carolina Herrera'), findsOneWidget);
        expect(find.textContaining('1544'), findsNothing);
        expect(find.byKey(const Key('btn_export_expenses_excel')), findsOneWidget);
        expect(find.text('Descargar Excel (Gastos y Compras)'), findsOneWidget);
      },
    );

    testWidgets(
      '6. Permite filtrar movimientos por Chips (Todos, Ingresos, Operativos, Personales)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(fakeApi),
            ],
            child: const MaterialApp(
              home: AccountingScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // En "Todos", vemos Carolina Herrera (ingreso) y Ampollas Vitamina C (gasto operativo)
        expect(find.textContaining('Carolina Herrera'), findsWidgets);
        expect(find.text('Ampollas Vitamina C'), findsOneWidget);

        // Filtrar por "Ingresos"
        await tester.ensureVisible(find.textContaining('Ingresos (1)'));
        await tester.tap(find.textContaining('Ingresos (1)'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Carolina Herrera'), findsWidgets);
        expect(find.text('Ampollas Vitamina C'), findsNothing);

        // Filtrar por "Operativos"
        await tester.ensureVisible(find.textContaining('Operativos (1)'));
        await tester.tap(find.textContaining('Operativos (1)'));
        await tester.pumpAndSettle();

        expect(find.text('Ampollas Vitamina C'), findsOneWidget);
        expect(find.textContaining('Carolina Herrera'), findsNothing);
      },
    );
  });

  group('AutoUpdaterService - Verificación de versión y assets', () {
    test('Compara versiones semánticas correctamente', () {
      expect(AutoUpdaterService.isNewerVersion('v1.0.4', 'v1.0.3'), isTrue);
      expect(AutoUpdaterService.isNewerVersion('1.0.4', 'v1.0.3'), isTrue);
      expect(AutoUpdaterService.isNewerVersion('v1.1.0', 'v1.0.9'), isTrue);
      expect(AutoUpdaterService.isNewerVersion('v2.0.0', 'v1.9.9'), isTrue);
      expect(AutoUpdaterService.isNewerVersion('v1.0.3', 'v1.0.3'), isFalse);
      expect(AutoUpdaterService.isNewerVersion('v1.0.2', 'v1.0.3'), isFalse);
    });

    test('Resuelve URL del asset datacare-windows.zip o portable zip', () {
      final assets = [
        {
          'name': 'DataCare-Windows-Setup-v1.0.4.exe',
          'browser_download_url': 'https://example.com/setup.exe',
        },
        {
          'name': 'datacare-windows.zip',
          'browser_download_url': 'https://example.com/datacare-windows.zip',
        },
      ];
      expect(
        AutoUpdaterService.getAssetUrl(assets, 'datacare-windows.zip'),
        'https://example.com/datacare-windows.zip',
      );

      final portableOnly = [
        {
          'name': 'DataCare-Windows-Portable-v1.0.4.zip',
          'browser_download_url': 'https://example.com/portable.zip',
        },
      ];
      expect(
        AutoUpdaterService.getAssetUrl(portableOnly, 'datacare-windows.zip'),
        'https://example.com/portable.zip',
      );
    });
  });
}
