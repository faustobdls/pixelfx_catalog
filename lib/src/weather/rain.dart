// The rain recipe (depth layers of two-tone streaks, far drops that end in the air, near ones that splash and
// throw droplets, mist low on the ground) is adapted from Sprite Fusion's open-source rain
// (https://www.spritefusion.com/pixel-art-vfx/rain), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'weather_lib.dart';

const double _d = 8.0;
const double _slant = -0.2;
final double _lenNorm = math.sqrt(_slant * _slant + 1.0);
final double _ux = _slant / _lenNorm;
final double _uy = 1.0 / _lenNorm;

class _RainLayer {
  final int n;
  final (int, int) m;
  final int len;
  final List<int> col;
  final (double, double)? stop;
  final (double, double)? z;
  final (double, double)? size;
  final bool near;

  const _RainLayer({
    required this.n,
    required this.m,
    required this.len,
    required this.col,
    this.stop,
    this.z,
    this.size,
    this.near = false,
  });
}

const List<_RainLayer> _layers = [
  _RainLayer(n: 200, m: (10, 13), len: 2, col: [2, 2, 3], stop: (-80.0, -6.0)),
  _RainLayer(n: 150, m: (14, 17), len: 4, col: [2, 3, 4], stop: (-45.0, -2.0)),
  _RainLayer(
    n: 96,
    m: (19, 23),
    len: 7,
    col: [3, 4, 5],
    z: (0.0, 1.4),
    size: (0.15, 0.4),
  ),
  _RainLayer(
    n: 42,
    m: (25, 29),
    len: 13,
    col: [3, 5, 7],
    z: (2.0, 6.5),
    size: (0.6, 1.0),
    near: true,
  ),
];

class _Puddle {
  final double x0;
  final double x1;
  final int y;

  const _Puddle(this.x0, this.x1, this.y);
}

List<_Puddle> _pools(int s) => List<_Puddle>.generate(5, (i) {
      final x = -150.0 + i * 66.0 + rand(s, i, 61) * 30.0;
      final w = 16.0 + rand(s, i, 63) * 26.0;
      return _Puddle(x, x + w, 3 + (rand(s, i, 62) * 3.0).floor());
    });

_Puddle? _poolAt(List<_Puddle> puddles, double x, double y) {
  for (final p in puddles) {
    if (x >= p.x0 + 2.0 && x <= p.x1 - 2.0 && (y - p.y).abs() < 1.5) return p;
  }
  return null;
}

void _rings(Painter q, double x, _Puddle pool, double age, List<int> c) {
  final xi = x.round();
  final y = pool.y;
  if (age < 0.05) q.px(xi, y, c[7]);
  for (var r = 0; r < 2; r++) {
    final a = age - r * 0.16;
    final u = a / 0.5;
    if (u <= 0.0 || u >= 1.0) continue;
    final w = (1.0 + 7.0 * math.sqrt(u)).round();
    final col = (u < 0.4 && r == 0) ? c[6] : c[5];
    final dEnd = u < 0.6 ? 2 : 1;
    for (final s in const [-1, 1]) {
      for (var d = 0; d < dEnd; d++) {
        final px = xi + s * (w - d);
        if (px > pool.x0 && px < pool.x1) q.px(px, y, col);
      }
    }
  }
}

void _layer(
  ClippedWeatherPainter q,
  double t,
  int s,
  List<int> c,
  List<_Puddle> puddles,
  int layerIdx,
  double density,
) {
  final ly = _layers[layerIdx];
  final sd = s * 11 + layerIdx;
  final c0 = c[ly.col[0]];
  final c1 = c[ly.col[1]];
  final c2 = c[ly.col[2]];
  final len = ly.len;
  final n = (ly.n * density).round();
  final gField = noiseField(s + 21, 256, 128, const [4, 8, 16]);
  final sweep = (256.0 * t) / _d;

  trips(t, _d, n, sd, ly.m.$1, ly.m.$2, (u, k, m, i) {
    final j = wrapInt(k, m);
    if (layerIdx < 2 &&
        rand(sd, i, j, 7) >
            0.35 +
                1.3 *
                    (sampleField(
                          gField,
                          (-166.0 + rand(sd, i, j, 2) * 332.0) * 0.8 + sweep,
                          9.0 + layerIdx * 40.0,
                        ) -
                        0.32)) {
      return;
    }
    final end = ly.z != null
        ? ly.z!.$1 + rand(sd, i, j, 1) * (ly.z!.$2 - ly.z!.$1)
        : ly.stop!.$1 + rand(sd, i, j, 1) * (ly.stop!.$2 - ly.stop!.$1);
    final y0 = -172.0 - len;
    final y = y0 + (end - y0) * u;
    final x = -166.0 + rand(sd, i, j, 2) * 332.0 - (end - y) * _slant;
    final a = ly.z != null ? 1.0 : math.min(1.0, (1.0 - u) * 5.0);
    if (len <= 2) {
      q.dot(x, y, c2, a);
      q.dot(x - _ux, y - _uy, c1, a * 0.8);
    } else {
      q.lineShaded(
        x - _ux * len,
        y - _uy * len,
        x - _ux * len * 0.45,
        y - _uy * len * 0.45,
        color: (_) => c0,
        alpha: (v) => a * (0.35 + 0.65 * v),
      );
      q.line(x - _ux * len * 0.45, y - _uy * len * 0.45, x - _ux, y - _uy, c1, a);
      q.dot(x, y, c2, a);
    }
    if (ly.near) q.glow(x, y - 2.0, 4, c[5], 0.12);
    if (ly.z == null) return;
    final dur = _d / m;
    for (var back = 1; back < 4; back++) {
      final age = u * dur + (back - 1) * dur;
      if (age > 0.7) break;
      final jp = wrapInt(k - back, m);
      final z = ly.z!.$1 + rand(sd, i, jp, 1) * (ly.z!.$2 - ly.z!.$1);
      final xp = -166.0 + rand(sd, i, jp, 2) * 332.0;
      if (rand(sd, i, jp, 5) > (ly.near ? 1.0 : 0.7)) continue;
      final size = ly.size!.$1 +
          ((z - ly.z!.$1) / (ly.z!.$2 - ly.z!.$1)) * (ly.size!.$2 - ly.size!.$1);
      final pool = ly.near ? _poolAt(puddles, xp, z) : null;
      if (pool != null) {
        _rings(q, xp, pool, age, c);
      } else if (crown(
            q,
            xp,
            z,
            age,
            size,
            (hot: c[6], cool: c[4], white: kWhite),
            rand(sd, i, jp, 4),
          ) &&
          ly.near &&
          age < 0.1) {
        q.glow(xp, z - 1.0, 5, c[5], 0.3 * (1.0 - age / 0.1));
      }
    }
  });
}

void _floor(
  ClippedWeatherPainter q,
  EffectMeta meta,
  double t,
  List<int> c,
  List<_Puddle> puddles,
) {
  pass(q, meta, 0.0, 9.5, (x, y, out) {
    if (y < 1.0) {
      out.c = c[4];
      out.l = c[5];
      out.k = 0.08;
      return;
    }
    if (y < 2.0) {
      out.c = c[1];
      return;
    }
    out.c = c[0];
    out.a = 0.55;
    out.b = true;
    final fy = y.floor();
    for (final p in puddles) {
      if (x >= p.x0 && x < p.x1 && fy == p.y) {
        final edge = x < p.x0 + 2.0 || x >= p.x1 - 2.0;
        out.c = edge ? c[3] : c[4];
        out.a = 1.0;
        out.b = false;
        out.l = c[5];
        out.k = 0.06;
      }
    }
  });
  for (var i = 0; i < puddles.length; i++) {
    final p = puddles[i];
    final gx = (p.x0 +
            3.0 +
            (p.x1 - p.x0 - 6.0) *
                (0.5 + 0.5 * math.sin((math.pi * 2.0 * t) / _d + i * 1.9)))
        .round();
    q.px(gx, p.y, c[6]);
    q.glow(gx, p.y, 4, c[5], 0.2);
  }
}

void _mist(Painter p, EffectMeta meta, double t, int s, List<int> c) {
  final mField = noiseField(s + 9, 256, 128, const [4, 8, 16, 32]);
  final drift = (256.0 * t) / _d;
  final crest = mix(c[4], c[5], 0.5);
  double dens(double x, double y) {
    final prof = smooth(-22.0, -4.0, y) * (1.0 - smooth(7.0, 10.0, y));
    return prof *
        (0.62 + (sampleField(mField, x * 0.45 + drift, y * 4.0 + 30.0) - 0.5) * 2.0);
  }

  pass(p, meta, -20.0, 9.0, (x, y, out) {
    final d = dens(x, y);
    if (d < 0.28) return;
    final th = bayer(x, y) * 0.06;
    out.b = true;
    if (d > 0.46 + th && dens(x, y - 1.0) < 0.43) {
      out.c = crest;
      out.a = 0.5;
    } else {
      out.c = d > 0.58 + th ? c[4] : c[3];
      out.a = clamp((d - 0.28) * 1.6) * 0.5;
    }
    out.l = c[4];
    out.k = (d - 0.3) * 0.1;
  });
}

const EffectMeta _rainMeta = EffectMeta(
  id: 'weather/rain',
  name: 'Rain',
  desc:
      'Slanted rain at four depths: far drops fade into the dark, near ones glint and splash, drops ring the puddles and a low mist drifts over the wet floor.',
  category: 'weather',
  tags: ['weather', 'rain', 'storm', 'water', 'ambient', 'loop'],
  size: (320, 180),
  origin: (160, 170),
  duration: _d,
  loop: true,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': [
      '#0e1322',
      '#1a2440',
      '#283a5e',
      '#3a5482',
      '#5674a8',
      '#84a6d6',
      '#c0dcf8',
      '#f2f8ff',
    ],
    'density': 1.0,
    'seed': 4,
  },
);

final PureEffect rainEffect = PureEffect(
  meta: _rainMeta,
  onDrawBack: (p, tRaw, o) {
    final t = (tRaw * 3e4).round() / 3e4;
    final q = clip(p, _rainMeta);
    final s = o.seed;
    final c = fit(o.palette, 8);
    final puddles = _pools(s);
    final density = o.numOpt('density', 1.0);
    final haze = mix(c[0], c[1], 0.6);
    pass(p, _rainMeta, -170.0, -0.5, (x, y, out) {
      out.c = haze;
      out.a = 0.3 + 0.26 * smooth(-170.0, 0.0, y);
      out.b = true;
    });
    _floor(q, _rainMeta, t, c, puddles);
    for (var l = 0; l < 3; l++) {
      _layer(q, t, s, c, puddles, l, density);
    }
    _mist(p, _rainMeta, t, s, c);
  },
  onDraw: (p, tRaw, o) {
    final t = (tRaw * 3e4).round() / 3e4;
    final q = clip(p, _rainMeta);
    final s = o.seed;
    final c = fit(o.palette, 8);
    final puddles = _pools(s);
    _layer(q, t, s, c, puddles, 3, o.numOpt('density', 1.0));
  },
);
