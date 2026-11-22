// The tongue, lick, flame-puff, smoke, ember and spark recipe is adapted from Sprite Fusion's open-source fire
// (https://www.spritefusion.com/pixel-art-vfx/fire), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'fire_lib.dart';

const double _d = 3.0;
final FireNoiseFn _nl = noiseFor(_d);
const double _rim = -25.0;
const double _rx = 15.0;
const double _ry = 3.0;

const List<TongueSpec> _tongues = [
  (-7.0, -1.5, 0.5, 2.0, 1),
  (7.2, -1.5, 0.55, 2.0, 1),
  (-3.0, -2.5, 0.84, 2.2, 1),
  (3.3, -2.5, 0.86, 2.2, 1),
  (-11.5, 0.5, 0.2, 1.5, 0),
  (11.5, 0.5, 0.22, 1.5, 0),
  (-8.3, 0.0, 0.34, 2.0, 0),
  (8.5, 0.0, 0.38, 2.0, 0),
  (-4.7, -0.5, 0.6, 2.8, 0),
  (4.9, -0.5, 0.64, 2.8, 0),
  (0.0, -1.0, 1.0, 3.6, 0),
];

class _SparkSeed {
  final double x, y, vx, vy, life, a, w, m;
  final bool big;
  _SparkSeed(
      this.x, this.y, this.vx, this.vy, this.life, this.a, this.w, this.m, this.big);
}

void _stand(Painter p, List<int> i, List<int> h, double fl) {
  void leg(double x0, double y0, double x1, double y1) {
    p.line(x0, y0, x1, y1, i[0]);
    p.line(x0 + 1.0, y0, x1 + 1.0, y1, i[2]);
    p.line(x0 + 2.0, y0, x1 + 2.0, y1, i[0]);
  }

  p.ellipseShaded(0, -9, 9, 1.8,
      color: (double d, double _) => d > 0.6 ? i[2] : 0);
  leg(-6, -17, -12, -1);
  leg(4, -17, 10, -1);
  p.rect(-14, -1, 5, 1, i[2]);
  p.rect(-15, 0, 6, 1, i[0]);
  p.px(-15, -1, i[3]);
  p.rect(9, -1, 5, 1, i[2]);
  p.rect(9, 0, 6, 1, i[0]);
  p.px(13, -1, i[3]);
  p.rect(-1, -16, 3, 15, i[0]);
  p.rect(0, -16, 1, 15, mix(i[3], h[4], 0.15 * fl));
  p.rect(-2, -1, 5, 1, i[2]);
  p.rect(-2, 0, 5, 1, i[0]);
  p.ellipseShaded(
    0,
    -9,
    9,
    1.8,
    color: (double d, double a) =>
        math.sin(a) > 0.0 && d > 0.55 ? (d > 0.85 ? i[0] : i[3]) : 0,
  );
}

void _bowl(Painter p, List<int> i, List<int> h, double fl) {
  p.shade(-_rx - 1.0, _rim - 1.0, _rx + 1.0, _rim + 9.0, (x, y, _) {
    final v = (y - _rim) / 9.0;
    final hw = _rx * math.sqrt(math.max(0.0, 1.0 - v * v * 0.9)) -
        (v > 0.5 ? (v - 0.5) * 6.0 : 0.0);
    if (x.abs() > hw + 0.5 || y < _rim) return null;
    if (x.abs() > hw - 0.5 || v > 0.92) return i[0];
    if (y < _rim + 1.0) return mix(i[3], h[4], 0.5 * fl);
    if (y < _rim + 2.0) return i[2];
    if (y < _rim + 3.0) {
      return (x + 0.5).floor() % 4 == 0
          ? mix(i[4], h[4], 0.25 * fl)
          : i[0];
    }
    return x < -_rx * 0.45 ? i[2] : (x < _rx * 0.25 ? i[1] : i[0]);
  });
}

void _coals(Painter p, List<int> i, List<int> h, double t, int s) {
  p.shade(-_rx, _rim - 6.0, _rx, _rim + 1.0, (x, y, out) {
    final xr = x / (_rx - 1.0);
    final top = _rim - 1.0 - 4.0 * math.max(0.0, 1.0 - xr * xr);
    if (y < top || y > _rim + 0.5 || x.abs() > _rx - 0.5) return null;
    final lump = rand(
      ((x + y.floor() * 1.5) / 3.0).floor(),
      (y / 2.0).floor(),
      s + 20,
    );
    final edge = y < top + 1.0;
    if (rand(x.floor(), y.floor(), s + 21) < 0.16 || (edge && lump < 0.3)) {
      return i[0];
    }
    final g = (0.5 + 0.5 * math.sin((t / _d) * math.pi * 4.0 + lump * 40.0)) *
        (edge ? 0.7 : 1.0);
    out.k = 0.3 * g;
    return g > 0.72
        ? h[2]
        : g > 0.5
            ? h[3]
            : g > 0.3
                ? h[4]
                : g > 0.15
                    ? h[5]
                    : h[6];
  });
}

final PureEffect brazierEffect = PureEffect(
  meta: const EffectMeta(
    id: 'fire/brazier',
    name: 'Brazier',
    desc:
        'An iron bowl on a tripod heaped with glowing coals and a big roaring fire, sparks and embers streaming up off it, light on the iron and the floor.',
    category: 'fire',
    tags: ['fire', 'brazier', 'prop', 'light', 'sparks', 'ambient', 'loop'],
    size: (112, 148),
    origin: (56, 136),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#4a1712', '#8a1f17', '#c9281f', '#f2561d',
        '#ff8a2a', '#ffc23d', '#ffe26b', '#fff3a6', '#ffffff',
      ],
      'iron': ['#0b0910', '#1c1924', '#302c3a', '#4c4658', '#78708a'],
      'seed': 8,
    },
  ),
  onDraw: (p, t, o) {
    final f = fit(o.palette, 9);
    final h = hotFirst(f);
    final i = fit(o.rampOpt('iron'), 5);
    final s = o.seed;
    final fl = 0.74 + 0.16 * _nl(t, 7.3, s + 1) + 0.1 * _nl(t, 19.0, s + 2);
    final glowCol = mix(mix(h[3], h[4], 0.5), kWhite, 0.25);
    final sparks = [h[1], h[2], h[4], h[5]];
    final emb = [h[1], h[2], h[4], h[6]];

    floorLight(p, 0, 0.5, 40, 7, glowCol, 0.32 * fl);
    _stand(p, i, h, fl);
    p.ellipseShaded(
      0,
      _rim,
      _rx,
      _ry,
      color: (double d, double a) => math.sin(a) < 0.0 && d > 0.7
          ? (d > 0.88 ? i[0] : mix(i[3], h[4], 0.3 * fl))
          : 0,
    );
    burn(
      p,
      t,
      _tongues,
      hRamp: h,
      d: _d,
      nl: _nl,
      seed: s,
      x: 0,
      y: _rim,
      height: 32,
      lean: 0.1,
      spread: 7,
      puffsRate: 8,
      licksRate: 4,
      smokeRate: 14,
      smokeSize: 3,
      smokeLife: (1.6, 2.4),
      embersRate: 10,
      glowR: 58,
      glow: 1.4,
      wind: 3,
      mid: (_) {
        _coals(p, i, h, t, s);
        _bowl(p, i, h, fl);
      },
    );

    looped<_SparkSeed>(
      t,
      _d,
      60,
      s + 600,
      (r, _) {
        final side = r.range(-1.0, 1.0);
        return (
          _SparkSeed(
            side * 8.0,
            _rim - r.range(4.0, 18.0),
            side * r.range(10.0, 40.0),
            -r.range(70.0, 150.0),
            r.range(0.7, 1.7),
            r.range(0.0, 6.3),
            r.range(1.8, 3.2),
            r.range(3.0, 8.0),
            r.chance(0.12),
          ),
          0.0,
        ).let((tup) => (tup.$1, tup.$1.life));
      },
      (q, age, _) {
        final (x, y, vx, vy) =
            drift(q.x, q.y, q.vx, q.vy, age, 0.0, -22.0, 1.9, 1.9);
        final k = 1.0 - age / q.life;
        final ramp = math.min(1.0, age * 1.5);
        final wob =
            q.m * (math.sin(age * q.w + q.a) - math.sin(q.a)) * ramp;
        final wv = q.m * q.w * math.cos(age * q.w + q.a) * ramp;
        if (hypot(vx + wv, vy) > 40.0) {
          sparkLine(p, x + wob, y, vx + wv, vy, k, sparks);
        } else {
          emberDot(
              p, x + wob, y, k, q.big ? 2.0 : 1.0, emb, age * 40.0 + q.a);
        }
      },
    );
  },
);

extension _LetExt<T> on T {
  R let<R>(R Function(T) fn) => fn(this);
}
