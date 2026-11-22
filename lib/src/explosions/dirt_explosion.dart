// The earth recipe (grit thrown in a fan, rocks that bounce and kick up dust, a dust column and dust rolling out along
// the floor) is adapted from Sprite Fusion's open-source explosion (https://www.spritefusion.com/pixel-art-vfx/explosion),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'explosions_lib.dart';

class _DirtExplosionSim extends BaseEffectSim {
  final EffectMeta meta;
  final List<int> e, f;
  final Rng r;
  final double x0, x1, y0, y1;
  final StoneColors clod;
  final int dust, soil, dark;
  late final Particles ps;
  final Lights lights = Lights();
  final Bits clods = Bits(ground: (_) => 0.0);
  double t = 0.0;

  _DirtExplosionSim(this.meta, Map<String, Object?> o)
      : e = fit(o.palette, 7),
        f = fit(
          (o['fire'] as List<Object?>?)?.cast<Object>() ??
              const [
                '#4a1712',
                '#c9281f',
                '#f2561d',
                '#ff8a2a',
                '#ffc23d',
                '#ffe26b',
                '#fff3a6',
                '#ffffff',
              ],
          8,
        ),
        r = Rng(o.seed),
        x0 = -meta.origin.$1 + 3.0,
        x1 = meta.size.$1 - meta.origin.$1 - 3.0,
        y0 = -meta.origin.$2 + 3.0,
        y1 = meta.size.$2 - meta.origin.$2 - 3.0,
        clod = StoneColors(
          fit(o.palette, 7)[5],
          fit(o.palette, 7)[3],
          fit(o.palette, 7)[2],
          fit(o.palette, 7)[4],
        ),
        dust = mix(fit(o.palette, 7)[4], rgb(150, 140, 150), 0.2),
        soil = mix(fit(o.palette, 7)[3], rgb(90, 80, 90), 0.2),
        dark = mix(fit(o.palette, 7)[2], rgb(60, 52, 60), 0.3) {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [f[6], f[5], f[3], f[2]],
    );
    lights.add(0, -10, 56, f[4], 0.7, 0.22);
    lights.add(0, -4, 26, kWhite, 0.6, 0.06);

    for (var i = 0; i < 14; i++) {
      final a = -math.pi / 2 + r.range(-0.7, 0.7);
      final sp = r.range(160, 320);
      ps.spawn(
          P.spark, 0, -2, math.cos(a) * sp, math.sin(a) * sp, r.range(0.15, 0.35));
    }
    for (var i = 0; i < 300; i++) {
      final side = r.sign();
      final a = -math.pi / 2 + side * r.range(0.05, 0.62);
      final sp = r.range(150, 470) * (1.0 - 0.3 * (a + math.pi / 2).abs());
      ps.spawn(
        P.grit,
        r.range(-4, 4),
        -1.0,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(1.2, 2.2),
        r.pick([e[1], e[2], e[2], e[3], e[3], e[4], e[5]]),
        r.chance(0.45) ? 2.0 : 1.0,
        r.range(0, 0.06),
      );
    }
    for (var i = 0; i < 30; i++) {
      final side = r.sign();
      final a = -math.pi / 2 + side * r.range(0.1, 0.6);
      final sp = r.range(200, 430);
      clods.add(ExplosionBit(
        kind: B.chunk,
        x: r.range(-5, 5),
        y: -2.0,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp,
        g: 1.0,
        drag: 0.35,
        bounce: 0.25,
        life: r.range(2.2, 3),
        a: r.range(0, tau),
        va: r.range(-12, 12),
        s: i < 12 ? r.range(2.6, 3.8) : r.range(1.4, 2.4),
      ));
    }
    for (var i = 0; i < 22; i++) {
      ps.spawn(
        P.smoke,
        r.range(-7, 7),
        -r.range(2, 12),
        r.range(-25, 25),
        -r.range(70, 180),
        r.range(1.8, 2.6),
        r.chance(0.6) ? soil : dust,
        r.range(9, 14),
        r.range(0, 0.14),
        PF.big,
      );
    }
    for (var i = 0; i < 14; i++) {
      final side = r.sign();
      final a = -math.pi / 2 + side * r.range(0.35, 0.6);
      final sp = r.range(110, 210);
      ps.spawn(
        P.smoke,
        side * r.range(2, 8),
        -r.range(2, 8),
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(1.6, 2.4),
        r.chance(0.5) ? soil : dust,
        r.range(8, 12),
        r.range(0.02, 0.1),
        PF.big,
      );
    }
    for (var i = 0; i < 16; i++) {
      final s = r.sign();
      ps.spawn(
        P.smoke,
        s * r.range(4, 16),
        -r.range(1, 5),
        s * r.range(70, 200),
        -r.range(2, 12),
        r.range(1.4, 2.2),
        dust,
        r.range(6, 9),
        r.range(0.02, 0.1),
        PF.big,
      );
    }
    for (var i = 0; i < 8; i++) {
      ps.spawn(
        P.smoke,
        r.range(-8, 8),
        -r.range(2, 8),
        r.range(-40, 40),
        -r.range(40, 110),
        r.range(1.2, 1.8),
        dark,
        r.range(6, 9),
        r.range(0, 0.05),
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    for (final b in clods.list) {
      (b as ExplosionBit).pvy = b.vy;
    }
    clods.update(dt);
    for (var i = clods.list.length - 1; i >= 0; i--) {
      final b = clods.list[i] as ExplosionBit;
      if (b.x < x0 + 4.0 || b.x > x1 - 4.0) {
        clods.list.removeAt(i);
        continue;
      }
      final landed = (b.pvy > 0.0 && b.vy <= 0.0) || (b.rest && !b.thud);
      if (!landed || b.pvy < 80.0) {
        if (b.rest) b.thud = true;
        continue;
      }
      b.thud = b.rest;
      for (var j = 0; j < 2 + (b.size + 0.5).floor(); j++) {
        ps.spawn(
          P.dust,
          b.x + r.range(-2, 2),
          -0.5,
          r.sign() * r.range(15, 55),
          -r.range(4, 22),
          r.range(0.35, 0.7),
          dust,
          r.range(1.6, 1.2 + b.size),
        );
      }
      for (var j = 0; j < (b.size * 3.0 + 0.5).floor(); j++) {
        ps.spawn(
          P.grit,
          b.x,
          -1.0,
          r.range(-70, 70),
          -r.range(40, 140),
          r.range(0.8, 1.4),
          r.pick([e[2], e[3], e[4]]),
          1.0,
        );
      }
      if (b.size > 2.2 && b.pvy > 200.0) b.size *= 0.6;
    }
    ps.update(dt);
    cullParticles(ps, x0, y0, x1, y1);
    fadeEdges(ps, x0, x1, 24.0, y1);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    crater(
      p,
      e,
      0,
      28,
      Ease.outCubic(math.min(1.0, t / 0.12)),
      1.0 - smooth(meta.duration - 0.7, meta.duration - 0.1, t),
    );
    final k = t / 0.45;
    if (k < 1.0) {
      band(
        p,
        0,
        0.5,
        90.0 * Ease.outCubic(k),
        0.16,
        math.max(1.0, 3.0 * (1.0 - k)),
        1.1 - k,
        [e[2], e[4], e[5], e[6]],
        keep: (g) => math.sin(g) < 0.0,
      );
    }
    drawDirt(p, ps, 'back');
  }

  @override
  void draw(Painter p) {
    final k = t / 0.45;
    if (k < 1.0) {
      band(
        p,
        0,
        0.5,
        90.0 * Ease.outCubic(k),
        0.16,
        math.max(1.0, 3.0 * (1.0 - k)),
        1.1 - k,
        [e[2], e[4], e[5], e[6]],
        keep: (g) => math.sin(g) >= 0.0,
      );
    }
    if (t < 0.09) dome(p, f, 0, 15.0 * (1.0 - t * 3.0), 1.0 - t / 0.09);
    for (final b in clods.list) {
      drawRock(p, b as ExplosionBit, clod, f);
    }
    drawDirt(p, ps, 'front');
    lightPool(p, 0, 1, 60, 10, f[3], 0.5 * math.max(0.0, 1.0 - t / 0.3));
    lights.draw(p);
  }
}

const EffectMeta _dirtExplosionMeta = EffectMeta(
  id: 'explosions/dirt-explosion',
  name: 'Dirt explosion',
  desc:
      'A buried charge goes off: a flash under the floor, a V of dirt clods and grit thrown high, a brown dust plume that billows and settles, and a crater left behind.',
  category: 'explosions',
  tags: ['explosion', 'dirt', 'earth', 'dust', 'debris', 'ground', 'one-shot'],
  size: (260, 240),
  origin: (130, 206),
  duration: 3.6,
  loop: false,
  fps: 30,
  bg: BackdropKind.ground,
  defaultOptions: {
    'palette': [
      '#1c1610',
      '#33281c',
      '#4f3f2c',
      '#6e5a40',
      '#927a58',
      '#b89f78',
      '#dcc8a2',
    ],
    'fire': [
      '#4a1712',
      '#c9281f',
      '#f2561d',
      '#ff8a2a',
      '#ffc23d',
      '#ffe26b',
      '#fff3a6',
      '#ffffff',
    ],
    'seed': 3,
  },
);

final SimulatedEffect dirtExplosionEffect = SimulatedEffect(
  meta: _dirtExplosionMeta,
  onCreate: (o) => _DirtExplosionSim(_dirtExplosionMeta, o),
);
