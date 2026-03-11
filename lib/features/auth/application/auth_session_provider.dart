import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../settings/application/user_settings_providers.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import '../data/auth_token_store.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((Ref ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final httpClientProvider = Provider<http.Client>((Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final jsonApiClientProvider = Provider<JsonApiClient>((Ref ref) {
  final apiConfig = ref.watch(apiConfigProvider);
  final httpClient = ref.watch(httpClientProvider);
  return JsonApiClient(baseUrl: apiConfig.baseUrl, httpClient: httpClient);
});

final authTokenStoreProvider = Provider<AuthTokenStore>((Ref ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return SecureAuthTokenStore(secureStorage: secureStorage);
});

final authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  final apiClient = ref.watch(jsonApiClientProvider);
  final tokenStore = ref.watch(authTokenStoreProvider);
  return AuthRepository(apiClient: apiClient, tokenStore: tokenStore);
});

class AuthSessionNotifier extends Notifier<AuthSessionState> {
  @override
  AuthSessionState build() => const AuthSessionState.signedOut();

  Future<void> bootstrap() async {
    state = state.copyWith(
      status: AuthSessionStatus.refreshing,
      clearErrorCode: true,
      clearErrorMessage: true,
    );

    try {
      final session = await ref.read(authRepositoryProvider).restoreSession();
      if (session == null) {
        state = const AuthSessionState.signedOut();
        return;
      }

      await _syncAuthenticatedUser(session.user);
      state = AuthSessionState(
        status: AuthSessionStatus.signedIn,
        user: session.user,
      );
    } on AuthRepositoryException catch (error) {
      state = AuthSessionState(
        status: AuthSessionStatus.error,
        errorCode: error.code,
        errorMessage: _toUiMessage(error),
      );
    } catch (error) {
      state = AuthSessionState(
        status: AuthSessionStatus.error,
        errorCode: 'bootstrap_failed',
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(
      status: AuthSessionStatus.authenticating,
      clearErrorCode: true,
      clearErrorMessage: true,
    );

    try {
      final session = await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      await _syncAuthenticatedUser(session.user);
      state = AuthSessionState(
        status: AuthSessionStatus.signedIn,
        user: session.user,
      );
    } on AuthRepositoryException catch (error) {
      state = AuthSessionState(
        status: AuthSessionStatus.error,
        errorCode: error.code,
        errorMessage: _toUiMessage(error),
      );
    } catch (error) {
      state = AuthSessionState(
        status: AuthSessionStatus.error,
        errorCode: 'login_failed',
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> refreshCurrentUser() async {
    state = state.copyWith(
      status: AuthSessionStatus.refreshing,
      clearErrorCode: true,
      clearErrorMessage: true,
    );

    try {
      final session = await ref.read(authRepositoryProvider).refreshSession();
      await _syncAuthenticatedUser(session.user);
      state = AuthSessionState(
        status: AuthSessionStatus.signedIn,
        user: session.user,
      );
    } on AuthRepositoryException catch (error) {
      await _handleRefreshFailure(error);
    } catch (error) {
      await _handleRefreshFailure(
        AuthRepositoryException(
          code: 'refresh_failed',
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> signOut() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } finally {
      await _resetLocalSessionState();
      state = const AuthSessionState.signedOut();
    }
  }

  Future<void> clearSessionOnly() async {
    await ref.read(authRepositoryProvider).clearSession();
    state = const AuthSessionState.signedOut();
  }

  Future<void> _handleRefreshFailure(AuthRepositoryException error) async {
    await ref.read(authRepositoryProvider).clearSession();
    await _resetLocalSessionState();
    state = const AuthSessionState.signedOut();
    state = state.copyWith(
      errorCode: error.code,
      errorMessage: _toUiMessage(error),
    );
  }

  Future<void> _syncAuthenticatedUser(AuthUserProfile user) async {
    final repository = ref.read(userSettingsRepositoryProvider);
    await repository.syncAuthenticatedUser(
      backendUserId: user.id,
      role: user.role.apiValue,
    );
    ref.invalidate(userSettingsProvider);
    ref.invalidate(selectedTrackProvider);
  }

  Future<void> _resetLocalSessionState() async {
    await ref.read(userSettingsRepositoryProvider).resetForLogout();
    ref.invalidate(userSettingsProvider);
    ref.invalidate(selectedTrackProvider);
  }

  String _toUiMessage(AuthRepositoryException error) {
    switch (error.code) {
      case 'invalid_credentials':
        return '이메일 또는 비밀번호를 확인해 주세요.';
      case 'invalid_refresh_token':
      case 'refresh_token_reuse_detected':
      case 'invalid_access_token':
        return '세션이 만료되어 다시 로그인해야 합니다.';
      default:
        return '로그인 상태를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
  }
}

final authSessionProvider =
    NotifierProvider<AuthSessionNotifier, AuthSessionState>(
      AuthSessionNotifier.new,
    );

final authBootstrapProvider = FutureProvider<void>((Ref ref) async {
  await ref.read(authSessionProvider.notifier).bootstrap();
});
