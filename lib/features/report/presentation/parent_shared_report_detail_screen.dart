import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/domain_enums.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/label_maps.dart';
import '../application/report_providers.dart';
import '../data/models/report_schema_v1.dart';
import '../data/shared_reports_repository.dart';

class ParentSharedReportDetailScreen extends ConsumerStatefulWidget {
  const ParentSharedReportDetailScreen({
    super.key,
    required this.sharedReportId,
  });

  final int sharedReportId;

  @override
  ConsumerState<ParentSharedReportDetailScreen> createState() =>
      _ParentSharedReportDetailScreenState();
}

class _ParentSharedReportDetailScreenState
    extends ConsumerState<ParentSharedReportDetailScreen> {
  final Set<int> _expandedDayIndices = <int>{};

  void _toggleDayExpanded(int index) {
    setState(() {
      if (!_expandedDayIndices.add(index)) {
        _expandedDayIndices.remove(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      sharedReportByIdProvider(widget.sharedReportId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('리포트 상세')),
      body: AppPageBody(
        child: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              '리포트를 불러오지 못했습니다.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
          data: (detail) {
            final report = detail.report;
            final totalSolved = report.days.fold<int>(
              0,
              (value, day) => value + day.solvedCount,
            );
            final totalWrong = report.days.fold<int>(
              0,
              (value, day) => value + day.wrongCount,
            );

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _HeaderCard(
                    detail: detail,
                    totalSolved: totalSolved,
                    totalWrong: totalWrong,
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.md),
                ),
                SliverToBoxAdapter(
                  child: Text('일자별 요약', style: AppTypography.section),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.sm),
                ),
                if (report.days.isEmpty)
                  const SliverToBoxAdapter(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Text('리포트에 일자 데이터가 없습니다.'),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final day = report.days[index];
                      return _DaySummaryCard(
                        day: day,
                        expanded: _expandedDayIndices.contains(index),
                        onToggleExpanded: () => _toggleDayExpanded(index),
                      );
                    }, childCount: report.days.length),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.lg),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.detail,
    required this.totalSolved,
    required this.totalWrong,
  });

  final SharedReportRecord detail;
  final int totalSolved;
  final int totalWrong;

  @override
  Widget build(BuildContext context) {
    final student = detail.report.student;
    final track =
        student.track?.dbValue ??
        (detail.report.days.isEmpty
            ? null
            : detail.report.days.first.track.dbValue);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('파일: ${detail.source}', style: AppTypography.body),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '생성 시각: ${_formatDateTime(detail.report.generatedAt)}',
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '학생: ${student.displayName ?? '-'} · 역할: ${student.role ?? '-'} · 트랙: ${track == null ? '-' : displayTrack(track)}',
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _pill('총 풀이 $totalSolved문항'),
                _pill('총 오답 $totalWrong문항'),
                _pill('일수 ${detail.report.days.length}일'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2FF),
        borderRadius: BorderRadius.circular(AppRadius.buttonPill),
      ),
      child: Text(
        text,
        style: AppTypography.label.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({
    required this.day,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final ReportDay day;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onToggleExpanded,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_formatDayKey(day.dayKey)} · ${displayTrack(day.track.dbValue)}',
                      style: AppTypography.section,
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '풀이 ${day.solvedCount}/6 · 오답 ${day.wrongCount} · 듣기 정답 ${day.listeningCorrect}/3 · 독해 정답 ${day.readingCorrect}/3',
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.xs),
              if (day.wrongReasonCounts.isNotEmpty)
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final entry in day.wrongReasonCounts.entries)
                      _tag(
                        '${displayWrongReasonTag(entry.key.dbValue)} ${entry.value}회',
                      ),
                  ],
                ),
              if (expanded) ...[
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.sm),
                ...day.questions.map((question) {
                  final wrongReason = question.wrongReasonTag;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      wrongReason == null
                          ? '${displaySkill(question.skill.dbValue)} ${question.typeTag} · ${question.isCorrect ? '정답' : '오답'} · ID ${question.questionId}'
                          : '${displaySkill(question.skill.dbValue)} ${question.typeTag} · 오답(${displayWrongReasonTag(wrongReason.dbValue)}) · ID ${question.questionId}',
                      style: AppTypography.label,
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FA),
        borderRadius: BorderRadius.circular(AppRadius.buttonPill),
      ),
      child: Text(
        text,
        style: AppTypography.label.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  String _formatDayKey(String dayKey) {
    return '${dayKey.substring(0, 4)}-${dayKey.substring(4, 6)}-${dayKey.substring(6, 8)}';
  }
}
