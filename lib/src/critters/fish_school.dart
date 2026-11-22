import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'critters_lib.dart';

const double _duration = 4.8;
final CritterGrid _grid = CritterGrid(-28, -12, 34, 24);

const List<(double, double, double, bool, double)> _school = [
  (-34, -16, 0.72, true, 0.1),
  (2, -20, 0.68, true, 0.55),
  (30, -10, 0.7, true, 0.3),
  (-22, 4, 1.0, false, 0.8),
  (12, -4, 1.0, false, 0.2),
  (-40, -2, 0.95, false, 0.45),
  (26, 14, 0.96, false, 0.65),
];

void _fish(
  CritterGrid g,
  List<int> c,
  List<int> sp,
  double s,
  double t,
  double ph,
  double dart,
) {
  g.clear();
  final len = 15.0 * s;
  final h = 8.0 * s;
  final beats = 12.0 + (dart > 0.0 ? 6.0 : 0.0);
  final w = (t / _duration) * tau * beats + ph * tau;
  final amp = (1.3 + 1.2 * dart) * s;

  double bend(double u) => amp * math.pow(u, 1.8) * math.sin(w - 4.0 * u);
  double prof(double u) => u < 0.3
      ? math.sqrt(u / 0.3)
      : 1.0 - math.pow((u - 0.3) / 0.7, 1.5) * 0.72;
  double hh(double u) => (h / 2.0) * prof(u);

  g.shade(-len, -h, 0, h, (x, y, _) {
    final u = -x / len;
    if (u < 0.0 || u > 1.0) return 0;
    final dy = y - bend(u);
    final hu = hh(u);
    if (dy.abs() > hu) return 0;
    final v = dy / hu;
    if (v > -0.12 && v < 0.12 && u > 0.22 && u < 0.92) {
      return u < 0.3 ? sp[1] : sp[v < 0.0 ? 2 : 1];
    }
    if (v < -0.6) return (u < 0.5 && v < -0.8) ? c[3] : c[2];
    if (v < -0.12) return c[3];
    if (v < 0.5) return c[4];
    return v > 0.86 ? c[4] : c[5];
  });

  final tb = bend(1.0);
  final ta = math.atan(amp * 1.8 * 0.9 * math.cos(w - 4.0)) * 0.8;
  final tl = 6.0 * s;
  final hb = hh(1.0);
  (double, double) rot(double dx, double dy) => (
        -(len + dx * math.cos(ta) - dy * math.sin(ta)),
        tb + dx * math.sin(ta) + dy * math.cos(ta),
      );

  g.polyFn(
    [
      rot(-0.5, -hb),
      rot(tl, -hb - 3.4 * s),
      rot(tl * 0.62, 0.0),
      rot(tl, hb + 3.4 * s),
      rot(-0.5, hb),
    ],
    (_, y) => y < tb - 1.0 ? c[4] : c[3],
    0.88,
  );

  const d0 = 0.34;
  const d1 = 0.66;
  g.polyFn(
    [
      (-d0 * len, bend(d0) - hh(d0) + 0.5),
      (-(d0 + 0.08) * len, bend(d0) - hh(d0) - 3.6 * s),
      (-d1 * len, bend(d1) - hh(d1) + 0.5),
    ],
    (x, _) => roundJs(x) % 2 != 0 ? c[3] : c[4],
    0.85,
  );

  final pf = math.sin(w * 0.5) * 1.2;
  g.set(-0.34 * len, bend(0.34) + 1.5 * s + pf * 0.3, c[4], 0.85);
  g.set(-0.34 * len - 1.0, bend(0.34) + 2.0 * s + pf * 0.6, c[4], 0.85);
  for (var y = -2; y <= 1; y++) {
    g.set(-0.26 * len, bend(0.26) + y * s, c[2]);
  }
  final ex = -0.13 * len - 1.0;
  final ey = bend(0.13) - 0.25 * h;
  g.set(ex, ey, c[0]);
  g.set(ex + 1.0, ey, c[0]);
  g.set(ex, ey + 1.0, c[1]);
  g.set(ex + 1.0, ey + 1.0, c[0]);
  g.set(ex + 1.0, ey, c[6]);
  g.outline(c[0]);
}

({double x, double y, double dart}) _place(
  (double, double, double, bool, double) f,
  int i,
  double t,
) {
  final (bx, by, _, _, ph) = f;
  final a = (t / _duration) * tau;
  final dt = wrap(t - (i * 0.71 * _duration).remainder(_duration), _duration);
  final dart = i == 4
      ? (dt < 0.25
          ? Ease.outCubic(dt / 0.25)
          : (dt < 1.6 ? 1.0 - Ease.inOutSine((dt - 0.25) / 1.35) : 0.0))
      : 0.0;
  return (
    x: bx + 3.0 * math.sin(a + ph * tau) + 8.0 * dart,
    y: by + 1.8 * math.sin(2.0 * a + ph * 5.0),
    dart: (i == 4 && dt < 0.6) ? 1.0 - dt / 0.6 : 0.0,
  );
}

void _caustics(Painter p, List<int> c, double t) {
  final a = (t / _duration) * tau;
  for (var y = -38; y < 38; y++) {
    for (var x = -66; x < 66; x++) {
      final fall =
          clamp(1.0 - ((x / 64.0) * (x / 64.0) + (y / 40.0) * (y / 40.0))) *
              (0.6 + 0.4 * clamp(-y / 40.0 + 0.6));
      if (fall <= 0.0) continue;
      final u = x * 0.16 + 1.9 * math.sin(y * 0.12 + a);
      final v = y * 0.19 + 1.9 * math.sin(x * 0.1 - a);
      final n1 = math.sin(u) + math.sin(v);
      final sh = 0.75 + 0.25 * math.sin(x * 0.05 - y * 0.04 + 2.0 * a);
      final f = math.max(0.0, 1.0 - n1.abs() * 5.0) * fall * sh;
      if (f > 0.55) {
        p.light(x, y, c[4], 0.3);
      } else if (f > 0.25) {
        p.light(x, y, c[3], 0.14);
      }
    }
  }
}

final PureEffect fishSchoolEffect = PureEffect(
  meta: const EffectMeta(
    id: 'critters/fish-school',
    name: 'Fish school',
    desc:
        'A school of fish holds station in two depth rows: bodies wag into swinging tails, one darts ahead now and then, bubbles rise and caustic light ripples over them.',
    category: 'critters',
    tags: ['critter', 'fish', 'school', 'sea', 'underwater', 'swim', 'loop'],
    size: (136, 80),
    origin: (68, 40),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#0a1a2a',
        '#123552',
        '#1d5a7e',
        '#2f8aa8',
        '#62bccc',
        '#bfe8e6',
        '#f4fff8',
      ],
      'stripe': ['#5a1e14', '#d8582a', '#ffa04a'],
      'seed': 1,
    },
  ),
  onDraw: (p, time, o) {
    final seed = o.seed;
    final t = shift(time, _duration, seed);
    final c = fit(o.palette, 7);
    final sp = fit(o.rampOpt('stripe'), 3);
    final g = _grid;

    for (final (x0, w, ph) in const [
      (-30.0, 10.0, 0.0),
      (14.0, 7.0, 2.1),
      (44.0, 12.0, 4.0),
    ]) {
      final sw = math.sin((t / _duration) * tau + ph) * 4.0;
      p.glowLine(x0 + sw - 12.0, -40, x0 + sw + 8.0, 40, w, c[4], 0.05);
    }

    for (final back in const [true, false]) {
      for (var i = 0; i < _school.length; i++) {
        final f = _school[i];
        if (f.$4 != back) continue;
        final pos = _place(f, i, t);
        _fish(g, c, sp, f.$3, t, f.$5, pos.dart);
        if (back) {
          g.recolor((_, _, col, _, _) => mix(col, c[1], 0.42));
        }
        g.draw(p, 1.0, pos.x, pos.y);
      }
    }

    cycle(t, _duration, 9, seed * 13 + 1, (r) => r.range(1.6, 2.6),
        (age, len, r, i) {
      final idx = i % _school.length;
      final f = _school[idx];
      final pos = _place(f, idx, wrap(t - age, _duration));
      final rad = r.range(0.6, 1.6) * f.$3;
      final ph = r.next() * tau;
      final x = pos.x +
          1.0 +
          math.sin(age * (4.0 + 2.0 / rad) + ph) * (0.5 + rad * 0.7);
      final y = pos.y - 1.0 - (16.0 + 12.0 * rad) * age;
      if (y < -38.0) return;
      bubble(
        p,
        x,
        y,
        rad,
        [c[6], c[5], c[4], c[3]],
        math.min(
          1.0,
          math.min(age * 4.0, math.min((len - age) * 3.0, (y + 38.0) / 4.0)),
        ),
      );
    });

    _caustics(p, c, t);
    p.glow(0, -8, 74, c[2], 0.2);
    p.glow(-6, -18, 40, c[3], 0.1);
  },
);
