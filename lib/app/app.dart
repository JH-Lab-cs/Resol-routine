import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ui/app_theme.dart';
import '../features/content_pack/application/content_pack_bootstrap.dart';
import '../features/root/presentation/root_shell.dart';

class ResolRoutineApp extends ConsumerWidget {
  const ResolRoutineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapState = ref.watch(appBootstrapProvider);

    return MaterialApp(
      title: 'Resol Routine',
      theme: AppTheme.light(),
      home: bootstrapState.when(
        data: (_) => const RootShell(),
        loading: () => const _BootstrapLoadingScreen(),
        error: (error, _) => _BootstrapErrorScreen(error: error),
      ),
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
