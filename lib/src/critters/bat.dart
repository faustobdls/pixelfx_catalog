import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'critters_lib.dart';

const double _duration = 2.4;
const int _flaps = 6;
final CritterGrid _grid = CritterGrid(-24, -22, 48, 40);

class _WingFrame {
  final double arm;
  final double al;
  final List<double> f;
  final List<double> fl;
  final int lift;

  const _WingFrame({
    required this.arm,
    required this.al,
    required this.f,
    required this.fl,
    required this.lift,
  });
}

const List<_WingFrame> _frames = [
  _WingFrame(arm: -58, al: 8, f: [-112, -76, -38], fl: [9, 11, 9], lift: 1),
  _WingFrame(arm: -18, al: 9, f: [-40, -12, 16], fl: [10, 11, 9], lift: 0),
  _WingFrame(arm: 28, al: 8, f: [50, 72, 94], fl: [9, 10, 8], lift: -2),
  _WingFrame(arm: -42, al: 6, f: [-66, -38, -10], fl: [7, 8, 6], lift: -1),
];

double _rad(double d) => (d * math.pi) / 180.0;

({double x, double y, double vx}) _at(double t) {
  final a = (t / _duration) * tau;
  return (
    x: 22.0 * math.sin(a),
    y: 7.0 * math.sin(2.0 * a),
    vx: math.cos(a),
  );
}

int _frameAt(double t) =>
    (wrap((t / _duration) * _flaps, 1.0) * 4.0).floor() % 4;

({
  (double, double) sh,
  (double, double) wr,
  List<(double, double)> tips,
  (double, double) hip,
  List<(double, double)> poly,
}) _wingPts(_WingFrame f, int s) {
  final sh = (s * 2.5, -2.0);
  final ar = _rad(f.arm);
  final wr = (sh.$1 + s * math.cos(ar) * f.al, sh.$2 + math.sin(ar) * f.al);
  final tips = <(double, double)>[
    for (var i = 0; i < f.f.length; i++)
      (
        wr.$1 + s * math.cos(_rad(f.f[i])) * f.fl[i],
        wr.$2 + math.sin(_rad(f.f[i])) * f.fl[i],
      ),
  ];
  (double, double) pull((double, double) a, (double, double) b, double k) => (
        lerp((a.$1 + b.$1) / 2.0, wr.$1, k),
        lerp((a.$2 + b.$2) / 2.0, wr.$2, k),
      );
  final hip = (s * 2.0, 3.5);
  return (
    sh: sh,
    wr: wr,
    tips: tips,
    hip: hip,
    poly: [
      sh,
      wr,
      tips[0],
      pull(tips[0], tips[1], 0.22),
      tips[1],
      pull(tips[1], tips[2], 0.22),
      tips[2],
      pull(tips[2], hip, 0.38),
      hip,
    ],
  );
}

void _bat(CritterGrid g, List<int> c, List<int> e, _WingFrame f, double t) {
  g.clear();
  for (final s in const [-1, 1]) {
    final w = _wingPts(f, s);
    double lead(double x, double y) {
      final (ax, ay) = w.wr;
      final (bx, by) = w.tips[0];
      final dx = bx - ax;
      final dy = by - ay;
      final lRaw = hypot(dx, dy);
      final len = lRaw == 0.0 ? 1.0 : lRaw;
      return (((x - ax) * dy - (y - ay) * dx) / len).abs();
    }

    g.polyFn(w.poly, (x, y) {
      final near = hypot(x - w.sh.$1, y - w.sh.$2);
      if (lead(x, y) < 1.2 && f.arm < 20) return c[3];
      return near < 4.5 ? c[1] : c[2];
    });
    g.line(w.sh.$1, w.sh.$2, w.wr.$1, w.wr.$2, c[4]);
    for (final tip in w.tips) {
      g.lineFn(
        w.wr.$1,
        w.wr.$2,
        tip.$1,
        tip.$2,
        (u) => u < 0.6 ? c[4] : c[3],
      );
    }
    g.set(w.wr.$1, w.wr.$2 - 1.0, c[5]);
  }
  g.ellipse(0, 0.5, 3.8, 4.8, (nx, ny) {
    if (nx * -0.6 + ny * -0.8 > 0.45) return c[4];
    if (nx * 0.6 + ny * 0.8 > 0.55) return c[2];
    if (ny > 0.1 && nx.abs() < 0.5) return c[4];
    return c[3];
  });
  for (final s in const [-1, 1]) {
    g.poly(
      [(s * 0.6, -3.5), (s * 3.6, -9.5), (s * 3.8, -3.0)],
      s < 0 ? c[4] : c[3],
    );
    g.line(s * 2.6, -4.0, s * 3.2, -7.5, c[5]);
  }
  g.set(-2, -1, e[1]);
  g.set(1, -1, e[1]);
  g.set(-1, 0, c[1]);
  g.set(0, 0, c[1]);
  g.set(-1, 1, c[6]);
  g.set(0, 1, c[6]);
  g.set(-2, 5, c[3]);
  g.set(1, 5, c[3]);
  g.outline(c[0]);
}

final PureEffect batEffect = PureEffect(
  meta: const EffectMeta(
    id: 'critters/bat',
    name: 'Bat',
    desc:
        'A bat flaps in four snappy wing frames along a figure-eight, its body lifting on each downbeat, moonlight on its wing bones, red eyes glowing and glinting.',
    category: 'critters',
    tags: ['critter', 'bat', 'night', 'flying', 'spooky', 'loop'],
    size: (112, 80),
    origin: (56, 40),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.sky,
    defaultOptions: {
      'palette': [
        '#0c0912',
        '#1f1629',
        '#382645',
        '#5b3f66',
        '#866089',
        '#b88fb0',
        '#e8cfe0',
      ],
      'eyes': ['#8a1020', '#ff3b30', '#ffb04a', '#fff0c0'],
      'seed': 1,
    },
  ),
  onDraw: (p, time, o) {
    final seed = o.seed;
    final t = shift(time, _duration, seed);
    final c = fit(o.palette, 7);
    final e = fit(o.rampOpt('eyes'), 4);
    final s = _at(t);
    final fi = _frameAt(t);
    final f = _frames[fi];
    final x = roundJs(s.x);
    final y = roundJs(s.y + f.lift);

    for (var k = 2; k <= 16; k++) {
      final a = _at(t - (k - 1) * 0.022);
      final b2 = _at(t - k * 0.022);
      final u = 1.0 - k / 17.0;
      for (final ex in const [-1.5, 1.5]) {
        p.glowLine(
          a.x + ex,
          a.y - 0.5,
          b2.x + ex,
          b2.y - 0.5,
          2.6,
          e[1],
          0.16 * u,
        );
      }
    }

    cycle(t, _duration, 9, seed * 11 + 1, (_) => _duration, (age, len, r, _) {
      final px = r.range(-50.0, 50.0) + math.sin(age * 1.1 + r.next() * 6.0) * 3.0;
      final py = r.range(-34.0, 34.0) + age * r.range(-2.0, 3.0);
      final tw = math.sin(age * 2.6 + r.next() * 6.0);
      final a = math.min(1.0, math.min(age * 2.0, (len - age) * 2.0)) *
          (0.4 + 0.5 * tw);
      p.dot(px, py, tw > 0.7 ? c[6] : c[5], a);
      if (tw > 0.5) p.glow(px, py, 3, c[5], 0.2 * a);
    });

    final g = _grid;
    if (fi == 2) {
      _bat(g, c, e, _frames[1], t);
      g.recolor((_, _, col, _, _) => mix(col, c[4], 0.35));
      g.fillAlpha(0.35);
      g.draw(p, 1.0, x.toDouble(), (y - _frames[1].lift + f.lift).toDouble());
    }
    _bat(g, c, e, f, t);
    g.draw(p, 1.0, x.toDouble(), y.toDouble());

    p.glow(x - 3, y - 6, 10, c[5], 0.12);
    for (final ex in const [-1.5, 1.5]) {
      p.glow(x + ex, y - 0.5, 7, e[1], 0.6);
      p.glow(x + ex, y - 0.5, 2.5, e[2], 0.5);
    }
    p.glow(x, y, 22, e[0], 0.25);
    for (final g0 in const [0.3, 1.5]) {
      final k = wrap(t - g0, _duration) / 0.24;
      if (k < 1.0) {
        final sk = math.sin(math.pi * k);
        sparkle(p, x - 2, y - 1, 1.0 + 2.5 * sk, e[3], e[2], 0.4 * sk);
      }
    }
  },
);
