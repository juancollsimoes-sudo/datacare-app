import 'dart:async';
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
  Sesion? _selectedSession;
  Timer? _hoverTimer;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  void _onSessionHoverEntered(Sesion session) {
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _selectedSession = session;
        });
      }
    });
  }

  void _onSessionHoverExited() {
    _hoverTimer?.cancel();
  }

  Widget _buildSessionDetails(Sesion session) {
    final theme = Theme.of(context);
    final isCorporal = session.tipo == 'corporal';

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Detalles de la Sesión #${session.id}', style: theme.textTheme.titleLarge),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCorporal
                            ? theme.colorScheme.tertiaryContainer
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCorporal ? Icons.accessibility_new : Icons.face,
                            size: 14,
                            color: isCorporal
                                ? theme.colorScheme.onTertiaryContainer
                                : theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCorporal ? 'Corporal' : 'Facial',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCorporal
                                  ? theme.colorScheme.onTertiaryContainer
                                  : theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedSession = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Fecha: ${session.fecha.split('T')[0]}', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            if (isCorporal && (session.peso != null || session.grasaCorporal != null || session.imc != null)) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (session.peso != null && session.peso!.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.scale_outlined, size: 16),
                      label: Text('Peso: ${session.peso} kg'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (session.grasaCorporal != null)
                    Chip(
                      avatar: const Icon(Icons.percent_rounded, size: 16),
                      label: Text('Grasa: ${session.grasaCorporal}%'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (session.imc != null)
                    Chip(
                      avatar: const Icon(Icons.speed_outlined, size: 16),
                      label: Text('IMC: ${session.imc}'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (session.aguaCorporal != null)
                    Chip(
                      avatar: const Icon(Icons.water_drop_outlined, size: 16),
                      label: Text('Agua: ${session.aguaCorporal}%'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text('Notas: ${session.notasSesion ?? 'Sin notas'}'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Editar Sesión'),
                onPressed: () {
                  context.go('/sessions/edit/${session.pacienteId}', extra: session);
                },
              ),
            )
          ],
        ),
      ),
    );
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

          DateTime now = DateTime.now();
          DateTime today = DateTime(now.year, now.month, now.day);
          DateTime limit = today.add(const Duration(days: 14));
          List<Sesion> upcomingSessions = [];

          sessionsMap.forEach((date, sessions) {
            if ((date.isAtSameMomentAs(today) || date.isAfter(today)) && date.isBefore(limit.add(const Duration(days: 1)))) {
              upcomingSessions.addAll(sessions);
            }
          });

          upcomingSessions.sort((a, b) => DateTime.parse(a.fecha).compareTo(DateTime.parse(b.fecha)));

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
                    _selectedSession = null; // Reset selection when changing day
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
                child: _selectedSession != null
                    ? _buildSessionDetails(_selectedSession!)
                    : ListView.builder(
                        itemCount: selectedEvents.length,
                        itemBuilder: (context, index) {
                          final event = selectedEvents[index];
                          final isCorporal = event.tipo == 'corporal';
                          final theme = Theme.of(context);

                          return MouseRegion(
                            onEnter: (_) => _onSessionHoverEntered(event),
                            onExit: (_) => _onSessionHoverExited(),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isCorporal
                                      ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5)
                                      : theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCorporal ? Icons.accessibility_new : Icons.face,
                                  size: 20,
                                  color: isCorporal ? theme.colorScheme.tertiary : theme.colorScheme.primary,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text('Sesión #${event.id} - ${event.fecha.split('T')[0]}'),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isCorporal
                                          ? theme.colorScheme.tertiaryContainer
                                          : theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isCorporal ? 'Corporal' : 'Facial',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isCorporal
                                            ? theme.colorScheme.onTertiaryContainer
                                            : theme.colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                isCorporal && (event.peso != null || event.grasaCorporal != null)
                                    ? 'Peso: ${event.peso ?? '-'} kg | Grasa: ${event.grasaCorporal != null ? '${event.grasaCorporal}%' : '-'}'
                                    : (event.notasSesion ?? 'Sin notas'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                setState(() {
                                  _selectedSession = event;
                                });
                              },
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              Container(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Próximas sesiones (2 semanas)', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 140,
                      child: upcomingSessions.isEmpty
                          ? const Center(child: Text('No hay sesiones próximas'))
                          : ListView.builder(
                              itemCount: upcomingSessions.length,
                              itemBuilder: (context, index) {
                                final event = upcomingSessions[index];
                                final isCorporal = event.tipo == 'corporal';
                                final theme = Theme.of(context);

                                return MouseRegion(
                                  onEnter: (_) => _onSessionHoverEntered(event),
                                  onExit: (_) => _onSessionHoverExited(),
                                  child: ListTile(
                                    leading: Icon(
                                      isCorporal ? Icons.accessibility_new : Icons.face,
                                      color: isCorporal ? theme.colorScheme.tertiary : theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                    title: Row(
                                      children: [
                                        Text('Sesión #${event.id} - ${event.fecha.split('T')[0]}'),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isCorporal
                                                ? theme.colorScheme.tertiaryContainer
                                                : theme.colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isCorporal ? 'Corporal' : 'Facial',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: isCorporal
                                                  ? theme.colorScheme.onTertiaryContainer
                                                  : theme.colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: const Icon(Icons.chevron_right, size: 16),
                                    onTap: () {
                                      setState(() {
                                        _selectedSession = event;
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
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
