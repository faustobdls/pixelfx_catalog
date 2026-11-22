// The crescent recipe is adapted from Sprite Fusion's open-source slash, and the star from his impact
// (https://www.spritefusion.com/pixel-art-vfx), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart' hide star;

import 'melee_lib.dart';

final Pose _fists = kReady.copyWith(
  fx: 12,
  fy: -25,
  bx: 9,
  by: -27,
  crouch: 3,
  lean: 1,
);

final Pose _coil = _fists.copyWith(
  crouch: 7,
  lean: 3,
  fx: 8,
  fy: -11,
  bx: 8,
  by: -27,
  ffx: 10,
  fbx: -9,
);

final Pose _topBase = _fists.copyWith(
  x: 1,
  y: -11,
  crouch: -1,
  lean: 2,
  fx: 12,
  fy: -42,
  bx: -6,
  by: -21,
  ffx: 8,
  ffy: -8,
  fbx: -3,
  fby: -2,
  toeB: true,
);

final Pose _top = _topBase.copyWith(ghost: 1);

typedef _BurstSpec = ({double a, double r0, double l});

class _UppercutSim extends BaseEffectSim {
  final List<int> c;
  final int ink;
  final Rng rg;
  late final Particles ps;
  final Lights lights = Lights();
  late final Swing a;
  late final SwingPoint top;
  late final double sx;
  late final double sy;
  late final double hitTime;
  late final List<Spike> spikes;
  late final List<_BurstSpec> bursts;
  double t = 0.0;
  bool hit = false;
  bool kicked = false;

  _UppercutSim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        ink = hex(o['outline'] ?? '#2a0a08'),
        rg = Rng(o.seed) {
    ps = Particles(
      rng: rg,
      ground: (_) => 0.0,
      sparks: (o['sparks'] as List).cast<Object>(),
    );
    a = Swing(
      cx: 8.0,
      cy: -25.0,
      r: 27.0,
      sy: 1.0,
      rot: 0.0,
      a0: 1.08,
      dir: -1.0,
      span: 2.5,
      w: 13.0,
      t0: 0.02,
      sweep: 0.07,
      hold: 0.05,
      trail: 0.22,
      ramp: c,
    );
    top = slashEnd(a);
    sx = top.x + 3.0;
    sy = top.y - 5.0;
    hitTime = a.t0 + a.sweep * 0.8;
    spikes = List.generate(
      10,
      (i) => (
        a: (i / 10.0) * tau + rg.range(-0.12, 0.12) - math.pi / 2.0,
        len: (i.isOdd ? 7.0 : 13.0) + rg.range(0.0, 4.0),
        w: i.isOdd ? 2.2 : 3.0,
      ),
    );
    bursts = List.generate(
      8,
      (i) => (
        a: (i / 8.0) * tau + 0.2 + rg.range(-0.15, 0.15),
        r0: rg.range(15.0, 18.0),
        l: rg.range(5.0, 9.0),
      ),
    );
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (!kicked) {
      kicked = true;
      for (var i = 0; i < 4; i++) {
        ps.spawn(
          P.dust,
          18.0 + rg.range(-4.0, 4.0),
          -1.0,
          rg.range(-30.0, 30.0),
          -rg.range(5.0, 20.0),
          rg.range(0.3, 0.55),
          '#6a6080',
          rg.range(1.5, 2.6),
        );
      }
    }
    if (!hit && t >= hitTime) {
      hit = true;
      lights.add(sx, sy, 56.0, c[4], 0.6, 0.4);
      lights.add(sx, sy, 18.0, kWhite, 0.7, 0.08);
      for (var i = 0; i < 16; i++) {
        final ang = -math.pi / 2.0 + rg.range(-1.6, 1.6);
        final sp = rg.range(120.0, 320.0);
        ps.spawn(
          P.spark,
          sx,
          sy,
          math.cos(ang) * sp,
          math.sin(ang) * sp,
          rg.range(0.15, 0.45),
        );
      }
      for (var i = 0; i < 6; i++) {
        final ang = rg.range(0.0, tau);
        final d = rg.range(14.0, 24.0);
        ps.spawn(
          P.star,
          sx + math.cos(ang) * d,
          sy + math.sin(ang) * d,
          math.cos(ang) * 20.0,
          math.sin(ang) * 20.0 - 10.0,
          rg.range(0.25, 0.5),
          rg.chance(0.5) ? c[5] : kWhite,
          rg.range(1.4, 2.6),
          rg.range(0.04, 0.18),
        );
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    slash(p, a, t);
    final u = t - a.t0;
    if (u > 0.0 && u < 0.16) {
      final lines = [
        (a.cx + a.r + 7.0, -16.0, 18.0),
        (a.cx + a.r + 11.0, -30.0, 12.0),
        (a.cx - 4.0, -40.0, 10.0),
      ];
      for (final (dx, y0, l) in lines) {
        final k = u / 0.16;
        final y = y0 - 30.0 * k;
        for (var d = 0.0; d < l; d += 1.0) {
          p.dot(
            dx,
            y + d,
            d < 3.0
                ? kWhite
                : d < l * 0.5
                    ? c[5]
                    : c[3],
            (1.0 - d / l) * (1.0 - k),
          );
        }
      }
    }
    if (u > 0.0 && u < a.sweep + 0.06) {
      final (x, y) = onSwing(a, a.r - 5.0, a.span * Ease.outExpo(clamp(u / a.sweep)));
      p.glow(x, y, 34.0, c[3], 0.45 * (1.0 - u / (a.sweep + 0.06)));
    }
    final q = t - hitTime;
    if (q >= 0.0 && q < 0.36) {
      final pop = Ease.outBack(clamp(q / 0.05), 2.6);
      final out = 1.0 - smooth(0.16, 0.36, q);
      final sc = pop * (0.35 + 0.65 * out);
      final turn = q * 1.2;
      final sp = [
        for (final s in spikes) (a: s.a + turn, len: s.len, w: s.w),
      ];
      if (sc > 0.08) {
        star(p, sx, sy, sp, sc * 1.12, 1.0, ink, ink, ink, ink);
        star(
          p,
          sx,
          sy,
          sp,
          sc,
          1.0,
          q < 0.05 ? kWhite : c[6],
          c[4],
          c[3],
          c[2],
        );
      }
      p.glow(sx, sy, 30.0, c[4], 0.45 * out);
    }
    if (q >= 0.02 && q < 0.24) {
      final k = (q - 0.02) / 0.22;
      final r = 7.0 + 17.0 * Ease.outCubic(k);
      final th = math.max(1.0, 2.2 * (1.0 - k));
      final col = k < 0.25
          ? kWhite
          : k < 0.5
              ? c[5]
              : k < 0.75
                  ? c[4]
                  : c[3];
      for (var ang = 0.0; ang < tau; ang += 0.6 / r) {
        for (var o = 0.0; o < th; o += 0.5) {
          p.dot(
            sx + math.cos(ang) * (r - o),
            sy + math.sin(ang) * (r - o),
            col,
            1.15 - k,
          );
        }
      }
    }
    if (q >= 0.02 && q < 0.2) {
      final k = (q - 0.02) / 0.18;
      for (final b in bursts) {
        final r0 = b.r0 + 10.0 * Ease.outCubic(k);
        final ca = math.cos(b.a);
        final sa = math.sin(b.a);
        p.line(
          sx + ca * r0,
          sy + sa * r0,
          sx + ca * (r0 + b.l * (1.0 - k)),
          sy + sa * (r0 + b.l * (1.0 - k)),
          k < 0.4 ? kWhite : c[5],
          1.1 - k,
        );
      }
    }
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect uppercutEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'melee/uppercut',
    name: 'Uppercut',
    desc:
        'A crescent rises from the floor past the face, and at the top a comic impact star bursts: bold outline, hot core, burst lines, twinkles and sparks.',
    category: 'melee',
    tags: [
      'melee',
      'uppercut',
      'punch',
      'rising',
      'launcher',
      'comic',
      'combat',
      'directional',
      'one-shot',
    ],
    size: (132, 128),
    origin: (48, 110),
    duration: 0.85,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#3a1408',
        '#7a2a10',
        '#c4501a',
        '#f08a2a',
        '#ffc94a',
        '#fff2a8',
        '#ffffff',
      ],
      'outline': '#2a0a08',
      'sparks': ['#fff3a6', '#ffe26b', '#ff8a2a', '#f2561d'],
      'seed': 11,
    },
  ),
  act: ActSpec(
    target: const TargetSpec(x: 44),
    poses: [
      PoseKey(-0.42, _fists),
      PoseKey(-0.16, _coil),
      PoseKey(0.0, _coil.copyWith(crouch: 8)),
      PoseKey(
        0.03,
        _fists.copyWith(
          y: -4,
          crouch: 1,
          lean: 4,
          fx: 18,
          fy: -27,
          bx: -5,
          by: -23,
          ffx: 9,
          fbx: -7,
          toeB: true,
          ghost: 1,
        ),
        PoseEase.snap,
      ),
      PoseKey(0.076, _top, PoseEase.snap),
      PoseKey(0.3, _topBase.copyWith(y: -13)),
      PoseKey(
        0.56,
        _topBase.copyWith(
          y: 0,
          crouch: 2,
          fx: 13,
          fy: -31,
          ffx: 7,
          ffy: -6,
          fbx: -5,
          fby: -5,
        ),
        PoseEase.inEase,
      ),
      PoseKey(
        0.6,
        _fists.copyWith(
          y: 0,
          crouch: 7,
          lean: 3,
          fx: 12,
          fy: -14,
          bx: -6,
          by: -16,
          ffx: 10,
          fbx: -9,
        ),
        PoseEase.snap,
      ),
      PoseKey(0.98, _fists),
    ],
    hits: const [
      HitSpec(
        t: 0.076,
        stop: 0.13,
        shake: 0.18,
        amp: 2,
        push: -2.6,
        straw: 18,
        y: -34,
      ),
    ],
    dust: const [
      DustSpec(t: 0.03, x: 8, n: 6),
      DustSpec(t: 0.6, x: 0, n: 6),
    ],
  ),
  onCreate: (o) => _UppercutSim(o),
);
