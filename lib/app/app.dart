import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ui/app_theme.dart';
import '../features/auth/application/auth_session_provider.dart';
import '../features/auth/data/auth_models.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/content_pack/application/content_pack_bootstrap.dart';
import '../features/onboarding/presentation/onboarding_flow_screen.dart';
import '../features/root/presentation/root_shell.dart';
import '../features/settings/application/user_settings_providers.dart';

class ResolRoutineApp extends ConsumerWidget {
  const ResolRoutineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapState = ref.watch(appBootstrapProvider);

    return MaterialApp(
      title: 'Resol Routine',
      theme: AppTheme.light(),
      home: bootstrapState.when(
        data: (_) => const _EntryGate(),
        loading: () => const _BootstrapLoadingScreen(),
        error: (error, _) => _BootstrapErrorScreen(error: error),
      ),
    );
  }
}

class _EntryGate extends ConsumerWidget {
  const _EntryGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authSessionProvider);
    final settingsState = ref.watch(userSettingsProvider);

    if (authState.status == AuthSessionStatus.authenticating ||
        authState.status == AuthSessionStatus.refreshing) {
      return const _BootstrapLoadingScreen();
    }

    if (authState.status == AuthSessionStatus.signedOut ||
        authState.status == AuthSessionStatus.error) {
      return const SignInScreen();
    }

    return settingsState.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: (settings) {
        final onboardingRequired = settings.displayName.trim().isEmpty;
        if (onboardingRequired) {
          return OnboardingFlowScreen(
            initialRole: authState.user?.role.apiValue,
            startAtProfileStep: authState.isSignedIn,
            roleLocked: authState.isSignedIn,
          );
        }
        return const RootShell();
      },
      loading: () => const _BootstrapLoadingScreen(),
      error: (error, _) => _BootstrapErrorScreen(error: error),
    );
  }
}

class _BootstrapLoadingScreen extends StatelessWidget {
  const _BootstrapLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _BootstrapErrorScreen extends StatelessWidget {
  const _BootstrapErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '앱 초기화에 실패했습니다. 앱을 다시 실행해 주세요.\n\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
