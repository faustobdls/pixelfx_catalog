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

class RowBuffer {
  int w = 0;
  Uint32List c = Uint32List(0);
  Float32List a = Float32List(0);
  Uint8List b = Uint8List(0);
  Uint32List l = Uint32List(0);
  Float32List k = Float32List(0);

  void ensureWidth(int width) {
    if (w == width) return;
    w = width;
    c = Uint32List(width);
    a = Float32List(width);
    b = Uint8List(width);
    l = Uint32List(width);
    k = Float32List(width);
  }
}

final RowBuffer _rowBuffer = RowBuffer();

/// Fast whole-sky row shader over local rows [y0d]..[y1d].
void rows(
  Painter p,
  EffectMeta meta,
  double y0d,
  double y1d,
  void Function(double y, RowBuffer r) fn,
) {
  final box = boxOf(meta);
  final w = box.w;
  final rBuf = _rowBuffer..ensureWidth(w);
  final y0 = math.max(box.y0, y0d.floor());
  final y1 = math.min(box.y1 - 1, y1d.ceil());
  if (y0 > y1) return;
  final rot = p.sn != 0.0;
  final q = rot ? clip(p, meta) : null;
  final cBuf = p.frame.color;
  final lBuf = p.frame.light;
  final stride = p.w;
  final fade = p.fade;
  final lk = p.lightK * fade;
  final fx = p.fx.toDouble();

  for (var y = y0; y <= y1; y++) {
    rBuf.c.fillRange(0, w, 0);
    rBuf.k.fillRange(0, w, 0.0);
    rBuf.a.fillRange(0, w, 1.0);
    rBuf.b.fillRange(0, w, 0);
    fn(y + 0.5, rBuf);
    if (rot) {
      for (var i = 0; i < w; i++) {
        if (rBuf.c[i] != 0) {
          if (rBuf.b[i] != 0) {
            q!.blend(box.x0 + i, y, rBuf.c[i], rBuf.a[i]);
          } else {
            q!.dot(box.x0 + i, y, rBuf.c[i], rBuf.a[i]);
          }
        }
        if (rBuf.k[i] > 0.0) {
          q!.light(box.x0 + i, y, rBuf.l[i] != 0 ? rBuf.l[i] : rBuf.c[i], rBuf.k[i]);
        }
      }
      continue;
    }
    final sy = (p.ty + y + 0.5).floor();
    final ry = sy - p.oy;
    if (ry < 0 || ry >= p.h) continue;
    final row = ry * stride;
    final by = (sy & 3) << 2;
    var sxf = p.tx + (box.x0 + 0.5) * fx;
    for (var i = 0; i < w; i++, sxf += fx) {
      final c = rBuf.c[i];
      final kk = rBuf.k[i];
      if (c == 0 && !(kk > 0.0)) continue;
      final sx = sxf.floor();
      final rx = sx - p.ox;
      if (rx < 0 || rx >= stride) continue;
      final j = row + rx;
      if (c != 0) {
        final a = rBuf.a[i] * fade;
        if (rBuf.b[i] != 0) {
          if (a > 0.004) {
            final d = cBuf[j];
            final da = (d >>> 24) / 255.0;
            final oa = a + da * (1.0 - a);
            final k = a / oa;
            final m = 1.0 - k;
            final r = ((c & 255) * k + (d & 255) * m).toInt() & 255;
            final g = (((c >>> 8) & 255) * k + ((d >>> 8) & 255) * m).toInt() & 255;
            final bl = (((c >>> 16) & 255) * k + ((d >>> 16) & 255) * m).toInt() & 255;
            final outA = (oa * 255.0).toInt() & 255;
            cBuf[j] = ((outA << 24) | (bl << 16) | (g << 8) | r) & 0xffffffff;
          }
        } else if (a >= 1.0 || a > _bayerThresholds[by | (sx & 3)]) {
          cBuf[j] = c;
        }
      }
      if (kk > 0.0) {
        final k = kk * lk;
        if (k > 0.004) {
          final lc = rBuf.l[i] != 0 ? rBuf.l[i] : c;
          final d = lBuf[j];
          final r = math.min(255, ((d & 255) + (lc & 255) * k).toInt());
          final g = math.min(255, (((d >>> 8) & 255) + ((lc >>> 8) & 255) * k).toInt());
          final bl = math.min(255, (((d >>> 16) & 255) + ((lc >>> 16) & 255) * k).toInt());
          lBuf[j] = ((255 << 24) | (bl << 16) | (g << 8) | r) & 0xffffffff;
        }
      }
    }
  }
}

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

class BoltBranch {
  final List<(double, double)> pts;
  final double w;
  final int depth;

  const BoltBranch(this.pts, this.w, this.depth);
}

/// Branching lightning path from `(x0, y0)` to `(x1, y1)`.
List<BoltBranch> tree(
  Rng r,
  double x0,
  double y0,
  double x1,
  double y1, [
  double jag = 0.3,
  double forks = 0.4,
  double w = 1.0,
  int depth = 0,
]) {
  final out = <BoltBranch>[];
  final l = math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
  var pts = <(double, double)>[(x0, y0), (x1, y1)];
  var off = l * jag;
  while (pts.length < 2.0 + l / 3.0) {
    final nxt = <(double, double)>[pts[0]];
    for (var i = 0; i < pts.length - 1; i++) {
      final (ax, ay) = pts[i];
      final (bx, by) = pts[i + 1];
      final segLen = math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay));
      final len = segLen == 0.0 ? 1.0 : segLen;
      final o = r.range(-off, off);
      nxt.add((
        (ax + bx) / 2.0 + (-(by - ay) / len) * o,
        (ay + by) / 2.0 + ((bx - ax) / len) * o,
      ));
      nxt.add((bx, by));
    }
    pts = nxt;
    off *= 0.52;
  }
  out.add(BoltBranch(pts, w, depth));
  if (depth < 2) {
    for (var i = 2; i < pts.length - 3; i++) {
      if (r.chance(forks / (1 + depth) / math.max(4.0, pts.length / 6.0))) {
        final (ax, ay) = pts[i];
        final (bx, by) = pts[math.min(pts.length - 1, i + 3)];
        final a = math.atan2(by - ay, bx - ax) + r.sign() * r.range(0.35, 0.95);
        final fl = (l - (i / pts.length) * l) * r.range(0.25, 0.55);
        out.addAll(
          tree(
            r,
            ax,
            ay,
            ax + math.cos(a) * fl,
            ay + math.sin(a) * fl,
            jag * 1.1,
            forks,
            w * 0.55,
            depth + 1,
          ),
        );
      }
    }
  }
  return out;
}

/// Raindrop splash on the floor, [age] seconds after landing at `(x, z)`.
void splash(
  Painter q,
  double x,
  double z,
  double age,
  double size,
  ({int hot, int cool}) c,
  double h,
) {
  final l = 0.3 + 0.12 * size;
  final u = age / l;
  if (u >= 1.0) return;
  if (age < 0.07) {
    q.px(x, z - 1.0, c.hot);
    if (size > 0.3) {
      final dy = age > 0.035 ? 1.0 : 0.0;
      q.px(x - 1.0, z - 1.0 - dy, c.hot);
      q.px(x + 1.0, z - 1.0 - dy, c.hot);
    }
    if (size > 0.65 && age > 0.03) {
      q.px(x - 2.0, z - 2.0, c.cool);
      q.px(x + 2.0, z - 2.0, c.cool);
    }
  }
  final rx = 1.0 + (1.2 + 3.6 * size) * math.sqrt(u);
  final ry = math.max(0.5, rx * 0.26);
  final n = (rx * 6.5).ceil();
  for (var j = 0; j < n; j++) {
    final a = (j / n) * tau;
    final s = math.sin(a);
    if (s < -0.25) continue;
    q.dot(
      x + math.cos(a) * rx,
      z + s * ry,
      u < 0.3 && s > 0.0 ? c.hot : c.cool,
      u < 0.45 ? (s > 0.2 ? 1.0 : 0.7) : (1.0 - u) * 1.6 * (s > 0.2 ? 1.0 : 0.6),
    );
  }
  final nd = size > 0.55 ? 3 : 2;
  final hi = (h * 1e6).floor();
  for (var d = 0; d < nd; d++) {
    final vx = (rand(hi, d, 1) - 0.5) * 2.0 * (25.0 + 35.0 * size);
    final vy = -(55.0 + rand(hi, d, 2) * 70.0 * (0.5 + size));
    final y = z - 1.0 + vy * age + 475.0 * age * age;
    if (y > z - 0.5 || age > 0.34) continue;
    final xx = x + vx * age;
    q.px(xx, y, age < 0.12 ? c.hot : c.cool);
    if (vy + 950.0 * age < -40.0) {
      q.dot(xx - vx * 0.012, y + 1.0, c.cool, 0.7);
    }
  }
}
