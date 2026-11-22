// The speed lines are adapted from Sprite Fusion's open-source dash and the ray star from his sparkle
// (https://www.spritefusion.com/pixel-art-vfx), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

final Pose _stance = kReady.copyWith(
  weapon: 'sword',
  x: -14,
  fx: 12,
  fy: -21,
  sa: -0.3,
);

final Pose _back = _stance.copyWith(
  crouch: 5,
  lean: -3,
  fx: -3,
  fy: -19,
  sa: -0.05,
  bx: 8,
  by: -30,
  armsFront: true,
  ffx: 10,
  fbx: -8,
);

final Pose _lunge = _stance.copyWith(
  crouch: 6,
  lean: 6,
  fx: 23,
  fy: -20,
  sa: 0,
  bx: -8,
  by: -24,
  ffx: 15,
  fbx: -11,
  toeB: true,
);

const double _kOut = 0.07;
const double _kHold = 0.06;
const double _kPull = 0.2;
const double _kHx = 9.0;
const double _kHy = -20.0;

void _longStar(
  Painter p,
  double x,
  double y,
  double l,
  double k,
  List<int> c,
) {
  if (l < 1.0) return;
  final arms = [
    (1.0, 0.0, l),
    (-1.0, 0.0, l * 0.7),
    (0.0, -1.0, l * 0.42),
    (0.0, 1.0, l * 0.42),
  ];
  for (final (dx, dy, len) in arms) {
    for (var d = 1.0; d <= len; d += 0.5) {
      final u = d / len;
      final col = u < 0.3
          ? kWhite
          : u < 0.65
              ? c[5]
              : c[4];
      p.dot(x + dx * d, y + dy * d, col, u < 0.7 ? 1.0 : 1.0 - (u - 0.7) / 0.35);
      if (u < 0.25 && len > 6.0) {
        p.dot(x + dx * d - dy, y + dy * d + dx, c[5]);
        p.dot(x + dx * d + dy, y + dy * d - dx, c[5]);
      }
    }
  }
  for (final (dx, dy) in const [(1, 1), (1, -1), (-1, 1), (-1, -1)]) {
    for (var d = 1; d <= math.min(3.0, l * 0.14); d++) {
      p.px(x + dx * d, y + dy * d, d < 2 ? c[5] : c[4]);
    }
  }
  p.px(x, y, kWhite);
  p.glow(x, y, 6.0 + l * 1.3, c[4], 0.35 * k);
  p.glow(x, y, 3.0 + l * 0.4, kWhite, 0.3 * k);
}

typedef _StreakSpec = ({
  double off,
  double x0,
  double t0,
  int w,
  bool hot,
  double len,
});

class _SpeedLine {
  double x;
  final double y;
  final double l;
  final double v;
  final double t;

  _SpeedLine({
    required this.x,
    required this.y,
    required this.l,
    required this.v,
    required this.t,
  });
}

class _ThrustSim extends BaseEffectSim {
  final List<int> c;
  final Rng rg;
  late final Particles ps;
  final Lights lights = Lights();
  final double reach;
  late final double tx;
  late final double ty;
  late final List<_StreakSpec> streaks;
  final List<_SpeedLine> lines = [];
  double t = 0.0;
  bool struck = false;

  _ThrustSim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        rg = Rng(o.seed),
        reach = o.numOpt('reach', 66.0) {
    ps = Particles(
      rng: rg,
      ground: (_) => 0.0,
      sparks: (o['sparks'] as List).cast<Object>(),
    );
    tx = _kHx + reach;
    ty = _kHy;
    streaks = [
      for (final off in const [-7.0, -4.0, -2.0, 0.0, 2.0, 4.0, 7.0])
        (
          off: off,
          x0: _kHx + 1.0 + rg.range(0.0, 5.0) + off.abs() * 0.6,
          t0: rg.range(0.0, 0.02) + off.abs() * 0.003,
          w: off == 0.0 ? 2 : 1,
          hot: off == 0.0,
          len: rg.range(0.75, 1.0),
        ),
    ];
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (t < _kOut + 0.08 && rg.chance(0.5)) {
      final s = rg.sign();
      lines.add(
        _SpeedLine(
          x: _kHx + rg.range(0.0, reach * 0.6),
          y: _kHy + s * rg.range(7.0, 17.0),
          l: rg.range(18.0, 42.0),
          v: rg.range(200.0, 340.0),
          t: t,
        ),
      );
    }
    for (var i = lines.length - 1; i >= 0; i--) {
      if (t - lines[i].t > 0.24) lines.removeAt(i);
    }
    for (final l in lines) {
      l.x += l.v * dt;
    }
    if (!struck && t >= _kOut) {
      struck = true;
      lights.add(tx, ty, 44.0, c[4], 0.45, 0.3);
      lights.add(tx, ty, 14.0, kWhite, 0.6, 0.06);
      for (var i = 0; i < 12; i++) {
        final a = rg.range(-0.55, 0.45);
        final sp = rg.range(150.0, 330.0);
        ps.spawn(
          P.spark,
          tx,
          ty,
          math.cos(a) * sp,
          math.sin(a) * sp - 30.0,
          rg.range(0.12, 0.35),
        );
      }
      for (var i = 0; i < 10; i++) {
        final a = rg.range(-0.9, 0.9) + (rg.chance(0.3) ? math.pi : 0.0);
        final sp = rg.range(40.0, 120.0);
        ps.spawn(
          P.mote,
          tx + rg.range(-6.0, 2.0),
          ty + rg.range(-2.0, 2.0),
          math.cos(a) * sp,
          math.sin(a) * sp,
          rg.range(0.25, 0.5),
          rg.chance(0.5) ? c[5] : c[4],
          0.6,
        );
      }
      for (var i = 0; i < 4; i++) {
        ps.spawn(
          P.star,
          tx + rg.range(-10.0, 8.0),
          ty + rg.range(-9.0, 9.0),
          0.0,
          -3.0,
          rg.range(0.2, 0.4),
          rg.chance(0.5) ? c[5] : kWhite,
          rg.range(1.0, 2.0),
          rg.range(0.06, 0.2),
        );
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    if (t < 0.05) {
      sparkle(p, _kHx + 2.0, _kHy, 5.0 * (1.0 - t / 0.05) + 1.0, c[5], c[3], 0.4);
    }
    for (final l in lines) {
      final k = (t - l.t) / 0.24;
      for (var d = 0.0; d < l.l * (1.0 - k * 0.6); d++) {
        p.dot(
          l.x - d,
          l.y,
          d < 3.0
              ? kWhite
              : d < l.l * 0.4
                  ? c[5]
                  : c[3],
          (1.0 - d / l.l) * (1.0 - k),
        );
      }
    }
    final pull = smooth(_kOut + _kHold, _kOut + _kHold + _kPull, t);
    for (final s in streaks) {
      final u = clamp((t - s.t0) / _kOut);
      final head = Ease.outExpo(u);
      if (u <= 0.0 || pull >= 1.0) continue;
      final y0 = _kHy + s.off;
      final end = s.x0 + (tx - s.x0) * s.len;
      final x1 = s.x0 + (end - s.x0) * head;
      final xa = s.x0 +
          (end - s.x0) * math.max(pull, head * 0.35 * (1.0 - s.len) * 3.0);
      double yAt(double x) =>
          y0 + (ty - y0) * clamp((x - s.x0) / (tx - s.x0)) * 0.85;
      for (var x = xa; x <= x1; x += 0.5) {
        final v = (x - xa) / math.max(1.0, x1 - xa);
        final col = v > 0.88
            ? kWhite
            : s.hot
                ? (v > 0.35 ? c[6] : c[5])
                : v > 0.55
                    ? c[5]
                    : v > 0.25
                        ? c[4]
                        : c[3];
        p.dot(x, yAt(x), col, v < 0.12 ? v / 0.12 : 1.0);
        if (s.w > 1 && v > 0.1) {
          p.dot(
            x,
            yAt(x) + 1.0,
            v > 0.6 ? c[5] : c[3],
            v < 0.2 ? v / 0.2 : 1.0,
          );
        }
      }
    }
    if (t < _kOut + _kHold + _kPull) {
      p.glowLine(
        _kHx + (tx - _kHx) * pull,
        _kHy,
        _kHx + (tx - _kHx) * Ease.outExpo(clamp(t / _kOut)),
        ty,
        6.0,
        c[4],
        0.22 * (1.0 - pull),
      );
    }
    final q = t - _kOut;
    if (q >= 0.0 && q < 0.4) {
      final g = Ease.outBack(clamp(q / 0.04), 2.4) *
          (1.0 - smooth(0.08, 0.4, q)) *
          (1.0 + 0.12 * math.sin(q * 70.0));
      _longStar(p, tx, ty, 24.0 * g, 1.0 - q / 0.4, c);
    }
    if (q >= 0.0 && q < 0.2) {
      final k = q / 0.2;
      final rx = 2.0 + 7.0 * Ease.outCubic(k);
      final ry = 4.0 + 12.0 * Ease.outCubic(k);
      for (var a = 0.0; a < tau; a += 0.05) {
        p.dot(
          tx + 4.0 + 10.0 * k + math.cos(a) * rx,
          ty + math.sin(a) * ry,
          k < 0.3 ? kWhite : c[5],
          1.15 - k,
        );
      }
    }
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect thrustEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'melee/thrust',
    name: 'Thrust',
    desc:
        'A piercing stab: a bundle of streaks shoots out from the hand to a point, a long four-point star flares at the tip with a pierce ring, sparks and speed lines.',
    category: 'melee',
    tags: [
      'melee',
      'thrust',
      'stab',
      'spear',
      'rapier',
      'pierce',
      'combat',
      'directional',
      'one-shot',
    ],
    size: (196, 76),
    origin: (34, 62),
    duration: 0.75,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#2a1608',
        '#6b3c10',
        '#b8701a',
        '#f0b42e',
        '#ffe27a',
        '#fff6cf',
        '#ffffff',
      ],
      'sparks': ['#fff3a6', '#ffe26b', '#ff8a2a', '#f2561d'],
      'reach': 66,
      'seed': 4,
    },
  ),
  act: ActSpec(
    target: const TargetSpec(x: 80),
    poses: [
      PoseKey(-0.46, _stance),
      PoseKey(-0.24, _back),
      PoseKey(-0.05, _back.copyWith(crouch: 6, fx: -5)),
      PoseKey(0.0, _lunge.copyWith(ghost: 1), PoseEase.snap),
      PoseKey(0.07, _lunge, PoseEase.snap),
      PoseKey(0.3, _lunge.copyWith(crouch: 5, lean: 5)),
      PoseKey(0.7, _stance),
    ],
    hits: const [
      HitSpec(
        t: 0.07,
        stop: 0.12,
        shake: 0.14,
        amp: 2,
        push: 2.8,
        straw: 16,
        y: -26,
      ),
    ],
    dust: const [
      DustSpec(t: 0.0, x: -24, n: 6, dir: -1),
      DustSpec(t: 0.07, x: 1, n: 6, dir: 1),
    ],
  ),
  onCreate: (o) => _ThrustSim(o),
);
