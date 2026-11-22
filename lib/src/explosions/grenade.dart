// The blast (fire puffs that cool into smoke, sparks, grit, scorch, rings, lights) is adapted from Sprite Fusion's
// open-source explosion (https://www.spritefusion.com/pixel-art-vfx/explosion), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'explosions_lib.dart';

const double _blow = 1.62;
const double _rb = 6.2;

class _GrenadeBody {
  double x = -140.0;
  double y = -70.0;
  double vx = 168.0;
  double vy = -150.0;
  double a = 0.0;
  double va = -9.0;
  bool rest = false;
}

class _GrenadeSim extends BaseEffectSim {
  final EffectMeta meta;
  final List<int> f, fr, hr, g;
  final Rng r;
  final double x0, x1, y0, y1;
  late final Particles ps;
  final Lights lights = Lights();
  final Bits bits = Bits(ground: (_) => 0.0);
  final int dust = hex('#7d7280');
  final List<int> metal = [hex('#3a3c46'), hex('#6a6e7c'), hex('#a8acb8')];
  final _GrenadeBody body = _GrenadeBody();
  double t = 0.0;
  bool blown = false;
  double bx = 0.0;

  _GrenadeSim(this.meta, Map<String, Object?> o)
      : f = fit(o.palette, 8),
        fr = fireRamp(fit(o.palette, 8)),
        hr = heatRamp(fireRamp(fit(o.palette, 8))),
        g = fit(
          (o['body'] as List<Object?>?)?.cast<Object>() ??
              const ['#141a10', '#2c3a1e', '#4a5c30', '#6e8446', '#9ab06a'],
          5,
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
    );
  }

  void _blast() {
    blown = true;
    bx = body.x;
    const y = -5.0;
    lights.add(bx, y - 10.0, 70, mix(f[3], f[6], 0.45), 0.85, 0.5);
    lights.add(bx, y, 30, kWhite, 0.7, 0.07);
    for (var i = 0; i < 38; i++) {
      final a = r.range(-math.pi + 0.04, -0.04);
      final sp = r.range(380, 640);
      ps.spawn(
        P.mote,
        bx,
        y,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(0.12, 0.26),
        r.pick([f[7], f[6], f[5]]),
        r.range(0.6, 0.9),
      );
    }
    for (var i = 0; i < 60; i++) {
      final a = r.range(0, tau);
      final sp = r.range(140, 360);
      ps.spawn(
        P.spark,
        bx,
        y,
        math.cos(a) * sp,
        math.sin(a) * sp - 60.0,
        r.range(0.2, 0.55),
      );
    }
    for (var i = 0; i < 4; i++) {
      ps.spawn(
        P.fire,
        bx + r.range(-2, 2),
        y + r.range(-2, 2),
        r.range(-15, 15),
        r.range(-30, -8),
        r.range(0.16, 0.26),
        0,
        r.range(6, 8),
      );
    }
    for (var i = 0; i < 16; i++) {
      final a = r.range(-math.pi - 0.2, 0.2);
      final d = r.range(0, 6);
      final sp = r.range(40, 150);
      ps.spawn(
        P.fire,
        bx + math.cos(a) * d,
        y + math.sin(a) * d,
        math.cos(a) * sp,
        math.sin(a) * sp * 0.8 - 30.0,
        r.range(0.45, 0.9),
        0,
        r.range(3.5, 7),
        0,
        r.chance(0.5) ? PF.smokes : 0,
      );
    }
    for (var i = 0; i < 9; i++) {
      final a = r.range(-math.pi, 0);
      final d = r.range(2, 10);
      ps.spawn(
        P.smoke,
        bx + math.cos(a) * d,
        y + math.sin(a) * d,
        math.cos(a) * 25.0,
        -r.range(20, 60),
        r.range(1.4, 2.1),
        0,
        r.range(6, 10),
        r.range(0.05, 0.3),
        PF.big,
      );
    }
    for (var i = 0; i < 30; i++) {
      final a = r.range(0, tau);
      final sp = r.range(30, 120);
      ps.spawn(
        P.ember,
        bx,
        y,
        math.cos(a) * sp,
        math.sin(a) * sp - 50.0,
        r.range(0.8, 1.8),
        f[3],
      );
    }
    for (var i = 0; i < 12; i++) {
      final a = r.range(-math.pi + 0.2, -0.2);
      final sp = r.range(150, 330);
      bits.add(DebrisBit(
        kind: B.shard,
        x: bx,
        y: y,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp,
        g: 1.0,
        drag: 0.5,
        bounce: 0.3,
        life: r.range(1.4, 2.1),
        a: r.range(0, tau),
        va: r.range(-24, 24),
        s: r.range(2, 3.5),
        c: r.pick(metal),
      ));
    }
    for (var i = 0; i < 70; i++) {
      final u = r.range(-1, 1);
      final a = -math.pi / 2 + u * 0.8;
      final sp = r.range(100, 300) * (1.0 - 0.4 * u.abs());
      ps.spawn(
        P.grit,
        bx + u * 4.0,
        -1.0,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(1, 1.8),
        r.pick([hex('#5a4f6b'), hex('#3e3650'), hex('#776c88')]),
        r.chance(0.35) ? 2.0 : 1.0,
      );
    }
    for (var i = 0; i < 10; i++) {
      final s = r.sign();
      ps.spawn(
        P.smoke,
        bx + s * r.range(0, 6),
        -r.range(1, 4),
        s * r.range(60, 180),
        -r.range(2, 10),
        r.range(1, 1.7),
        dust,
        r.range(5, 8),
        r.range(0, 0.05),
        PF.big,
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (!blown) {
      if (!body.rest) {
        body.vy += 900.0 * dt;
        body.x += body.vx * dt;
        body.y += body.vy * dt;
        if (body.y >= -_rb && body.vy > 0.0) {
          body.y = -_rb;
          if (body.vy > 90.0) {
            for (var i = 0; i < 4; i++) {
              ps.spawn(
                P.dust,
                body.x + r.range(-2, 2),
                -0.5,
                r.sign() * r.range(10, 40),
                -r.range(4, 16),
                r.range(0.3, 0.6),
                dust,
                r.range(1.5, 2.6),
              );
            }
            for (var i = 0; i < 3; i++) {
              ps.spawn(P.spark, body.x, -1.0, r.range(-60, 60),
                  -r.range(40, 120), r.range(0.08, 0.16));
            }
            body.vy = -body.vy * 0.36;
            body.vx *= 0.8;
          } else {
            body.vy = 0.0;
          }
        }
        if (body.y >= -_rb - 0.01 && body.vy == 0.0) {
          body.vx -= body.vx * 2.4 * dt;
          body.va = -body.vx / _rb;
          if (body.vx.abs() < 3.0) {
            body.rest = true;
            body.vx = 0.0;
          }
        }
        body.a += body.va * dt;
      }
      final tip = _fuse(body.x, body.y, body.a);
      final hurry = smooth(_blow - 0.5, _blow, t);
      if (r.chance((24.0 + 50.0 * hurry) * dt)) {
        ps.spawn(P.spark, tip.$1, tip.$2, r.range(-50, 50), -r.range(30, 110),
            r.range(0.08, 0.2));
      }
      if (r.chance(9.0 * dt)) {
        ps.spawn(P.vapour, tip.$1, tip.$2 - 1.0, r.range(-4, 4), -r.range(10, 20),
            r.range(0.5, 0.9), hex('#8a8494'), r.range(1.2, 2));
      }
      if (t >= _blow) _blast();
    }
    bits.update(dt);
    for (var i = bits.list.length - 1; i >= 0; i--) {
      final b = bits.list[i];
      if (b.x < x0 + 3.0 || b.x > x1 - 3.0 || b.y < y0 + 3.0) {
        bits.list.removeAt(i);
      }
    }
    ps.update(dt);
    cullParticles(ps, x0, y0, x1, y1);
    fadeEdges(ps, x0, x1, 24.0, y1);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    if (blown) {
      final u = t - _blow;
      scorch(
        p,
        hr,
        u,
        22,
        1.6,
        1.0 - smooth(meta.duration - _blow - 0.8, meta.duration - _blow - 0.15, u),
        2,
      );
      final k = u / 0.4;
      if (k < 1.0) {
        band(
          p,
          bx,
          0.5,
          70.0 * Ease.outCubic(k),
          0.16,
          math.max(1.0, 3.5 * (1.0 - k)),
          1.15 - k,
          [hex('#4a3f69'), hex('#6e6390'), f[3], f[6]],
          keep: (g2) => math.sin(g2) < 0.0,
        );
      }
    }
    drawPs(p, ps, 'back', fr);
  }

  @override
  void draw(Painter p) {
    if (!blown) {
      final shake = smooth(_blow - 0.45, _blow, t);
      final jx = shake * math.sin(t * 90.0) * 0.8;
      _drawGrenade(p, g, body.x + jx, body.y, body.a);
      final tip = _fuse(body.x + jx, body.y, body.a);
      p.px(tip.$1, tip.$2, math.sin(t * 50.0) > 0.0 ? f[6] : f[5]);
      p.glow(tip.$1, tip.$2, 6.0 + 3.0 * shake, f[4],
          0.5 + 0.3 * math.sin(t * 37.0));
    } else {
      final u = t - _blow;
      final k = u / 0.4;
      if (k < 1.0) {
        band(
          p,
          bx,
          0.5,
          70.0 * Ease.outCubic(k),
          0.16,
          math.max(1.0, 3.5 * (1.0 - k)),
          1.15 - k,
          [hex('#4a3f69'), hex('#6e6390'), f[3], f[6]],
          keep: (g2) => math.sin(g2) >= 0.0,
        );
      }
    }
    bits.draw(p);
    drawPs(p, ps, 'front', fr);
    if (blown) {
      final u = t - _blow;
      if (u < 0.07) {
        final k2 = 1.0 - u / 0.07;
        final r = 11.0 * (0.8 + 0.2 * k2);
        p.circle(bx, -6, r + 1.2, f[2]);
        p.circle(bx, -6, r, k2 > 0.45 ? f[6] : f[5]);
        p.circle(bx, -6, r * 0.6, k2 > 0.45 ? kWhite : f[6]);
      }
      if (u < 0.2) {
        flare(p, bx, -6, 40.0 * math.pow(1.0 - u / 0.2, 1.4).toDouble(),
            1.0 - u / 0.2, f);
      }
      if (u < 0.3) {
        final k3 = u / 0.3;
        final e = 1.0 - math.pow(1.0 - k3, 3).toDouble();
        final r = 8.0 + 40.0 * e;
        p.ringShaded(
          bx,
          -6,
          r,
          math.max(1.0, 2.5 * (1.0 - k3) + 0.4),
          color: (_, _) => f[5],
          alpha: (_, an) =>
              math.sin(an) * r > 9.0 ? 0.0 : math.min(1.0, (1.0 - k3) * 1.6),
        );
      }
      lightPool(p, bx, 1, 70, 12, f[3], 0.55 * math.max(0.0, 1.0 - u / 0.6));
    }
    lights.draw(p);
  }
}

(double, double) _fuse(double x, double y, double a) {
  final ca = math.cos(a);
  final sa = math.sin(a);
  return (x + sa * 10.4, y - ca * 10.4);
}

void _drawGrenade(Painter p, List<int> g, double x, double y, double a) {
  final ca = math.cos(a);
  final sa = math.sin(a);
  final m = [hex('#2a2c36'), hex('#5e6270'), hex('#9a9eac'), hex('#d0d4de')];
  p.shade(x - 13, y - 13, x + 13, y + 13, (px, py, out) {
    final dx = px - x;
    final dy = py - y;
    final u = dx * ca + dy * sa;
    final v = -dx * sa + dy * ca;
    if (v < -5.0 && v > -10.2 && u.abs() < 2.4) {
      return v < -9.4 || u.abs() > 1.7 ? m[0] : (u < -0.6 ? m[3] : m[2]);
    }
    final ringD = hypot(u + 3.4, v + 8.0);
    if (ringD < 1.9 && ringD > 0.9) return m[2];
    if (u > 2.2 && u < 3.6 && v > -8.6 && v < 2.0) return u > 3.0 ? m[0] : m[1];
    final e = (u / 5.1) * (u / 5.1) + ((v - 0.6) / 6.4) * ((v - 0.6) / 6.4);
    if (e > 1.2) return null;
    if (e > 1.0) return kExplosionOutline;
    final lit = -(dx * 0.6 + dy * 0.8) / 6.0;
    final gv = (((v + 30.0) % 3.1) - 1.55).abs() < 0.45;
    final gu = (((u + 30.0) % 3.4) - 1.7).abs() < 0.45;
    final idxRaw = 2.0 +
        lit * 1.7 -
        ((gv || gu) ? 1.0 : 0.0) +
        (e < 0.3 && lit > 0.3 ? 1.0 : 0.0);
    final i = clampInt((idxRaw + 0.5).floor(), 0, 4);
    return g[i];
  });
}

const EffectMeta _grenadeMeta = EffectMeta(
  id: 'explosions/grenade',
  name: 'Grenade',
  desc:
      'A grenade is lobbed in, bounces, rolls to a stop with its fuse fizzing, shudders, then blows: a white flash, shrapnel streaks, sparks, a small fireball and a scorch.',
  category: 'explosions',
  tags: [
    'explosion',
    'grenade',
    'shrapnel',
    'fire',
    'smoke',
    'ground',
    'one-shot',
  ],
  size: (300, 200),
  origin: (160, 170),
  duration: 4.2,
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
    'body': ['#141a10', '#2c3a1e', '#4a5c30', '#6e8446', '#9ab06a'],
    'seed': 6,
  },
);

final SimulatedEffect grenadeEffect = SimulatedEffect(
  meta: _grenadeMeta,
  onCreate: (o) => _GrenadeSim(_grenadeMeta, o),
);
