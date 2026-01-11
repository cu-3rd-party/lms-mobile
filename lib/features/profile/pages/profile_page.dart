import 'package:flutter/material.dart';
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
  static const String _caldavServer = 'caldav.yandex.ru';
  static const String _guideUrl =
      'https://yandex.ru/support/yandex-360/customers/calendar/web/ru/sync/sync-desktop?ysclid=mfnvr3tyy654330747&tabs=defaultTabsGroup-ao4idw1j_macos';
  static const String _prefsEmailKey = 'caldav_email';
  static const String _prefsPasswordKey = 'caldav_password';

  final TextEditingController _passwordController = TextEditingController();
  bool _isSaving = false;
  bool _isPasswordVisible = false;
  String? _caldavEmail;
  bool _isConnected = false;
  bool _hasSavedPassword = false;

  @override
  void initState() {
    super.initState();
    _caldavEmail = widget.profile.universityEmail;
    _loadCaldavState();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadCaldavState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_prefsEmailKey);
    final savedPassword = prefs.getString(_prefsPasswordKey);
    if (!mounted) return;
    setState(() {
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _caldavEmail = savedEmail;
      }
      _isConnected = savedEmail != null && savedPassword != null;
      _hasSavedPassword = savedPassword != null && savedPassword.isNotEmpty;
    });
  }

  Future<void> _saveCaldav() async {
    final password = _passwordController.text.trim();
    if (_caldavEmail == null || _caldavEmail!.isEmpty) {
      _showSnackBar('Не удалось определить почту CU');
      return;
    }
    if (password.isEmpty) {
      _showSnackBar('Введите пароль от CalDAV');
      return;
    }
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsEmailKey, _caldavEmail!);
    await prefs.setString(_prefsPasswordKey, password);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isConnected = true;
      _hasSavedPassword = true;
    });
    widget.onCalendarChanged?.call();
    _showSnackBar('Календарь подключен');
  }

  Future<void> _disconnectCaldav() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsEmailKey);
    await prefs.remove(_prefsPasswordKey);
    if (!mounted) return;
    setState(() {
      _isConnected = false;
      _hasSavedPassword = false;
    });
    widget.onCalendarChanged?.call();
    _showSnackBar('Интеграция отключена');
  }

  void _showSnackBar(String message) {
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
          ],
        ),
      ),
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
                  'Календарь (CalDAV)',
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
          _buildRow('Сервер', _caldavServer),
          _buildRow('Email', _caldavEmail ?? '-'),
          const SizedBox(height: 8),
          if (_hasSavedPassword)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Пароль календаря установлен',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
          Text(
            'Пароль CalDAV',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[500],
                ),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveCaldav,
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
                          _isConnected ? 'Обновить пароль' : 'Подключить',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              if (_isConnected) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _disconnectCaldav,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Отключить',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _openGuide,
            child: const Text(
              'Гайд: как получить пароль приложения',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF00E676),
                decoration: TextDecoration.underline,
              ),
            ),
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
