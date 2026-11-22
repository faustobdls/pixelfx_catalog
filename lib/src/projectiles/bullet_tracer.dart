import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'projectiles_lib.dart';

const _slug = ['..oyyp..', '.ypwwwwp', 'ywwwwwww', '.ypwwwwp', '..oyyp..'];

const _bulletTracerMeta = EffectMeta(
  id: 'projectiles/bullet-tracer',
  name: 'Bullet tracer',
  desc:
      'A white-hot slug tearing along, its tracer burning behind it in a long streak that sputters and cools from white through gold to red, shedding sparks and a thread of smoke.',
  category: 'projectiles',
  tags: ['projectile', 'bullet', 'tracer', 'gun', 'directional', 'loop'],
  size: (200, 40),
  origin: (184, 18),
  duration: 0.6,
  loop: true,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': [
      '#4a1712',
      '#8a1f17',
      '#c9281f',
      '#f2561d',
      '#ff8a2a',
      '#ffc23d',
      '#ffe26b',
      '#fff3a6',
      '#ffffff',
    ],
    'smoke': ['#2e2a36', '#46404f', '#625b6b', '#817a8a', '#a39caa'],
    'length': 120,
    'speed': 520,
    'seed': 4,
  },
);

final PixelEffect bulletTracerEffect = PureEffect(
  meta: _bulletTracerMeta,
  onDraw: (p, t, o) {
    final f = fit(o.palette, 9);
    final sm = fit(o.rampOpt('smoke'), 5);
    final s = o.seed;
    const dDur = 0.6;
    final l = o.numOpt('length', 120);
    final v = o.numOpt('speed', 520);
    final fr = (t * 30 + 1e-6).floor();
    final ph = (tau * t) / dDur;
    final left = -_bulletTracerMeta.origin.$1 + 2.0;

    final puffs = <CloudPuff>[];
    beat(t, dDur, 18, s + 7, (r) => r.range(0.5, 0.7), (age, life, r, _) {
      final k = age / life;
      final x = -l * r.range(0.45, 0.8) - age * 90;
      final y = 0.5 +
          math.sin(age * 6 + r.range(0, tau)) * age * 3 -
          age * age * 8;
      if (x < left + 6) return;
      puffs.add(CloudPuff(
        x: x,
        y: y,
        r: 1.2 + age * 4,
        a: 0.55 *
            (1 - k) *
            math.min(1.0, age * 8) *
            smooth(left, left + 30, x),
        b: 0.95 - k * 0.4,
        w: 0,
      ));
    });
    cloud(p, puffs, sm, sm, dens: 1.2, max: 0.6);

    double heat(double d) =>
        1 -
        math.pow(d / l, 0.8) +
        noise(d * 0.12 - t * 40, s) * 0.12 +
        0.08 * math.sin(d * 0.35 - ph * 9);
    double yAt(double d) => 0.5 + math.sin(d * 0.09 + ph * 2) * (d / l) * 0.8;
    final hot = l * 0.32;
    p.shade(-hot - 1, -4, 1, 5, (x, y, _) {
      final d = -x;
      final u = d / hot;
      if (u < 0 || u > 1) return null;
      final w = 0.7 +
          2.3 *
              math.pow(1 - u, 1.4) *
              (0.9 + 0.1 * math.sin(d * 0.8 - ph * 12));
      final vv = (y - yAt(d)).abs() / w;
      if (vv > 1) return null;
      final h = heat(d);
      return vv < 0.38
          ? (h > 0.8 ? kWhite : f[7])
          : vv < 0.7
              ? (h > 0.75
                  ? f[7]
                  : h > 0.6
                      ? f[6]
                      : f[5])
              : u < 0.5
                  ? f[5]
                  : f[4];
    });
    for (var d = hot; d <= l; d += 0.5) {
      final u = d / l;
      final h = heat(d);
      if (u > 0.55 && rand((d / 3).floor(), fr, s) < (u - 0.55) * 1.6) continue;
      final c = h > 0.55
          ? f[6]
          : h > 0.42
              ? f[5]
              : h > 0.3
                  ? f[4]
                  : h > 0.18
                      ? f[3]
                      : h > 0.08
                          ? f[2]
                          : f[1];
      p.dot(-d, yAt(d), c, u < 0.85 ? 1.0 : (1 - u) / 0.15);
    }
    p.glowLine(-2, 1, -l * 0.45, 1, 6, f[4], 0.35);
    p.glowLine(-2, 1, -l * 0.2, 1, 3, f[7], 0.3);

    final sp = [f[7], f[6], f[4], f[3]];
    beat(t, dDur, 16, s + 2, (r) => r.range(0.1, 0.28), (age, life, r, _) {
      final (x, y, vx, vy) = wake(
        -r.range(4, l * 0.5),
        0.5 + r.range(-0.5, 1),
        -r.range(10, 80),
        r.range(-60, 50),
        age,
        v * 0.35,
        3,
        260,
      );
      if (x > left + 8) spark(p, x, y, vx, vy, 1 - age / life, sp, 0.45, 0.012, 6);
    });

    p.sprite(
      _slug,
      {'w': kWhite, 'p': f[7], 'y': f[6], 'o': f[5]},
      -1,
      -1,
    );
    p.glow(2, 1, 24, f[4], 0.5);
    p.glow(3, 1, 8, kWhite, 0.55);
  },
);
