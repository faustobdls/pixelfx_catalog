// The falling leaf (a pendulum swing that speeds through the bottom of each arc, a tilt that follows it, a flip
// by squashing across, a rest on the ground, a litter of fallen leaves) is adapted from Sprite Fusion's
// open-source falling leaves (https://www.spritefusion.com/pixel-art-vfx/falling-leaves), MIT License,
// Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'weather_lib.dart';

const double _d = 10.0;
const double _floor = 1.0;

double _gust(double t) =>
    16.0 * math.sin((tau * t) / _d - 1.2) +
    5.0 * math.sin((tau * 3.0 * t) / _d);

double _hc(double th) {
  final k = ((th + math.pi / 2.0) / math.pi).floor();
  return 2.0 * k + 1.0 + math.sin(th - k * math.pi);
}

double _shapeDist(int shape, double u, double v) {
  switch (shape) {
    case 0:
      return u.abs() >= 1.0
          ? 9.0
          : (v * v) / (0.36 * (1.0 - u * u) * (1.15 - 0.3 * u));
    case 1:
      final r = math.sqrt(u * u + (v * 1.1) * (v * 1.1));
      final a = math.atan2(v, u);
      return r / (0.62 + 0.38 * math.pow(math.cos(2.5 * a).abs(), 1.5));
    default:
      return u.abs() >= 1.0 ? 9.0 : (v * v) / (0.16 * (1.0 - u * u));
  }
}

final Map<String, List<(double, double, int, double)>> _litterCache = {};

void _leaf(
  ClippedWeatherPainter? q,
  double x,
  double y,
  double size,
  double ang,
  double flip,
  int shape,
  List<int> col,
  double a, [
  List<(double, double, int, double)>? baked,
]) {
  final back = flip < -0.25;
  final fs = 0.35 + 0.65 * flip.abs();
  final cs = math.cos(ang);
  final sn = math.sin(ang);
  final l = size;
  final wd = size * 0.9;
  final ext = l + 1.5;
  final face = back
      ? [
          mix(col[1], hex('#9c8a78'), 0.2),
          mix(col[2], hex('#c8b49c'), 0.22),
          mix(col[3], hex('#e0d0b8'), 0.22),
        ]
      : [col[2], col[3], col[4]];
  final rim = col[0];
  final vein = back ? mix(col[2], hex('#e8dcc8'), 0.5) : col[1];

  int? eval(double px, double py) {
    final dx = px - x;
    final dy = py - y;
    final lu = (dx * cs + dy * sn) / l;
    final lv = (-dx * sn + dy * cs) / (wd * fs);
    final d = _shapeDist(shape, lu, lv);
    if (lu < -1.25 || lu > 1.1) return null;
    if (lu < -0.92 && (lv * wd * fs).abs() < 0.5) return rim;
    if (d > 1.32) return null;
    if (d > 1.0) return rim;
    if ((lv * wd * fs).abs() < 0.45 && lu > -0.9 && lu < 0.75) return vein;
    return lv < -0.15 ? face[2] : (lv < 0.35 ? face[1] : face[0]);
  }

  if (baked != null) {
    for (var py = (y - ext).floor(); py <= (y + ext).ceil(); py++) {
      for (var px = (x - ext).floor(); px <= (x + ext).ceil(); px++) {
        final c = eval(px + 0.5, py + 0.5);
        if (c != null) baked.add((px + 0.5, py + 0.5, c, a));
      }
    }
    return;
  }

  q!.shade(x - ext, y - ext, x + ext, y + ext, (px, py, out) {
    final c = eval(px, py);
    if (c == null) return null;
    out.c = c;
    out.a = a;
    return null;
  });
}

void _leaves(
  ClippedWeatherPainter q,
  double t,
  int s,
  List<List<int>> r3,
  bool front,
) {
  trips(t, _d, 62, s * 19, 2, 3, (u, k, m, i) {
    final j = wrapInt(k, m);
    double r(int n) => rand(s * 19, i, j, n);
    final near = r(1) < 0.35;
    if (near != front) return;
    final dur = _d / m;
    const air = 0.72;
    final tf = dur * air;
    final a = math.min(u * dur, tf);
    final rest = u * dur - tf;
    final w = 1.7 + r(2) * 1.2;
    final ph0 = r(3) * tau;
    final amp = (near ? 14.0 : 8.0) + r(4) * 10.0;
    final x0 = -180.0 + r(5) * 340.0;
    const y0 = -186.0;
    double path(double aa) =>
        0.45 * aa + (0.9 * (_hc(w * aa + ph0) - _hc(ph0))) / w;
    final vy = (_floor - y0) / path(tf);
    final born = t - u * dur;
    double xAt(double aa) =>
        x0 +
        7.0 * aa +
        math.sin(w * aa + ph0) * amp +
        (_gust(born + aa) - _gust(born)) * (near ? 1.0 : 0.7);
    final size = (near ? 5.8 : 4.2) + r(6) * 1.6;
    final shape = (r(7) * 3.0).floor();
    final col = r3[(r(8) * 3.0).floor()];
    if (rest > 0.0) {
      final fade = 1.0 - rest / (dur - tf);
      _leaf(
        q,
        xAt(tf),
        _floor - 1.0,
        size,
        (r(9) - 0.5) * 0.5,
        0.42,
        shape,
        col,
        fade,
      );
      return;
    }
    final x = xAt(a);
    final y = y0 + vy * path(a);
    final tilt = math.cos(w * a + ph0) * 0.75 + (near ? 0.0 : 0.3);
    final flip = math.cos(r(10) * tau + a * (r(11) < 0.3 ? 5.0 : 1.2));
    _leaf(q, x, y, size, tilt, flip, shape, col, 1.0);
    if (flip > 0.86) {
      final kGlow = (flip - 0.86) / 0.14;
      final hx = x - math.cos(tilt) * size * 0.3;
      final hy = y - math.sin(tilt) * size * 0.3 - 1.0;
      q.px(hx, hy, col[5]);
      q.glow(hx, hy, 5.0 + size * 0.5, col[4], 0.22 * kGlow);
    }
  });
}

void _litter(ClippedWeatherPainter q, int s, List<List<int>> r3) {
  final key = '$s|${r3.expand((e) => e).join(',')}';
  var px = _litterCache[key];
  if (px == null) {
    px = <(double, double, int, double)>[];
    for (var i = 0; i < 64; i++) {
      final x = -164.0 + rand(s, i, 91) * 328.0;
      final y = _floor - 2.0 + (rand(s, i, 92) * 4.0).floor() * 2.0;
      final col = r3[(rand(s, i, 93) * 3.0).floor()];
      _leaf(
        null,
        x,
        y,
        3.6 + rand(s, i, 94) * 1.8,
        (rand(s, i, 95) - 0.5) * 0.7,
        0.45 + rand(s, i, 96) * 0.25,
        (rand(s, i, 97) * 3.0).floor(),
        col.map((c) => mix(c, col[0], 0.12)).toList(),
        1.0,
        px,
      );
    }
    _litterCache[key] = px;
  }
  for (final (x, y, c, a) in px) {
    q.dot(x, y, c, a);
  }
}

const List<String> _defaultReds = [
  '#40101a',
  '#7c1c22',
  '#b8302a',
  '#e85a3c',
  '#ff9a72',
  '#ffd8c4',
];

const List<String> _defaultGolds = [
  '#3e300c',
  '#7a5c14',
  '#b8901e',
  '#e8c23a',
  '#fff09a',
  '#fffbe0',
];

List<List<int>> _ramps(Map<String, Object?> o) => [
      fit(o.palette, 6),
      fit((o['reds'] as List<Object>?) ?? _defaultReds, 6),
      fit((o['golds'] as List<Object>?) ?? _defaultGolds, 6),
    ];

const EffectMeta _fallingLeavesMeta = EffectMeta(
  id: 'weather/falling-leaves',
  name: 'Falling leaves',
  desc:
      'Autumn leaves swing down through the air, tilting and flipping to show their pale backs, ride a gust, land flat in the litter and fade.',
  category: 'weather',
  tags: [
    'weather',
    'leaves',
    'autumn',
    'fall',
    'wind',
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
      '#4a1d0c',
      '#8a3a14',
      '#c8621e',
      '#f0982e',
      '#ffcf72',
      '#fff0c4',
    ],
    'reds': _defaultReds,
    'golds': _defaultGolds,
    'seed': 8,
  },
);

final PureEffect fallingLeavesEffect = PureEffect(
  meta: _fallingLeavesMeta,
  onDrawBack: (p, t, o) {
    final q = clip(p, _fallingLeavesMeta);
    final s = o.seed;
    final r3 = _ramps(o);
    final c = r3[0];
    final top = hex('#0e0a12');
    final low = mix(hex('#140c14'), c[0], 0.3);
    rows(p, _fallingLeavesMeta, -170.0, 9.0, (y, rBuf) {
      final k = (y + 170.0) / 180.0;
      final col = mix(top, low, k * k);
      rBuf.c.fillRange(0, rBuf.w, col);
      rBuf.a.fillRange(0, rBuf.w, 0.32 + 0.1 * k);
      rBuf.b.fillRange(0, rBuf.w, 1);
    });
    _litter(q, s, r3);
    _leaves(q, t, s, r3, false);
  },
  onDraw: (p, t, o) {
    _leaves(clip(p, _fallingLeavesMeta), t, o.seed, _ramps(o), true);
  },
);
