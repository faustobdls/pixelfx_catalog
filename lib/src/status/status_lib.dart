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

/// 1D value noise in [-1, 1] whose lattice wraps every [period] cells.
double wnoise(double x, int period, [int seed = 0]) {
  final i = x.floor();
  final f = x - i;
  final u = f * f * (3.0 - 2.0 * f);
  final a = rand(wrapInt(i, period), seed);
  final b = rand(wrapInt(i + 1, period), seed);
  return (a + (b - a) * u) * 2.0 - 1.0;
}

/// Noise of time [t] that repeats every [d] seconds, about [f] wiggles a second.
double tnoise(double t, double d, double f, [int seed = 0, double off = 0.0]) {
  final period = math.max(2, (f * d + 0.5).floor());
  return wnoise((t / d) * period + off, period, seed);
}

double travel(double v, double g, double d, double a) => d > 0.0
    ? (g / d) * a + ((v - g / d) * (1.0 - math.exp(-d * a))) / d
    : v * a + 0.5 * g * a * a;

const List<(double lw, double lh, int ri)> flameLayers = [
  (1.0, 1.0, 6),
  (0.76, 0.86, 4),
  (0.54, 0.68, 2),
  (0.3, 0.42, 0),
];

/// A flame tongue standing on ([x], [y]): [h] tall, [w] half-wide at its root.
void tongue(
  Painter p,
  double x,
  double y,
  double h,
  double w,
  double sx,
  List<int> f,
  double t,
  double d,
  int n, [
  List<(double lw, double lh, int ri)> layers = flameLayers,
]) {
  if (h < 1.0) return;
  for (final (lw, lh, ri) in layers) {
    if (ri == 0 && h < 4.0) continue;
    final bigH = h * lh;
    final col = f[ri];
    for (var r = 0; r <= bigH; r++) {
      final u = r / math.max(1.0, bigH);
      final half = w *
              lw *
              math.pow(1.0 - u, 0.85) *
              math.min(1.0, (r + 1.5) / 3.5) +
          tnoise(t, d, 9.0, n, r * 0.45) * 0.5;
      if (half < 0.3) continue;
      final cx =
          x + sx * u * u * lh + tnoise(t, d, 4.0, n + 7, r * 0.2) * u * 1.1;
      final x0 = (cx - half + 0.5).floor();
      final x1 = (cx + half + 0.5).floor();
      final py = (y - r + 0.5).floor();
      for (var px = x0; px <= x1; px++) {
        p.px(px, py, col);
      }
    }
  }
}

/// A ball of flame at age [u] (0..1) of its life, radius [size], cooling down [f].
void flame(
  Painter p,
  double x,
  double y,
  double size,
  double u,
  List<int> f, [
  double heatSeed = 0.0,
]) {
  final n = f.length;
  final k = 1.0 - u;
  final heat = math.min(0.999, math.pow(u, 0.62) + heatSeed * 0.1);
  final idx = math.min(n - 2, (heat * (n - 1)).floor());
  final r = size * (0.55 + 0.45 * math.min(1.0, u * 7.0)) * (1.0 - u * 0.55);
  final c = f[idx];
  if (idx >= n - 2) {
    p.disc(x, y, r, c, math.min(1.0, k * 3.0) * 0.85);
    return;
  }
  p.circle(x, y, r, f[math.min(n - 1, idx + 2)]);
  p.circle(x - r * 0.16, y - r * 0.22, r * 0.78, c);
  if (r > 1.6) p.circle(x, y - r * 0.9, r * 0.42, c);
  if (idx <= 3 && r > 1.8) {
    p.circle(x - r * 0.28, y - r * 0.34, r * 0.36, f[math.max(0, idx - 1)]);
  }
  if (idx < 6) p.glow(x, y, r * 2.4 + 2.0, c, 0.18 * k);
}

int _rampAt(List<int> r, double t) =>
    r[math.min(r.length - 1, math.max(0, (t * r.length).floor()))];

/// A puff of smoke at age [u] (0..1), swelling and thinning.
void smoke(
  Painter p,
  double x,
  double y,
  double size,
  double u,
  int col, [
  double k = 1.0,
  int warm = 0,
]) {
  final r = size * (0.65 + math.min(1.0, u * 2.5) * 0.45 + u * 0.4);
  final a = math.min(1.0, u * 12.0) * math.min(1.0, (1.0 - u) * 2.4) * 0.58 * k;
  if (a <= 0.01) return;
  final c = col != 0
      ? mix(col, _rampAt(kSmokeRamp, u), u)
      : _rampAt(kSmokeRamp, u * 1.05);
  p.disc(x, y, r, c, a * 0.45);
  p.disc(x + r * 0.05, y + r * 0.06, r * 0.74, c, a * 0.62);
  if (warm != 0 && u < 0.6) {
    p.disc(
      x + r * 0.1,
      y + r * 0.3,
      r * 0.56,
      mix(c, warm, 0.5),
      a * 0.7 * (1.0 - u / 0.6),
    );
  }
  if (u < 0.5) {
    p.disc(
      x - r * 0.22,
      y - r * 0.3,
      r * 0.5,
      mix(c, kWhite, 0.12),
      a * 0.4 * (1.0 - u * 2.0),
    );
  }
}

/// An ember at age [u]: hot and flickering, cooling to a dim red that blinks out.
void ember(
  Painter p,
  double x,
  double y,
  double u,
  List<int> e,
  double ph, [
  double k = 1.0,
]) {
  final left = 1.0 - u;
  if (left < 0.22 && math.sin(ph * 40.0) < 0.0) return;
  final c = left > 0.5
      ? (math.sin(ph * 22.0) > -0.2 ? e[0] : e[1])
      : (left > 0.22 ? e[1] : e[2]);
  p.px(x, y, c);
  p.glow(x, y, 3.0, c, 0.32 * left * k);
}

/// A flat, translucent bank of haze centred on ([x], [y]), [rx] by [ry].
void haze(
  Painter p,
  double x,
  double y,
  double rx,
  double ry,
  int col,
  double a,
) {
  if (a <= 0.01 || rx < 0.5 || ry < 0.5) return;
  final y0 = (y - ry).floor();
  final y1 = (y + ry).ceil();
  final x0 = (x - rx).floor();
  final x1 = (x + rx).ceil();
  for (var py = y0; py <= y1; py++) {
    for (var px = x0; px <= x1; px++) {
      final dx = (px + 0.5 - x) / rx;
      final dy = (py + 0.5 - y) / ry;
      final d = dx * dx + dy * dy;
      if (d < 1.0) p.blend(px, py, col, a * (1.0 - d));
    }
  }
}

typedef IconMask = String Function(int dx, int dy);

/// A shape from a bitmap (rows of strings, "." empty), centred on (0, 0).
IconMask bitmap(List<String> rows, [int k = 1, bool flip = false]) {
  final h = rows.length;
  final w = rows[0].length;
  final ox = (w * k) ~/ 2;
  final oy = (h * k) ~/ 2;
  return (int dx, int dy) {
    var bx = ((dx + ox) / k).floor();
    final by = ((dy + oy) / k).floor();
    if (bx < 0 || by < 0 || bx >= w || by >= h) return '';
    if (flip) bx = w - 1 - bx;
    final c = rows[by][bx];
    return c == '.' ? '' : c;
  };
}

/// A little shaded pixel icon at ([x], [y]) filled from [r] = [outline, shadow, body, light].
void icon(
  Painter p,
  num x,
  num y,
  int ext,
  IconMask inside,
  List<int> r, [
  double a = 1.0,
  Map<String, int>? paint,
]) {
  final bigX = (x + 0.5).floor();
  final bigY = (y + 0.5).floor();
  bool at(int dx, int dy) => inside(dx, dy).isNotEmpty;
  for (var dy = -ext - 1; dy <= ext + 1; dy++) {
    for (var dx = -ext - 1; dx <= ext + 1; dx++) {
      final ch = inside(dx, dy);
      int c;
      if (ch.isNotEmpty) {
        final mapped = paint?[ch];
        if (mapped != null) {
          c = mapped;
        } else {
          final top = !at(dx, dy - 1);
          final left = !at(dx - 1, dy);
          final bottom = !at(dx, dy + 1);
          final right = !at(dx + 1, dy);
          c = top || left ? r[3] : (bottom || right ? r[1] : r[2]);
        }
      } else if (r[0] != 0 &&
          (at(dx - 1, dy) ||
              at(dx + 1, dy) ||
              at(dx, dy - 1) ||
              at(dx, dy + 1))) {
        c = r[0];
      } else {
        continue;
      }
      p.dot(bigX + dx, bigY + dy, c, a);
    }
  }
}

/// [IconMask] for a shape given in its own unit space by [f](u, v).
IconMask shaped(
  bool Function(double u, double v) f,
  double s, [
  double ang = 0.0,
]) {
  final c = math.cos(ang);
  final n = math.sin(ang);
  return (int dx, int dy) {
    final x = dx + 0.5;
    final y = dy + 0.5;
    return f((x * c + y * n) / s, (-x * n + y * c) / s) ? '#' : '';
  };
}

/// A five-pointed star in unit space (points at radius 1, inner corners at [r0]).
bool Function(double u, double v) starShape([double r0 = 0.45]) {
  return (double u, double v) {
    final a = math.atan2(v, u) + math.pi / 2.0;
    final d = hypot(u, v);
    const seg = (2.0 * math.pi) / 5.0;
    final k =
        1.0 - ((((a % seg) + seg) % seg) - seg / 2.0).abs() / (seg / 2.0);
    return d <= 1.0 - (1.0 - r0) * math.pow(k, 0.8);
  };
}

/// A heart in unit space (two lobes and a point, about 2 wide and 2 tall, centred).
bool heartShape(double u, double v) {
  final du1 = u + 0.5;
  final du2 = u - 0.5;
  final dv = v + 0.32;
  if (du1 * du1 + dv * dv <= 0.55 * 0.55) return true;
  if (du2 * du2 + dv * dv <= 0.55 * 0.55) return true;
  return v >= -0.32 &&
      v <= 1.0 &&
      u.abs() <= 1.04 * math.pow(1.0 - (v + 0.32) / 1.32, 0.75);
}

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
