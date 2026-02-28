import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/domain_enums.dart';
import '../../../core/ui/app_copy_ko.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/components/section_title.dart';
import '../../../core/ui/label_maps.dart';
import '../../mock_exam/presentation/mock_exam_result_screen.dart';
import '../../today/data/today_quiz_repository.dart';
import '../application/wrong_note_providers.dart';
import '../data/wrong_note_repository.dart';
import 'wrong_notes_screen.dart';

class WrongReviewScreen extends ConsumerWidget {
  const WrongReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wrongNotesAsync = ref.watch(wrongNoteListProvider);

    return Material(
      color: AppColors.background,
      child: AppPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              title: '오답 복습',
              subtitle: '날짜별 오답 세션에서 문제를 다시 풀어보세요.',
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: wrongNotesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('${AppCopyKo.loadFailed('오답 복습')}\n$error'),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(child: Text(AppCopyKo.emptyWrongNotes));
                  }
                  final groups = _groupByDay(items);

                  return ListView.separated(
                    itemCount: groups.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return _WrongReviewGroupCard(group: group);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WrongReviewGroupCard extends StatelessWidget {
  const _WrongReviewGroupCard({required this.group});

  final _WrongReviewGroup group;

  @override
  Widget build(BuildContext context) {
    final tags = group.topTypeTags;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.mdLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.shortReviewTitle, style: AppTypography.title),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        '${group.items.length}문제',
                        style: AppTypography.section.copyWith(
                          fontSize: 34 / 1.8,
                          color: const Color(0xFFE9493D),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        tags.join(' '),
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            label: '${group.fullReviewTitle} 시작',
            button: true,
            child: GestureDetector(
              key: ValueKey<String>('wrong-review-open-${group.key}'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => _WrongReviewSessionScreen(group: group),
                  ),
                );
              },
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5FA),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 44,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WrongReviewSessionScreen extends ConsumerStatefulWidget {
  const _WrongReviewSessionScreen({required this.group});

  final _WrongReviewGroup group;

  @override
  ConsumerState<_WrongReviewSessionScreen> createState() =>
      _WrongReviewSessionScreenState();
}

class _WrongReviewSessionScreenState
    extends ConsumerState<_WrongReviewSessionScreen> {
  late Future<List<_WrongReviewItemDetail>> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadDetails();
  }

  @override
  void didUpdateWidget(covariant _WrongReviewSessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.key != widget.group.key) {
      _detailsFuture = _loadDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.group.fullReviewTitle)),
      body: FutureBuilder<List<_WrongReviewItemDetail>>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${AppCopyKo.loadFailed('오답 복습 세션')}\n${snapshot.error}',
              ),
            );
          }

          final details = snapshot.data ?? const <_WrongReviewItemDetail>[];
          if (details.isEmpty) {
            return const Center(child: Text(AppCopyKo.emptyWrongNotes));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: details.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = details[index];
              final wrongReason = item.detail.wrongReasonTag == null
                  ? '미선택'
                  : displayWrongReasonTag(item.detail.wrongReasonTag!.dbValue);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '문항 ${index + 1} · ${displaySkill(item.meta.skill.dbValue)} · ${item.meta.typeTag}',
                              style: AppTypography.section,
                            ),
                          ),
                          if (item.meta.mockSessionId != null &&
                              item.meta.mockType != null)
                            IconButton(
                              tooltip: AppCopyKo.wrongNoteOpenResult,
                              onPressed: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => MockExamResultScreen(
                                      mockSessionId: item.meta.mockSessionId!,
                                      examTitle: _mockExamLabel(
                                        item.meta.mockType!,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.assessment_outlined),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        item.detail.question.prompt,
                        style: AppTypography.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '오답 이유: $wrongReason',
                        style: AppTypography.label.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => _WrongReviewRetryScreen(
                                    detail: item.detail,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('다시 풀기'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => WrongNoteDetailScreen(
                                    attemptId: item.meta.attemptId,
                                  ),
                                ),
                              );
                            },
                            child: const Text('해설 보기'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<_WrongReviewItemDetail>> _loadDetails() async {
    final repository = ref.read(wrongNoteRepositoryProvider);
    final details = await Future.wait(
      widget.group.items.map((item) => repository.loadDetail(item.attemptId)),
    );

    return <_WrongReviewItemDetail>[
      for (var i = 0; i < widget.group.items.length; i++)
        _WrongReviewItemDetail(meta: widget.group.items[i], detail: details[i]),
    ];
  }
}

class _WrongReviewItemDetail {
  const _WrongReviewItemDetail({required this.meta, required this.detail});

  final WrongNoteListItem meta;
  final WrongNoteDetail detail;
}

class _WrongReviewRetryScreen extends StatefulWidget {
  const _WrongReviewRetryScreen({required this.detail});

  final WrongNoteDetail detail;

  @override
  State<_WrongReviewRetryScreen> createState() =>
      _WrongReviewRetryScreenState();
}

class _WrongReviewRetryScreenState extends State<_WrongReviewRetryScreen> {
  String? _selectedAnswer;
  bool _submitted = false;
  bool _isCorrect = false;

  @override
  Widget build(BuildContext context) {
    final question = widget.detail.question;
    final evidenceIds = question.evidenceSentenceIds.toSet();
    final dayKey = widget.detail.dayKey;
    final track = displayTrack(question.track.dbValue);

    return Scaffold(
      appBar: AppBar(title: const Text('다시 풀기')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            '$dayKey · $track · ${question.typeTag}',
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSourceArea(question, evidenceIds),
          const SizedBox(height: AppSpacing.md),
          Text(question.prompt, style: AppTypography.section),
          const SizedBox(height: AppSpacing.sm),
          ..._optionKeys.map((key) {
            final isCorrectAnswer = key == question.answerKey;
            final isSelected = key == _selectedAnswer;
            final selectedWrong = _submitted && isSelected && !_isCorrect;

            final color = _submitted && isCorrectAnswer
                ? const Color(0xFFD8F3DE)
                : selectedWrong
                ? const Color(0xFFFFE3E7)
                : Colors.white;

            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: ListTile(
                onTap: _submitted
                    ? null
                    : () {
                        setState(() {
                          _selectedAnswer = key;
                        });
                      },
                title: Text('$key. ${question.options.byKey(key)}'),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.sm),
          if (!_submitted)
            FilledButton(
              onPressed: _selectedAnswer == null
                  ? null
                  : () {
                      setState(() {
                        _submitted = true;
                        _isCorrect = _selectedAnswer == question.answerKey;
                      });
                    },
              child: const Text('채점하기'),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: _isCorrect
                    ? const Color(0xFFE1F7E8)
                    : const Color(0xFFFFE9EC),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isCorrect ? '정답입니다!' : '오답입니다.',
                    style: AppTypography.section,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text('정답: ${question.answerKey}'),
                  const SizedBox(height: AppSpacing.xs),
                  Text(question.whyCorrectKo),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '선택한 보기 해설: ${question.whyWrongKo.byKey(_selectedAnswer!)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _submitted = false;
                  _isCorrect = false;
                  _selectedAnswer = null;
                });
              },
              child: const Text('다시 시도'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceArea(
    QuizQuestionDetail question,
    Set<String> evidenceIds,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displaySkill(question.skill.dbValue),
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ...question.sourceLines.map((line) {
              final highlighted = line.containsEvidence(evidenceIds);
              final prefix = question.skill == Skill.reading
                  ? '${line.index + 1}. '
                  : '${line.speaker}: ';
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: highlighted ? const Color(0xFFFFF2C2) : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text('$prefix${line.text}'),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _WrongReviewGroup {
  const _WrongReviewGroup({
    required this.key,
    required this.dayKey,
    required this.date,
    required this.items,
    required this.topTypeTags,
  });

  final String key;
  final String dayKey;
  final DateTime? date;
  final List<WrongNoteListItem> items;
  final List<String> topTypeTags;

  String get fullReviewTitle {
    final parsed = date;
    if (parsed == null) {
      return '$dayKey 오답 복습';
    }
    return '${parsed.year}년 ${parsed.month}월 ${parsed.day}일 오답 복습';
  }

  String get shortReviewTitle {
    final parsed = date;
    if (parsed == null) {
      return '$dayKey 오답';
    }
    final weekday = _weekdayLabel(parsed.weekday);
    return '${parsed.month}.${parsed.day} ($weekday) 오답';
  }
}

List<_WrongReviewGroup> _groupByDay(List<WrongNoteListItem> items) {
  final grouped = <String, List<WrongNoteListItem>>{};
  for (final item in items) {
    final key = _resolveGroupKey(item);
    grouped.putIfAbsent(key, () => <WrongNoteListItem>[]).add(item);
  }

  final groups = <_WrongReviewGroup>[
    for (final entry in grouped.entries)
      _WrongReviewGroup(
        key: entry.key,
        dayKey: entry.key,
        date: _parseDate(entry.key),
        items: entry.value,
        topTypeTags: _extractTypeTags(entry.value),
      ),
  ];

  groups.sort((left, right) {
    final leftDate = left.date;
    final rightDate = right.date;
    if (leftDate != null && rightDate != null) {
      final byDate = rightDate.compareTo(leftDate);
      if (byDate != 0) {
        return byDate;
      }
    }
    if (leftDate == null && rightDate != null) {
      return 1;
    }
    if (leftDate != null && rightDate == null) {
      return -1;
    }
    return right.dayKey.compareTo(left.dayKey);
  });
  return groups;
}

String _resolveGroupKey(WrongNoteListItem item) {
  if (item.sourceKind == WrongNoteSourceKind.mock) {
    return _formatDateOnly(item.completedAt ?? item.attemptedAt);
  }
  if (item.dayKey != '-') {
    return item.dayKey;
  }
  return _formatDateOnly(item.attemptedAt);
}

DateTime? _parseDate(String dayKey) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(dayKey);
  if (match == null) {
    return null;
  }
  final year = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  final day = int.tryParse(match.group(3) ?? '');
  if (year == null || month == null || day == null) {
    return null;
  }
  return DateTime(year, month, day);
}

List<String> _extractTypeTags(List<WrongNoteListItem> items) {
  final seen = <String>{};
  final tags = <String>[];
  for (final item in items) {
    final normalized = item.typeTag.trim();
    if (normalized.isEmpty || seen.contains(normalized)) {
      continue;
    }
    seen.add(normalized);
    tags.add('#$normalized');
    if (tags.length >= 3) {
      break;
    }
  }
  return tags.isEmpty ? const <String>['#오답복습'] : tags;
}

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return '월';
    case DateTime.tuesday:
      return '화';
    case DateTime.wednesday:
      return '수';
    case DateTime.thursday:
      return '목';
    case DateTime.friday:
      return '금';
    case DateTime.saturday:
      return '토';
    case DateTime.sunday:
      return '일';
  }
  return '-';
}

String _mockExamLabel(MockExamType type) {
  switch (type) {
    case MockExamType.weekly:
      return AppCopyKo.mockExamWeekly;
    case MockExamType.monthly:
      return AppCopyKo.mockExamMonthly;
  }
}

String _formatDateOnly(DateTime dateTime) {
  final local = dateTime.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

const List<String> _optionKeys = <String>['A', 'B', 'C', 'D', 'E'];
