import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart' hide star;

import 'impacts_lib.dart';

final SimulatedEffect critHitEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'impacts/crit-hit',
    name: 'Critical hit',
    desc:
        'A critical hit: a jagged starburst slams in white and overshoots, a ring breaks into flying arcs, sparks streak off, shards tumble to the floor under a big flare.',
    category: 'impacts',
    tags: [
      'impact',
      'hit',
      'crit',
      'critical',
      'combat',
      'directional',
      'one-shot',
    ],
    size: (216, 136),
    origin: (84, 106),
    duration: 0.9,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#2a0510',
        '#5c0a1c',
        '#a3142a',
        '#e0302c',
        '#ff7a2a',
        '#ffc23d',
        '#fff09a',
        '#ffffff',
      ],
      'height': 26,
      'aim': 0.12,
      'seed': 3,
    },
  ),
  onCreate: (o) => _CritHitSim(o),
);

class _StarKey {
  final double t;
  final double sc;
  final double th;
  final double a;
  final List<int> cols;

  const _StarKey(this.t, this.sc, this.th, this.a, this.cols);
}

const List<_StarKey> _keys = [
  _StarKey(0.0, 1.0, 1.0, 1.0, [6, 7, 7, 7]),
  _StarKey(0.025, 1.3, 1.0, 1.0, [2, 5, 6, 7]),
  _StarKey(0.058, 1.05, 0.72, 1.0, [2, 4, 5, 6]),
  _StarKey(0.092, 1.22, 0.3, 1.0, [1, 2, 3, 4]),
];
const double _keysEnd = 0.125;

void _lensFlare(Painter p, double x, double y, double l, double k, List<int> c) {
  final dirs = <(double, double, double)>[
    (1.0, 0.0, l),
    (0.0, 1.0, l * 0.45),
    (0.7, 0.7, l * 0.16),
    (0.7, -0.7, l * 0.16),
  ];
  for (final (dx, dy, len) in dirs) {
    for (final s in [-1.0, 1.0]) {
      for (var d = 1; d <= len; d++) {
        final u = d / len;
        final a = u < 0.7 ? 1.0 : k * (1.6 - u);
        p.dot(
          x + s * dx * d,
          y + s * dy * d,
          u < 0.35 ? kWhite : (u < 0.7 ? c[6] : c[5]),
          a,
        );
        if (dy == 0.0 && u < 0.42) {
          for (final e in [-1.0, 1.0]) {
            p.dot(
              x + s * d,
              y + e,
              u < 0.2 ? c[6] : c[5],
              u < 0.3 ? 1.0 : k,
            );
          }
        }
      }
    }
  }
  p.glowLine(x - l, y, x + l, y, 6.0, c[6], 0.5 * k);
  p.glowLine(x, y - l * 0.45, x, y + l * 0.45, 4.0, c[6], 0.3 * k);
}

class _CritHitSim extends BaseEffectSim {
  static double _floor(double _) => 0.0;

  final List<int> c;
  final Rng r;
  final double x = 0.0;
  final double y;
  final double aim;
  late final Particles ps;
  final Bits bits = Bits(ground: _floor);
  final Lights lights = Lights();
  late final List<ImpactSpike> sp;
  late final List<RingSeg> segs;
  double t = 0.0;

  _CritHitSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed),
        y = -o.numOpt('height', 26.0),
        aim = o.numOpt('aim', 0.12) {
    ps = Particles(rng: r, ground: _floor, sparks: [c[7], c[6], c[5], c[3]]);
    sp = spikes(
      r,
      14,
      aim,
      len: (11.0, 15.0),
      w: (1.8, 2.5),
      fwd: 1.4,
      back: 0.6,
      jag: 0.5,
    );
    final sorted = [...sp]..sort((a, b) => b.len.compareTo(a.len));
    for (var i = 0; i < 2 && i < sorted.length; i++) {
      sorted[i].len *= 1.3;
    }
    segs = List<RingSeg>.generate(7, (i) {
      final a = aim + (i / 7) * tau;
      return RingSeg(
        a: a,
        gap: r.range(0.55, 0.85),
        dr: r.range(0.08, 0.4) + 0.15 * math.max(0.0, math.cos(a - aim)),
        w: 0.7 + 0.5 * math.max(0.0, math.cos(a - aim)),
      );
    });

    lights.add(x, y, 84.0, c[5], 0.6, 0.5);
    lights.add(x, y, 30.0, kWhite, 0.7, 0.1);
    lights.add(x, -4.0, 44.0, c[4], 0.3, 0.45);

    for (var i = 0; i < 36; i++) {
      final back = r.chance(0.22);
      final a = (back ? aim + math.pi : aim) +
          r.range(-1.0, 1.0) * (back ? 0.6 : 0.8);
      final v = r.range(170.0, 430.0) * (back ? 0.6 : 1.0);
      ps.spawn(
        P.spark,
        x,
        y,
        math.cos(a) * v,
        math.sin(a) * v - 50.0,
        r.range(0.15, 0.5),
        kWhite,
        1.0,
        r.chance(0.3) ? r.range(0.0, 0.04) : 0.0,
      );
    }
    for (var i = 0; i < 10; i++) {
      final a = aim + r.range(-1.0, 1.0) * 1.1 - 0.35;
      final v = r.range(110.0, 280.0);
      bits.add(
        DebrisBit(
          kind: B.shard,
          x: x,
          y: y,
          vx: math.cos(a) * v,
          vy: math.sin(a) * v - 40.0,
          g: 0.8,
          drag: 0.7,
          bounce: 0.35,
          life: r.range(0.55, 0.85),
          a: r.range(0.0, tau),
          va: r.range(-25.0, 25.0),
          s: r.range(2.0, 4.5),
          c: r.pick([c[7], c[6], c[6], c[5]]),
        ),
      );
    }
    for (var i = 0; i < 12; i++) {
      final a = aim - math.pi / 2.0 + r.range(-1.4, 1.4);
      final v = r.range(35.0, 110.0);
      ps.spawn(
        P.mote,
        x + math.cos(a) * 4.0,
        y + math.sin(a) * 4.0,
        math.cos(a) * v,
        math.sin(a) * v - 15.0,
        r.range(0.35, 0.7),
        r.pick([c[6], c[5], c[5]]),
        0.6,
        r.range(0.0, 0.05),
      );
    }
    for (var i = 0; i < 5; i++) {
      final a = r.range(0.0, tau);
      final d = r.range(14.0, 34.0);
      ps.spawn(
        P.star,
        x + math.cos(a) * d,
        y + math.sin(a) * d * 0.8,
        0.0,
        -4.0,
        r.range(0.22, 0.38),
        r.chance(0.5) ? c[6] : kWhite,
        r.range(1.6, 3.0),
        r.range(0.08, 0.32),
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    ps.update(dt);
    bits.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    final u = clamp((t - 0.03) / 0.37);
    if (t >= 0.03 && u < 1.0) {
      final rad = 10.0 + 30.0 * Ease.outCubic(u);
      final brk = smooth(0.12, 0.6, u);
      final th = math.max(1.0, 3.6 * math.pow(1.0 - u, 1.2));
      final idx = u < 0.12
          ? 7
          : (u < 0.3 ? 6 : (u < 0.5 ? 5 : (u < 0.75 ? 4 : 3)));
      brokenRing(
        p,
        x,
        y,
        rad,
        th,
        segs,
        brk,
        c[idx],
        c[math.max(2, idx - 2)],
        u < 0.6 ? 1.0 : (1.0 - u) / 0.4,
        1.0,
        0.0,
      );
      if (u < 0.6) {
        p.glowRing(x, y, rad, 6.0, c[5], 0.35 * math.pow(1.0 - u / 0.6, 2));
      }
    }
    bits.draw(p);
    ps.draw(p);

    final f = (t - 0.04) / 0.28;
    if (f > 0.0 && f < 1.0) {
      _lensFlare(p, x, y, 64.0 * math.pow(1.0 - f, 1.3), 1.0 - f, c);
      p.glow(x, y, 56.0, c[5], 0.4 * (1.0 - f));
    }

    for (var i = 0; i < _keys.length; i++) {
      final key = _keys[i];
      final nextT = i + 1 < _keys.length ? _keys[i + 1].t : _keysEnd;
      if (t >= key.t && t < nextT) {
        star(
          p,
          x,
          y,
          sp,
          key.sc,
          key.th,
          [for (final j in key.cols) c[j]],
          key.a,
          2.6,
        );
      }
    }

    final pop = math.exp(-t / 0.05);
    if (pop > 0.02) {
      p.glow(x, y, 44.0, c[5], 0.4 * pop);
      p.glow(x, y, 12.0, kWhite, 0.6 * pop);
    }
    lights.draw(p);
  }
}
