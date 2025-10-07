import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'view_model.dart';

class QuestionScreen extends StatefulWidget {
  const QuestionScreen({super.key});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen>
    with TickerProviderStateMixin {
  late final QuizViewModel viewModel = QuizViewModel(
    onGameOver: _handleGameOver,
  );

  late final AnimationController _questionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  late final AnimationController _optionsController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  late final AnimationController _answerRevealController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  late final AnimationController _progressController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  Animation<double> _progressAnimation = const AlwaysStoppedAnimation<double>(
    0.0,
  );
  String? _currentQuestionId;
  double _currentProgress = 0;
  final FlutterTts _tts = FlutterTts();
  bool _isTtsEnabled = true;
  bool _isTtsConfigured = false;
  String? _narratedQuestionId;
  bool _hasNarratedAnswer = false;

  @override
  void initState() {
    super.initState();
    _initializeState();
    viewModel.addListener(_handleModelChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _questionController.forward(from: 0);
      _optionsController.forward(from: 0);
    });

    Future.microtask(() async {
      await _narrateQuestion(forceReplay: true);
    });
  }

  void _initializeState() {
    _currentQuestionId = viewModel.currentQuestion?.question;
    _currentProgress = viewModel.totalQuestions == 0
        ? 0.0
        : viewModel.answeredQuestionCount / viewModel.totalQuestions;

    _progressAnimation = AlwaysStoppedAnimation<double>(_currentProgress);
    _progressController.value = 1;
  }

  void _handleModelChanged() {
    final nextQuestionId = viewModel.currentQuestion?.question;
    final newProgress = viewModel.totalQuestions == 0
        ? 0.0
        : viewModel.answeredQuestionCount / viewModel.totalQuestions;

    if (nextQuestionId != _currentQuestionId) {
      _currentQuestionId = nextQuestionId;
      _questionController.forward(from: 0);
      _optionsController.forward(from: 0);
      _answerRevealController.value = 0;
      _hasNarratedAnswer = false;
      Future.microtask(() => _narrateQuestion(forceReplay: true));
    }

    if (viewModel.didAnswerQuestion) {
      _answerRevealController.forward(from: 0);
      if (!_hasNarratedAnswer) {
        Future.microtask(_narrateAnswerFeedback);
      }
    }

    if ((newProgress - _currentProgress).abs() > 0.0001) {
      _progressAnimation =
          Tween<double>(begin: _currentProgress, end: newProgress).animate(
            CurvedAnimation(
              parent: _progressController,
              curve: Curves.easeOutCubic,
            ),
          );
      _progressController.forward(from: 0);
      _currentProgress = newProgress;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _ensureTtsConfigured() async {
    if (_isTtsConfigured) {
      return;
    }

    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      // Some platforms might not support awaiting completion; continue anyway.
    }

    try {
      final dynamic languages = await _tts.getLanguages;
      if (languages is List && languages.contains('id-ID')) {
        await _tts.setLanguage('id-ID');
      } else {
        await _tts.setLanguage('en-US');
      }
    } catch (_) {
      await _tts.setLanguage('en-US');
    }

    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.02);
    await _tts.setVolume(1.0);
    _isTtsConfigured = true;
  }

  Future<void> _narrateQuestion({bool forceReplay = false}) async {
    if (!_isTtsEnabled || !mounted) return;

    final question = viewModel.currentQuestion;
    if (question == null) return;

    if (!forceReplay && _narratedQuestionId == question.question) {
      return;
    }
    _narratedQuestionId = question.question;

    await _ensureTtsConfigured();
    await _tts.stop();
    if (!_isTtsEnabled || !mounted) return;

    final questionIndex = viewModel.answeredQuestionCount;
    final segments = <String>[
      'Pertanyaan $questionIndex dari ${viewModel.totalQuestions}. ${question.question}',
      ...List.generate(
        question.possibleAnswers.length,
        (index) => 'Pilihan ${index + 1}: ${question.possibleAnswers[index]}',
      ),
    ];

    for (final line in segments) {
      if (!_isTtsEnabled || !mounted) return;
      await _tts.speak(line);
      if (!_isTtsEnabled || !mounted) return;
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> _narrateAnswerFeedback() async {
    if (_hasNarratedAnswer || !_isTtsEnabled || !mounted) {
      return;
    }

    final question = viewModel.currentQuestion;
    final selectedIndex = viewModel.selectedAnswerIndex;
    if (question == null || selectedIndex == null) return;

    _hasNarratedAnswer = true;

    await _ensureTtsConfigured();
    await _tts.stop();
    if (!_isTtsEnabled || !mounted) return;

    final selectedText = question.possibleAnswers[selectedIndex];

    if (viewModel.isAnswerCorrect) {
      await _tts.speak('Bagus! Jawaban kamu benar, yaitu $selectedText.');
    } else {
      final correctText = question.possibleAnswers[question.correctAnswer];
      await _tts.speak(
        'Belum tepat. Kamu memilih $selectedText. Jawaban yang benar adalah $correctText.',
      );
    }
  }

  void _toggleNarration() {
    setState(() {
      _isTtsEnabled = !_isTtsEnabled;
    });

    if (_isTtsEnabled) {
      Future.microtask(() => _narrateQuestion(forceReplay: true));
    } else {
      unawaited(_tts.stop());
    }
  }

  void _replayNarration() {
    if (!_isTtsEnabled) {
      return;
    }
    Future.microtask(() => _narrateQuestion(forceReplay: true));
  }

  void _onAnswerSelected(int index) {
    if (viewModel.didAnswerQuestion) {
      return;
    }
    unawaited(_tts.stop());
    viewModel.checkAnswer(index);
  }

  void _onNextPressed() {
    unawaited(_tts.stop());
    viewModel.getNextQuestion();
  }

  @override
  void dispose() {
    viewModel.removeListener(_handleModelChanged);
    _questionController.dispose();
    _optionsController.dispose();
    _answerRevealController.dispose();
    _progressController.dispose();
    unawaited(_tts.stop());
    super.dispose();
  }

  void _handleGameOver() {
    final colorScheme = Theme.of(context).colorScheme;

    unawaited(_tts.stop());
    if (_isTtsEnabled) {
      Future.microtask(() async {
        await _ensureTtsConfigured();
        if (!mounted || !_isTtsEnabled) return;
        final message =
            'Permainan selesai. Skor akhir kamu ${viewModel.score} dari ${viewModel.totalQuestions}.';
        await _tts.speak(message);
      });
    }

    showDialog<void>(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Hero(
                tag: 'quiz-badge',
                child: Icon(
                  Icons.rocket_launch_outlined,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Misi Selesai!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Skor akhir kamu ${viewModel.score} dari ${viewModel.totalQuestions}.',
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: viewModel.totalQuestions == 0
                    ? 0.0
                    : viewModel.score / viewModel.totalQuestions,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: colorScheme.primary,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text('Kembali ke Beranda'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final question = viewModel.currentQuestion;
    final answers = question?.possibleAnswers ?? const <String>[];

    final questionSlide =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _questionController,
            curve: Curves.easeOutCubic,
          ),
        );

    final questionFade = CurvedAnimation(
      parent: _questionController,
      curve: const Interval(0, 0.9, curve: Curves.easeOut),
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Pertanyaan'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Hero(
            tag: 'quiz-badge',
            child: CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.rocket_launch_outlined,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isTtsEnabled ? 'Bisukan narasi' : 'Aktifkan narasi',
            onPressed: _toggleNarration,
            icon: Icon(
              _isTtsEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1).animate(animation),
                  child: child,
                ),
              );
            },
            child: viewModel.hasNextQuestion && viewModel.didAnswerQuestion
                ? TextButton(
                    key: const ValueKey('next-enabled'),
                    onPressed: _onNextPressed,
                    child: const Text('Next'),
                  )
                : TextButton(
                    key: const ValueKey('next-disabled'),
                    onPressed: null,
                    child: const Text('Next'),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedStatusBar(
                animation: _progressAnimation,
                answered: viewModel.answeredQuestionCount,
                total: viewModel.totalQuestions,
                score: viewModel.score,
              ),
              const SizedBox(height: 28),
              Expanded(
                child: FadeTransition(
                  opacity: questionFade,
                  child: SlideTransition(
                    position: questionSlide,
                    child: GestureDetector(
                      onTap: _replayNarration,
                      behavior: HitTestBehavior.opaque,
                      child: QuestionCard(
                        question: question?.question ?? '',
                        colorScheme: colorScheme,
                        controller: _questionController,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AnimatedSize(
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOut,
                child: AnswerCards(
                  answers: answers,
                  onTapped: _onAnswerSelected,
                  correctAnswer: viewModel.didAnswerQuestion
                      ? question?.correctAnswer
                      : null,
                  selectedAnswer: viewModel.selectedAnswerIndex,
                  reveal: _answerRevealController,
                  entrance: _optionsController,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedStatusBar extends StatelessWidget {
  final Animation<double> animation;
  final int answered;
  final int total;
  final int score;

  const AnimatedStatusBar({
    required this.animation,
    required this.answered,
    required this.total,
    required this.score,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progressValue = animation.value.clamp(0.0, 1.0);
        return Card(
          elevation: 6,
          shadowColor: colorScheme.primary.withValues(alpha: 0.22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Pertanyaan $answered / $total',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: Text(
                        'Skor $score',
                        key: ValueKey(score),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 14,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                          ),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progressValue,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary,
                                  colorScheme.secondary,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class QuestionCard extends StatelessWidget {
  final String question;
  final ColorScheme colorScheme;
  final AnimationController controller;

  const QuestionCard({
    required this.question,
    required this.colorScheme,
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final rotation = (math.sin(controller.value * math.pi) * 0.02).clamp(
          -0.04,
          0.04,
        );
        return Transform.rotate(angle: rotation, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.secondaryContainer.withValues(alpha: 0.85),
              colorScheme.primaryContainer,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Pertanyaan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSecondaryContainer.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              question,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnswerCards extends StatelessWidget {
  final List<String> answers;
  final void Function(int index) onTapped;
  final int? correctAnswer;
  final int? selectedAnswer;
  final AnimationController reveal;
  final AnimationController entrance;

  const AnswerCards({
    required this.answers,
    required this.onTapped,
    required this.correctAnswer,
    required this.selectedAnswer,
    required this.reveal,
    required this.entrance,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final animations = Listenable.merge(<Listenable>[reveal, entrance]);

    return AnimatedBuilder(
      animation: animations,
      builder: (context, child) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 5 / 3,
          ),
          itemCount: answers.length,
          itemBuilder: (context, index) {
            final isSelected = selectedAnswer == index;
            final isCorrect = correctAnswer == index;
            final revealValue = reveal.value;

            final entryCurve = CurvedAnimation(
              parent: entrance,
              curve: Interval(
                0.05 + (index * 0.15),
                math.min(1, 0.55 + (index * 0.2)),
                curve: Curves.easeOutBack,
              ),
            );

            final baseColor = colorScheme.secondaryContainer;
            Color targetColor = baseColor;
            if (correctAnswer != null) {
              if (isCorrect) {
                targetColor = colorScheme.primaryContainer;
              } else if (isSelected && !isCorrect) {
                targetColor = colorScheme.errorContainer;
              } else {
                targetColor = colorScheme.surfaceContainerHighest;
              }
            }

            final animatedColor = Color.lerp(
              baseColor,
              targetColor,
              revealValue,
            );

            final scale = entryCurve.value;
            final highlightScale = isCorrect
                ? 1 + (0.08 * revealValue)
                : isSelected && !isCorrect
                ? 0.96 + (0.04 * (1 - revealValue))
                : 1;

            return Transform.scale(
              scale: scale.clamp(0.85, 1.0) * highlightScale,
              child: _AnimatedAnswerCard(
                text: answers[index],
                onTap: correctAnswer == null ? () => onTapped(index) : null,
                color: animatedColor ?? baseColor,
                showRipple: isSelected,
                revealValue: revealValue,
                isCorrect: isCorrect,
              ),
            );
          },
        );
      },
    );
  }
}

class _AnimatedAnswerCard extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color color;
  final bool showRipple;
  final double revealValue;
  final bool isCorrect;

  const _AnimatedAnswerCard({
    required this.text,
    required this.onTap,
    required this.color,
    required this.showRipple,
    required this.revealValue,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isCorrect
                  ? colorScheme.primary.withValues(alpha: 0.8 * revealValue)
                  : colorScheme.outlineVariant,
              width: isCorrect ? 2 : 1,
            ),
            boxShadow: [
              if (isCorrect && revealValue > 0.1)
                BoxShadow(
                  color: colorScheme.primary.withValues(
                    alpha: 0.25 * revealValue,
                  ),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: showRipple ? 0.25 * (1 - revealValue) : 0,
                  duration: const Duration(milliseconds: 300),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                        radius: 0.9,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  child: Center(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
