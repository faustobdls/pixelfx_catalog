import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'ice_lib.dart';

const double _duration = 0.8;

void _spear(Painter p, List<int> c, double len, double pulse, double glint) {
  const tipLen = 16.0;
  const hMax = 3.5;
  double half(double x) => x > -tipLen
      ? hMax * (-x / tipLen) + 0.3
      : (x < -len + 3.0 ? hMax * (0.7 + 0.3 * ((x + len) / 3.0)) : hMax);
  p.shade(-len - 1.0, -hMax - 2.0, 1.0, hMax + 2.0, (x, y, o) {
    if (x > 0.0 || x < -len) return null;
    final h = half(x);
    if (y.abs() > h + 0.5) {
      if (y.abs() < h + 1.5) o.c = c[1];
      return null;
    }
    final v = y / math.max(0.5, h);
    if (x > -1.5) return o.c = kWhite;
    if (v > -0.3 && v < 0.35 && (x - pulse).abs() < 2.5) return o.c = kWhite;
    if (v < -0.3 && (x - glint).abs() < 1.0) return o.c = kWhite;
    o.c = v < -0.72
        ? kWhite
        : (v < -0.36
            ? c[6]
            : (v < -0.18
                ? c[7]
                : (v < 0.38 ? c[4] : (v < 0.78 ? c[2] : c[1]))));
    return null;
  });
}

final PureEffect iceLanceEffect = PureEffect(
  meta: const EffectMeta(
    id: 'ice/ice-lance',
    name: 'Ice lance',
    desc:
        'A faceted ice spear flying right: a light pulse runs through its core, rings of cold air shear off the tip, frost peels off into a wake and crystals shed behind it.',
    category: 'ice',
    tags: ['ice', 'lance', 'spear', 'projectile', 'directional', 'magic', 'loop'],
    size: (176, 64),
    origin: (146, 32),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#151a3d', '#212f6b', '#2c58aa', '#3a8bd8',
        '#62c8f4', '#a6ecff', '#dcfbff', '#ffffff',
      ],
      'length': 40,
      'seed': 13,
    },
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final s = o.seed;
    final len = o.numOpt('length', 40.0);
    final ph = t / _duration;
    p.each(-len - 100.0, -12, -len + 4.0, 12, (x, y, sx, sy) {
      final u = (-len + 4.0 - x) / 104.0;
      final w = 4.5 * math.pow(1.0 - u, 0.7) +
          0.5 +
          1.5 * math.sin(u * 9.0 - ph * tau * 2.0) * u;
      final v = y.abs() / w;
      if (v >= 1.0) return;
      final a = (1.0 - v * v) * math.pow(1.0 - u, 1.4);
      if (a.isNaN || a < 0.04) return;
      p.blendPx(
        sx,
        sy,
        v < 0.25 && u < 0.4 ? c[6] : (v < 0.6 ? c[5] : c[4]),
        a * 0.7,
      );
      if (a > 0.3) p.add(sx, sy, c[5], 0.12 * a);
    });
    p.glowLine(-len - 60.0, 0, 0, 0, 14, c[4], 0.22);
    cycle(t, _duration, 14, s, (g) => g.range(0.35, 0.55), (age, life, r, _) {
      final x0 = r.range(-len + 2.0, -8.0);
      final (x, y) = fly(
        x0,
        r.range(-2.5, 2.5),
        -r.range(150, 230),
        r.sign() * r.range(8, 30),
        age,
        0,
        2.2,
      );
      final k = age / life;
      final rad = 1.2 + 5.5 * k;
      final a = 0.5 * math.pow(1.0 - k, 1.3);
      p.discShaded(
        x,
        y,
        rad,
        color: (_, _) => k < 0.3 ? c[6] : c[5],
        alpha: (d, _) => a * (1.0 - d * d),
      );
      p.glow(x, y, rad * 1.6, c[4], 0.1 * (1.0 - k));
    });
    cycle(t, _duration, 9, s + 1, (g) => g.range(0.4, 0.6),
        (age, life, r, _) {
      final (x, y) = fly(
        r.range(-len, -6.0),
        r.range(-3, 3),
        -r.range(170, 260),
        r.range(-35, 35),
        age,
        60,
        1.2,
      );
      final k = age / life;
      final a = r.range(0, tau) + age * r.range(10, 18) * r.sign();
      final l = r.range(1.2, 2.2);
      final ca = math.cos(a);
      final sa = math.sin(a);
      if (k > 0.85 && (age * 30.0).remainder(2.0) < 1.0) return;
      p.line(x - ca * l, y - sa * l, x + ca * l, y + sa * l, c[5]);
      p.px(x + ca * l, y + sa * l, kWhite);
      if (math.cos(a * 2.0) > 0.9) {
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          p.px(x + dx, y + dy, c[6]);
        }
        p.glow(x, y, 6, c[5], 0.45);
      }
    });
    cycle(t, _duration, 12, s + 2, (g) => g.range(0.16, 0.26),
        (age, life, r, _) {
      final y = r.sign() * r.range(4, 13);
      final x = r.range(-20, 0) - age * r.range(280, 380);
      final l = r.range(6, 16);
      final k = age / life;
      p.lineShaded(
        x,
        y,
        x + l,
        y,
        color: (u) => u > 0.7 ? c[6] : c[4],
        alpha: (u) => u * (1.0 - k) * 1.4,
      );
    });
    for (var i = 0; i < 3; i++) {
      final q = (ph * 3.0 + i / 3.0) % 1.0;
      final x = -4.0 - q * (len + 20.0);
      final ry = 4.5 + q * 8.0;
      final rx = 1.2 + q * 2.6;
      if (q > 0.8) continue;
      for (var k = 0; k < 40; k++) {
        final an = (k / 40.0) * tau;
        final px = x + math.cos(an) * rx;
        final py = math.sin(an) * ry;
        if (py.abs() < 4.6 && px > -len - 2.0) continue;
        final col = math.cos(an) > 0.0
            ? (q < 0.35 ? kWhite : c[6])
            : (q < 0.4 ? c[5] : c[4]);
        p.px(px, py, col);
      }
      p.glowRing(x, 0, ry * 0.75, 3, c[5], 0.14 * (1.0 - q));
    }
    for (final (dy, fl, fw) in const [(-1.0, 10.0, 4.0), (1.0, 9.0, 4.0), (-0.2, 6.0, 3.0)]) {
      blade(
        p,
        -len + 3.0,
        dy * 1.5,
        -len + 3.0 - fl,
        dy * (2.0 + fl * 0.5),
        fw,
        c,
      );
    }
    final pulse = -len + ((ph * 2.0) % 1.0) * (len + 6.0);
    final glint = -((ph * 2.0 + 0.5) % 1.0) * len * 1.2;
    _spear(p, c, len, pulse, glint);
    p.glowLine(-len, 0, 0, 0, 10, c[4], 0.1);
    p.glow(pulse, 0, 8, c[6], 0.3);
    p.glow(0, 0, 8, kWhite, 0.4);
    p.glow(-len * 0.4, 0, 30, c[3], 0.16);
  },
);
