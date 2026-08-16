import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_provider.dart';
import 'package:datacare/src/rust/db/models.dart';

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  return await apiClient.getDashboardStats();
});
