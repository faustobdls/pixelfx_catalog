// The crescent, echo, trail, glint and spark recipe is adapted from Sprite Fusion's open-source slash
// (https://www.spritefusion.com/pixel-art-vfx/slash), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

final Pose _guard = kReady.copyWith(weapon: 'sword', fx: 12, fy: -21, sa: -0.85);
final Pose _wind = _guard.copyWith(
  x: -8,
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
final Pose _cut = _guard.copyWith(
  x: 0,
  crouch: 2,
  lean: 3,
  fx: 16,
  fy: -37,
  sa: -1.45,
  bx: -7,
  by: -24,
  ffx: 11,
  fbx: -10,
  ghost: 1,
);
final Pose _down = _guard.copyWith(
  x: 2,
  crouch: 5,
  lean: 5,
  fx: 20,
  fy: -21,
  sa: 0.62,
  bx: -9,
  by: -24,
  ffx: 13,
  fbx: -10,
  toeB: true,
);

class _SlashArc {
  final double cx, cy, r, sy, rot, a0, a1, w, t0, sweep, hold, trail;
  final List<int> ramp;

  const _SlashArc({
    required this.cx,
    required this.cy,
    required this.r,
    required this.sy,
    required this.rot,
    required this.a0,
    required this.a1,
    required this.w,
    required this.t0,
    required this.sweep,
    required this.hold,
    required this.trail,
    required this.ramp,
  });
}

Point2 _onArc(_SlashArc s, double r, double a) {
  final lx = math.cos(a) * r;
  final ly = math.sin(a) * r * s.sy;
  final c = math.cos(s.rot);
  final n = math.sin(s.rot);
  return (s.cx + lx * c - ly * n, s.cy + lx * n + ly * c);
}

void _crescent(
  Painter p,
  _SlashArc s,
  double ta,
  double l,
  double wMax,
  double age,
) {
  if (l.abs() < 0.02 || wMax < 0.3) return;
  final rList = s.ramp;
  final n = rList.length;
  final dir = l < 0.0 ? -1.0 : 1.0;
  final span = l.abs();
  final c = math.cos(s.rot);
  final sn = math.sin(s.rot);
  final b = s.r + 2.0;

  p.shade(s.cx - b, s.cy - b, s.cx + b, s.cy + b, (x, y, out) {
    final dx = x - s.cx;
    final dy = y - s.cy;
    final lx = dx * c + dy * sn;
    final ly = (-dx * sn + dy * c) / s.sy;
    final r = hypot(lx, ly);
    if (r > s.r + 0.5 || r < s.r - wMax - 1.0) return null;
    var u = (dir * (math.atan2(ly, lx) - ta)) % tau;
    if (u < 0.0) u += tau;
    if (u > span) return null;
    final v = u / span;
    final w = wMax *
        math.pow(
          math.max(0.0, math.sin(math.pi * math.pow(v, 2.2))),
          0.6,
        );
    if (w < 0.35) return null;
    final q = (s.r - r) / w;
    if (q < 0.0 || q > 1.0) return null;
    final ci = (q < 0.22 && age < 0.5)
        ? 0
        : (q * (n - 1) * 0.75 + age * 2.4 - v * 0.8 + 0.4).round();
    out.c = rList[n - 1 - clampInt(ci, 0, n - 1)];
    out.a = math.min(1.0, v / 0.4);
    return null;
  });

  for (var u = 0.0; u <= span; u += 0.3) {
    final (x, y) = _onArc(s, s.r - wMax * 0.4, ta + dir * u);
    p.glow(x, y, 5.0 + wMax, rList[n - 3], 0.22 * (1.0 - age) * (u / span));
  }
}

void _drawSlash(Painter p, _SlashArc s, double t) {
  final u = t - s.t0;
  if (u < 0.0) return;
  final span = s.a1 - s.a0;
  final head = Ease.outExpo(clamp(u / s.sweep));
  final tail = smooth(s.sweep + s.hold, s.sweep + s.hold + s.trail, u);
  final age = clamp(u / (s.sweep + s.hold + s.trail));
  if (tail < 1.0) {
    _crescent(p, s, s.a0 + span * tail, span * (head - tail),
        s.w * (1.0 - tail * 0.55), age);
  }
  final th = 0.7 * (1.0 - clamp((u - s.sweep - s.hold) / (s.trail + 0.2)));
  if (tail > 0.02 && th > 0.0) {
    final step = 0.6 / (span.abs() * s.r);
    for (var k = 0.0; k <= tail; k += step) {
      final (x, y) = _onArc(s, s.r - 0.5, s.a0 + span * k);
      p.dot(x, y, s.ramp[1], th * (0.4 + 0.6 * k));
    }
  }
}

class _SwordSlashSim extends BaseEffectSim {
  final List<int> c;
  final Rng rg;
  late final Particles ps;
  late final _SlashArc a;
  late final _SlashArc e;
  late final double tipX, tipY, tipDx, tipDy;
  double t = 0.0;
  bool landed = false;

  _SwordSlashSim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        rg = Rng(o.seed) {
    ps = Particles(
      rng: rg,
      ground: (_) => 0.0,
      sparks: (o['sparks'] as List).cast<Object>(),
    );
    final r0 = o.numOpt('radius', 42.0);
    const a0 = -2.55;
    const a1 = 0.95;
    a = _SlashArc(
      cx: 6,
      cy: -26,
      r: r0,
      sy: 0.6,
      rot: -0.38,
      a0: a0,
      a1: a1,
      w: 12,
      t0: 0,
      sweep: 0.06,
      hold: 0.06,
      trail: 0.24,
      ramp: c,
    );
    e = _SlashArc(
      cx: 6,
      cy: -26,
      r: r0 * (33.0 / 42.0),
      sy: 0.6,
      rot: -0.38,
      a0: a0 + (a1 - a0) * 0.1,
      a1: a1 - (a1 - a0) * (0.15 / 3.5),
      w: r0 * (4.5 / 42.0),
      t0: 0.017,
      sweep: 0.06,
      hold: 0.03,
      trail: 0.2,
      ramp: c.sublist(0, 6),
    );
    final (x, y) = _onArc(a, a.r - a.w * 0.3, a.a1);
    final dir = a.a1 >= a.a0 ? 1.0 : -1.0;
    final (x2, y2) = _onArc(a, a.r - a.w * 0.3, a.a1 + dir * 0.05);
    final rawL = hypot(x2 - x, y2 - y);
    final l = rawL == 0.0 ? 1.0 : rawL;
    tipX = x;
    tipY = y;
    tipDx = (x2 - x) / l;
    tipDy = (y2 - y) / l;
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (!landed && t >= a.sweep) {
      landed = true;
      for (var i = 0; i < 10; i++) {
        final ang = math.atan2(tipDy, tipDx) + rg.range(-0.5, 0.5);
        final sp = rg.range(150, 400);
        ps.spawn(P.spark, tipX, tipY, math.cos(ang) * sp, math.sin(ang) * sp,
            rg.range(0.12, 0.35));
      }
      for (var i = 0; i < 16; i++) {
        final ang = a.a0 + (a.a1 - a.a0) * rg.range(0.3, 1.0);
        final (x, y) = _onArc(a, a.r, ang);
        final ox = x - a.cx;
        final oy = y - a.cy;
        final rawL = hypot(ox, oy);
        final l = rawL == 0.0 ? 1.0 : rawL;
        final sp = rg.range(30, 100);
        ps.spawn(
          P.mote,
          x,
          y,
          (ox / l) * sp,
          (oy / l) * sp - 10.0,
          rg.range(0.25, 0.55),
          c[4 + rg.intRange(0, 1)],
          0.6,
        );
      }
    }
    ps.update(dt);
  }

  @override
  void draw(Painter p) {
    _drawSlash(p, e, t);
    _drawSlash(p, a, t);
    final g = t - a.sweep * 0.6;
    if (g > 0.0 && g < 0.22) {
      sparkle(p, tipX, tipY,
          9.0 * Ease.outBack(math.min(1.0, g / 0.05)) * (1.0 - g / 0.22),
          c[5], c[3], 0.6);
    }
    if (t < 0.3) {
      final (x, y) = _onArc(
          a, a.r - 4.0, a.a0 + (a.a1 - a.a0) * Ease.outExpo(clamp(t / a.sweep)));
      p.glow(x, y, 40, c[3], 0.5 * (1.0 - t / 0.3));
    }
    ps.draw(p);
  }
}

final SimulatedEffect swordSlashEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'melee/sword-slash',
    name: 'Sword slash',
    desc:
        'A tilted crescent whips round in two frames, cools from white to deep blue as it trails off, glints at the tip and throws sparks.',
    category: 'melee',
    tags: ['melee', 'slash', 'sword', 'combat', 'directional', 'one-shot'],
    size: (136, 104),
    origin: (44, 92),
    duration: 0.75,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#212f6b', '#2c58aa', '#3a8bd8', '#62c8f4',
        '#b8c9e8', '#e8f1ff', '#ffffff',
      ],
      'sparks': ['#fff3a6', '#ffe26b', '#ff8a2a', '#f2561d'],
      'radius': 42,
      'seed': 2,
    },
  ),
  act: ActSpec(
    target: const TargetSpec(x: 58),
    poses: [
      PoseKey(-0.55, _guard.copyWith(x: -8)),
      PoseKey(-0.3, _wind),
      PoseKey(-0.08, _wind.copyWith(crouch: 5, lean: -5)),
      PoseKey(0.0, _cut, PoseEase.snap),
      PoseKey(0.06, _down, PoseEase.snap),
      PoseKey(0.3, _down.copyWith(x: 3, crouch: 6)),
      PoseKey(
        0.58,
        _guard.copyWith(
            x: 1, crouch: 3, fx: 15, fy: -21, sa: 0.1, bx: -5, by: -21, ffx: 9, fbx: -7),
      ),
      PoseKey(0.86, _guard.copyWith(x: -8)),
    ],
    hits: const [
      HitSpec(t: 0.06, stop: 0.14, shake: 0.18, amp: 2, push: 2.8, straw: 18),
    ],
    dust: const [
      DustSpec(t: 0.06, x: 16, n: 7, dir: 1),
      DustSpec(t: 0.06, x: -11, n: 4, dir: -1),
    ],
  ),
  onCreate: (o) => _SwordSlashSim(o),
);
