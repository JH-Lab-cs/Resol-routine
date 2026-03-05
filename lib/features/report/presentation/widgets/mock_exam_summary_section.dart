import 'package:flutter/material.dart';

import '../../../../core/domain/domain_enums.dart';
import '../../../../core/ui/app_tokens.dart';
import '../../../../core/ui/label_maps.dart';
import '../../data/models/report_schema_v1.dart';

class MockExamSummarySection extends StatefulWidget {
  const MockExamSummarySection({
    super.key,
    required this.mockExams,
    this.title = '모의고사 요약',
    this.maxVisiblePerType = 10,
  });

  final ReportMockExams? mockExams;
  final String title;
  final int maxVisiblePerType;

  @override
  State<MockExamSummarySection> createState() => _MockExamSummarySectionState();
}

class _MockExamSummarySectionState extends State<MockExamSummarySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final weekly = widget.mockExams?.weekly ?? const <ReportMockExamSummary>[];
    final monthly =
        widget.mockExams?.monthly ?? const <ReportMockExamSummary>[];
    final totalCount = weekly.length + monthly.length;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          setState(() {
            _expanded = !_expanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.title, style: AppTypography.section),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '주간 ${weekly.length}회 · 월간 ${monthly.length}회',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (_expanded) ...[
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.sm),
                if (totalCount == 0)
                  Text(
                    '완료한 모의고사 기록이 없습니다.',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else ...[
                  if (weekly.isNotEmpty)
                    _TypeSummaryList(
                      title: '주간 모의고사',
                      entries: weekly,
                      maxVisible: widget.maxVisiblePerType,
                    ),
                  if (weekly.isNotEmpty && monthly.isNotEmpty)
                    const SizedBox(height: AppSpacing.sm),
                  if (monthly.isNotEmpty)
                    _TypeSummaryList(
                      title: '월간 모의고사',
                      entries: monthly,
                      maxVisible: widget.maxVisiblePerType,
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeSummaryList extends StatelessWidget {
  const _TypeSummaryList({
    required this.title,
    required this.entries,
    required this.maxVisible,
  });

  final String title;
  final List<ReportMockExamSummary> entries;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final boundedMaxVisible = maxVisible < 1 ? 1 : maxVisible;
    final visibleEntries = entries
        .take(boundedMaxVisible)
        .toList(growable: false);
    final overflowCount = entries.length - visibleEntries.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title · 최근 ${visibleEntries.length}회',
          style: AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final entry in visibleEntries) ...[
          _SummaryTile(entry: entry),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (overflowCount > 0)
          Text(
            '외 $overflowCount회',
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.entry});

  final ReportMockExamSummary entry;

  @override
  Widget build(BuildContext context) {
    final percent = _formatAccuracy(
      correctCount: entry.correctCount,
      totalCount: entry.totalCount,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FA),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.periodKey} · ${displayTrack(entry.track.dbValue)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '정답 ${entry.correctCount}/${entry.totalCount} · $percent',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '완료 ${_formatCompletedAt(entry.completedAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

String _formatCompletedAt(DateTime value) {
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatAccuracy({required int correctCount, required int totalCount}) {
  if (totalCount <= 0) {
    return '0%';
  }
  final percent = ((correctCount * 100) / totalCount).round();
  return '$percent%';
}
