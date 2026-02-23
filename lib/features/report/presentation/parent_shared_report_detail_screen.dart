import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/domain_enums.dart';
import '../../../core/ui/app_copy_ko.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/components/skeleton.dart';
import '../../../core/ui/haptics.dart';
import '../../../core/ui/label_maps.dart';
import '../application/report_providers.dart';
import '../data/models/report_schema_v1.dart';
import '../data/shared_reports_repository.dart';
import 'widgets/vocab_bookmarks_section.dart';
import 'widgets/vocab_wrong_words_section.dart';

enum _ReportRange { all, last7Days }

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
  final Set<String> _expandedDayKeys = <String>{};
  _ReportRange _range = _ReportRange.all;
  bool _onlyWrong = false;
  Skill? _skill;
  WrongReasonTag? _wrongReason;
  String? _typeTag;

  void _toggleDayExpanded(String dayEntryKey) {
    setState(() {
      if (!_expandedDayKeys.add(dayEntryKey)) {
        _expandedDayKeys.remove(dayEntryKey);
      }
    });
  }

  void _setRange(_ReportRange next) {
    if (_range == next) {
      return;
    }
    Haptics.selection();
    setState(() {
      _range = next;
    });
  }

  void _setOnlyWrong(bool value) {
    if (_onlyWrong == value) {
      return;
    }
    Haptics.selection();
    setState(() {
      _onlyWrong = value;
    });
  }

  void _setSkill(Skill? skill) {
    if (_skill == skill) {
      return;
    }
    Haptics.selection();
    setState(() {
      _skill = skill;
    });
  }

  void _setWrongReason(WrongReasonTag? reason) {
    if (_wrongReason == reason) {
      return;
    }
    Haptics.selection();
    setState(() {
      _wrongReason = reason;
    });
  }

  void _setTypeTag(String? typeTag) {
    if (_typeTag == typeTag) {
      return;
    }
    Haptics.selection();
    setState(() {
      _typeTag = typeTag;
    });
  }

  Future<void> _showTypeTagPicker(
    BuildContext context,
    Map<String, int> typeTagCounts,
  ) async {
    const allKey = '__ALL__';
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final entries = typeTagCounts.entries.toList(growable: false);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('유형 필터 선택')),
              ListTile(
                key: const ValueKey<String>('typeTag-option-all'),
                title: const Text('전체'),
                trailing: _typeTag == null
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(allKey),
              ),
              for (final entry in entries)
                ListTile(
                  key: ValueKey<String>('typeTag-option-${entry.key}'),
                  title: Text(entry.key),
                  subtitle: Text('${entry.value}문항'),
                  trailing: _typeTag == entry.key
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(entry.key),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }
    if (selected == null) {
      return;
    }
    _setTypeTag(selected == allKey ? null : selected);
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      sharedReportByIdProvider(widget.sharedReportId),
    );
    final isRefreshing = detailAsync.isLoading && detailAsync.hasValue;

    return Scaffold(
      appBar: AppBar(title: const Text('리포트 상세')),
      body: AppPageBody(
        child: Stack(
          children: [
            detailAsync.when(
              skipLoadingOnRefresh: true,
              skipLoadingOnReload: true,
              loading: () => const _ParentDetailLoadingSkeleton(),
              error: (error, _) {
                if (error is SharedReportNotFoundException) {
                  return _DeletedReportState(
                    onBack: () => Navigator.of(context).maybePop(),
                  );
                }

                return Center(
                  child: Text(
                    '${AppCopyKo.loadFailed('리포트')}\n$error',
                    textAlign: TextAlign.center,
                  ),
                );
              },
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
                final bookmarkedVocabIds =
                    report.vocabBookmarks?.bookmarkedVocabIds ??
                    const <String>[];
                final customLemmaById =
                    report.customVocab?.lemmasById ?? const <String, String>{};

                final latestDate = _latestDayDate(report.days);
                final recent7Days = _selectRecent7CalendarDays(
                  days: report.days,
                  latestDate: latestDate,
                );
                final rangeDays = _range == _ReportRange.last7Days
                    ? recent7Days
                    : report.days;
                final typeTagCounts = _collectTypeTagCounts(
                  days: rangeDays,
                  onlyWrong: _onlyWrong,
                  skill: _skill,
                  wrongReason: _wrongReason,
                );

                final filteredRange = _filterDays(
                  days: rangeDays,
                  onlyWrong: _onlyWrong,
                  skill: _skill,
                  wrongReason: _wrongReason,
                  typeTag: _typeTag,
                );
                final recentSummary = _filterDays(
                  days: recent7Days,
                  onlyWrong: _onlyWrong,
                  skill: _skill,
                  wrongReason: _wrongReason,
                  typeTag: _typeTag,
                );

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _HeaderCard(
                        detail: detail,
                        totalSolved: totalSolved,
                        totalWrong: totalWrong,
                        bookmarkedCount: bookmarkedVocabIds.length,
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.md),
                    ),
                    SliverToBoxAdapter(
                      child: _RecentSummaryCard(
                        latestDate: latestDate,
                        summary: recentSummary,
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.md),
                    ),
                    SliverToBoxAdapter(
                      child: VocabBookmarksSection(
                        bookmarkedVocabIds: bookmarkedVocabIds,
                        customLemmaById: customLemmaById,
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.md),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _FilterHeaderDelegate(
                        child: _FilterBar(
                          range: _range,
                          onlyWrong: _onlyWrong,
                          skill: _skill,
                          wrongReason: _wrongReason,
                          typeTag: _typeTag,
                          onRangeChanged: _setRange,
                          onOnlyWrongChanged: _setOnlyWrong,
                          onSkillChanged: _setSkill,
                          onWrongReasonChanged: _setWrongReason,
                          onTypeTagTap: () async {
                            await _showTypeTagPicker(context, typeTagCounts);
                          },
                          onTypeTagClear: () => _setTypeTag(null),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.sm),
                    ),
                    SliverToBoxAdapter(
                      child: Text('일자별 요약', style: AppTypography.section),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.sm),
                    ),
                    if (filteredRange.days.isEmpty)
                      const SliverToBoxAdapter(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: Text(AppCopyKo.emptyFilteredDays),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final filteredDay = filteredRange.days[index];
                          final day = filteredDay.day;
                          final dayEntryKey = _dayEntryKey(day);
                          return _DaySummaryCard(
                            filteredDay: filteredDay,
                            customLemmaById: customLemmaById,
                            hasQuestionFilter:
                                _onlyWrong ||
                                _skill != null ||
                                _wrongReason != null ||
                                _typeTag != null,
                            expanded: _expandedDayKeys.contains(dayEntryKey),
                            onToggleExpanded: () =>
                                _toggleDayExpanded(dayEntryKey),
                            dayToggleKey: ValueKey<String>(
                              'report-day-toggle-${day.dayKey}-${day.track.dbValue}',
                            ),
                          );
                        }, childCount: filteredRange.days.length),
                      ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.lg),
                    ),
                  ],
                );
              },
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

  String _dayEntryKey(ReportDay day) => '${day.dayKey}|${day.track.dbValue}';

  DateTime? _latestDayDate(List<ReportDay> days) {
    DateTime? latest;
    for (final day in days) {
      final date = _parseDayKey(day.dayKey);
      if (date == null) {
        continue;
      }
      if (latest == null || date.isAfter(latest)) {
        latest = date;
      }
    }
    return latest;
  }

  List<ReportDay> _selectRecent7CalendarDays({
    required List<ReportDay> days,
    required DateTime? latestDate,
  }) {
    if (latestDate == null) {
      return const <ReportDay>[];
    }
    final startDate = latestDate.subtract(const Duration(days: 6));
    final output = <ReportDay>[];
    for (final day in days) {
      final date = _parseDayKey(day.dayKey);
      if (date == null) {
        continue;
      }
      if (date.isBefore(startDate) || date.isAfter(latestDate)) {
        continue;
      }
      output.add(day);
    }
    return output;
  }

  DateTime? _parseDayKey(String dayKey) {
    if (dayKey.length != 8) {
      return null;
    }
    final year = int.tryParse(dayKey.substring(0, 4));
    final month = int.tryParse(dayKey.substring(4, 6));
    final day = int.tryParse(dayKey.substring(6, 8));
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  Map<String, int> _collectTypeTagCounts({
    required List<ReportDay> days,
    required bool onlyWrong,
    required Skill? skill,
    required WrongReasonTag? wrongReason,
  }) {
    final counts = <String, int>{};
    for (final day in days) {
      for (final question in day.questions) {
        if (skill != null && question.skill != skill) {
          continue;
        }
        if (onlyWrong && question.isCorrect) {
          continue;
        }
        if (wrongReason != null && question.wrongReasonTag != wrongReason) {
          continue;
        }
        counts.update(
          question.typeTag,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return <String, int>{
      for (final entry in sortedEntries) entry.key: entry.value,
    };
  }

  _FilteredReportDays _filterDays({
    required List<ReportDay> days,
    required bool onlyWrong,
    required Skill? skill,
    required WrongReasonTag? wrongReason,
    required String? typeTag,
  }) {
    final hasQuestionFilter =
        onlyWrong || skill != null || wrongReason != null || typeTag != null;
    final filtered = <_FilteredDay>[];
    var totalSolved = 0;
    var totalWrong = 0;
    var listeningCorrect = 0;
    var readingCorrect = 0;

    for (final day in days) {
      final matchedQuestions = <ReportQuestionResult>[];
      var dayWrong = 0;
      var dayListeningCorrect = 0;
      var dayReadingCorrect = 0;
      final dayWrongReasons = <WrongReasonTag, int>{};

      for (final question in day.questions) {
        if (skill != null && question.skill != skill) {
          continue;
        }
        if (typeTag != null && question.typeTag != typeTag) {
          continue;
        }
        if (onlyWrong && question.isCorrect) {
          continue;
        }
        if (wrongReason != null && question.wrongReasonTag != wrongReason) {
          continue;
        }

        matchedQuestions.add(question);
        if (!question.isCorrect) {
          dayWrong += 1;
          final tag = question.wrongReasonTag;
          if (tag != null) {
            dayWrongReasons.update(
              tag,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
          }
        } else if (question.skill == Skill.listening) {
          dayListeningCorrect += 1;
        } else {
          dayReadingCorrect += 1;
        }
      }

      if (!hasQuestionFilter) {
        matchedQuestions
          ..clear()
          ..addAll(day.questions);
        dayWrong = day.wrongCount;
        dayListeningCorrect = day.listeningCorrect;
        dayReadingCorrect = day.readingCorrect;
        dayWrongReasons
          ..clear()
          ..addAll(day.wrongReasonCounts);
      }

      if (hasQuestionFilter && matchedQuestions.isEmpty) {
        continue;
      }

      filtered.add(
        _FilteredDay(
          day: day,
          questions: matchedQuestions,
          solvedCount: matchedQuestions.length,
          wrongCount: dayWrong,
          listeningCorrect: dayListeningCorrect,
          readingCorrect: dayReadingCorrect,
          wrongReasonCounts: dayWrongReasons,
        ),
      );
      totalSolved += matchedQuestions.length;
      totalWrong += dayWrong;
      listeningCorrect += dayListeningCorrect;
      readingCorrect += dayReadingCorrect;
    }

    return _FilteredReportDays(
      days: filtered,
      totalSolved: totalSolved,
      totalWrong: totalWrong,
      listeningCorrect: listeningCorrect,
      readingCorrect: readingCorrect,
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.range,
    required this.onlyWrong,
    required this.skill,
    required this.wrongReason,
    required this.typeTag,
    required this.onRangeChanged,
    required this.onOnlyWrongChanged,
    required this.onSkillChanged,
    required this.onWrongReasonChanged,
    required this.onTypeTagTap,
    required this.onTypeTagClear,
  });

  final _ReportRange range;
  final bool onlyWrong;
  final Skill? skill;
  final WrongReasonTag? wrongReason;
  final String? typeTag;
  final ValueChanged<_ReportRange> onRangeChanged;
  final ValueChanged<bool> onOnlyWrongChanged;
  final ValueChanged<Skill?> onSkillChanged;
  final ValueChanged<WrongReasonTag?> onWrongReasonChanged;
  final VoidCallback onTypeTagTap;
  final VoidCallback onTypeTagClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              key: const ValueKey<String>('filter-range-all'),
              label: const Text('전체'),
              selected: range == _ReportRange.all,
              onSelected: (_) => onRangeChanged(_ReportRange.all),
            ),
            const SizedBox(width: AppSpacing.xs),
            ChoiceChip(
              key: const ValueKey<String>('filter-range-last7'),
              label: const Text('최근 7일'),
              selected: range == _ReportRange.last7Days,
              onSelected: (_) => onRangeChanged(_ReportRange.last7Days),
            ),
            const SizedBox(width: AppSpacing.xs),
            FilterChip(
              key: const ValueKey<String>('filter-only-wrong'),
              label: const Text('오답만'),
              selected: onlyWrong,
              onSelected: onOnlyWrongChanged,
            ),
            const SizedBox(width: AppSpacing.xs),
            ChoiceChip(
              key: const ValueKey<String>('filter-skill-all'),
              label: const Text('스킬 전체'),
              selected: skill == null,
              onSelected: (_) => onSkillChanged(null),
            ),
            const SizedBox(width: AppSpacing.xs),
            ChoiceChip(
              key: const ValueKey<String>('filter-skill-LISTENING'),
              label: const Text('듣기'),
              selected: skill == Skill.listening,
              onSelected: (_) => onSkillChanged(Skill.listening),
            ),
            const SizedBox(width: AppSpacing.xs),
            ChoiceChip(
              key: const ValueKey<String>('filter-skill-READING'),
              label: const Text('독해'),
              selected: skill == Skill.reading,
              onSelected: (_) => onSkillChanged(Skill.reading),
            ),
            const SizedBox(width: AppSpacing.xs),
            ChoiceChip(
              key: const ValueKey<String>('filter-wrong-all'),
              label: const Text('오답이유 전체'),
              selected: wrongReason == null,
              onSelected: (_) => onWrongReasonChanged(null),
            ),
            const SizedBox(width: AppSpacing.xs),
            for (final reason in WrongReasonTag.values) ...[
              ChoiceChip(
                key: ValueKey<String>('filter-wrong-${reason.dbValue}'),
                label: Text(displayWrongReasonTag(reason.dbValue)),
                selected: wrongReason == reason,
                onSelected: (_) => onWrongReasonChanged(reason),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            ActionChip(
              key: const ValueKey<String>('filter-typeTag'),
              label: Text(typeTag == null ? '유형 선택' : '유형 $typeTag'),
              onPressed: onTypeTagTap,
            ),
            if (typeTag != null) ...[
              const SizedBox(width: AppSpacing.xs),
              ActionChip(
                key: const ValueKey<String>('filter-typeTag-clear'),
                label: const Text('유형 해제'),
                onPressed: onTypeTagClear,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  _FilterHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _DeletedReportState extends StatelessWidget {
  const _DeletedReportState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('삭제된 리포트입니다', style: AppTypography.section),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(onPressed: onBack, child: const Text('목록으로')),
          ],
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
    required this.bookmarkedCount,
  });

  final SharedReportRecord detail;
  final int totalSolved;
  final int totalWrong;
  final int bookmarkedCount;

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
            Text(
              '파일: ${detail.source}',
              style: AppTypography.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '생성 시각: ${_formatDateTime(detail.report.generatedAt)}',
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '학생: ${student.displayName ?? '-'}',
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '역할: ${student.role ?? '-'} · 트랙: ${track == null ? '-' : displayTrack(track)}',
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _pill('총 풀이 $totalSolved문항'),
                _pill('총 오답 $totalWrong문항'),
                _pill('일수 ${detail.report.days.length}일'),
                _pill('북마크 $bookmarkedCount개'),
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

class _RecentSummaryCard extends StatelessWidget {
  const _RecentSummaryCard({required this.latestDate, required this.summary});

  final DateTime? latestDate;
  final _FilteredReportDays summary;

  @override
  Widget build(BuildContext context) {
    if (latestDate == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Text(AppCopyKo.emptyReportDays),
        ),
      );
    }

    final startDate = latestDate!.subtract(const Duration(days: 6));
    final rangeLabel =
        '${_formatDate(startDate)} ~ ${_formatDate(latestDate!)} (최근 7일)';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('최근 7일 요약', style: AppTypography.section),
            const SizedBox(height: AppSpacing.xs),
            Text(
              rangeLabel,
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _pill('일수 ${summary.days.length}일'),
                _pill('문항 ${summary.totalSolved}개'),
                _pill('오답 ${summary.totalWrong}개'),
                _pill('듣기 정답 ${summary.listeningCorrect}개'),
                _pill('독해 정답 ${summary.readingCorrect}개'),
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

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({
    required this.filteredDay,
    required this.customLemmaById,
    required this.hasQuestionFilter,
    required this.expanded,
    required this.onToggleExpanded,
    required this.dayToggleKey,
  });

  final _FilteredDay filteredDay;
  final Map<String, String> customLemmaById;
  final bool hasQuestionFilter;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final Key dayToggleKey;

  @override
  Widget build(BuildContext context) {
    final day = filteredDay.day;
    final summaryText = hasQuestionFilter
        ? '표시 문항 ${filteredDay.solvedCount}개 · 오답 ${filteredDay.wrongCount}개 · 듣기 정답 ${filteredDay.listeningCorrect}개 · 독해 정답 ${filteredDay.readingCorrect}개'
        : '풀이 ${filteredDay.solvedCount}/6 · 오답 ${filteredDay.wrongCount} · 듣기 정답 ${filteredDay.listeningCorrect}/3 · 독해 정답 ${filteredDay.readingCorrect}/3';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        key: dayToggleKey,
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
              Text(summaryText, style: AppTypography.body),
              if (day.vocabQuiz != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '단어시험 ${day.vocabQuiz!.correctCount}/${day.vocabQuiz!.totalCount} · ${_formatAccuracy(correctCount: day.vocabQuiz!.correctCount, totalCount: day.vocabQuiz!.totalCount)}',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              if (filteredDay.wrongReasonCounts.isNotEmpty)
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final entry in filteredDay.wrongReasonCounts.entries)
                      _tag(
                        '${displayWrongReasonTag(entry.key.dbValue)} ${entry.value}회',
                      ),
                  ],
                ),
              if (expanded) ...[
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.sm),
                if (day.vocabQuiz != null) ...[
                  Text(
                    '틀린 단어 ${day.vocabQuiz!.wrongVocabIds.length}개',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  VocabWrongWordsSection(
                    wrongVocabIds: day.vocabQuiz!.wrongVocabIds,
                    customLemmaById: customLemmaById,
                    maxVisible: 6,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                ...filteredDay.questions.map((question) {
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

class _ParentDetailLoadingSkeleton extends StatelessWidget {
  const _ParentDetailLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey<String>('parent-detail-loading-skeleton'),
      children: const [
        SkeletonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLine(width: 240),
              SizedBox(height: AppSpacing.xs),
              SkeletonLine(width: 190),
              SizedBox(height: AppSpacing.xs),
              SkeletonLine(width: 210),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLine(width: 120, height: 20),
              SizedBox(height: AppSpacing.sm),
              SkeletonLine(width: 220),
              SizedBox(height: AppSpacing.sm),
              SkeletonLine(height: 42, radius: AppRadius.buttonPill),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLine(width: 140),
              SizedBox(height: AppSpacing.sm),
              SkeletonLine(height: 88, radius: AppRadius.md),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilteredDay {
  const _FilteredDay({
    required this.day,
    required this.questions,
    required this.solvedCount,
    required this.wrongCount,
    required this.listeningCorrect,
    required this.readingCorrect,
    required this.wrongReasonCounts,
  });

  final ReportDay day;
  final List<ReportQuestionResult> questions;
  final int solvedCount;
  final int wrongCount;
  final int listeningCorrect;
  final int readingCorrect;
  final Map<WrongReasonTag, int> wrongReasonCounts;
}

class _FilteredReportDays {
  const _FilteredReportDays({
    required this.days,
    required this.totalSolved,
    required this.totalWrong,
    required this.listeningCorrect,
    required this.readingCorrect,
  });

  final List<_FilteredDay> days;
  final int totalSolved;
  final int totalWrong;
  final int listeningCorrect;
  final int readingCorrect;
}

String _formatAccuracy({required int correctCount, required int totalCount}) {
  if (totalCount <= 0) {
    return '0%';
  }
  final percent = ((correctCount * 100) / totalCount).round();
  return '$percent%';
}
