// Shared by the lightning effects.
// Adapted from Sprite Fusion's open-source lightning
// (https://www.spritefusion.com/pixel-art-vfx/lightning), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

const List<String> voltPalette = [
  '#120a33', '#2a1b78', '#4630c0', '#5a62f0',
  '#58a6ff', '#9ed8ff', '#e4f6ff', '#ffffff',
];

const List<String> plasmaSparks = [
  '#ffffff', '#c8f8ff', '#7ff3ff', '#1ab8e6',
];

final int kLightningSoot = hex('#110c16');
final int kLightningSoot2 = hex('#1c1522');

class BoltPath {
  final List<Point2> pts;
  final double w;
  const BoltPath(this.pts, this.w);
}

class BoltTree {
  final List<BoltPath> paths;
  const BoltTree(this.paths);
}

BoltTree zigzag(
  Rng r,
  double x0,
  double y0,
  double x1,
  double y1, [
  double jag = 0.32,
  double forks = 0.35,
  double w = 1.0,
  int depth = 0,
]) {
  final out = <BoltPath>[];
  final l = hypot(x1 - x0, y1 - y0);
  var pts = <Point2>[(x0, y0), (x1, y1)];
  var off = l * jag;
  while (pts.length < 2.0 + l / 3.0) {
    final nxt = <Point2>[pts[0]];
    for (var i = 0; i < pts.length - 1; i++) {
      final (ax, ay) = pts[i];
      final (bx, by) = pts[i + 1];
      final segRaw = hypot(bx - ax, by - ay);
      final segL = segRaw == 0.0 ? 1.0 : segRaw;
      final o = r.range(-off, off);
      nxt.add((
        (ax + bx) / 2.0 + (-(by - ay) / segL) * o,
        (ay + by) / 2.0 + ((bx - ax) / segL) * o,
      ));
      nxt.add((bx, by));
    }
    pts = nxt;
    off *= 0.52;
  }
  out.add(BoltPath(pts, w));
  if (depth < 2) {
    for (var i = 2; i < pts.length - 3; i++) {
      if (r.chance(forks / (1 + depth) / math.max(4.0, pts.length / 6.0))) {
        final (ax, ay) = pts[i];
        final (bx, by) = pts[math.min(pts.length - 1, i + 3)];
        final a = math.atan2(by - ay, bx - ax) + r.sign() * r.range(0.35, 0.9);
        final fl = (l - (i / pts.length) * l) * r.range(0.25, 0.55);
        out.addAll(
          zigzag(
            r,
            ax,
            ay,
            ax + math.cos(a) * fl,
            ay + math.sin(a) * fl,
            jag * 1.1,
            forks,
            w * 0.55,
            depth + 1,
          ).paths,
        );
      }
    }
  }
  return BoltTree(out);
}

BoltTree bendBolt(BoltTree b, Point2 Function(double x, double y) fn) =>
    BoltTree([
      for (final q in b.paths)
        BoltPath([for (final (x, y) in q.pts) fn(x, y)], q.w),
    ]);

class _LightningInkGrid {
  static const int n = 1024;
  static const int half = 512;
  final Uint8List grid = Uint8List(n * n);
  final List<int> hit = [];

  void mark(num x, num y, int lvl) {
    final ix = x.floor() + half;
    final iy = y.floor() + half;
    if (ix < 0 || iy < 0 || ix >= n || iy >= n) return;
    final i = iy * n + ix;
    final v = grid[i];
    if (v == 0) hit.add(i);
    if (lvl > v) grid[i] = lvl;
  }

  void stamp(double x, double y, double r, int lvl) {
    if (r <= 0.5) {
      mark(x.round(), y.round(), lvl);
      return;
    }
    final r2 = r * r;
    final y0 = (y - r).floor();
    final y1 = (y + r).ceil();
    final x0 = (x - r).floor();
    final x1 = (x + r).ceil();
    for (var py = y0; py <= y1; py++) {
      final dy = py + 0.5 - y;
      for (var px = x0; px <= x1; px++) {
        final dx = px + 0.5 - x;
        if (dx * dx + dy * dy <= r2) mark(px, py, lvl);
      }
    }
  }

  void flush(Painter p, List<int> cols, [List<double>? alphas]) {
    for (final i in hit) {
      final v = grid[i];
      grid[i] = 0;
      final x = (i % n) - half;
      final y = (i ~/ n) - half;
      final a = alphas != null ? alphas[v - 1] : 1.0;
      if (a >= 1.0) {
        p.px(x, y, cols[v - 1]);
      } else if (a > 0.0) {
        p.dot(x, y, cols[v - 1], a);
      }
    }
    hit.clear();
  }
}

final _LightningInkGrid _inkGrid = _LightningInkGrid();
const List<(int, int)> _cross = [(1, 0), (-1, 0), (0, 1), (0, -1)];

void _walk(
  List<Point2> pts,
  void Function(double x, double y, int i) fn,
) {
  for (var i = 0; i < pts.length - 1; i++) {
    final (ax, ay) = pts[i];
    final (bx, by) = pts[i + 1];
    final l = math.max(1.0, hypot(bx - ax, by - ay));
    for (var d = 0.0; d <= l; d += 0.5) {
      fn(ax + ((bx - ax) * d) / l, ay + ((by - ay) * d) / l, i);
    }
  }
}

void boltStroke(
  Painter p,
  BoltTree b,
  double k,
  List<int> c, [
  double s = 1.0,
  bool hero = false,
  double light = 0.5,
  double a = 1.0,
  double core = 0.0,
  double? minY,
]) {
  if (k <= 0.02) return;
  for (final q in b.paths) {
    final trunk = q.w >= 1.0;
    if (!trunk && k < 0.5) continue;
    final rh = (trunk ? (k > 0.6 ? 2.1 : 1.6) : 1.1) * s;
    final rb = (trunk ? (k > 0.6 ? 1.3 : 0.8) : 0.5) * s;
    final pts = q.pts;
    _walk(pts, (x, y, _) {
      _inkGrid.stamp(x, y, rh, 1);
      _inkGrid.stamp(x, y, rb, trunk ? 3 : 2);
      if (trunk && k > 0.3) {
        if (core > 0.0) {
          _inkGrid.stamp(x, y, core, 4);
        } else {
          _inkGrid.mark(x, y, 4);
        }
      }
    });
    for (var i = 0; i < pts.length - 1; i += 3) {
      if (minY == null || pts[i].$2 > minY) {
        p.glow(pts[i].$1, pts[i].$2, (trunk ? 14.0 : 7.0) * s, c[4],
            light * k * q.w);
      }
    }
  }
  _inkGrid.flush(
    p,
    hero ? [c[3], c[6], c[7], c[7]] : [c[2], c[4], c[5], c[7]],
    [a, a, a, a],
  );
}

void crackle(
  Painter p,
  BoltTree b,
  double k,
  List<int> c, [
  double glowK = 0.5,
  double a = 1.0,
]) {
  if (k <= 0.02) return;
  for (final q in b.paths) {
    final thick = q.w >= 1.0;
    _walk(q.pts, (x, y, _) {
      if (k > 0.45 && thick) {
        for (final (dx, dy) in _cross) {
          _inkGrid.mark(x + dx * 1.5, y + dy * 1.5, 1);
        }
      }
      if (k > 0.25 && (thick || q.w > 0.4)) {
        _inkGrid.mark(x + 1, y, 2);
        _inkGrid.mark(x, y + 1, 2);
      }
      _inkGrid.mark(x, y, thick && k > 0.3 ? 4 : 3);
    });
    for (var i = 0; i < q.pts.length - 1; i += 3) {
      p.glow(q.pts[i].$1, q.pts[i].$2, (thick ? 9.0 : 5.0) * (0.5 + k * 0.5),
          c[4], glowK * k * q.w);
    }
  }
  _inkGrid.flush(
    p,
    [c[3], c[5], c[5], c[7]],
    [math.min(1.0, (k - 0.45) * 1.6) * a, a, a, a],
  );
}

void traceBolt(
  Painter p,
  List<Point2> pts,
  int c, [
  double a = 1.0,
  int from = 0,
  int? to,
]) {
  final end = math.min(to ?? pts.length - 1, pts.length - 1);
  for (var i = math.max(0, from); i < end; i++) {
    p.line(pts[i].$1, pts[i].$2, pts[i + 1].$1, pts[i + 1].$2, c, a);
  }
}

void lightningScorch(
  Painter p,
  double cx,
  double cy,
  double rx,
  double t0, [
  double fade = 1.0,
  double? ry,
]) {
  if (fade <= 0.0) return;
  final ryVal = ry ?? math.max(2.5, rx * 0.12);
  final y0 = cy.floor();
  final y1 = (cy + ryVal).floor();
  final x0 = (cx - rx).floor();
  final x1 = (cx + rx).ceil();
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      final dx = (x + 0.5 - cx) / rx;
      final dy = (y + 0.5 - cy) / ryVal;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > 1.0) continue;
      final n = rand(x, y, 41);
      final temp = t0 * (1.25 - d) - n * 0.35;
      if (temp > 0.06) {
        final idx = math.min(
          kFireRamp.length - 1,
          ((1.0 - math.min(1.0, temp)) * (kFireRamp.length - 1)).floor(),
        );
        final c = kFireRamp[idx];
        p.dot(x, y, c, fade);
        if ((x & 3) == 0) p.glow(x + 0.5, y, 6, c, 0.18 * temp * fade);
      } else {
        p.dot(x, y, d < 0.5 ? kLightningSoot : kLightningSoot2,
            (d < 0.95 - n * 0.3 ? 1.0 : 1.0 - d) * fade);
      }
    }
  }
}

int heatColor(double t) {
  if (t <= 0.06) return 0;
  final idx = math.min(
    kFireRamp.length - 1,
    ((1.0 - math.min(1.0, t)) * (kFireRamp.length - 1)).floor(),
  );
  return kFireRamp[idx];
}
