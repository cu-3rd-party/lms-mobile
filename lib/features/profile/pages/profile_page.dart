import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cumobile/data/models/student_profile.dart';

class ProfilePage extends StatefulWidget {
  final StudentProfile profile;
  final VoidCallback onLogout;
  final VoidCallback? onCalendarChanged;

  const ProfilePage({
    super.key,
    required this.profile,
    required this.onLogout,
    this.onCalendarChanged,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String _guideUrl =
      'https://yandex.ru/support/yandex-360/customers/calendar/web/ru/export';
  static const String _prefsIcsUrlKey = 'ics_url';

  final TextEditingController _icsUrlController = TextEditingController();
  bool _isSaving = false;
  bool _isConnected = false;
  String _savedUrl = '';
  bool _hasChanges = false;
  bool _isEditing = false;
  String? _logFilePath;

  @override
  void initState() {
    super.initState();
    _icsUrlController.addListener(_onUrlChanged);
    _loadIcsState();
    _checkLogFile();
  }

  @override
  void dispose() {
    _icsUrlController.removeListener(_onUrlChanged);
    _icsUrlController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final hasChanges = _icsUrlController.text.trim() != _savedUrl;
    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  Future<void> _loadIcsState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_prefsIcsUrlKey);
    if (!mounted) return;
    setState(() {
      _isConnected = savedUrl != null && savedUrl.isNotEmpty;
      if (_isConnected) {
        _savedUrl = savedUrl!;
        _icsUrlController.text = savedUrl;
      }
    });
  }

  Future<void> _checkLogFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'logs', 'errors.log'));
      if (file.existsSync() && mounted) {
        setState(() => _logFilePath = file.path);
      }
    } catch (_) {}
  }

  Future<void> _openLogFile() async {
    if (_logFilePath == null) return;
    await OpenFilex.open(_logFilePath!);
  }

  Future<void> _saveIcsUrl() async {
    final url = _icsUrlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('Введите ссылку на iCal');
      return;
    }
    if (!url.contains('.ics') && !url.contains('ics.xml')) {
      _showSnackBar('Некорректная ссылка на iCal');
      return;
    }
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsIcsUrlKey, url);
    if (!mounted) return;
    final wasConnected = _isConnected;
    setState(() {
      _isSaving = false;
      _isConnected = true;
      _savedUrl = url;
      _hasChanges = false;
      _isEditing = false;
    });
    widget.onCalendarChanged?.call();
    _showSnackBar(wasConnected ? 'Ссылка обновлена' : 'Календарь подключен');
  }

  Future<void> _disconnectCalendar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsIcsUrlKey);
    if (!mounted) return;
    setState(() {
      _isConnected = false;
      _savedUrl = '';
      _hasChanges = false;
      _isEditing = false;
      _icsUrlController.clear();
    });
    widget.onCalendarChanged?.call();
    _showSnackBar('Интеграция отключена');
  }

  String _maskUrl(String url) {
    final tokenMatch = RegExp(r'private_token=([^&]+)').firstMatch(url);
    if (tokenMatch != null) {
      final token = tokenMatch.group(1)!;
      final masked = '${token.substring(0, 4)}${'•' * 8}';
      return url.replaceFirst(token, masked);
    }
    return url;
  }

  void _showSnackBar(String message) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _openGuide() async {
    final uri = Uri.parse(_guideUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final content = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${widget.profile.firstName[0]}${widget.profile.lastName[0]}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00E676),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.profile.fullName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.profile.course} курс • ${_translateEducationLevel(widget.profile.educationLevel)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildCalendarCard(),
          if (_logFilePath != null) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _openLogFile,
              child: Text(
                'Открыть лог ошибок',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.grey[700],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (isIos) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Профиль'),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout();
            },
            child: Icon(
              CupertinoIcons.square_arrow_right,
              color: Colors.grey[500],
              size: 22,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF121212),
        child: SafeArea(top: false, bottom: false, child: content),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Профиль',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout();
            },
            icon: Icon(Icons.logout, color: Colors.grey[500], size: 22),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildInfoCard() {
    final otherEmails =
        widget.profile.emails.where((e) => !_isCuEmail(e.value)).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRow('Логин', widget.profile.timeLogin),
          if (widget.profile.telegram != null)
            _buildRow('Telegram', '@${widget.profile.telegram}'),
          if (widget.profile.universityEmail != null)
            _buildRow('Email CU', widget.profile.universityEmail!),
          const SizedBox(height: 12),
          if (otherEmails.isNotEmpty) ...[
            Text(
              'Email',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            ...otherEmails.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.masked,
                          style: const TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          e.type,
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 8),
          if (widget.profile.phones.isNotEmpty) ...[
            Text(
              'Телефон',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            ...widget.profile.phones.map((ph) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '+${ph.masked}',
                          style: const TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ph.type,
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  bool _isCuEmail(String value) {
    final lower = value.toLowerCase();
    return lower.endsWith('@edu.centraluniversity.ru') ||
        lower.endsWith('@centraluniversity.ru');
  }

  Widget _buildCalendarCard() {
    final isIos = Platform.isIOS;
    final showInput = !_isConnected || _isEditing;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Календарь (iCal)',
                  style: TextStyle(fontSize: 15, color: Colors.white),
                ),
              ),
              if (_isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Подключено',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF00E676),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (showInput) ...[
            Text(
              'Ссылка на iCal (ICS)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 6),
            isIos
                ? CupertinoTextField(
                    controller: _icsUrlController,
                    placeholder: 'https://calendar.yandex.ru/export/ics.xml?...',
                    placeholderStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    maxLines: 2,
                    keyboardType: TextInputType.url,
                  )
                : TextField(
                    controller: _icsUrlController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 2,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      hintText: 'https://calendar.yandex.ru/export/ics.xml?...',
                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
            if (!_isConnected || _hasChanges) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: isIos
                    ? CupertinoButton.filled(
                        onPressed: _isSaving ? null : _saveIcsUrl,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _isSaving
                            ? const CupertinoActivityIndicator(
                                radius: 10,
                                color: CupertinoColors.black,
                              )
                            : Text(
                                _isConnected ? 'Сохранить' : 'Подключить',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                      )
                    : ElevatedButton(
                        onPressed: _isSaving ? null : _saveIcsUrl,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: const Color(0xFF121212),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF121212),
                                ),
                              )
                            : Text(
                                _isConnected ? 'Сохранить' : 'Подключить',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
              ),
            ],
            if (_isEditing && !_hasChanges) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _isEditing = false),
                child: Text(
                  'Отмена',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _maskUrl(_savedUrl),
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _isEditing = true),
              child: const Text(
                'Изменить ссылку',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF00E676),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: _openGuide,
                child: Text(
                  'Как получить ссылку?',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.grey[600],
                  ),
                ),
              ),
              if (_isConnected) ...[
                const Spacer(),
                GestureDetector(
                  onTap: _disconnectCalendar,
                  child: const Text(
                    'Отключить',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  static String _translateEducationLevel(String level) {
    switch (level) {
      case 'Bachelor':
        return 'Бакалавриат';
      case 'Master':
        return 'Магистратура';
      case 'Specialist':
        return 'Специалитет';
      default:
        return level;
    }
  }
}
