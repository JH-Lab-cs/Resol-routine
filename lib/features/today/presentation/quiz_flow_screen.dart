import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/primary_pill_button.dart';
import '../application/today_quiz_providers.dart';
import '../data/attempt_payload.dart';
import '../data/today_quiz_repository.dart';
import '../data/today_session_repository.dart';
import '../application/today_session_providers.dart';

class QuizFlowScreen extends ConsumerStatefulWidget {
  const QuizFlowScreen({super.key, required this.track});

  final String track;

  @override
  ConsumerState<QuizFlowScreen> createState() => _QuizFlowScreenState();
}

class _QuizFlowScreenState extends ConsumerState<QuizFlowScreen> {
  DailySessionBundle? _session;
  List<QuizQuestionDetail> _questions = const [];
  SessionProgress _progress = const SessionProgress(
    completed: 0,
    listeningCompleted: 0,
    readingCompleted: 0,
  );

  bool _isLoading = true;
  bool _started = false;
  int _currentIndex = 0;

  String? _selectedAnswer;
  String? _selectedWrongReasonTag;
  bool _submitted = false;
  bool _isCorrect = false;
  bool _saving = false;
  bool _showTranscript = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final session = await ref
          .read(todaySessionRepositoryProvider)
          .getOrCreateSession(track: widget.track);
      final quizRepository = ref.read(todayQuizRepositoryProvider);
      final questions = await quizRepository.loadSessionQuestions(
        session.sessionId,
      );
      final attempts = await quizRepository.loadSessionAttempts(
        session.sessionId,
      );
      final progress = await quizRepository.loadSessionProgress(
        session.sessionId,
      );

      final firstUnansweredIndex = questions.indexWhere(
        (question) => !attempts.containsKey(question.questionId),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _questions = questions;
        _progress = progress;
        _currentIndex = firstUnansweredIndex < 0
            ? questions.length
            : firstUnansweredIndex;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('퀴즈 로딩 실패: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = _session;
    if (session == null) {
      return const Scaffold(body: Center(child: Text('세션이 없습니다.')));
    }

    if (!_started) {
      final startLabel = _progress.completed == 0 ? '시작하기' : '이어하기';
      return Scaffold(
        appBar: AppBar(title: const Text('오늘 루틴 퀴즈')),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('트랙 ${session.track}', style: AppTypography.label),
              const SizedBox(height: AppSpacing.xs),
              Text('총 6문제', style: AppTypography.title),
              const SizedBox(height: AppSpacing.md),
              Text(
                _progress.completed == 0
                    ? '오늘 루틴을 시작해 보세요.'
                    : '진행도 ${_progress.completed}/6 · 이어서 풀 수 있어요.',
                style: AppTypography.body,
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

    if (_currentIndex >= _questions.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('오늘 루틴 퀴즈')),
        body: const Center(
          child: Text('오늘 루틴 완료 🎉', style: AppTypography.title),
        ),
      );
    }

    final question = _questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('오늘 루틴 퀴즈')),
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
            _ExplanationPanel(
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
                        label: Text(tag),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('오답 태그를 선택해 주세요.')),
                        );
                        return;
                      }

                      if (!_isCorrect) {
                        await _saveCurrentAttempt();
                      }

                      if (!mounted) {
                        return;
                      }

                      setState(() {
                        _currentIndex += 1;
                        _submitted = false;
                        _isCorrect = false;
                        _selectedAnswer = null;
                        _selectedWrongReasonTag = null;
                        _showTranscript = true;
                      });
                    },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceArea(QuizQuestionDetail question) {
    final evidenceIds = question.evidenceSentenceIds.toSet();

    if (question.skill == 'LISTENING') {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('LISTENING', style: AppTypography.label),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showTranscript = !_showTranscript;
                      });
                    },
                    child: Text(_showTranscript ? '대본 숨기기' : '대본 보기'),
                  ),
                ],
              ),
              if (_showTranscript) ...[
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
            Text('READING', style: AppTypography.label),
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
      await ref
          .read(todayQuizRepositoryProvider)
          .saveAttempt(
            sessionId: session.sessionId,
            questionId: question.questionId,
            selectedAnswer: _selectedAnswer!,
            isCorrect: _isCorrect,
            wrongReasonTag: _selectedWrongReasonTag,
          );

      final updatedProgress = await ref
          .read(todayQuizRepositoryProvider)
          .loadSessionProgress(session.sessionId);

      if (!mounted) {
        return;
      }

      setState(() {
        _progress = updatedProgress;
      });

      ref.invalidate(todaySessionProvider(widget.track));
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }
}

class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.optionKey,
    required this.text,
    required this.selected,
    this.onTap,
  });

  final String optionKey;
  final String text;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryContainer : Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            '$optionKey. $text',
            style: AppTypography.body.copyWith(
              color: selected ? AppColors.primary : AppColors.textPrimary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplanationPanel extends StatelessWidget {
  const _ExplanationPanel({
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
        color: isCorrect ? const Color(0xFFE1F7E8) : const Color(0xFFFFE9EC),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isCorrect ? '정답입니다!' : '오답입니다.', style: AppTypography.section),
          const SizedBox(height: AppSpacing.xs),
          Text('정답: ${question.answerKey}'),
          const SizedBox(height: AppSpacing.xs),
          Text(question.whyCorrectKo),
          const SizedBox(height: AppSpacing.xs),
          Text('선택한 보기 해설: ${question.whyWrongKo.byKey(selectedAnswer)}'),
        ],
      ),
    );
  }
}

const List<String> _optionKeys = <String>['A', 'B', 'C', 'D', 'E'];
