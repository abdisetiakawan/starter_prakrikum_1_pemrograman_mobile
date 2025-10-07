import 'package:flutter/cupertino.dart';
import 'model.dart';

class QuizViewModel extends ChangeNotifier {
  final QuestionBank _questionBank = QuestionBank();
  final VoidCallback onGameOver;
  late final int totalQuestions;
  Question? currentQuestion;
  int answeredQuestionCount = 0;
  int score = 0;
  bool didAnswerQuestion = false;
  int? selectedAnswerIndex;

  bool get isAnswerCorrect =>
      selectedAnswerIndex != null &&
      selectedAnswerIndex == currentQuestion?.correctAnswer;

  bool get hasNextQuestion => answeredQuestionCount < totalQuestions;

  QuizViewModel({required this.onGameOver}) {
    totalQuestions = _questionBank.remainingQuestions;
    getNextQuestion();
  }

  void getNextQuestion() {
    if (_questionBank.hasNextQuestion) {
      currentQuestion = _questionBank.getRandomQuestion();
      answeredQuestionCount++;
    }

    didAnswerQuestion = false;
    selectedAnswerIndex = null;

    notifyListeners();
  }

  void checkAnswer(int selectedIndex) {
    if (didAnswerQuestion) {
      return;
    }

    selectedAnswerIndex = selectedIndex;

    if (currentQuestion?.correctAnswer == selectedIndex) {
      score++;
    }

    didAnswerQuestion = true;

    if (!_questionBank.hasNextQuestion) {
      onGameOver();
    }

    notifyListeners();
  }
}
