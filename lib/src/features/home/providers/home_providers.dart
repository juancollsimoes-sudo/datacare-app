import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:datacare/src/rust/api/db_api.dart';
import 'package:datacare/src/rust/db/models.dart';

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  return await getDashboardStats();
});
