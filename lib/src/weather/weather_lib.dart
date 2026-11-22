// Helpers shared by the weather loops. Weather fills its whole canvas edge to edge.
// The noise bake and the branching bolt are adapted from Sprite Fusion's open-source fog and lightning
// (https://www.spritefusion.com/pixel-art-vfx/fog), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

const List<double> _bayerThresholds = [
  0.5 / 16, 8.5 / 16, 2.5 / 16, 10.5 / 16,
  12.5 / 16, 4.5 / 16, 14.5 / 16, 6.5 / 16,
  3.5 / 16, 11.5 / 16, 1.5 / 16, 9.5 / 16,
  15.5 / 16, 7.5 / 16, 13.5 / 16, 5.5 / 16,
];

class CanvasBox {
  final int x0;
  final int y0;
  final int x1;
  final int y1;
  final int w;
  final int h;

  const CanvasBox({
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
    required this.w,
    required this.h,
  });
}

CanvasBox boxOf(EffectMeta meta) {
  final w = meta.width;
  final h = meta.height;
  final ox = meta.originX;
  final oy = meta.originY;
  return CanvasBox(x0: -ox, y0: -oy, x1: w - ox, y1: h - oy, w: w, h: h);
}

class ClippedWeatherPainter extends Painter {
  final CanvasBox box;
  late final bool Function(int sx, int sy) _ok;

  ClippedWeatherPainter(Painter source, this.box) : super(source.frame) {
    tx = source.tx;
    ty = source.ty;
    fx = source.fx;
    cs = source.cs;
    sn = source.sn;
    fade = source.fade;
    lightK = source.lightK;
    layer = source.layer;
    if (sn == 0.0) {
      final a = toX(box.x0.toDouble(), 0.0);
      final b = toX(box.x1.toDouble(), 0.0);
      final sx0 = math.min(a, b).round();
      final sx1 = math.max(a, b).round();
      final sy0 = toY(0.0, box.y0.toDouble()).round();
      final sy1 = toY(0.0, box.y1.toDouble()).round();
      _ok = (sx, sy) => sx >= sx0 && sx < sx1 && sy >= sy0 && sy < sy1;
    } else {
      _ok = (sx, sy) {
        final lx = fromX(sx + 0.5, sy + 0.5);
        final ly = fromY(sx + 0.5, sy + 0.5);
        return lx >= box.x0 && lx < box.x1 && ly >= box.y0 && ly < box.y1;
      };
    }
  }

  @override
  void put(int sx, int sy, int c, [double a = 1.0]) {
    if (_ok(sx, sy)) super.put(sx, sy, c, a);
  }

  @override
  void add(int sx, int sy, int c, [double k = 1.0]) {
    if (_ok(sx, sy)) super.add(sx, sy, c, k);
  }

  @override
  void blendPx(int sx, int sy, int c, double a) {
    if (_ok(sx, sy)) super.blendPx(sx, sy, c, a);
  }

  @override
  void glow(num x, num y, num r, int c, [double k = 0.5]) {
    final rd = r.toDouble();
    if (rd < 1.0 || k <= 0.004) return;
    final xd = x.toDouble();
    final yd = y.toDouble();
    final x0 = math.max(box.x0, (xd - rd).floor());
    final x1 = math.min(box.x1 - 1, (xd + rd).ceil());
    final y0 = math.max(box.y0, (yd - rd).floor());
    final y1 = math.min(box.y1 - 1, (yd + rd).ceil());
    for (var py = y0; py <= y1; py++) {
      final dy = (py + 0.5 - yd) / rd;
      for (var px = x0; px <= x1; px++) {
        final dx = (px + 0.5 - xd) / rd;
        final d = dx * dx + dy * dy;
        if (d >= 1.0) continue;
        final f = 1.0 - math.sqrt(d);
        light(px, py, c, f * f * k);
      }
    }
  }
}

ClippedWeatherPainter clip(Painter p, EffectMeta meta) =>
    ClippedWeatherPainter(p, boxOf(meta));

class PassOut {
  int c = 0;
  double a = 1.0;
  bool b = false;
  int l = 0;
  double k = 0.0;

  void reset() {
    c = 0;
    a = 1.0;
    b = false;
    l = 0;
    k = 0.0;
  }
}

final PassOut _passOut = PassOut();

/// Per-pixel shader over canvas rows [y0]..[y1] (local, clipped to canvas).
void pass(
  Painter p,
  EffectMeta meta,
  double y0d,
  double y1d,
  void Function(double x, double y, PassOut out) fn,
) {
  final b = boxOf(meta);
  final y0 = math.max(b.y0, y0d.floor());
  final y1 = math.min(b.y1 - 1, y1d.ceil());
  if (y0 > y1) return;
  final o = _passOut;

  if (p.sn != 0.0) {
    final q = clip(p, meta);
    for (var y = y0; y <= y1; y++) {
      for (var x = b.x0; x < b.x1; x++) {
        o.reset();
        fn(x + 0.5, y + 0.5, o);
        if (o.c != 0) {
          if (o.b) {
            q.blend(x, y, o.c, o.a);
          } else {
            q.dot(x, y, o.c, o.a);
          }
        }
        if (o.k > 0.0) q.light(x, y, o.l != 0 ? o.l : o.c, o.k);
      }
    }
    return;
  }

  final cBuf = p.frame.color;
  final lBuf = p.frame.light;
  final w = p.w;
  final fade = p.fade;
  final lk = p.lightK * fade;
  final fx = p.fx.toDouble();
  final tx = p.tx;

  for (var y = y0; y <= y1; y++) {
    final sy = (p.ty + y + 0.5).floor();
    final ry = sy - p.oy;
    if (ry < 0 || ry >= p.h) continue;
    final row = ry * w;
    final by = (sy & 3) << 2;
    var sxf = tx + (b.x0 + 0.5) * fx;
    for (var x = b.x0; x < b.x1; x++, sxf += fx) {
      final sx = sxf.floor();
      final rx = sx - p.ox;
      if (rx < 0 || rx >= w) continue;
      o.reset();
      fn(x + 0.5, y + 0.5, o);
      final i = row + rx;
      if (o.c != 0) {
        final a = o.a * fade;
        if (o.b) {
          if (a > 0.004) {
            final d = cBuf[i];
            final da = (d >>> 24) / 255.0;
            final oa = a + da * (1.0 - a);
            final k = a / oa;
            final j = 1.0 - k;
            final c = o.c;
            final r = ((c & 255) * k + (d & 255) * j).toInt() & 255;
            final g = (((c >>> 8) & 255) * k + ((d >>> 8) & 255) * j).toInt() & 255;
            final bl =
                (((c >>> 16) & 255) * k + ((d >>> 16) & 255) * j).toInt() & 255;
            final outA = (oa * 255.0).toInt() & 255;
            cBuf[i] = ((outA << 24) | (bl << 16) | (g << 8) | r) & 0xffffffff;
          }
        } else if (a >= 1.0 || a > _bayerThresholds[by | (sx & 3)]) {
          cBuf[i] = o.c;
        }
      }
      if (o.k > 0.0) {
        final k = o.k * lk;
        if (k > 0.004) {
          final c = o.l != 0 ? o.l : o.c;
          final d = lBuf[i];
          final r = math.min(255, ((d & 255) + (c & 255) * k).toInt());
          final g =
              math.min(255, (((d >>> 8) & 255) + ((c >>> 8) & 255) * k).toInt());
          final bl = math.min(
              255, (((d >>> 16) & 255) + ((c >>> 16) & 255) * k).toInt());
          lBuf[i] = ((255 << 24) | (bl << 16) | (g << 8) | r) & 0xffffffff;
        }
      }
    }
  }
}

/// Ordered-dither threshold of a local pixel (0..1): `a > bayer(x, y)` draws it.
double bayer(double x, double y) =>
    _bayerThresholds[((y.floor() & 3) << 2) | (x.floor() & 3)];

class NoiseField {
  final int w;
  final int h;
  final Float32List d;

  const NoiseField(this.w, this.h, this.d);
}

final Map<String, NoiseField> _fieldsCache = {};

/// A baked fractal noise that tiles cleanly for seamless loops.
NoiseField noiseField(
  int seed, [
  int w = 256,
  int h = 128,
  List<int> cells = const [4, 8, 16, 32],
]) {
  final key = '$seed|$w|$h|${cells.join(',')}';
  final cached = _fieldsCache[key];
  if (cached != null) return cached;
  final d = Float32Array(w * h);
  var amp = 0.5;
  var total = 0.0;
  for (final n in cells) {
    final cs = w / n;
    final rows = math.max(1, (h / cs).round());
    double at(int a, int b) => rand(wrapInt(a, n), wrapInt(b, rows), seed, n);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final gx = x / cs;
        final gy = (y / h) * rows;
        final ix = gx.floor();
        final iy = gy.floor();
        final u = gx - ix;
        final v = gy - iy;
        final su = u * u * (3.0 - 2.0 * u);
        final sv = v * v * (3.0 - 2.0 * v);
        final top = at(ix, iy) + (at(ix + 1, iy) - at(ix, iy)) * su;
        final bot = at(ix, iy + 1) + (at(ix + 1, iy + 1) - at(ix, iy + 1)) * su;
        d[y * w + x] += (top + (bot - top) * sv) * amp;
      }
    }
    total += amp;
    amp *= 0.5;
  }
  for (var i = 0; i < d.length; i++) {
    d[i] /= total;
  }
  final built = NoiseField(w, h, d);
  _fieldsCache[key] = built;
  return built;
}

typedef Float32Array = Float32List;

double sampleField(NoiseField f, double u, double v) {
  final x = u.floor();
  final y = v.floor();
  final fx = u - x;
  final fy = v - y;
  final m = f.w - 1;
  final n = f.h - 1;
  final d = f.d;
  final x0 = x & m;
  final x1 = (x + 1) & m;
  final y0 = (y & n) * f.w;
  final y1 = ((y + 1) & n) * f.w;
  final a = d[y0 + x0];
  final b = d[y0 + x1];
  final c = d[y1 + x0];
  final e = d[y1 + x1];
  return a + (b - a) * fx + (c - a + (a - b - c + e) * fx) * fy;
}

void trips(
  double t,
  double d,
  int n,
  int seed,
  int m0,
  int m1,
  void Function(double u, int k, int m, int i) fn,
) {
  for (var i = 0; i < n; i++) {
    final m = m0 + (rand(seed, i, 72) * (m1 - m0 + 1)).floor();
    final s = (t / d) * m + rand(seed, i, 71);
    final k = s.floor();
    fn(s - k, k, m, i);
  }
}

double wave(double t, double d, double c, [double ph = 0.0]) =>
    math.sin((tau * c * t) / d + ph);

/// A crisp splash on a floor line. Returns false once finished.
bool crown(
  Painter q,
  double x,
  double z,
  double age,
  double size,
  ({int hot, int cool, int white}) c,
  double h,
) {
  final l = 0.22 + 0.14 * size;
  final u = age / l;
  final xi = x.round();
  final zi = z.round();
  if (u >= 1.0) return false;
  if (age < 0.1) {
    final up = age < 0.033 ? 1 : (age < 0.067 ? 2 : 2 + (size > 0.5 ? 1 : 0));
    q.px(xi, zi - 1, age < 0.05 ? c.white : c.hot);
    final maxD = math.min<int>(up, size > 0.5 ? 3 : 1);
    for (var d = 1; d <= maxD; d++) {
      final dy = d > 1 ? d - 1 : 0;
      q.px(xi - d, zi - 1 - dy, d == 1 ? c.hot : c.cool);
      q.px(xi + d, zi - 1 - dy, d == 1 ? c.hot : c.cool);
    }
  }
  if (u > 0.15) {
    final w = (1.0 + (1.5 + 3.5 * size) * math.sqrt(u)).round();
    final gap = u > 0.55 ? math.max(0, w - 2) : -1;
    for (var d = -w; d <= w; d++) {
      if (d.abs() > gap) {
        q.px(xi + d, zi, (d.abs() >= w - 1 && u < 0.6) ? c.hot : c.cool);
      }
    }
  }
  final nd = size > 0.5 ? 2 : 1;
  final hi = (h * 1e6).floor();
  for (var d = 0; d < nd; d++) {
    final vx = (rand(hi, d, 1) - 0.5) * 2.0 * (20.0 + 30.0 * size);
    final vy = -(50.0 + rand(hi, d, 2) * 60.0 * (0.4 + size));
    final y = zi - 1.0 + vy * age + 475.0 * age * age;
    if (y < zi - 0.5 && age < 0.3) {
      q.px(x + vx * age, y, age < 0.1 ? c.white : c.hot);
    }
  }
  return true;
}
