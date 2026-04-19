import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cumobile/core/theme/app_colors.dart';
import 'package:cumobile/data/models/course_overview.dart';
import 'package:cumobile/data/models/notification_item.dart';
import 'package:cumobile/data/services/api_service.dart';
import 'package:cumobile/features/longread/pages/longread_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _selectedSegment = 0;
  bool _isLoading = true;
  List<NotificationItem> _educationItems = [];
  List<NotificationItem> _otherItems = [];
  static final Logger _log = Logger('NotificationsPage');
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');

  @override
  void initState() {
    super.initState();
    if (!Platform.isIOS) {
      _tabController = TabController(length: 2, vsync: this);
    }
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final results = await Future.wait([
        apiService.fetchNotifications(category: 1),
        apiService.fetchNotifications(category: 2),
      ]);
      final education = results[0];
      final other = results[1];
      education.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      other.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _educationItems = education;
        _otherItems = other;
        _isLoading = false;
      });
    } catch (e, st) {
      _log.warning('Error loading notifications', e, st);
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
        : (isIos
            ? _buildCupertinoBody()
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildList('Education'),
                  _buildList('Others'),
                ],
              ));

    if (isIos) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Уведомления'),
        ),
        backgroundColor: c.background,
        child: SafeArea(top: false, bottom: false, child: body),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Уведомления',
          style: TextStyle(color: c.textPrimary, fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: c.accent,
          indicatorWeight: 2,
          labelColor: c.textPrimary,
          unselectedLabelColor: c.textTertiary,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Учеба'),
            Tab(text: 'Другое'),
          ],
        ),
      ),
      body: body,
    );
  }

  Widget _buildCupertinoBody() {
    final c = AppColors.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: _selectedSegment,
            thumbColor: c.surface,
            backgroundColor: c.background,
            children: const {
              0: Padding(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Text('Учеба'),
              ),
              1: Padding(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Text('Другое'),
              ),
            },
            onValueChanged: (value) {
              if (value == null) return;
              setState(() => _selectedSegment = value);
            },
          ),
        ),
        Expanded(
          child: _selectedSegment == 0 ? _buildList('Education') : _buildList('Others'),
        ),
      ],
    );
  }

  Widget _buildList(String category) {
    final c = AppColors.of(context);
    final items = category == 'Education' ? _educationItems : _otherItems;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    if (items.isEmpty) {
      if (Platform.isIOS) {
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: _loadNotifications),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Нет уведомлений',
                  style: TextStyle(color: c.textTertiary),
                ),
              ),
            ),
          ],
        );
      }
      return RefreshIndicator(
        onRefresh: _loadNotifications,
        color: c.accent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Text(
                  'Нет уведомлений',
                  style: TextStyle(color: c.textTertiary),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (Platform.isIOS) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _loadNotifications),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index.isOdd) {
                    return const SizedBox(height: 8);
                  }
                  final itemIndex = index ~/ 2;
                  return _buildCard(items[itemIndex]);
                },
                childCount: math.max(0, items.length * 2 - 1),
              ),
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: c.accent,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        itemBuilder: (context, index) => _buildCard(items[index]),
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemCount: items.length,
      ),
    );
  }

  Widget _buildCard(NotificationItem item) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _iconFor(item.icon, item.category),
              size: 18,
              color: c.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateFormat.format(item.createdAt.toLocal()),
                  style: TextStyle(fontSize: 11, color: c.textTertiary),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.description.trim(),
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                ],
                if (item.link != null && item.link!.uri.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _openLink(item.link!.uri),
                    child: Row(
                      children: [
                        Icon(
                          isIos ? CupertinoIcons.link : Icons.link,
                          size: 14,
                          color: c.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.link!.label.isNotEmpty ? item.link!.label : item.link!.uri,
                            style: TextStyle(
                              fontSize: 12,
                              color: c.accent,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String icon, String category) {
    switch (icon) {
      case 'ServiceDesk':
        return Platform.isIOS ? CupertinoIcons.headphones : Icons.support_agent;
      case 'News':
        return Platform.isIOS ? CupertinoIcons.news : Icons.campaign;
      case 'Education':
        return Platform.isIOS ? CupertinoIcons.book : Icons.school;
      default:
        return category == 'Education'
            ? (Platform.isIOS ? CupertinoIcons.book : Icons.school)
            : (Platform.isIOS ? CupertinoIcons.bell : Icons.notifications);
    }
  }

  static final _longreadPattern = RegExp(
    r'my\.centraluniversity\.ru/learn/courses/view/actual/\d+/themes/\d+/longreads/(\d+)',
  );

  Future<void> _openLink(String url) async {
    final longreadMatch = _longreadPattern.firstMatch(url);
    if (longreadMatch != null) {
      final longreadId = int.tryParse(longreadMatch.group(1) ?? '');
      if (longreadId != null) {
        _openLongread(longreadId);
        return;
      }
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openLongread(int longreadId) {
    final c = AppColors.of(context);
    final themeColor = c.accent;
    final longread = Longread(
      id: longreadId,
      type: '',
      name: 'Загрузка...',
      state: '',
      exercises: [],
    );
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(
              builder: (context) => LongreadPage(
                longread: longread,
                themeColor: themeColor,
              ),
            )
          : MaterialPageRoute(
              builder: (context) => LongreadPage(
                longread: longread,
                themeColor: themeColor,
              ),
            ),
    );
  }
}
