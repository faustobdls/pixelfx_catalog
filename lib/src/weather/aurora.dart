// The banded light (posterized steps from a white-hot core out to deep color, fine strands running through it,
// pulses travelling along, light laid over the top) is adapted from Sprite Fusion's open-source holy light
// (https://www.spritefusion.com/pixel-art-vfx/holy-light), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'weather_lib.dart';

const double _d = 12.0;
const int _w = 320;
const int _h = 180;

const List<double> _bay = [
  0.5 / 16, 8.5 / 16, 2.5 / 16, 10.5 / 16,
  12.5 / 16, 4.5 / 16, 14.5 / 16, 6.5 / 16,
  3.5 / 16, 11.5 / 16, 1.5 / 16, 9.5 / 16,
  15.5 / 16, 7.5 / 16, 13.5 / 16, 5.5 / 16,
];

final Float32List _intensity = Float32List(_w * _h);
final Float32List _hv = Float32List(_w * _h);
final Float32List _blurBuf = Float32List(_w * _h);
final Float32List _tmpBuf = Float32List(_w * _h);

final Float32List _prof = Float32List.fromList(
  List<double>.generate(201, (i) {
    final v = i / 200.0;
    if (v < 0.035) return 2.6;
    if (v < 0.22) return 1.15 - v;
    return math.pow(1.0 - v, 1.5) * 0.9;
  }),
);

void _blur(Float32List src, Float32List dst, int r) {
  final n = 2 * r + 1;
  for (var y = 0; y < _h; y++) {
    var acc = 0.0;
    final o = y * _w;
    for (var x = -r; x < _w + r; x++) {
      if (x + r < _w) acc += src[o + math.min(_w - 1, x + r)];
      if (x - r - 1 >= 0) acc -= src[o + x - r - 1];
      if (x >= 0 && x < _w) _tmpBuf[o + x] = acc / n;
    }
  }
  for (var x = 0; x < _w; x++) {
    var acc = 0.0;
    for (var y = -r; y < _h + r; y++) {
      if (y + r < _h) acc += _tmpBuf[math.min(_h - 1, y + r) * _w + x];
      if (y - r - 1 >= 0) acc -= _tmpBuf[(y - r - 1) * _w + x];
      if (y >= 0 && y < _h) dst[y * _w + x] = acc / n;
    }
  }
}

double _cyc(double t, num c, [double ph = 0.0]) => (tau * c * t) / _d + ph;

class _CurtainSpec {
  final double y;
  final double slope;
  final double amp;
  final double lam;
  final double fold;
  final double flam;
  final double height;
  final double k;
  final double s0;
  final double s1;
  final double rip;
  final List<int> c;
  final double hue;

  const _CurtainSpec({
    required this.y,
    required this.slope,
    required this.amp,
    required this.lam,
    required this.fold,
    required this.flam,
    required this.height,
    required this.k,
    required this.s0,
    required this.s1,
    required this.rip,
    required this.c,
    required this.hue,
  });
}

const List<_CurtainSpec> _curtains = [
  _CurtainSpec(
    y: -132,
    slope: -0.08,
    amp: 8,
    lam: 210,
    fold: 14,
    flam: 150,
    height: 40,
    k: 0.6,
    s0: -210,
    s1: 210,
    rip: 1.6,
    c: [1, 1, 2],
    hue: 0.35,
  ),
  _CurtainSpec(
    y: -88,
    slope: 0.22,
    amp: 13,
    lam: 250,
    fold: 19,
    flam: 165,
    height: 82,
    k: 1.5,
    s0: -195,
    s1: 180,
    rip: 2.4,
    c: [1, 2, 3],
    hue: 0,
  ),
  _CurtainSpec(
    y: -38,
    slope: -0.05,
    amp: 5,
    lam: 150,
    fold: 10,
    flam: 110,
    height: 20,
    k: 0.45,
    s0: -210,
    s1: 210,
    rip: 1.4,
    c: [2, 1, 3],
    hue: 0,
  ),
];

class _RayPeak {
  final double x;
  final double hem;
  final double h;
  final double k;

  const _RayPeak(this.x, this.hem, this.h, this.k);
}

void _curtain(
  _CurtainSpec c,
  int n,
  double t,
  NoiseField f,
  double breath,
  List<_RayPeak> rays,
) {
  const x0 = -160.0;
  const y0 = -180.0;
  final fast = (256.0 * 2.0 * t) / _d;
  final slow = (256.0 * t) / _d;
  var p1 = 0.0;
  var p2 = 0.0;
  var lastX = -999.0;
  for (var s = c.s0; s < c.s1; s += 0.5) {
    final x = s +
        c.fold * math.sin((tau * s) / c.flam + _cyc(t, c.c[0], n * 2.0)) +
        5.0 * math.sin((tau * s) / 64.0 + _cyc(t, c.c[2], n.toDouble()));
    if (x < x0 - 2.0 || x >= x0 + _w + 1.0) continue;
    final hem = c.y +
        c.slope * s +
        c.amp * math.sin((tau * s) / c.lam + _cyc(t, c.c[1], n * 1.7)) +
        c.rip * math.sin((tau * s) / 23.0 - _cyc(t, 7, n.toDouble()));
    final env =
        smooth(c.s0, c.s0 + 60.0, s) * (1.0 - smooth(c.s1 - 70.0, c.s1, s));
    final r1 = clamp(
      (sampleField(f, s * 5.0 - fast + n * 40.0, 10.0 + n * 30.0) - 0.38) * 3.2,
    );
    final r2 = clamp(
      (sampleField(f, s * 4.3 + fast * 0.7 + n * 90.0, 50.0 + n * 13.0) -
              0.35) *
          3.0,
    );
    final patch = sampleField(f, s * 0.7 + slow + n * 17.0, 80.0 + n * 9.0);
    final k = c.k *
        env *
        breath *
        (0.2 + 0.8 * r1) *
        (0.3 + 1.4 * math.max(0.0, patch - 0.3));
    if (k < 0.01) continue;
    final h = c.height * (0.45 + 0.75 * r2) * (0.75 + 0.5 * patch);
    final xi = (x - x0).floor();
    final fr = x - x0 - xi;
    if (p1 > 0.75 &&
        p1 >= p2 &&
        p1 >= r1 &&
        (x - lastX).abs() > 2.0 &&
        k > 0.25) {
      rays.add(_RayPeak(x, hem - 1.0, h * 0.9, math.min(0.85, k * 0.9)));
      lastX = x;
    }
    p2 = p1;
    p1 = r1;
    if (xi < -1 || xi >= _w) continue;
    final top = math.max(0, (hem - h - y0).floor());
    final bot = math.min(_h - 1, (hem - y0).floor() + 3);
    final inv = 1.0 / h;
    final k0 = k * 0.5 * (1.0 - fr);
    final k1 = k * 0.5 * fr;
    var v = (hem - y0 - 0.5 - top) * inv;
    for (var yi = top; yi <= bot; yi++, v -= inv) {
      final pr = v >= 0.0
          ? _prof[math.min(200, (v * 200.0).toInt())]
          : math.max(0.0, 0.45 + v * h * 0.16);
      if (pr <= 0.0) continue;
      final o = yi * _w + xi;
      final hv = (v + c.hue) < 0.0
          ? 0.0
          : ((v + c.hue) > 1.0 ? 1.0 : v + c.hue);
      if (xi >= 0) {
        _intensity[o] += k0 * pr;
        _hv[o] += k0 * pr * hv;
      }
      if (xi + 1 < _w) {
        _intensity[o + 1] += k1 * pr;
        _hv[o + 1] += k1 * pr * hv;
      }
    }
  }
}

void _stars(Painter q, double t, int s, List<int> uPal) {
  for (var i = 0; i < 150; i++) {
    final x = -160.0 + rand(s, i, 1) * 320.0;
    final y = -180.0 + rand(s, i, 2) * 175.0;
    final r = rand(s, i, 3);
    final c = 1 + (rand(s, i, 4) * 4.0).floor();
    final tw = 0.5 + 0.5 * math.sin(_cyc(t, c, rand(s, i, 5) * tau));
    final col = r < 0.6
        ? mix(uPal[3], kWhite, 0.2)
        : (r < 0.9 ? mix(uPal[5], kWhite, 0.5) : kWhite);
    if (r < 0.6) {
      q.dot(x, y, col, 0.35 + 0.5 * tw);
    } else if (r < 0.95) {
      q.px(x, y, col);
      q.glow(x + 0.5, y + 0.5, 3, uPal[5], 0.25 * tw);
    } else {
      sparkle(
        q,
        x,
        y,
        (1 + (tw * 2.0 + 0.5).floor()).toDouble(),
        mix(uPal[5], kWhite, 0.6),
        uPal[4],
        0.35 * tw,
      );
    }
  }
}

const List<String> _defaultUpper = [
  '#120b2a',
  '#26164f',
  '#41208a',
  '#6a34c0',
  '#9c62e8',
  '#d2b4ff',
  '#f6eeff',
];

const EffectMeta _auroraMeta = EffectMeta(
  id: 'weather/aurora',
  name: 'Aurora',
  desc:
      'Rippling curtains of green-to-violet light over a starfield: folding hems burn bright, rays shimmer up into violet, and the whole sky slowly breathes.',
  category: 'weather',
  tags: [
    'weather',
    'aurora',
    'northern lights',
    'sky',
    'night',
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
      '#081a1e',
      '#0d3a36',
      '#13664e',
      '#1fa06a',
      '#3fd88e',
      '#9af7bf',
      '#e6fff0',
    ],
    'upper': _defaultUpper,
    'seed': 3,
  },
);

final PureEffect auroraEffect = PureEffect(
  meta: _auroraMeta,
  onDraw: (p, t, o) {
    final q = clip(p, _auroraMeta);
    final b = boxOf(_auroraMeta);
    final s = o.seed;
    final gPal = fit(o.palette, 7);
    final uPal = fit((o['upper'] as List<Object>?) ?? _defaultUpper, 7);
    _stars(q, t, s, uPal);
    _intensity.fillRange(0, _intensity.length, 0.0);
    _hv.fillRange(0, _hv.length, 0.0);
    final f = noiseField(s * 5 + 1, 256, 128, const [8, 16, 32]);
    final breath = 0.75 + 0.25 * math.sin(_cyc(t, 1, -1.2));
    final rays = <_RayPeak>[];
    for (var n = 0; n < _curtains.length; n++) {
      _curtain(_curtains[n], n, t, f, breath, rays);
    }
    _blur(_intensity, _blurBuf, 5);
    final gm = List<int>.generate(7, (i) => mix(gPal[i], uPal[i], 0.5));
    rows(p, _auroraMeta, b.y0.toDouble(), -12.0, (y, rBuf) {
      final base = (y.floor() - b.y0) * _w;
      final by = (y.floor() & 3) << 2;
      for (var xi = 0; xi < _w; xi++) {
        final i = base + xi;
        final raw = _intensity[i];
        final bl = _blurBuf[i];
        var k = bl > 0.015 ? math.min(0.4, bl * 0.6) : 0.0;
        if (raw >= 0.03) {
          final e = (raw * 1.5) / (1.0 + raw * 1.5);
          final v = _hv[i] / raw;
          final th = e > 0.45 ? _bay[by | (xi & 3)] * 0.06 : 0.0;
          var lv = e > 0.86 + th
              ? 6
              : (e > 0.72 + th
                  ? 5
                  : (e > 0.56 + th
                      ? 4
                      : (e > 0.4 + th ? 3 : (e > 0.24 ? 2 : 1))));
          if (v > 0.35) lv = math.min(lv, 5);
          final c = v < 0.3 ? gPal[lv] : (v < 0.5 ? gm[lv] : uPal[lv]);
          if (lv >= 3) {
            rBuf.c[xi] = c;
            rBuf.a[xi] = clamp((e - 0.3) * 2.2);
            rBuf.b[xi] = lv < 5 ? 1 : 0;
          }
          rBuf.l[xi] = lv >= 3
              ? (v < 0.4 ? gPal[4] : uPal[4])
              : (c == gPal[lv] ? gPal[4] : (c == uPal[lv] ? uPal[4] : gm[4]));
          k += e * (lv >= 3 ? 0.28 : 0.72);
        } else {
          rBuf.l[xi] = gPal[4];
        }
        rBuf.k[xi] = k;
      }
    });
    for (final r in rays) {
      final n = (r.h + 0.5).floor();
      for (var j = 1; j < n; j++) {
        final u = j / n;
        final col = u < 0.35
            ? gPal[5]
            : (u < 0.6 ? mix(gPal[5], uPal[5], 0.5) : uPal[5]);
        q.blend(r.x, r.hem - j, col, r.k * math.pow(1.0 - u, 1.3));
      }
      q.px(r.x, r.hem, gPal[6]);
    }
  },
);
