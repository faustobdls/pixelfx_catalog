import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'projectiles_lib.dart';

const _laserBoltMeta = EffectMeta(
  id: 'projectiles/laser-bolt',
  name: 'Laser bolt',
  desc:
      'A red laser bolt: a white-hot core in a rounded head, red bands tapering back, pulses racing down it, a tail that shimmers apart into wavering dashes.',
  category: 'projectiles',
  tags: ['projectile', 'laser', 'energy', 'sci-fi', 'directional', 'loop'],
  size: (128, 32),
  origin: (108, 16),
  duration: 0.5,
  loop: true,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': [
      '#2a0610',
      '#5c0d1c',
      '#9a1428',
      '#d8243a',
      '#ff4d5e',
      '#ff8a94',
      '#ffd0d4',
      '#ffffff',
    ],
    'length': 40,
    'seed': 2,
  },
);

final PixelEffect laserBoltEffect = PureEffect(
  meta: _laserBoltMeta,
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final l = o.numOpt('length', 40);
    final s = o.seed;
    const dDur = 0.5;
    final ph = t / dDur;
    final fr = (t * 30 + 1e-6).floor();
    final left = -_laserBoltMeta.origin.$1 + 2.0;

    beat(t, dDur, 14, s, (r) => r.range(0.18, 0.3), (age, life, r, _) {
      final k = age / life;
      final x0 = -l * 0.8 - age * r.range(150, 230);
      final len = r.range(3, 7) * (1 - k * 0.5);
      final y = 0.5 +
          math.sin(x0 * 0.25 + ph * tau * 2) * (0.5 + k * 1.5) +
          r.range(-0.6, 0.6) * k;
      if (x0 - len < left || rand(fr, r.intRange(0, 999)) < k * 0.5) return;
      p.line(
        x0,
        y,
        x0 - len,
        y,
        k < 0.3
            ? c[5]
            : k < 0.6
                ? c[4]
                : c[3],
      );
      if (k < 0.4) p.glow(x0 - len / 2, y, 4, c[4], 0.3 * (1 - k));
    });

    p.shade(-l - 1, -5, 4, 6, (x, y, _) {
      final d = -x + 3;
      final u = d / (l + 3);
      if (u < 0 || u > 1) return null;
      final head = d < 3
          ? math.sqrt(math.max(0.0, 1 - math.pow((3 - d) / 3, 2)))
          : 1.0;
      final w = (3.4 * math.pow(1 - u, 0.9) + 0.5) *
          head *
          (1 + 0.08 * math.sin(d * 0.9 - ph * tau * 4));
      final v = (y - 0.5).abs() / w;
      if (v > 1.2) return null;
      if (v > 1 && (u > 0.5 || rand(x.floor(), fr) > 0.6)) return null;
      final pulse = (((d * 0.05 - ph * 3) % 1 + 1) % 1) < 0.12 ? 1 : 0;
      final lvl = v < 0.22
          ? (u < 0.6 ? 7 : 6)
          : v < 0.45
              ? 6 - (u > 0.5 ? 1 : 0)
              : v < 0.72
                  ? 4
                  : v <= 1
                      ? 3
                      : 2;
      return c[math.min(7, lvl + (v < 0.72 ? pulse : 0))];
    });

    for (final side in const [0.0, math.pi]) {
      for (var d = 2.0; d < l * 0.7; d += 1) {
        final a = d * 0.45 - ph * tau * 3 + side;
        final y = 0.5 + math.sin(a) * (2.2 * (1 - d / l) + 0.6);
        if (math.cos(a) > 0.3) p.dot(-d, y, math.cos(a) > 0.8 ? kWhite : c[6]);
      }
    }

    final g = 0.75 + 0.25 * math.sin(ph * tau * 2);
    sparkle(p, 1, 0.5, (3 + (g * 2 + 0.5).floor()).toDouble(), c[6], c[4], 0.5);
    p.glowLine(1, 0.5, -l, 0.5, 9, c[3], 0.4);
    p.glow(-2, 0.5, 20, c[3], 0.5 * g);
    p.glow(1, 0.5, 6, kWhite, 0.25);
  },
);
