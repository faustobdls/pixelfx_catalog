// Shared by the water effects: the water ramp, droplets that fly over a water surface seen at a low angle and
// land with rings, ripple trains, lacy foam, foam billows, wet stone.
// The droplet sprites (a pixel, a shaded 2x2, a round bead with a highlight, each trailing a tail along its
// motion) are adapted from Sprite Fusion's open-source blood (https://www.spritefusion.com/pixel-art-vfx/blood),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

/// Water, deep to white: deep color only in shadow, tinted middles, white crests.
const List<String> kWaterPalette = [
  '#0a1630',
  '#123063',
  '#1b5596',
  '#2a7fc4',
  '#45a9e3',
  '#86d3f5',
  '#cdf1ff',
  '#ffffff',
];

/// Wet stone for props (lips, basins, vents), outline to highlight.
const List<String> kRockPalette = [
  '#141219',
  '#221f2b',
  '#34303f',
  '#4a4558',
  '#655f74',
  '#8a8498',
];

List<int> rockColors() => kRockPalette.map(hex).toList(growable: false);

/// A droplet at (x, y) moving at (vx, vy) px/s: [s] 1 is a pixel, 2 a shaded 2x2,
/// 3 a round bead with a highlight; a tail trails back along its motion, longer the faster it goes.
void bead(
  Painter p,
  double x,
  double y,
  double vx,
  double vy,
  int s,
  List<int> c, [
  double a = 1.0,
]) {
  final spRaw = hypot(vx, vy);
  final sp = spRaw == 0.0 ? 1.0 : spRaw;
  final ux = vx / sp;
  final uy = vy / sp;
  final tail = math.min(5.0, sp * 0.011);
  if (tail >= 1.0) {
    p.lineShaded(
      x - ux * (tail + 1.0),
      y - uy * (tail + 1.0),
      x - ux * 1.2,
      y - uy * 1.2,
      color: (u) => u < 0.45 ? c[3] : (s > 1 ? c[5] : c[4]),
      alpha: (_) => a,
    );
  }
  if (s >= 3) {
    p.circle(x, y, 1.75, c[4], a);
    p.circle(x - 0.25, y - 0.25, 1.15, c[6], a);
    p.dot(x - 0.7, y - 0.7, kWhite, a);
  } else if (s >= 2) {
    final xi = x.floor();
    final yi = y.floor();
    p.dot(xi, yi, kWhite, a);
    p.dot(xi + 1, yi, c[6], a);
    p.dot(xi, yi + 1, c[5], a);
    p.dot(xi + 1, yi + 1, c[4], a);
  } else {
    p.dot(x, y, sp > 160.0 ? c[6] : c[5], a);
  }
}

class WaterDrop {
  double x;
  double z;
  double h;
  double vx;
  double vz;
  double vh;
  int s;
  double life;
  final double max;
  double delay;

  WaterDrop({
    this.x = 0.0,
    this.z = 0.0,
    this.h = 0.0,
    this.vx = 0.0,
    this.vz = 0.0,
    this.vh = 0.0,
    this.s = 1,
    this.life = 4.0,
    this.delay = 0.0,
  }) : max = life;
}

class Drops {
  final double sy;
  final double g;
  final double drag;
  final void Function(WaterDrop drop)? onLand;
  final List<WaterDrop> list = [];

  Drops({
    this.sy = 0.22,
    this.g = 820.0,
    this.drag = 0.35,
    this.onLand,
  });

  void add(WaterDrop d) => list.add(d);

  int get count => list.length;

  void update(double dt) {
    final k = drag * dt;
    for (var i = list.length - 1; i >= 0; i--) {
      final d = list[i];
      if (d.delay > 0.0) {
        d.delay -= dt;
        continue;
      }
      d.life -= dt;
      if (d.life <= 0.0) {
        list.removeAt(i);
        continue;
      }
      d.vh -= g * dt;
      d.vx -= d.vx * k;
      d.vz -= d.vz * k;
      d.vh -= d.vh * k * 0.5;
      d.x += d.vx * dt;
      d.z += d.vz * dt;
      d.h += d.vh * dt;
      if (d.h <= 0.0 && d.vh < 0.0) {
        d.h = 0.0;
        list.removeAt(i);
        onLand?.call(d);
      }
    }
  }

  /// Draw drops behind z = 0 ('back'), in front ('front'), or all ('all').
  void draw(Painter p, List<int> c, [String layer = 'all']) {
    for (final d in list) {
      if (d.delay > 0.0 ||
          (layer == 'back' && d.z >= 0.0) ||
          (layer == 'front' && d.z < 0.0)) {
        continue;
      }
      final x = d.x;
      final y = d.z * sy - d.h;
      bead(p, x, y, d.vx, d.vz * sy - d.vh, d.s, c, math.min(1.0, d.life / 0.2));
      p.glow(x, y, 2.5 + d.s, c[5], 0.1 + 0.05 * d.s);
    }
  }
}

/// A ripple on a surface seen at a low angle.
void ring(
  Painter p,
  double cx,
  double cy,
  double r,
  double sy,
  double k,
  List<int> c, {
  int n = 2,
  double gap = 3.0,
  int half = 0,
  bool hot = false,
  double glint = 0.0,
  int seed = 0,
  double wob = 0.0,
}) {
  if (k <= 0.02 || r < 0.5) return;
  for (var j = 0; j < n; j++) {
    final rr = r - j * gap;
    if (rr < 0.6) break;
    final kj = k * (1.0 - j * 0.42);
    final m = math.max(6, (rr * tau * 1.3).ceil());
    final need = 1.15 - 2.3 * math.min(1.0, kj * 1.25);
    for (var i = 0; i < m; i++) {
      final a = (i / m) * tau;
      final s = math.sin(a);
      final near = s > 0.0;
      if ((half > 0 && !near) || (half < 0 && near)) continue;
      if (noise(a * 4.7 + seed * 13.1 + j * 5.3, seed) * 0.65 +
              noise(a * 11.3 + seed * 7.7, seed + 3) * 0.35 <
          need) {
        continue;
      }
      final lit = kj * (near ? 1.0 : 0.7) * (0.88 - 0.12 * math.cos(a));
      final col = hot && near && j == 0
          ? kWhite
          : c[lit > 0.7 ? 6 : (lit > 0.38 ? 5 : 4)];
      final ra = wob != 0.0
          ? rr + wob * noise(a * 2.6 + seed * 1.9 + j, seed + 11)
          : rr;
      final x = cx + math.cos(a) * ra;
      final y = cy + s * ra * sy;
      p.dot(x, y, col);
      if (j == 0) p.light(x, y, c[4], 0.3 * lit);
    }
  }
  if (glint > 0.0 && half >= 0) {
    final x = cx + math.cos(2.05) * r;
    final y = cy + math.sin(2.05) * r * sy;
    p.px(x, y, kWhite);
    p.glow(x, y, 3.0 + glint * 2.0, c[5], 0.35 * glint);
  }
}

class RippleEntry {
  final double x;
  final double z;
  final double r0;
  final double r1;
  final double life;
  double age;
  final double k;
  final int n;
  final double gap;
  final double hot;
  final double glint;
  final int seed;

  RippleEntry({
    required this.x,
    required this.z,
    required this.r0,
    required this.r1,
    required this.life,
    required this.age,
    required this.k,
    required this.n,
    required this.gap,
    required this.hot,
    required this.glint,
    required this.seed,
  });
}

class Ripples {
  final double sy;
  final List<RippleEntry> list = [];
  int _seq = 0;

  Ripples({this.sy = 0.22});

  void add(
    double x,
    double z,
    double r0,
    double r1,
    double life, {
    double delay = 0.0,
    double k = 1.0,
    int n = 2,
    double gap = 3.0,
    double hot = 0.1,
    double glint = 0.0,
  }) {
    _seq++;
    list.add(RippleEntry(
      x: x,
      z: z,
      r0: r0,
      r1: r1,
      life: life,
      age: -delay,
      k: k,
      n: n,
      gap: gap,
      hot: hot,
      glint: glint,
      seed: _seq,
    ));
  }

  int get count => list.length;

  void update(double dt) {
    for (var i = list.length - 1; i >= 0; i--) {
      list[i].age += dt;
      if (list[i].age >= list[i].life) list.removeAt(i);
    }
  }

  void draw(Painter p, List<int> c, [int half = 0]) {
    for (final q in list) {
      if (q.age < 0.0) continue;
      final u = q.age / q.life;
      final r = q.r0 + (q.r1 - q.r0) * (1.0 - math.pow(1.0 - u, 2.6));
      final k = q.k * math.pow(1.0 - u, 1.7);
      ring(
        p,
        q.x,
        q.z * sy,
        r,
        sy,
        k,
        c,
        n: q.n,
        gap: q.gap * (0.55 + 0.6 * u),
        half: half,
        hot: q.age < q.hot,
        glint: q.glint * k,
        seed: q.seed,
      );
    }
  }
}

/// Lacy foam floating on the surface around (cx, cy).
void lace(
  Painter p,
  double cx,
  double cy,
  double rx,
  double ry,
  double k,
  List<int> c,
  double t, [
  int seed = 0,
]) {
  if (k <= 0.01 || rx < 1.0) return;
  final sy = ry / rx;
  p.shade(cx - rx, cy - ry, cx + rx, cy + ry, (x, y, _) {
    final dx = (x - cx) / rx;
    final dy = (y - cy) / ry;
    final d = dx * dx + dy * dy;
    if (d > 1.0) return null;
    final u = (x - cx) * 0.36;
    final v = ((y - cy) / sy) * 0.36;
    final n = noise2(u + seed * 7.13, v - t * 0.35, seed);
    final m = noise2(u * 2.2 - t * 0.3, v * 2.2 + seed * 3.1, seed + 9);
    final net = 1.0 - n.abs() * 4.6 + m * 0.3;
    final need = 1.02 - k * (1.15 - d * 0.9);
    if (net < need) return null;
    return net > need + 0.4 ? kWhite : c[6];
  });
}

class MistPuff {
  double x;
  double y;
  double vx;
  double vy;
  final double r0;
  final double r1;
  double life;
  final double max;
  final int c;
  final double a;
  double delay;

  MistPuff({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.r0,
    required this.r1,
    required this.life,
    required this.c,
    required this.a,
    required this.delay,
  }) : max = life;
}

class Mist {
  final List<MistPuff> list = [];

  void add(
    double x,
    double y,
    double vx,
    double vy,
    double r0,
    double r1,
    double life,
    Object c, [
    double a = 0.25,
    double delay = 0.0,
  ]) {
    list.add(MistPuff(
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      r0: r0,
      r1: r1,
      life: life,
      c: hex(c),
      a: a,
      delay: delay,
    ));
  }

  int get count => list.length;

  void update(double dt) {
    for (var i = list.length - 1; i >= 0; i--) {
      final m = list[i];
      if (m.delay > 0.0) {
        m.delay -= dt;
        continue;
      }
      m.life -= dt;
      if (m.life <= 0.0) {
        list.removeAt(i);
        continue;
      }
      m.vx -= m.vx * 2.4 * dt;
      m.vy -= m.vy * 2.4 * dt + 7.0 * dt;
      m.x += m.vx * dt;
      m.y += m.vy * dt;
    }
  }

  void draw(Painter p, [int? haze]) {
    for (final m in list) {
      if (m.delay > 0.0) continue;
      final age = 1.0 - m.life / m.max;
      final r = m.r0 + (m.r1 - m.r0) * (1.0 - math.pow(1.0 - age, 2.2));
      final a = m.a * math.min(1.0, age / 0.12) * math.pow(1.0 - age, 1.4);
      if (a < 0.01) continue;
      p.discShaded(
        m.x,
        m.y,
        r,
        color: (_, _) => m.c,
        alpha: (d, _) => a * (1.0 - d * d) * (1.0 - d * 0.5),
      );
      p.discShaded(
        m.x - r * 0.2,
        m.y - r * 0.32,
        r * 0.55,
        color: (_, _) => kWhite,
        alpha: (d, _) => a * 0.25 * (1.0 - d) * (1.0 - d),
      );
      if (haze != null) {
        p.glow(m.x, m.y, r * 1.5, haze,
            (0.16 * a) / m.a * math.min(1.0, m.a * 3.0));
      }
    }
  }
}

/// A billow of churning foam: shadowed underside, white body, lit cap.
void billow(Painter p, double x, double y, double r, List<int> c, [double a = 1.0]) {
  if (r < 0.9) {
    p.dot(x, y, c[6], a);
    return;
  }
  p.circle(x + r * 0.12, y + r * 0.2, r, c[4], a);
  p.circle(x, y, r * 0.84, c[6], a);
  if (r > 1.6) p.circle(x - r * 0.3, y - r * 0.32, r * 0.46, kWhite, a);
}

/// A pebble or rock: lit upper left, shaded lower right, dark rim.
void pebble(Painter p, double x, double y, double r, List<int> st) {
  p.shade(x - r - 1.0, y - r - 1.0, x + r + 1.0, y + r + 1.0, (px, py, _) {
    final dx = px - x;
    final dy = py - y;
    final d = hypot(dx * 1.1, dy);
    if (d > r + 0.8) return null;
    final lit = (dx + dy) / math.max(0.5, r);
    return d > r
        ? st[0]
        : (lit < -0.7
            ? st[5]
            : (lit < 0.2 ? st[4] : (lit < 0.8 ? st[3] : st[2])));
  });
}
