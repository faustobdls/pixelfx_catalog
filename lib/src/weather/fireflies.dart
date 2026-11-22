// The firefly (a wandering point that glows up and fades on its own rhythm, close ones drawn with a dark body,
// beating wings and a lantern that throws a big soft light, grass blades swaying underneath) is adapted from
// Sprite Fusion's open-source fireflies (https://www.spritefusion.com/pixel-art-vfx/fireflies), MIT License,
// Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'weather_lib.dart';

const double _d = 12.0;

double _cyc(double t, int n, [double ph = 0.0]) => (tau * n * t) / _d + ph;

class _Firefly {
  final (double, double) Function(double tt) pos;
  final int depth;
  final double glow;

  const _Firefly({
    required this.pos,
    required this.depth,
    required this.glow,
  });
}

_Firefly _fly(int s, int i, double t) {
  double r(int n) => rand(s, i, n);
  final depth = i < 14 ? 0 : (i < 26 ? 1 : 2);
  final k = const [0.5, 0.8, 1.0][depth];
  final cx = -150.0 + r(1) * 300.0;
  final cy = -16.0 - r(2) * (depth == 2 ? 70.0 : 130.0);
  final ax = (14.0 + r(3) * 26.0) * k;
  final ay = (8.0 + r(4) * 14.0) * k;
  final n1 = 1 + (r(5) * 2.0).floor();
  final n2 = 1 + (r(6) * 3.0).floor();
  final ph1 = r(7) * tau;
  final ph2 = r(8) * tau;
  (double, double) pos(double tt) => (
        cx +
            ax * math.sin(_cyc(tt, n1, ph1)) +
            10.0 * k * loopNoise(tt / _d, 1.5, i * 3),
        cy +
            ay * math.sin(_cyc(tt, n2, ph2)) +
            6.0 * k * loopNoise(tt / _d, 1.5, i * 3 + 1),
      );
  final per = _d / (3 + (r(9) * 4.0).floor());
  final u = wrap(t / per + r(10), 1.0);
  final two = r(11) < 0.35;
  double pulse(double v) {
    if (v < 0.06) return v / 0.06;
    if (v < 0.14) return 1.0;
    if (v < 0.4) return 1.0 - (v - 0.14) / 0.26;
    return 0.0;
  }

  final p1 = u >= 0.0 ? pulse(u) : 0.0;
  final p2 = two && u - 0.22 >= 0.0 ? pulse(u - 0.22) * 0.8 : 0.0;
  return _Firefly(pos: pos, depth: depth, glow: math.max(p1, p2));
}

void _drawFirefly(
  ClippedWeatherPainter q,
  double t,
  _Firefly f,
  List<int> c,
) {
  final (x, y) = f.pos(t);
  final g = f.glow;
  final xi = (x + 0.5).floor();
  final yi = (y + 0.5).floor();
  if (f.depth == 0) {
    if (g < 0.08) return;
    q.dot(xi, yi, g > 0.6 ? c[4] : c[3], math.min(1.0, g * 1.6));
    q.glow(x, y, 6, c[2], 0.45 * g);
    return;
  }
  if (g > 0.3) {
    for (var j = 1; j <= 4; j++) {
      final (tx, ty) = f.pos(t - j * 0.05);
      q.dot(tx, ty, c[2], (g - 0.3) * (1.0 - j / 5.0) * 1.3);
    }
  }
  if (f.depth == 1) {
    q.px(xi, yi, g > 0.5 ? c[5] : (g > 0.15 ? c[3] : c[1]));
    if (g > 0.4) q.px(xi, yi + 1, c[2]);
    q.glow(x, y, 9, c[2], 0.5 * g);
    q.glow(x, y, 3, c[4], 0.5 * g);
    return;
  }
  final (nx, _) = f.pos(t + 0.05);
  final dir = nx >= x ? 1 : -1;
  final beat = (t * 30.0).floor() % 2;
  q.px(xi + dir, yi, c[0]);
  q.px(xi + dir * 2, yi, c[0]);
  final wingCol = mix(c[1], kWhite, 0.4);
  q.dot(xi, yi - 1 - beat, wingCol, 0.7);
  q.dot(xi + dir, yi - 1 - beat, wingCol, 0.7);
  q.px(xi, yi, g > 0.3 ? c[5] : c[1]);
  q.px(xi - dir, yi, g > 0.5 ? c[4] : (g > 0.15 ? c[3] : c[1]));
  if (g > 0.6) q.px(xi - dir, yi + 1, c[3]);
  if (g > 0.7) {
    for (final (dx, dy) in const [(0, -2), (0, 2), (-2, 0), (2, 0)]) {
      q.dot(xi - dir + dx, yi + dy, c[3], (g - 0.7) * 3.0);
    }
  }
  q.glow(x, y, 28, c[2], 0.45 * g);
  q.glow(x, y, 10, c[4], 0.5 * g);
  q.glow(x, y, 4, c[5], 0.5 * g);
}

void _grass(
  ClippedWeatherPainter q,
  double t,
  int s,
  List<int> gPal,
  List<int> c,
  List<_Firefly> flies,
  bool front,
) {
  final lit = <(double, double, double)>[];
  for (final f in flies) {
    if (f.glow > 0.25 && f.depth > 0) {
      final (fx, fy) = f.pos(t);
      lit.add((fx, fy, f.glow));
    }
  }
  final n = front ? 150 : 230;
  for (var i = 0; i < n; i++) {
    double r(int k) => rand(s * 3 + (front ? 1 : 0), i, k);
    final x = -162.0 + (i + r(1)) * (324.0 / n);
    final h = (front ? 4.0 : 5.0) +
        r(2) * (front ? 8.0 : 11.0) +
        (r(3) < 0.1 ? 6.0 : 0.0);
    final base = (front ? 9.0 : 2.0) - r(4) * 3.0;
    final sway = (1.2 + r(5)) * math.sin(_cyc(t, 2, -x * 0.03) + r(6)) +
        0.6 * math.sin(_cyc(t, 5, x * 0.07));
    final tone = front ? 1 + (r(7) * 3.0).floor() : 1 + (r(7) * 2.0).floor();
    var tipLight = 0.0;
    for (final (fx, fy, g) in lit) {
      final d = math.sqrt(
        (fx - (x + sway)) * (fx - (x + sway)) +
            (fy - (base - h)) * (fy - (base - h)),
      );
      if (d < 28.0) tipLight = math.max(tipLight, g * (1.0 - d / 28.0));
    }
    for (var row = 0; row < h; row++) {
      final u = row / h;
      final col = u > 0.8 && tipLight > 0.2
          ? (tipLight > 0.55 && u > 0.9 ? c[3] : c[2])
          : (u > 0.7 ? gPal[math.min(5, tone + 1)] : gPal[tone]);
      q.px(x + sway * u * u, base - row, col);
    }
    if (r(8) < 0.07) {
      final sx = x + sway;
      final sy = base - h;
      q.px(sx, sy - 1.0, tipLight > 0.2 ? c[3] : gPal[5]);
      q.px(sx - 1.0, sy, gPal[4]);
      q.px(sx + 1.0, sy, gPal[4]);
    }
  }
}

const List<String> _defaultGrass = [
  '#070f0b',
  '#0c1a12',
  '#13281a',
  '#1d3a24',
  '#2b5232',
  '#3f6e40',
];

const EffectMeta _firefliesMeta = EffectMeta(
  id: 'weather/fireflies',
  name: 'Fireflies',
  desc:
      'Fireflies wander over a meadow at night, each glowing up and fading on its own rhythm, trailing light and lighting the grass tips beneath them.',
  category: 'weather',
  tags: [
    'weather',
    'fireflies',
    'night',
    'glow',
    'meadow',
    'nature',
    'ambient',
    'loop',
  ],
  size: (320, 180),
  origin: (160, 170),
  duration: _d,
  loop: true,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': [
      '#2a3a10',
      '#5a7a1a',
      '#9ad02a',
      '#d6ff5a',
      '#f4ffb8',
      '#ffffff',
    ],
    'grass': _defaultGrass,
    'seed': 2,
  },
);

final PureEffect firefliesEffect = PureEffect(
  meta: _firefliesMeta,
  onDrawBack: (p, t, o) {
    final q = clip(p, _firefliesMeta);
    final s = o.seed;
    final c = fit(o.palette, 6);
    final gPal = fit((o['grass'] as List<Object>?) ?? _defaultGrass, 6);
    rows(p, _firefliesMeta, -170.0, 9.0, (y, rBuf) {
      final k = (y + 170.0) / 180.0;
      rBuf.c.fillRange(0, rBuf.w, mix(gPal[0], gPal[1], k));
      rBuf.a.fillRange(0, rBuf.w, 0.48 + 0.14 * k);
      rBuf.b.fillRange(0, rBuf.w, 1);
    });
    final flies = List<_Firefly>.generate(32, (i) => _fly(s, i, t));
    _grass(q, t, s, gPal, c, flies, false);
    for (final f in flies) {
      if (f.depth < 2) _drawFirefly(q, t, f, c);
    }
  },
  onDraw: (p, t, o) {
    final q = clip(p, _firefliesMeta);
    final s = o.seed;
    final c = fit(o.palette, 6);
    final gPal = fit((o['grass'] as List<Object>?) ?? _defaultGrass, 6);
    final flies = List<_Firefly>.generate(32, (i) => _fly(s, i, t));
    _grass(q, t, s, gPal, c, flies, true);
    for (final f in flies) {
      if (f.depth == 2) _drawFirefly(q, t, f, c);
    }
  },
);
