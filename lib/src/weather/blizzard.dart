// Snow driven near-flat by the wind (depth layers of streaks, a gusty wind) after Sprite Fusion's open-source snow
// (https://www.spritefusion.com/pixel-art-vfx/snow), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'weather_lib.dart';

const double _d = 8.0;

double _gustAt(double x, double t) =>
    0.5 + 0.5 * math.sin(tau * ((x + 160.0) / 400.0 - (2.0 * t) / _d) + 0.8);

double _bank(double x) =>
    -2.0 + 1.2 * math.sin(x * 0.05 + 2.0) + 0.8 * math.sin(x * 0.15 + 1.0);

class _BlizzardLayer {
  final int n;
  final (int, int) m;
  final (double, double) len;
  final (double, double) drop;
  final List<int> col;
  final bool near;

  const _BlizzardLayer({
    required this.n,
    required this.m,
    required this.len,
    required this.drop,
    required this.col,
    this.near = false,
  });
}

const List<_BlizzardLayer> _layers = [
  _BlizzardLayer(
    n: 240,
    m: (3, 4),
    len: (2.0, 4.0),
    drop: (10.0, 40.0),
    col: [3, 4, 5],
  ),
  _BlizzardLayer(
    n: 130,
    m: (4, 5),
    len: (5.0, 8.0),
    drop: (20.0, 60.0),
    col: [4, 5, 6],
  ),
  _BlizzardLayer(
    n: 34,
    m: (6, 7),
    len: (10.0, 16.0),
    drop: (30.0, 70.0),
    col: [4, 6, 7],
    near: true,
  ),
];

final Float32List _gx = Float32List(320);
final Float32List _wv = Float32List(320);

void _streaks(
  ClippedWeatherPainter q,
  double t,
  int s,
  List<int> c,
  int layerIdx,
) {
  final ly = _layers[layerIdx];
  final sd = s * 17 + layerIdx;
  final c0 = c[ly.col[0]];
  final c1 = c[ly.col[1]];
  final c2 = c[ly.col[2]];
  trips(t, _d, ly.n, sd, ly.m.$1, ly.m.$2, (u, k, m, i) {
    final j = wrapInt(k, m);
    double r(int n) => rand(sd, i, j, n);
    final drop = ly.drop.$1 + r(3) * (ly.drop.$2 - ly.drop.$1);
    final x = -190.0 + 380.0 * u;
    final y = -178.0 +
        r(1) * 182.0 +
        drop * u +
        3.0 * math.sin(u * tau * (1.0 + r(5)) + r(6) * 6.0);
    if (y > _bank(x) - 1.0) return;
    final g = _gustAt(x, t);
    if (!ly.near && r(7) > 0.45 + 0.75 * g) return;
    final len = (ly.len.$1 + r(2) * (ly.len.$2 - ly.len.$1)) * (0.7 + 0.6 * g);
    final dx = 380.0 / (_d / m);
    final dy = drop / (_d / m);
    final l = math.sqrt(dx * dx + dy * dy);
    final ux = dx / l;
    final uy = dy / l;
    q.lineShaded(
      x - ux * len,
      y - uy * len,
      x - ux * len * 0.45,
      y - uy * len * 0.45,
      color: (_) => c0,
      alpha: (v) => 0.3 + 0.7 * v,
    );
    q.line(x - ux * len * 0.45, y - uy * len * 0.45, x - ux, y - uy, c1);
    q.px(x, y, g > 0.6 && ly.near ? kWhite : c2);
    if (ly.near) q.glow(x, y, 5, c[5], 0.12 + 0.12 * g);
  });
}

void _sheets(Painter p, double t, int s, List<int> c, bool near) {
  final f = noiseField(s * 3 + 7 + (near ? 1 : 0), 256, 128);
  final shift = (256.0 * (near ? 3.0 : 2.0) * t) / _d;
  final col = near ? c[6] : c[5];
  final y0 = near ? -110.0 : -170.0;
  final haze = mix(c[2], c[3], 0.5);
  final sy = near ? 4.5 : 3.2;
  final th = near ? 0.58 : 0.54;
  for (var i = 0; i < 320; i++) {
    _gx[i] = _gustAt(i - 160.0 + 0.5, t);
    _wv[i] = 5.0 *
        math.sin((i - 160.0) * 0.021 - (tau * t) / _d + (near ? 2.0 : 0.0));
  }
  rows(p, _blizzardMeta, y0, 4.0, (y, rBuf) {
    final fade = near ? smooth(-110.0, -40.0, y) : 1.0;
    for (var i = 0; i < 320; i++) {
      final g = _gx[i];
      final n = sampleField(f, (i - 160.0) * 0.16 - shift, (y + _wv[i]) * sy + 40.0);
      final d = (n - th) * 2.2 * (0.35 + g) * fade;
      if (near) {
        if (d <= 0.02) continue;
        rBuf.c[i] = col;
        rBuf.a[i] = math.min(0.5, d);
      } else {
        rBuf.c[i] = d > 0.08 ? col : haze;
        rBuf.a[i] = 0.3 + 0.12 * g + math.min(0.42, math.max(0.0, d));
      }
      rBuf.b[i] = 1;
      if (d > 0.05) {
        rBuf.l[i] = c[5];
        rBuf.k[i] = d * 0.08;
      }
    }
  });
}

void _ground(
  Painter p,
  ClippedWeatherPainter q,
  double t,
  int s,
  List<int> c,
) {
  final f = noiseField(s * 5 + 1, 256, 128);
  final shift = (256.0 * 4.0 * t) / _d;
  for (var i = 0; i < 320; i++) {
    _gx[i] = _gustAt(i - 160.0 + 0.5, t);
    _wv[i] = _bank(i - 160.0 + 0.5);
  }
  rows(p, _blizzardMeta, -16.0, 9.0, (y, rBuf) {
    for (var i = 0; i < 320; i++) {
      final x = i - 160.0 + 0.5;
      final top = _wv[i];
      final d = y - top;
      if (d >= 0.0) {
        rBuf.c[i] = d < 1.0
            ? kWhite
            : (d < 2.0 ? c[6] : (d < 4.0 ? c[5] : c[4]));
        if (d < 1.0) {
          rBuf.l[i] = c[6];
          rBuf.k[i] = 0.1;
        }
        continue;
      }
      if (y < -14.0) continue;
      final n = sampleField(f, x * 0.5 - shift, y * 3.0 + 9.0);
      final sp = (n - 0.5) * 3.0 * smooth(-14.0, -1.0, y) * (0.4 + _gx[i]);
      if (sp > 0.02) {
        rBuf.c[i] = c[6];
        rBuf.a[i] = math.min(0.55, sp);
        rBuf.b[i] = 1;
      }
    }
  });
  trips(t, _d, 40, s * 23, 8, 10, (u, k, m, i) {
    final j = wrapInt(k, m);
    final x = -175.0 + 350.0 * u;
    final y = _bank(x) -
        1.0 -
        rand(s, i, j, 1) * 6.0 * math.sin(u * 9.0 + i).abs();
    q.px(x, y, rand(s, i, j, 2) < 0.5 ? kWhite : c[6]);
    q.px(x - 1.0, y, c[5]);
  });
}

const EffectMeta _blizzardMeta = EffectMeta(
  id: 'weather/blizzard',
  name: 'Blizzard',
  desc:
      'Snow driven almost flat by a gale: streaks at three depths race past, gusts throw translucent sheets of snow across the sky and spindrift streams off the drifts.',
  category: 'weather',
  tags: [
    'weather',
    'blizzard',
    'snow',
    'wind',
    'storm',
    'winter',
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
      '#0d111f',
      '#182035',
      '#27324d',
      '#3e4d6e',
      '#64779c',
      '#9cb0d0',
      '#d8e4f6',
      '#ffffff',
    ],
    'seed': 9,
  },
);

final PureEffect blizzardEffect = PureEffect(
  meta: _blizzardMeta,
  onDrawBack: (p, t, o) {
    final q = clip(p, _blizzardMeta);
    final s = o.seed;
    final c = fit(o.palette, 8);
    _sheets(p, t, s, c, false);
    _streaks(q, t, s, c, 0);
    _streaks(q, t, s, c, 1);
    _ground(p, q, t, s, c);
  },
  onDraw: (p, t, o) {
    final q = clip(p, _blizzardMeta);
    final s = o.seed;
    final c = fit(o.palette, 8);
    _sheets(p, t, s, c, true);
    _streaks(q, t, s, c, 2);
  },
);
