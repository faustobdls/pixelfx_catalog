import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'projectiles_lib.dart';

const _energyDiscMeta = EffectMeta(
  id: 'projectiles/energy-disc',
  name: 'Energy disc',
  desc:
      'A sawblade of crackling energy spinning flat out as it flies: hooked teeth bright on their leading edges, a white hub, spiral arms churning, sparks flung off the teeth.',
  category: 'projectiles',
  tags: [
    'projectile',
    'disc',
    'saw',
    'energy',
    'sci-fi',
    'directional',
    'loop',
  ],
  size: (120, 52),
  origin: (92, 26),
  duration: 0.5,
  loop: true,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': [
      '#0a0f2e',
      '#172a78',
      '#2550d0',
      '#3f8cff',
      '#7cc8ff',
      '#c8f0ff',
      '#ffffff',
    ],
    'size': 9,
    'teeth': 8,
    'speed': 220,
    'seed': 5,
  },
);

final PixelEffect energyDiscEffect = PureEffect(
  meta: _energyDiscMeta,
  onDraw: (p, t, o) {
    final c = fit(o.palette, 7);
    final rad = o.numOpt('size', 9);
    final n = o.intOpt('teeth', 8);
    final v = o.numOpt('speed', 220);
    final s = o.seed;
    const d = 0.5;
    final left = -_energyDiscMeta.origin.$1 + 2.0;
    final rot = (tau * 3 * t) / d;
    final segVal = tau / n;
    double frac(double x) => x - x.floor();

    beat(t, d, 8, s + 4, (r) => r.range(0.12, 0.22), (age, life, r, _) {
      final k = age / life;
      final side = r.chance(0.5) ? -1 : 1;
      final x0 = -2 - age * r.range(180, 260);
      final len = r.range(8, 16) * (0.5 + k);
      final y = side * (rad + r.range(0.5, 3));
      if (x0 - len < left) return;
      p.lineShaded(
        x0,
        y,
        x0 - len,
        y,
        color: (_) => k < 0.35
            ? c[5]
            : k < 0.7
                ? c[4]
                : c[3],
        alpha: (u) => (u < 0.65 ? 1.0 : (1 - u) / 0.35),
      );
    });
    p.glowLine(-2, 0, -26, 0, 8, c[3], 0.35);

    final sp = [kWhite, c[5], c[4], c[3]];
    beat(t, d, 20, s, (r) => r.range(0.12, 0.3), (age, life, r, _) {
      final a = rot - r.range(0, tau) * 0 + r.range(0, tau);
      final tip = rad + 3.5;
      final x0 = math.cos(a) * tip;
      final y0 = math.sin(a) * tip;
      final spd = r.range(120, 230);
      final (x, y, vx, vy) = wake(
        x0,
        y0,
        -math.sin(a) * spd,
        math.cos(a) * spd,
        age,
        v * 0.6,
        2.4,
        60,
      );
      if (x > left + 8 && y.abs() < 23) {
        spark(p, x, y, vx, vy, 1 - age / life, sp, 0.45, 0.014, 7);
      }
    });

    p.shade(-rad - 5, -rad - 5, rad + 5, rad + 5, (x, y, _) {
      final r = hypot(x, y);
      final th = math.atan2(y, x);
      if (r > rad + 4.6) return null;
      if (r <= rad) {
        if (r < 1.8) return kWhite;
        if (r < 2.9) return c[1];
        if (r > rad - 1.1) return c[5];
        final arm = math.sin(3 * (th - rot * 0.5) - r * 0.85);
        return arm > 0.65
            ? c[5]
            : arm > 0.2
                ? c[4]
                : arm > -0.3
                    ? c[3]
                    : c[2];
      }
      final ph = frac((th - rot) / segVal);
      final h = 4.2 * math.pow(ph, 1.4);
      if (r - rad < h) {
        return ph > 0.86
            ? kWhite
            : ph > 0.6
                ? c[6]
                : ph > 0.35
                    ? c[5]
                    : c[4];
      }
      if (r - rad < 1.6) return c[2];
      return null;
    });

    final fr = (t * 30 + 1e-6).floor();
    for (var j = 0; j < 3; j++) {
      final g = rng(fr, j, s);
      final a0 = g.range(0, tau);
      final pts = <(double, double)>[];
      for (var i = 0; i <= 4; i++) {
        final rr = 2.5 + ((rad - 3) * i) / 4;
        final a = a0 + i * 0.25 + (i != 0 ? g.range(-0.35, 0.35) : 0);
        pts.add((math.cos(a) * rr, math.sin(a) * rr));
      }
      p.polyline(pts, j != 0 ? c[6] : kWhite);
    }
    p.ring(0, 0, rad + 0.5, 1, c[6]);
    p.glow(0, 0, 30, c[3], 0.4);
    p.glow(0, 0, 6, c[5], 0.35);
    p.glow(math.cos(rot) * rad, math.sin(rot) * rad, 5, c[6], 0.4);
  },
);
