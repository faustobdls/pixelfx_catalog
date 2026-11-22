// Things that flutter down (a fall timed to land as their time in the air runs out, a flip by squashing across,
// a rest on the ground and a fade) after Sprite Fusion's open-source falling leaves
// (https://www.spritefusion.com/pixel-art-vfx/falling-leaves), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'weather_lib.dart';

const double _d = 10.0;
const double _floor = 1.0;

double _gust(double t) =>
    22.0 * math.sin((tau * t) / _d + 0.4) +
    7.0 * math.sin((tau * 2.0 * t) / _d - 1.0);

final Map<String, List<(double, double, int, double)>> _scatterCache = {};

void _petal(
  ClippedWeatherPainter? q,
  double x,
  double y,
  double len,
  double ang,
  double flip,
  List<int> c,
  double a, [
  List<(double, double, int, double)>? baked,
]) {
  final fs = 0.3 + 0.7 * flip.abs();
  final back = flip < -0.2;
  final cs = math.cos(ang);
  final sn = math.sin(ang);
  final e = len + 1.0;
  final face = back ? [c[1], c[2], c[3]] : [c[2], c[3], c[4]];
  final tip = back ? c[3] : c[5];

  int? eval(double px, double py) {
    final dx = px - x;
    final dy = py - y;
    final u = (dx * cs + dy * sn) / len;
    final v = (-dx * sn + dy * cs) / (len * fs);
    if (u < -1.0 || u > 1.0) return null;
    final hw = 0.55 * math.sqrt(1.0 - u * u) * (1.0 + 0.35 * u);
    if (v.abs() > hw || (u > 0.7 && v.abs() < 0.12)) return null;
    if (u > 0.45 && v < 0.1) return tip;
    if (u < -0.45) return face[0];
    return v < 0.0 ? face[2] : face[1];
  }

  if (baked != null) {
    for (var py = (y - e).floor(); py <= (y + e).ceil(); py++) {
      for (var px = (x - e).floor(); px <= (x + e).ceil(); px++) {
        final col = eval(px + 0.5, py + 0.5);
        if (col != null) baked.add((px + 0.5, py + 0.5, col, a));
      }
    }
    return;
  }

  q!.shade(x - e, y - e, x + e, y + e, (px, py, out) {
    final col = eval(px, py);
    if (col == null) return null;
    out.c = col;
    out.a = a;
    return null;
  });
}

void _petals(
  ClippedWeatherPainter q,
  double t,
  int s,
  List<int> c,
  bool near,
) {
  final n = near ? 54 : 90;
  final sd = s * 7 + (near ? 1 : 0);
  trips(t, _d, n, sd, 1, 2, (u, k, m, i) {
    final j = wrapInt(k, m);
    double r(int idx) => rand(sd, i, j, idx);
    final dur = _d / m;
    final tf = dur * 0.84;
    final a = math.min(u * dur, tf);
    final rest = u * dur - tf;
    final born = t - u * dur;
    final x0 = -200.0 + r(1) * 330.0;
    const y0 = -184.0;
    final vy = (_floor + (near ? 2.0 : 0.0) - y0) / tf;
    final vx = 9.0 + r(2) * 10.0;
    final rho = (near ? 3.0 : 2.0) + r(3) * 3.0;
    final w = 2.2 + r(4) * 2.8;
    final ph = r(5) * tau;
    final gk = near ? 1.0 : 0.6;
    (double, double) at(double aa) => (
          x0 +
              vx * aa +
              (_gust(born + aa) - _gust(born)) * gk +
              rho * math.cos(w * aa + ph),
          y0 + vy * aa + rho * 0.6 * math.sin(w * aa + ph),
        );
    final len = (near ? 3.6 : 2.6) + r(6) * 1.1;
    if (rest > 0.0) {
      final (x, y) = at(tf);
      final fade = 1.0 - rest / (dur - tf);
      if (fade > 0.15) {
        _petal(
          q,
          x,
          y,
          len * (0.35 + 0.65 * fade),
          (r(7) - 0.5) * 1.2,
          0.5,
          c,
          1.0,
        );
      }
      return;
    }
    final (x, y) = at(a);
    final flip = math.cos(r(8) * tau + a * (3.0 + r(9) * 5.0));
    final ang = r(10) * tau + a * (r(11) - 0.5) * 3.0;
    _petal(q, x, y, len, ang, flip, c, 1.0);
    if (flip > 0.9) {
      final g = (flip - 0.9) / 0.1;
      q.px(x, y - 1.0, kWhite);
      q.glow(x, y, near ? 7 : 5, c[4], (near ? 0.32 : 0.22) * g);
    }
  });
}

void _blossoms(ClippedWeatherPainter q, double t, int s, List<int> c) {
  final heart = hex('#ffe08a');
  trips(t, _d, 7, s * 31, 1, 1, (u, k, m, i) {
    double r(int idx) => rand(s * 31, i, idx);
    final y = -190.0 + (_floor + 2.0 + 190.0) * math.min(1.0, u / 0.9);
    final born = t - u * _d;
    if (u > 0.9) return;
    final x = -190.0 +
        r(1) * 330.0 +
        14.0 * u * _d * 0.1 +
        (_gust(t) - _gust(born)) +
        6.0 * math.sin(u * tau * 2.0 + r(2) * 6.0);
    final rot = r(3) * tau + u * _d * (r(4) - 0.5) * 2.0;
    final rad = 3.6 + r(5) * 1.2;
    for (var p = 0; p < 5; p++) {
      final an = rot + (p * tau) / 5.0;
      _petal(
        q,
        x + math.cos(an) * rad * 0.75,
        y + math.sin(an) * rad * 0.75,
        rad * 0.7,
        an,
        1.0,
        c,
        1.0,
      );
    }
    q.px(x, y, heart);
    q.glow(x, y, 8, c[4], 0.2);
  });
}

void _scatter(ClippedWeatherPainter q, int s, List<int> c) {
  final key = '$s|${c.join(',')}';
  var px = _scatterCache[key];
  if (px == null) {
    px = <(double, double, int, double)>[];
    for (var i = 0; i < 46; i++) {
      _petal(
        null,
        -164.0 + rand(s, i, 71) * 328.0,
        _floor + (rand(s, i, 72) * 3.0).floor() * 2.0,
        2.6 + rand(s, i, 73),
        (rand(s, i, 74) - 0.5) * 1.2,
        0.5,
        c,
        1.0,
        px,
      );
    }
    _scatterCache[key] = px;
  }
  for (final (x, y, col, a) in px) {
    q.dot(x, y, col, a);
  }
}

const EffectMeta _cherryBlossomsMeta = EffectMeta(
  id: 'weather/cherry-blossoms',
  name: 'Cherry blossoms',
  desc:
      'Pink petals flutter down on a spring breeze, tumbling in little spirals and flashing as they catch the light, with a few whole blossoms spinning among them.',
  category: 'weather',
  tags: [
    'weather',
    'cherry blossom',
    'sakura',
    'petals',
    'spring',
    'wind',
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
      '#4a1832',
      '#8e3460',
      '#d26a94',
      '#f2a2c0',
      '#ffd2e2',
      '#fff4f8',
    ],
    'seed': 12,
  },
);

final PureEffect cherryBlossomsEffect = PureEffect(
  meta: _cherryBlossomsMeta,
  onDrawBack: (p, t, o) {
    final q = clip(p, _cherryBlossomsMeta);
    final s = o.seed;
    final c = fit(o.palette, 6);
    final top = hex('#0e0a14');
    final low = mix(hex('#1a0e1a'), c[0], 0.4);
    rows(p, _cherryBlossomsMeta, -170.0, 9.0, (y, rBuf) {
      final k = (y + 170.0) / 180.0;
      rBuf.c.fillRange(0, rBuf.w, mix(top, low, k * k));
      rBuf.a.fillRange(0, rBuf.w, 0.3 + 0.12 * k);
      rBuf.b.fillRange(0, rBuf.w, 1);
    });
    _scatter(q, s, c);
    _petals(q, t, s, c, false);
  },
  onDraw: (p, t, o) {
    final q = clip(p, _cherryBlossomsMeta);
    final s = o.seed;
    final c = fit(o.palette, 6);
    _petals(q, t, s, c, true);
    _blossoms(q, t, s, c);
  },
);
