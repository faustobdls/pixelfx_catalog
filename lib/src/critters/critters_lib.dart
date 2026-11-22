// The critters' kit: offscreen grid, shaded parts, 1 px directional outline, loop helpers.
// The flame tongue and fire puff recipes are adapted from Sprite Fusion's open-source fire
// (https://www.spritefusion.com/pixel-art-vfx/fire), and the bubble from its open-source bubbles
// (https://www.spritefusion.com/pixel-art-vfx/bubbles), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

/// Matches JS `Math.round(x)` including negative `.5` tie-breaking toward +infinity.
@pragma('vm:prefer-inline')
int roundJs(num x) => (x + 0.5).floor();

double shift(double t, double d, [int seed = 1]) =>
    wrap(t + (seed - 1) * 0.618 * d, d);

double curve(double x, List<(double, double)> list) {
  if (x <= list.first.$1) return list.first.$2;
  for (var i = 1; i < list.length; i++) {
    final (x0, v0) = list[i - 1];
    final (x1, v1) = list[i];
    if (x <= x1) {
      final denom = x1 - x0;
      final u = denom == 0.0 ? 1.0 : (x - x0) / denom;
      return v0 + (v1 - v0) * u * u * (3.0 - 2.0 * u);
    }
  }
  return list.last.$2;
}

double lnoise(double t, double d, int f, [double off = 0.0, int seed = 0]) =>
    tileNoise((t / d) * f + off, 0.5, f, 0, seed);

double spring(double age, double hz, double damp) =>
    age < 0.0 ? 0.0 : math.exp(-age * damp) * math.cos(age * hz * tau);

class TossResult {
  double x;
  double y;
  double vx;
  double vy;
  final bool landed;
  final double at;
  final double lx;
  int size = 1;
  double k = 1.0;
  bool gone = false;
  double splat = 0.0;

  TossResult({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.landed,
    required this.at,
    required this.lx,
  });
}

TossResult toss(
  double x,
  double y,
  double vx,
  double vy,
  double age,
  double g, [
  double floor = 0.0,
]) {
  final tl = g > 0.0
      ? (-vy + math.sqrt(math.max(0.0, vy * vy + 2.0 * g * (floor - y)))) / g
      : double.infinity;
  if (age < tl) {
    return TossResult(
      x: x + vx * age,
      y: y + vy * age + 0.5 * g * age * age,
      vx: vx,
      vy: vy + g * age,
      landed: false,
      at: tl,
      lx: x + vx * tl,
    );
  }
  return TossResult(
    x: x + vx * tl,
    y: floor,
    vx: 0.0,
    vy: 0.0,
    landed: true,
    at: tl,
    lx: x + vx * tl,
  );
}

class BounceResult {
  final double x;
  final double y;
  final double vx;
  final double vy;
  final int hops;
  final bool rest;

  const BounceResult({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.hops,
    required this.rest,
  });
}

BounceResult bounce(
  double x,
  double y,
  double vx,
  double vy,
  double age,
  double g, [
  double floor = 0.0,
  double e = 0.45,
]) {
  var cx = x;
  var cy = y;
  var cvx = vx;
  var cvy = vy;
  var rem = age;
  var hops = 0;
  for (; hops < 6; hops++) {
    final f = toss(cx, cy, cvx, cvy, rem, g, floor);
    if (!f.landed) {
      return BounceResult(
        x: f.x,
        y: f.y,
        vx: f.vx,
        vy: f.vy,
        hops: hops,
        rest: false,
      );
    }
    final vl = cvy + g * f.at;
    rem -= f.at;
    cx = f.lx;
    cy = floor - 0.01;
    cvx *= 0.7;
    cvy = -vl * e;
    if (cvy.abs() < 25.0) break;
  }
  return BounceResult(
    x: cx,
    y: floor - 0.25,
    vx: 0.0,
    vy: 0.0,
    hops: hops,
    rest: true,
  );
}

class GridShadeOut {
  double a = 1.0;
  int t = 0;

  void reset() {
    a = 1.0;
    t = 0;
  }
}

class CritterGrid {
  final int x0;
  final int y0;
  final int w;
  final int h;
  final Uint32List c;
  final Float32List a;
  final Uint8List tag;
  Uint8List? d;
  final GridShadeOut _o = GridShadeOut();

  CritterGrid(num x0, num y0, this.w, this.h)
      : x0 = x0.floor(),
        y0 = y0.floor(),
        c = Uint32List(w * h),
        a = Float32List(w * h),
        tag = Uint8List(w * h);

  int idx(num x, num y) {
    final ix = x.floor() - x0;
    final iy = y.floor() - y0;
    return (ix < 0 || iy < 0 || ix >= w || iy >= h) ? -1 : iy * w + ix;
  }

  void set(num x, num y, int col, [double alpha = 1.0, int tVal = 0]) {
    final i = idx(x, y);
    if (i >= 0 && col != 0) {
      c[i] = col;
      a[i] = alpha;
      tag[i] = tVal;
    }
  }

  int get(num x, num y) {
    final i = idx(x, y);
    return i < 0 ? 0 : c[i];
  }

  int tagAt(num x, num y) {
    final i = idx(x, y);
    return i < 0 ? 0 : tag[i];
  }

  void erase(num x, num y) {
    final i = idx(x, y);
    if (i >= 0) c[i] = 0;
  }

  void fillAlpha(double alpha) {
    a.fillRange(0, a.length, alpha);
  }

  void shade(
    num x0d,
    num y0d,
    num x1d,
    num y1d,
    int Function(double x, double y, GridShadeOut out) fn,
  ) {
    final o = _o;
    final startY = y0d.floor();
    final endY = y1d.floor();
    final startX = x0d.floor();
    final endX = x1d.floor();
    for (var y = startY; y <= endY; y++) {
      for (var x = startX; x <= endX; x++) {
        o.reset();
        final col = fn(x + 0.5, y + 0.5, o);
        if (col != 0) set(x, y, col, o.a, o.t);
      }
    }
  }

  void ellipse(
    num cx,
    num cy,
    num rx,
    num ry,
    int Function(double nx, double ny) fn, [
    double alpha = 1.0,
  ]) {
    if (rx <= 0 || ry <= 0) return;
    shade(cx - rx, cy - ry, cx + rx, cy + ry, (x, y, out) {
      final nx = (x - cx) / rx;
      final ny = (y - cy) / ry;
      if (nx * nx + ny * ny > 1.0) return 0;
      out.a = alpha;
      return fn(nx, ny);
    });
  }

  void ellipseSolid(
    num cx,
    num cy,
    num rx,
    num ry,
    int col, [
    double alpha = 1.0,
  ]) {
    if (rx <= 0 || ry <= 0) return;
    shade(cx - rx, cy - ry, cx + rx, cy + ry, (x, y, out) {
      final nx = (x - cx) / rx;
      final ny = (y - cy) / ry;
      if (nx * nx + ny * ny > 1.0) return 0;
      out.a = alpha;
      return col;
    });
  }

  void line(num x0d, num y0d, num x1d, num y1d, int col, [double alpha = 1.0]) {
    final n = math.max<int>(
      1,
      math.max((x1d - x0d).abs(), (y1d - y0d).abs()).ceil(),
    );
    for (var i = 0; i <= n; i++) {
      set(
        x0d + ((x1d - x0d) * i) / n,
        y0d + ((y1d - y0d) * i) / n,
        col,
        alpha,
      );
    }
  }

  void lineFn(
    num x0d,
    num y0d,
    num x1d,
    num y1d,
    int Function(double u) fn, [
    double alpha = 1.0,
  ]) {
    final n = math.max<int>(
      1,
      math.max((x1d - x0d).abs(), (y1d - y0d).abs()).ceil(),
    );
    for (var i = 0; i <= n; i++) {
      set(
        x0d + ((x1d - x0d) * i) / n,
        y0d + ((y1d - y0d) * i) / n,
        fn(i / n),
        alpha,
      );
    }
  }

  void tube(
    List<(double, double)> pts,
    double Function(double u) rFn,
    int Function(double u, double v) cFn, [
    double alpha = 1.0,
  ]) {
    for (var k = 1; k < pts.length; k++) {
      final (ax, ay) = pts[k - 1];
      final (bx, by) = pts[k];
      final len = math.max(1.0, hypot(bx - ax, by - ay));
      for (var s = 0.0; s <= len; s += 0.5) {
        final u = (k - 1 + s / len) / (pts.length - 1);
        final rr = rFn(u);
        final x = ax + ((bx - ax) * s) / len;
        final y = ay + ((by - ay) * s) / len;
        if (rr < 0.75) {
          set(x, y, cFn(u, 0.0), alpha);
          continue;
        }
        shade(x - rr, y - rr, x + rr, y + rr, (px, py, out) {
          final distRatio = hypot(px - x, py - y) / rr;
          out.a = alpha;
          return distRatio > 1.0 ? 0 : cFn(u, distRatio);
        });
      }
    }
  }

  void poly(
    List<(double, double)> pts,
    int col, [
    double alpha = 1.0,
  ]) {
    polyFn(pts, (_, _) => col, alpha);
  }

  void polyFn(
    List<(double, double)> pts,
    int Function(double x, double y) fn, [
    double alpha = 1.0,
  ]) {
    var x0d = double.infinity;
    var y0d = double.infinity;
    var x1d = -double.infinity;
    var y1d = -double.infinity;
    for (final (x, y) in pts) {
      x0d = math.min(x0d, x);
      x1d = math.max(x1d, x);
      y0d = math.min(y0d, y);
      y1d = math.max(y1d, y);
    }
    final n = pts.length;
    shade(x0d, y0d, x1d, y1d, (x, y, out) {
      var inside = false;
      for (var i = 0, j = n - 1; i < n; j = i++) {
        final (xi, yi) = pts[i];
        final (xj, yj) = pts[j];
        if ((yi > y) != (yj > y) &&
            x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) {
          inside = !inside;
        }
      }
      out.a = alpha;
      return inside ? fn(x, y) : 0;
    });
  }

  Uint8List depths([int max = 4]) {
    final len = w * h;
    final dep = Uint8List(len);
    final q = <int>[];
    for (var i = 0; i < len; i++) {
      if (c[i] == 0) continue;
      final x = i % w;
      final y = i ~/ w;
      if (x == 0 ||
          y == 0 ||
          x == w - 1 ||
          y == h - 1 ||
          c[i - 1] == 0 ||
          c[i + 1] == 0 ||
          c[i - w] == 0 ||
          c[i + w] == 0) {
        dep[i] = 1;
        q.add(i);
      }
    }
    for (var k = 0; k < q.length; k++) {
      final i = q[k];
      final v = dep[i];
      if (v >= max) continue;
      for (final j in [i - 1, i + 1, i - w, i + w]) {
        if (j >= 0 && j < len && c[j] != 0 && dep[j] == 0) {
          dep[j] = v + 1;
          q.add(j);
        }
      }
    }
    for (var i = 0; i < len; i++) {
      if (c[i] != 0 && dep[i] == 0) dep[i] = max;
    }
    d = dep;
    return dep;
  }

  int depth(num x, num y) {
    final i = idx(x, y);
    final dep = d;
    return (i < 0 || dep == null) ? 0 : dep[i];
  }

  void outline(int col, [double alpha = 1.0]) {
    outlineShaded((_, _, _, _) => col, alpha);
  }

  void outlineShaded(
    int Function(int x, int y, int nx, int ny) fn, [
    double alpha = 1.0,
  ]) {
    final src = Uint32List.fromList(c);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        if (src[i] != 0) continue;
        final l = x > 0 && src[i - 1] != 0;
        final r = x < w - 1 && src[i + 1] != 0;
        final u = y > 0 && src[i - w] != 0;
        final dn = y < h - 1 && src[i + w] != 0;
        if (!(l || r || u || dn)) continue;
        final col = fn(
          x0 + x,
          y0 + y,
          (l ? 1 : 0) - (r ? 1 : 0),
          (u ? 1 : 0) - (dn ? 1 : 0),
        );
        if (col != 0) {
          c[i] = col;
          a[i] = alpha;
          tag[i] = 255;
        }
      }
    }
  }

  void recolor(
    int Function(int x, int y, int color, double alpha, int tag) fn,
  ) {
    final len = w * h;
    for (var i = 0; i < len; i++) {
      if (c[i] == 0) continue;
      c[i] = fn(x0 + (i % w), y0 + (i ~/ w), c[i], a[i], tag[i]);
    }
  }

  void draw(Painter p, [double fade = 1.0, double dx = 0.0, double dy = 0.0]) {
    final xi = x0 + roundJs(dx);
    final yi = y0 + roundJs(dy);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final col = c[i];
        if (col == 0) continue;
        final alpha = a[i];
        if (alpha >= 0.999) {
          p.dot(xi + x, yi + y, col, fade);
        } else {
          p.blend(xi + x, yi + y, col, alpha * fade);
        }
      }
    }
  }

  CritterGrid clear() {
    c.fillRange(0, c.length, 0);
    tag.fillRange(0, tag.length, 0);
    d = null;
    return this;
  }
}

class Swarm {
  Particles ps;

  Swarm({
    double Function(double x)? ground,
    List<Object>? sparks,
    Object? haze,
    void Function(double x, double y)? onLand,
  }) : ps = Particles(
          rng: Rng(1),
          ground: ground,
          sparks: sparks,
          haze: haze,
          onLand: onLand,
        );

  Swarm begin(double t) {
    ps.list.clear();
    ps.t = t;
    return this;
  }

  void setSparks(List<int> cols) {
    if (cols.length == ps.sparks.length) {
      ps.sparks.setAll(0, cols);
    } else {
      ps = Particles(
        rng: Rng(1),
        ground: ps.ground,
        sparks: cols,
        haze: ps.haze,
        onLand: ps.onLand,
      )..t = ps.t;
    }
  }

  void add(
    ParticleKind k,
    double x,
    double y,
    double vx,
    double vy,
    double age,
    double life, [
    int? col,
    double size = 1.0,
    int flag = 0,
    double seed = 0.0,
  ]) {
    if (age < 0.0 || age >= life) return;
    ps.list.add(
      SimParticle(
        k: k,
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        life: life - age,
        max: life,
        col: col ?? kWhite,
        size: size,
        seed: seed,
        delay: 0.0,
        flag: flag,
      ),
    );
  }

  void draw(Painter p, [String? layer]) {
    ps.draw(p, layer);
  }
}

const List<(double, double, int)> _tongueLayers = [
  (1.0, 1.0, 6),
  (0.76, 0.86, 4),
  (0.54, 0.68, 2),
  (0.3, 0.42, 0),
];

void tongue(
  Painter p,
  double x,
  double y,
  double h,
  double w,
  double sx,
  double t,
  double d,
  num n,
  List<int> heat, [
  int only = -1,
]) {
  if (h < 1.0) return;
  final f1 = math.max<int>(1, roundJs(9.0 * d));
  final f2 = math.max<int>(1, roundJs(4.0 * d));
  final nSeed = n.toInt();
  for (var li = 0; li < _tongueLayers.length; li++) {
    if (only >= 0 && li != only) continue;
    final (lw, lh, ri) = _tongueLayers[li];
    final hh = h * lh;
    final col = heat[ri];
    for (var r = 0; r <= hh; r++) {
      final u = r / math.max(1.0, hh);
      final half = w *
              lw *
              math.pow(1.0 - u, 0.85) *
              math.min(1.0, (r + 1.5) / 3.5) +
          lnoise(t, d, f1, r * 0.45, nSeed) * 0.5;
      final cx = x +
          sx * u * u * lh +
          lnoise(t, d, f2, r * 0.2, nSeed + 7) * u * 1.1;
      if (half < 0.3) continue;
      final pxEnd = roundJs(cx + half);
      final py = roundJs(y - r);
      for (var px = roundJs(cx - half); px <= pxEnd; px++) {
        p.px(px, py, col);
      }
    }
  }
}

void firePuff(
  Painter p,
  double x,
  double y,
  double k,
  double size,
  double seed,
  List<int> heat,
) {
  final age = 1.0 - k;
  final n = heat.length;
  final hot = math.min(
    0.999,
    math.pow(age, 0.62).toDouble() + (seed.remainder(1.0)) * 0.1,
  );
  final idx = math.min(n - 2, (hot * (n - 1)).floor());
  final r = size * (0.55 + 0.45 * math.min(1.0, age * 7.0)) * (1.0 - age * 0.55);
  final c = heat[idx];
  if (idx >= n - 2) {
    p.disc(x, y, r, c, math.min(1.0, k * 3.0) * 0.85);
    return;
  }
  p.circle(x, y, r, heat[math.min(n - 1, idx + 2)]);
  p.circle(x - r * 0.16, y - r * 0.22, r * 0.78, c);
  if (r > 1.6) p.circle(x, y - r * 0.9, r * 0.42, c);
  if (idx <= 3 && r > 1.8) {
    p.circle(x - r * 0.28, y - r * 0.34, r * 0.36, heat[math.max(0, idx - 1)]);
  }
  if (idx < 6) p.glow(x, y, r * 2.4 + 2.0, c, 0.18 * k);
}

void bubble(
  Painter p,
  double cx,
  double cy,
  double r,
  List<int> cols, [
  double a = 1.0,
  double wob = 0.0,
]) {
  final hi = cols[0];
  final lit = cols[1];
  final rim = cols[2];
  final shadeCol = cols[3];
  if (r < 0.9) {
    p.dot(cx, cy, r < 0.7 ? rim : lit, a);
    return;
  }
  if (r < 1.5) {
    final px = cx.floor();
    final py = cy.floor();
    p.dot(px, py, hi, a);
    p.dot(px + 1, py, lit, a);
    p.dot(px, py + 1, rim, a);
    p.dot(px + 1, py + 1, shadeCol, a);
    p.glow(cx + 0.5, cy + 0.5, 3, lit, 0.12 * a);
    return;
  }
  final rx = r * (1.0 + wob);
  final ry = r * (1.0 - wob);
  final yEnd = (cy + ry + 1.0).ceil();
  final xStart = (cx - rx - 1.0).floor();
  final xEnd = (cx + rx + 1.0).ceil();
  for (var y = (cy - ry - 1.0).floor(); y <= yEnd; y++) {
    for (var x = xStart; x <= xEnd; x++) {
      final dx = (x + 0.5 - cx) / rx;
      final dy = (y + 0.5 - cy) / ry;
      final d = math.sqrt(dx * dx + dy * dy) * r;
      if (d > r + 0.5) continue;
      final l = (-dx - dy) / math.sqrt2 / math.max(0.01, d / r);
      if (d > r - 0.6) {
        p.dot(x, y, l > 0.45 ? lit : (l < -0.55 ? shadeCol : rim), a);
      }
    }
  }
  final hx = roundJs(cx - rx * 0.45);
  final hy = roundJs(cy - ry * 0.45);
  p.dot(hx, hy, hi, a);
  if (r >= 2.5) {
    p.dot(hx + 1, hy, lit, a);
    p.dot(hx, hy + 1, lit, a);
  }
  if (r >= 2.0) {
    p.dot(roundJs(cx + rx * 0.5), roundJs(cy + ry * 0.5), lit, a);
  }
  p.glow(cx, cy, r * 2.4 + 2.0, rim, 0.14 * a);
}

void shadow(
  Painter p,
  double cx,
  double cy,
  double rx,
  double ry,
  int c,
  double a,
) {
  if (rx <= 0.0 || ry <= 0.0 || a <= 0.0) return;
  final yEnd = (cy + ry).ceil();
  final xStart = (cx - rx).floor();
  final xEnd = (cx + rx).ceil();
  for (var y = (cy - ry).floor(); y <= yEnd; y++) {
    for (var x = xStart; x <= xEnd; x++) {
      final dx = (x + 0.5 - cx) / rx;
      final dy = (y + 0.5 - cy) / ry;
      final d = dx * dx + dy * dy;
      if (d < 1.0) p.blend(x, y, c, a * math.pow(1.0 - d, 0.7).toDouble());
    }
  }
}
