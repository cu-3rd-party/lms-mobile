import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import 'package:cumobile/core/theme/app_colors.dart';

class FilesTab extends StatelessWidget {
  final List<FileSystemEntity> files;
  final bool isLoading;
  final Set<String> selectedFiles;
  final VoidCallback onRefresh;
  final VoidCallback onOpenTemplates;
  final VoidCallback onStartScan;
  final VoidCallback onDeleteAll;
  final VoidCallback onDeleteSelected;
  final void Function(File) onDelete;
  final void Function(String) onToggleSelection;

  const FilesTab({
    super.key,
    required this.files,
    required this.isLoading,
    required this.selectedFiles,
    required this.onRefresh,
    required this.onOpenTemplates,
    required this.onStartScan,
    required this.onDeleteAll,
    required this.onDeleteSelected,
    required this.onDelete,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final sortedFiles = files.whereType<File>().toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    final isIos = Platform.isIOS;
    if (isLoading && sortedFiles.isEmpty) {
      return Center(
        child: isIos
            ? CupertinoActivityIndicator(
                radius: 14,
                color: c.accent,
              )
            : CircularProgressIndicator(color: c.accent),
      );
    }

    if (sortedFiles.isEmpty) {
      final emptyContent = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isIos ? CupertinoIcons.folder : Icons.folder_open,
            size: 64,
            color: c.textDisabled,
          ),
          const SizedBox(height: 16),
          Text(
            'Нет скачанных файлов',
            style: TextStyle(color: c.textTertiary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _TemplatesButton(isIos: isIos, onOpenTemplates: onOpenTemplates),
              isIos
                  ? CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      onPressed: onStartScan,
                      child: Text('Начать скан', style: TextStyle(color: c.onAccent)),
                    )
                  : ElevatedButton(
                      onPressed: onStartScan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: c.onAccent,
                      ),
                      child: const Text('Начать скан'),
                    ),
            ],
          ),
        ],
      );

      if (isIos) {
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: () async => onRefresh()),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: emptyContent),
            ),
          ],
        );
      }

      return RefreshIndicator(
        onRefresh: () async => onRefresh(),
        color: c.accent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            Center(child: emptyContent),
          ],
        ),
      );
    }

    final totalSize = sortedFiles.fold<int>(0, (sum, file) => sum + file.lengthSync());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _TemplatesCallout(isIos: isIos, onOpenTemplates: onOpenTemplates),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _ScanCallout(isIos: isIos, onStartScan: onStartScan),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${sortedFiles.length} файлов • ${_formatFileSize(totalSize)}',
                style: TextStyle(fontSize: 13, color: c.textTertiary),
              ),
              const Spacer(),
              if (selectedFiles.isNotEmpty)
                isIos
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: onDeleteSelected,
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.delete, size: 18, color: c.danger),
                            const SizedBox(width: 6),
                            Text(
                              'Удалить (${selectedFiles.length})',
                              style: TextStyle(color: c.danger, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : TextButton.icon(
                        onPressed: onDeleteSelected,
                        icon: Icon(Icons.delete, size: 18, color: c.danger),
                        label: Text(
                          'Удалить (${selectedFiles.length})',
                          style: TextStyle(color: c.danger, fontSize: 12),
                        ),
                      )
              else
                isIos
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: onDeleteAll,
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.delete_solid,
                              size: 18,
                              color: c.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Удалить все',
                              style: TextStyle(color: c.textTertiary, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : TextButton.icon(
                        onPressed: onDeleteAll,
                        icon: Icon(Icons.delete_sweep, size: 18, color: c.textTertiary),
                        label: Text(
                          'Удалить все',
                          style: TextStyle(color: c.textTertiary, fontSize: 12),
                        ),
                      ),
            ],
          ),
        ),
        Expanded(
          child: isIos
              ? CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    CupertinoSliverRefreshControl(onRefresh: () async => onRefresh()),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final file = sortedFiles[index];
                            return _FileListItem(
                              file: file,
                              isSelected: selectedFiles.contains(file.path),
                              onTap: () => OpenFilex.open(file.path),
                              onLongPress: () => onToggleSelection(file.path),
                              onDelete: () => onDelete(file),
                            );
                          },
                          childCount: sortedFiles.length,
                        ),
                      ),
                    ),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: () async => onRefresh(),
                  color: c.accent,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sortedFiles.length,
                    itemBuilder: (context, index) {
                      final file = sortedFiles[index];
                      return _FileListItem(
                        file: file,
                        isSelected: selectedFiles.contains(file.path),
                        onTap: () => OpenFilex.open(file.path),
                        onLongPress: () => onToggleSelection(file.path),
                        onDelete: () => onDelete(file),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _TemplatesButton extends StatelessWidget {
  final bool isIos;
  final VoidCallback onOpenTemplates;

  const _TemplatesButton({required this.isIos, required this.onOpenTemplates});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (isIos) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        onPressed: onOpenTemplates,
        child: Text(
          'Шаблоны имён',
          style: TextStyle(color: c.accent, fontSize: 14),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onOpenTemplates,
      style: OutlinedButton.styleFrom(
        foregroundColor: c.accent,
        side: BorderSide(color: c.accent),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      icon: const Icon(Icons.description_outlined, size: 18),
      label: const Text('Шаблоны имён'),
    );
  }
}

class _TemplatesCallout extends StatelessWidget {
  final bool isIos;
  final VoidCallback onOpenTemplates;

  const _TemplatesCallout({required this.isIos, required this.onOpenTemplates});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final radius = BorderRadius.circular(12);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onOpenTemplates,
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: radius,
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isIos ? CupertinoIcons.doc_text : Icons.description_outlined,
                  color: c.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Шаблоны имён файлов',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Автопереименование вложений',
                      style: TextStyle(color: c.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                isIos ? CupertinoIcons.chevron_right : Icons.chevron_right,
                color: c.textTertiary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanCallout extends StatelessWidget {
  final bool isIos;
  final VoidCallback onStartScan;

  const _ScanCallout({required this.isIos, required this.onStartScan});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final radius = BorderRadius.circular(12);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onStartScan,
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: radius,
            border: Border.all(color: c.accent.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isIos ? CupertinoIcons.viewfinder : Icons.document_scanner_outlined,
                  color: c.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Сканировать работу',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              isIos
                  ? CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      onPressed: onStartScan,
                      child: Text(
                        'Начать',
                        style: TextStyle(color: c.onAccent),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: onStartScan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: c.onAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      child: const Text('Начать'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileListItem extends StatelessWidget {
  final File file;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  const _FileListItem({
    required this.file,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    final stat = file.statSync();
    final name = _visibleName(file);
    final ext = _getFileExtension(name);

    final content = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? c.accent.withValues(alpha: 0.1)
            : c.surface,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: c.accent, width: 1)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  ext.length > 4 ? ext.substring(0, 4) : ext,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: c.accent,
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
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatFileSize(stat.size)} • ${DateFormat('dd.MM.yyyy HH:mm').format(stat.modified)}',
                    style: TextStyle(fontSize: 11, color: c.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              isIos
                  ? CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: onDelete,
                      child: Icon(
                        CupertinoIcons.delete,
                        color: c.danger,
                        size: 20,
                      ),
                    )
                  : IconButton(
                      onPressed: onDelete,
                      icon: Icon(
                        isIos ? CupertinoIcons.delete : Icons.delete,
                        color: c.danger,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
            else
              Icon(
                isIos ? CupertinoIcons.arrow_up_right_square : Icons.open_in_new,
                size: 18,
                color: c.textTertiary,
              ),
          ],
        ),
      ),
    );

    return isIos
        ? GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: content,
          )
        : InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: content,
          );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _getFileExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1 || lastDot == path.length - 1) return '';
    return path.substring(lastDot + 1).toUpperCase();
  }

  String _visibleName(File file) {
    final base = p.basename(file.path);
    final match = RegExp(r'^(.*)__dup\d+(\.[^.]+)$').firstMatch(base);
    if (match != null) {
      return '${match.group(1)}${match.group(2)}';
    }
    return base;
  }
}
