enum AuthUserRole { student, parent }

AuthUserRole authUserRoleFromApi(String raw) {
  switch (raw) {
    case 'STUDENT':
      return AuthUserRole.student;
    case 'PARENT':
      return AuthUserRole.parent;
    default:
      throw FormatException('Unsupported auth role: "$raw"');
  }
}

extension AuthUserRoleApiValue on AuthUserRole {
  String get apiValue {
    switch (this) {
      case AuthUserRole.student:
        return 'STUDENT';
      case AuthUserRole.parent:
        return 'PARENT';
    }
  }
}

class AuthUserProfile {
  const AuthUserProfile({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String email;
  final AuthUserRole role;
  final DateTime createdAt;
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
  });

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
}

class AuthSession {
  const AuthSession({required this.tokens, required this.user});

  final AuthTokens tokens;
  final AuthUserProfile user;
}

enum AuthSessionStatus {
  signedOut,
  authenticating,
  refreshing,
  signedIn,
  error,
}

class AuthSessionState {
  const AuthSessionState({
    required this.status,
    this.user,
    this.errorCode,
    this.errorMessage,
  });

  const AuthSessionState.signedOut()
    : status = AuthSessionStatus.signedOut,
      user = null,
      errorCode = null,
      errorMessage = null;

  final AuthSessionStatus status;
  final AuthUserProfile? user;
  final String? errorCode;
  final String? errorMessage;

  bool get isSignedIn => status == AuthSessionStatus.signedIn && user != null;

  AuthSessionState copyWith({
    AuthSessionStatus? status,
    AuthUserProfile? user,
    bool clearUser = false,
    String? errorCode,
    bool clearErrorCode = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AuthSessionState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      errorCode: clearErrorCode ? null : (errorCode ?? this.errorCode),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

class StoredAuthTokens {
  const StoredAuthTokens({
    required this.userId,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
  });

  final String userId;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
}

class AuthRepositoryException implements Exception {
  const AuthRepositoryException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  bool get isUnauthorized =>
      statusCode == 401 ||
      code == 'invalid_access_token' ||
      code == 'invalid_refresh_token' ||
      code == 'refresh_token_reuse_detected';

  @override
  String toString() => 'AuthRepositoryException($code, $message)';
}
