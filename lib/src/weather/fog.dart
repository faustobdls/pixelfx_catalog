// The banded fog (a baked tiling noise, warped, cut into a few translucent tones with Bayer edges, a lit crest
// wherever a band's top meets thinner fog) is adapted from Sprite Fusion's open-source fog
// (https://www.spritefusion.com/pixel-art-vfx/fog), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'weather_lib.dart';

const double _d = 12.0;
const int _w = 320;
const List<double> _thresholds = [0.3, 0.5, 0.7];
const double _bw = 0.06;

class _FogBank {
  final double top;
  final double base;
  final double bot;
  final double sx;
  final double sy;
  final double lap;
  final double alpha;
  final List<int> tone;
  final int crest;
  final double warp;
  final int crestFrom;

  const _FogBank({
    required this.top,
    required this.base,
    required this.bot,
    required this.sx,
    required this.sy,
    required this.lap,
    required this.alpha,
    required this.tone,
    required this.crest,
    required this.warp,
    required this.crestFrom,
  });
}

const List<_FogBank> _banks = [
  _FogBank(
    top: -84,
    base: -40,
    bot: -20,
    sx: 1.6,
    sy: 2.2,
    lap: 1,
    alpha: 0.24,
    tone: [2, 3, 4],
    crest: 5,
    warp: 16,
    crestFrom: 3,
  ),
  _FogBank(
    top: -62,
    base: -24,
    bot: -2,
    sx: 1.0667,
    sy: 2.5,
    lap: 1,
    alpha: 0.3,
    tone: [2, 3, 4],
    crest: 5,
    warp: 22,
    crestFrom: 2,
  ),
  _FogBank(
    top: -42,
    base: -8,
    bot: 10,
    sx: 0.8,
    sy: 2.8,
    lap: 1,
    alpha: 0.36,
    tone: [2, 3, 5],
    crest: 6,
    warp: 28,
    crestFrom: 1,
  ),
];

final Float32List _br = Float32List(_w);
final List<Float32List> _p1 = List<Float32List>.generate(
  _banks.length,
  (_) => Float32List(_w),
);
final List<Float32List> _p2 = List<Float32List>.generate(
  _banks.length,
  (_) => Float32List(_w),
);
final Float32List _warp = Float32List(_w);

void _bank(Painter p, double t, int s, List<int> c, int n) {
  final b = _banks[n];
  final fField = noiseField(s * 7 + n, 256, 128);
  final gField = noiseField(s * 7 + 11, 256, 128, const [4, 8, 16]);
  final drift = (256.0 * b.lap * t) / _d;
  final boil = (128.0 * t) / _d;
  final prev1 = _p1[n];
  final prev2 = _p2[n];
  final tones = [c[b.tone[0]], c[b.tone[1]], c[b.tone[2]]];
  final crest = mix(c[b.crest], kWhite, 0.12 + 0.08 * n);
  prev1.fillRange(0, _w, 0.0);
  prev2.fillRange(0, _w, 0.0);
  for (var i = 0; i < _w; i++) {
    _br[i] = 2.0 * math.sin((tau * t) / _d + (i - 160) * 0.006 + n * 1.7);
  }
  rows(p, _fogMeta, b.top - 2.0, b.bot, (y, rBuf) {
    final prof = smooth(b.top, b.base, y) *
        (1.0 - smooth(b.bot - (b.bot < 10.0 ? 14.0 : 4.0), b.bot + 1.0, y));
    for (var i = 0; i < _w; i += 2) {
      final wVal = sampleField(gField, i * 0.35 + n * 70.0, y * 0.5 + boil) - 0.5;
      _warp[i] = wVal;
      _warp[i + 1] = wVal;
    }
    for (var i = 0; i < _w; i++) {
      final x = i - 160.0 + 0.5;
      final w = _warp[i];
      final nn = clamp(
            (sampleField(
                      fField,
                      x * b.sx + drift + w * b.warp,
                      (y + _br[i]) * b.sy + w * 8.0,
                    ) -
                    0.5) *
                2.6 +
                0.5,
          ) -
          0.5;
      final f = prof <= 0.01 ? 0.0 : (prof * 0.72 + nn * 0.95) * (0.6 + 0.5 * prof);
      final above = prev2[i];
      prev2[i] = prev1[i];
      prev1[i] = f;
      if (f <= _thresholds[0]) continue;
      final th = bayer(i.toDouble(), y) * _bw;
      final band =
          f > _thresholds[2] + th ? 2 : (f > _thresholds[1] + th ? 1 : 0);
      final solid =
          f > _thresholds[2] ? 2 : (f > _thresholds[1] ? 1 : 0);
      if (solid >= b.crestFrom && above < _thresholds[solid]) {
        rBuf.c[i] = crest;
        rBuf.a[i] = b.alpha * 0.95;
        rBuf.l[i] = c[6];
        rBuf.k[i] = 0.07;
      } else {
        rBuf.c[i] = tones[band];
        rBuf.a[i] = b.alpha * (0.55 + 0.25 * band);
        if (band == 2) {
          rBuf.l[i] = c[5];
          rBuf.k[i] = 0.03 + 0.02 * n;
        }
      }
      rBuf.b[i] = 1;
    }
  });
}

void _streaks(Painter p, double t, int s, List<int> c, bool front) {
  final fField = noiseField(s * 7 + 20 + (front ? 1 : 0), 256, 128);
  final drift = (256.0 * t) / _d;
  final sx = front ? 0.4 : 0.5;
  final y0 = front ? -40.0 : -96.0;
  final y1 = front ? 6.0 : -30.0;
  rows(p, _fogMeta, y0, y1, (y, rBuf) {
    final env = smooth(y0, y0 + 10.0, y) * (1.0 - smooth(y1 - 10.0, y1, y));
    for (var i = 0; i < _w; i++) {
      final x = i - 160.0 + 0.5;
      final st =
          (sampleField(fField, x * sx + drift, y * 6.5 + 30.0) - 0.64) * 3.0 * env;
      if (st <= 0.05) continue;
      rBuf.c[i] = st > 0.35 ? c[5] : c[4];
      rBuf.a[i] = math.min(0.4, st);
      rBuf.b[i] = 1;
      rBuf.l[i] = c[5];
      rBuf.k[i] = st * 0.05;
    }
  });
}

const EffectMeta _fogMeta = EffectMeta(
  id: 'weather/fog',
  name: 'Fog',
  desc:
      'Slow banks of moonlit fog at three depths drift past each other, crests catching the light, while thin streaks of mist slide by in front.',
  category: 'weather',
  tags: ['weather', 'fog', 'mist', 'haze', 'night', 'ambient', 'loop'],
  size: (320, 180),
  origin: (160, 170),
  duration: _d,
  loop: true,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': [
      '#14121e',
      '#24213a',
      '#363250',
      '#4f4a6c',
      '#6d688b',
      '#918cab',
      '#bdb8d4',
      '#ece8f6',
    ],
    'seed': 5,
  },
);

final PureEffect fogEffect = PureEffect(
  meta: _fogMeta,
  onDrawBack: (p, t, o) {
    final s = o.seed;
    final c = fit(o.palette, 8);
    _bank(p, t, s, c, 0);
    _bank(p, t, s, c, 1);
  },
  onDraw: (p, t, o) {
    final s = o.seed;
    final c = fit(o.palette, 8);
    _bank(p, t, s, c, 2);
    _streaks(p, t, s, c, true);
  },
);
