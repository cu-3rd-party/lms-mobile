import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:cumobile/core/services/file_rename_service.dart';

enum FileRenameChoice { keepOriginal, useRule, custom }

class FileRenameResult {
  final String name;
  final bool saveAsRule;

  FileRenameResult({required this.name, this.saveAsRule = false});
}

class FileRenameDialog extends StatefulWidget {
  final String originalName;
  final int courseId;
  final String? courseName;
  final String? activityType;

  const FileRenameDialog({
    super.key,
    required this.originalName,
    required this.courseId,
    this.courseName,
    this.activityType,
  });

  static Future<FileRenameResult?> show({
    required BuildContext context,
    required String originalName,
    required int courseId,
    String? courseName,
    String? activityType,
  }) async {
    return showDialog<FileRenameResult>(
      context: context,
      builder: (context) => FileRenameDialog(
        originalName: originalName,
        courseId: courseId,
        courseName: courseName,
        activityType: activityType,
      ),
    );
  }

  @override
  State<FileRenameDialog> createState() => _FileRenameDialogState();
}

class _FileRenameDialogState extends State<FileRenameDialog> {
  static const _accentColor = Color(0xFF00E676);

  late FileRenameChoice _choice;
  late TextEditingController _customController;
  FileRenameRule? _rule;
  bool _saveAsRule = false;

  String get _extension => p.extension(widget.originalName);
  String get _nameWithoutExtension =>
      p.basenameWithoutExtension(widget.originalName);

  @override
  void initState() {
    super.initState();
    _rule = FileRenameService.instance.findRule(
      courseId: widget.courseId,
      activityType: widget.activityType,
      fileExtension: _extension,
    );
    _choice = _rule != null ? FileRenameChoice.useRule : FileRenameChoice.keepOriginal;
    _customController = TextEditingController(text: _nameWithoutExtension);
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;

    if (isIos) {
      return CupertinoAlertDialog(
        title: const Text('Имя файла'),
        content: _buildContent(isIos),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: _submit,
            child: const Text('Готово'),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text(
        'Имя файла',
        style: TextStyle(color: Colors.white),
      ),
      content: _buildContent(isIos),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Отмена', style: TextStyle(color: Colors.grey[400])),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Готово', style: TextStyle(color: _accentColor)),
        ),
      ],
    );
  }

  Widget _buildContent(bool isIos) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
      _buildOption(
        isIos: isIos,
        value: FileRenameChoice.keepOriginal,
        title: 'Оставить оригинальное',
        subtitle: widget.originalName,
          ),
          if (_rule != null) ...[
            const SizedBox(height: 8),
        _buildOption(
          isIos: isIos,
          value: FileRenameChoice.useRule,
          title: 'Использовать шаблон',
          subtitle: '${_rule!.targetName}$_extension',
            ),
          ],
          const SizedBox(height: 8),
          _buildOption(
            isIos: isIos,
            value: FileRenameChoice.custom,
            title: 'Своё название',
            subtitle: null,
          ),
          if (_choice == FileRenameChoice.custom) ...[
            const SizedBox(height: 12),
            _buildCustomInput(isIos),
            if (_rule == null) ...[
              const SizedBox(height: 8),
              _buildSaveAsRuleCheckbox(isIos),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildOption({
    required bool isIos,
    required FileRenameChoice value,
    required String title,
    String? subtitle,
  }) {
    final isSelected = _choice == value;
    return GestureDetector(
      onTap: () => setState(() => _choice = value),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _accentColor : Colors.grey[700]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3A3A3A) : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? (isIos ? CupertinoIcons.checkmark_circle_fill : Icons.radio_button_checked)
                    : (isIos ? CupertinoIcons.circle : Icons.radio_button_off),
                color: isSelected ? _accentColor : Colors.grey[500],
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomInput(bool isIos) {
    if (isIos) {
      return Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: _customController,
              placeholder: 'Название',
              padding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _extension,
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _customController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.all(10),
              hintText: 'Название',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _extension,
          style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSaveAsRuleCheckbox(bool isIos) {
    final label = widget.activityType != null
        ? 'Сохранить для "${widget.activityType}" (*$_extension)'
        : 'Сохранить для *$_extension';

    return GestureDetector(
      onTap: () => setState(() => _saveAsRule = !_saveAsRule),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            _saveAsRule
                ? (isIos ? CupertinoIcons.checkmark_square_fill : Icons.check_box)
                : (isIos ? CupertinoIcons.square : Icons.check_box_outline_blank),
            color: _saveAsRule ? _accentColor : Colors.grey[500],
            size: 20,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.1),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    String finalName;

    switch (_choice) {
      case FileRenameChoice.keepOriginal:
        finalName = widget.originalName;
        break;
      case FileRenameChoice.useRule:
        finalName = '${_rule!.targetName}$_extension';
        break;
      case FileRenameChoice.custom:
        final customName = _customController.text.trim();
        if (customName.isEmpty) {
          finalName = widget.originalName;
        } else {
          finalName = '$customName$_extension';
        }
        break;
    }

    // Save rule if requested
    if (_saveAsRule && _choice == FileRenameChoice.custom) {
      final customName = _customController.text.trim();
      if (customName.isNotEmpty) {
        FileRenameService.instance.addRule(
          FileRenameRule(
            courseId: widget.courseId,
            activityType: widget.activityType,
            fileExtension: _extension.replaceAll('.', ''),
            targetName: customName,
          ),
        );
      }
    }

    Navigator.of(context).pop(FileRenameResult(
      name: finalName,
      saveAsRule: _saveAsRule,
    ));
  }
}
