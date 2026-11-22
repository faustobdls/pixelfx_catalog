// The pop's star and slivers follow Sprite Fusion's open-source impact, and the sparks his slash
// (https://www.spritefusion.com/pixel-art-vfx), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart' hide star;

import 'melee_lib.dart';

final Pose _stance = kReady.copyWith(
  weapon: 'handle',
  x: -7,
  sa: -0.3,
  fx: 13,
  fy: -21,
  bx: 7,
  by: -18,
);

final Pose _cock = _stance.copyWith(
  crouch: 4,
  lean: -3,
  fx: -6,
  fy: -38,
  sa: -2.2,
  bx: 9,
  by: -23,
  armsFront: true,
  ffx: 9,
  fbx: -7,
);

final Pose _crack = _stance.copyWith(
  crouch: 4,
  lean: 5,
  fx: 18,
  fy: -21,
  sa: 0,
  bx: -8,
  by: -23,
  ffx: 12,
  fbx: -10,
  toeB: true,
);

const double _kRoll0 = 0.02;
const double _kRoll = 0.19;
const double _kCrack = _kRoll0 + _kRoll;
const double _kRecoil = 0.16;
const double _kHx = 11.0;
const double _kHy = -21.0;

typedef _SliverSpec = ({double a, double r, double v, double arc});
typedef _TipSample = ({Point2 p, double t});

class _WhipCrackSim extends BaseEffectSim {
  final List<int> c;
  final Rng rg;
  late final Particles ps;
  final Lights lights = Lights();
  final double length;
  late final double tipX;
  late final double tipY;
  late final List<Spike> spikes;
  late final List<_SliverSpec> slivers;
  final List<_TipSample> tipTrail = [];
  double t = 0.0;
  bool cracked = false;

  _WhipCrackSim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        rg = Rng(o.seed),
        length = o.numOpt('length', 76.0) {
    ps = Particles(
      rng: rg,
      ground: (_) => 0.0,
      sparks: (o['sparks'] as List).cast<Object>(),
    );
    tipX = _kHx + length;
    tipY = _kHy - 1.0;
    const spikeBase = [0.0, 0.8, 1.6, 2.4, 3.14, 3.9, 4.7, 5.5];
    spikes = [
      for (var i = 0; i < spikeBase.length; i++)
        (
          a: spikeBase[i] + rg.range(-0.15, 0.15),
          len: (i == 0 ? 13.0 : i.isOdd ? 6.0 : 9.0) + rg.range(0.0, 3.0),
          w: 1.4 + rg.range(0.0, 0.5),
        ),
    ];
    slivers = [
      for (final a in const [-1.2, -0.3, 0.5, 1.3])
        (
          a: a + rg.range(-0.2, 0.2),
          r: rg.range(4.0, 6.0),
          v: rg.range(80.0, 120.0),
          arc: rg.range(0.4, 0.7),
        ),
    ];
  }

  double _lam(double time) =>
      length * (0.34 + 0.66 * Ease.inQuad(clamp((time - _kRoll0) / _kRoll)));

  List<Point2> _shape(double time) {
    final l = _lam(time);
    final r = 6.5 - 3.5 * (l / length);
    final pts = <Point2>[];
    final recoil = smooth(_kCrack + 0.04, _kCrack + 0.04 + _kRecoil, time);
    final len = length * (1.0 - recoil * 0.85);
    for (var s = 0.0; s <= len; s += 1.0) {
      double x;
      double y;
      if (s <= l) {
        x = _kHx + s;
        y = _kHy -
            math.sin((math.pi * s) / math.max(l, 1.0)) * 2.5 * (1.0 - l / length);
      } else if (s <= l + math.pi * r) {
        final th = (s - l) / r;
        x = _kHx + l + math.sin(th) * r;
        y = _kHy + r - math.cos(th) * r;
      } else {
        x = _kHx + l - (s - l - math.pi * r);
        y = _kHy + 2.0 * r;
      }
      if (recoil > 0.0) y += math.sin((math.pi * s) / length) * 6.0 * recoil;
      pts.add((x, y));
    }
    return pts;
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (t > _kCrack - 0.05 && t < _kCrack + 0.01) {
      final pts = _shape(t);
      tipTrail.add((p: pts.last, t: t));
    }
    for (var i = tipTrail.length - 1; i >= 0; i--) {
      if (t - tipTrail[i].t > 0.06) tipTrail.removeAt(i);
    }
    if (!cracked && t >= _kCrack) {
      cracked = true;
      lights.add(tipX, tipY, 46.0, c[4], 0.6, 0.3);
      lights.add(tipX, tipY, 14.0, kWhite, 0.8, 0.07);
      for (var i = 0; i < 16; i++) {
        final a = rg.range(-1.3, 1.2);
        final sp = rg.range(130.0, 300.0);
        ps.spawn(
          P.spark,
          tipX,
          tipY,
          math.cos(a) * sp,
          math.sin(a) * sp - 40.0,
          rg.range(0.12, 0.36),
        );
      }
      for (var i = 0; i < 3; i++) {
        ps.spawn(
          P.smoke,
          tipX + rg.range(-2.0, 3.0),
          tipY + rg.range(-2.0, 2.0),
          rg.range(10.0, 40.0),
          -rg.range(6.0, 18.0),
          rg.range(0.5, 0.8),
          c[2],
          rg.range(2.5, 4.0),
          rg.range(0.02, 0.06),
        );
      }
      for (var i = 0; i < 4; i++) {
        ps.spawn(
          P.star,
          tipX + rg.range(-8.0, 10.0),
          tipY + rg.range(-8.0, 8.0),
          0.0,
          -3.0,
          rg.range(0.2, 0.4),
          rg.chance(0.5) ? c[5] : kWhite,
          rg.range(0.8, 1.8),
          rg.range(0.05, 0.2),
        );
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    const end = _kCrack + 0.04 + _kRecoil;
    if (t < end) {
      final fade = 1.0 - smooth(end - 0.06, end, t);
      if (t < _kCrack) {
        for (final (lag, col, alpha) in [
          (0.03, c[1], 0.5),
          (0.015, c[2], 0.7),
        ]) {
          final old = _shape(math.max(0.0, t - lag));
          for (var i = 1; i < old.length; i += 2) {
            p.dot(old[i].$1, old[i].$2, col, alpha);
          }
        }
      }
      final pts = _shape(t);
      final n = pts.length;
      final l = _lam(t);
      final r = 6.5 - 3.5 * (l / length);
      for (var i = 1; i < n; i++) {
        final (x0, y0) = pts[i - 1];
        final (x1, y1) = pts[i];
        final u = i / n;
        final s = i.toDouble();
        final inLoop = t < _kCrack && s > l && s < l + math.pi * r;
        final lead = inLoop && (s - l - (math.pi * r) / 2.0).abs() < r * 0.9;
        p.line(
          x0,
          y0,
          x1,
          y1,
          lead
              ? kWhite
              : inLoop
                  ? c[5]
                  : u < 0.5
                      ? c[4]
                      : c[3],
          fade,
        );
        if (u < 0.4) p.line(x0, y0 + 1.0, x1, y1 + 1.0, c[2], fade);
      }
      if (t < _kCrack) {
        final ll = _lam(t);
        final rr = 6.5 - 3.5 * (ll / length);
        p.glow(_kHx + ll + rr, _kHy + rr, 12.0, c[4], 0.4);
      }
    }
    for (var i = 1; i < tipTrail.length; i++) {
      final k = 1.0 - (t - tipTrail[i].t) / 0.06;
      p.line(
        tipTrail[i - 1].p.$1,
        tipTrail[i - 1].p.$2,
        tipTrail[i].p.$1,
        tipTrail[i].p.$2,
        k > 0.6 ? kWhite : c[5],
        k,
      );
    }
    final q = t - _kCrack;
    if (q >= 0.0 && q < 0.035) {
      star(p, tipX, tipY, spikes, 1.0, 1.0, kWhite, c[5], c[6], c[4]);
    } else if (q >= 0.035 && q < 0.07) {
      star(p, tipX, tipY, spikes, 1.3, 0.5, c[6], c[5], c[5], c[3]);
    }
    if (q >= 0.02 && q < 0.2) {
      final k = (q - 0.02) / 0.18;
      final r = 4.0 + 16.0 * Ease.outCubic(k);
      final th = math.max(1.0, 2.2 * (1.0 - k));
      final col = k < 0.25
          ? kWhite
          : k < 0.5
              ? c[5]
              : k < 0.75
                  ? c[4]
                  : c[3];
      for (var a = 0.0; a < tau; a += 0.6 / r) {
        for (var o = 0.0; o < th; o += 0.5) {
          p.dot(
            tipX + math.cos(a) * (r - o),
            tipY + math.sin(a) * (r - o) * 0.8,
            col,
            1.15 - k,
          );
        }
      }
      p.glow(tipX, tipY, r + 6.0, c[4], 0.25 * (1.0 - k));
    }
    if (q >= 0.04 && q < 0.16) {
      final k = (q - 0.04) / 0.12;
      for (final s in slivers) {
        sliver(
          p,
          tipX,
          tipY,
          s.a,
          s.r + s.v * (q - 0.04),
          s.arc * (1.0 - 0.4 * k),
          k < 0.4 ? c[6] : c[5],
          1.0 - k,
        );
      }
    }
    if (q >= 0.0 && q < 0.15) {
      p.glow(tipX, tipY, 26.0, c[5], 0.7 * math.exp(-q / 0.04));
    }
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect whipCrackEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'melee/whip-crack',
    name: 'Whip crack',
    desc:
        'A whip rolls out to the right as a loop running down its length, faster and faster, until the tip flips over and cracks: a white pop, a ring of air, sparks and a puff of smoke.',
    category: 'melee',
    tags: [
      'melee',
      'whip',
      'crack',
      'lash',
      'combat',
      'directional',
      'one-shot',
    ],
    size: (192, 80),
    origin: (30, 68),
    duration: 0.85,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#2a1a10',
        '#5c3a1e',
        '#9c6a34',
        '#d8a45a',
        '#ffd890',
        '#fff4d6',
        '#ffffff',
      ],
      'sparks': ['#fff3a6', '#ffe26b', '#ff8a2a', '#f2561d'],
      'length': 76,
      'seed': 3,
    },
  ),
  act: ActSpec(
    target: const TargetSpec(x: 94),
    poses: [
      PoseKey(-0.46, _stance),
      PoseKey(-0.22, _cock),
      PoseKey(0.02, _cock.copyWith(lean: -4)),
      PoseKey(
        0.06,
        _crack.copyWith(fx: 15, fy: -34, sa: -0.7, lean: 2, ghost: 1),
        PoseEase.snap,
      ),
      PoseKey(0.12, _crack, PoseEase.snap),
      PoseKey(0.21, _crack),
      PoseKey(
        0.26,
        _crack.copyWith(fx: 15, fy: -27, sa: -0.3, lean: 2, crouch: 3),
        PoseEase.snap,
      ),
      PoseKey(
        0.44,
        _crack.copyWith(fx: 17, fy: -22, sa: 0.1, lean: 3, crouch: 3),
      ),
      PoseKey(0.92, _stance),
    ],
    hits: const [
      HitSpec(
        t: 0.21,
        stop: 0.1,
        shake: 0.14,
        amp: 2,
        push: 2.4,
        straw: 14,
        y: -28,
      ),
    ],
    dust: const [
      DustSpec(t: 0.06, x: 2, n: 4, dir: 1),
    ],
  ),
  onCreate: (o) => _WhipCrackSim(o),
);
