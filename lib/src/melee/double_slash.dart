// The crescent, trace, glint and spark recipe is adapted from Sprite Fusion's open-source slash
// (https://www.spritefusion.com/pixel-art-vfx/slash), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'melee_lib.dart';

final Pose _stance = kReady.copyWith(weapon: 'sword', fx: 12, fy: -21, sa: -0.85);
final Pose _high = _stance.copyWith(
  x: -7,
  crouch: 4,
  lean: -4,
  fx: -7,
  fy: -35,
  sa: -2.65,
  bx: 9,
  by: -25,
  armsFront: true,
  ffx: 9,
  fbx: -8,
);
final Pose _low = _stance.copyWith(
  x: 3,
  crouch: 6,
  lean: 6,
  fx: 22,
  fy: -20,
  sa: 0.62,
  bx: -8,
  by: -24,
  ffx: 13,
  fbx: -10,
  toeB: true,
);

const double _kUp = 0.14;
const double _kR0 = 62.0;
const double _kClose = _kUp + 0.012;
const double _kX = 34.0;
const double _kY = -23.0;

typedef _SliverSpec = ({double a, double r, double v, double arc});

class _DoubleSlashSim extends BaseEffectSim {
  final List<int> c;
  final Rng rg;
  late final Particles ps;
  final Lights lights = Lights();
  late final Swing down;
  late final Swing up;
  late final List<SwingPoint> ends;
  late final List<_SliverSpec> slivers;
  double t = 0.0;
  bool cut1 = false;
  bool cut2 = false;
  bool closed = false;

  _DoubleSlashSim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        rg = Rng(o.seed) {
    ps = Particles(
      rng: rg,
      ground: (_) => 0.0,
      sparks: (o['sparks'] as List).cast<Object>(),
    );
    down = through(
      _kX,
      _kY,
      0.72,
      1.0,
      _kR0,
      0.84,
      at: 0.55,
      w: 10.0,
      t0: 0.0,
      sweep: 0.06,
      hold: 0.07,
      trail: 0.24,
      ramp: c,
      lens: true,
    );
    up = through(
      _kX,
      _kY,
      -0.66,
      -1.0,
      _kR0,
      0.84,
      at: 0.55,
      w: 11.0,
      t0: _kUp,
      sweep: 0.06,
      hold: 0.06,
      trail: 0.26,
      ramp: c,
      lens: true,
    );
    ends = [slashEnd(down), slashEnd(up)];
    slivers = [
      for (final a in const [-2.4, -1.1, 0.2, 1.6])
        (
          a: a + rg.range(-0.2, 0.2),
          r: rg.range(5.0, 8.0),
          v: rg.range(70.0, 120.0),
          arc: rg.range(0.4, 0.7),
        ),
    ];
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (!cut1 && t >= down.sweep) {
      cut1 = true;
      shavings(ps, rg, down, 10, [c[4], c[5]]);
      for (var i = 0; i < 6; i++) {
        final a = math.atan2(ends[0].dy, ends[0].dx) + rg.range(-0.5, 0.5);
        final sp = rg.range(120.0, 300.0);
        ps.spawn(
          P.spark,
          ends[0].x,
          ends[0].y,
          math.cos(a) * sp,
          math.sin(a) * sp,
          rg.range(0.12, 0.3),
        );
      }
    }
    if (!closed && t >= _kClose) {
      closed = true;
      lights.add(_kX, _kY, 56.0, c[3], 0.45, 0.4);
      lights.add(_kX, _kY, 18.0, kWhite, 0.6, 0.08);
      for (var i = 0; i < 18; i++) {
        final a = rg.range(-math.pi, math.pi) * 0.8;
        final sp = rg.range(140.0, 360.0);
        ps.spawn(
          P.spark,
          _kX,
          _kY,
          math.cos(a) * sp,
          math.sin(a) * sp - 40.0,
          rg.range(0.14, 0.4),
        );
      }
      for (var i = 0; i < 5; i++) {
        ps.spawn(
          P.star,
          _kX + rg.range(-14.0, 14.0),
          _kY + rg.range(-12.0, 12.0),
          0.0,
          -4.0,
          rg.range(0.2, 0.4),
          rg.chance(0.5) ? c[5] : kWhite,
          rg.range(1.0, 2.2),
          rg.range(0.05, 0.2),
        );
      }
    }
    if (!cut2 && t >= _kUp + up.sweep) {
      cut2 = true;
      shavings(ps, rg, up, 12, [c[4], c[5]]);
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    final flash = t >= _kClose && t < _kClose + 0.07 ? 1.0 : 0.0;
    down.hot = up.hot = flash;
    slash(p, down, t);
    slash(p, up, t);
    for (final (s, e) in [(down, ends[0]), (up, ends[1])]) {
      final g = t - s.t0 - s.sweep * 0.6;
      if (g > 0.0 && g < 0.2) {
        sparkle(
          p,
          e.x,
          e.y,
          7.0 * Ease.outBack(math.min(1.0, g / 0.05)) * (1.0 - g / 0.2),
          c[5],
          c[3],
          0.5,
        );
      }
    }
    final q = t - _kClose;
    if (q >= 0.0 && q < 0.26) {
      final k = q / 0.26;
      flare(p, _kX, _kY, 22.0 * math.pow(1.0 - k, 1.4), 1.0 - k, c);
      p.glow(_kX, _kY, 34.0, c[4], 0.35 * (1.0 - k));
    }
    if (q >= 0.03 && q < 0.15) {
      final k = (q - 0.03) / 0.12;
      for (final s in slivers) {
        sliver(
          p,
          _kX,
          _kY,
          s.a,
          s.r + s.v * (q - 0.03),
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
    for (final s in [down, up]) {
      final u = t - s.t0;
      if (u <= 0.0 || u >= 0.25) continue;
      final e = slashEnd(
        s.copyWith(span: s.span * Ease.outExpo(clamp(u / s.sweep))),
      );
      p.glow(e.x, e.y, 40.0, c[3], 0.5 * (1.0 - u / 0.25));
    }
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect doubleSlashEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'melee/double-slash',
    name: 'Double slash',
    desc:
        'A down cut, then an up cut that crosses it: the moment the X closes both strokes flash white, the crossing bursts with light and sparks, and a dotted X lingers.',
    category: 'melee',
    tags: [
      'melee',
      'slash',
      'combo',
      'sword',
      'cross',
      'combat',
      'directional',
      'one-shot',
    ],
    size: (164, 108),
    origin: (44, 92),
    duration: 0.8,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#2a0a22',
        '#5e1238',
        '#a01f4e',
        '#e0386a',
        '#ff86a6',
        '#ffd2dd',
        '#ffffff',
      ],
      'sparks': ['#fff3a6', '#ffe26b', '#ff8a2a', '#f2561d'],
      'seed': 6,
    },
  ),
  act: ActSpec(
    target: const TargetSpec(x: 62),
    poses: [
      PoseKey(-0.42, _stance.copyWith(x: -7)),
      PoseKey(-0.18, _high),
      PoseKey(-0.04, _high.copyWith(crouch: 5)),
      PoseKey(
        0.0,
        _stance.copyWith(
          x: 0,
          crouch: 2,
          lean: 3,
          fx: 16,
          fy: -37,
          sa: -1.45,
          bx: -7,
          by: -24,
          ffx: 11,
          fbx: -9,
          ghost: 1,
        ),
        PoseEase.snap,
      ),
      PoseKey(0.06, _low, PoseEase.snap),
      PoseKey(
        0.14,
        _low.copyWith(x: 4, crouch: 6, lean: 5, fx: 20, fy: -17, sa: 0.85, ghost: 1),
      ),
      PoseKey(
        0.17,
        _low.copyWith(
          x: 5,
          crouch: 3,
          lean: 5,
          fx: 22,
          fy: -28,
          sa: 0.1,
          by: -18,
          toeB: true,
          ghost: 1,
        ),
        PoseEase.snap,
      ),
      PoseKey(
        0.21,
        _low.copyWith(
          x: 6,
          crouch: 1,
          lean: 6,
          fx: 19,
          fy: -37,
          sa: -0.95,
          by: -18,
          ffx: 13,
          fby: -6,
        ),
        PoseEase.snap,
      ),
      PoseKey(
        0.5,
        _low.copyWith(
          x: 6,
          crouch: 3,
          lean: 3,
          fx: 18,
          fy: -36,
          sa: -1.05,
          by: -19,
          ffx: 12,
        ),
      ),
      PoseKey(0.92, _stance.copyWith(x: -7)),
    ],
    hits: const [
      HitSpec(t: 0.06, stop: 0.05, shake: 0.08, amp: 1, push: 1.4, straw: 8),
      HitSpec(
        t: 0.16,
        stop: 0.14,
        shake: 0.2,
        amp: 2,
        push: 2.8,
        straw: 18,
        y: -28,
      ),
    ],
    dust: const [
      DustSpec(t: 0.06, x: 16, n: 5, dir: 1),
      DustSpec(t: 0.17, x: -8, n: 4, dir: -1),
    ],
  ),
  onCreate: (o) => _DoubleSlashSim(o),
);
