import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'projectiles_lib.dart';

const _muzzleShotgunMeta = EffectMeta(
  id: 'projectiles/muzzle-shotgun',
  name: 'Shotgun blast',
  desc:
      'A shotgun blast from a muzzle `height` px above the floor (the origin): a wide ragged fan of flame, pellet streaks, a heavy rolling smoke cloud, a red shell kicked out on the pump.',
  category: 'projectiles',
  tags: [
    'projectile',
    'muzzle',
    'gun',
    'shotgun',
    'flash',
    'smoke',
    'casing',
    'directional',
    'one-shot',
  ],
  size: (160, 88),
  origin: (44, 82),
  duration: 3.2,
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
    'smoke': [
      '#221e2a',
      '#36313f',
      '#4e4858',
      '#6a6474',
      '#888192',
      '#a8a1b1',
      '#c8c1cf',
    ],
    'shell': ['#4a0f14', '#9a1e22', '#d8423a', '#8c5c1c', '#e9b54a'],
    'height': 26,
    'seed': 5,
  },
);

const _f1 = 1 / 30;

List<FlashLobe> _fan(List<double> jit, int fr) {
  final k = fr == 1
      ? 1.0
      : fr == 2
          ? 0.82
          : 0.55;
  final w = fr == 1 ? 1.0 : 1.25;
  final l = <FlashLobe>[
    FlashLobe(off: 0.5, a: 0, len: 11 * k, wid: 3.6 * w, core: 0.5),
  ];
  for (var i = 0; i < 9; i++) {
    final u = i / 8 - 0.5;
    final a = u * 1.15 + jit[i * 3] * 0.12;
    final len = (17 + 11 * (1 - u.abs() * 1.4) + jit[i * 3 + 1] * 7) * k;
    l.add(FlashLobe(
      off: 2,
      a: a,
      len: len,
      wid: (1.7 + jit[i * 3 + 2]) * w,
      core: fr == 1 ? 0.32 : 0,
    ));
  }
  if (fr == 1) {
    for (final s in const [-1, 1]) {
      l.add(FlashLobe(
        off: 1,
        a: s * (1.6 + jit[27 + (s > 0 ? 1 : 0)] * 0.4),
        len: 5 + jit[29] * 3,
        wid: 1.2,
        core: 0,
      ));
    }
  }
  return l;
}

class _Pellet {
  const _Pellet(this.a, this.v, this.d0);

  final double a;
  final double v;
  final double d0;
}

final PixelEffect muzzleShotgunEffect = SimulatedEffect(
  meta: _muzzleShotgunMeta,
  onCreate: _MuzzleShotgunSim.new,
);

class _MuzzleShotgunSim extends BaseEffectSim {
  _MuzzleShotgunSim(Map<String, Object?> o)
      : f = fit(o.palette, 9),
        sm = fit(o.rampOpt('smoke'), 7),
        sh = fit(o.rampOpt('shell'), 5),
        r = Rng(o.seed) {
    final h = o.numOpt('height', 26);
    my = -h;
    ps = Particles(
      rng: r,
      ground: (_) => 0,
      sparks: [f[7], f[6], f[4], f[3]],
    );
    smoke = Smoke(r);
    right = _muzzleShotgunMeta.size.$1 - _muzzleShotgunMeta.origin.$1 - 2.0;
    jit = List.generate(32, (_) => r.next());
    pellets = List.generate(
      10,
      (_) => _Pellet(
        r.range(-0.13, 0.13),
        r.range(900, 1150),
        r.range(0, 4),
      ),
    );
    for (var i = 0; i < 16; i++) {
      final a = r.range(-0.55, 0.55);
      final sp = r.range(180, 460);
      ps.spawn(
        P.spark,
        4,
        my,
        math.cos(a) * sp,
        math.sin(a) * sp - 20,
        r.range(0.08, 0.3),
      );
    }
    for (var i = 0; i < 7; i++) {
      final a = r.range(-0.5, 0.3);
      final sp = r.range(70, 200);
      ps.spawn(
        P.ember,
        4,
        my,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(0.4, 0.9),
        f[5],
      );
    }
    for (var i = 0; i < 26; i++) {
      final a = r.range(-0.45, 0.35);
      final sp = r.range(60, 230) * (i < 8 ? 1.15 : 0.8);
      smoke.add(SmokePuff(
        x: 4 + r.range(0, 4),
        y: my + r.range(-1.5, 1.5),
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp,
        r0: r.range(2.5, 3.5),
        r1: r.range(7, 12.5),
        life: r.range(2.1, 2.9),
        a: r.range(0.55, 0.72),
        b: r.range(0.9, 1),
        drag: r.range(2.6, 3.6),
        rise: r.range(9, 15),
        grow: r.range(1.8, 2.8),
        warm: 1,
        delay: r.range(0, 0.04),
      ));
    }
    for (var i = 0; i < 6; i++) {
      smoke.add(SmokePuff(
        x: 2,
        y: my,
        vx: r.range(15, 50),
        vy: -r.range(10, 25),
        r0: 1.5,
        r1: r.range(4, 6),
        life: r.range(1.8, 2.4),
        a: 0.5,
        b: 1,
        drag: 2,
        rise: 10,
        curl: -r.range(1.5, 3),
        warm: 0.6,
        delay: 0.08 + i * 0.05,
      ));
    }
    shellVx = -r.range(30, 55);
    shellVy = -r.range(110, 150);
    shellVa = r.sign() * r.range(16, 24);
    shellA0 = r.range(0, 6.28);
  }

  static const double _shellT0 = 0.42;

  final List<int> f;
  final List<int> sm;
  final List<int> sh;
  final Rng r;
  late final double my;
  late final Particles ps;
  late final Smoke smoke;
  late final double right;
  late final List<double> jit;
  late final List<_Pellet> pellets;
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
    final pop = math.exp(-(t + 0.008) / 0.05);
    final list = smoke.puffs();
    for (final q in list) {
      q.w *= 0.25 + pop * 1.2;
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
      dens: 1.4,
      max: 0.86,
      lit: 1.4,
    );

    if (t > _shellT0 && t < _muzzleShotgunMeta.duration - 0.05) {
      final k = casing(
        -9,
        my,
        shellVx,
        shellVy,
        shellVa,
        t - _shellT0,
        850,
        -1,
        0.35,
        shellA0,
      );
      final ca = math.cos(k.a);
      final sa = math.sin(k.a);
      final fade = clamp((_muzzleShotgunMeta.duration - 0.05 - t) / 0.3);
      for (var d = -1.5; d <= 1.5; d += 0.5) {
        p.dot(
          k.x + ca * d,
          k.y + sa * d - 0.5,
          d > 0.8
              ? (d > 1.2 ? sh[4] : sh[3])
              : d > -0.6
                  ? sh[2]
                  : sh[1],
          fade,
        );
      }
      for (var d = -1.0; d <= 1; d += 0.5) {
        p.dot(
          k.x + ca * d - sa,
          k.y + sa * d + ca - 0.5,
          d > 0.6 ? sh[3] : sh[0],
          fade,
        );
      }
      if (k.hit >= 0 && k.hit < 0.07) {
        p.glow(k.x, k.y, 5, sh[4], 0.5 * (1 - k.hit / 0.07));
      }
    }

    if (t < 3 * _f1) {
      final fr = t < _f1
          ? 1
          : t < 2 * _f1
              ? 2
              : 3;
      flash(
        p,
        0,
        my,
        0,
        _fan(jit, fr),
        fr == 1
            ? [kWhite, f[7], f[6], f[3]]
            : fr == 2
                ? [f[7], f[6], f[4], f[2]]
                : [f[5], f[4], f[3], f[1]],
        fr + 9,
      );
    }

    if (t < 0.2) {
      for (final q in pellets) {
        final head = 6 + q.d0 + q.v * t;
        final tail = math.max(4.0, head - 26);
        final ca = math.cos(q.a);
        final sa = math.sin(q.a);
        for (var d = tail; d <= head; d += 0.5) {
          final x = ca * d;
          if (x > right) break;
          final u = (d - tail) / math.max(1.0, head - tail);
          p.dot(
            x,
            my + sa * d,
            u > 0.85
                ? kWhite
                : u > 0.5
                    ? f[6]
                    : f[4],
            u > 0.3 ? 1.0 : u / 0.3,
          );
        }
        if (ca * head < right) p.glow(ca * head, my + sa * head, 4, f[6], 0.5);
      }
    }
    ps.draw(p);
    p.glow(8, my, 46, f[4], 0.95 * pop);
    p.glow(4, my, 12, kWhite, 0.6 * pop);
    p.glow(10, 0, 30, f[4], 0.28 * pop);
  }
}
