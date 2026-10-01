import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:cumobile/core/theme/app_colors.dart';
import 'package:cumobile/data/models/campus_map.dart';

class CampusMapPage extends StatefulWidget {
  final String? destination;

  const CampusMapPage({super.key, this.destination});

  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}

class _CampusMapPageState extends State<CampusMapPage> {
  static const Color _routeColor = Color(0xFF1845F0);
  static const Color _fromColor = Color(0xFF1845F0);
  static const Color _toColor = Color(0xFFE5484D);
  static const Set<String> _visiblePinCategories = {'food', 'toilet', 'medical', 'entrance'};

  CampusMapData? _data;
  bool _loadFailed = false;
  CampusPlace? _from;
  CampusPlace? _to;
  int _floor = 1;
  CampusRoute _route = CampusRoute.empty;
  String? _error;
  final TransformationController _transform = TransformationController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await CampusMapData.load();
      if (!mounted) return;
      final from = data.byId('entrance-1') ?? data.places.first;
      final destination = widget.destination?.trim() ?? '';
      final requested = destination.isEmpty ? null : data.resolve(destination, from);
      setState(() {
        _data = data;
        _from = from;
        _to = requested ?? data.byId('E201');
        _floor = requested?.floor ?? from.floor;
        if (destination.isNotEmpty && requested == null) {
          _error = 'Аудитория $destination не найдена на планах';
        }
      });
      _recalculate();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  void _recalculate() {
    final data = _data;
    final from = _from;
    final to = _to;
    if (data == null || from == null || to == null) {
      setState(() => _route = CampusRoute.empty);
      return;
    }
    setState(() => _route = data.route(from, to));
  }

  void _setFrom(CampusPlace place) {
    setState(() {
      _from = place;
      _floor = place.floor;
      _error = null;
    });
    _transform.value = Matrix4.identity();
    _recalculate();
  }

  void _setTo(CampusPlace place) {
    setState(() {
      _to = place;
      _error = null;
    });
    _recalculate();
  }

  void _swap() {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    setState(() {
      _from = to;
      _to = from;
      _floor = to.floor;
      _error = null;
    });
    _transform.value = Matrix4.identity();
    _recalculate();
  }

  void _quickAction(String category) {
    final data = _data;
    final from = _from;
    if (data == null || from == null) return;
    final target = data.nearestOfCategory(category, from);
    setState(() {
      _to = target;
      _floor = from.floor;
      _error = null;
    });
    _recalculate();
  }

  void _changeFloor(int floor) {
    if (floor == _floor) return;
    setState(() => _floor = floor);
    _transform.value = Matrix4.identity();
  }

  Future<void> _pickPlace({required bool isFrom}) async {
    final data = _data;
    final from = _from;
    if (data == null || from == null) return;
    final result = await showModalBottomSheet<_PickResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.of(context).background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PlacePickerSheet(
        data: data,
        title: isFrom ? 'Откуда' : 'Куда',
        hint: isFrom ? 'S308' : 'Аудитория, кафе, туалет…',
      ),
    );
    if (result == null || !mounted) return;
    var place = result.place;
    if (place == null) {
      final query = result.query ?? '';
      place = data.resolve(query, from);
      if (place == null) {
        final suggestion = data.suggestionFor(query);
        setState(() {
          _error = isFrom
              ? (suggestion != null
                  ? '${query.toUpperCase()} не найдена. Возможно: $suggestion'
                  : '${query.toUpperCase()} не найдена на планах этажей 1–3')
              : 'Место не найдено';
        });
        return;
      }
    }
    if (isFrom) {
      _setFrom(place);
    } else {
      _setTo(place);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    final body = _buildBody(isIos);

    if (isIos) {
      return CupertinoPageScaffold(
        backgroundColor: c.background,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: c.background,
          border: null,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: Icon(CupertinoIcons.back, color: c.accent),
          ),
          middle: Text(
            'Карта кампуса',
            style: TextStyle(color: c.textPrimary, fontSize: 16),
          ),
        ),
        child: SafeArea(bottom: false, child: body),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Карта кампуса',
          style: TextStyle(color: c.textPrimary, fontSize: 16),
        ),
      ),
      body: body,
    );
  }

  Widget _buildBody(bool isIos) {
    final c = AppColors.of(context);
    if (_loadFailed) {
      return Center(
        child: Text('Не удалось загрузить карту', style: TextStyle(color: c.textTertiary)),
      );
    }
    final data = _data;
    if (data == null) {
      return Center(
        child: isIos
            ? CupertinoActivityIndicator(radius: 14, color: c.accent)
            : CircularProgressIndicator(color: c.accent),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
      children: [
        _buildControls(isIos),
        const SizedBox(height: 12),
        _buildFloorTabs(isIos),
        const SizedBox(height: 10),
        _buildMap(data),
        ..._buildRouteHints(),
      ],
    );
  }

  Widget _buildControls(bool isIos) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildPlaceField(
                      label: 'Откуда',
                      place: _from,
                      color: _fromColor,
                      onTap: () => _pickPlace(isFrom: true),
                    ),
                    const SizedBox(height: 8),
                    _buildPlaceField(
                      label: 'Куда',
                      place: _to,
                      color: _toColor,
                      onTap: () => _pickPlace(isFrom: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              isIos
                  ? CupertinoButton(
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(36, 36),
                      onPressed: _swap,
                      child: Icon(CupertinoIcons.arrow_up_arrow_down, color: c.accent, size: 20),
                    )
                  : IconButton(
                      onPressed: _swap,
                      icon: Icon(Icons.swap_vert, color: c.accent),
                      tooltip: 'Поменять местами',
                    ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: c.danger, fontSize: 12)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickAction('Туалет', isIos ? CupertinoIcons.person_2 : Icons.wc, 'toilet'),
              _buildQuickAction(
                'Поесть',
                isIos ? CupertinoIcons.cart : Icons.restaurant,
                'food',
              ),
              _buildQuickAction(
                'Медпункт',
                isIos ? CupertinoIcons.heart : Icons.local_hospital,
                'medical',
              ),
              _buildQuickAction(
                'Выход',
                isIos ? CupertinoIcons.arrow_right_square : Icons.logout,
                'entrance',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceField({
    required String label,
    required CampusPlace? place,
    required Color color,
    required VoidCallback onTap,
  }) {
    final c = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 52,
              child: Text(label, style: TextStyle(fontSize: 12, color: c.textTertiary)),
            ),
            Expanded(
              child: Text(
                place == null
                    ? 'Выберите место'
                    : '${place.name} · ${place.floor} этаж',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: place == null ? c.textTertiary : c.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(String label, IconData icon, String category) {
    final c = AppColors.of(context);
    final active = _to?.category == category;
    final color = active ? c.accent : c.textSecondary;
    return GestureDetector(
      onTap: () => _quickAction(category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.accent.withValues(alpha: 0.15) : c.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildFloorTabs(bool isIos) {
    final c = AppColors.of(context);
    final routeFloors = _route.paths.keys.toSet();
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: _floor,
        backgroundColor: c.surface,
        thumbColor: c.accent.withValues(alpha: 0.3),
        children: {
          for (final floor in CampusMapData.floorNumbers)
            floor: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$floor этаж',
                    style: TextStyle(fontSize: 13, color: c.textPrimary),
                  ),
                  if (routeFloors.contains(floor)) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _routeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        },
        onValueChanged: (value) {
          if (value != null) _changeFloor(value);
        },
      ),
    );
  }

  Widget _buildMap(CampusMapData data) {
    final c = AppColors.of(context);
    final floor = _floor;
    final path = _route.paths[floor]?.points ?? const <Offset>[];
    final rooms = data.places.where((p) => p.floor == floor && p.isRoom).toList();
    final pins = data.places
        .where((p) =>
            p.floor == floor &&
            !p.isRoom &&
            (p.id == _from?.id ||
                p.id == _to?.id ||
                _visiblePinCategories.contains(p.category)))
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: Colors.white,
        child: AspectRatio(
          aspectRatio: data.aspectRatio(floor),
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: 6,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                Offset toLocal(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        CampusMapData.floorAsset(floor),
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RoutePainter(
                          points: path.map(toLocal).toList(),
                          color: _routeColor,
                        ),
                      ),
                    ),
                    for (final room in rooms)
                      _positioned(
                        toLocal(data.positionOf(room)),
                        _RoomLabel(
                          id: room.id,
                          selected: room.id == _from?.id || room.id == _to?.id,
                          color: room.id == _from?.id ? _fromColor : _toColor,
                        ),
                      ),
                    for (final pin in pins)
                      _positioned(
                        toLocal(data.positionOf(pin)),
                        _Pin(
                          color: pin.id == _from?.id
                              ? _fromColor
                              : pin.id == _to?.id
                                  ? _toColor
                                  : c.textSecondary,
                          selected: pin.id == _from?.id || pin.id == _to?.id,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _positioned(Offset center, Widget child) {
    return Positioned(
      left: center.dx,
      top: center.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: child,
      ),
    );
  }

  List<Widget> _buildRouteHints() {
    final c = AppColors.of(context);
    final from = _from;
    final to = _to;
    if (from == null || to == null) return const [];
    final hints = <Widget>[];
    final pathOnFloor = _route.paths[_floor]?.points ?? const [];
    if (from.floor != to.floor) {
      final other = from.floor == _floor ? to.floor : from.floor;
      hints.add(
        GestureDetector(
          onTap: () => _changeFloor(other),
          child: Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _routeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.stairs_outlined, size: 18, color: _routeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Перейдите на $other этаж',
                    style: const TextStyle(fontSize: 13, color: _routeColor),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: _routeColor),
              ],
            ),
          ),
        ),
      );
    }
    if (pathOnFloor.isEmpty && (_floor == from.floor || _floor == to.floor) && from.id != to.id) {
      hints.add(
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'Маршрут не найден — проверьте двери на плане',
            style: TextStyle(fontSize: 12, color: c.danger),
          ),
        ),
      );
    }
    return hints;
  }
}

class _RoutePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;

  _RoutePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

class _RoomLabel extends StatelessWidget {
  final String id;
  final bool selected;
  final Color color;

  const _RoomLabel({required this.id, required this.selected, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0.5),
      decoration: BoxDecoration(
        color: selected ? color : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        id,
        style: TextStyle(
          fontSize: 6,
          height: 1.1,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : const Color(0xFF333333),
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final Color color;
  final bool selected;

  const _Pin({required this.color, required this.selected});

  @override
  Widget build(BuildContext context) {
    final size = selected ? 10.0 : 6.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: selected ? 2 : 1),
      ),
    );
  }
}

class _PickResult {
  final CampusPlace? place;
  final String? query;

  const _PickResult({this.place, this.query});
}

class _PlacePickerSheet extends StatefulWidget {
  final CampusMapData data;
  final String title;
  final String hint;

  const _PlacePickerSheet({required this.data, required this.title, required this.hint});

  @override
  State<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<_PlacePickerSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<CampusPlace> get _matches {
    final query = CampusMapData.normalize(_query);
    final places = [...widget.data.places]
      ..sort((a, b) {
        if (a.isRoom != b.isRoom) return a.isRoom ? -1 : 1;
        if (a.floor != b.floor) return a.floor - b.floor;
        return a.name.compareTo(b.name);
      });
    if (query.isEmpty) return places;
    final dotted = query.replaceAll('-', '.');
    return places
        .where((p) =>
            CampusMapData.normalize(p.id).contains(dotted) ||
            CampusMapData.normalize(p.name).contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isIos = Platform.isIOS;
    final matches = _matches;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Отмена', style: TextStyle(color: c.textTertiary)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: isIos
                  ? CupertinoSearchTextField(
                      controller: _controller,
                      autofocus: true,
                      placeholder: widget.hint,
                      style: TextStyle(color: c.textPrimary),
                      onChanged: (value) => setState(() => _query = value),
                      onSubmitted: _submit,
                    )
                  : TextField(
                      controller: _controller,
                      autofocus: true,
                      style: TextStyle(color: c.textPrimary),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                      onSubmitted: _submit,
                    ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text(
                        'Ничего не найдено',
                        style: TextStyle(color: c.textTertiary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final place = matches[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            _iconFor(place, isIos),
                            size: 20,
                            color: c.accent,
                          ),
                          title: Text(place.name, style: TextStyle(color: c.textPrimary)),
                          subtitle: Text(
                            '${place.floor} этаж',
                            style: TextStyle(color: c.textTertiary, fontSize: 12),
                          ),
                          onTap: () => Navigator.pop(context, _PickResult(place: place)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(String value) {
    if (value.trim().isEmpty) return;
    Navigator.pop(context, _PickResult(query: value));
  }

  IconData _iconFor(CampusPlace place, bool isIos) {
    switch (place.category) {
      case 'room':
        return isIos ? CupertinoIcons.book : Icons.meeting_room_outlined;
      case 'toilet':
        return isIos ? CupertinoIcons.person_2 : Icons.wc;
      case 'food':
        return isIos ? CupertinoIcons.cart : Icons.restaurant;
      case 'medical':
        return isIos ? CupertinoIcons.heart : Icons.local_hospital;
      case 'entrance':
        return isIos ? CupertinoIcons.arrow_right_square : Icons.door_front_door_outlined;
      case 'transit':
        return isIos ? CupertinoIcons.arrow_up_arrow_down : Icons.elevator_outlined;
      default:
        return isIos ? CupertinoIcons.location : Icons.place_outlined;
    }
  }
}
