import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart' hide star;

import 'impacts_lib.dart';

final SimulatedEffect parryEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'impacts/parry',
    name: 'Parry',
    desc:
        'Two blades clash: their edges flash in an X, a white four-point star rings out, a ring breaks into arcs and a fan of gold sparks sprays up and rains down.',
    category: 'impacts',
    tags: [
      'impact',
      'parry',
      'block',
      'clash',
      'sword',
      'metal',
      'sparks',
      'one-shot',
    ],
    size: (200, 112),
    origin: (100, 96),
    duration: 1.0,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#2a1a08',
        '#6a4410',
        '#b07a1a',
        '#e8b030',
        '#ffe066',
        '#fff6c4',
        '#ffffff',
      ],
      'height': 30,
      'seed': 11,
    },
  ),
  onCreate: (o) => _ParrySim(o),
);

class _ParrySim extends BaseEffectSim {
  static double _floor(double _) => 0.0;

  final List<int> c;
  final Rng r;
  final double x = 0.0;
  final double y;
  late final Particles ps;
  final Lights lights = Lights();
  late final List<ImpactSpike> sp;
  late final List<RingSeg> segs;
  late final List<double> edges;
  double t = 0.0;

  _ParrySim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        r = Rng(o.seed),
        y = -o.numOpt('height', 30.0) {
    ps = Particles(rng: r, ground: _floor, sparks: [c[4], c[4], c[3], c[2]]);
    sp = List<ImpactSpike>.generate(8, (i) {
      return ImpactSpike(
        a: (i * math.pi) / 4.0 + r.range(-0.04, 0.04),
        len: i.isOdd
            ? r.range(6.0, 8.0)
            : (i % 4 == 0 ? r.range(19.0, 22.0) : r.range(14.0, 17.0)),
        w: i.isOdd ? 1.2 : 2.2,
      );
    });
    segs = List<RingSeg>.generate(
      6,
      (i) => RingSeg(
        a: (i / 6) * tau + r.range(-0.1, 0.1),
        gap: r.range(0.55, 0.8),
        dr: r.range(0.1, 0.35),
      ),
    );
    edges = [
      -0.62 + r.range(-0.08, 0.08),
      math.pi + 0.62 + r.range(-0.08, 0.08),
    ];

    lights.add(x, y, 60.0, c[4], 0.65, 0.4);
    lights.add(x, y, 22.0, kWhite, 0.8, 0.08);

    for (var i = 0; i < 24; i++) {
      final s = i.isOdd ? 1 : -1;
      final a = -math.pi / 2.0 + s * r.range(0.3, 1.3);
      final v = r.range(130.0, 290.0);
      ps.spawn(
        P.spark,
        x + s * r.range(1.0, 3.0),
        y,
        math.cos(a) * v,
        math.sin(a) * v,
        r.range(0.45, 0.85),
        kWhite,
        1.0,
        i > 17 ? r.range(0.02, 0.07) : 0.0,
      );
    }
    for (var i = 0; i < 8; i++) {
      final a = r.range(0.0, tau);
      final v = r.range(40.0, 110.0);
      ps.spawn(
        P.mote,
        x,
        y,
        math.cos(a) * v,
        math.sin(a) * v - 20.0,
        r.range(0.3, 0.55),
        r.pick([c[5], c[6]]),
        0.6,
        r.range(0.0, 0.04),
      );
    }
    for (var i = 0; i < 3; i++) {
      final a = r.range(0.0, tau);
      final d = r.range(12.0, 26.0);
      ps.spawn(
        P.star,
        x + math.cos(a) * d,
        y + math.sin(a) * d,
        0.0,
        -3.0,
        r.range(0.22, 0.34),
        kWhite,
        r.range(1.6, 2.6),
        r.range(0.1, 0.3),
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    final u = (t - 0.03) / 0.36;
    if (u >= 0.0 && u < 1.0) {
      final rad = 8.0 + 24.0 * Ease.outCubic(u);
      final brk = smooth(0.15, 0.6, u);
      final idx = u < 0.15 ? 6 : (u < 0.35 ? 5 : (u < 0.6 ? 4 : 3));
      brokenRing(
        p,
        x,
        y,
        rad,
        math.max(1.0, 2.6 * math.pow(1.0 - u, 1.2)),
        segs,
        brk,
        c[idx],
        c[math.max(2, idx - 2)],
        u < 0.6 ? 1.0 : (1.0 - u) / 0.4,
        1.0,
        0.0,
      );
      if (u < 0.5) {
        p.glowRing(x, y, rad, 5.0, c[4], 0.3 * (1.0 - u / 0.5));
      }
    }

    ps.draw(p);

    if (t < 0.058) {
      for (final a in edges) {
        final ca = math.cos(a);
        final sa = math.sin(a);
        final l = t < 0.025 ? 26.0 : 32.0;
        final k = t < 0.025 ? 1.0 : 0.6;
        for (var d = -l; d <= l; d += 0.5) {
          final q = d.abs() / l;
          p.dot(
            x + ca * d,
            y + sa * d,
            q < 0.4 ? kWhite : (q < 0.75 ? c[5] : c[4]),
            q < 0.6 ? 1.0 : k * (1.3 - q),
          );
        }
        p.glowLine(
          x - ca * l,
          y - sa * l,
          x + ca * l,
          y + sa * l,
          4.0,
          c[5],
          0.35 * k,
        );
      }
    }

    if (t < 0.025) {
      star(p, x, y, sp, 1.0, 1.0, [c[4], kWhite, kWhite, kWhite], 1.0, 2.6);
    } else if (t < 0.058) {
      star(p, x, y, sp, 1.25, 0.65, [c[2], c[5], c[6], kWhite], 1.0, 2.6);
    } else if (t < 0.092) {
      star(p, x, y, sp, 1.4, 0.3, [c[2], c[4], c[5], c[6]], 1.0, 2.0);
    }

    final pop = math.exp(-t / 0.05);
    if (pop > 0.02) {
      p.glow(x, y, 30.0, c[4], 0.5 * pop);
      p.glow(x, y, 10.0, kWhite, 0.4 * pop);
    }
    lights.draw(p);
  }
}
