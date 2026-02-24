import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/domain_enums.dart';
import '../../../core/ui/app_copy_ko.dart';
import '../../../core/ui/app_tokens.dart';
import '../application/mock_exam_providers.dart';
import '../data/mock_exam_session_repository.dart';
import 'mock_exam_result_screen.dart';

class MockExamHistoryScreen extends ConsumerStatefulWidget {
  const MockExamHistoryScreen({super.key, required this.track});

  final String track;

  @override
  ConsumerState<MockExamHistoryScreen> createState() =>
      _MockExamHistoryScreenState();
}

class _MockExamHistoryScreenState extends ConsumerState<MockExamHistoryScreen> {
  MockExamType _selectedType = MockExamType.weekly;

  @override
  Widget build(BuildContext context) {
    final query = MockExamHistoryQuery(
      type: _selectedType,
      track: widget.track,
      limit: 20,
    );
    final summariesAsync = ref.watch(mockExamRecentSessionsProvider(query));

    return Scaffold(
      appBar: AppBar(title: const Text('모의고사 기록')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  key: const ValueKey<String>('mock-history-tab-weekly'),
                  label: const Text('주간'),
                  selected: _selectedType == MockExamType.weekly,
                  onSelected: (_) {
                    setState(() {
                      _selectedType = MockExamType.weekly;
                    });
                  },
                ),
                ChoiceChip(
                  key: const ValueKey<String>('mock-history-tab-monthly'),
                  label: const Text('월간'),
                  selected: _selectedType == MockExamType.monthly,
                  onSelected: (_) {
                    setState(() {
                      _selectedType = MockExamType.monthly;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: summariesAsync.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('${AppCopyKo.loadFailed('모의고사 기록')}\n$error'),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(child: Text('아직 모의고사 기록이 없습니다.'));
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final statusText = _statusText(item);
                      final title = _titleForType(item.examType);
                      return Card(
                        key: ValueKey<String>(
                          'mock-history-item-${item.sessionId}',
                        ),
                        child: ListTile(
                          title: Text(
                            '$title · ${item.periodKey}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '정답 ${item.correctCount}/${item.plannedItems} · '
                            '오답 ${item.wrongCount} · $statusText',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => MockExamResultScreen(
                                  mockSessionId: item.sessionId,
                                  examTitle: title,
                                ),
                              ),
                            );
                          },
                        ),
                      );
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

  String _titleForType(MockExamType type) {
    switch (type) {
      case MockExamType.weekly:
        return '주간 모의고사';
      case MockExamType.monthly:
        return '월간 모의고사';
    }
  }

  String _statusText(MockExamSessionSummary item) {
    if (item.completedItems <= 0) {
      return '미시작';
    }
    if (item.completedItems >= item.plannedItems) {
      return '완료';
    }
    return '진행중 ${item.completedItems}/${item.plannedItems}';
  }
}
