import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/domain_enums.dart';
import '../../../core/ui/app_copy_ko.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_snackbars.dart';
import '../../../core/ui/components/primary_pill_button.dart';
import '../../../core/ui/label_maps.dart';
import '../../my/application/my_stats_providers.dart';
import '../../today/application/today_quiz_providers.dart';
import '../../today/data/attempt_payload.dart';
import '../../today/data/today_quiz_repository.dart';
import '../../today/presentation/quiz_flow_screen.dart';
import '../../wrong_notes/application/wrong_note_providers.dart';
import '../application/mock_exam_providers.dart';
import '../data/mock_exam_attempt_repository.dart';
import '../data/mock_exam_session_repository.dart';
import 'weekly_mock_flow_screen.dart' show MockExamFlowExitAction;

class MonthlyMockFlowScreen extends ConsumerStatefulWidget {
  const MonthlyMockFlowScreen({super.key, required this.track, this.nowLocal});

  final String track;
  final DateTime? nowLocal;

  @override
  ConsumerState<MonthlyMockFlowScreen> createState() =>
      _MonthlyMockFlowScreenState();
}

class _MonthlyMockFlowScreenState extends ConsumerState<MonthlyMockFlowScreen> {
  static const List<String> _optionKeys = <String>['A', 'B', 'C', 'D', 'E'];

  MockExamSessionBundle? _session;
  List<QuizQuestionDetail> _questions = const <QuizQuestionDetail>[];
  MockExamSessionProgress _progress = const MockExamSessionProgress(
    completed: 0,
    listeningCompleted: 0,
    readingCompleted: 0,
  );

  bool _isLoading = true;
  bool _insufficientQuestions = false;
  bool _started = false;
  int _currentIndex = 0;

  String? _selectedAnswer;
  WrongReasonTag? _selectedWrongReasonTag;
  bool _submitted = false;
  bool _isCorrect = false;
  bool _saving = false;
  MockExamCompletionReport? _completionReport;
  bool _loadingCompletionReport = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final session = await ref
          .read(mockExamSessionRepositoryProvider)
          .getOrCreateSession(
            type: MockExamType.monthly,
            track: widget.track,
            plan: MockExamSessionRepository.monthlyDefaultPlan,
            nowLocal: widget.nowLocal,
          );
      final questions = await _loadSessionQuestions(session.items);
      final attemptRepository = ref.read(mockExamAttemptRepositoryProvider);
      final firstUnansweredIndex = await attemptRepository
          .findFirstUnansweredOrderIndex(mockSessionId: session.sessionId);
      final progress = await attemptRepository.loadSessionProgress(
        session.sessionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _questions = questions;
        _progress = progress;
        _currentIndex = firstUnansweredIndex;
        _isLoading = false;
      });

      if (_isSessionCompleted(
        currentIndex: firstUnansweredIndex,
        questionCount: questions.length,
        completedItems: progress.completed,
        plannedItems: session.plannedItems,
      )) {
        await _loadCompletionReport(session.sessionId);
      }
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.message.toString();
      if (message.contains('INSUFFICIENT_QUESTIONS')) {
        setState(() {
          _isLoading = false;
          _insufficientQuestions = true;
        });
        return;
      }
      setState(() {
        _isLoading = false;
      });
      AppSnackbars.showError(context, '${AppCopyKo.quizLoadFailed}\n$error');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      AppSnackbars.showError(context, '${AppCopyKo.quizLoadFailed}\n$error');
    }
  }

  Future<List<QuizQuestionDetail>> _loadSessionQuestions(
    List<MockExamSessionItemBundle> items,
  ) async {
    final todayQuizRepository = ref.read(todayQuizRepositoryProvider);
    final futures = items.map((item) {
      return todayQuizRepository.loadQuestionDetail(
        questionId: item.questionId,
        orderIndex: item.orderIndex,
      );
    });
    return Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_insufficientQuestions) {
      return _buildInsufficientQuestionsScreen();
    }

    final session = _session;
    if (session == null) {
      return const Scaffold(body: Center(child: Text('세션이 없습니다.')));
    }

    final sessionCompleted = _isSessionCompleted(
      currentIndex: _currentIndex,
      questionCount: _questions.length,
      completedItems: _progress.completed,
      plannedItems: session.plannedItems,
    );
    if (sessionCompleted) {
      if (_completionReport == null && !_loadingCompletionReport) {
        unawaited(_loadCompletionReport(session.sessionId));
      }
      return _buildCompletionScreen();
    }

    if (_questions.isEmpty) {
      return _buildEmptyQuizScreen();
    }

    if (!_started) {
      final startLabel = _progress.completed == 0 ? '시작하기' : '이어하기';
      return Scaffold(
        appBar: AppBar(title: const Text('월간 모의고사')),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '트랙 ${displayTrack(session.track)}',
                style: AppTypography.label,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('총 ${session.plannedItems}문제', style: AppTypography.title),
              const SizedBox(height: AppSpacing.md),
              Text(
                _progress.completed == 0
                    ? '월간 모의고사를 시작해 보세요.'
                    : '진행도 ${_progress.completed}/${session.plannedItems} · 이어서 풀 수 있어요.',
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '문제 순서는 듣기 17문제 후 독해 28문제로 고정됩니다.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              PrimaryPillButton(
                label: startLabel,
                onPressed: () {
                  setState(() {
                    _started = true;
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    final question = _questions[_currentIndex];
    return Scaffold(
      appBar: AppBar(title: const Text('월간 모의고사')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            '문제 ${_currentIndex + 1} / ${_questions.length}',
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSourceArea(question),
          const SizedBox(height: AppSpacing.md),
          Text(question.prompt, style: AppTypography.section),
          const SizedBox(height: AppSpacing.sm),
          ..._optionKeys.map((key) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: OptionTile(
                optionKey: key,
                text: question.options.byKey(key),
                selected: _selectedAnswer == key,
                onTap: _submitted
                    ? null
                    : () {
                        setState(() {
                          _selectedAnswer = key;
                        });
                      },
              ),
            );
          }),
          const SizedBox(height: AppSpacing.sm),
          if (!_submitted)
            PrimaryPillButton(
              label: '제출하기',
              onPressed: _selectedAnswer == null || _saving
                  ? null
                  : () async {
                      setState(() {
                        _submitted = true;
                        _isCorrect = _selectedAnswer == question.answerKey;
                      });

                      if (_isCorrect) {
                        await _saveCurrentAttempt();
                      }
                    },
            ),
          if (_submitted) ...[
            const SizedBox(height: AppSpacing.md),
            _MockExplanationPanel(
              question: question,
              selectedAnswer: _selectedAnswer!,
              isCorrect: _isCorrect,
            ),
            if (!_isCorrect) ...[
              const SizedBox(height: AppSpacing.md),
              Text('오답 이유 태그를 선택하세요', style: AppTypography.body),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: wrongReasonTags
                    .map((tag) {
                      final selected = tag == _selectedWrongReasonTag;
                      return ChoiceChip(
                        label: Text(_wrongReasonTagLabel(tag, question.skill)),
                        selected: selected,
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        labelStyle: AppTypography.label.copyWith(
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedWrongReasonTag = tag;
                          });
                        },
                      );
                    })
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            PrimaryPillButton(
              label: _currentIndex == _questions.length - 1 ? '완료' : '다음 문제',
              onPressed: _saving
                  ? null
                  : () async {
                      if (!_isCorrect && _selectedWrongReasonTag == null) {
                        AppSnackbars.showWarning(
                          context,
                          AppCopyKo.wrongTagRequired,
                        );
                        return;
                      }

                      if (!_isCorrect) {
                        await _saveCurrentAttempt();
                      }

                      if (!mounted) {
                        return;
                      }

                      final nextIndex = _currentIndex + 1;
                      setState(() {
                        _currentIndex = nextIndex;
                        _submitted = false;
                        _isCorrect = false;
                        _selectedAnswer = null;
                        _selectedWrongReasonTag = null;
                      });

                      if (nextIndex >= _questions.length) {
                        await _loadCompletionReport(session.sessionId);
                      }
                    },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsufficientQuestionsScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('월간 모의고사')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('문항 준비 중입니다.', style: AppTypography.title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '현재 트랙에서 월간 모의고사 문항이 충분하지 않습니다. 콘텐츠가 추가되면 이용할 수 있어요.',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            PrimaryPillButton(
              label: '홈으로',
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop(MockExamFlowExitAction.home);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyQuizScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('월간 모의고사')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('문제를 불러오지 못했어요.', style: AppTypography.title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '세션 정보를 확인한 뒤 다시 시도해 주세요.',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            PrimaryPillButton(
              label: '홈으로',
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop(MockExamFlowExitAction.home);
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: const StadiumBorder(),
                side: const BorderSide(color: AppColors.border),
              ),
              child: const Text('뒤로가기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionScreen() {
    final report = _completionReport;
    final topWrongReason = report?.topWrongReasonTag;
    final listeningTotal = _questions
        .where((question) => question.skill == Skill.listening)
        .length;
    final readingTotal = _questions
        .where((question) => question.skill == Skill.reading)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('월간 모의고사')),
      body: ListView(
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
                  '월간 모의고사 완료',
                  style: AppTypography.title.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '총 ${_questions.length}문제를 모두 풀었어요.',
                  style: AppTypography.body.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loadingCompletionReport && report == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.28,
              children: [
                _SummaryMetricCard(
                  label: '듣기 정답',
                  value:
                      '${report?.listeningCorrectCount ?? 0}/$listeningTotal',
                ),
                _SummaryMetricCard(
                  label: '독해 정답',
                  value: '${report?.readingCorrectCount ?? 0}/$readingTotal',
                ),
                _SummaryMetricCard(
                  label: '오답 개수',
                  value: '${report?.wrongCount ?? 0}개',
                ),
                _SummaryMetricCard(
                  label: '오답 이유 Top 1',
                  value: topWrongReason == null
                      ? '없음'
                      : displayWrongReasonTag(topWrongReason.dbValue),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryPillButton(
            label: '홈으로',
            onPressed: () {
              Navigator.of(context).pop(MockExamFlowExitAction.home);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop(MockExamFlowExitAction.wrongNotes);
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: const StadiumBorder(),
              side: const BorderSide(color: AppColors.border),
            ),
            child: const Text('오답노트 보기'),
          ),
        ],
      ),
    );
  }

  bool _isSessionCompleted({
    required int currentIndex,
    required int questionCount,
    required int completedItems,
    required int plannedItems,
  }) {
    final completedByIndex = questionCount > 0 && currentIndex >= questionCount;
    final completedByProgress = completedItems >= plannedItems;
    return completedByIndex || completedByProgress;
  }

  Future<void> _loadCompletionReport(int sessionId) async {
    if (_loadingCompletionReport) {
      return;
    }

    setState(() {
      _loadingCompletionReport = true;
    });

    try {
      final report = await ref
          .read(mockExamAttemptRepositoryProvider)
          .loadCompletionReport(sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _completionReport = report;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _completionReport ??= const MockExamCompletionReport(
          listeningCorrectCount: 0,
          readingCorrectCount: 0,
          wrongCount: 0,
          topWrongReasonTag: null,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCompletionReport = false;
        });
      }
    }
  }

  Widget _buildSourceArea(QuizQuestionDetail question) {
    final evidenceIds = question.evidenceSentenceIds.toSet();

    if (question.skill == Skill.listening) {
      if (!_submitted) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Text(
                  displaySkill(question.skill.dbValue),
                  style: AppTypography.label,
                ),
                const Spacer(),
                Semantics(
                  label: '듣기 재생',
                  button: true,
                  child: IconButton(
                    onPressed: () => _playListeningAudio(question),
                    icon: const Icon(Icons.volume_up_rounded),
                    tooltip: '듣기 재생',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displaySkill(question.skill.dbValue),
                style: AppTypography.label,
              ),
              const SizedBox(height: AppSpacing.xs),
              ...question.sourceLines.map((line) {
                final highlighted = line.containsEvidence(evidenceIds);
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: highlighted
                        ? const Color(0xFFFFF2C2)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text('${line.speaker}: ${line.text}'),
                );
              }),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displaySkill(question.skill.dbValue),
              style: AppTypography.label,
            ),
            const SizedBox(height: AppSpacing.xs),
            ...question.sourceLines.map((line) {
              final highlighted = line.containsEvidence(evidenceIds);
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: highlighted
                      ? const Color(0xFFFFF2C2)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text('${line.index + 1}. ${line.text}'),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCurrentAttempt() async {
    final session = _session;
    if (session == null) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final question = _questions[_currentIndex];
      final attemptRepository = ref.read(mockExamAttemptRepositoryProvider);
      await attemptRepository.saveAttemptIdempotent(
        mockSessionId: session.sessionId,
        questionId: question.questionId,
        selectedAnswer: _selectedAnswer!,
        isCorrect: _isCorrect,
        wrongReasonTag: _selectedWrongReasonTag,
      );

      final updatedProgress = await attemptRepository.loadSessionProgress(
        session.sessionId,
      );
      MockExamCompletionReport? completionReport;
      if (updatedProgress.completed >= session.plannedItems) {
        completionReport = await attemptRepository.loadCompletionReport(
          session.sessionId,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _progress = updatedProgress;
        if (completionReport != null) {
          _completionReport = completionReport;
        }
      });

      ref.invalidate(myStatsProvider(widget.track));
      ref.invalidate(wrongNoteListProvider);
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackbars.showError(context, '$error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _playListeningAudio(QuizQuestionDetail question) {
    AppSnackbars.showSuccess(
      context,
      '"${question.questionId}" 문항의 듣기 재생을 시작합니다.',
      haptic: false,
    );
  }

  String _wrongReasonTagLabel(WrongReasonTag tag, Skill skill) {
    if (skill == Skill.listening && tag == WrongReasonTag.time) {
      return '리스닝 부족';
    }
    return displayWrongReasonTag(tag.dbValue);
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({required this.label, required this.value});

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

class _MockExplanationPanel extends StatelessWidget {
  const _MockExplanationPanel({
    required this.question,
    required this.selectedAnswer,
    required this.isCorrect,
  });

  final QuizQuestionDetail question;
  final String selectedAnswer;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isCorrect
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isCorrect
              ? AppColors.success.withValues(alpha: 0.25)
              : AppColors.danger.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCorrect ? '정답입니다!' : '오답입니다.',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              color: isCorrect ? AppColors.success : AppColors.danger,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '정답: ${question.answerKey} · 내 답: $selectedAnswer',
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(question.whyCorrectKo, style: AppTypography.body),
          if (!isCorrect) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              question.whyWrongKo.byKey(selectedAnswer),
              style: AppTypography.label.copyWith(color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}
