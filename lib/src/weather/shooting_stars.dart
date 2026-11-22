// The glints (a cross of rays with a white heart and soft light, little twinkling stars around it) are adapted from
// Sprite Fusion's open-source sparkle (https://www.spritefusion.com/pixel-art-vfx/sparkle), MIT License,
// Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'weather_lib.dart';

const double _d = 10.0;
const double _train = 1.6;

class _MeteorSpec {
  final double t0;
  final double x;
  final double y;
  final double a;
  final double v;
  final double life;
  final double s;
  final bool flare;

  const _MeteorSpec({
    required this.t0,
    required this.x,
    required this.y,
    required this.a,
    required this.v,
    required this.life,
    required this.s,
    this.flare = false,
  });
}

const List<_MeteorSpec> _meteors = [
  _MeteorSpec(t0: 0.5, x: 60, y: -170, a: 2.45, v: 260, life: 0.55, s: 0.6),
  _MeteorSpec(t0: 1.9, x: -40, y: -176, a: 2.2, v: 220, life: 0.7, s: 0.8),
  _MeteorSpec(t0: 3.4, x: 150, y: -150, a: 2.62, v: 300, life: 0.45, s: 0.5),
  _MeteorSpec(
    t0: 4.6,
    x: 130,
    y: -178,
    a: 2.35,
    v: 240,
    life: 1.05,
    s: 1.4,
    flare: true,
  ),
  _MeteorSpec(t0: 6.7, x: -90, y: -168, a: 2.05, v: 200, life: 0.6, s: 0.7),
  _MeteorSpec(t0: 7.9, x: 20, y: -160, a: 2.5, v: 280, life: 0.5, s: 0.6),
  _MeteorSpec(
    t0: 9.2,
    x: -10,
    y: -176,
    a: 2.28,
    v: 230,
    life: 0.8,
    s: 1.0,
    flare: true,
  ),
];

void _sky(
  Painter p,
  ClippedWeatherPainter q,
  double t,
  int s,
  List<int> skyPal,
) {
  rows(p, _shootingStarsMeta, -180.0, -1.0, (y, rBuf) {
    final fy = y.floor();
    for (var i = 0; i < 320; i++) {
      final x = i - 160.0 + 0.5;
      final d = ((y + 110.0) - (x * -0.32)).abs() / 36.0;
      if (d >= 1.0) continue;
      final k = (1.0 - d) * (1.0 - d);
      rBuf.l[i] = skyPal[2];
      rBuf.k[i] = 0.1 * k;
      if (rand(i, fy, s, 5) < 0.05 * k) {
        rBuf.c[i] = skyPal[2];
        rBuf.a[i] = 0.7;
      }
    }
  });
  for (var i = 0; i < 130; i++) {
    final x = -160.0 + rand(s, i, 1) * 320.0;
    final y = -180.0 + rand(s, i, 2) * 178.0;
    final r = rand(s, i, 3);
    final c = 1 + (rand(s, i, 4) * 4.0).floor();
    final tw = 0.5 + 0.5 * math.sin((tau * c * t) / _d + rand(s, i, 5) * tau);
    if (r < 0.6) {
      q.dot(x, y, skyPal[3], 0.35 + 0.5 * tw);
    } else if (r < 0.94) {
      q.px(x, y, r < 0.8 ? skyPal[4] : kWhite);
      q.glow(x + 0.5, y + 0.5, 3, skyPal[3], 0.22 * tw);
    } else {
      sparkle(
        q,
        x,
        y,
        (1 + (tw * 2.0 + 0.5).floor()).toDouble(),
        skyPal[4],
        skyPal[3],
        0.3 * tw,
      );
    }
  }
}

void _meteor(
  ClippedWeatherPainter q,
  double age,
  _MeteorSpec m,
  int i,
  int s,
  List<int> c,
) {
  final ca = math.cos(m.a);
  final sa = math.sin(m.a);
  final end = m.life + (m.flare ? 0.5 : 0.0) + _train;
  if (age > end) return;
  (double, double) pos(double tt) => (m.x + ca * m.v * tt, m.y + sa * m.v * tt);
  final burn = math.min(age, m.life);
  final (hx, hy) = pos(burn);
  final trainK = age < m.life
      ? 1.0
      : 1.0 - (age - m.life) / (_train + (m.flare ? 0.5 : 0.0));
  if (trainK > 0.0) {
    final len = m.v * burn;
    final nx = -sa;
    final ny = ca;
    for (var d = 0; d < len; d += 1) {
      final passed = age - d / m.v;
      if (passed < 0.08) continue;
      final g = trainK *
          math.min(1.0, (passed - 0.08) * 4.0) *
          (0.35 + 0.65 * math.sin((math.pi * d) / len)) *
          m.s;
      final tw =
          math.sin(d * 0.09 + passed * 1.7) * math.min(4.0, passed * 3.0);
      final x = m.x + ca * d + nx * tw + passed * 4.0;
      final y = m.y + sa * d + ny * tw;
      q.dot(x, y, passed < 0.6 ? c[2] : c[1], g * 0.75);
      if (d % 6 == 0) q.glow(x, y, 6.0 + passed * 4.0, c[1], 0.12 * g);
    }
  }
  if (age > m.life + (m.flare ? 0.5 : 0.0)) return;
  final u = age / m.life;
  final k = age < m.life
      ? math.min(1.0, u * 6.0) * (u > 0.75 ? 1.0 - (u - 0.75) / 0.25 : 1.0)
      : 0.0;
  if (k > 0.0) {
    final l = (24.0 + 40.0 * m.s) * math.min(1.0, u * 3.0);
    final trailRamp = c.sublist(1).reversed.toList();
    for (var d = 0.0; d <= l; d += 0.5) {
      final v = d / l;
      final x = hx - ca * d;
      final y = hy - sa * d;
      q.dot(
        x,
        y,
        v < 0.08 ? kWhite : at(trailRamp, v * 0.95),
        k * (v < 0.6 ? 1.0 : (1.0 - v) / 0.4),
      );
      if (m.s > 0.9 && v < 0.4) {
        q.dot(
          x - sa * 0.9,
          y + ca * 0.9,
          v < 0.15 ? c[4] : c[3],
          k * (1.0 - v / 0.4),
        );
      }
    }
    q.px(hx, hy, kWhite);
    if (m.s > 0.9) {
      q.px(hx + 1.0, hy, kWhite);
      q.px(hx, hy + 1.0, c[4]);
    }
    q.glow(hx, hy, 8.0 + 10.0 * m.s, c[4], 0.45 * k);
    q.glow(hx - ca * l * 0.3, hy - sa * l * 0.3, 10.0 + 8.0 * m.s, c[3], 0.2 * k);
  }
  if (!m.flare || age < m.life * 0.82) return;
  final f = (age - m.life * 0.82) / (m.life * 0.18 + 0.5);
  final (fx, fy) = pos(m.life * 0.86);
  if (f < 0.35) {
    sparkle(q, fx, fy, 9.0 * math.sin((math.pi * f) / 0.35) + 2.0, c[4], c[3], 0.6);
    q.glow(fx, fy, 40, c[3], 0.5 * (1.0 - f / 0.35));
  }
  for (var j = 0; j < 7; j++) {
    final ang = rand(s, i, j, 5) * tau;
    final rad = 5.0 + rand(s, i, j, 6) * 16.0;
    final d0 = rand(s, i, j, 7) * 0.3;
    final g = (f - d0) / 0.45;
    if (g <= 0.0 || g >= 1.0) continue;
    final sx = fx + math.cos(ang) * rad * (0.6 + g * 0.5);
    final sy = fy + math.sin(ang) * rad * (0.6 + g * 0.5) - g * 3.0;
    final arm = (2.5 * math.sin(math.pi * g) + 0.5).floor();
    if (arm >= 1) {
      sparkle(
        q,
        sx,
        sy,
        arm.toDouble(),
        j % 3 != 0 ? c[4] : kWhite,
        c[3],
        0.3 * (1.0 - g),
      );
    } else {
      q.px(sx, sy, c[4]);
    }
  }
  for (var j = 0; j < 4; j++) {
    final da = (rand(s, i, j, 1) - 0.5) * 0.5;
    final sp = m.v * (0.5 + rand(s, i, j, 2) * 0.4);
    final tt = f * (m.life * 0.18 + 0.5);
    final g = 1.0 - f;
    final x = fx + math.cos(m.a + da) * sp * tt;
    final y = fy + math.sin(m.a + da) * sp * tt;
    if (g <= 0.0) continue;
    q.line(
      x - math.cos(m.a + da) * 5.0 * g,
      y - math.sin(m.a + da) * 5.0 * g,
      x,
      y,
      c[3],
      g,
    );
    q.px(x, y, g > 0.5 ? kWhite : c[4]);
    q.glow(x, y, 5, c[3], 0.35 * g);
  }
}

const List<String> _defaultSky = [
  '#141428',
  '#2a2a4a',
  '#4c4c7c',
  '#8e8ec4',
  '#dcdcff',
];

const EffectMeta _shootingStarsMeta = EffectMeta(
  id: 'weather/shooting-stars',
  name: 'Shooting stars',
  desc:
      'Meteors burn across a starry sky, white heads trailing gold and rose; the big ones flare and break up, and each leaves a glowing train that twists and fades.',
  category: 'weather',
  tags: [
    'weather',
    'meteor',
    'shooting star',
    'night',
    'sky',
    'stars',
    'ambient',
    'loop',
  ],
  size: (320, 180),
  origin: (160, 180),
  duration: _d,
  loop: true,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': [
      '#3a1e5a',
      '#7a3a8a',
      '#e0607a',
      '#ffa86a',
      '#ffe6a8',
      '#ffffff',
    ],
    'sky': _defaultSky,
    'seed': 4,
  },
);

final PureEffect shootingStarsEffect = PureEffect(
  meta: _shootingStarsMeta,
  onDraw: (p, t, o) {
    final q = clip(p, _shootingStarsMeta);
    final s = o.seed;
    final c = fit(o.palette, 6);
    final skyPal = fit((o['sky'] as List<Object>?) ?? _defaultSky, 5);
    _sky(p, q, t, s, skyPal);
    for (var i = 0; i < _meteors.length; i++) {
      final m = _meteors[i];
      _meteor(q, wrap(t - m.t0, _d), m, i, s, c);
    }
  },
);
