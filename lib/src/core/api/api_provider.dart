import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'desktop_api_client.dart';
import 'web_api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  if (kIsWeb) {
    return WebApiClient();
  } else {
    return DesktopApiClient();
  }
});
