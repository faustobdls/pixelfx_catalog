import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'critters_lib.dart';

const double _duration = 3.2;
final Swarm _swarm = Swarm();

({double x, double y, double vx, double vy}) _at(double t, double hover) {
  final a = (t / _duration) * tau;
  return (
    x: 34.0 * math.sin(a),
    y: -hover - 10.0 * math.sin(2.0 * a),
    vx: ((34.0 * tau) / _duration) * math.cos(a),
    vy: ((-20.0 * tau) / _duration) * math.cos(2.0 * a),
  );
}

const List<(double, double, double, int)> _tails = [
  (-3.5, 13.0, 2.5, 3),
  (3.5, 14.0, 2.5, 7),
  (0.0, 20.0, 3.2, 11),
];

final PureEffect wispEffect = PureEffect(
  meta: const EffectMeta(
    id: 'critters/wisp',
    name: 'Wisp',
    desc:
        'A will-o\'-the-wisp loops a figure-eight over the floor: a little soul-flame with a face, its flame tail licking up and streaming behind, shedding puffs and sparks.',
    category: 'critters',
    tags: ['critter', 'wisp', 'spirit', 'flame', 'magic', 'flying', 'loop'],
    size: (128, 104),
    origin: (64, 96),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#0a1f2e',
        '#0f3d52',
        '#14707e',
        '#1fa8a8',
        '#4fe0c8',
        '#a8fff0',
        '#ffffff',
      ],
      'hover': 36,
      'seed': 1,
    },
  ),
  onDrawBack: (p, time, o) {
    final t = shift(time, _duration, o.seed);
    final c = fit(o.palette, 7);
    final s = _at(t, o.numOpt('hover', 36.0));
    final near = clamp(1.0 - (-s.y - 24.0) / 30.0);
    shadow(p, s.x, 0, 7, 1.2, c[0], 0.4);
    for (var x = -24; x <= 24; x += 6) {
      p.glow(
        s.x + x,
        -1,
        16,
        c[4],
        (0.08 + 0.1 * near) * (1.0 - x.abs() / 32.0),
      );
    }
  },
  onDraw: (p, time, o) {
    final seed = o.seed;
    final hover = o.numOpt('hover', 36.0);
    final t = shift(time, _duration, seed);
    final c = fit(o.palette, 7);
    final s = _at(t, hover);
    final heat = [c[6], c[6], c[5], c[5], c[4], c[4], c[3], c[3], c[3]];
    final lean = clamp(-s.vx / 80.0, -0.9, 0.9);
    final stretch = clamp(s.vy / 120.0, -0.3, 0.4);
    final x = s.x;
    final y = s.y;

    cycle(t, _duration, 30, seed * 7 + 1, (r) => r.range(0.3, 0.6),
        (age, len, r, _) {
      final s0 = _at(wrap(t - age, _duration), hover);
      final (px, py) = fly(
        s0.x + r.range(-3.0, 3.0),
        s0.y - r.range(0.0, 4.0),
        r.range(-8.0, 8.0),
        -r.range(6.0, 16.0),
        age,
        -40.0,
        2.5,
      );
      firePuff(
        p,
        px,
        py,
        1.0 - age / len,
        r.range(1.2, 2.6),
        r.next() * 100.0,
        heat,
      );
    });

    for (var li = 0; li < 4; li++) {
      for (final (dx, h, w, n) in _tails) {
        final hh = (h + 0.25 * h * lnoise(t, _duration, 9, n.toDouble(), 5)) *
            (1.0 + stretch);
        tongue(
          p,
          x + dx,
          y - 2.0,
          hh,
          w,
          lnoise(t, _duration, 6, n.toDouble(), 40) * 1.5 + lean * hh * 0.9,
          t,
          _duration,
          n,
          heat,
          li,
        );
      }
    }

    const r = 7.5;
    p.shade(x - r - 2.0, y - r - 2.0, x + r + 2.0, y + r + 2.0, (px, py, _) {
      final dx = px - x;
      final dy = py - y;
      final ang = math.atan2(dy, dx);
      final rr = r +
          0.7 * lnoise(t, _duration, 16, ang * 1.6 + 10.0, 3) +
          (dy > 0.0 ? -0.6 : 0.0);
      final d = hypot(dx, dy) / rr;
      if (d > 1.0) return null;
      return d < 0.42
          ? c[6]
          : (d < 0.68 ? c[5] : (d < 0.88 ? c[4] : c[3]));
    });

    final look = roundJs(clamp(s.vx / 60.0, -1.0, 1.0));
    final tw = wrap(t, _duration);
    final blink = tw > 2.2 && tw < 2.28;
    final rx = roundJs(x);
    final ry = roundJs(y);
    for (final side in const [-1, 1]) {
      final ex = rx + side * 2 - (side > 0 ? 0 : 1) + look;
      final ey = ry - 1;
      if (blink) {
        p.px(ex, ey + 1, c[1]);
        p.px(ex + 1, ey + 1, c[1]);
      } else {
        for (var k = 0; k < 3; k++) {
          p.px(ex, ey + k, c[1]);
          p.px(ex + 1, ey + k, c[1]);
        }
        p.px(ex + (look > 0 ? 1 : 0), ey, c[6]);
      }
    }
    p.px(rx + look, ry + 3, c[2]);
    p.px(rx - 1 + look, ry + 3, c[2]);

    final sw = _swarm.begin(t);
    sw.setSparks([c[6], c[5], c[4], c[3]]);
    cycle(t, _duration, 26, seed * 7 + 2, (r) => r.range(0.8, 1.6),
        (age, len, r, _) {
      final s0 = _at(wrap(t - age, _duration), hover);
      final sSeed = r.next() * 100.0;
      final (px, py) = fly(
        s0.x + r.range(-5.0, 5.0),
        s0.y - r.range(4.0, 12.0),
        r.range(-20.0, 20.0),
        -r.range(20.0, 45.0),
        age,
        -15.0,
        1.6,
      );
      sw.add(
        P.ember,
        px + math.sin(age * 2.3 + sSeed) * 3.0 * math.min(1.0, age),
        py,
        0,
        0,
        age,
        len,
        c[4],
        r.chance(0.3) ? 2.0 : 1.0,
        0,
        sSeed,
      );
    });
    sw.draw(p);

    final fl = 0.85 + 0.15 * lnoise(t, _duration, 22, 0, 9);
    p.glow(x + lean * 3.0, y - 6.0, 46.0 * fl, c[4], 0.38);
    p.glow(x, y - 1.0, 13, c[5], 0.35 * fl);
  },
);
