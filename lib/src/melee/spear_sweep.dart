// The crescent, trace and glint recipe is adapted from Sprite Fusion's open-source slash, and the rolling dust and
// grit from his explosion (https://www.spritefusion.com/pixel-art-vfx), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'melee_lib.dart';

final Pose _rest = kReady.copyWith(
  weapon: 'spear',
  sa: -1.42,
  fx: 11,
  fy: -21,
  bx: 7,
  by: -16,
);

final Pose _cock = _rest.copyWith(
  two: true,
  yaw: 2.5,
  crouch: 6,
  lean: 2,
  fx: 15,
  fy: -17,
  sa: 0.05,
  ffx: 9,
  fbx: -8,
);

final Pose _out = _rest.copyWith(
  two: true,
  x: 2,
  crouch: 6,
  lean: 6,
  fx: 20,
  fy: -15,
  sa: 0.04,
  ffx: 12,
  fbx: -10,
  toeB: true,
);

class _SpearSweepSim extends BaseEffectSim {
  final List<int> c;
  final Rng rg;
  final StoneColors st;
  late final Particles ps;
  final Lights lights = Lights();
  late final Swing a;
  late final SwingPoint end;
  double t = 0.0;
  double lastU = 0.0;
  bool done = false;

  _SpearSweepSim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        rg = Rng(o.seed),
        st = stone(o['stone'] ?? '#4a3f69') {
    ps = Particles(
      rng: rg,
      ground: (_) => 0.0,
      sparks: (o['sparks'] as List).cast<Object>(),
    );
    a = Swing(
      cx: 2.0,
      cy: -12.0,
      r: 50.0,
      sy: 0.2,
      k: 0.19,
      rot: -0.04,
      a0: math.pi + 0.55,
      dir: -1.0,
      span: math.pi + 0.35,
      w: 19.0,
      t0: 0.0,
      sweep: 0.13,
      hold: 0.05,
      trail: 0.3,
      ramp: c,
    );
    end = slashEnd(a);
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    final uEnd = a.span * Ease.outExpo(clamp(t / a.sweep));
    for (var u = lastU; u < uEnd; u += 0.09) {
      final tr = swingTravel(a, u);
      final near = math.sin(tr.a) >= 0.0;
      final fy = near ? -1.0 : -3.0;
      final sp = rg.range(30.0, 90.0);
      ps.spawn(
        P.smoke,
        tr.x,
        fy - rg.range(0.0, 2.0),
        tr.dx * sp,
        -rg.range(4.0, 16.0),
        rg.range(0.7, 1.15),
        st.dust,
        rg.range(3.0, 5.5),
        rg.range(0.0, 0.05),
      );
      if (rg.chance(0.6)) {
        ps.spawn(
          P.grit,
          tr.x,
          fy,
          tr.dx * rg.range(40.0, 120.0) + rg.range(-20.0, 20.0),
          -rg.range(40.0, 130.0),
          rg.range(0.6, 1.0),
          rg.pick([st.light, st.body, st.shade]),
          rg.chance(0.3) ? 2.0 : 1.0,
        );
      }
      if (rg.chance(0.35)) {
        ps.spawn(
          P.mote,
          tr.x,
          tr.y,
          tr.dx * rg.range(40.0, 100.0),
          tr.dy * 40.0 - rg.range(5.0, 20.0),
          rg.range(0.2, 0.4),
          rg.chance(0.5) ? c[4] : c[5],
          0.6,
          0.0,
          near ? 0 : PF.back,
        );
      }
    }
    lastU = uEnd;
    if (!done && t >= a.sweep) {
      done = true;
      lights.add(end.x, end.y - 4.0, 50.0, c[3], 0.5, 0.35);
      for (var i = 0; i < 8; i++) {
        final ang = math.atan2(end.dy, end.dx) + rg.range(-0.5, 0.3);
        final sp = rg.range(120.0, 260.0);
        ps.spawn(
          P.spark,
          end.x,
          end.y,
          math.cos(ang) * sp,
          math.sin(ang) * sp - 40.0,
          rg.range(0.12, 0.3),
        );
      }
      for (var i = 0; i < 6; i++) {
        ps.spawn(
          P.smoke,
          end.x + rg.range(-6.0, 4.0),
          -rg.range(1.0, 4.0),
          rg.range(30.0, 90.0),
          -rg.range(4.0, 14.0),
          rg.range(0.9, 1.25),
          st.dust,
          rg.range(4.5, 7.0),
          rg.range(0.0, 0.08),
          PF.big,
        );
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    slash(p, a, t, -1);
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    slash(p, a, t, 1);
    final g = t - a.sweep * 0.6;
    if (g > 0.0 && g < 0.24) {
      sparkle(
        p,
        end.x,
        end.y,
        9.0 * Ease.outBack(math.min(1.0, g / 0.05)) * (1.0 - g / 0.24),
        c[5],
        c[3],
        0.55,
      );
    }
    if (t < a.sweep + 0.12) {
      final (x, y) = onSwing(a, a.r - 5.0, a.span * Ease.outExpo(clamp(t / a.sweep)));
      p.glow(x, y, 36.0, c[3], 0.45 * (1.0 - t / (a.sweep + 0.12)));
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect spearSweepEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'melee/spear-sweep',
    name: 'Spear sweep',
    desc:
        'A wide low sweep at shin height: a long flat crescent swings from behind the legs round the front, and the wind of it kicks a wake of dust and grit along the floor.',
    category: 'melee',
    tags: [
      'melee',
      'sweep',
      'spear',
      'polearm',
      'low',
      'aoe',
      'ground',
      'dust',
      'combat',
      'one-shot',
    ],
    size: (216, 84),
    origin: (104, 70),
    duration: 1.5,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#0f2a2a',
        '#18504a',
        '#22806e',
        '#3fb894',
        '#8fe6c0',
        '#dcfff0',
        '#ffffff',
      ],
      'sparks': ['#fff3a6', '#ffe26b', '#ff8a2a', '#f2561d'],
      'stone': '#4a3f69',
      'seed': 10,
    },
  ),
  act: ActSpec(
    target: const TargetSpec(x: 62),
    poses: [
      PoseKey(-0.56, _rest),
      PoseKey(
        -0.34,
        _rest.copyWith(two: true, crouch: 4, fx: 14, fy: -22, sa: -0.7),
      ),
      PoseKey(-0.14, _cock),
      PoseKey(-0.02, _cock.copyWith(crouch: 7, yaw: 2.7)),
      PoseKey(0.045, _out.copyWith(x: 1, yaw: 1.3, ghost: 1), PoseEase.snap),
      PoseKey(0.09, _out.copyWith(ghost: 1), PoseEase.snap),
      PoseKey(0.14, _out, PoseEase.snap),
      PoseKey(0.62, _out.copyWith(crouch: 5, lean: 5)),
      PoseKey(
        1.12,
        _rest.copyWith(two: true, crouch: 4, sa: -0.7, fx: 14, fy: -22),
      ),
      PoseKey(1.5, _rest),
    ],
    hits: const [
      HitSpec(
        t: 0.1,
        stop: 0.12,
        shake: 0.18,
        amp: 2,
        push: 2.6,
        straw: 18,
        y: -12,
      ),
    ],
    dust: const [
      DustSpec(t: 0.09, x: 14, n: 6, dir: 1),
      DustSpec(t: 0.09, x: -10, n: 5, dir: -1),
    ],
  ),
  onCreate: (o) => _SpearSweepSim(o),
);
