import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

class CampusPlace {
  final String id;
  final String name;
  final int floor;
  final double x;
  final double y;
  final String category;
  final String? toilet;

  const CampusPlace({
    required this.id,
    required this.name,
    required this.floor,
    required this.x,
    required this.y,
    required this.category,
    this.toilet,
  });

  factory CampusPlace.fromJson(Map<String, dynamic> json) {
    return CampusPlace(
      id: json['id'] as String,
      name: json['name'] as String,
      floor: (json['floor'] as num).toInt(),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      category: json['category'] as String,
      toilet: json['toilet'] as String?,
    );
  }

  bool get isRoom => category == 'room';
}

class CampusTransition {
  final String id;
  final Map<int, Offset> floors;

  const CampusTransition({required this.id, required this.floors});

  factory CampusTransition.fromJson(Map<String, dynamic> json) {
    final floors = <int, Offset>{};
    (json['floors'] as Map<String, dynamic>).forEach((key, value) {
      final point = value as List;
      floors[int.parse(key)] = Offset(
        (point[0] as num).toDouble(),
        (point[1] as num).toDouble(),
      );
    });
    return CampusTransition(id: json['id'] as String, floors: floors);
  }
}

class CampusFloorGrid {
  static const List<double> _penalties = [0, 1.5, 0.6, 0.2, 0];

  final int width;
  final int height;
  final Uint8List _bits;
  late final Uint8List _wallDistance = _buildWallDistance();

  CampusFloorGrid({required this.width, required this.height, required Uint8List bits})
      : _bits = bits;

  factory CampusFloorGrid.fromJson(Map<String, dynamic> json) {
    return CampusFloorGrid(
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      bits: base64Decode(json['bits'] as String),
    );
  }

  int get length => width * height;

  bool isNavigable(int index) => (_bits[index >> 3] & (1 << (index & 7))) != 0;

  double wallPenalty(int index) => _penalties[_wallDistance[index]];

  Uint8List _buildWallDistance() {
    final maxLevel = _penalties.length - 1;
    final distance = Uint8List(length)..fillRange(0, length, maxLevel);
    final queue = <int>[];
    for (var i = 0; i < length; i++) {
      if (!isNavigable(i)) {
        distance[i] = 0;
        queue.add(i);
      }
    }
    for (var q = 0; q < queue.length; q++) {
      final current = queue[q];
      final next = distance[current] + 1;
      if (next >= maxLevel) continue;
      final cx = current % width;
      final cy = current ~/ width;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = cx + dx;
          final ny = cy + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          final neighbor = ny * width + nx;
          if (distance[neighbor] <= next) continue;
          distance[neighbor] = next;
          queue.add(neighbor);
        }
      }
    }
    return distance;
  }
}

class CampusPath {
  final List<Offset> points;
  final double cost;

  const CampusPath({required this.points, required this.cost});
}

class CampusRoute {
  final Map<int, CampusPath> paths;

  const CampusRoute(this.paths);

  static const empty = CampusRoute({});
}

class CampusMapData {
  static const List<int> floorNumbers = [1, 2, 3];
  static const String defaultToilet = 'male';

  final List<CampusPlace> places;
  final List<CampusTransition> transitions;
  final Map<int, CampusFloorGrid> grids;
  final Map<String, Offset> roomPositions;
  final Map<String, CampusPath?> _pathCache = {};

  CampusMapData({
    required this.places,
    required this.transitions,
    required this.grids,
    required this.roomPositions,
  });

  static Future<CampusMapData>? _loading;

  static Future<CampusMapData> load() {
    return _loading ??= _load();
  }

  static Future<CampusMapData> _load() async {
    final raw = await rootBundle.loadString('assets/maps/campus_map.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final grids = <int, CampusFloorGrid>{};
    (json['grids'] as Map<String, dynamic>).forEach((key, value) {
      grids[int.parse(key)] = CampusFloorGrid.fromJson(value as Map<String, dynamic>);
    });
    final roomPositions = <String, Offset>{};
    (json['roomPositions'] as Map<String, dynamic>).forEach((key, value) {
      final point = value as List;
      roomPositions[key] = Offset(
        (point[0] as num).toDouble(),
        (point[1] as num).toDouble(),
      );
    });
    return CampusMapData(
      places: (json['pois'] as List)
          .map((e) => CampusPlace.fromJson(e as Map<String, dynamic>))
          .toList(),
      transitions: (json['transitions'] as List)
          .map((e) => CampusTransition.fromJson(e as Map<String, dynamic>))
          .toList(),
      grids: grids,
      roomPositions: roomPositions,
    );
  }

  static String floorAsset(int floor) => 'assets/maps/floor-$floor.png';

  double aspectRatio(int floor) {
    final grid = grids[floor];
    if (grid == null) return 1;
    return grid.width / grid.height;
  }

  Offset positionOf(CampusPlace place) =>
      roomPositions[place.id] ?? Offset(place.x, place.y);

  CampusPlace? byId(String id) {
    for (final place in places) {
      if (place.id == id) return place;
    }
    return null;
  }

  CampusPlace? findRoom(String input) {
    final normalized = input.trim().toUpperCase().replaceAll(RegExp(r'\s'), '');
    final dotted = normalized.replaceAll('-', '.');
    for (final place in places) {
      if (place.id == normalized || place.id == dotted) return place;
    }
    return null;
  }

  static String normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'\s+'), ' ');

  CampusPlace? resolve(String query, CampusPlace from) {
    final room = findRoom(query);
    if (room != null) return room;
    final normalized = normalize(query);
    if (normalized.isEmpty) return null;
    final exact = places
        .where((p) => normalize(p.id) == normalized || normalize(p.name) == normalized)
        .toList();
    if (exact.isNotEmpty) return nearest(exact, from);
    final partial = places.where((p) => normalize(p.name).contains(normalized)).toList();
    if (partial.isEmpty) return null;
    return nearest(preferToilet(partial), from);
  }

  String? suggestionFor(String query) {
    final match = RegExp(r'^[ESNW](\d+(?:\.\d+)?)$')
        .firstMatch(query.trim().toUpperCase().replaceAll('-', '.'));
    if (match == null) return null;
    final digits = match.group(1);
    for (final place in places) {
      if (place.isRoom && place.id.substring(1) == digits) return place.id;
    }
    return null;
  }

  List<CampusPlace> preferToilet(List<CampusPlace> candidates) {
    if (!candidates.every((p) => p.category == 'toilet')) return candidates;
    final preferred = candidates.where((p) => p.toilet == defaultToilet).toList();
    return preferred.isEmpty ? candidates : preferred;
  }

  CampusPlace nearest(List<CampusPlace> candidates, CampusPlace from) {
    final sameFloor = candidates.where((p) => p.floor == from.floor).toList();
    final pool = sameFloor.isEmpty ? candidates : sameFloor;
    CampusPlace best = pool.first;
    var bestCost = double.infinity;
    for (final place in pool) {
      final cost = place.floor == from.floor
          ? (findPath(from.floor, positionOf(from), positionOf(place))?.cost ??
              double.infinity)
          : double.infinity;
      if (cost < bestCost) {
        bestCost = cost;
        best = place;
      }
    }
    return best;
  }

  CampusPlace nearestOfCategory(String category, CampusPlace from) {
    final candidates = preferToilet(places.where((p) => p.category == category).toList());
    return nearest(candidates, from);
  }

  CampusRoute route(CampusPlace from, CampusPlace to) {
    if (from.floor == to.floor) {
      final path = findPath(from.floor, positionOf(from), positionOf(to));
      return path == null ? CampusRoute.empty : CampusRoute({from.floor: path});
    }
    CampusRoute? best;
    var bestCost = double.infinity;
    for (final transition in transitions) {
      final start = transition.floors[from.floor];
      final end = transition.floors[to.floor];
      if (start == null || end == null) continue;
      final first = findPath(from.floor, positionOf(from), start);
      final second = findPath(to.floor, end, positionOf(to));
      if (first == null || second == null) continue;
      final cost = first.cost + second.cost;
      if (cost < bestCost) {
        bestCost = cost;
        best = CampusRoute({from.floor: first, to.floor: second});
      }
    }
    return best ?? CampusRoute.empty;
  }

  CampusPath? findPath(int floor, Offset from, Offset to) {
    final key = '$floor:${from.dx},${from.dy}:${to.dx},${to.dy}';
    if (_pathCache.containsKey(key)) return _pathCache[key];
    final grid = grids[floor];
    final path = grid == null ? null : _findPath(grid, from, to);
    _pathCache[key] = path;
    return path;
  }

  static _Cell? _snap(CampusFloorGrid grid, Offset point) {
    final x = math.max(0, math.min(grid.width - 1, (point.dx * grid.width).floor()));
    final y = math.max(0, math.min(grid.height - 1, (point.dy * grid.height).floor()));
    for (var radius = 0; radius <= 8; radius++) {
      for (var cy = y - radius; cy <= y + radius; cy++) {
        for (var cx = x - radius; cx <= x + radius; cx++) {
          if (cx < 0 || cy < 0 || cx >= grid.width || cy >= grid.height) continue;
          if (radius > 0 && (cx - x).abs() != radius && (cy - y).abs() != radius) continue;
          final index = cy * grid.width + cx;
          if (grid.isNavigable(index)) return _Cell(cx, cy, index);
        }
      }
    }
    return null;
  }

  static CampusPath? _findPath(CampusFloorGrid grid, Offset fromPoint, Offset toPoint) {
    final start = _snap(grid, fromPoint);
    final goal = _snap(grid, toPoint);
    if (start == null || goal == null) return null;

    final size = grid.length;
    final parent = Int32List(size)..fillRange(0, size, -1);
    final cost = Float32List(size)..fillRange(0, size, double.infinity);
    final closed = Uint8List(size);
    cost[start.index] = 0;

    final open = _MinHeap()..push(_Node(start.index, start.x, start.y, 0, 0));
    const directions = [
      [-1, 0, 1.0],
      [1, 0, 1.0],
      [0, -1, 1.0],
      [0, 1, 1.0],
      [-1, -1, math.sqrt2],
      [1, -1, math.sqrt2],
      [-1, 1, math.sqrt2],
      [1, 1, math.sqrt2],
    ];

    while (open.isNotEmpty) {
      final node = open.pop();
      if (closed[node.index] == 1 || node.cost != cost[node.index]) continue;
      closed[node.index] = 1;
      if (node.index == goal.index) break;
      final base = cost[node.index];
      for (final dir in directions) {
        final dx = dir[0] as int;
        final dy = dir[1] as int;
        final step = dir[2] as double;
        final nx = node.x + dx;
        final ny = node.y + dy;
        if (nx < 0 || ny < 0 || nx >= grid.width || ny >= grid.height) continue;
        final next = ny * grid.width + nx;
        if (!grid.isNavigable(next)) continue;
        if (dx != 0 &&
            dy != 0 &&
            (!grid.isNavigable(node.y * grid.width + nx) ||
                !grid.isNavigable(ny * grid.width + node.x))) {
          continue;
        }
        final nextCost = base + step * (1 + grid.wallPenalty(next));
        if (nextCost >= cost[next]) continue;
        cost[next] = nextCost;
        parent[next] = node.index;
        final stored = cost[next];
        final heuristic = math.sqrt(
          math.pow(goal.x - nx, 2) + math.pow(goal.y - ny, 2),
        );
        open.push(_Node(next, nx, ny, stored, stored + heuristic));
      }
    }

    if (!cost[goal.index].isFinite) return null;
    final cells = <_Cell>[];
    var current = goal.index;
    while (current != -1) {
      cells.add(_Cell(current % grid.width, current ~/ grid.width, current));
      if (current == start.index) break;
      current = parent[current];
    }
    final ordered = cells.reversed.toList();
    final smoothed = _smooth(grid, ordered);
    return CampusPath(
      points: smoothed
          .map((c) => Offset((c.x + 0.5) / grid.width, (c.y + 0.5) / grid.height))
          .toList(),
      cost: cost[goal.index],
    );
  }

  static List<_Cell> _smooth(CampusFloorGrid grid, List<_Cell> cells) {
    if (cells.length < 3) return cells;
    final result = <_Cell>[cells.first];
    var anchor = 0;
    while (anchor < cells.length - 1) {
      var furthest = anchor + 1;
      var maxPenalty = grid.wallPenalty(cells[furthest].index);
      for (var candidate = anchor + 2; candidate < cells.length; candidate++) {
        maxPenalty = math.max(maxPenalty, grid.wallPenalty(cells[candidate].index));
        if (!_hasLineOfSight(grid, cells[anchor], cells[candidate], maxPenalty)) break;
        furthest = candidate;
      }
      result.add(cells[furthest]);
      anchor = furthest;
    }
    return result;
  }

  static bool _hasLineOfSight(CampusFloorGrid grid, _Cell from, _Cell to, double maxPenalty) {
    final steps = (math.max((to.x - from.x).abs(), (to.y - from.y).abs()) * 4).ceil();
    for (var i = 1; i < steps; i++) {
      final t = i / steps;
      final sx = from.x + (to.x - from.x) * t;
      final sy = from.y + (to.y - from.y) * t;
      final xs = {(sx + 0.5 - 1e-6).floor(), (sx + 0.5 + 1e-6).floor()};
      final ys = {(sy + 0.5 - 1e-6).floor(), (sy + 0.5 + 1e-6).floor()};
      for (final x in xs) {
        for (final y in ys) {
          final index = y * grid.width + x;
          if (!grid.isNavigable(index) || grid.wallPenalty(index) > maxPenalty) return false;
        }
      }
    }
    return true;
  }
}

class _Cell {
  final int x;
  final int y;
  final int index;

  const _Cell(this.x, this.y, this.index);
}

class _Node {
  final int index;
  final int x;
  final int y;
  final double cost;
  final double score;

  const _Node(this.index, this.x, this.y, this.cost, this.score);
}

class _MinHeap {
  final List<_Node> _items = [];

  bool get isNotEmpty => _items.isNotEmpty;

  void push(_Node node) {
    _items.add(node);
    var i = _items.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_items[parent].score <= node.score) break;
      _items[i] = _items[parent];
      i = parent;
    }
    _items[i] = node;
  }

  _Node pop() {
    final top = _items.first;
    final last = _items.removeLast();
    if (_items.isEmpty) return top;
    var i = 0;
    while (true) {
      final left = i * 2 + 1;
      final right = left + 1;
      if (left >= _items.length) break;
      final child =
          right < _items.length && _items[right].score < _items[left].score ? right : left;
      if (_items[child].score >= last.score) break;
      _items[i] = _items[child];
      i = child;
    }
    _items[i] = last;
    return top;
  }
}
