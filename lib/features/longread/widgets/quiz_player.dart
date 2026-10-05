import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:cumobile/core/services/analytics_service.dart';
import 'package:cumobile/core/theme/app_colors.dart';
import 'package:cumobile/core/ui/app_dialogs.dart';
import 'package:cumobile/core/ui/html_colors.dart';
import 'package:cumobile/core/ui/html_table_style.dart';
import 'package:cumobile/core/ui/sync_indicator.dart';
import 'package:cumobile/data/models/quiz.dart';
import 'package:cumobile/data/models/student_task.dart';
import 'package:cumobile/data/services/api_service.dart';
import 'package:cumobile/features/longread/widgets/exercise_header.dart';

enum _SaveState { saving, saved, failed }

class QuizPlayer extends StatefulWidget {
  final int taskId;
  final Color themeColor;
  final int? courseId;
  final VoidCallback? onStateChanged;

  const QuizPlayer({
    super.key,
    required this.taskId,
    required this.themeColor,
    this.courseId,
    this.onStateChanged,
  });

  @override
  State<QuizPlayer> createState() => _QuizPlayerState();
}

class _QuizPlayerState extends State<QuizPlayer> {
  static const _saveDebounce = Duration(milliseconds: 500);

  QuizTask? _task;
  QuizAttempt? _attempt;
  List<QuizPlayerQuestion> _questions = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isStarting = false;
  bool _isCompleting = false;
  bool _timeIsUp = false;
  bool _isFromCache = false;
  final Map<int, Object?> _answers = {};
  final Map<int, Timer> _saveTimers = {};
  final Map<int, Future<void>> _saveFutures = {};
  final Map<int, _SaveState> _saveStates = {};
  final Map<int, TextEditingController> _textControllers = {};
  final Map<int, String?> _inputErrors = {};
  Timer? _ticker;
  DateTime? _timerEnd;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final entry in _saveTimers.entries.toList()) {
      entry.value.cancel();
      _save(entry.key);
    }
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _isEditable {
    final task = _task;
    return task != null &&
        !_isFromCache &&
        !_timeIsUp &&
        task.isAnswerableState &&
        task.currentAttemptId != null &&
        task.quizSessionId != null;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = _task == null;
        _hasError = false;
      });
      if (_task == null) await _showCachedSnapshot();
    }
    final task = await apiService.fetchQuizTask(widget.taskId);
    if (!mounted) return;
    if (task == null) {
      setState(() {
        _isLoading = false;
        _hasError = _task == null;
      });
      return;
    }
    final attemptId = task.displayAttemptId;
    final quizId = task.quizId;
    final results = await Future.wait([
      quizId != null && task.state != 'backlog'
          ? apiService.fetchQuizQuestions(quizId)
          : Future<List<QuizPlayerQuestion>?>.value(null),
      attemptId != null
          ? apiService.fetchQuizAttempt(attemptId)
          : Future<QuizAttempt?>.value(null),
    ]);
    if (!mounted) return;
    _apply(
      task,
      results[1] as QuizAttempt?,
      results[0] as List<QuizPlayerQuestion>? ?? const [],
      fromCache: false,
    );
  }

  Future<void> _showCachedSnapshot() async {
    final task = await apiService.cachedQuizTask(widget.taskId);
    if (task == null || !mounted) return;
    final attemptId = task.displayAttemptId;
    final quizId = task.quizId;
    final results = await Future.wait([
      quizId != null && task.state != 'backlog'
          ? apiService.cachedQuizQuestions(quizId)
          : Future<List<QuizPlayerQuestion>?>.value(null),
      attemptId != null
          ? apiService.cachedQuizAttempt(attemptId)
          : Future<QuizAttempt?>.value(null),
    ]);
    if (!mounted || (!_isFromCache && _task != null)) return;
    _apply(
      task,
      results[1] as QuizAttempt?,
      results[0] as List<QuizPlayerQuestion>? ?? const [],
      fromCache: true,
    );
  }

  void _apply(
    QuizTask task,
    QuizAttempt? attempt,
    List<QuizPlayerQuestion> rawQuestions, {
    required bool fromCache,
  }) {
    final questions = _orderQuestions(rawQuestions, attempt);
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
    _answers
      ..clear()
      ..addAll(attempt?.answers ?? const {});
    for (final question in questions) {
      if (_usesTextField(question.type)) {
        _textControllers[question.id] = TextEditingController(
          text: _answerToText(question, _answers[question.id]),
        );
      }
    }

    setState(() {
      _task = task;
      _attempt = attempt;
      _questions = questions;
      _isFromCache = fromCache;
      _isLoading = false;
      _hasError = false;
      _timeIsUp = false;
      _inputErrors.clear();
      _saveStates.clear();
    });
    _setupTimer();
  }

  List<QuizPlayerQuestion> _orderQuestions(
    List<QuizPlayerQuestion> questions,
    QuizAttempt? attempt,
  ) {
    final ordered = [
      for (final question in questions)
        question.withOrder(
          attempt?.questionOrders[question.id] ?? question.order,
          [...question.options]..sort(
              (a, b) => (attempt?.optionOrders[a.id.toString()] ?? 1)
                  .compareTo(attempt?.optionOrders[b.id.toString()] ?? 1),
            ),
        ),
    ]..sort((a, b) => a.order.compareTo(b.order));
    return ordered;
  }

  void _setupTimer() {
    _ticker?.cancel();
    final task = _task;
    final startedAt = _attempt?.startedAt;
    final timer = task?.timer;
    if (!_isEditable || startedAt == null || timer == null) {
      _timerEnd = null;
      return;
    }
    _timerEnd = startedAt.add(timer);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _onTick();
  }

  void _onTick() {
    final end = _timerEnd;
    if (end == null || !mounted) return;
    if (DateTime.now().isBefore(end)) {
      setState(() {});
      return;
    }
    _ticker?.cancel();
    setState(() => _timeIsUp = true);
    _onTimeIsUp();
  }

  Future<void> _onTimeIsUp() async {
    await _flushSaves();
    if (!mounted) return;
    await AppDialogs.message(
      context,
      title: 'Время закончилось',
      message: 'Мы сохранили и отправили все ответы.',
    );
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    await _load(silent: true);
    widget.onStateChanged?.call();
  }

  static bool _usesTextField(String type) =>
      type == QuizQuestionType.openText ||
      type == QuizQuestionType.stringMatch ||
      type == QuizQuestionType.numberMatch;

  static String _answerToText(QuizPlayerQuestion question, Object? value) {
    if (value == null) return '';
    if (question.type != QuizQuestionType.openText) {
      if (value is num && value % 1 == 0) return value.toInt().toString();
      return value.toString();
    }
    final body = html_parser.parse(value.toString()).body;
    if (body == null) return '';
    final paragraphs = body.querySelectorAll('p');
    if (paragraphs.isEmpty) return body.text.trim();
    return paragraphs.map((p) => p.text).join('\n').trim();
  }

  static String _escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String? _textToHtml(String text) {
    if (text.trim().isEmpty) return null;
    return text
        .split('\n')
        .map((line) => line.trim().isEmpty ? '<p><br></p>' : '<p>${_escape(line)}</p>')
        .join();
  }

  bool _hasAnswer(Object? value) {
    if (value == null) return false;
    if (value is List) return value.isNotEmpty;
    if (value is String) return value.trim().isNotEmpty;
    return true;
  }

  void _setAnswer(QuizPlayerQuestion question, Object? value) {
    if (!_isEditable) return;
    setState(() {
      _answers[question.id] = value;
      _inputErrors[question.id] = null;
    });
    _saveTimers[question.id]?.cancel();
    _saveTimers[question.id] = Timer(_saveDebounce, () => _save(question.id));
  }

  void _onTextChanged(QuizPlayerQuestion question, String text) {
    switch (question.type) {
      case QuizQuestionType.openText:
        _setAnswer(question, _textToHtml(text));
      case QuizQuestionType.stringMatch:
        _setAnswer(question, text.trim().isEmpty ? null : text);
      case QuizQuestionType.numberMatch:
        final normalized = text.trim().replaceAll(',', '.');
        if (normalized.isEmpty) {
          _setAnswer(question, null);
          return;
        }
        final value = num.tryParse(normalized);
        final precision = question.precision;
        final decimals = normalized.contains('.') ? normalized.split('.').last.length : 0;
        String? error;
        if (value == null) {
          error = 'Введите число';
        } else if (precision != null && decimals > precision) {
          error = precision == 0
              ? 'Ответом является целое число'
              : 'Не больше $precision знаков после запятой';
        }
        if (error != null) {
          _saveTimers.remove(question.id)?.cancel();
          setState(() => _inputErrors[question.id] = error);
          return;
        }
        _setAnswer(question, value);
    }
  }

  Future<void> _save(int questionId) {
    _saveTimers.remove(questionId)?.cancel();
    final previous = _saveFutures[questionId] ?? Future<void>.value();
    final future = previous.then((_) => _performSave(questionId));
    _saveFutures[questionId] = future;
    return future;
  }

  Future<void> _performSave(int questionId) async {
    final task = _task;
    final attemptId = task?.currentAttemptId;
    final sessionId = task?.quizSessionId;
    final question = _questions.where((q) => q.id == questionId).firstOrNull;
    if (attemptId == null || sessionId == null || question == null) return;
    if (mounted) setState(() => _saveStates[questionId] = _SaveState.saving);
    final result = await apiService.submitQuizAnswer(
      attemptId: attemptId,
      sessionId: sessionId,
      questionId: questionId,
      type: question.type,
      answer: _answers[questionId],
    );
    if (!mounted) return;
    setState(() {
      _saveStates[questionId] = result.success ? _SaveState.saved : _SaveState.failed;
    });
    if (!result.success && result.errorCode == 'invalidState' && !_timeIsUp) {
      setState(() => _timeIsUp = true);
      await AppDialogs.message(context, message: result.errorMessage);
      if (mounted) await _load(silent: true);
    }
  }

  Future<void> _flushSaves() async {
    for (final questionId in _saveTimers.keys.toList()) {
      _save(questionId);
    }
    await Future.wait(_saveFutures.values);
  }

  Future<void> _start() async {
    final task = _task;
    if (task == null || _isStarting) return;
    final courseId = widget.courseId;
    if (courseId != null) Analytics.taskStartButtonPressed(courseId: courseId);
    setState(() => _isStarting = true);
    String? error;
    if (task.canStartTask) {
      if (!await apiService.startTask(task.id)) error = 'Не удалось начать тест';
    } else if (task.canStartAttempt) {
      final result = await apiService.startQuizAttempt(task.quizSessionId!);
      if (!result.success) error = result.errorMessage;
    }
    if (!mounted) return;
    if (error != null) {
      setState(() => _isStarting = false);
      await AppDialogs.message(context, message: error);
      return;
    }
    for (var i = 0; i < 10; i++) {
      final updated = await apiService.fetchQuizTask(task.id);
      if (!mounted) return;
      if (updated?.currentAttemptId != null) break;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    await _load(silent: true);
    if (!mounted) return;
    setState(() => _isStarting = false);
    widget.onStateChanged?.call();
  }

  Future<void> _complete() async {
    final task = _task;
    final attemptId = task?.currentAttemptId;
    final sessionId = task?.quizSessionId;
    if (task == null || attemptId == null || sessionId == null || _isCompleting) return;
    final hasUnanswered = _questions.any((q) => !_hasAnswer(_answers[q.id]));
    final confirmed = await AppDialogs.confirm(
      context,
      title: hasUnanswered
          ? 'У вас есть неотвеченные вопросы'
          : 'Вы уверены, что хотите завершить тест?',
      message: hasUnanswered ? 'Всё равно завершить тест?' : null,
      confirmLabel: 'Завершить',
    );
    if (!confirmed || !mounted) return;
    setState(() => _isCompleting = true);
    await _flushSaves();
    final result = await apiService.completeQuizAttempt(
      attemptId: attemptId,
      sessionId: sessionId,
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() => _isCompleting = false);
      await AppDialogs.message(
        context,
        message: result.errorCode == null
            ? 'При отправке решения произошла ошибка'
            : result.errorMessage,
      );
      if (result.errorCode != null && mounted) await _load(silent: true);
      return;
    }
    _ticker?.cancel();
    for (var i = 0; i < 10; i++) {
      final updated = await apiService.fetchQuizTask(task.id);
      if (!mounted) return;
      if (updated != null && updated.currentAttemptId == null) break;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    await _load(silent: true);
    if (!mounted) return;
    setState(() => _isCompleting = false);
    widget.onStateChanged?.call();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Решение отправлено!')),
    );
  }

  @override
  Widget build(BuildContext context) => _buildBody();

  Widget _buildLoader() {
    final c = AppColors.of(context);
    return Platform.isIOS
        ? CupertinoActivityIndicator(radius: 14, color: c.accent)
        : CircularProgressIndicator(color: c.accent);
  }

  Widget _buildBody() {
    final c = AppColors.of(context);
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: _buildLoader()),
      );
    }
    final task = _task;
    if (_hasError || task == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Не удалось загрузить тест',
                style: TextStyle(fontSize: 15, color: c.textSecondary),
              ),
              const SizedBox(height: 12),
              _buildButton(label: 'Повторить', onPressed: _load),
            ],
          ),
        ),
      );
    }

    final canStart = !_isEditable &&
        !_isFromCache &&
        (task.canStartTask || (task.canStartAttempt && task.isAnswerableState));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isFromCache)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SyncIndicator(visible: _isFromCache),
                const SizedBox(width: 8),
                Text(
                  'Обновляем тест…',
                  style: TextStyle(fontSize: 12, color: c.textTertiary),
                ),
              ],
            ),
          ),
        if (_timerEnd != null && _isEditable) ...[
          _buildTimer(),
          const SizedBox(height: 12),
        ],
        if (canStart) ...[
          _buildStartBlock(task),
          const SizedBox(height: 12),
        ],
        if (_questions.isNotEmpty)
          for (var i = 0; i < _questions.length; i++) _buildQuestion(i, _questions[i])
        else if (!canStart)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              task.displayAttemptId == null ? 'Ответов пока нет' : 'Вопросы теста недоступны',
              style: TextStyle(fontSize: 13, color: c.textTertiary),
            ),
          ),
        if (_isEditable) ...[
          const SizedBox(height: 4),
          _buildButton(
            label: 'Завершить тест',
            onPressed: _complete,
            isLoading: _isCompleting,
          ),
        ],
      ],
    );
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0 && minutes > 0) return '$hours ч $minutes мин';
    if (hours > 0) return '$hours ч';
    return '${duration.inMinutes} мин';
  }

  Widget _buildTimer() {
    final c = AppColors.of(context);
    final end = _timerEnd!;
    final left = end.difference(DateTime.now());
    final safe = left.isNegative ? Duration.zero : left;
    final hours = safe.inHours;
    final minutes = (safe.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');
    final text = hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
    final isUrgent = safe < const Duration(minutes: 1);
    final color = isUrgent ? c.danger : widget.themeColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Platform.isIOS ? CupertinoIcons.timer : Icons.timer_outlined, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            'Осталось $text',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartBlock(QuizTask task) {
    final c = AppColors.of(context);
    final timer = task.timer;
    final hint = task.canStartTask
        ? 'Вопросы появятся после начала теста.'
        : 'Можно начать новую попытку.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            timer == null
                ? hint
                : '$hint После старта запустится таймер на ${_formatDuration(timer)}.',
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildButton(
            label: task.canStartTask ? 'Начать тест' : 'Начать попытку',
            onPressed: _start,
            isLoading: _isStarting,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    final c = AppColors.of(context);
    final child = isLoading
        ? (Platform.isIOS
            ? CupertinoActivityIndicator(color: c.onAccent)
            : SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.onAccent),
              ))
        : Text(label, style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w600));
    return SizedBox(
      width: double.infinity,
      child: Platform.isIOS
          ? CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: widget.themeColor,
              borderRadius: BorderRadius.circular(12),
              onPressed: isLoading ? null : onPressed,
              child: child,
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                foregroundColor: c.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: child,
            ),
    );
  }

  Widget _buildRichText(String html, {double fontSize = 14}) {
    final c = AppColors.of(context);
    return Html(
      data: normalizeHtmlColors(html),
      extensions: const [TableHtmlExtension()],
      style: {
        ...htmlTableStyles(c),
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(fontSize),
          color: c.textPrimary,
          lineHeight: LineHeight(1.5),
        ),
        'p': Style(margin: Margins.only(bottom: 4)),
        'code': Style(
          backgroundColor: c.surfaceVariant,
          fontFamily: 'monospace',
        ),
      },
    );
  }

  String _questionHint(QuizPlayerQuestion question) {
    switch (question.type) {
      case QuizQuestionType.singleChoice:
        return 'Выберите один вариант';
      case QuizQuestionType.multipleChoice:
        return 'Выберите несколько вариантов';
      case QuizQuestionType.numberMatch:
        final precision = question.precision;
        if (precision == null) return 'Введите число';
        return precision == 0
            ? 'Ответом является целое число'
            : 'Точность ответа — $precision ${ExerciseHeader.pluralize(precision, 'знак', 'знака', 'знаков')} после запятой';
      case QuizQuestionType.stringMatch:
        return 'Введите ответ';
      case QuizQuestionType.openText:
        return 'Развёрнутый ответ';
      default:
        return '';
    }
  }

  Widget _buildQuestion(int index, QuizPlayerQuestion question) {
    final c = AppColors.of(context);
    final result = _attempt?.results[question.id];
    final hasResult = _attempt?.results.containsKey(question.id) == true && result != null;
    final maxScore = question.maxScore;
    final scoreText = hasResult
        ? '${_formatScore(result)} / ${_formatScore(maxScore ?? 0)} б'
        : maxScore != null
            ? '${_formatScore(maxScore)} б'
            : null;
    final scoreColor = !hasResult
        ? c.textTertiary
        : result == maxScore
            ? StudentTask.evaluatedColor
            : result == 0
                ? StudentTask.failedColor
                : StudentTask.reviewColor;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Вопрос ${index + 1}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textTertiary,
                  ),
                ),
              ),
              if (scoreText != null)
                Text(
                  scoreText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scoreColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRichText(question.content, fontSize: 15),
          const SizedBox(height: 4),
          Text(
            _questionHint(question),
            style: TextStyle(fontSize: 12, color: c.textTertiary),
          ),
          const SizedBox(height: 10),
          _buildAnswerInput(question),
          _buildSaveState(question.id),
        ],
      ),
    );
  }

  static String _formatScore(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  Widget _buildSaveState(int questionId) {
    final c = AppColors.of(context);
    final error = _inputErrors[questionId];
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(error, style: TextStyle(fontSize: 12, color: c.danger)),
      );
    }
    final state = _saveStates[questionId];
    if (state == null || !_isEditable) return const SizedBox.shrink();
    final (text, color) = switch (state) {
      _SaveState.saving => ('Сохраняем…', c.textTertiary),
      _SaveState.saved => ('Ответ сохранён', c.textTertiary),
      _SaveState.failed => ('Не удалось сохранить ответ', c.danger),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color))),
          if (state == _SaveState.failed)
            GestureDetector(
              onTap: () => _save(questionId),
              child: Text(
                'Повторить',
                style: TextStyle(fontSize: 12, color: widget.themeColor, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnswerInput(QuizPlayerQuestion question) {
    switch (question.type) {
      case QuizQuestionType.singleChoice:
        return _buildOptions(question, multiple: false);
      case QuizQuestionType.multipleChoice:
        return _buildOptions(question, multiple: true);
      case QuizQuestionType.openText:
      case QuizQuestionType.stringMatch:
      case QuizQuestionType.numberMatch:
        return _buildTextInput(question);
      default:
        return Text(
          'Этот тип вопроса можно пройти только на сайте',
          style: TextStyle(fontSize: 13, color: AppColors.of(context).textSecondary),
        );
    }
  }

  Widget _buildOptions(QuizPlayerQuestion question, {required bool multiple}) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    final value = _answers[question.id];
    final selected = <Object>{
      if (value is List) ...value.whereType<Object>(),
      if (value != null && value is! List) value,
    };
    final enabled = _isEditable;

    bool isSelected(QuizOption option) =>
        selected.any((id) => id == option.id || id.toString() == option.id.toString());

    void toggle(QuizOption option) {
      HapticFeedback.selectionClick();
      if (!multiple) {
        _setAnswer(question, option.id);
        return;
      }
      final next = [
        for (final id in selected)
          if (id.toString() != option.id.toString()) id,
        if (!isSelected(option)) option.id,
      ];
      _setAnswer(question, next.isEmpty ? null : next);
    }

    return Column(
      children: [
        for (final option in question.options)
          Builder(builder: (context) {
            final checked = isSelected(option);
            final IconData icon;
            if (multiple) {
              icon = checked
                  ? (isIos ? CupertinoIcons.checkmark_square_fill : Icons.check_box)
                  : (isIos ? CupertinoIcons.square : Icons.check_box_outline_blank);
            } else {
              icon = checked
                  ? (isIos ? CupertinoIcons.largecircle_fill_circle : Icons.radio_button_checked)
                  : (isIos ? CupertinoIcons.circle : Icons.radio_button_unchecked);
            }
            final accent = checked ? widget.themeColor : c.textTertiary;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? () => toggle(option) : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: checked ? widget.themeColor.withValues(alpha: 0.12) : c.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: checked ? widget.themeColor.withValues(alpha: 0.6) : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 22, color: enabled ? accent : accent.withValues(alpha: 0.6)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildRichText(option.content)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTextInput(QuizPlayerQuestion question) {
    final c = AppColors.of(context);
    final controller = _textControllers[question.id];
    if (controller == null) return const SizedBox.shrink();
    final isOpenText = question.type == QuizQuestionType.openText;
    final isNumber = question.type == QuizQuestionType.numberMatch;
    final keyboardType = isOpenText
        ? TextInputType.multiline
        : isNumber
            ? TextInputType.numberWithOptions(
                decimal: question.precision != 0,
                signed: true,
              )
            : TextInputType.text;
    final enabled = _isEditable;
    final textStyle = TextStyle(fontSize: 15, color: c.textPrimary);

    if (!enabled && controller.text.isEmpty) {
      return Text(
        'Нет ответа',
        style: TextStyle(fontSize: 14, color: c.textTertiary),
      );
    }

    if (Platform.isIOS) {
      return CupertinoTextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        minLines: isOpenText ? 4 : 1,
        maxLines: isOpenText ? null : 1,
        placeholder: 'Ответ',
        style: textStyle,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        onChanged: (text) => _onTextChanged(question, text),
      );
    }
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      minLines: isOpenText ? 4 : 1,
      maxLines: isOpenText ? null : 1,
      style: textStyle,
      decoration: InputDecoration(
        hintText: 'Ответ',
        hintStyle: TextStyle(color: c.textTertiary),
        filled: true,
        fillColor: c.surfaceVariant,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (text) => _onTextChanged(question, text),
    );
  }
}
