import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'projectiles_lib.dart';

const _muzzlePistolMeta = EffectMeta(
  id: 'projectiles/muzzle-pistol',
  name: 'Pistol shot',
  desc:
      'One pistol shot from a muzzle `height` px above the floor (the origin): a spiky white-cored flash, sparks, a curl of smoke hooking up and back, a casing that bounces and settles.',
  category: 'projectiles',
  tags: [
    'projectile',
    'muzzle',
    'gun',
    'pistol',
    'flash',
    'smoke',
    'casing',
    'directional',
    'one-shot',
  ],
  size: (96, 72),
  origin: (44, 66),
  duration: 1.8,
  loop: false,
  fps: 30,
  bg: BackdropKind.ground,
  defaultOptions: {
    'palette': [
      '#4a1712',
      '#8a1f17',
      '#c9281f',
      '#f2561d',
      '#ff8a2a',
      '#ffc23d',
      '#ffe26b',
      '#fff3a6',
      '#ffffff',
    ],
    'brass': ['#4a2e10', '#8c5c1c', '#d9a441', '#ffe39a'],
    'smoke': [
      '#26222e',
      '#3b3644',
      '#544e5e',
      '#6f6979',
      '#8c8596',
      '#aca5b5',
      '#cbc4d2',
    ],
    'height': 26,
    'seed': 3,
  },
);

const _f1 = 1 / 30;

final PixelEffect muzzlePistolEffect = SimulatedEffect(
  meta: _muzzlePistolMeta,
  onCreate: _MuzzlePistolSim.new,
);

class _MuzzlePistolSim extends BaseEffectSim {
  _MuzzlePistolSim(Map<String, Object?> o)
      : f = fit(o.palette, 9),
        b = fit(o.rampOpt('brass'), 4),
        sm = fit(o.rampOpt('smoke'), 7),
        seedOpt = o.seed,
        r = Rng(o.seed) {
    final h = o.numOpt('height', 26);
    my = -h;
    ps = Particles(
      rng: r,
      ground: (_) => 0,
      sparks: [f[7], f[6], f[4], f[3]],
    );
    smoke = Smoke(r);
    shapeSeed = r.intRange(0, 1000000);
    tilt = r.range(-0.05, 0.05);
    for (var i = 0; i < 6; i++) {
      final a = r.range(-0.3, 0.3);
      final sp = r.range(180, 400);
      ps.spawn(
        P.spark,
        3,
        my,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(0.06, 0.16),
      );
    }
    for (var i = 0; i < 5; i++) {
      final a = r.range(-0.35, 0.25);
      final sp = r.range(60, 160);
      ps.spawn(
        P.ember,
        3,
        my,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(0.25, 0.5),
        f[5],
      );
    }
    for (var i = 0; i < 3; i++) {
      smoke.add(SmokePuff(
        x: 3,
        y: my,
        vx: r.range(70, 120),
        vy: r.range(-12, 6),
        r0: 1.6,
        r1: r.range(4.5, 6),
        life: r.range(0.8, 1.05),
        a: 0.55,
        drag: 3.5,
        rise: 10,
        warm: 0.9,
        delay: i * 0.012,
      ));
    }
    for (var i = 0; i < 14; i++) {
      final k = i / 13;
      smoke.add(SmokePuff(
        x: 2,
        y: my,
        vx: 115 - 75 * k + r.range(-12, 12),
        vy: -6 - 10 * k + r.range(-5, 5),
        r0: 1.4,
        r1: (3.6 + k * 2.6) * r.range(0.75, 1.25),
        life: 1.15 + k * 0.3,
        a: 0.62,
        b: r.range(0.85, 1),
        drag: 2.2,
        rise: 6,
        curl: -4.4 + k * 1.8 + r.range(-0.5, 0.5),
        grow: 1.6,
        warm: 0.7,
        delay: 0.02 + i * 0.022,
      ));
    }
    smoke.add(SmokePuff(
      x: -7,
      y: my - 2,
      vx: -6,
      vy: -18,
      r0: 1.2,
      r1: 4,
      life: 1.05,
      a: 0.4,
      rise: 8,
      delay: 0.03,
    ));
    shellVx = -r.range(25, 45);
    shellVy = -r.range(95, 130);
    shellVa = r.sign() * r.range(22, 32);
    shellA0 = r.range(0, 6.28);
  }

  final List<int> f;
  final List<int> b;
  final List<int> sm;
  final int seedOpt;
  final Rng r;
  late final double my;
  late final Particles ps;
  late final Smoke smoke;
  late final int shapeSeed;
  late final double tilt;
  late final double shellVx;
  late final double shellVy;
  late final double shellVa;
  late final double shellA0;
  double t = 0;

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    ps.update(dt);
    smoke.update(dt);
  }

  @override
  void draw(Painter p) {
    final pop = math.exp(-(t + 0.008) / 0.035);
    final list = smoke.puffs();
    for (final q in list) {
      q.w *= 0.4 + pop;
    }
    cloud(
      p,
      list,
      sm,
      [
        sm[0],
        mix(f[1], sm[1], 0.5),
        mix(f[2], sm[2], 0.4),
        f[3],
        f[4],
        f[5],
        f[7],
      ],
      dens: 1.5,
      max: 0.8,
      lit: 1.4,
    );
    if (t < _muzzlePistolMeta.duration) {
      drawCasing(
        p,
        casing(-7, my - 1, shellVx, shellVy, shellVa, t, 850, -0.5, 0.42, shellA0),
        b,
        math.min(1.0, (_muzzlePistolMeta.duration - 0.05 - t) / 0.3),
      );
    }
    if (t < 2 * _f1) {
      final fr = t < _f1 ? 1 : 2;
      final lobes = flashShape(
        rng(shapeSeed),
        fr,
        size: 1.15,
        spike: const [15, 22],
        diag: const [7, 12],
        cross: const [4.5, 8],
        back: const [3, 5.5],
      );
      flash(
        p,
        0,
        my,
        tilt,
        lobes,
        fr == 1 ? [kWhite, f[7], f[6], f[3]] : [f[7], f[6], f[4], f[2]],
        fr + seedOpt,
      );
    }
    ps.draw(p);
    p.glow(4, my, 30, f[4], 0.85 * pop);
    p.glow(2, my, 8, kWhite, 0.5 * pop);
    p.glow(4, 0, 16, f[4], 0.2 * pop);
  }
}
