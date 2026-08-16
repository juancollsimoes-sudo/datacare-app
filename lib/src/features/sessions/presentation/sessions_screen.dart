import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:datacare/src/core/api/api_provider.dart';
import 'package:datacare/src/rust/db/models.dart';

final allSessionsProvider = FutureProvider<Map<DateTime, List<Sesion>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final patientsResult = await api.listPacientes(page: 1, pageSize: 1000);
  Map<DateTime, List<Sesion>> sessionsMap = {};

  for (var patient in patientsResult.items) {
    final sessionsResult = await api.listSesionesByPaciente(pacienteId: patient.id, page: 1, pageSize: 1000);
    for (var session in sessionsResult.items) {
      try {
        DateTime date = DateTime.parse(session.fecha);
        DateTime dayOnly = DateTime(date.year, date.month, date.day);
        if (sessionsMap[dayOnly] == null) {
          sessionsMap[dayOnly] = [];
        }
        sessionsMap[dayOnly]!.add(session);
      } catch (e) {
        // Ignorar fechas inválidas
      }
    }
  }
  return sessionsMap;
});

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(allSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario de Sesiones'),
      ),
      body: sessionsAsync.when(
        data: (sessionsMap) {
          List<Sesion> getEventsForDay(DateTime day) {
            DateTime dayOnly = DateTime(day.year, day.month, day.day);
            return sessionsMap[dayOnly] ?? [];
          }

          final selectedEvents = getEventsForDay(_selectedDay ?? _focusedDay);

          return Column(
            children: [
              TableCalendar<Sesion>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                eventLoader: getEventsForDay,
                calendarStyle: const CalendarStyle(
                  markerDecoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                ),
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: ListView.builder(
                  itemCount: selectedEvents.length,
                  itemBuilder: (context, index) {
                    final event = selectedEvents[index];
                    return ListTile(
                      leading: const Icon(Icons.event_note),
                      title: Text('Sesión #${event.id} - ${event.fecha.split('T')[0]}'),
                      subtitle: Text(event.notasSesion ?? 'Sin notas'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        context.go('/sessions/edit/${event.pacienteId}', extra: event);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
