import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/domain_enums.dart';
import '../../../core/ui/app_copy_ko.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/label_maps.dart';
import '../application/mock_exam_providers.dart';
import '../data/mock_exam_attempt_repository.dart';
import '../../wrong_notes/presentation/wrong_notes_screen.dart';

class MockExamResultScreen extends ConsumerStatefulWidget {
  const MockExamResultScreen({
    super.key,
    required this.mockSessionId,
    required this.examTitle,
  });

  final int mockSessionId;
  final String examTitle;

  @override
  ConsumerState<MockExamResultScreen> createState() =>
      _MockExamResultScreenState();
}

class _MockExamResultScreenState extends ConsumerState<MockExamResultScreen> {
  bool _onlyWrong = false;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(
      mockExamResultSummaryProvider(widget.mockSessionId),
    );
    final reviewItemsAsync = ref.watch(
      mockExamReviewItemsProvider(widget.mockSessionId),
    );

    return Scaffold(
      appBar: AppBar(title: Text('${widget.examTitle} 결과')),
      body: switch ((summaryAsync, reviewItemsAsync)) {
        (AsyncValue(hasError: true), _) => _buildError(summaryAsync.error!),
        (_, AsyncValue(hasError: true)) => _buildError(reviewItemsAsync.error!),
        (AsyncValue(hasValue: true), AsyncValue(hasValue: true)) =>
          _buildContent(
            summary: summaryAsync.requireValue,
            reviewItems: reviewItemsAsync.requireValue,
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildError(Object error) {
    return Center(child: Text('${AppCopyKo.loadFailed('모의고사 결과')}\n$error'));
  }

  Widget _buildContent({
    required MockExamResultSummary summary,
    required List<MockReviewItem> reviewItems,
  }) {
    final answeredItems = reviewItems
        .where((item) => item.isAnswered)
        .toList(growable: false);
    final visibleItems = _onlyWrong
        ? answeredItems.where((item) => !item.isCorrect).toList(growable: false)
        : answeredItems;
    final total = summary.plannedItems;
    final correct = summary.listeningCorrectCount + summary.readingCorrectCount;
    final wrong = summary.wrongCount;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            gradient: const LinearGradient(
              colors: <Color>[AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.examTitle} 결과',
                style: AppTypography.title.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '정답 $correct/$total · 오답 $wrong/$total',
                style: AppTypography.body.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '기간 ${_periodText(summary)} · 소요시간 ${_elapsedText(summary.elapsed)}',
                style: AppTypography.label.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.28,
          children: [
            _ResultMetricCard(
              label: '듣기 정답',
              value: '${summary.listeningCorrectCount}개',
            ),
            _ResultMetricCard(
              label: '독해 정답',
              value: '${summary.readingCorrectCount}개',
            ),
            _ResultMetricCard(label: '오답 개수', value: '${summary.wrongCount}개'),
            _ResultMetricCard(
              label: '오답 이유 Top 1',
              value: summary.topWrongReasonTag == null
                  ? '없음'
                  : displayWrongReasonTag(summary.topWrongReasonTag!.dbValue),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              children: [
                SwitchListTile(
                  key: const ValueKey<String>('mock-result-only-wrong-toggle'),
                  value: _onlyWrong,
                  onChanged: (value) {
                    setState(() {
                      _onlyWrong = value;
                    });
                  },
                  title: const Text('오답만 보기'),
                  dense: true,
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: Text('오답노트')),
                          body: const WrongNotesScreen(),
                        ),
                      ),
                    );
                  },
                  child: const Text('오답노트 열기'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('문항 리뷰', style: AppTypography.section),
        const SizedBox(height: AppSpacing.xs),
        if (visibleItems.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                _onlyWrong ? AppCopyKo.emptyWrongNotes : AppCopyKo.emptyData,
              ),
            ),
          )
        else
          ...visibleItems.map((item) => _buildReviewItem(item)),
      ],
    );
  }

  Widget _buildReviewItem(MockReviewItem item) {
    final isWrong = !item.isCorrect;
    final canOpenExplanation = isWrong && item.attemptId != null;

    return Card(
      key: ValueKey<String>('mock-review-item-${item.orderIndex}'),
      child: ListTile(
        onTap: canOpenExplanation
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        WrongNoteDetailScreen(attemptId: item.attemptId!),
                  ),
                );
              }
            : null,
        title: Text(
          '문항 ${item.orderIndex + 1} · ${displaySkill(item.skill.dbValue)} · ${item.typeTag}',
        ),
        subtitle: Text(item.questionId),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: isWrong
                ? AppColors.danger.withValues(alpha: 0.12)
                : AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.buttonPill),
          ),
          child: Text(
            isWrong ? '오답' : '정답',
            style: AppTypography.label.copyWith(
              color: isWrong ? AppColors.danger : AppColors.success,
            ),
          ),
        ),
      ),
    );
  }

  String _periodText(MockExamResultSummary summary) {
    switch (summary.examType) {
      case MockExamType.weekly:
        return '주간 ${summary.periodKey}';
      case MockExamType.monthly:
        return '월간 ${summary.periodKey}';
    }
  }

  String _elapsedText(Duration? elapsed) {
    if (elapsed == null) {
      return '-';
    }
    final totalSeconds = elapsed.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes <= 0) {
      return '$seconds초';
    }
    return '$minutes분 $seconds초';
  }
}

class _ResultMetricCard extends StatelessWidget {
  const _ResultMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: AppTypography.section),
          ],
        ),
      ),
    );
  }
}
