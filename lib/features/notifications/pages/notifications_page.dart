import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cumobile/data/models/notification_item.dart';
import 'package:cumobile/data/services/api_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isLoading = true;
  List<NotificationItem> _educationItems = [];
  List<NotificationItem> _otherItems = [];
  static final Logger _log = Logger('NotificationsPage');
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Уведомления',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E676),
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[500],
          tabs: const [
            Tab(text: 'Учеба'),
            Tab(text: 'Другое'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList('Education'),
                _buildList('Others'),
              ],
            ),
    );
  }

  Widget _buildList(String category) {
    final items = category == 'Education' ? _educationItems : _otherItems;
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Нет уведомлений',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => _buildCard(items[index]),
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemCount: items.length,
    );
  }

  Widget _buildCard(NotificationItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _iconFor(item.icon, item.category),
              size: 18,
              color: const Color(0xFF00E676),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateFormat.format(item.createdAt.toLocal()),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.description.trim(),
                    style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                  ),
                ],
                if (item.link != null && item.link!.uri.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _openLink(item.link!.uri),
                    child: Row(
                      children: [
                        Icon(Icons.link, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.link!.label.isNotEmpty ? item.link!.label : item.link!.uri,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF00E676),
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
        return Icons.support_agent;
      case 'News':
        return Icons.campaign;
      case 'Education':
        return Icons.school;
      default:
        return category == 'Education' ? Icons.school : Icons.notifications;
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
