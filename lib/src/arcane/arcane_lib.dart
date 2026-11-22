// Shared by the arcane effects.
// Adapted from Sprite Fusion's open-source black hole & energy
// (https://www.spritefusion.com/pixel-art-vfx/energy), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

const List<double> _bayer4x4 = [
  0.5 / 16, 8.5 / 16, 2.5 / 16, 10.5 / 16,
  12.5 / 16, 4.5 / 16, 14.5 / 16, 6.5 / 16,
  3.5 / 16, 11.5 / 16, 1.5 / 16, 9.5 / 16,
  15.5 / 16, 7.5 / 16, 13.5 / 16, 5.5 / 16,
];
const List<(int, int)> _cross = [(1, 0), (-1, 0), (0, 1), (0, -1)];

double arcaneBayer(double x, double y) =>
    _bayer4x4[((y.floor() & 3) << 2) | (x.floor() & 3)];

int tone(
  List<int> r,
  double intensity,
  double x,
  double y, [
  double lo = 0.06,
  double sharp = 0.0,
]) {
  final b = arcaneBayer(x, y);
  if (intensity < lo && b > intensity / lo) return 0;
  final n = r.length - 1;
  final f = clamp(intensity) * n;
  var i = f.floor();
  final q = sharp > 0.0
      ? clamp((f - i - 0.5) / (1.0 - sharp) + 0.5)
      : f - i;
  if (q > b) i = math.min(n, i + 1);
  return r[i];
}

void mote(
  Painter p,
  double x,
  double y,
  double vx,
  double vy,
  int c, [
  double size = 1.0,
  double k = 1.0,
  double glow = 0.4,
]) {
  final rawSp = hypot(vx, vy);
  final sp = rawSp == 0.0 ? 1.0 : rawSp;
  final ux = vx / sp;
  final uy = vy / sp;
  final len = math.min(16.0, 0.5 + sp * 0.026) * size;
  final a = k < 0.35 ? k / 0.35 : 1.0;
  if (len > 1.2) {
    p.line(x - ux * len, y - uy * len, x - ux * len * 0.35, y - uy * len * 0.35,
        scaleColor(c, 0.55), a);
  }
  p.line(x - ux * len * 0.4, y - uy * len * 0.4, x, y, c, a);
  if (glow > 0.0) p.glow(x, y, 2.5 + size, c, glow * k);
}

void streak(
  Painter p,
  double x,
  double y,
  double vx,
  double vy,
  int c, [
  double a = 1.0,
  double maxLen = 7.0,
  double glow = 0.4,
]) {
  final rawSp = hypot(vx, vy);
  final sp = rawSp == 0.0 ? 1.0 : rawSp;
  final ux = vx / sp;
  final uy = vy / sp;
  final l = clamp(sp / 30.0, 1.0, maxLen);
  for (var d = l; d >= 0.0; d -= 0.5) {
    p.dot(
      x - ux * d,
      y - uy * d,
      d < 1.0 ? kWhite : (d < l * 0.5 ? c : scaleColor(c, 0.6)),
      (d < l * 0.5 ? 1.0 : 1.2 - d / l) * a,
    );
  }
  if (glow > 0.0) p.glow(x, y, 4, c, glow * a);
}

class ArcaneArcPath {
  final List<Point2> pts;
  final double w;

  const ArcaneArcPath(this.pts, this.w);
}

List<ArcaneArcPath> arcaneArc(
  Rng r,
  double x0,
  double y0,
  double x1,
  double y1, {
  double jag = 0.3,
  int forks = 1,
  double forkLen = 0.5,
}) {
  final l = hypot(x1 - x0, y1 - y0);
  final depth = math.max(
      1, math.min(5, (math.log(math.max(1e-6, l / 1.5)) / math.ln2).round()));
  final main = bolt(r, x0, y0, x1, y1, jag: jag, depth: depth);
  final out = <ArcaneArcPath>[ArcaneArcPath(main, 1.0)];
  for (var k = 0; k < forks && main.length > 3; k++) {
    if (r.next() > 0.7) continue;
    final i = 1 + (r.next() * (main.length - 2)).floor();
    final (x, y) = main[i];
    final (px, py) = main[i - 1];
    final a = math.atan2(y - py, x - px) +
        (r.next() < 0.5 ? -1.0 : 1.0) * (0.4 + r.next() * 0.6);
    final fl = l * forkLen * (0.4 + 0.6 * r.next()) * (1.0 - i / main.length);
    if (fl > 1.5) {
      out.add(ArcaneArcPath(
        bolt(r, x, y, x + math.cos(a) * fl, y + math.sin(a) * fl,
            jag: jag * 1.1, depth: math.max(1, depth - 2)),
        0.55,
      ));
    }
  }
  return out;
}

void drawArc(
  Painter p,
  List<ArcaneArcPath> paths, {
  required int core,
  required int body,
  required int halo,
  required int glow,
  double k = 1.0,
  double glowK = 0.5,
}) {
  void steps(
    void Function(double x, double y, ArcaneArcPath path, int i, bool first) fn,
  ) {
    for (final path in paths) {
      for (var i = 0; i < path.pts.length - 1; i++) {
        final (ax, ay) = path.pts[i];
        final (bx, by) = path.pts[i + 1];
        final l = math.max(1.0, hypot(bx - ax, by - ay));
        for (var d = 0.0; d <= l; d += 0.5) {
          fn(ax + ((bx - ax) * d) / l, ay + ((by - ay) * d) / l, path, i,
              d == 0.0);
        }
      }
    }
  }

  if (k > 0.45) {
    steps((x, y, path, _, _) {
      if (path.w >= 1.0) {
        for (final (dx, dy) in _cross) {
          p.dot(x + dx * 1.5, y + dy * 1.5, halo, (k - 0.45) * 1.6);
        }
      }
    });
  }
  if (k > 0.25) {
    steps((x, y, path, _, _) {
      if (path.w > 0.4) {
        p.dot(x + 1.0, y, body);
        p.dot(x, y + 1.0, body);
      }
    });
  }
  steps((x, y, path, i, first) {
    p.px(x, y, path.w >= 1.0 && k > 0.3 ? core : body);
    if (first && i % 3 == 0) {
      p.glow(x, y, (path.w >= 1.0 ? 9.0 : 5.0) * (0.5 + k * 0.5), glow,
          glowK * k * path.w);
    }
  });
}

void floorRing(
  Painter p,
  double cx,
  double cy,
  double r,
  double sy,
  int Function(double ang) color, [
  double Function(double ang)? alpha,
  bool Function(double ang)? keep,
]) {
  if (r < 0.5) return;
  final ry = r * sy;
  final rySafe = math.max(0.3, ry);
  p.shade(cx - r - 1, cy - ry - 1, cx + r + 1, cy + ry + 1, (x, y, o) {
    final nx = (x - cx) / r;
    final ny = (y - cy) / rySafe;
    final d = hypot(nx, ny);
    if (d < 1e-6) return null;
    final g = hypot(nx / r, ny / rySafe) / d;
    if ((d - 1.0).abs() / g > 0.5) return null;
    final ang = math.atan2(ny, nx);
    if (keep != null && !keep(ang)) return null;
    o.c = color(ang);
    o.a = alpha != null ? alpha(ang) : 1.0;
    return null;
  });
}

const List<List<String>> arcaneGlyphs = [
  ['.#.', '#.#', '.#.', '.#.', '#.#'],
  ['#.#', '#.#', '.#.', '#.#', '#.#'],
  ['##.', '#.#', '##.', '#..', '#..'],
  ['#..', '#.#', '###', '#.#', '..#'],
  ['.##', '#..', '.#.', '..#', '##.'],
  ['###', '.#.', '###', '.#.', '.#.'],
  ['#.#', '###', '#.#', '..#', '..#'],
  ['.#.', '.##', '.#.', '##.', '.#.'],
];

void arcaneGlyph(
  Painter p,
  int i,
  double x,
  double y,
  int c, [
  double a = 1.0,
  int under = 0,
]) {
  final g = arcaneGlyphs[wrapInt(i, arcaneGlyphs.length)];
  final ix = x.round() - 1;
  final iy = y.round() - g.length + 1;
  if (under != 0) p.sprite(g, const {}, ix, iy + 1, tint: under, a: a);
  p.sprite(g, const {}, ix, iy, tint: c, a: a);
}

Uint8List actorShades(ActorDefinition a) {
  final s = Uint8List(a.w * a.h);
  for (var i = 0; i < s.length; i++) {
    if (a.mask.data[i] != 0) {
      final l = luma(a.pixels[i]);
      s[i] = l < 0.24 ? 1 : (l < 0.62 ? 2 : 3);
    }
  }
  return s;
}

const List<List<String>> arcaneSigils = [
  ['..#..', '.#.#.', '#.#.#', '..#..', '.###.', '..#..', '.#.#.'],
  ['#...#', '.#.#.', '..#..', '.###.', '..#..', '.#.#.', '#...#'],
  ['#....', '##...', '#.#..', '#..#.', '#.#..', '##...', '#....'],
  ['..#..', '#.#.#', '.###.', '..#..', '..#..', '.#.#.', '#...#'],
  ['#.#.#', '#.#.#', '#####', '..#..', '..#..', '..#..', '.###.'],
  ['#...#', '##.##', '#.#.#', '#...#', '#.#.#', '##.##', '#...#'],
  ['..#..', '.#.#.', '#...#', '.#.#.', '..#..', '..#..', '..#..'],
  ['#..#.', '#.#..', '##...', '#....', '##...', '#.#..', '#..#.'],
];

void sigil(
  Painter p,
  int i,
  double x,
  double y,
  int c, [
  double a = 1.0,
  int edge = 0,
]) {
  final g = arcaneSigils[wrapInt(i, arcaneSigils.length)];
  final ix = (x + 0.5).floor() - 2;
  final iy = (y + 0.5).floor() - 3;
  if (edge != 0) {
    for (final (dx, dy) in _cross) {
      p.sprite(g, const {}, ix + dx, iy + dy, tint: edge, a: a);
    }
  }
  p.sprite(g, const {}, ix, iy, tint: c, a: a);
}

void squeezed(
  Painter p,
  ActorDefinition actor,
  Uint8List sh,
  double sx,
  int body,
  int edge, [
  double a = 1.0,
  double dx = 0.0,
]) {
  if (sx <= 0.02) return;
  final cx = actor.x + actor.w / 2.0;
  final half = actor.w / 2.0 + 1.0;
  for (var y = 0; y < actor.h; y++) {
    for (var x = (cx - half * sx).floor();
        x <= (cx + half * sx).ceil();
        x++) {
      final raw = cx + (x + 0.5 - cx) / sx - 0.5;
      final i = (raw + 0.5).floor() - actor.x;
      final v = (i < 0 || i >= actor.w) ? 0 : sh[y * actor.w + i];
      if (v != 0) {
        p.dot(x + dx, (actor.y + y).toDouble(), v == 1 ? edge : body, a);
      }
    }
  }
}
