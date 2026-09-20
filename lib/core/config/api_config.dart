import 'dart:io';

class ApiConfig {
  const ApiConfig({required this.baseUrl});

  final String baseUrl;

  factory ApiConfig.fromEnvironment() {
    const defined = String.fromEnvironment('API_BASE_URL');
    if (defined.isNotEmpty) return ApiConfig(baseUrl: defined);
    return ApiConfig(baseUrl: _defaultBaseUrl);
  }

  static String get _defaultBaseUrl {
    // Gateway (GATEWAY_HTTP_PORT), exposed by both the prod and dev stacks.
    if (Platform.isAndroid) return 'http://10.0.2.2:8086';
    return 'http://localhost:8086';
  }
}
