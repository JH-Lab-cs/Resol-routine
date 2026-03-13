import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_provider.dart';
import '../../auth/data/auth_models.dart';
import '../data/family_repository.dart';

final familyRepositoryProvider = Provider<FamilyRepository>((Ref ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return FamilyRepository(authRepository: authRepository);
});

class FamilyLinksNotifier extends AsyncNotifier<FamilyLinksSnapshot> {
  @override
  Future<FamilyLinksSnapshot> build() async {
    final authState = ref.watch(authSessionProvider);
    if (authState.status != AuthSessionStatus.signedIn ||
        authState.user == null) {
      throw const FamilyRepositoryException(
        code: 'missing_session',
        message: 'No authenticated family session is available.',
      );
    }
    try {
      return await _loadSnapshot();
    } on FamilyRepositoryException catch (error) {
      await _handleRepositoryFailure(error);
      rethrow;
    }
  }

  Future<void> refreshLinks() async {
    final previous = state;
    state = const AsyncLoading<FamilyLinksSnapshot>().copyWithPrevious(
      previous,
      isRefresh: true,
    );
    await _refreshIntoState(previous: previous);
  }

  Future<void> consumeChildLinkCode(String code) async {
    final previous = state;
    state = const AsyncLoading<FamilyLinksSnapshot>().copyWithPrevious(
      previous,
      isRefresh: true,
    );
    try {
      await ref.read(familyRepositoryProvider).consumeChildLinkCode(code);
      final snapshot = await _loadSnapshot();
      state = AsyncData(snapshot);
    } on FamilyRepositoryException catch (error, stackTrace) {
      await _handleRepositoryFailure(error);
      _restoreFailureState(previous, error, stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      _restoreFailureState(previous, error, stackTrace);
      rethrow;
    }
  }

  Future<FamilyLinksSnapshot> _loadSnapshot() {
    return ref.read(familyRepositoryProvider).loadFamilyLinks();
  }

  Future<void> _refreshIntoState({
    required AsyncValue<FamilyLinksSnapshot> previous,
  }) async {
    try {
      final snapshot = await _loadSnapshot();
      state = AsyncData(snapshot);
    } on FamilyRepositoryException catch (error, stackTrace) {
      await _handleRepositoryFailure(error);
      _restoreFailureState(previous, error, stackTrace);
    } catch (error, stackTrace) {
      _restoreFailureState(previous, error, stackTrace);
    }
  }

  Future<void> _handleRepositoryFailure(FamilyRepositoryException error) async {
    if (!error.isUnauthorized) {
      return;
    }
    await ref.read(authSessionProvider.notifier).clearSessionOnly();
  }

  void _restoreFailureState(
    AsyncValue<FamilyLinksSnapshot> previous,
    Object error,
    StackTrace stackTrace,
  ) {
    final previousValue = previous.valueOrNull;
    if (previousValue != null) {
      state = AsyncData(previousValue);
      return;
    }
    state = AsyncError(error, stackTrace);
  }
}

final familyLinksProvider =
    AsyncNotifierProvider<FamilyLinksNotifier, FamilyLinksSnapshot>(
      FamilyLinksNotifier.new,
    );

class StudentLinkCodeNotifier extends AsyncNotifier<FamilyLinkCode?> {
  @override
  Future<FamilyLinkCode?> build() async {
    final authState = ref.watch(authSessionProvider);
    if (authState.status != AuthSessionStatus.signedIn ||
        authState.user?.role != AuthUserRole.student) {
      return null;
    }
    return _issueCode();
  }

  Future<void> regenerate() async {
    final previous = state;
    state = const AsyncLoading<FamilyLinkCode?>().copyWithPrevious(
      previous,
      isRefresh: true,
    );
    await _refreshIntoState(previous: previous);
  }

  Future<FamilyLinkCode> _issueCode() {
    return ref.read(familyRepositoryProvider).createChildLinkCode();
  }

  Future<void> _refreshIntoState({
    required AsyncValue<FamilyLinkCode?> previous,
  }) async {
    try {
      final code = await _issueCode();
      state = AsyncData(code);
    } on FamilyRepositoryException catch (error, stackTrace) {
      if (error.isUnauthorized) {
        await ref.read(authSessionProvider.notifier).clearSessionOnly();
      }
      final previousValue = previous.valueOrNull;
      if (previousValue != null) {
        state = AsyncData(previousValue);
      } else {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    } catch (error, stackTrace) {
      final previousValue = previous.valueOrNull;
      if (previousValue != null) {
        state = AsyncData(previousValue);
      } else {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }
}

final studentLinkCodeProvider =
    AsyncNotifierProvider<StudentLinkCodeNotifier, FamilyLinkCode?>(
      StudentLinkCodeNotifier.new,
    );
