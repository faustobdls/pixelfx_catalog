// The tongue, lick, flame-puff, smoke and ember recipe is adapted from Sprite Fusion's open-source fire
// (https://www.spritefusion.com/pixel-art-vfx/fire), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'fire_lib.dart';

const double _d = 2.0;
final FireNoiseFn _nl = noiseFor(_d);
const double _base = -16.0;

const List<TongueSpec> _tongues = [
  (-1.9, -1.0, 0.74, 2.0, 1),
  (2.1, -1.0, 0.7, 2.0, 1),
  (-3.4, 0.5, 0.42, 1.6, 0),
  (3.6, 0.5, 0.46, 1.6, 0),
  (0.0, 0.0, 1.0, 2.9, 0),
];

void _plate(Painter p, List<int> i, List<int> h, double fl) {
  p.shade(-5.5, -5.5, 5.5, 11.5, (x, y, _) {
    if (x < -5.0 || x > 5.0 || y < -5.0 || y > 11.0) return i[0];
    final rv = x.abs() < 0.6 && ((y + 3.5).abs() < 0.6 || (y - 9.5).abs() < 0.6);
    if (rv) return mix(i[4], h[3], 0.35 * fl);
    if (y < -4.0 || x < -4.0) return mix(i[3], h[4], 0.3 * fl);
    if (y > 10.0 || x > 4.0) return i[1];
    return y < 2.0 ? i[2] : i[1];
  });
}

void _handle(Painter p, List<int> w) {
  p.shade(-3.0, -12.0, 3.0, 15.0, (x, y, _) {
    final half = 1.3 + clamp((14.0 - y) / 26.0) * 0.9;
    if (x.abs() > half + 0.5 || y > 14.5) return null;
    if (x.abs() > half - 0.5 || y > 13.5) return w[0];
    final g = rand((y / 3.0).floor(), (x + 0.5).floor(), 9);
    return x < -0.3 ? (g < 0.3 ? w[2] : w[4]) : (g < 0.4 ? w[1] : w[2]);
  });
}

void _ring(Painter p, List<int> i, List<int> h, double fl) {
  p.rect(-3, -2, 7, 4, i[0]);
  p.rect(-2, -1, 5, 1, mix(i[4], h[3], 0.3 * fl));
  p.rect(-2, 0, 5, 1, i[2]);
}

void _wrap(Painter p, List<int> w, List<int> i, List<int> h, double t) {
  p.shade(-6.0, _base - 2.0, 6.0, -9.0, (x, y, out) {
    final v = (y - (_base - 1.5)) / 7.5;
    final half = 4.6 - v * 1.9;
    if (x.abs() > half + 0.5 || y < _base - 1.5 || y > -9.5) return null;
    if (x.abs() > half - 0.5 || y > -10.5) return w[0];
    final cord = (y - x * 0.6 + 40.0).floor() % 3 == 0;
    final hashVal = rand(x.floor(), y.floor(), 31);
    if (v < 0.45) {
      if (hashVal < 0.42) {
        final g = 0.5 + 0.5 * math.sin((t / _d) * math.pi * 4.0 + hashVal * 40.0);
        out.k = 0.3 * g;
        return g > 0.66 ? h[2] : (g > 0.33 ? h[4] : h[5]);
      }
      return hashVal < 0.75 ? w[0] : w[1];
    }
    if (cord) return i[2];
    return x < -1.0 ? w[3] : (x < 1.5 ? w[2] : w[1]);
  });
}

final PureEffect torchEffect = PureEffect(
  meta: const EffectMeta(
    id: 'fire/torch',
    name: 'Torch',
    desc:
        'A wall torch on an iron bracket: a licking flame leaping off a pitch-soaked wrap, licks and puffs torn off its tips, smoke, embers, a flickering light on the wall.',
    category: 'fire',
    tags: ['fire', 'torch', 'prop', 'light', 'wall', 'dungeon', 'loop'],
    size: (72, 120),
    origin: (36, 94),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#4a1712', '#8a1f17', '#c9281f', '#f2561d',
        '#ff8a2a', '#ffc23d', '#ffe26b', '#fff3a6', '#ffffff',
      ],
      'wood': ['#0e080a', '#24130f', '#3b2216', '#5a3520', '#8a5a34', '#b9884f'],
      'iron': ['#0d0b12', '#1e1b26', '#363242', '#5b5566', '#8a8396'],
      'seed': 4,
    },
  ),
  onDraw: (p, t, o) {
    final f = fit(o.palette, 9);
    final h = hotFirst(f);
    final w = fit(o.rampOpt('wood'), 6);
    final i = fit(o.rampOpt('iron'), 5);
    final s = o.seed;
    final fl0 = 0.74 + 0.16 * _nl(t, 7.3, s + 1) + 0.1 * _nl(t, 19.0, s + 2);
    _plate(p, i, h, fl0);
    _handle(p, w);
    _ring(p, i, h, fl0);
    burn(
      p,
      t,
      _tongues,
      hRamp: h,
      d: _d,
      nl: _nl,
      seed: s,
      x: 0,
      y: _base,
      height: 20,
      lean: 0.12,
      spread: 4,
      puffsRate: 10,
      licksRate: 5,
      smokeRate: 7,
      smokeSize: 2.3,
      smokeLife: (1.3, 2.1),
      embersRate: 7,
      glowR: 48,
      glow: 1.25,
      wind: 2,
      mid: (_) => _wrap(p, w, i, h, t),
    );
  },
);
