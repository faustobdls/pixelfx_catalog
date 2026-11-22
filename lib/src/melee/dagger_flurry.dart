// The crescent, trace, glint and spark recipe is adapted from Sprite Fusion's open-source slash
// (https://www.spritefusion.com/pixel-art-vfx/slash), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'melee_lib.dart';

final Pose _base = kReady.copyWith(
  weapon: 'dagger',
  offWeapon: 'dagger',
  sa: -0.5,
  sb: -0.9,
  crouch: 4,
  lean: 3,
  ffx: 11,
  fbx: -9,
  fx: 12,
  fy: -24,
  bx: 9,
  by: -24,
);

Pose _near(double fx, double fy, double sa, {double? x, int? ghost}) =>
    _base.copyWith(
      fx: fx,
      fy: fy,
      sa: sa,
      bx: 4,
      by: -24,
      sb: -1,
      x: x,
      ghost: ghost,
    );

Pose _far(double bx, double by, double sb, {double? x}) => _base.copyWith(
      bx: bx,
      by: by,
      sb: sb,
      fx: 1,
      fy: -23,
      sa: -1,
      x: x,
    );

const double _kEvery = 0.055;
const List<(double, double, double, double)> _kCuts = [
  (21.0, -27.0, -0.5, 1.0),
  (33.0, -16.0, 0.9, -1.0),
  (26.0, -38.0, 2.4, 1.0),
  (37.0, -30.0, -1.8, -1.0),
  (19.0, -17.0, 0.2, 1.0),
  (30.0, -24.0, 1.4, -1.0),
];

typedef _SliverSpec = ({double a, double r, double v, double arc});

class _DaggerFlurrySim extends BaseEffectSim {
  final List<int> c;
  final Rng rg;
  late final Particles ps;
  final Lights lights = Lights();
  late final Swing big;
  late final List<Swing> all;
  late final List<SwingPoint> ends;
  late final List<bool> done;
  late final List<_SliverSpec> slivers;
  double t = 0.0;

  _DaggerFlurrySim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        rg = Rng(o.seed) {
    ps = Particles(
      rng: rg,
      ground: (_) => 0.0,
      sparks: (o['sparks'] as List).cast<Object>(),
    );
    final small = <Swing>[];
    for (var i = 0; i < _kCuts.length; i++) {
      final (x, y, rot, dir) = _kCuts[i];
      small.add(
        Swing(
          cx: x,
          cy: y,
          r: rg.range(12.0, 15.0),
          sy: rg.range(0.55, 0.75),
          rot: rot,
          a0: rg.range(-2.8, -2.2),
          dir: dir,
          span: rg.range(2.3, 2.8),
          w: rg.range(5.2, 6.4),
          t0: i * _kEvery,
          sweep: 0.035,
          hold: 0.03,
          trail: 0.13,
          ramp: c,
        ),
      );
    }
    big = Swing(
      cx: 24.0,
      cy: -26.0,
      r: 30.0,
      sy: 0.36,
      k: 0.24,
      rot: 0.12,
      a0: 3.0,
      dir: -1.0,
      span: 2.85,
      w: 11.0,
      t0: small.length * _kEvery + 0.04,
      sweep: 0.055,
      hold: 0.06,
      trail: 0.24,
      ramp: c,
    );
    all = [...small, big];
    ends = all.map(slashEnd).toList();
    done = List<bool>.filled(all.length, false);
    slivers = [
      for (final a in const [-2.6, -1.5, -0.4, 0.7])
        (
          a: a + rg.range(-0.2, 0.2),
          r: rg.range(4.0, 7.0),
          v: rg.range(70.0, 110.0),
          arc: rg.range(0.4, 0.7),
        ),
    ];
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    for (var i = 0; i < all.length; i++) {
      final s = all[i];
      if (done[i] || t < s.t0 + s.sweep) continue;
      done[i] = true;
      final e = ends[i];
      final last = identical(s, big);
      lights.add(
        e.x,
        e.y,
        last ? 56.0 : 26.0,
        c[3],
        last ? 0.6 : 0.4,
        last ? 0.4 : 0.14,
      );
      if (last) lights.add(e.x, e.y, 16.0, kWhite, 0.7, 0.08);
      for (var k = 0; k < (last ? 12 : 3); k++) {
        final a = math.atan2(e.dy, e.dx) + rg.range(-0.5, 0.5);
        final sp = rg.range(100.0, last ? 340.0 : 220.0);
        ps.spawn(
          P.spark,
          e.x,
          e.y,
          math.cos(a) * sp,
          math.sin(a) * sp,
          rg.range(0.1, last ? 0.35 : 0.22),
        );
      }
      shavings(ps, rg, s, last ? 14 : 4, [c[4], c[5]]);
      if (last) {
        for (var k = 0; k < 5; k++) {
          ps.spawn(
            P.star,
            s.cx + rg.range(-22.0, 22.0),
            s.cy + rg.range(-14.0, 14.0),
            0.0,
            -4.0,
            rg.range(0.2, 0.45),
            rg.chance(0.5) ? c[5] : kWhite,
            rg.range(1.0, 2.2),
            rg.range(0.05, 0.25),
          );
        }
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    for (final s in all) {
      slash(p, s, t);
    }
    for (var i = 0; i < all.length; i++) {
      final s = all[i];
      final e = ends[i];
      final g = t - s.t0 - s.sweep * 0.6;
      final last = identical(s, big);
      final life = last ? 0.24 : 0.12;
      if (g > 0.0 && g < life) {
        sparkle(
          p,
          e.x,
          e.y,
          (last ? 10.0 : 4.0) *
              Ease.outBack(math.min(1.0, g / 0.04)) *
              (1.0 - g / life),
          c[5],
          c[3],
          last ? 0.6 : 0.35,
        );
      }
      final u = t - s.t0;
      if (u > 0.0 && u < s.sweep + 0.1) {
        final h = slashEnd(
          s.copyWith(span: s.span * Ease.outExpo(clamp(u / s.sweep))),
        );
        p.glow(
          h.x,
          h.y,
          last ? 40.0 : 22.0,
          c[3],
          (last ? 0.5 : 0.35) * (1.0 - u / (s.sweep + 0.1)),
        );
      }
    }
    final q = t - big.t0 - big.sweep;
    if (q > 0.02 && q < 0.14) {
      final k = (q - 0.02) / 0.12;
      final e = ends.last;
      for (final s in slivers) {
        sliver(
          p,
          e.x,
          e.y,
          s.a + math.atan2(e.dy, e.dx),
          s.r + s.v * (q - 0.02),
          s.arc * (1.0 - 0.4 * k),
          k < 0.4
              ? c[6]
              : k < 0.7
                  ? c[5]
                  : c[4],
          1.0 - k,
        );
      }
    }
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect daggerFlurryEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'melee/dagger-flurry',
    name: 'Dagger flurry',
    desc:
        'A flurry of small quick crescents at every angle in front of the fighter, each with a flick of sparks, finished by one big cut that glints and bursts.',
    category: 'melee',
    tags: [
      'melee',
      'slash',
      'dagger',
      'combo',
      'flurry',
      'fast',
      'combat',
      'directional',
      'one-shot',
    ],
    size: (148, 104),
    origin: (36, 86),
    duration: 0.95,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#1b1630',
        '#3a2f63',
        '#6150a3',
        '#9480d8',
        '#c7b8f5',
        '#efe9ff',
        '#ffffff',
      ],
      'sparks': ['#ffffff', '#efe9ff', '#c7b8f5', '#9480d8'],
      'seed': 12,
    },
  ),
  act: ActSpec(
    target: const TargetSpec(x: 60),
    poses: [
      PoseKey(-0.4, _base.copyWith(x: -4)),
      PoseKey(
        -0.14,
        _base.copyWith(
          x: -6,
          lean: -2,
          crouch: 5,
          fx: 2,
          fy: -22,
          sa: -1.2,
          bx: 2,
          by: -26,
          sb: -1.5,
        ),
      ),
      PoseKey(
        -0.03,
        _base.copyWith(
          x: -6,
          lean: -3,
          crouch: 6,
          fx: 1,
          fy: -21,
          sa: -1.2,
          bx: 1,
          by: -25,
          sb: -1.5,
        ),
      ),
      PoseKey(0.0, _near(20, -31, -0.5, x: 2, ghost: 1), PoseEase.snap),
      PoseKey(0.055, _far(21, -23, 0.5, x: 3), PoseEase.snap),
      PoseKey(0.11, _near(18, -36, -1, x: 4), PoseEase.snap),
      PoseKey(0.165, _far(22, -31, -0.6, x: 5), PoseEase.snap),
      PoseKey(0.22, _near(20, -22, 0.2, x: 5), PoseEase.snap),
      PoseKey(0.275, _far(21, -27, 0.05, x: 6), PoseEase.snap),
      PoseKey(
        0.33,
        _base.copyWith(
          x: 4,
          lean: -3,
          crouch: 5,
          fx: -1,
          fy: -33,
          sa: -2.5,
          bx: 2,
          by: -23,
          sb: -1.2,
        ),
        PoseEase.snap,
      ),
      PoseKey(
        0.37,
        _base.copyWith(
          x: 7,
          lean: 2,
          crouch: 4,
          fx: 16,
          fy: -34,
          sa: -1,
          bx: -7,
          by: -24,
          sb: -2.4,
          ghost: 1,
        ),
        PoseEase.snap,
      ),
      PoseKey(
        0.43,
        _base.copyWith(
          x: 9,
          lean: 6,
          crouch: 6,
          fx: 22,
          fy: -23,
          sa: 0.15,
          bx: -9,
          by: -24,
          sb: -2.6,
          ffx: 13,
          fbx: -10,
          toeB: true,
        ),
        PoseEase.snap,
      ),
      PoseKey(
        0.68,
        _base.copyWith(
          x: 9,
          lean: 5,
          crouch: 5,
          fx: 21,
          fy: -22,
          sa: 0.2,
          bx: -8,
          by: -24,
          sb: -2.6,
        ),
      ),
      PoseKey(1.05, _base.copyWith(x: -4)),
    ],
    hits: const [
      HitSpec(t: 0.05, stop: 0.015, push: 0.5, straw: 3, flash: 0.02),
      HitSpec(t: 0.105, stop: 0.015, push: -0.3, straw: 3, flash: 0.02),
      HitSpec(t: 0.16, stop: 0.015, push: 0.5, straw: 3, flash: 0.02),
      HitSpec(t: 0.215, stop: 0.015, push: -0.3, straw: 3, flash: 0.02),
      HitSpec(t: 0.27, stop: 0.015, push: 0.5, straw: 3, flash: 0.02),
      HitSpec(t: 0.325, stop: 0.015, push: -0.3, straw: 3, flash: 0.02),
      HitSpec(t: 0.42, stop: 0.12, shake: 0.18, amp: 2, push: 2.6, straw: 16),
    ],
    dust: const [
      DustSpec(t: 0.43, x: 20, n: 7, dir: 1),
      DustSpec(t: 0.0, x: -6, n: 3, dir: -1),
    ],
  ),
  onCreate: (o) => _DaggerFlurrySim(o),
);
