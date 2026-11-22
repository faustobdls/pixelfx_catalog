// The impact (rocks thrown up that tumble and bounce and kick up dust where they land, gravel, dust rolling out
// along the floor and climbing, a ring on the floor, a white flash) is adapted from Sprite Fusion's open-source
// explosion (https://www.spritefusion.com/pixel-art-vfx/explosion), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'nature_lib.dart';

const double _x0 = 6.0;
const double _y0 = -26.0;
const double _vx = 220.0;
const double _vy = -170.0;
const double _g = 860.0;
const double _dur = 2.3;

void _surface(
  Painter p,
  double x,
  double y,
  double r,
  double a,
  List<int> s,
  List<int> m,
) {
  final c = math.cos(a);
  final sn = math.sin(a);
  (double, double) at(double u, double v) =>
      (x + (u * c - v * sn) * r, y + (u * sn + v * c) * r);
  for (final (u, v) in const [(0.42, 0.12), (-0.3, 0.38)]) {
    final (px, py) = at(u, v);
    p.px(px, py, s[3]);
  }
  for (var k = 0; k < 9; k++) {
    final g = 3.6 + (k / 8) * 1.3;
    final rr = k % 3 == 1 ? 0.78 : 0.92;
    final (px, py) = at(math.cos(g) * rr, math.sin(g) * rr);
    p.px(px, py, m[k % 3 == 1 ? 0 : (py < y ? 2 : 1)]);
  }
}

class _BoulderSim extends BaseEffectSim {
  final List<int> s;
  final Rng r;
  final double rad;
  final int dust;
  final int dust2;
  final Particles ps;
  final List<int> mossC;
  final Bits bits;
  final Lights lights;
  final List<Point2> shape;
  final double tHit;
  final double xHit;

  double t = 0.0;
  bool hit = false;
  bool thrown = false;

  _BoulderSim._({
    required this.s,
    required this.r,
    required this.rad,
    required this.dust,
    required this.dust2,
    required this.ps,
    required this.mossC,
    required this.bits,
    required this.lights,
    required this.shape,
    required this.tHit,
    required this.xHit,
  });

  factory _BoulderSim(Map<String, Object?> o) {
    final s = fit(o.palette, 8);
    final r = Rng(o.seed);
    double floorFn(double _) => 0.0;
    final rad = o.numOpt('size', 11.0);
    final dust = mix(s[6], hex('#9a8f86'), 0.4);
    final dust2 = mix(s[5], hex('#7a7068'), 0.35);
    final ps = Particles(rng: r, ground: floorFn, sparks: o.rampOpt('sparks'));
    final mossC = [hex('#1f3a1e'), hex('#3f7a2c'), hex('#7cb83a')];
    final bits = Bits(ground: floorFn);
    final lights = Lights();
    final shape = stoneShape(r, 8);
    final tHit = (-_vy + math.sqrt(_vy * _vy - 2 * _g * (_y0 + rad * 0.8))) / _g;
    final xHit = _x0 + _vx * tHit;
    return _BoulderSim._(
      s: s,
      r: r,
      rad: rad,
      dust: dust,
      dust2: dust2,
      ps: ps,
      mossC: mossC,
      bits: bits,
      lights: lights,
      shape: shape,
      tHit: tHit,
      xHit: xHit,
    );
  }

  Point2 _at(double tt) => (_x0 + _vx * tt, _y0 + _vy * tt + 0.5 * _g * tt * tt);

  void _rock({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required double drag,
    required double bounce,
    required double life,
    required double a,
    required double va,
    required double s,
  }) {
    bits.add(RockBit(
      kind: B.chunk,
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      g: 1,
      drag: drag,
      bounce: bounce,
      life: life,
      a: a,
      va: va,
      s: s,
      pts: stoneShape(r),
    ));
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final f = math.min(1.0, dt * 120);
    if (!thrown) {
      thrown = true;
      for (var i = 0; i < 6; i++) {
        ps.spawn(
          P.dust,
          _x0 - r.range(0, 6),
          _y0 + r.range(-4, 4),
          -r.range(20, 70),
          r.range(-20, 20),
          r.range(0.4, 0.7),
          dust,
          r.range(2.5, 4.5),
        );
      }
      lights.add(_x0, _y0, 30, kWhite, 0.3, 0.1);
    }
    if (t < tHit) {
      final (x, y) = _at(t);
      if (r.chance(0.5 * f)) {
        ps.spawn(
          P.dust,
          x - r.range(2, 6),
          y + r.range(-4, 4),
          -r.range(10, 40),
          r.range(-10, 10),
          r.range(0.3, 0.6),
          dust,
          r.range(2, 3.5),
        );
      }
      if (r.chance(0.12 * f)) {
        ps.spawn(
          P.grit,
          x + r.range(-4, 4),
          y + r.range(-2, 4),
          _vx * 0.3,
          r.range(-40, 20),
          r.range(0.6, 0.9),
          r.pick([s[5], s[4]]),
          r.chance(0.3) ? 2 : 1,
        );
      }
    }
    if (!hit && t >= tHit) {
      hit = true;
      final x = xHit;
      final y = -rad * 0.6;
      lights.add(x, y, 36, kWhite, 0.75, 0.1);
      lights.add(x, y, 60, hex('#ffb060'), 0.45, 0.5);
      for (var i = 0; i < 9; i++) {
        final a = -math.pi / 2 + r.range(-1.2, 1.1);
        final sp = r.range(100, 240);
        _rock(
          x: x + r.range(-5, 5),
          y: y + r.range(-5, 5),
          vx: math.cos(a) * sp + 30,
          vy: math.sin(a) * sp,
          drag: 0.7,
          bounce: 0.35,
          life: r.range(1.3, 1.7),
          a: r.range(0, tau),
          va: r.range(-14, 14),
          s: r.range(2.8, 5.2),
        );
      }
      for (var i = 0; i < 14; i++) {
        final a = -math.pi / 2 + r.range(-1.4, 1.4);
        final sp = r.range(120, 280);
        _rock(
          x: x + r.range(-4, 4),
          y: y,
          vx: math.cos(a) * sp + 25,
          vy: math.sin(a) * sp,
          drag: 0.8,
          bounce: 0.3,
          life: r.range(1.1, 1.5),
          a: r.range(0, tau),
          va: r.range(-18, 18),
          s: r.range(1.4, 2.6),
        );
      }
      for (var i = 0; i < 60; i++) {
        final u = r.range(-1, 1);
        final a = -math.pi / 2 + u * 1.1;
        final sp = r.range(80, 300) * (1 - 0.3 * u.abs());
        ps.spawn(
          P.grit,
          x + u * 6,
          -1,
          math.cos(a) * sp + 30,
          math.sin(a) * sp,
          r.range(1, 1.8),
          r.pick([s[6], s[5], s[4], s[4], s[3]]),
          r.chance(0.4) ? 2 : 1,
        );
      }
      for (var i = 0; i < 12; i++) {
        final a = -math.pi / 2 + r.range(-1.3, 1.3);
        final sp = r.range(150, 380);
        ps.spawn(
          P.spark,
          x,
          y,
          math.cos(a) * sp + 40,
          math.sin(a) * sp,
          r.range(0.15, 0.4),
        );
      }
      for (var i = 0; i < 14; i++) {
        final sd = r.sign();
        ps.spawn(
          P.smoke,
          x + sd * r.range(2, 10),
          -r.range(1, 5),
          sd * r.range(40, 140) + 10,
          -r.range(4, 20),
          r.range(1.1, 1.8),
          r.chance(0.5) ? dust : dust2,
          r.range(4.5, 8),
          r.range(0, 0.05),
          PF.big,
        );
      }
      for (var i = 0; i < 6; i++) {
        ps.spawn(
          P.smoke,
          x + r.range(-6, 6),
          -r.range(4, 14),
          r.range(-15, 25),
          -r.range(30, 80),
          r.range(1.2, 1.8),
          dust,
          r.range(6, 9),
          r.range(0, 0.1),
          PF.big,
        );
      }
      for (var i = 0; i < 3; i++) {
        ps.spawn(
          P.star,
          x + r.range(-8, 8),
          y + r.range(-10, 4),
          0,
          -4,
          r.range(0.2, 0.4),
          s[7],
          r.range(1, 2),
        );
      }
    }
    bits.update(dt);
    for (final b in bits.list) {
      if (b is RockBit && b.rest && !b.dusted) {
        b.dusted = true;
        for (var i = 0; i < 2; i++) {
          ps.spawn(
            P.dust,
            b.x + r.range(-1.5, 1.5),
            -0.5,
            r.sign() * r.range(8, 35),
            -r.range(2, 12),
            math.min(r.range(0.3, 0.6), _dur - 0.05 - t),
            dust2,
            r.range(1.3, 2.6),
          );
        }
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final e = t - tHit;
    if (e > 0) {
      final fade = 1 - smooth(_dur - 0.6, _dur - 0.15, t);
      final w = 10 * math.min(1.0, e / 0.05);
      for (var x = (-w).floor(); x <= w; x++) {
        final d = x.abs() / w;
        p.dot(xHit + x, 0, d < 0.6 ? s[0] : s[1], fade);
        if (d < 0.5) p.dot(xHit + x, 1, s[1], fade * 0.8);
      }
      for (final sd in const [-1, 1]) {
        for (var k = 0; k < 4; k++) {
          p.dot(
            xHit + sd * (w + 2 + k * 3),
            (k & 1) != 0 ? 1 : 0,
            s[1],
            fade * (1 - k / 4),
          );
        }
      }
      final k = e / 0.45;
      if (k < 1) {
        band(
          p,
          xHit,
          0.5,
          46 * Ease.outCubic(k),
          0.18,
          math.max(1.0, 3 * (1 - k)),
          1.15 - k,
          [s[4], s[6], hex('#ffd27a'), kWhite],
          keep: (g) => math.sin(g) < 0,
        );
      }
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    if (t < tHit) {
      final (x, y) = _at(t);
      final sp = hypot(_vx, _vy + _g * t);
      final ux = _vx / sp;
      final uy = (_vy + _g * t) / sp;
      for (var i = 0; i < 4; i++) {
        final off = (i - 1.5) * rad * 0.55;
        final nx = -uy * off;
        final ny = ux * off;
        final l = 10.0 + (i % 2) * 6;
        p.line(
          x - ux * (rad + 2) + nx,
          y - uy * (rad + 2) + ny,
          x - ux * (rad + 2 + l) + nx,
          y - uy * (rad + 2 + l) + ny,
          (i % 2) != 0 ? s[5] : s[6],
          0.8,
        );
      }
      drawRock(p, x, y, rad, t * 13, shape, s);
      _surface(p, x, y, rad * 0.8, t * 13, s, mossC);
      p.glow(x, y, rad * 2, s[6], 0.12);
    }
    final e = t - tHit;
    if (e >= 0 && e < 0.07) {
      drawRock(p, xHit, -rad * 0.8, rad, tHit * 13, shape, s, 1, true);
      sparkle(
        p,
        xHit,
        -rad * 0.6,
        12 * (1 - e / 0.07),
        kWhite,
        hex('#ffd27a'),
        0.6,
      );
    }
    if (e >= 0 && e < 0.14) {
      final k = e / 0.14;
      for (var i = 0; i < 9; i++) {
        final a = -math.pi + (i / 8) * math.pi;
        final r0 = rad + 4 + 16 * k;
        final r1 = r0 + 8 * (1 - k);
        p.line(
          xHit + math.cos(a) * r0,
          -rad * 0.6 + math.sin(a) * r0,
          xHit + math.cos(a) * r1,
          -rad * 0.6 + math.sin(a) * r1,
          k < 0.5 ? kWhite : s[6],
        );
      }
    }
    if (e > 0) {
      final k = e / 0.45;
      if (k < 1) {
        band(
          p,
          xHit,
          0.5,
          46 * Ease.outCubic(k),
          0.18,
          math.max(1.0, 3 * (1 - k)),
          1.15 - k,
          [s[4], s[6], hex('#ffd27a'), kWhite],
          keep: (g) => math.sin(g) >= 0,
        );
      }
    }
    for (final b in bits.list) {
      if (b is RockBit) {
        drawRock(p, b.x, b.y, b.s, b.a, b.pts, s, math.min(1.0, b.life / 0.4));
      }
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final PixelEffect boulder = SimulatedEffect(
  meta: const EffectMeta(
    id: 'nature/boulder',
    name: 'Boulder',
    desc:
        'A spinning boulder arcs right shedding dust and pebbles, smashes into the floor in a white flash and bursts into tumbling chunks, gravel and rolling dust.',
    category: 'nature',
    tags: [
      'nature',
      'earth',
      'rock',
      'projectile',
      'impact',
      'directional',
      'one-shot',
    ],
    size: (264, 120),
    origin: (40, 104),
    duration: 2.3,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#100e12',
        '#1e1a22',
        '#302a36',
        '#463e4c',
        '#5e5464',
        '#7c7080',
        '#a0949e',
        '#cec4c8',
      ],
      'sparks': ['#fff3a6', '#ffe26b', '#ff8a2a', '#f2561d'],
      'size': 11,
      'seed': 11,
    },
  ),
  onCreate: _BoulderSim.new,
);
