import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:resol_routine/features/auth/application/auth_session_provider.dart';
import 'package:resol_routine/features/auth/data/auth_models.dart';
import 'package:resol_routine/features/settings/application/user_settings_providers.dart';

Override signedInAuthOverride({
  AuthUserRole role = AuthUserRole.student,
  String userId = 'user-1',
  String email = 'user@example.com',
}) {
  final state = AuthSessionState(
    status: AuthSessionStatus.signedIn,
    user: AuthUserProfile(
      id: userId,
      email: email,
      role: role,
      createdAt: DateTime.utc(2026, 3, 1, 12),
    ),
  );
  return authSessionProvider.overrideWith(() => FakeAuthSessionNotifier(state));
}

class FakeAuthSessionNotifier extends AuthSessionNotifier {
  FakeAuthSessionNotifier(this._initialState);

  final AuthSessionState _initialState;

  @override
  AuthSessionState build() => _initialState;

  @override
  Future<void> bootstrap() async {}

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> refreshCurrentUser() async {}

  @override
  Future<void> signOut() async {
    await ref.read(userSettingsRepositoryProvider).resetForLogout();
    ref.invalidate(userSettingsProvider);
    ref.invalidate(selectedTrackProvider);
    state = const AuthSessionState.signedOut();
  }

  @override
  Future<void> clearSessionOnly() async {
    state = const AuthSessionState.signedOut();
  }
}
