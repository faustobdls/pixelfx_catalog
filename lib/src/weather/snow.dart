// The snow recipe (depth layers falling at their own speeds with a sway, a gusty wind, flakes that settle on a
// drift for a while) is adapted from Sprite Fusion's open-source snow (https://www.spritefusion.com/pixel-art-vfx/snow),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'weather_lib.dart';

const double _d = 12.0;

double _bank(double x) =>
    -3.0 +
    1.6 * math.sin(x * 0.045 + 1.3) +
    1.1 * math.sin(x * 0.12 + 0.4) +
    0.6 * math.sin(x * 0.31 + 2.0);

double _gust(double t) =>
    10.0 * math.sin((tau * t) / _d + 0.6) +
    4.0 * math.sin((tau * 2.0 * t) / _d + 2.1);

class _SnowLayer {
  final int n;
  final (int, int) m;
  final double air;
  final (double, double) sway;
  final double wind;
  final double gust;

  const _SnowLayer({
    required this.n,
    required this.m,
    required this.air,
    required this.sway,
    required this.wind,
    required this.gust,
  });
}

const List<_SnowLayer> _layers = [
  _SnowLayer(n: 230, m: (1, 2), air: 1.0, sway: (1.0, 3.0), wind: 3.0, gust: 0.4),
  _SnowLayer(n: 140, m: (2, 3), air: 0.8, sway: (3.0, 7.0), wind: 6.0, gust: 0.7),
  _SnowLayer(n: 24, m: (2, 3), air: 0.74, sway: (8.0, 15.0), wind: 9.0, gust: 1.0),
];

const List<(int, int)> _axis = [(1, 0), (-1, 0), (0, 1), (0, -1)];
const List<(int, int)> _diag = [(1, 1), (-1, -1), (1, -1), (-1, 1)];

void _snowCrystal(
  ClippedWeatherPainter q,
  double x,
  double y,
  int r,
  int turn,
  List<int> c,
) {
  final xi = (x + 0.5).floor();
  final yi = (y + 0.5).floor();
  final turnB = turn != 0;
  final longDirs = turnB ? _diag : _axis;
  final shortDirs = turnB ? _axis : _diag;
  final rad = turnB ? r - 1 : r;
  for (final (dx, dy) in longDirs) {
    for (var d = 1; d <= rad; d++) {
      q.px(xi + dx * d, yi + dy * d, d == rad ? kWhite : c[6]);
    }
    final nubs = turnB
        ? (rad >= 3 ? [rad - 1] : const <int>[])
        : (rad >= 5
            ? [rad - 1, rad - 2]
            : (rad >= 4 ? [rad - 1] : const <int>[]));
    for (final n in nubs) {
      final ox = turnB ? dx : dy;
      final oy = turnB ? -dy : -dx;
      q.px(xi + dx * n + (turnB ? 0 : ox), yi + dy * n + oy, c[4]);
      q.px(
        xi + dx * n + (turnB ? -dx : -ox) + (turnB ? dx : 0),
        yi + dy * n + (turnB ? 0 : -oy),
        c[4],
      );
    }
  }
  final shortLim = turnB ? 1 : math.max(1, (rad / 2).floor());
  for (final (dx, dy) in shortDirs) {
    for (var d = 1; d <= shortLim; d++) {
      q.px(xi + dx * d, yi + dy * d, d == 1 ? c[6] : c[5]);
    }
  }
  q.px(xi, yi, kWhite);
  q.glow(xi + 0.5, yi + 0.5, r * 2.5 + 5.0, c[5], 0.13);
  q.light(xi, yi, c[6], 0.4);
}

void _layer(ClippedWeatherPainter q, double t, int s, List<int> c, int layerIdx) {
  final ly = _layers[layerIdx];
  final sd = s * 13 + layerIdx;
  trips(t, _d, ly.n, sd, ly.m.$1, ly.m.$2, (u, k, m, i) {
    final j = wrapInt(k, m);
    final dur = _d / m;
    double r(int n) => rand(sd, i, j, n);
    final tf = dur * ly.air;
    final age = math.min(u * dur, tf);
    final sw = ly.sway.$1 + r(3) * (ly.sway.$2 - ly.sway.$1);
    final f = 0.25 + r(4) * 0.35;
    final ph = r(5) * tau;
    final xBase = -175.0 + r(2) * 350.0;
    final born = t - u * dur;
    double xAt(double a) =>
        xBase +
        ly.wind * a +
        (_gust(born + a) - _gust(born)) * ly.gust +
        sw * math.sin(tau * f * a + ph);
    final x = xAt(age);
    final xl = xAt(tf);
    const y0 = -176.0;
    final y1 = layerIdx != 0 ? _bank(xl) - 0.5 : -110.0 + r(1) * 106.0;
    final y = y0 + (y1 - y0) * (age / tf);
    final rest = u * dur - tf;
    if (layerIdx == 0) {
      final a = math.min(1.0, (1.0 - u) * 6.0);
      q.dot(x, y, r(6) < 0.5 ? c[4] : c[5], a);
      return;
    }
    final fade = rest > 0.0 ? 1.0 - rest / (dur - tf) : 1.0;
    if (layerIdx == 1) {
      final big = r(6) < 0.3;
      if (rest > 0.0) {
        q.dot(xl, y1, c[7], fade * 0.9);
        return;
      }
      q.px(x, y, big ? kWhite : c[7]);
      if (big) {
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          q.px(x + dx, y + dy, c[5]);
        }
      } else {
        q.px(x + 1.0, y, c[6]);
        q.px(x, y + 1.0, c[6]);
        q.px(x + 1.0, y + 1.0, c[5]);
      }
      return;
    }
    final rad = r(6) < 0.4 ? 3 : (r(6) < 0.8 ? 4 : 5);
    final spin = 1.5 + r(7) * 2.5;
    if (rest > 0.0) {
      q.dot(xl - 1.0, y1, c[6], fade);
      q.dot(xl, y1, kWhite, fade);
      q.dot(xl + 1.0, y1, c[6], fade);
      q.glow(xl, y1, 5, c[5], 0.25 * fade);
      return;
    }
    _snowCrystal(q, x, y, rad, (age * spin + r(8) * 2.0).floor() % 2, c);
  });
}

void _drift(ClippedWeatherPainter q, double t, int s, List<int> c) {
  pass(q, _snowMeta, -7.0, 9.0, (x, y, out) {
    final top = _bank(x);
    final d = y - top;
    if (d < 0.0) return;
    out.c = d < 1.0
        ? kWhite
        : (d < 2.0
            ? c[7]
            : (d < 3.5 ? c[6] : (d < 6.0 ? c[5] : c[4])));
    if (d < 1.0) {
      out.l = c[6];
      out.k = 0.12;
    }
  });
  for (var i = 0; i < 18; i++) {
    final x = -156.0 + rand(s, i, 81) * 312.0;
    final cMul = 1 + (rand(s, i, 82) * 3.0).floor();
    final tw = math.sin((tau * cMul * t) / _d + rand(s, i, 83) * tau);
    if (tw < 0.55) continue;
    final y = _bank(x).ceil() + (rand(s, i, 84) * 3.0).floor();
    final k = (tw - 0.55) / 0.45;
    q.px(x, y, kWhite);
    if (k > 0.5) {
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, -1)]) {
        q.px(x + dx, y + dy, c[6]);
      }
    }
    q.glow(x + 0.5, y + 0.5, 6, c[6], 0.35 * k);
  }
}

const EffectMeta _snowMeta = EffectMeta(
  id: 'weather/snow',
  name: 'Snow',
  desc:
      'Snow at three depths in a gusty breeze: far specks, drifting flakes, big near crystals that spin and glow; they settle on a sparkling drift and melt away.',
  category: 'weather',
  tags: ['weather', 'snow', 'winter', 'cold', 'ambient', 'loop'],
  size: (320, 180),
  origin: (160, 170),
  duration: _d,
  loop: true,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': [
      '#0c1020',
      '#161d36',
      '#24304f',
      '#3a4a72',
      '#5f74a3',
      '#93abd6',
      '#cfe0fa',
      '#ffffff',
    ],
    'seed': 6,
  },
);

final PureEffect snowEffect = PureEffect(
  meta: _snowMeta,
  onDrawBack: (p, t, o) {
    final q = clip(p, _snowMeta);
    final s = o.seed;
    final c = fit(o.palette, 8);
    final haze = mix(c[1], c[2], 0.4);
    pass(p, _snowMeta, -170.0, 9.0, (x, y, out) {
      out.c = haze;
      out.a = 0.26 + 0.22 * smooth(-170.0, 0.0, y);
      out.b = true;
    });
    _layer(q, t, s, c, 0);
    _drift(q, t, s, c);
    _layer(q, t, s, c, 1);
  },
  onDraw: (p, t, o) {
    final q = clip(p, _snowMeta);
    final s = o.seed;
    final c = fit(o.palette, 8);
    _layer(q, t, s, c, 2);
  },
);
