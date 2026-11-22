import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'projectiles_lib.dart';

const _muzzleSmgMeta = EffectMeta(
  id: 'projectiles/muzzle-smg',
  name: 'SMG burst',
  desc:
      'Sustained fire at twelve rounds a second: each shot a different spiky flash with a white core, sparks, smoke wisps piling up and drifting, brass casings bouncing on the floor.',
  category: 'projectiles',
  tags: [
    'projectile',
    'muzzle',
    'gun',
    'automatic',
    'flash',
    'smoke',
    'casing',
    'directional',
    'loop',
  ],
  size: (112, 72),
  origin: (56, 66),
  duration: 1,
  loop: true,
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
    'seed': 6,
  },
);

const _shots = 12;
const _f1 = 1 / 30;

void _eachShot(
  double t,
  double dDur,
  double life,
  void Function(int s, double age) fn,
) {
  for (var s = 0; s < _shots; s++) {
    for (var age = wrap(t - (s * dDur) / _shots + 1e-7, dDur);
        age < life;
        age += dDur) {
      fn(s, age);
    }
  }
}

final PixelEffect muzzleSmgEffect = PureEffect(
  meta: _muzzleSmgMeta,
  onDraw: (p, t, o) {
    final f = fit(o.palette, 9);
    final b = fit(o.rampOpt('brass'), 4);
    final sm = fit(o.rampOpt('smoke'), 7);
    final s = o.seed;
    const dDur = 1.0;
    final h = o.numOpt('height', 26);
    const mx = 0.0;
    final my = -h;
    final sp = [f[7], f[6], f[4], f[3]];
    final top = -_muzzleSmgMeta.origin.$2 + 1.0;

    var pop = 0.0;
    _eachShot(t, dDur, 0.2, (_, age) {
      pop = math.max(pop, math.exp(-(age + 0.008) / 0.035));
    });

    final puffs = <CloudPuff>[];
    _eachShot(t, dDur, 2.2, (shotIdx, age) {
      for (var j = 0; j < 3; j++) {
        final r = rng(s, shotIdx, j, 3);
        final life = r.range(1.5, 2.2);
        final dl = j * 0.03;
        if (age < dl || age - dl >= life) continue;
        final a = age - dl;
        final k = a / life;
        final port = j == 2;
        final vx = port ? r.range(-12, 6) : r.range(45, 100) * (1 - j * 0.4);
        final vy = port ? -r.range(14, 26) : -r.range(4, 16);
        final x = (port ? -7.0 : mx + 3) +
            (vx * (1 - math.exp(-3.2 * a))) / 3.2 -
            r.range(3, 7) * a * a +
            math.sin(a * 2.1 + r.range(0, tau)) * a * 2.5;
        final y = (port ? my - 2 : my) +
            (vy * (1 - math.exp(-2.4 * a))) / 2.4 -
            0.5 * r.range(9, 16) * a * a;
        final rad =
            (port ? 1.0 : 1.2) + r.range(2, 4.5) * (1 - math.exp(-1.4 * a));
        if (y - rad < top + 1) continue;
        final edge = math.min(1.0, (y - rad - top) / 12);
        puffs.add(CloudPuff(
          x: x,
          y: y,
          r: rad,
          a: math.min(1.0, a * 10) *
              math.pow(1 - k, 1.6) *
              (port ? 0.24 : 0.34) *
              edge,
          b: clamp(0.92 - k * 0.6),
          w: pop * math.exp(-hypot(x - mx, y - my) / 9),
        ));
      }
    });
    cloud(
      p,
      puffs,
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
      max: 0.7,
      lit: 1.3,
    );

    _eachShot(t, dDur, dDur, (shotIdx, age) {
      final r = rng(s, shotIdx, 7);
      final k = casing(
        -7,
        my - 1,
        -r.range(18, 48),
        -r.range(85, 135),
        r.sign() * r.range(20, 32),
        age,
        850,
        -0.5,
        0.42,
        r.range(0, tau),
      );
      drawCasing(p, k, b, clamp((dDur - age) / 0.25));
    });

    _eachShot(t, dDur, 2 * _f1, (shotIdx, age) {
      final r = rng(s, shotIdx);
      final fr = age < _f1 ? 1 : 2;
      final tilt = r.range(-0.06, 0.06);
      final lobes = flashShape(
        r,
        fr,
        size: r.range(0.95, 1.2),
        spike: const [12, 21],
        diag: const [6, 11],
        cross: const [4, 7.5],
        back: const [2.5, 5],
      );
      final c = fr == 1 ? [kWhite, f[7], f[6], f[3]] : [f[7], f[6], f[4], f[2]];
      flash(p, mx, my, tilt, lobes, c, shotIdx * 7 + fr);
    });

    _eachShot(t, dDur, 0.3, (shotIdx, age) {
      for (var j = 0; j < 5; j++) {
        final r = rng(s, shotIdx, j, 11);
        final life = r.range(0.05, 0.16) * (j > 2 ? 1.8 : 1);
        if (age >= life) continue;
        final a = r.range(-0.3, 0.3);
        final spd = r.range(170, 380) * (j > 2 ? 0.5 : 1);
        final (x, y) = fly(
          mx + 2,
          my,
          math.cos(a) * spd,
          math.sin(a) * spd,
          age,
          420,
          2.2,
        );
        final (vx, vy) = flyV(
          math.cos(a) * spd,
          math.sin(a) * spd,
          age,
          420,
          2.2,
        );
        if (j > 2) {
          p.px(x, y, age / life < 0.5 ? f[6] : f[4]);
        } else {
          spark(p, x, y, vx, vy, 1 - age / life, sp, 0.45, 0.011);
        }
      }
    });

    _eachShot(t, dDur, 0.15, (_, age) {
      final k = math.exp(-(age + 0.008) / 0.03);
      p.glow(mx + 4, my, 26, f[4], 0.8 * k);
      p.glow(mx + 2, my, 7, kWhite, 0.45 * k);
      p.glow(mx + 2, 0, 12, f[4], 0.16 * k);
    });
  },
);
