// The crescent shading, cooling ramp, dotted trace, glint and spark recipe is adapted from Sprite Fusion's
// open-source slash (https://www.spritefusion.com/pixel-art-vfx/slash), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'melee_lib.dart';

final Pose _stance = kReady.copyWith(
  weapon: 'sword',
  fx: 12,
  fy: -21,
  sa: -0.85,
);

final Pose _wound = _stance.copyWith(
  crouch: 6,
  lean: -2,
  yaw: 1.1,
  fx: 13,
  fy: -20,
  sa: 0.3,
  bx: 6,
  by: -24,
  ffx: 8,
  fbx: -8,
);

final Pose _wide = _stance.copyWith(
  crouch: 5,
  lean: 3,
  fx: 21,
  fy: -21,
  sa: 0.05,
  bx: -9,
  by: -23,
  ffx: 11,
  fbx: -11,
);

const double _kSw = 0.17;
const double _kFlare = 0.3;
const double _kW = 16.0;
const double _kWe = 5.0;

double _turn(double t) => 1.0 - math.pow(1.0 - clamp(t / _kSw), 1.6);
double _passedAt(double f) => _kSw * (1.0 - math.pow(1.0 - clamp(f), 1.0 / 1.6));

class _SpinSlashSim extends BaseEffectSim {
  final List<int> c;
  late final int n;
  final Rng rg;
  late final Particles ps;
  final Lights lights = Lights();
  late final Swing a;
  late final Swing e;
  late final List<int> dim;
  double t = 0.0;
  bool closed = false;
  double lastU = 0.0;

  _SpinSlashSim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        rg = Rng(o.seed) {
    n = c.length;
    final r0 = o.numOpt('radius', 46.0);
    ps = Particles(
      rng: rg,
      ground: (_) => 0.0,
      sparks: (o['sparks'] as List).cast<Object>(),
    );
    a = Swing(
      cx: 0.0,
      cy: -17.0,
      r: r0,
      sy: 0.27,
      rot: -0.1,
      a0: 0.5,
      dir: -1.0,
      k: 0.15,
    );
    e = a.copyWith(r: r0 * 0.8, k: 0.1);
    dim = [c[0], c[0], c[1], c[2], c[3], c[4], c[5]];
  }

  void _body(Painter p, Swing s, double w0, double lag, int half, bool rim) {
    final uEnd = tau * _turn(t - lag);
    final ramp = half < 0 ? dim : c;
    if (uEnd < 0.02 || t - lag > _kSw + 0.02) return;
    smear(p, s, 0.0, uEnd, w0, (u, r, out, _) {
      final age = t - lag - _passedAt(u / tau);
      final lead = uEnd - u;
      final w = w0 *
          math.pow(clamp(lead / 0.85), 0.5) *
          (0.3 + 0.7 * math.exp(-age / 0.075)) *
          math.pow(clamp(u / 1.3), 0.7);
      if (w < 0.45) return;
      final q = (s.r - r) / w;
      if (q < 0.0 || q > 1.0) return;
      final ci = rim && q < 0.26 && age < 0.06
          ? 0
          : (q * (n - 1) * 0.7 + age * 13.0 + (rim ? 0.4 : 1.4) + 0.5).floor();
      out.c = ramp[n - 1 - clampInt(ci, 0, n - 1)];
      out.a = math.min(1.0, u / 1.1 + 0.2);
    }, half: half);
  }

  void _ring(Painter p, int half) {
    _body(p, e, _kWe, 0.025, half, false);
    _body(p, a, _kW, 0.0, half, true);
    if (t < _kSw + 0.04) {
      glowAlong(
        p,
        a,
        a.r - 5.0,
        0.0,
        tau * _turn(t),
        14.0,
        c[3],
        0.0,
        kFn: (u) =>
            (half < 0 ? 0.2 : 0.3) * math.exp(-(t - _passedAt(u / tau)) / 0.08),
        half: half,
      );
    }
    if (t < _kSw) return;
    final f = (t - _kSw) / _kFlare;
    final ramp = half < 0 ? dim : c;
    if (f < 1.0) {
      final rad = a.r + 6.0 * Ease.outCubic(f);
      final th = f < 0.13
          ? 9.0
          : math.max(1.0, 6.0 * math.pow(1.0 - f, 1.5) + 0.5);
      final s = a.copyWith(r: rad);
      final step = f < 0.13
          ? 6
          : f < 0.3
              ? 5
              : f < 0.55
                  ? 4
                  : 3;
      smear(p, s, 0.0, tau, th, (u, r, out, _) {
        final q = (rad - r) / th;
        if (q < 0.0 || q > 1.0) return;
        out.c = f < 0.13
            ? (q < 0.6 ? kWhite : ramp[5])
            : q < 0.45
                ? ramp[step]
                : ramp[step - 1];
        out.a = f < 0.4 ? 1.0 : 1.3 - f;
      }, half: half);
      glowAlong(
        p,
        s,
        rad - 2.0,
        0.0,
        tau,
        14.0,
        c[4],
        0.32 * (1.0 - f) * (1.0 - f),
        half: half,
      );
    }
    final k = 1.0 - clamp((t - _kSw - 0.06) / 0.4);
    if (k > 0.0) {
      trace(
        p,
        a,
        a.r - 0.5,
        0.0,
        tau,
        ramp[4],
        0.0,
        aFn: (u) => clamp(k * 1.5 - rand((u * 30.0).floor(), 5) * 0.8) * 0.95,
        half: half,
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    final uEnd = tau * _turn(t);
    if (t < _kSw) {
      for (var u = lastU; u < uEnd; u += 0.3) {
        final tr = swingTravel(a, u);
        final ox = tr.x - a.cx;
        final oy = tr.y - a.cy;
        final rawL = hypot(ox, oy);
        final l = rawL == 0.0 ? 1.0 : rawL;
        final sp = rg.range(40.0, 120.0);
        ps.spawn(
          P.mote,
          tr.x,
          tr.y,
          tr.dx * sp + (ox / l) * sp * 0.35,
          tr.dy * sp * 0.6 - rg.range(5.0, 30.0),
          rg.range(0.22, 0.45),
          c[4 + rg.intRange(0, 1)],
          0.55,
          0.0,
          math.sin(tr.a) < 0.0 ? PF.back : 0,
        );
      }
      lastU = uEnd;
    }
    if (!closed && t >= _kSw) {
      closed = true;
      lights.add(a.cx, a.cy + 4.0, 90.0, c[3], 0.4, 0.4);
      final end = swingTravel(a, tau);
      for (var i = 0; i < 9; i++) {
        final ang = math.atan2(end.dy, end.dx) + rg.range(-0.45, 0.35);
        final sp = rg.range(160.0, 360.0);
        ps.spawn(
          P.spark,
          end.x,
          end.y,
          math.cos(ang) * sp,
          math.sin(ang) * sp - rg.range(20.0, 70.0),
          rg.range(0.14, 0.36),
        );
      }
      for (var i = 0; i < 16; i++) {
        final u = rg.range(0.0, tau);
        final tr = swingTravel(a, u);
        final sp = rg.range(110.0, 260.0);
        ps.spawn(
          P.spark,
          tr.x,
          tr.y,
          tr.dx * sp,
          tr.dy * sp - rg.range(20.0, 80.0),
          rg.range(0.12, 0.32),
          0,
          1.0,
          0.0,
          math.sin(tr.a) < 0.0 ? PF.back : 0,
        );
      }
      for (var i = 0; i < 6; i++) {
        final u = rg.range(0.0, tau);
        final (x, y) = onSwing(a, a.r + rg.range(-1.0, 3.0), u);
        ps.spawn(
          P.star,
          x,
          y,
          0.0,
          -rg.range(2.0, 8.0),
          rg.range(0.25, 0.5),
          rg.chance(0.5) ? c[5] : kWhite,
          rg.range(1.2, 2.6),
          rg.range(0.04, 0.16),
          math.sin(a.a0 + a.dir * u) < 0.0 ? PF.back : 0,
        );
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    _ring(p, -1);
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    _ring(p, 1);
    if (t < 0.06) {
      final (x, y) = onSwing(a, a.r - 3.0, 0.0);
      sparkle(p, x, y, 7.0 * (1.0 - t / 0.06), c[5], c[3], 0.5);
    }
    final g = t - _kSw * 0.85;
    final tip = onSwing(a, a.r - 3.0, tau);
    if (g > 0.0 && g < 0.24) {
      sparkle(
        p,
        tip.$1,
        tip.$2,
        10.0 * Ease.outBack(math.min(1.0, g / 0.05)) * (1.0 - g / 0.24),
        c[5],
        c[3],
        0.6,
      );
    }
    if (t < _kSw + 0.05) {
      final u = tau * _turn(t);
      final (x, y) = onSwing(a, a.r - 5.0, u);
      final far = math.sin(a.a0 + a.dir * u) < 0.0;
      p.glow(
        x,
        y,
        far ? 26.0 : 38.0,
        c[3],
        (far ? 0.3 : 0.5) * (1.0 - smooth(_kSw - 0.04, _kSw + 0.05, t)),
      );
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect spinSlashEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'melee/spin-slash',
    name: 'Spin slash',
    desc:
        'The blade whirls once round the waist on a tilted plane, behind the body and back in front; the closed ring flares white, dissolves into a dotted trace and throws sparks.',
    category: 'melee',
    tags: [
      'melee',
      'slash',
      'spin',
      'sword',
      'aoe',
      'combat',
      'one-shot',
    ],
    size: (208, 104),
    origin: (104, 84),
    duration: 0.8,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#16224a',
        '#1f4a86',
        '#2a7fc0',
        '#48b8ec',
        '#9fe2ff',
        '#e2f7ff',
        '#ffffff',
      ],
      'sparks': ['#fff3a6', '#ffe26b', '#ff8a2a', '#f2561d'],
      'radius': 46,
      'seed': 3,
    },
  ),
  act: ActSpec(
    target: const TargetSpec(x: 60),
    poses: [
      PoseKey(-0.46, _stance),
      PoseKey(-0.2, _wound),
      PoseKey(-0.02, _wound.copyWith(crouch: 7, yaw: 1.3)),
      PoseKey(0.0, _wide.copyWith(sa: -0.1, ghost: 1), PoseEase.snap),
      PoseKey(0.05, _wide.copyWith(yaw: -1.57, ghost: 1), PoseEase.snap),
      PoseKey(0.09, _wide.copyWith(yaw: -3.14, ghost: 1), PoseEase.snap),
      PoseKey(0.13, _wide.copyWith(yaw: -4.71, ghost: 1), PoseEase.snap),
      PoseKey(0.17, _wide, PoseEase.snap),
      PoseKey(0.56, _wide.copyWith(crouch: 4, lean: 2)),
      PoseKey(0.92, _stance),
    ],
    hits: const [
      HitSpec(t: 0.17, stop: 0.12, shake: 0.16, amp: 2, push: 2.4, straw: 16),
    ],
    dust: const [
      DustSpec(t: 0.0, x: 0, n: 6),
      DustSpec(t: 0.17, x: 12, n: 6, dir: 1),
    ],
  ),
  onCreate: (o) => _SpinSlashSim(o),
);
