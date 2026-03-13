import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_copy_ko.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../application/parent_report_providers.dart';
import '../data/parent_report_models.dart';

class ParentReportDetailScreen extends ConsumerWidget {
  const ParentReportDetailScreen({
    super.key,
    required this.childId,
    required this.childDisplayName,
  });

  final String childId;
  final String childDisplayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(parentReportDetailProvider(childId));

    return Scaffold(
      appBar: AppBar(title: Text('$childDisplayName 리포트')),
      body: AppPageBody(
        child: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ParentReportErrorState(
            message: _parentReportErrorMessage(error),
            onRetry: () => ref.invalidate(parentReportDetailProvider(childId)),
          ),
          data: (detail) {
            if (!detail.hasAnyReportData) {
              return const _ParentReportEmptyState(
                message: AppCopyKo.parentReportNoData,
              );
            }
            return ListView(
              children: [
                _ParentReportHeadlineCard(
                  title: childDisplayName,
                  subtitle: detail.child.email,
                ),
                const SizedBox(height: AppSpacing.md),
                _SummaryGrid(detail: detail),
                const SizedBox(height: AppSpacing.md),
                _RecentTrendCard(points: detail.recentTrend),
                const SizedBox(height: AppSpacing.md),
                _RecentActivityCard(activities: detail.recentActivity),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ParentReportHeadlineCard extends StatelessWidget {
  const _ParentReportHeadlineCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

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
          Text(title, style: AppTypography.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.detail});

  final ParentReportDetail detail;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (detail.dailySummary case final daily?)
        _MetricCard(
          title: '일간 학습',
          primaryValue: '${daily.correctCount}/${daily.answeredCount}',
          subtitle: '${daily.dayKey} · 오답 ${daily.wrongCount}개',
          icon: Icons.today_rounded,
        ),
      if (detail.weeklySummary case final weekly?)
        _MetricCard(
          title: '주간 리포트',
          primaryValue: '${weekly.correctCount}/${weekly.answeredCount}',
          subtitle: '${weekly.referenceKey} · 오답 ${weekly.wrongCount}개',
          icon: Icons.calendar_view_week_rounded,
        ),
      if (detail.monthlySummary case final monthly?)
        _MetricCard(
          title: '월간 리포트',
          primaryValue: '${monthly.correctCount}/${monthly.answeredCount}',
          subtitle: '${monthly.referenceKey} · 오답 ${monthly.wrongCount}개',
          icon: Icons.calendar_month_rounded,
        ),
      if (detail.vocabSummary case final vocab?)
        _MetricCard(
          title: '단어 퀴즈',
          primaryValue: '${vocab.correctCount}/${vocab.totalCount}',
          subtitle: '${vocab.dayKey} · 오답 단어 ${vocab.wrongVocabCount}개',
          icon: Icons.spellcheck_rounded,
        ),
      if (detail.weeklyMockSummary case final weeklyMock?)
        _MetricCard(
          title: '주간 모의고사',
          primaryValue:
              '${weeklyMock.listeningCorrectCount + weeklyMock.readingCorrectCount}/${weeklyMock.completedItems}',
          subtitle: '${weeklyMock.periodKey} · 오답 ${weeklyMock.wrongCount}개',
          icon: Icons.quiz_rounded,
        ),
      if (detail.monthlyMockSummary case final monthlyMock?)
        _MetricCard(
          title: '월간 모의고사',
          primaryValue:
              '${monthlyMock.listeningCorrectCount + monthlyMock.readingCorrectCount}/${monthlyMock.completedItems}',
          subtitle: '${monthlyMock.periodKey} · 오답 ${monthlyMock.wrongCount}개',
          icon: Icons.fact_check_rounded,
        ),
    ];

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.06,
      children: cards,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.primaryValue,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String primaryValue;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const Spacer(),
          Text(title, style: AppTypography.label),
          const SizedBox(height: AppSpacing.xxs),
          Text(primaryValue, style: AppTypography.title),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RecentTrendCard extends StatelessWidget {
  const _RecentTrendCard({required this.points});

  final List<ParentReportTrendPoint> points;

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
          Text('최근 7일 추이', style: AppTypography.section),
          const SizedBox(height: AppSpacing.sm),
          if (points.isEmpty)
            Text(
              AppCopyKo.parentReportNoTrend,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            Column(
              children: [
                for (final point in points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 84,
                          child: Text(point.dayKey, style: AppTypography.label),
                        ),
                        Expanded(
                          child: Text(
                            '정답 ${point.correctCount} · 오답 ${point.wrongCount} · 총 ${point.answeredCount}',
                            style: AppTypography.body,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.activities});

  final List<ParentReportActivity> activities;

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
            AppCopyKo.parentReportRecentActivity,
            style: AppTypography.section,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (activities.isEmpty)
            Text(
              AppCopyKo.parentReportNoActivity,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            Column(
              children: [
                for (final activity in activities)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_rounded),
                    title: Text(_activityTitle(activity)),
                    subtitle: Text(_activitySubtitle(activity)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ParentReportEmptyState extends StatelessWidget {
  const _ParentReportEmptyState({required this.message});

  final String message;

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
      child: Text(
        message,
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _ParentReportErrorState extends StatelessWidget {
  const _ParentReportErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
          Text(message, style: AppTypography.body),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onRetry, child: const Text('다시 불러오기')),
        ],
      ),
    );
  }
}

String parentReportErrorMessage(Object error) =>
    _parentReportErrorMessage(error);

String _parentReportErrorMessage(Object error) {
  if (error is ParentReportRepositoryException) {
    switch (error.code) {
      case 'child_report_access_forbidden':
        return AppCopyKo.parentReportAccessDenied;
      case 'child_reports_subscription_required':
        return AppCopyKo.parentReportSubscriptionRequired;
      case 'invalid_response':
        return AppCopyKo.parentReportMalformedResponse;
      default:
        if (error.isServerUnavailable) {
          return AppCopyKo.parentReportServerUnavailable;
        }
    }
  }
  return AppCopyKo.parentReportLoadFailed;
}

String _activityTitle(ParentReportActivity activity) {
  switch (activity.activityType) {
    case 'DAILY':
      return '일간 학습';
    case 'WEEKLY_REPORT':
      return '주간 리포트';
    case 'MONTHLY_REPORT':
      return '월간 리포트';
    case 'VOCAB':
      return '단어 퀴즈';
    case 'WEEKLY_MOCK':
      return '주간 모의고사';
    case 'MONTHLY_MOCK':
      return '월간 모의고사';
  }
  return activity.activityType;
}

String _activitySubtitle(ParentReportActivity activity) {
  final key = activity.dayKey ?? activity.periodKey ?? '';
  final counts = <String>[
    if (activity.correctCount != null) '정답 ${activity.correctCount}',
    if (activity.wrongCount != null) '오답 ${activity.wrongCount}',
    if (activity.answeredCount != null) '총 ${activity.answeredCount}',
  ].join(' · ');
  if (key.isEmpty) {
    return counts;
  }
  if (counts.isEmpty) {
    return key;
  }
  return '$key · $counts';
}
