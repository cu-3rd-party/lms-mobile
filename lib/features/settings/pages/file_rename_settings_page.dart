import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:cumobile/core/services/file_rename_service.dart';
import 'package:cumobile/data/models/student_performance.dart';
import 'package:cumobile/data/services/api_service.dart';

class FileRenameSettingsPage extends StatefulWidget {
  const FileRenameSettingsPage({super.key});

  @override
  State<FileRenameSettingsPage> createState() => _FileRenameSettingsPageState();
}

class _FileRenameSettingsPageState extends State<FileRenameSettingsPage> {
  static const _accentColor = Color(0xFF00E676);

  List<FileRenameRule> _rules = [];
  Map<int, String> _courseNames = {};

  @override
  void initState() {
    super.initState();
    _loadRules();
    _loadCourseNames();
  }

  void _loadRules() {
    setState(() {
      _rules = FileRenameService.instance.getAllRules();
    });
  }

  Future<void> _loadCourseNames() async {
    try {
      final response = await apiService.fetchStudentPerformance();
      final courses = response?.courses ?? [];
      setState(() {
        _courseNames = {
          for (final course in courses) course.id: course.cleanName,
        };
      });
    } catch (_) {
      // ignore errors; fall back to course ids
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;

    final body = Container(
      color: const Color(0xFF121212),
      child: _rules.isEmpty ? _buildEmptyState(isIos) : _buildRulesList(isIos),
    );

    if (isIos) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Шаблоны имён файлов'),
          backgroundColor: const Color(0xFF121212),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showAddDialog(isIos),
            child: const Icon(CupertinoIcons.add, color: _accentColor),
          ),
        ),
        child: SafeArea(child: body),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Шаблоны имён файлов'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: _accentColor),
            onPressed: () => _showAddDialog(isIos),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildEmptyState(bool isIos) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isIos ? CupertinoIcons.doc_text : Icons.description_outlined,
              size: 64,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'Нет шаблонов',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Шаблоны позволяют автоматически переименовывать файлы при прикреплении к заданиям.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            isIos
                ? CupertinoButton.filled(
                    onPressed: () => _showAddDialog(isIos),
                    child: const Text('Добавить шаблон'),
                  )
                : ElevatedButton.icon(
                    onPressed: () => _showAddDialog(isIos),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить шаблон'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.black,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesList(bool isIos) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _rules.length,
      separatorBuilder: (context, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final rule = _rules[index];
        return _buildRuleCard(rule, isIos);
      },
    );
  }

  Widget _buildRuleCard(FileRenameRule rule, bool isIos) {
    final activityText = rule.activityType ?? 'Все типы';
    final courseText = _courseNames[rule.courseId] ?? 'Курс #${rule.courseId}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '.${rule.fileExtension}',
                style: const TextStyle(
                  color: _accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${rule.targetName}.${rule.fileExtension}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$courseText • $activityText',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteRule(rule),
            icon: Icon(
              isIos ? CupertinoIcons.trash : Icons.delete_outline,
              color: Colors.redAccent,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(bool isIos) async {
    final result = await showDialog<FileRenameRule>(
      context: context,
      builder: (context) => _AddRuleDialog(isIos: isIos),
    );

    if (result != null) {
      await FileRenameService.instance.addRule(result);
      _loadRules();
    }
  }

  Future<void> _deleteRule(FileRenameRule rule) async {
    final confirmed = await _confirmDelete();
    if (confirmed == true) {
      await FileRenameService.instance.removeRule(rule.key);
      _loadRules();
    }
  }

  Future<bool?> _confirmDelete() async {
    final isIos = Platform.isIOS;

    if (isIos) {
      return showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Удалить шаблон?'),
          content: const Text('Это действие нельзя отменить.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Удалить'),
            ),
          ],
        ),
      );
    }

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Удалить шаблон?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Это действие нельзя отменить.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Отмена', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _AddRuleDialog extends StatefulWidget {
  final bool isIos;

  const _AddRuleDialog({required this.isIos});

  @override
  State<_AddRuleDialog> createState() => _AddRuleDialogState();
}

class _AddRuleDialogState extends State<_AddRuleDialog> {
  static const _accentColor = Color(0xFF00E676);

  final _extensionController = TextEditingController();
  final _targetNameController = TextEditingController();
  List<StudentPerformanceCourse> _courses = [];
  List<String> _activities = [];
  StudentPerformanceCourse? _selectedCourse;
  String? _selectedActivity;
  bool _isLoadingCourses = true;
  bool _isLoadingActivities = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _extensionController.dispose();
    _targetNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isIos) {
      return CupertinoAlertDialog(
        title: const Text('Новый шаблон'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _buildForm(widget.isIos),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: _submit,
            child: const Text('Добавить'),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Новый шаблон', style: TextStyle(color: Colors.white)),
      content: _buildForm(widget.isIos),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Отмена', style: TextStyle(color: Colors.grey[400])),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Добавить', style: TextStyle(color: _accentColor)),
        ),
      ],
    );
  }

  Widget _buildForm(bool isIos) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCourseSelector(isIos),
          const SizedBox(height: 12),
          _buildActivitySelector(isIos),
          const SizedBox(height: 12),
          _buildField(
            isIos: isIos,
            controller: _extensionController,
            label: 'Расширение файла',
            hint: 'Например: pdf',
          ),
          const SizedBox(height: 12),
          _buildField(
            isIos: isIos,
            controller: _targetNameController,
            label: 'Имя файла (без расширения)',
            hint: 'Например: ДЗ_Иванов',
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required bool isIos,
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
  }) {
    if (isIos) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          CupertinoTextField(
            controller: controller,
            placeholder: hint,
            keyboardType: keyboardType,
            padding: const EdgeInsets.all(10),
          ),
        ],
      );
    }

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[700]),
        isDense: true,
        contentPadding: const EdgeInsets.all(10),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildCourseSelector(bool isIos) {
    final enabled = !_isLoadingCourses && _courses.isNotEmpty;
    final value = _isLoadingCourses
        ? 'Загрузка курсов...'
        : (_selectedCourse?.cleanName ?? 'Курсы недоступны');

    return _buildSelector(
      isIos: isIos,
      label: 'Курс',
      value: value,
      enabled: enabled,
      isLoading: _isLoadingCourses,
      onTap: enabled ? _showCoursePicker : null,
    );
  }

  Widget _buildActivitySelector(bool isIos) {
    final enabled = _selectedCourse != null && !_isLoadingActivities;
    final hasActivities = _activities.isNotEmpty;
    String value;

    if (_isLoadingActivities) {
      value = 'Загрузка типов активности...';
    } else if (_selectedActivity != null) {
      value = _selectedActivity!;
    } else if (hasActivities) {
      value = 'Все типы';
    } else {
      value = 'Нет доступных типов';
    }

    return _buildSelector(
      isIos: isIos,
      label: 'Тип активности',
      value: value,
      enabled: enabled && (hasActivities || _selectedActivity == null),
      isLoading: _isLoadingActivities,
      onTap: enabled ? _showActivityPicker : null,
    );
  }

  Widget _buildSelector({
    required bool isIos,
    required String label,
    required String value,
    required bool enabled,
    required bool isLoading,
    VoidCallback? onTap,
  }) {
    if (isIos) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: enabled ? onTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(color: enabled ? Colors.white : Colors.grey[500], fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isLoading)
                    const SizedBox(
                      height: 16,
                      width: 16,
                      child: CupertinoActivityIndicator(radius: 8),
                    )
                  else
                    Icon(
                      CupertinoIcons.chevron_down,
                      size: 16,
                      color: enabled ? CupertinoColors.systemGrey : CupertinoColors.inactiveGray,
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: enabled ? Colors.white : Colors.grey[600],
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accentColor,
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_drop_down,
                    color: enabled ? Colors.grey[400] : Colors.grey[700],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoadingCourses = true;
      _courses = [];
      _selectedCourse = null;
    });

    try {
      final response = await apiService.fetchStudentPerformance();
      if (!mounted) return;

      final courses = response?.courses ?? [];
      setState(() {
        _courses = courses;
        _selectedCourse = courses.isNotEmpty ? courses.first : null;
        _isLoadingCourses = false;
      });

      if (_selectedCourse != null) {
        await _loadActivities(_selectedCourse!.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingCourses = false;
      });
    }
  }

  Future<void> _loadActivities(int courseId) async {
    setState(() {
      _isLoadingActivities = true;
      _activities = [];
      _selectedActivity = null;
    });

    try {
      final response = await apiService.fetchCourseExercises(courseId);
      if (!mounted) return;

      final activities = <String>{};
      for (final exercise in response?.exercises ?? []) {
        final name = exercise.activity?.name;
        if (name != null && name.isNotEmpty) {
          activities.add(name);
        }
      }

      setState(() {
        _activities = activities.toList()..sort();
        _isLoadingActivities = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingActivities = false;
      });
    }
  }

  Future<void> _showCoursePicker() async {
    if (widget.isIos) {
      final selected = await showCupertinoModalPopup<StudentPerformanceCourse>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: const Text('Выберите курс'),
          actions: _courses
              .map(
                (course) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(context, course),
                  child: Text(course.cleanName),
                ),
              )
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ),
      );

      if (selected != null) {
        setState(() {
          _selectedCourse = selected;
        });
        await _loadActivities(selected.id);
      }
      return;
    }

    final selected = await showModalBottomSheet<StudentPerformanceCourse>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Выберите курс',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(
              height: 360,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  final course = _courses[index];
                  return ListTile(
                    title: Text(
                      course.cleanName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => Navigator.pop(context, course),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedCourse = selected;
      });
      await _loadActivities(selected.id);
    }
  }

  Future<void> _showActivityPicker() async {
    if (_selectedCourse == null) return;

    const allActivitiesValue = '__all_activities__';
    final options = <String>[allActivitiesValue, ..._activities];

    if (widget.isIos) {
      final selected = await showCupertinoModalPopup<String>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: const Text('Тип активности'),
          actions: options
              .map(
                (activity) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(context, activity),
                  child: Text(activity == allActivitiesValue ? 'Все типы' : activity),
                ),
              )
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ),
      );

      if (selected != null) {
        setState(() {
          _selectedActivity = selected == allActivitiesValue ? null : selected;
        });
      }
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Тип активности',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(
              height: 320,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final activity = options[index];
                  return ListTile(
                    title: Text(
                      activity == allActivitiesValue ? 'Все типы' : activity,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => Navigator.pop(context, activity),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedActivity = selected == allActivitiesValue ? null : selected;
      });
    }
  }

  void _submit() {
    final extension = _extensionController.text.trim().replaceAll('.', '');
    final targetName = _targetNameController.text.trim();

    if (_selectedCourse == null || extension.isEmpty || targetName.isEmpty) {
      return;
    }

    Navigator.of(context).pop(FileRenameRule(
      courseId: _selectedCourse!.id,
      activityType: _selectedActivity,
      fileExtension: extension.toLowerCase(),
      targetName: targetName,
    ));
  }
}
