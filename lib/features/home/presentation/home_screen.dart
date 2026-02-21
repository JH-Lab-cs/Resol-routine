import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/db_text_limits.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/components/hero_progress_card.dart';
import '../../../core/ui/components/routine_card.dart';
import '../../../core/ui/components/section_title.dart';
import '../../../core/ui/label_maps.dart';
import '../../my/application/profile_ui_prefs_provider.dart';
import '../../report/application/report_providers.dart';
import '../../report/data/shared_reports_repository.dart';
import '../../report/presentation/parent_shared_report_detail_screen.dart';
import '../../settings/application/user_settings_providers.dart' as settings;
import '../../today/application/today_session_providers.dart';
import '../application/home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.onOpenQuiz,
    required this.onOpenVocab,
    required this.onOpenTodayVocabQuiz,
    required this.onOpenWrongNotes,
    required this.onOpenMy,
  });

  final VoidCallback onOpenQuiz;
  final VoidCallback onOpenVocab;
  final VoidCallback onOpenTodayVocabQuiz;
  final VoidCallback onOpenWrongNotes;
  final VoidCallback onOpenMy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settings.userSettingsProvider);

    return AppPageBody(
      showDecorativeBackground: true,
      child: settingsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('홈 데이터를 불러오지 못했어요.\n$error', textAlign: TextAlign.center),
        ),
        data: (settings) {
          if (settings.role == 'PARENT') {
            return _ParentHomeContent(
              onImportReport: () => _importReportFile(context, ref),
            );
          }

          final selectedTrack = ref.watch(selectedTrackProvider);
          final displayName = ref.watch(displayNameProvider);
          final profilePrefs = ref.watch(profileUiPrefsProvider);
          final summary = ref.watch(homeRoutineSummaryProvider(selectedTrack));

          return summary.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                '홈 데이터를 불러오지 못했어요.\n$error',
                textAlign: TextAlign.center,
              ),
            ),
            data: (data) {
              final completed = data.progress.completed;
              final ctaLabel = _ctaLabel(completed: completed, total: 6);

              return ListView(
                children: [
                  Text('오늘도 화이팅, $displayName! 👋', style: AppTypography.title),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '매일 6문제로 완성하는 1등급 습관',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '현재 트랙 ${displayTrack(selectedTrack)}',
                              style: AppTypography.label.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              '학습 학년 · 듣기 ${profilePrefs.listeningGradeLabel} · 독해 ${profilePrefs.readingGradeLabel}',
                              style: AppTypography.label.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      InkWell(
                        onTap: onOpenMy,
                        borderRadius: BorderRadius.circular(
                          AppRadius.buttonPill,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              AppRadius.buttonPill,
                            ),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '학습 설정',
                                style: AppTypography.label.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.mdLg),
                  HeroProgressCard(
                    completed: completed,
                    total: 6,
                    listeningCompleted: data.progress.listeningCompleted,
                    readingCompleted: data.progress.readingCompleted,
                    ctaLabel: ctaLabel,
                    onTap: onOpenQuiz,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionTitle(title: '나의 학습 루틴'),
                  const SizedBox(height: AppSpacing.md),
                  GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 1.12,
                    children: [
                      RoutineCard(
                        title: '하루 루틴 문제풀기',
                        subtitle: '오늘 6문제 학습',
                        icon: Icons.play_circle_fill_rounded,
                        onTap: onOpenQuiz,
                      ),
                      RoutineCard(
                        title: '오늘의 단어 암기',
                        subtitle: '핵심 단어 복습',
                        icon: Icons.menu_book_rounded,
                        onTap: onOpenVocab,
                      ),
                      RoutineCard(
                        title: '오답 복습',
                        subtitle: '실수 원인 점검',
                        icon: Icons.assignment_late_rounded,
                        onTap: onOpenWrongNotes,
                      ),
                      RoutineCard(
                        title: '오늘의 단어 시험',
                        subtitle: '20문제 5지선다',
                        icon: Icons.quiz_rounded,
                        onTap: onOpenTodayVocabQuiz,
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _ctaLabel({required int completed, required int total}) {
    if (completed <= 0) {
      return '오늘 루틴 시작하기';
    }
    if (completed < total) {
      return '지금까지 푼 문제 이어하기';
    }
    return '오늘 루틴 완료 🎉';
  }

  Future<void> _importReportFile(BuildContext context, WidgetRef ref) async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'json', extensions: ['json']),
        ],
      );
      if (file == null) {
        return;
      }

      try {
        final bytes = await file.length();
        if (bytes > DbTextLimits.reportImportMaxBytes) {
          if (!context.mounted) {
            return;
          }
          final maxMb = (DbTextLimits.reportImportMaxBytes / (1024 * 1024))
              .toStringAsFixed(0);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('파일이 너무 큽니다. ${maxMb}MB 이하 파일만 가져올 수 있어요.')),
          );
          return;
        }
      } catch (_) {
        // Proceed. Repository-level raw length guards still apply.
      }

      final payload = await file.readAsString();
      final source = file.path.isEmpty ? 'shared_report.json' : file.path;
      await ref
          .read(sharedReportsRepositoryProvider)
          .importFromJson(source: source, payloadJson: payload);

      ref.invalidate(sharedReportSummariesProvider);

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('리포트를 가져왔습니다.')));
    } on FormatException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('리포트 형식이 올바르지 않습니다.\n$error')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('리포트를 가져오지 못했습니다.\n$error')));
    }
  }
}

class _ParentHomeContent extends ConsumerWidget {
  const _ParentHomeContent({required this.onImportReport});

  final Future<void> Function() onImportReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(sharedReportSummariesProvider);

    return ListView(
      children: [
        Text('가정 리포트', style: AppTypography.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '학생이 공유한 JSON 리포트를 가져와서 학습 추이를 확인하세요.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: onImportReport,
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('리포트 가져오기'),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionTitle(title: '가져온 리포트'),
        const SizedBox(height: AppSpacing.sm),
        summariesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text('리포트 목록을 불러오지 못했습니다.\n$error'),
          ),
          data: (summaries) {
            if (summaries.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text('아직 가져온 리포트가 없습니다.'),
                ),
              );
            }

            return Column(
              children: [
                for (final summary in summaries)
                  _ParentReportSummaryCard(summary: summary),
              ],
            );
          },
        ),
      ],
    );
  }
}

enum _ParentReportMenuAction { delete }

class _ParentReportSummaryCard extends ConsumerWidget {
  const _ParentReportSummaryCard({required this.summary});

  final SharedReportSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackLabel = summary.track == null
        ? '-'
        : displayTrack(summary.track!);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        title: Text(summary.studentDisplayName ?? summary.source),
        subtitle: Text(
          '${summary.latestDayKey ?? '-'} · $trackLabel · 오답 ${summary.totalWrongCount}개',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<_ParentReportMenuAction>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: '리포트 메뉴',
              onSelected: (action) async {
                switch (action) {
                  case _ParentReportMenuAction.delete:
                    await _confirmDelete(context, ref);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<_ParentReportMenuAction>(
                  value: _ParentReportMenuAction.delete,
                  child: Text('삭제'),
                ),
              ],
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ParentSharedReportDetailScreen(sharedReportId: summary.id),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('리포트 삭제'),
        content: const Text('이 리포트를 삭제할까요?\n삭제하면 되돌릴 수 없습니다.'),
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
      ),
    );

    if (confirmed != true) {
      return;
    }

    final deleted = await ref
        .read(sharedReportsRepositoryProvider)
        .deleteById(summary.id);
    ref.invalidate(sharedReportSummariesProvider);
    ref.invalidate(sharedReportByIdProvider(summary.id));

    if (!context.mounted) {
      return;
    }

    final message = deleted ? '리포트를 삭제했습니다.' : '이미 삭제된 리포트입니다.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
