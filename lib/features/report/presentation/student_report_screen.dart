import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/domain/domain_enums.dart';
import '../../../core/ui/app_copy_ko.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/components/app_snackbars.dart';
import '../../../core/ui/components/skeleton.dart';
import '../../../core/ui/label_maps.dart';
import '../../../core/time/day_key.dart';
import '../application/report_providers.dart';
import '../data/models/report_schema_v1.dart';
import 'widgets/mock_exam_summary_section.dart';
import 'widgets/vocab_bookmarks_section.dart';
import 'widgets/vocab_wrong_words_section.dart';

class StudentReportScreen extends ConsumerStatefulWidget {
  const StudentReportScreen({super.key, required this.track});

  final String track;

  @override
  ConsumerState<StudentReportScreen> createState() =>
      _StudentReportScreenState();
}

class _StudentReportScreenState extends ConsumerState<StudentReportScreen> {
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(
      studentCumulativeReportProvider(widget.track),
    );
    final isRefreshing = reportAsync.isLoading && reportAsync.hasValue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('리포트'),
        actions: [
          Semantics(
            label: '리포트 공유',
            button: true,
            child: IconButton(
              tooltip: '리포트 공유',
              onPressed: _isSharing
                  ? null
                  : () {
                      _shareReport();
                    },
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded),
            ),
          ),
        ],
      ),
      body: AppPageBody(
        child: Stack(
          children: [
            reportAsync.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => const _StudentReportLoadingSkeleton(),
              error: (error, _) => Center(
                child: Text(
                  '${AppCopyKo.loadFailed('리포트')}\n$error',
                  textAlign: TextAlign.center,
                ),
              ),
              data: (report) => _ReportBody(
                track: widget.track,
                report: report,
                onShare: _isSharing ? null : _shareReport,
              ),
            ),
            if (isRefreshing)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareReport() async {
    setState(() {
      _isSharing = true;
    });

    File? exportFile;
    try {
      final exportPayload = await ref
          .read(reportExportRepositoryProvider)
          .buildExportPayload(track: widget.track);

      final tempDirectory = await getTemporaryDirectory();
      final filePath = p.join(tempDirectory.path, exportPayload.fileName);
      exportFile = File(filePath);

      await exportFile.writeAsString(exportPayload.jsonPayload, flush: true);

      final result = await SharePlus.instance.share(
        ShareParams(
          title: exportPayload.fileName,
          files: <XFile>[XFile(exportFile.path)],
          subject: 'ResolRoutine report export',
          text: 'IDs and metadata only. No copyrighted content included.',
        ),
      );

      if (!mounted) {
        return;
      }

      if (result.status == ShareResultStatus.success) {
        AppSnackbars.showSuccess(context, AppCopyKo.reportShareSuccess);
      } else {
        AppSnackbars.showCanceled(context);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackbars.showError(context, '${AppCopyKo.reportShareFailed}\n$error');
    } finally {
      if (exportFile != null) {
        try {
          await exportFile.delete();
        } catch (_) {
          // Ignore temp file cleanup errors.
        }
      }

      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.track,
    required this.report,
    required this.onShare,
  });

  final String track;
  final ReportSchema report;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final todayKey = formatDayKey(DateTime.now());
    final today = _findDayByKey(report.days, todayKey);
    final todayVocabQuiz = today?.vocabQuiz;
    final bookmarkedVocabIds =
        report.vocabBookmarks?.bookmarkedVocabIds ?? const <String>[];
    final customLemmaById =
        report.customVocab?.lemmasById ?? const <String, String>{};
    final todayVocabAccuracy = todayVocabQuiz == null
        ? null
        : _formatAccuracy(
            correctCount: todayVocabQuiz.correctCount,
            totalCount: todayVocabQuiz.totalCount,
          );

    return ListView(
      children: [
        Text('학습 리포트', style: AppTypography.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '내보내기 파일에는 문제 원문/지문/해설 텍스트가 포함되지 않습니다.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('오늘 요약', style: AppTypography.section),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  today == null
                      ? '오늘 풀이 데이터가 없습니다.'
                      : todayVocabQuiz == null
                      ? '풀이 문항 ${today.solvedCount}/6 · 오답 ${today.wrongCount}개'
                      : '풀이 문항 ${today.solvedCount}/6 · 오답 ${today.wrongCount}개 · 단어시험 ${todayVocabQuiz.correctCount}/${todayVocabQuiz.totalCount} · $todayVocabAccuracy',
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '트랙 ${displayTrack(track)} · 누적 ${report.days.length}일',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (todayVocabQuiz != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '틀린 단어 ${todayVocabQuiz.wrongVocabIds.length}개',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  VocabWrongWordsSection(
                    wrongVocabIds: todayVocabQuiz.wrongVocabIds,
                    customLemmaById: customLemmaById,
                    maxVisible: 6,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonalIcon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('JSON 리포트 공유'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        VocabBookmarksSection(
          bookmarkedVocabIds: bookmarkedVocabIds,
          customLemmaById: customLemmaById,
        ),
        const SizedBox(height: AppSpacing.md),
        MockExamSummarySection(mockExams: report.mockExams),
        const SizedBox(height: AppSpacing.md),
        if (today == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('오늘 루틴을 풀면 여기에서 문항 메타데이터를 확인할 수 있어요.'),
            ),
          )
        else ...[
          _TodayScoreCard(day: today),
          const SizedBox(height: AppSpacing.md),
          Text('오늘 문항 메타데이터', style: AppTypography.section),
          const SizedBox(height: AppSpacing.sm),
          ...today.questions.map((question) {
            final wrongReason = question.wrongReasonTag;
            final resultLabel = question.isCorrect ? '정답' : '오답';
            final resultColor = question.isCorrect
                ? AppColors.success
                : AppColors.warning;

            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                title: Text(
                  '${displaySkill(question.skill.dbValue)} · ${question.typeTag} · $resultLabel',
                  style: AppTypography.body.copyWith(color: resultColor),
                ),
                subtitle: Text(
                  wrongReason == null
                      ? '문항 ID: ${question.questionId}'
                      : '문항 ID: ${question.questionId}\n오답 이유: ${displayWrongReasonTag(wrongReason.dbValue)}',
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  ReportDay? _findDayByKey(List<ReportDay> days, String dayKey) {
    for (final day in days) {
      if (day.dayKey == dayKey) {
        return day;
      }
    }
    return null;
  }
}

class _StudentReportLoadingSkeleton extends StatelessWidget {
  const _StudentReportLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey<String>('student-report-loading-skeleton'),
      children: const [
        SkeletonLine(width: 160, height: 28),
        SizedBox(height: AppSpacing.xs),
        SkeletonLine(width: 260),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLine(width: 100, height: 20),
              SizedBox(height: AppSpacing.sm),
              SkeletonLine(width: 240),
              SizedBox(height: AppSpacing.xs),
              SkeletonLine(width: 180),
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
              SkeletonLine(width: 140, height: 20),
              SizedBox(height: AppSpacing.sm),
              SkeletonLine(height: 120, radius: AppRadius.md),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodayScoreCard extends StatelessWidget {
  const _TodayScoreCard({required this.day});

  final ReportDay day;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_formatDayKey(day.dayKey)} 리포트',
              style: AppTypography.section,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _pill('듣기 정답 ${day.listeningCorrect}/3'),
                _pill('독해 정답 ${day.readingCorrect}/3'),
                _pill('오답 ${day.wrongCount}개'),
                if (day.vocabQuiz != null)
                  _pill(
                    '단어시험 ${day.vocabQuiz!.correctCount}/${day.vocabQuiz!.totalCount} · ${_formatAccuracy(correctCount: day.vocabQuiz!.correctCount, totalCount: day.vocabQuiz!.totalCount)}',
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (day.wrongReasonCounts.isEmpty)
              Text(
                '오답 이유 태그 없음',
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final entry in day.wrongReasonCounts.entries)
                    _pill(
                      '${displayWrongReasonTag(entry.key.dbValue)} ${entry.value}회',
                    ),
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

  String _formatDayKey(String dayKey) {
    return '${dayKey.substring(0, 4)}-${dayKey.substring(4, 6)}-${dayKey.substring(6, 8)}';
  }
}

String _formatAccuracy({required int correctCount, required int totalCount}) {
  if (totalCount <= 0) {
    return '0%';
  }
  final percent = ((correctCount * 100) / totalCount).round();
  return '$percent%';
}
