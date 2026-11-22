// The blast (fire puffs that cool into smoke, sparks, embers, burning brands that land and keep burning, grit, scorch,
// rings) is adapted from Sprite Fusion's open-source explosion (https://www.spritefusion.com/pixel-art-vfx/explosion),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'explosions_lib.dart';

const double _blow = 0.8;
const double _bw = 8.0;
const double _bh = 22.0;

class _FuelPool {
  final double x, w;
  const _FuelPool(this.x, this.w);
}

class _LidState {
  double x = 0.0;
  double y = -_bh;
  double vx = 0.0;
  double vy = 0.0;
  double a = 0.0;
  double va = 0.0;
  bool on = false;
  bool rest = false;
}

class _BarrelExplosionSim extends BaseEffectSim {
  final EffectMeta meta;
  final List<int> f, fr, hr, c;
  final Rng r;
  final double x0, x1, y0, y1;
  late final Particles ps;
  late final Blazes blazes;
  final Lights lights = Lights();
  final Bits staves = Bits(ground: (_) => 0.0);
  final int oil = hex('#221a22');
  final int soot = hex('#1f1a24');
  final _LidState lid = _LidState();
  final List<_FuelPool> pools = [];
  double t = 0.0;
  bool blown = false;

  _BarrelExplosionSim(this.meta, Map<String, Object?> o)
      : f = fit(o.palette, 8),
        fr = fireRamp(fit(o.palette, 8)),
        hr = heatRamp(fireRamp(fit(o.palette, 8))),
        c = fit(
          (o['barrel'] as List<Object?>?)?.cast<Object>() ??
              const [
                '#1c0a0e',
                '#4a1218',
                '#7c1a1e',
                '#b02a26',
                '#d8483a',
                '#f08a70',
              ],
          6,
        ),
        r = Rng(o.seed),
        x0 = -meta.origin.$1 + 3.0,
        x1 = meta.size.$1 - meta.origin.$1 - 3.0,
        y0 = -meta.origin.$2 + 3.0,
        y1 = meta.size.$2 - meta.origin.$2 - 3.0 {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [f[6], f[5], f[3], f[2]],
      onLand: (x, y) =>
          blazes.add(x, y - 0.25, r.range(1.2, 2.2), r.range(0.6, 1.0)),
    );
    blazes = Blazes(ps);
  }

  void _doBlow() {
    blown = true;
    const y = -_bh * 0.5;
    lights.add(0, y - 20.0, 90, mix(f[3], f[6], 0.45), 0.85, 0.9);
    lights.add(0, y, 44, kWhite, 0.7, 0.09);

    for (var i = 0; i < 5; i++) {
      ps.spawn(
        P.fire,
        r.range(-3, 3),
        y + r.range(-3, 3),
        r.range(-20, 20),
        r.range(-40, -10),
        r.range(0.18, 0.28),
        0,
        r.range(9, 12),
      );
    }
    for (var i = 0; i < 30; i++) {
      final a = r.range(-math.pi - 0.15, 0.15);
      final d = r.range(0, 8);
      final sp = r.range(50, 190);
      ps.spawn(
        P.fire,
        math.cos(a) * d,
        y + math.sin(a) * d,
        math.cos(a) * sp,
        math.sin(a) * sp * 0.8 - 40.0,
        r.range(0.55, 1.05),
        0,
        r.range(5, 10),
        0,
        r.chance(0.5) ? (PF.smokes | PF.big) : 0,
      );
    }
    for (var i = 0; i < 12; i++) {
      ps.spawn(
        P.fire,
        r.range(-6, 6),
        y - r.range(0, 10),
        r.range(-14, 14),
        -r.range(170, 300),
        r.range(0.7, 1.15),
        0,
        r.range(6, 10),
        r.range(0, 0.12),
        r.chance(0.7) ? (PF.smokes | PF.big) : 0,
      );
    }
    for (var i = 0; i < 12; i++) {
      final a = r.range(-math.pi, 0);
      final d = r.range(4, 16);
      ps.spawn(
        P.smoke,
        math.cos(a) * d,
        y + math.sin(a) * d,
        math.cos(a) * 30.0,
        -r.range(30, 90),
        r.range(1.6, 2.6),
        soot,
        r.range(8, 13),
        r.range(0.1, 0.4),
        PF.big,
      );
    }
    for (var i = 0; i < 90; i++) {
      final a = r.range(0, tau);
      final sp = r.range(160, 400);
      ps.spawn(
        P.spark,
        0,
        y,
        math.cos(a) * sp,
        math.sin(a) * sp - 70.0,
        r.range(0.2, 0.6),
      );
    }
    for (var i = 0; i < 40; i++) {
      final a = r.range(0, tau);
      final sp = r.range(30, 140);
      ps.spawn(
        P.ember,
        math.cos(a) * 8.0,
        y + math.sin(a) * 8.0,
        math.cos(a) * sp,
        math.sin(a) * sp - 70.0,
        r.range(1.2, 2.6),
        f[3],
      );
    }
    for (var i = 0; i < 14; i++) {
      final a = -math.pi / 2 + r.range(-1.2, 1.2);
      final sp = r.range(120, 300);
      ps.spawn(
        P.brand,
        r.range(-4, 4),
        y,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(0.8, 1.4),
      );
    }
    for (var i = 0; i < 9; i++) {
      final side = (i % 2 != 0) ? 1.0 : -1.0;
      final a = -math.pi / 2 + side * r.range(0.25, 1.15);
      final sp = r.range(170, 330);
      staves.add(ExplosionBit(
        kind: B.chunk,
        x: side * r.range(2, 6),
        y: -r.range(4, _bh - 4.0),
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp,
        g: 1.0,
        drag: 0.5,
        bounce: 0.35,
        life: r.range(3, 3.8),
        a: r.range(0, tau),
        va: r.range(-16, 16),
        s: r.range(9, 13),
        heat: r.range(0.4, 0.9),
      ));
    }
    lid.on = true;
    lid.x = 0.0;
    lid.y = -_bh;
    lid.vx = r.range(-40, 40);
    lid.vy = -r.range(430, 480);
    lid.a = 0.0;
    lid.va = r.sign() * r.range(10, 14);

    for (var i = 0; i < 7; i++) {
      final x = r.range(-34, 34);
      pools.add(_FuelPool(x, r.range(5, 10)));
      blazes.add(x, -0.25, r.range(2.2, 3), r.range(0.8, 1.3));
    }
    for (var i = 0; i < 12; i++) {
      final s = r.sign();
      ps.spawn(
        P.smoke,
        s * r.range(0, 10),
        -r.range(1, 4),
        s * r.range(80, 220),
        -r.range(2, 12),
        r.range(1.1, 1.8),
        hex('#7d7280'),
        r.range(6, 9),
        r.range(0, 0.05),
        PF.big,
      );
    }
    for (var i = 0; i < 60; i++) {
      final u = r.range(-1, 1);
      final a = -math.pi / 2 + u * 0.7;
      final sp = r.range(120, 330) * (1.0 - 0.4 * u.abs());
      ps.spawn(
        P.grit,
        u * 6.0,
        -1.0,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(1.1, 1.9),
        r.pick([hex('#5a4f6b'), hex('#3e3650'), hex('#776c88')]),
        r.chance(0.4) ? 2.0 : 1.0,
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (!blown) {
      final k = t / _blow;
      if (r.chance((6.0 + 30.0 * k * k) * dt)) {
        final s = r.sign();
        ps.spawn(
          P.fire,
          s * r.range(4, 7),
          -_bh + 1.0,
          s * r.range(20, 60),
          -r.range(20, 60),
          r.range(0.15, 0.3),
          0,
          r.range(1.5, 3),
        );
        ps.spawn(
          P.spark,
          s * 6.0,
          -_bh + 1.0,
          s * r.range(40, 140),
          -r.range(20, 120),
          r.range(0.1, 0.25),
        );
      }
      if (r.chance(10.0 * dt)) {
        ps.spawn(
          P.smoke,
          r.range(-5, 5),
          -_bh,
          r.range(-8, 8),
          -r.range(15, 35),
          r.range(0.8, 1.3),
          0,
          r.range(2.5, 4),
        );
      }
      if (t >= _blow) _doBlow();
    }
    if (lid.on && !lid.rest) {
      lid.vy += 950.0 * dt;
      lid.vx -= lid.vx * 0.4 * dt;
      lid.x += lid.vx * dt;
      lid.y += lid.vy * dt;
      lid.a += lid.va * dt;
      if (lid.y >= -1.0 && lid.vy > 0.0) {
        for (var i = 0; i < 6; i++) {
          ps.spawn(P.spark, lid.x, -1.0, r.range(-90, 90), -r.range(40, 140),
              r.range(0.1, 0.25));
        }
        for (var i = 0; i < 5; i++) {
          ps.spawn(
            P.dust,
            lid.x + r.range(-4, 4),
            -0.5,
            r.sign() * r.range(15, 60),
            -r.range(4, 18),
            r.range(0.35, 0.7),
            hex('#7d7280'),
            r.range(1.8, 3),
          );
        }
        lid.y = -1.0;
        if (lid.vy > 160.0) {
          lid.vy *= -0.3;
          lid.vx *= 0.5;
          lid.va *= 0.5;
        } else {
          lid.rest = true;
          lid.a = math.pi / 2;
        }
      }
    }
    staves.update(dt);
    for (var i = staves.list.length - 1; i >= 0; i--) {
      final b = staves.list[i] as ExplosionBit;
      if (b.x < x0 + 8.0 || b.x > x1 - 8.0) {
        staves.list.removeAt(i);
      } else if (b.heat > 0.0) {
        b.heat = math.max(0.0, b.heat - dt * 0.35);
      }
    }
    blazes.update(dt);
    ps.update(dt);
    cullParticles(ps, x0, y0, x1, y1);
    fadeEdges(ps, x0, x1, 24.0, y1);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    if (blown) {
      final u = t - _blow;
      final out =
          1.0 - smooth(meta.duration - _blow - 1.0, meta.duration - _blow - 0.2, u);
      scorch(p, hr, u, 30, 2.2, out, 3);
      final left = 1.0 - smooth(1.6, 3.4, u);
      if (left > 0.0) {
        for (final q in pools) {
          final start = (-(q.w * left)).floor();
          final end = (q.w * left).ceil();
          for (var x = start; x <= end; x++) {
            final e = x.abs() / (q.w * left + 0.01);
            p.dot(
              q.x + x,
              1,
              rand((q.x + x).floor(), (t * 12.0).floor()) < 0.25 ? f[4] : oil,
              out * (e < 0.8 ? 1.0 : 0.6),
            );
            if (e < 0.6) p.dot(q.x + x, 2, oil, out * 0.8);
          }
        }
      }
      final k = u / 0.45;
      if (k < 1.0) {
        band(
          p,
          0,
          0.5,
          100.0 * Ease.outCubic(k),
          0.16,
          math.max(1.0, 4.5 * (1.0 - k)),
          1.15 - k,
          [hex('#4a3f69'), hex('#6e6390'), f[3], f[6]],
          keep: (g) => math.sin(g) < 0.0,
        );
      }
    }
    drawPs(p, ps, 'back', fr);
    blazes.drawBack(p);
  }

  @override
  void draw(Painter p) {
    if (!blown) {
      final k = t / _blow;
      final jx = math.sin(t * 70.0) * k * k * 1.4;
      final jy = math.sin(t * 53.0).abs() * k * k * 0.8;
      _drawBarrel(p, c, jx, -jy, k);
      p.glow(0, -_bh, 10.0 + 8.0 * k, f[4],
          0.25 + 0.35 * k * k * (0.6 + 0.4 * math.sin(t * 40.0)));
    } else {
      final u = t - _blow;
      final k = u / 0.45;
      if (k < 1.0) {
        band(
          p,
          0,
          0.5,
          100.0 * Ease.outCubic(k),
          0.16,
          math.max(1.0, 4.5 * (1.0 - k)),
          1.15 - k,
          [hex('#4a3f69'), hex('#6e6390'), f[3], f[6]],
          keep: (g) => math.sin(g) >= 0.0,
        );
      }
    }
    drawPs(p, ps, 'front', fr);
    for (final b in staves.list) {
      _drawStave(p, b as ExplosionBit, c, fr);
    }
    if (lid.on) {
      _drawLid(p, c, lid, math.min(1.0, (meta.duration - t) / 0.4));
    }
    if (blown) {
      final u = t - _blow;
      if (u < 0.08) {
        final k2 = 1.0 - u / 0.08;
        final r = 18.0 * (0.85 + 0.15 * k2);
        const y = -_bh * 0.5;
        p.circle(0, y, r + 1.4, f[2]);
        p.circle(0, y, r, k2 > 0.45 ? f[6] : f[5]);
        p.circle(0, y, r * 0.6, k2 > 0.45 ? kWhite : f[6]);
      }
      if (u < 0.22) {
        flare(p, 0, -_bh * 0.5,
            54.0 * math.pow(1.0 - u / 0.22, 1.4).toDouble(), 1.0 - u / 0.22, f);
      }
      lightPool(
        p,
        0,
        1,
        90,
        14,
        f[3],
        0.5 * math.max(0.0, 1.0 - u / 0.7) + 0.22 * (1.0 - smooth(1.6, 3.4, u)),
      );
    }
    lights.draw(p);
  }
}

void _drawBarrel(Painter p, List<int> c, double x, double y, double k) {
  final bulge = (k * k * 2.0 + 0.5).floor();
  p.shade(x - _bw - 1, y - _bh - 3, x + _bw + 1, y + 0.5, (px, py, out) {
    final dx = (px - x) / _bw;
    final v = (y - py) / _bh;
    if (dx.abs() > 1.1 || v < 0.0 || v > 1.05) return null;
    final edge = dx.abs() > 0.92 || v > 0.97 || v < 0.04;
    if (edge) return kExplosionOutline;
    final rib = (v - 0.33).abs() < 0.035 || (v - 0.67).abs() < 0.035;
    final ribLit = (v - 0.31).abs() < 0.03 || (v - 0.65).abs() < 0.03;
    final bandHit = v > 0.44 && v < 0.56;
    final lit = -dx;
    var i = lit > 0.55
        ? 5
        : (lit > 0.15 ? 4 : (lit > -0.35 ? 3 : (lit > -0.75 ? 2 : 1)));
    if (bandHit) {
      return lit > 0.3
          ? hex('#e8d8b0')
          : (lit > -0.4 ? hex('#b8a888') : hex('#6e6050'));
    }
    if (rib) {
      i = math.max(1, i - 2);
    } else if (ribLit) {
      i = math.min(5, i + 1);
    }
    return c[i];
  });
  p.ellipseShaded(
    x,
    y - _bh - bulge * 0.5,
    _bw - 0.5,
    2.2 + bulge * 0.4,
    color: (d, a) => d > 0.7 ? (math.sin(a) < 0.0 ? c[4] : c[2]) : c[1],
  );
}

void _drawStave(
    Painter p, ExplosionBit b, List<int> c, List<int> fr) {
  final fade = math.min(1.0, b.life / 0.5);
  final ca = math.cos(b.a);
  final sa = math.sin(b.a);
  final l = b.size;
  final face = math.cos(b.a * 1.7) > 0.0;
  for (var d = -l / 2.0; d <= l / 2.0; d += 0.5) {
    final t = 2.0 * d / l;
    final bow = (1.0 - t * t) * 1.2;
    final x = b.x + ca * d - sa * bow;
    final y = b.y + sa * d + ca * bow;
    final hot = b.heat > 0.3 && d.abs() > l / 2.0 - 1.0;
    p.dot(x + sa, y - ca, kExplosionOutline, fade);
    p.dot(
      x,
      y,
      hot ? fr[b.heat > 0.6 ? 3 : 5] : (face ? c[4] : c[1]),
      fade,
    );
    p.dot(x - sa, y + ca, face ? c[2] : kExplosionOutline, fade);
  }
  if (b.heat > 0.3) p.glow(b.x, b.y, 6, fr[4], 0.25 * b.heat * fade);
}

void _drawLid(Painter p, List<int> c, _LidState lid, double a) {
  final w = math.max(0.8, math.cos(lid.a).abs() * 7.5);
  final h = math.max(1.2, math.sin(lid.a).abs() * 7.5);
  final rx = lid.rest ? 7.5 : w;
  final ry = lid.rest ? 1.6 : h;
  final cy = lid.y - (lid.rest ? 0.5 : 0.0);
  p.ellipse(lid.x, cy, rx + 0.8, ry + 0.8, kExplosionOutline, a);
  p.ellipseShaded(
    lid.x,
    cy,
    rx,
    ry,
    color: (d, an) => d > 0.65 ? (math.sin(an) < 0.0 ? c[4] : c[2]) : c[3],
    alpha: (_, _) => a,
  );
}

const EffectMeta _barrelExplosionMeta = EffectMeta(
  id: 'explosions/barrel-explosion',
  name: 'Barrel explosion',
  desc:
      'An explosive barrel shudders, its lid bulging and spitting flame, then blows: a fireball column, staves and the lid flying, burning fuel splashed over the floor.',
  category: 'explosions',
  tags: [
    'explosion',
    'barrel',
    'fire',
    'smoke',
    'debris',
    'ground',
    'one-shot',
  ],
  size: (300, 240),
  origin: (150, 204),
  duration: 5.2,
  loop: false,
  fps: 30,
  bg: BackdropKind.ground,
  defaultOptions: {
    'palette': [
      '#4a1712',
      '#c9281f',
      '#f2561d',
      '#ff8a2a',
      '#ffc23d',
      '#ffe26b',
      '#fff3a6',
      '#ffffff',
    ],
    'barrel': [
      '#1c0a0e',
      '#4a1218',
      '#7c1a1e',
      '#b02a26',
      '#d8483a',
      '#f08a70',
    ],
    'seed': 8,
  },
);

final SimulatedEffect barrelExplosionEffect = SimulatedEffect(
  meta: _barrelExplosionMeta,
  onCreate: (o) => _BarrelExplosionSim(_barrelExplosionMeta, o),
);
