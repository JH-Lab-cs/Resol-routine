import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/components/primary_pill_button.dart';
import '../../../core/ui/components/section_title.dart';
import '../../today/application/today_quiz_providers.dart';
import '../../today/application/today_session_providers.dart';

final appVersionBuildProvider = FutureProvider<String>((Ref ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return '${packageInfo.version}+${packageInfo.buildNumber}';
});

class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(selectedTrackProvider);
    final versionAsync = ref.watch(appVersionBuildProvider);

    return AppScaffold(
      body: ListView(
        children: [
          const SectionTitle(title: '마이', subtitle: '현재 앱 상태와 개발용 도구'),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('현재 트랙: $track', style: AppTypography.body),
                  const SizedBox(height: AppSpacing.xs),
                  versionAsync.when(
                    loading: () => const Text(
                      '앱 버전/빌드: 불러오는 중...',
                      style: AppTypography.body,
                    ),
                    error: (_, _) =>
                        const Text('앱 버전/빌드: 확인 불가', style: AppTypography.body),
                    data: (value) =>
                        Text('앱 버전/빌드: $value', style: AppTypography.body),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryPillButton(
            label: '오늘 세션만 삭제 (개발용)',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('오늘 세션 삭제'),
                    content: const Text('오늘 선택한 트랙의 세션만 삭제합니다.\n계속할까요?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('취소'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('삭제'),
                      ),
                    ],
                  );
                },
              );

              if (confirmed != true) {
                return;
              }

              await ref
                  .read(todayQuizRepositoryProvider)
                  .deleteTodaySession(track: track);
              ref.invalidate(todaySessionProvider(track));

              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('오늘 세션을 삭제했습니다.')));
              }
            },
          ),
        ],
      ),
    );
  }
}
