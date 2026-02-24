import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/db_text_limits.dart';
import '../../../core/domain/domain_enums.dart';
import '../../../core/io/limited_utf8_reader.dart';
import '../../../core/ui/app_copy_ko.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/components/app_snackbars.dart';
import '../../../core/ui/components/hero_progress_card.dart';
import '../../../core/ui/components/routine_card.dart';
import '../../../core/ui/components/section_title.dart';
import '../../../core/ui/components/skeleton.dart';
import '../../../core/ui/label_maps.dart';
import '../../my/application/profile_ui_prefs_provider.dart';
import '../../mock_exam/application/mock_exam_providers.dart';
import '../../mock_exam/data/mock_exam_session_repository.dart';
import '../../mock_exam/presentation/mock_exam_result_screen.dart';
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
    required this.onOpenWeeklyMockExam,
    required this.onOpenMonthlyMockExam,
    required this.onOpenVocab,
    required this.onOpenTodayVocabQuiz,
    required this.onOpenWrongNotes,
    required this.onOpenMy,
  });

  final VoidCallback onOpenQuiz;
  final VoidCallback onOpenWeeklyMockExam;
  final VoidCallback onOpenMonthlyMockExam;
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
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const _HomeLoadingSkeleton(),
        error: (error, _) => Center(
          child: Text(
            '${AppCopyKo.loadFailed('홈 데이터')}\n$error',
            textAlign: TextAlign.center,
          ),
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
          final weeklyMockSummaryAsync = ref.watch(
            mockExamCurrentSummaryProvider(
              MockExamCurrentSummaryQuery(
                type: MockExamType.weekly,
                track: selectedTrack,
              ),
            ),
          );
          final monthlyMockSummaryAsync = ref.watch(
            mockExamCurrentSummaryProvider(
              MockExamCurrentSummaryQuery(
                type: MockExamType.monthly,
                track: selectedTrack,
              ),
            ),
          );
          final summary = ref.watch(homeRoutineSummaryProvider(selectedTrack));
          final isSummaryRefreshing = summary.isLoading && summary.hasValue;

          return summary.when(
            skipLoadingOnRefresh: true,
            skipLoadingOnReload: true,
            loading: () => const _HomeLoadingSkeleton(),
            error: (error, _) => Center(
              child: Text(
                '${AppCopyKo.loadFailed('홈 데이터')}\n$error',
                textAlign: TextAlign.center,
              ),
            ),
            data: (data) {
              final completed = data.progress.completed;
              final ctaLabel = _ctaLabel(completed: completed, total: 6);

              return Stack(
                children: [
                  ListView(
                    children: [
                      Text(
                        '오늘도 화이팅, $displayName! 👋',
                        style: AppTypography.title,
                      ),
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
                      const SizedBox(height: AppSpacing.lg),
                      const SectionTitle(title: '모의고사'),
                      const SizedBox(height: AppSpacing.md),
                      GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        crossAxisCount: 2,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        childAspectRatio: 1.12,
                        children: [
                          Builder(
                            builder: (context) {
                              final cardModel = _buildMockCardModel(
                                type: MockExamType.weekly,
                                summary: weeklyMockSummaryAsync.valueOrNull,
                              );
                              return RoutineCard(
                                key: const ValueKey<String>(
                                  'home-mock-weekly-card',
                                ),
                                title: '주간 모의고사',
                                subtitle: cardModel.subtitle,
                                icon: Icons.event_note_rounded,
                                onTap: () => _handleMockCardTap(
                                  context: context,
                                  cardModel: cardModel,
                                  fallbackOpenFlow: onOpenWeeklyMockExam,
                                ),
                              );
                            },
                          ),
                          Builder(
                            builder: (context) {
                              final cardModel = _buildMockCardModel(
                                type: MockExamType.monthly,
                                summary: monthlyMockSummaryAsync.valueOrNull,
                              );
                              return RoutineCard(
                                key: const ValueKey<String>(
                                  'home-mock-monthly-card',
                                ),
                                title: '월간 모의고사',
                                subtitle: cardModel.subtitle,
                                icon: Icons.calendar_month_rounded,
                                onTap: () => _handleMockCardTap(
                                  context: context,
                                  cardModel: cardModel,
                                  fallbackOpenFlow: onOpenMonthlyMockExam,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (isSummaryRefreshing)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(minHeight: 2),
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

  _MockCardUiModel _buildMockCardModel({
    required MockExamType type,
    required MockExamSessionSummary? summary,
  }) {
    final plannedItems = switch (type) {
      MockExamType.weekly => 20,
      MockExamType.monthly => 45,
    };
    final defaultDescription = switch (type) {
      MockExamType.weekly => '듣기 10 + 독해 10',
      MockExamType.monthly => '풀모의고사 45문항',
    };

    if (summary == null || summary.completedItems <= 0) {
      return _MockCardUiModel(
        type: type,
        status: _MockHomeCardStatus.notStarted,
        subtitle: '$defaultDescription · 시작하기',
      );
    }

    if (summary.completedItems >= summary.plannedItems) {
      return _MockCardUiModel(
        type: type,
        status: _MockHomeCardStatus.completed,
        summary: summary,
        subtitle: '결과 보기 · 정답 ${summary.correctCount}/${summary.plannedItems}',
      );
    }

    return _MockCardUiModel(
      type: type,
      status: _MockHomeCardStatus.inProgress,
      summary: summary,
      subtitle:
          '이어하기 · ${summary.completedItems}/${summary.plannedItems} '
          '(총 $plannedItems)',
    );
  }

  void _handleMockCardTap({
    required BuildContext context,
    required _MockCardUiModel cardModel,
    required VoidCallback fallbackOpenFlow,
  }) {
    if (cardModel.status != _MockHomeCardStatus.completed ||
        cardModel.summary == null) {
      fallbackOpenFlow();
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MockExamResultScreen(
          mockSessionId: cardModel.summary!.sessionId,
          examTitle: switch (cardModel.type) {
            MockExamType.weekly => '주간 모의고사',
            MockExamType.monthly => '월간 모의고사',
          },
        ),
      ),
    );
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
          _showImportSizeLimitSnackBar(context);
          return;
        }
      } catch (_) {
        // Proceed. Repository-level raw length guards still apply.
      }

      final payload = await LimitedUtf8Reader.read(
        file.openRead(),
        maxBytes: DbTextLimits.reportImportMaxBytes,
        path: 'importFile',
      );
      final source = file.path.isEmpty ? 'shared_report.json' : file.path;
      await ref
          .read(sharedReportsRepositoryProvider)
          .importFromJson(source: source, payloadJson: payload);

      ref.invalidate(sharedReportSummariesProvider);

      if (!context.mounted) {
        return;
      }
      AppSnackbars.showSuccess(context, AppCopyKo.reportImportSuccess);
    } on FormatException catch (error) {
      if (!context.mounted) {
        return;
      }
      if (_isImportSizeLimitError(error)) {
        _showImportSizeLimitSnackBar(context);
        return;
      }
      AppSnackbars.showWarning(
        context,
        '${AppCopyKo.reportImportInvalid}\n$error',
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppSnackbars.showError(
        context,
        '${AppCopyKo.reportImportFailed}\n$error',
      );
    }
  }

  bool _isImportSizeLimitError(FormatException error) {
    return error.message == 'File exceeds max bytes at "importFile".';
  }

  void _showImportSizeLimitSnackBar(BuildContext context) {
    final maxMb = (DbTextLimits.reportImportMaxBytes / (1024 * 1024))
        .toStringAsFixed(0);
    AppSnackbars.showWarning(
      context,
      AppCopyKo.importSizeExceeded(maxMb: maxMb),
    );
  }
}

enum _MockHomeCardStatus { notStarted, inProgress, completed }

class _MockCardUiModel {
  const _MockCardUiModel({
    required this.type,
    required this.status,
    required this.subtitle,
    this.summary,
  });

  final MockExamType type;
  final _MockHomeCardStatus status;
  final String subtitle;
  final MockExamSessionSummary? summary;
}

class _ParentHomeContent extends ConsumerWidget {
  const _ParentHomeContent({required this.onImportReport});

  final Future<void> Function() onImportReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(sharedReportSummariesProvider);
    final isRefreshing = summariesAsync.isLoading && summariesAsync.hasValue;

    return Stack(
      children: [
        ListView(
          children: [
            Text('가정 리포트', style: AppTypography.title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '학생이 공유한 JSON 리포트를 가져와서 학습 추이를 확인하세요.',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
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
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => const _ParentHomeLoadingSkeleton(),
              error: (error, _) => Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text('${AppCopyKo.loadFailed('리포트 목록')}\n$error'),
              ),
              data: (summaries) {
                if (summaries.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text(AppCopyKo.emptyImportedReports),
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
        ),
        if (isRefreshing)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
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
        title: Text(
          summary.studentDisplayName ?? summary.source,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${summary.latestDayKey ?? '-'} · $trackLabel · 오답 ${summary.totalWrongCount}개',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: '리포트 메뉴',
              button: true,
              child: PopupMenuButton<_ParentReportMenuAction>(
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

    final message = deleted
        ? AppCopyKo.reportDeleteSuccess
        : AppCopyKo.reportDeleteAlready;
    if (deleted) {
      AppSnackbars.showSuccess(context, message);
    } else {
      AppSnackbars.showWarning(context, message);
    }
  }
}

class _HomeLoadingSkeleton extends StatelessWidget {
  const _HomeLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey<String>('home-loading-skeleton'),
      children: const [
        SkeletonLine(width: 180, height: 28),
        SizedBox(height: AppSpacing.xs),
        SkeletonLine(width: 240),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLine(width: 120, height: 14),
              SizedBox(height: AppSpacing.xs),
              SkeletonLine(width: 220, height: 14),
              SizedBox(height: AppSpacing.md),
              SkeletonLine(height: 42, radius: AppRadius.buttonPill),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLine(width: 120),
              SizedBox(height: AppSpacing.sm),
              SkeletonLine(height: 94, radius: AppRadius.md),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParentHomeLoadingSkeleton extends StatelessWidget {
  const _ParentHomeLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('parent-home-loading-skeleton'),
      children: const [
        SkeletonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLine(height: 42, radius: AppRadius.buttonPill),
              SizedBox(height: AppSpacing.sm),
              SkeletonLine(width: 150),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        SkeletonListTile(),
        SizedBox(height: AppSpacing.sm),
        SkeletonListTile(),
        SizedBox(height: AppSpacing.sm),
        SkeletonListTile(),
      ],
    );
  }
}
