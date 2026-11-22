import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'projectiles_lib.dart';

const _plasmaShotMeta = EffectMeta(
  id: 'projectiles/plasma-shot',
  name: 'Plasma shot',
  desc:
      'A glowing plasma blob: hot knots churning in its core, a corona crackling over its skin, its tail necking into droplets that tear off, cool and wink out behind.',
  category: 'projectiles',
  tags: ['projectile', 'plasma', 'energy', 'sci-fi', 'directional', 'loop'],
  size: (144, 60),
  origin: (108, 30),
  duration: 0.8,
  loop: true,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': [
      '#061a1c',
      '#0b3b34',
      '#0f6a4a',
      '#18a05a',
      '#3fd46a',
      '#8cf57e',
      '#d6ffc4',
      '#ffffff',
    ],
    'size': 6,
    'speed': 200,
    'seed': 3,
  },
);

class _PlasmaBall {
  const _PlasmaBall({
    required this.x,
    required this.y,
    required this.r,
    required this.h,
    required this.core,
    this.k = 0,
  });

  final double x;
  final double y;
  final double r;
  final double h;
  final double core;
  final double k;
}

final PixelEffect plasmaShotEffect = PureEffect(
  meta: _plasmaShotMeta,
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final rad = o.numOpt('size', 6);
    final v = o.numOpt('speed', 200);
    final s = o.seed;
    const dDur = 0.8;
    final w = (tau * t) / dDur;
    final fr = (t * 30 + 1e-6).floor();
    final left = -_plasmaShotMeta.origin.$1 + 2.0;

    final t0 = -rad * 3.2;
    double tail(double x) =>
        math.sin(x * 0.2 + w * 2) * (0.3 + ((t0 - x) / 44) * 1.8);
    for (var x = t0; x > t0 - 44; x -= 1) {
      final u = (t0 - x) / 44;
      final y = tail(x);
      p.dot(
        x,
        y,
        u < 0.2
            ? c[6]
            : u < 0.45
                ? c[5]
                : c[4],
        u < 0.55 ? 1.0 : (1 - u) / 0.45,
      );
      if (u < 0.3) p.px(x, y + 1, u < 0.15 ? c[5] : c[4]);
    }

    final balls = <_PlasmaBall>[
      _PlasmaBall(x: 0, y: 0, r: rad, h: 1, core: 0.8),
    ];
    const speeds = [2, -3, 5];
    for (var i = 0; i < 3; i++) {
      final a = w * speeds[i] + (i * tau) / 3;
      final d = rad * (0.5 + 0.1 * math.sin(w * 3 + i * 2));
      balls.add(_PlasmaBall(
        x: math.cos(a) * d - 0.4,
        y: math.sin(a) * d * 0.8,
        r: rad * 0.32,
        h: 1,
        core: 1,
      ));
    }
    for (var i = 1; i <= 6; i++) {
      final x = -rad * (0.5 + i * 0.42);
      final wag = MathHelper.sinWag(w, i);
      final br = rad * (0.62 - i * 0.08);
      balls.add(_PlasmaBall(
        x: x,
        y: wag,
        r: br,
        h: 0.96 - i * 0.05,
        core: math.sqrt((5.2 - i * 0.65) * 0.3) / br,
      ));
    }
    final drops = <_PlasmaBall>[];
    cycle(t, dDur, 11, s, (r) => r.range(0.34, 0.5), (age, life, r, _) {
      final k = age / life;
      final pull = r.range(450, 800);
      final x = -rad * 2.9 - 0.5 * pull * age * age - r.range(0, 16) * age;
      final y = math.sin(w * 2 - 5.4 + age * 12) * 2 +
          r.range(-30, 30) * age * (0.4 + age);
      final dr = rad * r.range(0.3, 0.48) * (1 - k * 0.6);
      drops.add(_PlasmaBall(
        x: x,
        y: y,
        r: dr,
        h: 0.97 * (1 - k * 0.75),
        core: math.sqrt(math.max(0.0, 1 - k * 1.3) * 7 * 0.3) / dr,
        k: k,
      ));
    });
    final all = [...balls, ...drops];

    p.shade(-rad * 2.6 - 60, -rad * 2 - 8, rad * 1.6, rad * 2 + 8, (x, y, _) {
      var f = 0.0;
      var heat = 0.0;
      var hh = 0.0;
      for (final b in all) {
        final dx = x - b.x;
        final dy = y - b.y;
        final d2 = dx * dx + dy * dy;
        final q = d2 / (4 * b.r * b.r);
        if (q < 1) {
          final col = ((1 - q) * (1 - q)) / 0.5625;
          f += col;
          heat += col * b.h;
        }
        if (b.core != 0) hh += (b.core * b.core * b.r * b.r) / (d2 + 0.3);
      }
      if (f < 1) return null;
      final lvl = hh > 10
          ? 7
          : hh > 4.6
              ? 6
              : hh > 2.2
                  ? 5
                  : f > 1.4
                      ? 4
                      : 3;
      final cap = (2 + (heat / f) * 5.4 + 0.5).floor();
      return c[math.max(
        2,
        math.min(x > rad * 0.3 && lvl < 5 ? lvl + 1 : lvl, cap),
      )];
    });

    for (var j = 0; j < 3; j++) {
      final g = rng(fr, j, s);
      final a0 = g.range(-2.3, 2.3);
      final span = g.range(0.45, 0.9) * g.sign();
      const n = 6;
      final hgt = g.range(1.5, 3.5);
      final pts = <(double, double)>[];
      for (var i = 0; i <= n; i++) {
        final a = a0 + (span * i) / n;
        final rr = rad +
            0.6 +
            hgt * math.sin((math.pi * i) / n) +
            (i % n != 0 ? g.range(-0.5, 0.5) : 0);
        pts.add((math.cos(a) * rr - 0.4, math.sin(a) * rr * 0.92));
      }
      p.polyline(pts, j != 0 ? c[5] : c[6]);
      p.px(pts[3].$1, pts[3].$2, kWhite);
      p.glow(pts[3].$1, pts[3].$2, 6, c[5], 0.4);
    }
    for (var j = 0; j < 4; j++) {
      final g = rng(fr, j + 9, s);
      final a = g.range(-2.2, 2.2);
      final l = g.range(1.5, 4);
      final r0 = rad + 1;
      final x0 = math.cos(a) * r0 - 0.4;
      final y0 = math.sin(a) * r0 * 0.92;
      p.line(
        x0,
        y0,
        x0 + math.cos(a) * l,
        y0 + math.sin(a) * l,
        j % 2 != 0 ? c[4] : c[5],
      );
    }

    final sp = [kWhite, c[6], c[5], c[3]];
    beat(t, dDur, 14, s + 5, (r) => r.range(0.12, 0.3), (age, life, r, _) {
      final a = r.range(-2.4, 2.4);
      final spd = r.range(60, 130);
      final (x, y, vx, vy) = wake(
        math.cos(a) * (rad + 1),
        math.sin(a) * (rad + 1),
        math.cos(a) * spd,
        math.sin(a) * spd,
        age,
        v * 0.7,
        4,
        0,
      );
      if (x > left + 4 && y.abs() < 26) {
        spark(p, x, y, vx, vy, 1 - age / life, sp, 0.4, 0.015, 6);
      }
    });

    final pulse = 0.85 + 0.15 * math.sin(w * 4);
    p.glow(-2, 0, 34, c[3], 0.8 * pulse);
    p.glow(0, 0, 16, c[4], 0.35 * pulse);
    p.glow(1, 0, 7, c[6], 0.3 * pulse);
    p.glowLine(-rad, 0, -rad * 4.6, 0, 7, c[3], 0.3);
    for (final d in drops) {
      if (d.x < left + 4) continue;
      if (d.k < 0.6 && d.x < -rad * 3.5) {
        p.px(d.x, d.y, d.k < 0.3 ? c[7] : c[6]);
      }
      p.glow(d.x, d.y, 3 + d.r * 2, c[2], 0.6 * (1 - d.k));
    }
  },
);

abstract final class MathHelper {
  static double sinWag(double w, int i) =>
      math.sin(w * 2 - i * 0.9) * (0.3 + i * 0.28);
}
