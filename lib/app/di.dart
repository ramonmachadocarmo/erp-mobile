import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/biometric/biometric_service.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/network/unauthorized_handler.dart';
import '../core/storage/session_store.dart';

final apiConfigProvider = Provider<ApiConfig>(
  (_) => ApiConfig.fromEnvironment(),
);

final biometricServiceProvider = Provider<BiometricService>(
  (_) => BiometricService(),
);

final sessionStoreProvider = Provider<SessionStore>((_) => SessionStore());

final unauthorizedHandlerProvider = Provider<UnauthorizedHandler>(
  (_) => UnauthorizedHandler(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ref.watch(apiConfigProvider).baseUrl,
    session: ref.watch(sessionStoreProvider),
    unauthorized: ref.watch(unauthorizedHandlerProvider),
  );
});
