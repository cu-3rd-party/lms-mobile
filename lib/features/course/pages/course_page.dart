import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:cumobile/core/theme/app_colors.dart';
import 'package:cumobile/data/models/course.dart';
import 'package:cumobile/data/models/course_overview.dart';
import 'package:cumobile/features/longread/pages/longread_page.dart';
import 'package:cumobile/data/services/api_service.dart';

class CoursePage extends StatefulWidget {
  final Course course;

  const CoursePage({super.key, required this.course});

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  CourseOverview? _overview;
  bool _isLoading = true;
  static final Logger _log = Logger('CoursePage');
  final Set<int> _expandedThemes = {};
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    try {
      final overview = await apiService.fetchCourseOverview(widget.course.id);
      setState(() {
        _overview = overview;
        _isLoading = false;
      });
    } catch (e, st) {
      _log.warning('Error loading course overview', e, st);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    final body = _isLoading
        ? Center(
            child: isIos
                ? CupertinoActivityIndicator(
                    radius: 14,
                    color: c.accent,
                  )
                : CircularProgressIndicator(color: c.accent),
          )
        : _overview == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isIos ? CupertinoIcons.exclamationmark_triangle : Icons.error_outline,
                      color: c.textTertiary,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Не удалось загрузить курс',
                      style: TextStyle(color: c.textTertiary),
                    ),
                  ],
                ),
              )
            : _buildThemesList();

    if (isIos) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: _isSearching
              ? CupertinoTextField(
                  controller: _searchController,
                  placeholder: 'Поиск...',
                  placeholderStyle: TextStyle(
                    color: c.textTertiary,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                  autofocus: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                )
              : Text(
                  widget.course.cleanName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSearching)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _closeSearch,
                  child: const Text('Отмена', style: TextStyle(fontSize: 14)),
                )
              else
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() => _isSearching = true),
                  child: const Icon(CupertinoIcons.search, size: 22),
                ),
            ],
          ),
        ),
        backgroundColor: c.background,
        child: SafeArea(top: false, bottom: false, child: body),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.background,
        leading: IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.arrow_back, color: c.textPrimary),
          onPressed: _isSearching ? _closeSearch : () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Поиск...',
                  hintStyle: TextStyle(
                    color: c.textTertiary,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              )
            : Text(
                widget.course.cleanName,
                style: TextStyle(color: c.textPrimary, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: Icon(Icons.search, color: c.textPrimary),
              onPressed: () => setState(() => _isSearching = true),
            ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildThemesList() {
    final c = AppColors.of(context);
    final themes = _overview!.themes;
    if (themes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Platform.isIOS ? CupertinoIcons.folder : Icons.folder_open,
              color: c.textTertiary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Нет доступных тем',
              style: TextStyle(color: c.textTertiary),
            ),
          ],
        ),
      );
    }

    final query = _searchQuery.trim().toLowerCase();
    final filteredThemes = query.isEmpty
        ? themes
        : themes
            .map((theme) {
              if (theme.name.toLowerCase().contains(query)) {
                return theme;
              }
              final matchingLongreads = theme.longreads
                  .where((lr) =>
                      lr.name.toLowerCase().contains(query) ||
                      lr.exercises.any((ex) =>
                          ex.name.toLowerCase().contains(query) ||
                          (ex.activity?.name.toLowerCase().contains(query) ?? false)))
                  .toList();
              if (matchingLongreads.isEmpty) {
                return null;
              }
              return CourseTheme(
                id: theme.id,
                name: theme.name,
                order: theme.order,
                state: theme.state,
                longreads: matchingLongreads,
              );
            })
            .whereType<CourseTheme>()
            .toList();

    if (filteredThemes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Platform.isIOS ? CupertinoIcons.search : Icons.search,
              color: c.textTertiary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Ничего не найдено',
              style: TextStyle(color: c.textTertiary),
            ),
          ],
        ),
      );
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final listPadding = EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset);

    if (Platform.isIOS) {
      return ListView.builder(
        padding: listPadding,
        itemCount: filteredThemes.length,
        itemBuilder: (context, index) {
          final theme = filteredThemes[index];
          return _buildThemeCardCupertino(theme, index + 1);
        },
      );
    }

    return ListView.builder(
      padding: listPadding,
      itemCount: filteredThemes.length,
      itemBuilder: (context, index) {
        final theme = filteredThemes[index];
        return _buildThemeCard(theme, index + 1);
      },
    );
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Widget _buildThemeCard(CourseTheme theme, int number) {
    final c = AppColors.of(context);
    final isExpanded = _expandedThemes.contains(theme.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: () => _toggleTheme(theme.id),
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: widget.course.categoryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$number',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: widget.course.categoryColor,
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
                            theme.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: c.textPrimary,
                            ),
                          ),
                          if (theme.hasExercises)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${theme.totalExercises} ${_pluralize(theme.totalExercises, 'задание', 'задания', 'заданий')}',
                                style: TextStyle(fontSize: 12, color: c.textTertiary),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: c.textTertiary,
                      size: 24,
                    ),
                  ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                      child: Column(
                        children: theme.longreads
                            .map((lr) => _buildLongread(theme, lr))
                            .toList(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCardCupertino(CourseTheme theme, int number) {
    final c = AppColors.of(context);
    final isExpanded = _expandedThemes.contains(theme.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleTheme(theme.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.course.categoryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '$number',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: widget.course.categoryColor,
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
                          theme.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: c.textPrimary,
                          ),
                        ),
                        if (theme.hasExercises)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${theme.totalExercises} ${_pluralize(theme.totalExercises, 'задание', 'задания', 'заданий')}',
                              style: TextStyle(fontSize: 12, color: c.textTertiary),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                    color: c.textTertiary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                    child: Column(
                      children: theme.longreads
                          .map((lr) => _buildLongread(theme, lr))
                          .toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildLongread(CourseTheme theme, Longread longread) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    return GestureDetector(
      onTap: () => _openLongread(theme, longread),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  longread.exercises.isEmpty
                      ? (isIos ? CupertinoIcons.doc_plaintext : Icons.description)
                      : (isIos ? CupertinoIcons.square_list : Icons.assignment),
                  size: 16,
                  color: widget.course.categoryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    longread.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  isIos ? CupertinoIcons.chevron_forward : Icons.chevron_right,
                  size: 18,
                  color: c.textTertiary,
                ),
              ],
            ),
            if (longread.exercises.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...longread.exercises.map((ex) => _buildExercise(theme, longread, ex)),
            ],
          ],
        ),
      ),
    );
  }

  void _openLongread(CourseTheme theme, Longread longread) {
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(
              builder: (context) => LongreadPage(
                longread: longread,
                themeColor: widget.course.categoryColor,
                courseName: widget.course.cleanName,
                themeName: theme.name,
                courseId: widget.course.id,
                themeId: theme.id,
              ),
            )
          : MaterialPageRoute(
              builder: (context) => LongreadPage(
                longread: longread,
                themeColor: widget.course.categoryColor,
                courseName: widget.course.cleanName,
                themeName: theme.name,
                courseId: widget.course.id,
                themeId: theme.id,
              ),
            ),
    );
  }

  Widget _buildExercise(CourseTheme theme, Longread longread, ThemeExercise exercise) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    final content = Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name,
            style: TextStyle(fontSize: 12, color: c.textPrimary),
          ),
          const SizedBox(height: 6),
          if (exercise.deadline != null)
            Row(
              children: [
                Icon(
                  isIos ? CupertinoIcons.time : Icons.access_time,
                  size: 12,
                  color: exercise.isOverdue ? c.danger : c.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  exercise.formattedDeadline,
                  style: TextStyle(
                    fontSize: 11,
                    color: exercise.isOverdue ? c.danger : c.textTertiary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    return isIos
        ? GestureDetector(
            onTap: () => _openExercise(theme, longread, exercise),
            child: content,
          )
        : InkWell(
            onTap: () => _openExercise(theme, longread, exercise),
            borderRadius: BorderRadius.circular(6),
            child: content,
          );
  }

  void _toggleTheme(int themeId) {
    setState(() {
      if (_expandedThemes.contains(themeId)) {
        _expandedThemes.remove(themeId);
      } else {
        _expandedThemes.add(themeId);
      }
    });
  }

  void _openExercise(CourseTheme theme, Longread longread, ThemeExercise exercise) {
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(
              builder: (context) => LongreadPage(
                longread: longread,
                themeColor: widget.course.categoryColor,
                courseName: widget.course.cleanName,
                themeName: theme.name,
                courseId: widget.course.id,
                themeId: theme.id,
                selectedExerciseName: exercise.name,
              ),
            )
          : MaterialPageRoute(
              builder: (context) => LongreadPage(
                longread: longread,
                themeColor: widget.course.categoryColor,
                courseName: widget.course.cleanName,
                themeName: theme.name,
                courseId: widget.course.id,
                themeId: theme.id,
                selectedExerciseName: exercise.name,
              ),
            ),
    );
  }

  String _pluralize(int count, String one, String few, String many) {
    if (count % 10 == 1 && count % 100 != 11) return one;
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) return few;
    return many;
  }
}
