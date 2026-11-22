// The banded light (posterized steps from a hot core to the edges, fine strands through it, light laid over the top)
// is adapted from Sprite Fusion's open-source holy light (https://www.spritefusion.com/pixel-art-vfx/holy-light),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'weather_lib.dart';

const double _d = 10.0;
const int _w = 320;
const double _sx = -230.0;
const double _sy = -300.0;

final double _ax = math.cos(0.94);
final double _ay = math.sin(0.94);
final double _nx = -_ay;
final double _ny = _ax;

class _ShaftSpec {
  final double c;
  final double h;
  final double k;
  final int b;
  final double sw;

  const _ShaftSpec({
    required this.c,
    required this.h,
    required this.k,
    required this.b,
    required this.sw,
  });
}

const List<_ShaftSpec> _shaftSpecs = [
  _ShaftSpec(c: -0.27, h: 0.03, k: 0.65, b: 1, sw: 0.006),
  _ShaftSpec(c: -0.17, h: 0.022, k: 0.55, b: 2, sw: 0.005),
  _ShaftSpec(c: -0.07, h: 0.05, k: 1.0, b: 1, sw: 0.008),
  _ShaftSpec(c: 0.03, h: 0.018, k: 0.6, b: 3, sw: 0.004),
  _ShaftSpec(c: 0.12, h: 0.042, k: 0.85, b: 2, sw: 0.007),
  _ShaftSpec(c: 0.23, h: 0.026, k: 0.6, b: 1, sw: 0.005),
];

final Float32List _str = Float32List(512);

class _ShaftState {
  final double c;
  final double h;
  final double k;

  const _ShaftState(this.c, this.h, this.k);
}

List<_ShaftState> _shafts(double t, int s) {
  for (var i = 0; i < 512; i++) {
    final a = i / 512.0;
    _str[i] = 0.5 +
        0.5 *
            math.sin(a * 190.0 + math.sin((tau * t) / _d) * 2.0 + s) *
            math.sin(a * 77.0 - (tau * t) / _d + s * 2.0);
  }
  return List<_ShaftState>.generate(_shaftSpecs.length, (i) {
    final sp = _shaftSpecs[i];
    return _ShaftState(
      sp.c + sp.sw * math.sin((tau * t) / _d + i * 1.3),
      sp.h * (1.0 + 0.15 * math.sin((tau * sp.b * t) / _d + i)),
      sp.k * (0.72 + 0.28 * math.sin((tau * sp.b * t) / _d + i * 2.1)),
    );
  });
}

double _lightAt(double x, double y, List<_ShaftState> sh) {
  final dx = x - _sx;
  final dy = y - _sy;
  final r = dx * _ax + dy * _ay;
  final ang = (dx * _nx + dy * _ny) / r;
  var e = 0.0;
  for (final s in sh) {
    final q = (ang - s.c).abs() / s.h;
    if (q < 1.0) e += s.k * math.pow(1.0 - q * q, 1.5);
  }
  if (e <= 0.0) return 0.0;
  final strand = _str[clampInt(((ang + 0.36) * 700.0).floor(), 0, 511)];
  final fall = clamp(1.25 - (r - 230.0) / 420.0);
  return e * fall * (0.7 + 0.45 * strand);
}

void _motes(
  ClippedWeatherPainter q,
  double t,
  int s,
  List<int> c,
  List<_ShaftState> sh,
  bool front,
) {
  final start = front ? 0 : 50;
  final end = front ? 50 : 160;
  for (var i = start; i < end; i++) {
    double r(int k) => rand(s, i, k);
    final n1 = 1 + (r(1) * 2.0).floor();
    final n2 = 1 + (r(2) * 2.0).floor();
    final x = -170.0 +
        r(3) * 340.0 +
        (8.0 + r(4) * 14.0) * math.sin((tau * n1 * t) / _d + r(5) * tau);
    final y = -170.0 +
        r(6) * 172.0 +
        (6.0 + r(7) * 10.0) * math.sin((tau * n2 * t) / _d + r(8) * tau) +
        4.0 * math.sin((tau * 3.0 * t) / _d + i);
    final e = _lightAt(x, y, sh);
    if (e < 0.12) continue;
    final big = front && r(9) < 0.5;
    final k = math.min(1.0, e);
    q.px(x, y, k > 0.6 ? kWhite : (k > 0.3 ? c[5] : c[4]));
    if (big && k > 0.5) {
      q.px(x + 1.0, y, c[4]);
      q.px(x, y + 1.0, c[4]);
    }
    q.glow(x, y, big ? 6 : 4, c[4], 0.4 * k);
  }
}

const EffectMeta _godRaysMeta = EffectMeta(
  id: 'weather/god-rays',
  name: 'God rays',
  desc:
      'Shafts of light slant down from high on the left, breathing and swaying, pooling on the floor, as drifting dust motes light up whenever they cross a beam.',
  category: 'weather',
  tags: ['weather', 'god rays', 'light', 'sunbeam', 'dust', 'ambient', 'loop'],
  size: (320, 180),
  origin: (160, 170),
  duration: _d,
  loop: true,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': [
      '#1a1208',
      '#3a2810',
      '#7a5a24',
      '#c89a44',
      '#f2d27a',
      '#fff2c4',
      '#ffffff',
    ],
    'seed': 3,
  },
);

final PureEffect godRaysEffect = PureEffect(
  meta: _godRaysMeta,
  onDrawBack: (p, t, o) {
    final q = clip(p, _godRaysMeta);
    final s = o.seed;
    final c = fit(o.palette, 7);
    final sh = _shafts(t, s);
    final lPal = List<int>.generate(7, (i) => mix(c[0], c[i], 0.75));
    final n = sh.length;
    final sc = Float32List(n);
    final si = Float32List(n);
    final sk = Float32List(n);
    for (var j = 0; j < n; j++) {
      sc[j] = sh[j].c;
      si[j] = 1.0 / sh[j].h;
      sk[j] = sh[j].k;
    }
    rows(p, _godRaysMeta, -170.0, 9.0, (y, rBuf) {
      final floor = y > 0.0;
      final dy = y - _sy;
      final air = floor ? 0.8 : 0.66;
      final boost = floor ? 1.6 : 1.0;
      var r = (-160.0 + 0.5 - _sx) * _ax + dy * _ay;
      var nn = (-160.0 + 0.5 - _sx) * _nx + dy * _ny;
      rBuf.a.fillRange(0, _w, air);
      rBuf.b.fillRange(0, _w, 1);
      rBuf.c.fillRange(0, _w, c[0]);
      for (var i = 0; i < _w; i++, r += _ax, nn += _nx) {
        final ang = nn / r;
        var e = 0.0;
        for (var j = 0; j < n; j++) {
          final q2 = (ang - sc[j]) * si[j];
          if (q2 > -1.0 && q2 < 1.0) {
            final w = 1.0 - q2 * q2;
            e += sk[j] * w * math.sqrt(w);
          }
        }
        if (e <= 0.0) continue;
        final fall = 1.35 - (r - 200.0) / 330.0;
        final strandIdx = ((ang + 0.36) * 700.0).toInt();
        final clampedIdx = strandIdx < 0 ? 0 : (strandIdx > 511 ? 511 : strandIdx);
        final clampedFall = fall > 1.0 ? 1.0 : (fall < 0.0 ? 0.0 : fall);
        e *= clampedFall * (0.7 + 0.45 * _str[clampedIdx]) * boost;
        if (e < 0.06) continue;
        final lv = e > 1.05
            ? 6
            : (e > 0.78 ? 5 : (e > 0.52 ? 4 : (e > 0.3 ? 3 : 2)));
        rBuf.c[i] = floor ? c[lv] : lPal[lv];
        rBuf.a[i] = floor ? 0.85 : math.min(0.78, 0.12 + e * 0.5);
        rBuf.l[i] = c[4];
        rBuf.k[i] = e * (floor ? 0.32 : 0.26);
      }
    });
    q.glow(-168, -178, 130, c[3], 0.3);
    q.glow(-168, -178, 50, c[5], 0.35);
    _motes(q, t, s, c, sh, false);
  },
  onDraw: (p, t, o) {
    final q = clip(p, _godRaysMeta);
    final s = o.seed;
    final c = fit(o.palette, 7);
    _motes(q, t, s, c, _shafts(t, s), true);
  },
);
