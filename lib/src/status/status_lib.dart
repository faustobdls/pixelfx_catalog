// Shared by the status effects.
// Flame/smoke/ember adapted from Sprite Fusion's open-source fire & heal
// (https://www.spritefusion.com/pixel-art-vfx/fire), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

class ActorShape {
  final int w;
  final int h;
  final Uint8List data;
  final List<(int x, int y)> body;
  final List<(int x, int y)> up;
  final List<(int x, int y, int dir)> side;
  final List<(int x, int y, double nx, double ny)> outline;
  final List<int> top;
  final List<(int left, int right)> rows;

  ActorShape._({
    required this.w,
    required this.h,
    required this.data,
    required this.body,
    required this.up,
    required this.side,
    required this.outline,
    required this.top,
    required this.rows,
  });

  bool on(int x, int y) =>
      x >= 0 && y >= 0 && x < w && y < h && data[y * w + x] > 0;
}

final Expando<ActorShape> _shapes = Expando<ActorShape>();

ActorShape actorShape(ActorDefinition a) {
  final m = a.mask;
  var s = _shapes[m];
  if (s != null) return s;

  final w = m.w;
  final h = m.h;
  final data = m.data;
  bool on(int x, int y) =>
      x >= 0 && y >= 0 && x < w && y < h && data[y * w + x] > 0;

  final body = <(int, int)>[];
  final up = <(int, int)>[];
  final side = <(int, int, int)>[];
  final outline = <(int, int, double, double)>[];
  final top = <int>[];
  final rows = <(int, int)>[];

  for (var x = 0; x < w; x++) {
    var y = 0;
    while (y < h && !on(x, y)) {
      y++;
    }
    top.add(y < h ? y : -1);
  }
  for (var y = 0; y < h; y++) {
    var l = -1;
    var r = -1;
    for (var x = 0; x < w; x++) {
      if (!on(x, y)) continue;
      if (l < 0) l = x;
      r = x;
      body.add((x, y));
      if (!on(x, y - 1)) up.add((x, y));
      if (!on(x - 1, y)) side.add((x, y, -1));
      if (!on(x + 1, y)) side.add((x, y, 1));
    }
    rows.add((l, r));
  }
  for (var y = -1; y <= h; y++) {
    for (var x = -1; x <= w; x++) {
      if (on(x, y)) continue;
      var nx = 0.0;
      var ny = 0.0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (on(x + dx, y + dy)) {
            nx -= dx;
            ny -= dy;
          }
        }
      }
      if (on(x - 1, y) || on(x + 1, y) || on(x, y - 1) || on(x, y + 1)) {
        final rawL = hypot(nx, ny);
        final l = rawL == 0.0 ? 1.0 : rawL;
        outline.add((x, y, nx / l, ny / l));
      }
    }
  }

  s = ActorShape._(
    w: w,
    h: h,
    data: data,
    body: body,
    up: up,
    side: side,
    outline: outline,
    top: top,
    rows: rows,
  );
  _shapes[m] = s;
  return s;
}

int colorAt(ActorDefinition a, int x, int y) {
  final i = y * a.mask.w + x;
  if (a.pixels.isNotEmpty) return a.pixels[i];
  return a.mask.data[i] != 0 ? 0xff6b6b6b : 0;
}

double travel(double v, double g, double d, double a) => d > 0.0
    ? (g / d) * a + ((v - g / d) * (1.0 - math.exp(-d * a))) / d
    : v * a + 0.5 * g * a * a;

class ActorEye {
  final int x0, x1, y0, y1;
  final List<(int x, int y)> px;
  final int skin;
  const ActorEye(this.x0, this.x1, this.y0, this.y1, this.px, this.skin);
}

final Expando<List<ActorEye>> _eyesCache = Expando<List<ActorEye>>();

List<ActorEye> actorEyes(ActorDefinition a) {
  var list = _eyesCache[a.mask];
  if (list != null) return list;
  final explicit = a.eyes;
  if (explicit != null) {
    list = [
      for (final (x, y) in explicit)
        ActorEye(x, x, y, y + 1, [(x, y), (x, y + 1)], colorAt(a, x, y)),
    ];
    _eyesCache[a.mask] = list;
    return list;
  }
  final s = actorShape(a);
  final w = s.w;
  int col(int x, int y) => s.on(x, y) ? colorAt(a, x, y) : 0;
  bool dark(int x, int y) =>
      s.on(x, y) &&
      y < s.h * 0.4 &&
      luma(col(x, y)) < 0.15 &&
      s.on(x - 1, y) &&
      s.on(x + 1, y) &&
      s.on(x, y - 1) &&
      s.on(x, y + 1);

  final seen = <int>{};
  list = [];
  for (final (x0, y0) in s.body) {
    if (seen.contains(y0 * w + x0) || !dark(x0, y0)) continue;
    final px = <(int, int)>[];
    final q = <(int, int)>[(x0, y0)];
    seen.add(y0 * w + x0);
    while (q.isNotEmpty) {
      final (x, y) = q.removeLast();
      px.add((x, y));
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nx = x + dx;
        final ny = y + dy;
        final k = ny * w + nx;
        if (seen.contains(k) ||
            !(dark(nx, ny) || (s.on(nx, ny) && luma(col(nx, ny)) > 0.95))) {
          continue;
        }
        seen.add(k);
        q.add((nx, ny));
      }
    }
    if (px.length < 2 || px.length > 14) continue;
    var minX = 1 << 30;
    var maxX = -1 << 30;
    var minY = 1 << 30;
    var maxY = -1 << 30;
    for (final (x, y) in px) {
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    final counts = <int, int>{};
    for (final (x, y) in px) {
      for (final (dx, dy)
          in const [(1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0)]) {
        final c = col(x + dx, y + dy);
        final l = luma(c);
        if (c != 0 &&
            l > 0.5 &&
            l < 0.95 &&
            !px.any((p) => p.$1 == x + dx && p.$2 == y + dy)) {
          counts[c] = (counts[c] ?? 0) + 1;
        }
      }
    }
    if (counts.isEmpty) continue;
    final sorted = counts.entries.toList()
      ..sort((p, q) => q.value.compareTo(p.value));
    final skin = sorted.first.key;
    if (maxX - minX <= 4 && maxY - minY <= 5) {
      list.add(ActorEye(minX, maxX, minY, maxY, px, skin));
    }
  }
  list.sort((p, q) => p.x0.compareTo(q.x0));
  if (list.length > 2) list = [];
  _eyesCache[a.mask] = list;
  return list;
}
