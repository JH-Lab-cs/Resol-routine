import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/domain_enums.dart';
import '../../../core/ui/app_copy_ko.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_snackbars.dart';
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
                    return const Center(
                      child: Text(AppCopyKo.emptyMockHistory),
                    );
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
                          trailing: PopupMenuButton<_HistoryMenuAction>(
                            key: ValueKey<String>(
                              'mock-history-menu-${item.sessionId}',
                            ),
                            tooltip: '기록 메뉴',
                            icon: const Icon(Icons.more_vert_rounded),
                            onSelected: (action) {
                              if (action == _HistoryMenuAction.delete) {
                                _deleteSession(item);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem<_HistoryMenuAction>(
                                key: ValueKey<String>(
                                  'mock-history-delete-${item.sessionId}',
                                ),
                                value: _HistoryMenuAction.delete,
                                child: const Text(
                                  AppCopyKo.mockHistoryDeleteAction,
                                ),
                              ),
                            ],
                          ),
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

  Future<void> _deleteSession(MockExamSessionSummary item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final title = _titleForType(item.examType);
        return AlertDialog(
          title: Text(AppCopyKo.mockHistoryDeleteTitle(title)),
          content: Text(
            AppCopyKo.mockHistoryDeleteMessage(
              examLabel: title,
              periodKey: item.periodKey,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppCopyKo.mockHistoryDeleteCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(AppCopyKo.mockHistoryDeleteConfirm),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref
          .read(mockExamSessionRepositoryProvider)
          .deleteSessionById(item.sessionId);
      if (!mounted) {
        return;
      }
      ref.invalidate(mockExamRecentSessionsProvider);
      ref.invalidate(mockExamCurrentSummaryProvider);
      AppSnackbars.showSuccess(context, AppCopyKo.mockHistoryDeleteSuccess);
    } on StateError {
      if (!mounted) {
        return;
      }
      AppSnackbars.showWarning(context, AppCopyKo.mockHistoryDeleteAlready);
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppSnackbars.showError(context, AppCopyKo.mockHistoryDeleteFailed);
    }
  }
}

enum _HistoryMenuAction { delete }
