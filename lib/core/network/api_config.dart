import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _apiBaseUrlEnvKey = 'RESOL_API_BASE_URL';

class ApiConfig {
  const ApiConfig({required this.baseUrl});

  final String baseUrl;
}

String resolveApiBaseUrl() {
  const configuredBaseUrl = String.fromEnvironment(
    _apiBaseUrlEnvKey,
    defaultValue: '',
  );
  final normalizedConfiguredBaseUrl = configuredBaseUrl.trim();
  if (normalizedConfiguredBaseUrl.isNotEmpty) {
    return _withoutTrailingSlash(normalizedConfiguredBaseUrl);
  }

  if (kIsWeb) {
    return 'http://127.0.0.1:8000';
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:8000';
    default:
      return 'http://127.0.0.1:8000';
  }
}

String _withoutTrailingSlash(String value) {
  if (value.endsWith('/')) {
    return value.substring(0, value.length - 1);
  }
  return value;
}

final apiConfigProvider = Provider<ApiConfig>((Ref ref) {
  return ApiConfig(baseUrl: resolveApiBaseUrl());
});
