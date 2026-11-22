// Shared by the screen transitions: a 320 x 180 screen with its origin at the top-left.
// glint() is adapted from Sprite Fusion's open-source sparkle
// (https://www.spritefusion.com/pixel-art-vfx/sparkle), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

const int kScreenW = 320;
const int kScreenH = 180;

EffectMeta screenMeta({
  required String id,
  required String name,
  required String desc,
  required List<String> tags,
  required double duration,
  Map<String, Object?> options = const {},
}) {
  return EffectMeta(
    id: id,
    name: name,
    desc: desc,
    category: 'transitions',
    tags: ['transition', 'screen', ...tags, 'one-shot'],
    size: (kScreenW, kScreenH),
    origin: (0, 0),
    duration: duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.sky,
    defaultOptions: {
      'color': '#0b0a10',
      'seed': 1,
      ...options,
    },
  );
}

class ClippedScreenPainter extends Painter {
  ClippedScreenPainter(super.frame);

  void syncFrom(Painter p) {
    reset();
    tx = p.tx;
    ty = p.ty;
    fx = p.fx;
    cs = p.cs;
    sn = p.sn;
    fade = p.fade;
    lightK = p.lightK;
    layer = p.layer;
  }

  bool inside(int sx, int sy) {
    final lx = fromX(sx + 0.5, sy + 0.5);
    final ly = fromY(sx + 0.5, sy + 0.5);
    return lx >= 0.0 && ly >= 0.0 && lx < kScreenW && ly < kScreenH;
  }

  @override
  void put(int sx, int sy, int c, [double a = 1.0]) {
    if (inside(sx, sy)) super.put(sx, sy, c, a);
  }

  @override
  void add(int sx, int sy, int c, [double k = 1.0]) {
    if (inside(sx, sy)) super.add(sx, sy, c, k);
  }

  @override
  void blendPx(int sx, int sy, int c, double a) {
    if (inside(sx, sy)) super.blendPx(sx, sy, c, a);
  }
}

final Expando<ClippedScreenPainter> _clippedScreens = Expando();

Painter clipTo(Painter p) {
  var q = _clippedScreens[p];
  if (q == null) {
    q = ClippedScreenPainter(p.frame);
    _clippedScreens[p] = q;
  }
  q.syncFrom(p);
  return q;
}

bool _unrotated(Painter p) => p.sn == 0.0 && p.cs == 1.0;

int _col0(Painter p) => p.fx > 0 ? (p.tx + 0.5).floor() : (p.tx - 0.5).floor();

void fastRect(Painter p, double x, double y, double w, double h, int c) {
  if (!_unrotated(p)) {
    p.rect(x, y, w, h, c);
    return;
  }
  final x0 = x.round();
  final x1 = (x + w).round();
  final y0 = y.round();
  final y1 = (y + h).round();
  final fx = p.fx;
  final b = _col0(p);
  for (var yy = y0; yy < y1; yy++) {
    final sy = (p.ty + yy + 0.5).floor();
    for (var xx = x0; xx < x1; xx++) {
      p.put(b + fx * xx, sy, c, 1.0);
    }
  }
}

void transitionGlint(
  Painter p,
  double x,
  double y,
  double lenTotal,
  double ang,
  int c1,
  int c2, [
  double a = 1.0,
]) {
  if (lenTotal < 0.8 || a <= 0.0) return;
  for (var i = 0; i < 8; i++) {
    final diag = i % 2 == 1;
    final an = ang + (i * tau) / 8.0;
    final len = diag ? lenTotal * 0.42 : lenTotal;
    final ca = math.cos(an);
    final sa = math.sin(an);
    for (var d = 0.0; d <= len; d += 0.5) {
      final u = d / len;
      final c = diag
          ? (u < 0.5 ? c1 : c2)
          : (u < 0.3 ? kWhite : (u < 0.65 ? c1 : c2));
      p.dot(
        x + ca * d,
        y + sa * d,
        c,
        a * (u < 0.7 ? 1.0 : 1.0 - (u - 0.7) / 0.35),
      );
      if (!diag && u < 0.22 && lenTotal > 4.0) {
        p.dot(x + ca * d - sa, y + sa * d + ca, c1, a);
        p.dot(x + ca * d + sa, y + sa * d - ca, c1, a);
      }
    }
  }
  p.dot(x, y, kWhite, a);
  p.glow(x, y, 4.0 + lenTotal * 1.4, c1, 0.5 * a);
  p.glow(x, y, 2.0 + lenTotal * 0.5, kWhite, 0.4 * a);
}

double lifeLeft(double life, double t, double end) => math.min(life, end - t);

void _fillConvexCore(
  Painter p,
  List<(double, double)> pts,
  int Function(double x, double y) colorAt,
  double a,
) {
  if (pts.isEmpty) return;
  var y0 = double.infinity;
  var y1 = double.negativeInfinity;
  for (final (_, y) in pts) {
    if (y < y0) y0 = y;
    if (y > y1) y1 = y;
  }
  if (!y0.isFinite || !y1.isFinite) return;
  final r0 = math.max(0, (y0 - 0.5).ceil());
  final r1 = math.min(kScreenH - 1, (y1 - 0.5).floor());
  final n = pts.length;
  final unrot = _unrotated(p);
  final fx = p.fx;
  final b = _col0(p);
  for (var y = r0; y <= r1; y++) {
    final yc = y + 0.5;
    var xl = double.infinity;
    var xr = double.negativeInfinity;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final (xi, yi) = pts[i];
      final (xj, yj) = pts[j];
      if ((yi > yc) == (yj > yc)) continue;
      final x = xi + ((yc - yi) * (xj - xi)) / (yj - yi);
      if (x < xl) xl = x;
      if (x > xr) xr = x;
    }
    if (!xl.isFinite || !xr.isFinite) continue;
    final c0 = math.max(0, (xl - 0.5).ceil());
    final c1 = math.min(kScreenW - 1, (xr - 0.5).floor());
    if (unrot) {
      final sy = (p.ty + yc).floor();
      for (var x = c0; x <= c1; x++) {
        final col = colorAt(x + 0.5, yc);
        if (col != 0) p.put(b + fx * x, sy, col, a);
      }
    } else {
      for (var x = c0; x <= c1; x++) {
        final col = colorAt(x + 0.5, yc);
        if (col != 0) p.dot(x.toDouble(), y.toDouble(), col, a);
      }
    }
  }
}

void fillConvex(
  Painter p,
  List<(double, double)> pts,
  int c, [
  double a = 1.0,
]) {
  _fillConvexCore(p, pts, (_, _) => c, a);
}

void fillConvexFn(
  Painter p,
  List<(double, double)> pts,
  int Function(double x, double y) colorAt, [
  double a = 1.0,
]) {
  _fillConvexCore(p, pts, colorAt, a);
}

List<(double, double)> halfPlane(
  List<(double, double)> pts,
  double cx,
  double cy,
  double nx,
  double ny,
) {
  final out = <(double, double)>[];
  double side((double, double) pt) => (pt.$1 - cx) * nx + (pt.$2 - cy) * ny;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    final sa = side(a);
    final sb = side(b);
    if (sa >= 0.0) out.add(a);
    if ((sa >= 0.0) != (sb >= 0.0)) {
      final k = sa / (sa - sb);
      out.add((a.$1 + (b.$1 - a.$1) * k, a.$2 + (b.$2 - a.$2) * k));
    }
  }
  return out;
}

class ScalarField {
  final Float32List f;
  final Float32List g;
  final Float32List ny;
  final double lo;
  final double hi;
  final Uint32List order;
  final Float32List sorted;

  ScalarField({
    required this.f,
    required this.g,
    required this.ny,
    required this.lo,
    required this.hi,
    required this.order,
    required this.sorted,
  });

  int below(double v) {
    var a = 0;
    var b = sorted.length;
    while (a < b) {
      final m = (a + b) >> 1;
      if (sorted[m] < v) {
        a = m + 1;
      } else {
        b = m;
      }
    }
    return a;
  }
}

ScalarField screenField(
  double Function(double x, double y) fn, [
  double gmin = 0.45,
  double gmax = 3.0,
]) {
  const n = kScreenW * kScreenH;
  final f = Float32List(n);
  final g = Float32List(n);
  final ny = Float32List(n);
  var lo = double.infinity;
  var hi = double.negativeInfinity;
  for (var y = 0; y < kScreenH; y++) {
    for (var x = 0; x < kScreenW; x++) {
      final v = fn(x + 0.5, y + 0.5);
      f[y * kScreenW + x] = v;
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
  }
  for (var y = 0; y < kScreenH; y++) {
    for (var x = 0; x < kScreenW; x++) {
      final xa = math.max(0, x - 1);
      final xb = math.min(kScreenW - 1, x + 1);
      final ya = math.max(0, y - 1);
      final yb = math.min(kScreenH - 1, y + 1);
      final gx = (f[y * kScreenW + xb] - f[y * kScreenW + xa]) / (xb - xa);
      final gy = (f[yb * kScreenW + x] - f[ya * kScreenW + x]) / (yb - ya);
      final len = math.sqrt(gx * gx + gy * gy);
      g[y * kScreenW + x] = 1.0 / clamp(len, gmin, gmax);
      ny[y * kScreenW + x] = len > 1e-6 ? gy / len : 0.0;
    }
  }
  final order = Uint32List(n);
  for (var i = 0; i < n; i++) {
    order[i] = i;
  }
  order.sort((a, b) {
    final cmp = f[a].compareTo(f[b]);
    return cmp != 0 ? cmp : a.compareTo(b);
  });
  final sorted = Float32List(n);
  for (var i = 0; i < n; i++) {
    sorted[i] = f[order[i]];
  }
  return ScalarField(
    f: f,
    g: g,
    ny: ny,
    lo: lo,
    hi: hi,
    order: order,
    sorted: sorted,
  );
}

class ScreenPixels {
  final Painter _p;
  final bool _unrot;
  final double _tx;
  final double _ty;
  final int _fx;
  int _sx = 0;
  int _sy = 0;
  int _i0 = 0;

  ScreenPixels(this._p)
      : _unrot = _p.sn == 0.0 && _p.cs == 1.0,
        _tx = _p.tx,
        _ty = _p.ty,
        _fx = _p.fx;

  void at(int i) {
    if (_unrot) {
      _sx = (_tx + ((i % kScreenW) + 0.5) * _fx).floor();
      _sy = (_ty + (i ~/ kScreenW) + 0.5).floor();
    } else {
      _i0 = i;
    }
  }

  double get _x => (_i0 % kScreenW) + 0.5;
  double get _y => (_i0 ~/ kScreenW) + 0.5;

  void put(int c, [double a = 1.0]) {
    if (_unrot) {
      _p.put(_sx, _sy, c, a);
    } else {
      _p.dot(_x, _y, c, a);
    }
  }

  void add(int c, double k) {
    if (_unrot) {
      _p.add(_sx, _sy, c, k);
    } else {
      _p.light(_x, _y, c, k);
    }
  }

  void blend(int c, double a) {
    if (_unrot) {
      _p.blendPx(_sx, _sy, c, a);
    } else {
      _p.blend(_x, _y, c, a);
    }
  }
}

ScreenPixels screenPixels(Painter p) => ScreenPixels(p);
