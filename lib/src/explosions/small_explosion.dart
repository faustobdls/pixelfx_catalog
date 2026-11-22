// The particle recipe is adapted from Sprite Fusion's open-source explosion
// (https://www.spritefusion.com/pixel-art-vfx/explosion), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

final int _soot = hex('#0d0a12');
final int _soot2 = hex('#17121d');
final int _outline = hex('#1a1422');
final int _warm = rgb(255, 176, 96);

class _StoneColors {
  final int light;
  final int body;
  final int shade;
  final int dust;
  _StoneColors(this.light, this.body, this.shade, this.dust);
}

_StoneColors _stone(Object cRaw) {
  final c = hex(cRaw);
  return _StoneColors(
    mix(scaleColor(c, 1.35), kWhite, 0.08),
    c,
    scaleColor(c, 0.64),
    mix(scaleColor(c, 1.2), rgb(150, 140, 150), 0.3),
  );
}

void _scorch(
  Painter p,
  List<int> f,
  double t,
  double rx0,
  double cool,
  double fade,
) {
  if (fade <= 0.0) return;
  final rx = rx0 * math.min(1.0, t / 0.08);
  const ry = 4.0;
  final heat = f.reversed.toList(growable: false);
  final x0 = (-rx).floor();
  final x1 = rx.ceil();
  for (var y = 0; y <= 2; y++) {
    for (var x = x0; x <= x1; x++) {
      final dx = (x + 0.5) / rx;
      final dy = (y + 0.5) / ry;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > 1.0) continue;
      final k = rand(x * 31 + y, 3);
      final temp =
          math.pow(clamp(1.0 - t / cool), 1.4).toDouble() * (1.25 - d) -
              k * 0.35;
      if (temp > 0.06) {
        final idx = math.min(
          heat.length - 1,
          ((1.0 - math.min(1.0, temp)) * (heat.length - 1)).floor(),
        );
        final c = heat[idx];
        p.dot(x, y, c, fade);
        if ((x & 3) == 0) p.glow(x + 0.5, y, 6, c, 0.18 * temp * fade);
      } else {
        p.dot(x, y, d < 0.5 ? _soot : _soot2,
            (d < 0.95 - k * 0.3 ? 1.0 : 1.0 - d) * fade);
      }
    }
  }
}

class _RockBit extends DebrisBit {
  bool dusted = false;
  _RockBit({
    required super.x,
    required super.y,
    required super.vx,
    required super.vy,
    required super.a,
    required super.va,
    required super.s,
    required super.life,
  }) : super(kind: DebrisKind.chunk, g: 1.0, drag: 0.4, bounce: 0.3);
}

void _drawRock(Painter p, _RockBit b, _StoneColors st) {
  final r = 0.6 + b.s * 0.75;
  final fade = math.min(1.0, b.life / 0.5);
  final lx = math.cos(b.a) * r * 0.4;
  final ly = math.sin(b.a) * r * 0.4;
  p.shade(b.x - r - 1, b.y - r - 1, b.x + r + 1, b.y + r + 1, (x, y, out) {
    final dx = x - b.x;
    final dy = y - b.y;
    final d = hypot(dx * 1.15, dy);
    if (d > r + 0.9) return null;
    final lit = dx * lx + dy * ly;
    out.c = d > r
        ? _outline
        : (lit < -0.4 ? st.light : (lit > 0.6 ? st.shade : st.body));
    out.a = fade;
    return null;
  });
}

class _Flash {
  final double r;
  double life;
  final double max;
  _Flash(this.r, this.life) : max = life;
}

class _ShockRing {
  final double r0, r1, thick;
  final int c;
  double life;
  final double max;
  _ShockRing(this.r0, this.r1, this.life, this.thick, this.c) : max = life;
}

class _SmallExplosionSim extends BaseEffectSim {
  final EffectMeta meta;
  final List<int> f;
  final double s;
  final double rad;
  final _StoneColors st;
  final Rng r;
  late final Particles ps;
  late final Blazes blazes;
  final Bits rocks = Bits(ground: (_) => 0.0);
  final Lights lights = Lights();
  final List<_Flash> flashes = [];
  final List<_ShockRing> rings = [];
  final double yOff;
  double t = 0.0;

  _SmallExplosionSim(this.meta, Map<String, Object?> o)
      : f = fit(o.palette, 8),
        s = o.numOpt('size', 1.0),
        rad = 18.0 * o.numOpt('size', 1.0),
        st = _stone(o['stone'] ?? '#4a3f69'),
        r = Rng(o.seed),
        yOff = -(18.0 * o.numOpt('size', 1.0)) * 0.3 {
    final power = 0.9 * math.pow(s, 0.8).toDouble();
    const earth = 1.6;
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [f[6], f[5], f[3], f[2]],
      onLand: (x, y) =>
          blazes.add(x, y - 0.25, r.range(0.9, 1.5), r.range(0.55, 0.85)),
    );
    blazes = Blazes(ps);

    flashes.add(_Flash(rad * 1.05, 0.06));
    rings.add(_ShockRing(rad * 0.45, rad * 2.7, 0.34, 3.0, f[5]));
    rings.add(_ShockRing(rad * 0.3, rad * 1.6, 0.22, 1.8, f[3]));
    lights.add(0, yOff, rad * 3.4, _warm, 0.6 * power, 0.7);
    lights.add(0, yOff, rad * 1.6, kWhite, 0.6, 0.08);

    for (var i = 0; i < 5; i++) {
      ps.spawn(
          P.fire,
          r.range(-2.5, 2.5),
          yOff + r.range(-2.5, 2.5),
          r.range(-20, 20),
          r.range(-40, -10),
          r.range(0.18, 0.3),
          0,
          r.range(rad * 0.4, rad * 0.55));
    }
    for (var i = 0; i < (28 * power).round(); i++) {
      final a = r.range(0, tau);
      final d = r.range(0, rad * 0.55);
      final sp = r.range(40, 210) * power;
      ps.spawn(
          P.fire,
          math.cos(a) * d,
          yOff + math.sin(a) * d,
          math.cos(a) * sp,
          math.sin(a) * sp * 0.8 - 40,
          r.range(0.55, 1.15),
          0,
          r.range(rad * 0.22, rad * 0.46),
          0,
          r.chance(0.45) ? (PF.smokes | PF.big) : 0);
    }
    for (var i = 0; i < 5; i++) {
      final a = r.range(0, tau);
      final d = r.range(rad * 0.1, rad * 0.5);
      ps.spawn(
          P.smoke,
          math.cos(a) * d,
          yOff + math.sin(a) * d,
          math.cos(a) * 30,
          math.sin(a) * 20 - 30,
          r.range(0.9, 1.5),
          rgb(34, 29, 38),
          r.range(rad * 0.15, rad * 0.26),
          r.range(0.06, 0.2),
          PF.big);
    }
    for (var i = 0; i < 5; i++) {
      ps.spawn(
          P.fire,
          r.range(-rad * 0.25, rad * 0.25),
          yOff,
          r.range(-12, 12),
          r.range(-180, -100),
          r.range(0.8, 1.3),
          0,
          r.range(rad * 0.24, rad * 0.36),
          r.range(0, 0.1),
          r.chance(0.6) ? (PF.smokes | PF.big) : 0);
    }
    for (var i = 0; i < (10 * power).round(); i++) {
      final a = r.range(0, tau);
      final d = r.range(0, rad * 0.7);
      final sp = r.range(15, 100);
      ps.spawn(
          P.smoke,
          math.cos(a) * d,
          yOff + math.sin(a) * d,
          math.cos(a) * sp,
          math.sin(a) * sp * 0.6 - 35,
          r.range(1.8, 2.8),
          0,
          r.range(rad * 0.26, rad * 0.44),
          r.range(0.12, 0.45),
          PF.big);
    }
    for (var i = 0; i < (80 * power).round(); i++) {
      final a = r.range(0, tau);
      final sp = r.range(140, 380) * power;
      ps.spawn(P.spark, 0, yOff, math.cos(a) * sp, math.sin(a) * sp - 70,
          r.range(0.18, 0.6));
    }
    for (var i = 0; i < (40 * power).round(); i++) {
      final a = r.range(0, tau);
      final sp = r.range(30, 150);
      ps.spawn(
          P.ember,
          math.cos(a) * rad * 0.4,
          yOff + math.sin(a) * rad * 0.4,
          math.cos(a) * sp,
          math.sin(a) * sp - 75,
          r.range(1.2, 2.6),
          f[3]);
    }
    for (var i = 0;
        i < (r.range(9, 14) * math.max(0.0, power - 0.55)).round();
        i++) {
      final a = -math.pi / 2 + r.range(-1.35, 1.35);
      final sp = r.range(170, 330);
      ps.spawn(P.brand, 0, yOff, math.cos(a) * sp, math.sin(a) * sp,
          r.range(0.7, 1.3));
    }
    for (var i = 0; i < (rad * 0.5).round(); i++) {
      final sg = r.sign();
      ps.spawn(
          P.smoke,
          sg * r.range(0, rad * 0.6),
          -r.range(1, 5 + rad * 0.04),
          sg * r.range(3, 9.5) * rad,
          -r.range(2, 15),
          r.range(1.1, 2.0),
          st.dust,
          r.range(4, 7) + rad / 6,
          r.range(0, 0.06),
          PF.big);
    }
    final rockLimit = 26 * math.min(1.5, s);
    for (var i = 0; i < rockLimit; i++) {
      rocks.add(_RockBit(
        x: r.range(-0.4, 0.4) * rad,
        y: -3,
        vx: r.range(-9, 9) * rad * 0.25,
        vy: -r.range(7, 16) * rad * 0.9,
        life: r.range(1.8, 2.6),
        a: r.range(0, tau),
        va: r.range(-16, 16),
        s: r.intRange(1, 3).toDouble(),
      ));
    }
    for (var i = 0; i < (earth * rad * 4).round(); i++) {
      final u = r.range(-1, 1);
      final a = -math.pi / 2 + u * 0.5;
      final sp = r.range(5, 15) * rad * (1.0 - 0.45 * u.abs());
      ps.spawn(
        P.grit,
        u * 0.25 * rad,
        -1,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(1.2, 2.2),
        r.pick([st.light, st.body, st.body, st.shade]),
        r.chance(0.45) ? 2.0 : 1.0,
      );
    }
    for (var i = 0; i < (earth * 12).round(); i++) {
      ps.spawn(
          P.smoke,
          r.range(-0.3, 0.3) * rad,
          -r.range(2, rad * 0.6),
          r.range(-15, 15),
          -r.range(60, 190) * earth * 0.6,
          r.range(1.6, 2.6),
          st.dust,
          r.range(5, 9) * math.sqrt(s) + rad / 7,
          r.range(0, 0.15),
          PF.big);
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    for (var i = flashes.length - 1; i >= 0; i--) {
      if ((flashes[i].life -= dt) <= 0.0) flashes.removeAt(i);
    }
    for (var i = rings.length - 1; i >= 0; i--) {
      if ((rings[i].life -= dt) <= 0.0) rings.removeAt(i);
    }
    rocks.update(dt);
    for (final b in rocks.list) {
      final rb = b as _RockBit;
      if (rb.rest && !rb.dusted) {
        rb.dusted = true;
        for (var i = 0; i < 3; i++) {
          ps.spawn(
            P.dust,
            rb.x + r.range(-1.5, 1.5),
            -0.5,
            r.sign() * r.range(10, 55) * 0.6,
            -r.range(2, 22),
            r.range(0.3, 0.65),
            st.dust,
            r.range(1.3, 2.8),
          );
        }
      }
    }
    blazes.update(dt);
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    _scorch(p, f, t, 22.0 * s, 1.2 + rad / 14.0,
        1.0 - smooth(meta.duration - 1.2, meta.duration - 0.2, t));
    ps.draw(p, 'back');
    blazes.drawBack(p);
    final k = t / 0.5;
    if (k < 1.0) {
      band(
        p,
        0,
        0.5,
        80.0 * s * Ease.outCubic(k),
        0.16,
        math.max(1.0, (2.0 + rad / 9.0) * (1.0 - k)),
        1.15 - k,
        [st.body, st.light, f[3], f[6]],
        keep: (g) => math.sin(g) < 0.0,
      );
    }
  }

  @override
  void draw(Painter p) {
    final k = t / 0.5;
    if (k < 1.0) {
      band(
        p,
        0,
        0.5,
        80.0 * s * Ease.outCubic(k),
        0.16,
        math.max(1.0, (2.0 + rad / 9.0) * (1.0 - k)),
        1.15 - k,
        [st.body, st.light, f[3], f[6]],
        keep: (g) => math.sin(g) >= 0.0,
      );
    }
    for (final b in rocks.list) {
      _drawRock(p, b as _RockBit, st);
    }
    ps.draw(p, 'front');
    for (final fl in flashes) {
      final k2 = fl.life / fl.max;
      final r = fl.r * (0.8 + 0.2 * k2);
      p.circle(0, yOff, r + 1.2, f[2]);
      p.circle(0, yOff, r, k2 > 0.45 ? f[6] : f[5]);
      p.circle(0, yOff, r * 0.6, k2 > 0.45 ? kWhite : f[6]);
    }
    for (final rg in rings) {
      final k2 = rg.life / rg.max;
      final e = 1.0 - math.pow(k2, 3).toDouble();
      p.ring(0, yOff, rg.r0 + (rg.r1 - rg.r0) * e,
          math.max(1.0, rg.thick * k2 + 0.4), rg.c, math.min(1.0, k2 * 1.6));
    }
    lights.draw(p);
  }
}

const EffectMeta _smallExplosionMeta = EffectMeta(
  id: 'explosions/small-explosion',
  name: 'Explosion',
  desc:
      'A ground blast: a white flash and shock rings, fire that cools into a rolling smoke column, sparks, burning brands that land and keep burning, tumbling rocks and a glowing scorch.',
  category: 'explosions',
  tags: ['explosion', 'fire', 'smoke', 'debris', 'impact', 'one-shot'],
  size: (300, 240),
  origin: (150, 196),
  duration: 5.4,
  loop: false,
  fps: 30,
  bg: BackdropKind.ground,
  defaultOptions: {
    'palette': [
      '#4a1712', '#c9281f', '#f2561d', '#ff8a2a',
      '#ffc23d', '#ffe26b', '#fff3a6', '#ffffff',
    ],
    'stone': '#4a3f69',
    'size': 1,
    'seed': 7,
  },
);

final SimulatedEffect smallExplosionEffect = SimulatedEffect(
  meta: _smallExplosionMeta,
  onCreate: (o) => _SmallExplosionSim(_smallExplosionMeta, o),
);
