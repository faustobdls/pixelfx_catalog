// The crescent and trace recipe is adapted from Sprite Fusion's open-source slash, and the vapour from his
// ice and poison (https://www.spritefusion.com/pixel-art-vfx), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'melee_lib.dart';

final Pose _rest = kReady.copyWith(
  weapon: 'scythe',
  x: 2,
  sa: -1.5,
  fx: 11,
  fy: -22,
  bx: 7,
  by: -16,
);

final Pose _out = _rest.copyWith(
  two: true,
  crouch: 4,
  lean: 4,
  fx: 17,
  fy: -27,
  sa: -0.45,
  ffx: 11,
  fbx: -8,
);

final Pose _end = _rest.copyWith(
  two: true,
  x: 0,
  yaw: 3.14,
  crouch: 6,
  lean: 4,
  fx: 15,
  fy: -24,
  sa: 0.3,
  ffx: 11,
  fbx: -10,
  toeB: true,
);

const double _kWind = 0.08;
const double _kSweep = 0.34;
const double _kHang = 0.14;
const double _kTear = 0.55;
const double _kT0 = _kWind;
const double _kT1 = _kWind + _kSweep;
const double _kT2 = _kT1 + _kHang;
const double _kT3 = _kT2 + _kTear;
const double _kW = 21.0;

double _head(double t) => Ease.inOutSine(clamp((t - _kT0) / _kSweep));

class _Wisp {
  double x;
  double y;
  double vx;
  double vy;
  final double life;
  double max = 0.0;
  final double seed;
  final List<Point2> pts = [];
  final bool far;

  _Wisp({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.seed,
    required this.far,
  });
}

class _ScytheReapSim extends BaseEffectSim {
  final List<int> c;
  final Rng rg;
  late final Particles ps;
  final Lights lights = Lights();
  late final Swing a;
  final List<_Wisp> wisps = [];
  double t = 0.0;
  double lastTear = 0.0;

  _ScytheReapSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        rg = Rng(o.seed) {
    ps = Particles(rng: rg, ground: (_) => 0.0, haze: c[5]);
    a = Swing(
      cx: 8.0,
      cy: -33.0,
      r: 52.0,
      sy: 0.6,
      k: 0.1,
      rot: 0.08,
      a0: -0.5,
      dir: 1.0,
      span: 3.5,
    );
  }

  double _tear() => smooth(_kT2, _kT3, t);

  void _addWisp(double x, double y, bool far) {
    wisps.add(
      _Wisp(
        x: x,
        y: y,
        vx: rg.range(-12.0, 12.0),
        vy: -rg.range(8.0, 26.0),
        life: rg.range(0.5, 0.9),
        seed: rg.range(0.0, 100.0),
        far: far,
      ),
    );
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (t < _kWind && rg.chance(0.5)) {
      final (x, y) = onSwing(a, a.r - 4.0, 0.0);
      ps.spawn(
        P.vapour,
        x + rg.range(-14.0, 14.0),
        y + rg.range(-8.0, 8.0),
        rg.range(-10.0, 10.0),
        rg.range(-6.0, 6.0),
        rg.range(0.3, 0.5),
        c[5],
        rg.range(1.5, 2.5),
      );
    }
    if (t > _kT0 && t < _kT1 && rg.chance(0.5)) {
      final tr = swingTravel(a, a.span * _head(t) * rg.range(0.75, 1.0));
      ps.spawn(
        P.vapour,
        tr.x,
        tr.y,
        tr.dx * 20.0,
        -rg.range(4.0, 14.0),
        rg.range(0.5, 0.9),
        c[6],
        rg.range(2.0, 3.5),
        0.0,
        math.sin(tr.a) < 0.0 ? PF.back : 0,
      );
    }
    final k = _tear();
    for (var u = lastTear; u < k * 1.15; u += 0.022) {
      final uu = math.min(1.0, u) * a.span;
      final tr = swingTravel(a.copyWith(r: a.r - rg.range(0.0, 8.0)), uu);
      final far = math.sin(tr.a) < 0.0;
      _addWisp(tr.x, tr.y, far);
      if (rg.chance(0.5)) {
        ps.spawn(
          P.vapour,
          tr.x,
          tr.y,
          rg.range(-10.0, 10.0),
          -rg.range(6.0, 18.0),
          rg.range(0.55, 0.85),
          rg.chance(0.5) ? c[5] : c[4],
          rg.range(2.5, 4.5),
          0.0,
          far ? PF.back : 0,
        );
      }
      if (rg.chance(0.2)) {
        ps.spawn(
          P.star,
          tr.x + rg.range(-3.0, 3.0),
          tr.y + rg.range(-3.0, 3.0),
          0.0,
          -6.0,
          rg.range(0.25, 0.5),
          rg.chance(0.5) ? c[6] : kWhite,
          rg.range(0.6, 1.6),
          0.0,
          far ? PF.back : 0,
        );
      }
    }
    lastTear = math.max(lastTear, k * 1.15);
    for (var i = wisps.length - 1; i >= 0; i--) {
      final w = wisps[i];
      w.max += dt;
      if (w.max > w.life) {
        wisps.removeAt(i);
        continue;
      }
      w.vy -= 30.0 * dt;
      w.vx += math.sin(w.max * 9.0 + w.seed) * 120.0 * dt;
      w.vx -= w.vx * 2.0 * dt;
      w.vy -= w.vy * 1.2 * dt;
      w.x += w.vx * dt;
      w.y += w.vy * dt;
      w.pts.add((w.x, w.y));
      if (w.pts.length > 14) w.pts.removeAt(0);
    }
    ps.update(dt);
    lights.update(dt);
  }

  void _blade(Painter p, int half) {
    final uEnd = a.span * _head(t);
    final k = _tear();
    if (uEnd < 0.02 || k >= 1.0) return;
    final ramp = half < 0
        ? [c[0], c[0], c[1], c[2], c[3], c[4], c[5], c[6]]
        : c;
    smear(p, a, 0.0, uEnd, _kW, (u, r, out, _) {
      final v = u / uEnd;
      final sinTerm = math.max(
        0.0,
        math.sin(math.pi * math.pow(v, 1.7)),
      );
      final w = _kW * math.pow(sinTerm, 0.55);
      if (w < 0.5) return;
      final q = (a.r - r) / w;
      if (q < 0.0 || q > 1.0) return;
      final n = rand((u * 40.0).floor(), r.floor(), 7);
      if (k > 0.0 && (u / a.span) < k * 1.2 - n * 0.2) return;
      final ci = q < 0.08
          ? 7
          : q < 0.16
              ? 6
              : q < 0.25
                  ? 5
                  : q < 0.4
                      ? 4
                      : q < 0.62
                          ? 3
                          : 2;
      out.c = ramp[t > _kT1 && q < 0.2 ? ci - 1 : ci];
      out.a = math.min(1.0, v / 0.25);
    }, half: half);
    glowAlong(
      p,
      a,
      a.r - 2.0,
      math.max(0.0, k * 1.2 * a.span - 0.3),
      uEnd,
      14.0,
      c[5],
      0.0,
      kFn: (u) => 0.3 * (u / uEnd),
      half: half,
      step: 0.25,
    );
  }

  void _threads(Painter p, bool back) {
    for (final w in wisps) {
      if (w.far != back) continue;
      final life = 1.0 - w.max / w.life;
      for (var i = 1; i < w.pts.length; i++) {
        final f = i / w.pts.length;
        p.line(
          w.pts[i - 1].$1,
          w.pts[i - 1].$2,
          w.pts[i].$1,
          w.pts[i].$2,
          f > 0.75
              ? c[6]
              : f > 0.4
                  ? c[5]
                  : c[3],
          life * (0.3 + 0.7 * f),
        );
      }
      if (life > 0.5) p.glow(w.x, w.y, 5.0, c[5], 0.25 * life);
    }
  }

  @override
  void drawBack(Painter p) {
    _blade(p, -1);
    ps.draw(p, 'back');
    _threads(p, true);
  }

  @override
  void draw(Painter p) {
    _blade(p, 1);
    if (t < _kWind + 0.05) {
      final (x, y) = onSwing(a, a.r - 3.0, 0.0);
      sparkle(
        p,
        x,
        y,
        6.0 * math.min(1.0, t / 0.04) * (1.0 - smooth(_kWind - 0.02, _kWind + 0.05, t)),
        c[6],
        c[5],
        0.45,
      );
    }
    final g = t - _kT1 + 0.06;
    if (g > 0.0 && g < 0.3) {
      final (x, y) = onSwing(a, a.r - 3.0, a.span);
      sparkle(
        p,
        x,
        y,
        9.0 * Ease.outBack(math.min(1.0, g / 0.06)) * (1.0 - g / 0.3),
        c[6],
        c[5],
        0.55,
      );
    }
    ps.draw(p, 'front');
    _threads(p, false);
    lights.draw(p);
  }
}

final SimulatedEffect scytheReapEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'melee/scythe-reap',
    name: 'Scythe reap',
    desc:
        'A slow, huge dark crescent reaps round the front with a pale ghostly edge; it hangs, then tears away from the tail into curling wisps and cold vapour.',
    category: 'melee',
    tags: [
      'melee',
      'scythe',
      'reap',
      'dark',
      'ghost',
      'death',
      'slash',
      'combat',
      'one-shot',
    ],
    size: (184, 116),
    origin: (84, 98),
    duration: 2.1,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#07040c',
        '#140a22',
        '#24113a',
        '#3b1d58',
        '#5a3a82',
        '#7fd6c0',
        '#d8fff2',
        '#ffffff',
      ],
      'seed': 13,
    },
  ),
  act: ActSpec(
    target: const TargetSpec(x: 66),
    poses: [
      PoseKey(-0.56, _rest),
      PoseKey(-0.26, _out),
      PoseKey(0.08, _out.copyWith(crouch: 5)),
      PoseKey(
        0.2,
        _out.copyWith(
          yaw: 0.8,
          crouch: 5,
          lean: 3,
          fx: 16,
          fy: -23,
          sa: 0.1,
          ghost: 1,
        ),
      ),
      PoseKey(
        0.3,
        _out.copyWith(
          x: 1,
          yaw: 1.9,
          crouch: 6,
          lean: 3,
          fx: 15,
          fy: -23,
          sa: 0.2,
          ghost: 1,
        ),
      ),
      PoseKey(0.42, _end),
      PoseKey(0.92, _end.copyWith(crouch: 5)),
      PoseKey(1.3, _rest.copyWith(x: 1, yaw: 1.4, crouch: 4)),
      PoseKey(1.7, _rest),
    ],
    hits: const [
      HitSpec(
        t: 0.14,
        stop: 0.12,
        shake: 0.16,
        amp: 2,
        push: 2.4,
        straw: 20,
        skin: 'shadow',
      ),
    ],
    dust: const [
      DustSpec(t: 0.3, x: 2, n: 6),
    ],
  ),
  onCreate: (o) => _ScytheReapSim(o),
);
