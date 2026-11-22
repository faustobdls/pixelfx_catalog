// The layered flame tongue is adapted from Sprite Fusion's open-source fire
// (https://www.spritefusion.com/pixel-art-vfx/fire), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'fire_lib.dart';

const double _d = 4.0;
final FireNoiseFn _nl = noiseFor(_d);
const double _top = -16.0;
const double _wick = _top - 3.0;

const List<(double, double, int)> _calm = [
  (1.0, 1.0, 5),
  (0.8, 0.88, 3),
  (0.6, 0.72, 2),
  (0.38, 0.52, 1),
  (0.18, 0.3, 0),
];

const double _dripX = 4.0;
const double _dripY0 = _top + 2.0;
const double _dripY1 = -7.0;

class _SmokeSeed {
  final double vx, vy, life, s;
  _SmokeSeed(this.vx, this.vy, this.life, this.s);
}

class _MoteSeed {
  final double x, y, vx, vy, life, ph;
  _MoteSeed(this.x, this.y, this.vx, this.vy, this.life, this.ph);
}

void _dish(Painter p, List<int> b, List<int> h, double fl) {
  p.ellipseShaded(
    0,
    1,
    10,
    2.6,
    color: (double d, double a) => d > 0.82
        ? b[0]
        : (math.sin(a) < -0.2
            ? (d > 0.6 ? mix(b[3], h[3], 0.3 * fl) : b[2])
            : (d > 0.55 ? b[1] : b[2])),
  );
  p.rect(-8, 2, 17, 1, b[1]);
  p.rect(-7, 3, 15, 1, b[0]);
}

void _candle(Painter p, List<int> x, List<int> h, double fl) {
  const l = _top;
  final cols = [x[1], x[4], x[5], x[4], x[4], x[3], x[3], x[2], x[0]];
  for (var i = 0; i < 9; i++) {
    final px = i - 4;
    p.rect(px, l + 1.0, 1, -l - 2.0, cols[i]);
    if (i == 2) p.rect(px, -8, 1, 7, x[4]);
  }
  p.rect(-3, -1, 7, 1, x[2]);
  p.px(-4, -1, x[0]);
  p.px(4, -1, x[0]);
  p.rect(-3, l, 7, 1, mix(x[5], h[2], 0.25 * fl));
  p.px(-4, l, x[1]);
  p.px(4, l, x[1]);
  p.rect(-2, l + 1.0, 5, 1, mix(x[5], h[1], 0.5 * fl));
  p.rect(-1, l + 1.0, 3, 1, mix(x[4], h[2], 0.45 * fl));

  const y1 = _dripY1;
  p.rect(3, l + 1.0, 1, y1 - l - 1.0, x[4]);
  p.rect(4, l + 2.0, 1, y1 - l - 2.0, x[3]);
  p.px(5, l + 3.0, x[0]);
  p.rect(5, l + 4.0, 1, y1 - l - 4.0, x[0]);
  p.rect(3, y1, 2, 2, x[4]);
  p.px(5, y1, x[3]);
  p.px(5, y1 + 1.0, x[2]);
  p.px(6, y1, x[0]);
  p.px(6, y1 + 1.0, x[0]);
  p.rect(3, y1 + 2.0, 3, 1, x[0]);
  p.px(3, l + 2.0, x[5]);

  p.rect(-4, l + 1.0, 1, 4, x[4]);
  p.px(-5, l + 3.0, x[1]);
  p.px(-5, l + 4.0, x[1]);
  p.px(-4, l + 5.0, x[3]);
}

final PureEffect candleEffect = PureEffect(
  meta: const EffectMeta(
    id: 'fire/candle',
    name: 'Candle',
    desc:
        'A wax candle in a brass dish: a calm flame with a blue root that sways and stretches, a halo of light, motes drifting in it, a bead of wax running down a drip.',
    category: 'fire',
    tags: ['fire', 'candle', 'prop', 'light', 'calm', 'ambient', 'loop'],
    size: (56, 76),
    origin: (28, 64),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#4a1712', '#8a1f17', '#c9281f', '#f2561d',
        '#ff8a2a', '#ffc23d', '#ffe26b', '#fff3a6', '#ffffff',
      ],
      'root': ['#1b2a8a', '#3a62e0', '#7fb4ff'],
      'wax': ['#2e201e', '#5e4436', '#8e6e58', '#b8957a', '#d8b896', '#f0dcc0'],
      'brass': ['#2a1a10', '#6a4a1e', '#b4862e', '#e8c060', '#fff0b0'],
      'seed': 2,
    },
  ),
  onDraw: (p, t, o) {
    final f = fit(o.palette, 9);
    final h = hotFirst(f);
    final rt = fit(o.rampOpt('root'), 3);
    final x = fit(o.rampOpt('wax'), 6);
    final b = fit(o.rampOpt('brass'), 5);
    final s = o.seed;

    double n(double rate, [int sd = 0, double off = 0.0]) =>
        _nl(t, rate * 0.35, sd, off);
    final fl = 0.86 + 0.08 * _nl(t, 2.0, s + 1) + 0.06 * _nl(t, 7.0, s + 2);
    final stretch = math.max(0.0, _nl(t, 0.75, s + 3) - 0.3) * 0.6;
    final flameH = 12.0 * (1.0 + stretch) * (0.94 + 0.06 * fl);
    final sway = _nl(t, 0.5, s + 4) * 1.6 + _nl(t, 1.5, s + 5) * 0.5;
    final glowCol = mix(mix(h[3], h[4], 0.5), kWhite, 0.3);
    final cy = _wick - flameH * 0.4;

    floorLight(p, 0, 1, 26, 5, glowCol, 0.3 * fl);
    p.glow(sway * 0.3, cy, 38 * fl, glowCol, 0.42 * fl);
    p.glowRing(sway * 0.3, cy, 10, 4, h[2], 0.12 * fl);
    _dish(p, b, h, fl);
    _candle(p, x, h, fl);

    final run = t.remainder(_d) / _d;
    final swell = smooth(0.0, 0.3, run);
    final slide = smooth(0.3, 0.85, run);
    final set = smooth(0.85, 1.0, run);
    if (set < 1.0 && swell > 0.15) {
      final by = (_dripY0 + (_dripY1 - _dripY0) * slide + 0.5).floor();
      p.px(_dripX, by, mix(x[5], h[1], 0.4 * fl));
      if (swell > 0.6 && set < 0.5) {
        p.px(_dripX + 1.0, by, x[4]);
        p.px(_dripX + 1.0, by + 1, x[2]);
      }
    }

    p.line(0, _top, 0, _wick + 1.0, x[0]);
    p.px(0, _wick + 1.0, h[4]);
    flameTongue(
      p,
      0,
      _wick + 1.0,
      flameH,
      2.6,
      sway,
      n,
      s * 31,
      h,
      layers: _calm,
      jit: 0.25,
      wob: 0.6,
    );
    for (var dx = -2; dx <= 2; dx++) {
      final a = 1.0 - dx.abs() * 0.2;
      p.dot(dx, _wick + 1.0, dx.abs() == 2 ? rt[0] : rt[1], a);
      if (dx.abs() <= 1) p.dot(dx, _wick + 2.0, rt[0], 0.7);
    }
    p.px(0, _wick, rt[2]);

    looped<_SmokeSeed>(
      t,
      _d,
      6,
      s + 300,
      (r, _) {
        final vx = r.range(-1.5, 1.5);
        final vy = -r.range(8.0, 12.0);
        final life = r.range(1.4, 2.2);
        return (_SmokeSeed(vx, vy, life, r.range(0.8, 1.2)), life);
      },
      (q, age, _) {
        final (sx, sy, _, _) =
            drift(sway, _wick - flameH, q.vx, q.vy, age, 1.0, -6.0, 1.0, 0.8);
        smokePuff(
          p,
          sx + _nl(t - age, 0.6, s + 60) * (1.0 + age * 2.0),
          sy,
          1.0 - age / q.life,
          q.s,
          0,
          false,
          0.6,
        );
      },
    );

    looped<_MoteSeed>(
      t,
      _d,
      10,
      s + 400,
      (r, _) {
        final x = r.range(-20.0, 20.0);
        final y = r.range(-44.0, -8.0);
        final vx = r.range(-3.0, 3.0);
        final vy = r.range(-4.0, 2.0);
        final life = r.range(2.5, 4.0);
        return (_MoteSeed(x, y, vx, vy, life, r.range(0.0, 6.3)), life);
      },
      (q, age, _) {
        final mx = q.x + q.vx * age + math.sin(age * 1.3 + q.ph) * 2.0;
        final my = q.y + q.vy * age;
        final d = hypot(mx, my - cy);
        final k = math.min(
              1.0,
              math.min(age * 2.0, (q.life - age) * 2.0),
            ) *
            clamp(1.2 - d / 26.0);
        if (k > 0.15) {
          p.dot(mx, my, k > 0.6 ? h[1] : h[3], k);
          p.glow(mx, my, 3, h[2], 0.2 * k);
        }
      },
    );

    p.glow(sway * 0.5, _wick - flameH * 0.3, 10, h[1], 0.35 * fl);
  },
);
