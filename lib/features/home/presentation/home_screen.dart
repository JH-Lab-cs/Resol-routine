import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/domain_enums.dart';
import '../../../core/ui/app_copy_ko.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/components/hero_progress_card.dart';
import '../../../core/ui/components/routine_card.dart';
import '../../../core/ui/components/section_title.dart';
import '../../../core/ui/components/skeleton.dart';
import '../../dev/application/dev_tools_providers.dart';
import '../../family/application/family_providers.dart';
import '../../my/application/profile_ui_prefs_provider.dart';
import '../../my/application/my_stats_providers.dart';
import '../../mock_exam/application/mock_exam_providers.dart';
import '../../mock_exam/data/mock_exam_session_repository.dart';
import '../../mock_exam/presentation/mock_exam_result_screen.dart';
import '../../parent/application/parent_ui_providers.dart';
import '../../parent/presentation/parent_ui_helpers.dart';
import '../../report/application/parent_report_providers.dart';
import '../../report/data/parent_report_models.dart';
import '../../report/presentation/parent_report_screen.dart';
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
    required this.onOpenWrongReview,
    required this.onOpenMy,
    this.onOpenDevReports,
  });

  final VoidCallback onOpenQuiz;
  final VoidCallback onOpenWeeklyMockExam;
  final VoidCallback onOpenMonthlyMockExam;
  final VoidCallback onOpenVocab;
  final VoidCallback onOpenTodayVocabQuiz;
  final VoidCallback onOpenWrongNotes;
  final VoidCallback onOpenWrongReview;
  final VoidCallback onOpenMy;
  final VoidCallback? onOpenDevReports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settings.userSettingsProvider);

    return AppPageBody(
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
            return _ParentHomeContent(onOpenDevReports: onOpenDevReports);
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
          final statsAsync = ref.watch(myStatsProvider(selectedTrack));
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
              final attendanceStreakDays =
                  statsAsync.valueOrNull?.attendanceStreakDays ?? 0;
              final studentName = displayName.trim().isEmpty
                  ? '사용자'
                  : displayName.trim();

              return Stack(
                children: [
                  ListView(
                    children: [
                      Text(
                        '반가워요, $studentName 학생! 👋',
                        style: AppTypography.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '오늘도 화이팅!',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: Text(
                                '학습 학년 · 듣기 ${profilePrefs.listeningGradeLabel} · 독해 ${profilePrefs.readingGradeLabel}',
                                style: AppTypography.label.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _AttendanceStreakChip(
                            attendanceStreakDays: attendanceStreakDays,
                            compact: true,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          InkWell(
                            onTap: onOpenMy,
                            borderRadius: BorderRadius.circular(
                              AppRadius.buttonPill,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
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
                      const SectionTitle(title: '나의 학습 공간'),
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
                            title: '오답 노트',
                            subtitle: '틀린 문항 해설 보기',
                            icon: Icons.assignment_late_rounded,
                            onTap: onOpenWrongNotes,
                          ),
                          RoutineCard(
                            title: '오답 복습',
                            subtitle: '실수 원인 점검',
                            icon: Icons.replay_circle_filled_rounded,
                            onTap: onOpenWrongReview,
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
        subtitle: defaultDescription,
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
}

class _AttendanceStreakChip extends StatelessWidget {
  const _AttendanceStreakChip({
    required this.attendanceStreakDays,
    this.compact = false,
  });

  final int attendanceStreakDays;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? AppSpacing.xs : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0DA),
        borderRadius: BorderRadius.circular(AppRadius.buttonPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: compact ? 16 : 18,
            color: AppColors.streak,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            '$attendanceStreakDays일 연속',
            style: (compact ? AppTypography.label : AppTypography.body)
                .copyWith(color: AppColors.streak, fontWeight: FontWeight.w700),
          ),
        ],
      ),
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
  const _ParentHomeContent({this.onOpenDevReports});

  final VoidCallback? onOpenDevReports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyLinksAsync = ref.watch(familyLinksProvider);
    final children = ref.watch(parentLinkedChildrenProvider);
    final selectedChildId = ref.watch(selectedParentChildIdProvider);
    final showDevButton = ref.watch(devToolsVisibleProvider);
    ParentLinkedChild? selectedChild;
    for (final child in children) {
      if (child.id == selectedChildId) {
        selectedChild = child;
        break;
      }
    }
    final activeChild =
        selectedChild ?? (children.isEmpty ? null : children[0]);

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.mdLg,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '자녀 선택',
                style: AppTypography.section.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 118,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: children.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) {
                    if (index == children.length) {
                      return _ParentAddChildSelector(
                        onTap: () => showAddChildDialog(context, ref),
                      );
                    }

                    final child = children[index];
                    final selected = child.id == (activeChild?.id);
                    return _ParentChildSelector(
                      child: child,
                      selected: selected,
                      onTap: () {
                        ref.read(selectedParentChildIdProvider.notifier).state =
                            child.id;
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Text('학습 리포트', style: AppTypography.title),
            const Spacer(),
            if (activeChild != null)
              Text(
                activeChild.displayName,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        familyLinksAsync.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                '${AppCopyKo.loadFailed('가족 연결 정보')}\n$error',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          data: (_) => _ParentReportCard(
            activeChild: activeChild,
            showDevButton: showDevButton && onOpenDevReports != null,
            onOpenDevReports: onOpenDevReports,
          ),
        ),
      ],
    );
  }
}

class _ParentChildSelector extends StatelessWidget {
  const _ParentChildSelector({
    required this.child,
    required this.selected,
    required this.onTap,
  });

  final ParentLinkedChild child;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = child.displayName.isEmpty
        ? '?'
        : child.displayName.substring(0, 1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? const Color(0xFF2993E7)
                    : const Color(0xFFF0F2FF),
                border: Border.all(
                  color: selected ? AppColors.textPrimary : AppColors.border,
                  width: selected ? 4 : 1.5,
                ),
              ),
              child: Text(
                initial,
                style: AppTypography.display.copyWith(
                  color: selected ? Colors.white : AppColors.primary,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: 76,
              child: Text(
                child.displayName,
                style: AppTypography.body,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentAddChildSelector extends StatelessWidget {
  const _ParentAddChildSelector({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFCCD0DA)),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 36,
                color: Color(0xFF9EA2AD),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const SizedBox(
              width: 76,
              child: Text(
                '추가',
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentReportCard extends ConsumerWidget {
  const _ParentReportCard({
    required this.activeChild,
    required this.showDevButton,
    required this.onOpenDevReports,
  });

  final ParentLinkedChild? activeChild;
  final bool showDevButton;
  final VoidCallback? onOpenDevReports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(parentReportSummaryProvider);

    return summaryAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => _ParentReportMessageCard(
        message: parentReportErrorMessage(error),
        trailing: _buildDevButton(),
      ),
      data: (state) {
        if (state.emptyReason == ParentReportEmptyReason.noLinkedChild) {
          return _ParentReportMessageCard(
            message: AppCopyKo.parentReportNoLinkedChild,
            trailing: _buildDevButton(),
          );
        }
        if (state.emptyReason == ParentReportEmptyReason.noData) {
          return _ParentReportMessageCard(
            message: AppCopyKo.parentReportNoData,
            trailing: _buildDevButton(),
          );
        }

        final summary = state.summary!;
        final child = activeChild;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.mdLg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('최근 학습 활동', style: AppTypography.section),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (summary.dailySummary case final daily?)
                    _ParentSummaryChip(
                      label: '일간 ${daily.correctCount}/${daily.answeredCount}',
                      icon: Icons.today_rounded,
                    ),
                  if (summary.vocabSummary case final vocab?)
                    _ParentSummaryChip(
                      label: '단어 ${vocab.correctCount}/${vocab.totalCount}',
                      icon: Icons.spellcheck_rounded,
                    ),
                  if (summary.weeklyMockSummary case final weekly?)
                    _ParentSummaryChip(
                      label:
                          '주간 모의 ${weekly.listeningCorrectCount + weekly.readingCorrectCount}/${weekly.completedItems}',
                      icon: Icons.quiz_rounded,
                    ),
                  if (summary.monthlyMockSummary case final monthly?)
                    _ParentSummaryChip(
                      label:
                          '월간 모의 ${monthly.listeningCorrectCount + monthly.readingCorrectCount}/${monthly.completedItems}',
                      icon: Icons.fact_check_rounded,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (summary.recentActivity.isEmpty)
                Text(
                  AppCopyKo.parentReportNoActivity,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                Column(
                  children: [
                    for (final activity in summary.recentActivity.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.history_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                _parentActivityLabel(activity),
                                style: AppTypography.body,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey<String>(
                        'parent-home-report-detail-button',
                      ),
                      onPressed: child == null
                          ? null
                          : () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => ParentReportDetailScreen(
                                    childId: child.id,
                                    childDisplayName: child.displayName,
                                  ),
                                ),
                              );
                            },
                      child: const Text('리포트 상세 보기'),
                    ),
                  ),
                  if (showDevButton && onOpenDevReports != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      key: const ValueKey<String>(
                        'parent-home-dev-reports-button',
                      ),
                      onPressed: onOpenDevReports,
                      icon: const Icon(Icons.developer_mode_rounded),
                      tooltip: '개발자 리포트 테스트',
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget? _buildDevButton() {
    if (!showDevButton || onOpenDevReports == null) {
      return null;
    }
    return OutlinedButton.icon(
      key: const ValueKey<String>('parent-home-dev-reports-button'),
      onPressed: onOpenDevReports,
      icon: const Icon(Icons.developer_mode_rounded),
      label: const Text('개발자 리포트 테스트'),
    );
  }
}

class _ParentReportMessageCard extends StatelessWidget {
  const _ParentReportMessageCard({required this.message, this.trailing});

  final String message;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.mdLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          if (trailing != null) ...[
            const SizedBox(height: AppSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _ParentSummaryChip extends StatelessWidget {
  const _ParentSummaryChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(AppRadius.buttonPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xxs),
          Text(label, style: AppTypography.label),
        ],
      ),
    );
  }
}

String _parentActivityLabel(ParentReportActivity activity) {
  switch (activity.activityType) {
    case 'DAILY':
      return '${activity.dayKey ?? ''} 일간 학습 · 정답 ${activity.correctCount ?? 0} · 오답 ${activity.wrongCount ?? 0}';
    case 'VOCAB':
      return '${activity.dayKey ?? ''} 단어 퀴즈 · 정답 ${activity.correctCount ?? 0} · 오답 ${activity.wrongCount ?? 0}';
    case 'WEEKLY_MOCK':
      return '${activity.periodKey ?? ''} 주간 모의고사 · 오답 ${activity.wrongCount ?? 0}';
    case 'MONTHLY_MOCK':
      return '${activity.periodKey ?? ''} 월간 모의고사 · 오답 ${activity.wrongCount ?? 0}';
    case 'WEEKLY_REPORT':
      return '${activity.periodKey ?? ''} 주간 리포트 · 정답 ${activity.correctCount ?? 0}';
    case 'MONTHLY_REPORT':
      return '${activity.periodKey ?? ''} 월간 리포트 · 정답 ${activity.correctCount ?? 0}';
  }
  return activity.activityType;
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
