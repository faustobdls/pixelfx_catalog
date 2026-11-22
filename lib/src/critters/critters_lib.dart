// The critters' kit: offscreen grid, shaded parts, 1 px directional outline, loop helpers.
// The flame tongue and fire puff recipes are adapted from Sprite Fusion's open-source fire
// (https://www.spritefusion.com/pixel-art-vfx/fire), and the bubble from its open-source bubbles
// (https://www.spritefusion.com/pixel-art-vfx/bubbles), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

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

  void draw(Painter p, [double fade = 1.0, double dx = 0.0, double dy = 0.0]) {
    final xi = x0 + dx.round();
    final yi = y0 + dy.round();
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
