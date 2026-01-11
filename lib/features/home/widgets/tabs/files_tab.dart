import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

class FilesTab extends StatelessWidget {
  final List<FileSystemEntity> files;
  final bool isLoading;
  final Set<String> selectedFiles;
  final VoidCallback onRefresh;
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
    required this.onDeleteAll,
    required this.onDeleteSelected,
    required this.onDelete,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && files.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      );
    }

    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'Нет скачанных файлов',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRefresh,
              child: const Text('Обновить', style: TextStyle(color: Color(0xFF00E676))),
            ),
          ],
        ),
      );
    }

    final totalSize = files.fold<int>(
      0,
      (sum, file) => sum + (file as File).lengthSync(),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${files.length} файлов • ${_formatFileSize(totalSize)}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const Spacer(),
              if (selectedFiles.isNotEmpty)
                TextButton.icon(
                  onPressed: onDeleteSelected,
                  icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                  label: Text(
                    'Удалить (${selectedFiles.length})',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: onDeleteAll,
                  icon: Icon(Icons.delete_sweep, size: 18, color: Colors.grey[500]),
                  label: Text(
                    'Удалить все',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => onRefresh(),
            color: const Color(0xFF00E676),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index] as File;
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
    final stat = file.statSync();
    final name = file.path.split('/').last;
    final ext = _getFileExtension(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF00E676).withValues(alpha: 0.1)
            : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: const Color(0xFF00E676), width: 1)
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    ext.length > 4 ? ext.substring(0, 4) : ext,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E676),
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
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatFileSize(stat.size)} • ${DateFormat('dd.MM.yyyy').format(stat.modified)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isSelected)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              else
                Icon(Icons.open_in_new, size: 18, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
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
}
