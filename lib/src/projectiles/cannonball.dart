import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'projectiles_lib.dart';

const _cannonballMeta = EffectMeta(
  id: 'projectiles/cannonball',
  name: 'Cannon shot',
  desc:
      'A cannon fires from a muzzle `height` px above the floor (the origin): a white flash, a tongue of flame, the ball arcing off trailing smoke, a big gunsmoke cloud rolling out.',
  category: 'projectiles',
  tags: [
    'projectile',
    'cannon',
    'cannonball',
    'smoke',
    'flash',
    'directional',
    'one-shot',
  ],
  size: (208, 116),
  origin: (48, 102),
  duration: 3.8,
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
      '#3a3542',
      '#55505e',
      '#736d7c',
      '#938d9b',
      '#b3adba',
      '#d2cdd6',
      '#ece8ee',
    ],
    'iron': ['#141218', '#2c2a34', '#4c4a58', '#8a8898'],
    'height': 12,
    'seed': 4,
  },
);

const _ang = -0.32;
const _f1 = 1 / 30;

final PixelEffect cannonballEffect = SimulatedEffect(
  meta: _cannonballMeta,
  onCreate: _CannonballSim.new,
);

class _CannonballSim extends BaseEffectSim {
  _CannonballSim(Map<String, Object?> o)
      : f = fit(o.palette, 9),
        sm = fit(o.rampOpt('smoke'), 7),
        ir = fit(o.rampOpt('iron'), 4),
        h = o.numOpt('height', 12),
        r = Rng(o.seed) {
    my = -h;
    ps = Particles(
      rng: r,
      ground: (_) => 0,
      sparks: [f[7], f[6], f[4], f[3]],
    );
    smoke = Smoke(r);
    lights = Lights();
    final ca = math.cos(_ang);
    final sa = math.sin(_ang);
    right = _cannonballMeta.size.$1 - _cannonballMeta.origin.$1 - 3.0;
    top = -_cannonballMeta.origin.$2 + 3.0;
    bx = 4;
    by = my;
    bvx = ca * 330;
    bvy = sa * 330;
    jit = List.generate(16, (_) => r.next());
    lights.add(12, my - 2, 44, hex('#ffb060'), 1, 0.35);
    lights.add(6, my, 18, kWhite, 0.9, 0.08);
    for (var i = 0; i < 22; i++) {
      final a = _ang + r.range(-0.45, 0.45);
      final sp = r.range(140, 380);
      ps.spawn(
        P.spark,
        6,
        my,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(0.1, 0.4),
      );
    }
    for (var i = 0; i < 10; i++) {
      final a = _ang + r.range(-0.3, 0.3);
      final sp = r.range(70, 170);
      ps.spawn(
        P.spark,
        6,
        my,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(0.5, 0.9),
      );
    }
    for (var i = 0; i < 8; i++) {
      final a = _ang + r.range(-0.5, 0.3);
      final sp = r.range(40, 110);
      ps.spawn(
        P.ember,
        8,
        my,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(0.7, 1.4),
        f[5],
        2,
      );
    }
    for (var i = 0; i < 34; i++) {
      final a = _ang + r.range(-0.4, 0.35);
      final sp = r.range(40, 260) * (i < 12 ? 1.1 : 0.75);
      smoke.add(SmokePuff(
        x: 6 + r.range(0, 6),
        y: my + r.range(-2, 2),
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp,
        r0: r.range(3, 4.5),
        r1: r.range(9, 16),
        life: r.range(2.7, 3.5),
        a: r.range(0.6, 0.75),
        b: r.range(0.9, 1),
        drag: r.range(2.2, 3.2),
        rise: r.range(7, 13),
        grow: r.range(1.5, 2.4),
        curl: r.range(-1.2, 0.4),
        warm: 1,
        delay: r.range(0, 0.05),
      ));
    }
  }

  final List<int> f;
  final List<int> sm;
  final List<int> ir;
  final double h;
  late final double my;
  final Rng r;
  late final Particles ps;
  late final Smoke smoke;
  late final Lights lights;
  late final double right;
  late final double top;
  late final List<double> jit;
  late double bx;
  late double by;
  late double bvx;
  late double bvy;
  bool ballOut = false;
  double t = 0;
  double wisp = 0;

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (!ballOut) {
      final x0 = bx;
      final y0 = by;
      bvy += 260 * dt;
      bx += bvx * dt;
      by += bvy * dt;
      for (wisp += hypot(bx - x0, by - y0) / 2; wisp > 1; wisp--) {
        final frac = r.next();
        final x = x0 + (bx - x0) * frac;
        final y = y0 + (by - y0) * frac;
        if (x < right - 8 && x > 24 && t < 0.6) {
          smoke.add(SmokePuff(
            x: x - 3,
            y: y,
            vx: -bvx * 0.04,
            vy: -bvy * 0.04,
            r0: 1,
            r1: r.range(2.5, 3.6) * (1 - t),
            life: r.range(0.7, 1.1),
            a: 0.5 * (1 - t),
            b: 0.95,
            drag: 2,
            rise: 5,
            grow: 2,
          ));
        }
      }
      if (bx > right || by < top) ballOut = true;
    }
    ps.update(dt);
    smoke.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    final pop = math.exp(-(t + 0.008) / 0.06);
    final list = smoke.puffs();
    for (final q in list) {
      q.w *= 0.2 + pop * 1.3;
    }
    cloud(
      p,
      list,
      sm,
      [
        sm[0],
        mix(f[1], sm[1], 0.5),
        mix(f[2], sm[2], 0.45),
        f[3],
        f[4],
        f[6],
        f[7],
      ],
      dens: 1.35,
      max: 0.86,
      lit: 1.3,
    );
    ps.draw(p);
    if (!ballOut) {
      final x = bx;
      final y = by;
      p.circle(x, y, 3.2, ir[0]);
      p.circle(x, y, 2.6, ir[1]);
      p.circle(x - 0.7, y - 0.7, 1.8, ir[2]);
      p.px(x - 1, y - 1.5, ir[3]);
      p.px(x - 2, y - 1, ir[3]);
      p.px(x + 1.5, y + 1, t < 0.3 ? f[5] : ir[2]);
      p.glow(x, y, 6, f[4], 0.45 * clamp(1 - t / 0.5));
    }
    if (t < 3 * _f1) {
      final fr = t < _f1
          ? 1
          : t < 2 * _f1
              ? 2
              : 3;
      final k = (fr == 1
              ? 1.0
              : fr == 2
                  ? 1.15
                  : 0.8) *
          1.3;
      final lobes = <FlashLobe>[
        FlashLobe(off: 0, a: 0, len: 12 * k, wid: 5 * k, core: 0.55),
        FlashLobe(
          off: 2,
          a: 0,
          len: (24 + jit[0] * 8) * k,
          wid: 2.2 * k,
          core: 0.4,
        ),
      ];
      for (var i = 0; i < 6; i++) {
        final a =
            (i < 3 ? -1 : 1) * (0.4 + (i % 3) * 0.45 + jit[i + 1] * 0.2);
        final down = math.sin(_ang + a);
        var len = (8 + jit[i + 7] * 7) * k * (fr == 3 ? 0.7 : 1);
        if (down > 0.1) len = math.min(len, (h - 3) / down);
        lobes.add(FlashLobe(
          off: 2,
          a: a,
          len: len,
          wid: 1.6 * k,
          core: 0.25,
        ));
      }
      flash(
        p,
        4,
        my,
        _ang,
        lobes,
        fr == 1
            ? [kWhite, f[7], f[6], f[3]]
            : fr == 2
                ? [f[7], f[6], f[4], f[2]]
                : [f[5], f[4], f[3], f[1]],
        fr,
      );
      if (fr == 1) {
        p.circle(7, my - 1, 6.5, kWhite);
        p.ring(7, my - 1, 7.5, 1, f[7]);
      }
    }
    lights.draw(p);
    p.glow(14, 0, 22, f[4], 0.25 * pop);
  }
}
