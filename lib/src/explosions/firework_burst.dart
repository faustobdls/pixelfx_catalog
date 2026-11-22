// The flare, the twinkling crosses and the glitter are adapted from Sprite Fusion's open-source sparkle
// (https://www.spritefusion.com/pixel-art-vfx/sparkle), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const double _rise = 0.42;
const double _y0 = 72.0;
const double _drag = 2.6;
const double _g = 88.0;
const double _trail = 0.34;
const double _turn = 0.22;

class _Star {
  double x, y, vx, vy, age, acc;
  final double life, seed;
  final List<int> ramp, first;
  final bool big;
  final List<double> pts = [];

  _Star({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.ramp,
    required this.first,
    required this.big,
    required this.acc,
    required this.seed,
  }) : age = 0.0;
}

class _Pop {
  final double x, y, t0, life;
  final int c;
  const _Pop(this.x, this.y, this.t0, this.life, this.c);
}

class _FireworkBurstSim extends BaseEffectSim {
  final EffectMeta meta;
  final List<int> c, k;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  final List<_Star> stars = [];
  final List<_Pop> pops = [];
  double t = 0.0;
  bool burst = false;

  _FireworkBurstSim(this.meta, Map<String, Object?> o)
      : c = fit(o.palette, 7),
        k = fit(
          (o['core'] as List<Object?>?)?.cast<Object>() ??
              const [
                '#4a2c08',
                '#86520c',
                '#c48412',
                '#f0b424',
                '#ffe066',
                '#fff6c4',
                '#ffffff',
              ],
          7,
        ),
        r = Rng(o.seed) {
    ps = Particles(rng: r, sparks: [k[6], k[5], k[4], k[3]]);
  }

  void _shell(int n, double speed, List<int> ramp, (double, double) life,
      List<int> first) {
    for (var i = 0; i < n; i++) {
      final z = r.range(-1, 1);
      final a = r.range(0, tau);
      final s = math.sqrt(1.0 - z * z);
      final v = speed * r.range(0.93, 1.05);
      stars.add(_Star(
        x: 0.0,
        y: 0.0,
        vx: math.cos(a) * s * v,
        vy: math.sin(a) * s * v,
        life: r.range(life.$1, life.$2),
        ramp: ramp,
        first: first,
        big: r.chance(0.2),
        acc: r.next(),
        seed: r.range(0, 100),
      ));
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (t < _rise) {
      final y = _y0 * (1.0 - Ease.outCubic(t / _rise));
      if (r.chance(50.0 * dt)) {
        ps.spawn(P.spark, r.range(-0.5, 0.5), y + 2.0, r.range(-25, 25),
            r.range(20, 70), r.range(0.15, 0.35));
      }
      if (r.chance(14.0 * dt)) {
        ps.spawn(P.vapour, r.range(-1, 1), y + 3.0, r.range(-3, 3),
            r.range(5, 15), r.range(0.5, 0.8), hex('#4a4458'), r.range(1.5, 2.5));
      }
    }
    if (!burst && t >= _rise) {
      burst = true;
      lights.add(0, 0, 110, c[4], 0.6, 1.5);
      lights.add(0, 0, 30, kWhite, 0.5, 0.07);
      _shell(66, 236, c, (1.35, 1.9), k);
      _shell(26, 120, k, (1.0, 1.4), k);
      for (var i = 0; i < 7; i++) {
        final a = r.range(0, tau);
        final d = r.range(0, 8);
        ps.spawn(
          P.vapour,
          math.cos(a) * d,
          math.sin(a) * d,
          math.cos(a) * r.range(10, 30),
          math.sin(a) * r.range(10, 30),
          r.range(2.2, 3),
          hex('#4a4458'),
          r.range(6, 11),
        );
      }
      for (var i = 0; i < 24; i++) {
        final a = r.range(0, tau);
        final sp = r.range(40, 140);
        ps.spawn(P.spark, 0, 0, math.cos(a) * sp, math.sin(a) * sp,
            r.range(0.15, 0.35));
      }
    }
    for (var i = stars.length - 1; i >= 0; i--) {
      final s = stars[i];
      s.age += dt;
      final kv = s.age / s.life;
      if (kv >= 1.0) {
        final count = 2 + (s.big ? 1 : 0);
        for (var j = 0; j < count; j++) {
          pops.add(_Pop(
            s.x + r.range(-3, 3),
            s.y + r.range(-3, 3),
            t + r.range(0, 0.18),
            r.range(0.06, 0.12),
            r.chance(0.6) ? kWhite : s.ramp[5],
          ));
        }
        stars.removeAt(i);
        continue;
      }
      s.vx -= s.vx * _drag * dt;
      s.vy -= s.vy * _drag * dt - _g * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.pts
        ..add(s.x)
        ..add(s.y)
        ..add(t);
      while (s.pts.length > 3 && t - s.pts[2] > _trail) {
        s.pts.removeRange(0, 3);
      }
      for (s.acc += dt * (kv < 0.25 ? 4.0 : 11.0); s.acc > 1.0; s.acc -= 1.0) {
        ps.spawn(
          P.star,
          s.x,
          s.y,
          s.vx * 0.15 + r.range(-6, 6),
          s.vy * 0.15 + r.range(0, 10),
          r.range(0.35, 0.8),
          r.chance(0.5) ? k[5] : kWhite,
          r.chance(0.15) ? r.range(1, 1.6) : 0.5,
        );
      }
    }
    for (var i = pops.length - 1; i >= 0; i--) {
      if (t > pops[i].t0 + pops[i].life) pops.removeAt(i);
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    if (t < _rise) {
      final u = t / _rise;
      final y = _y0 * (1.0 - Ease.outCubic(u));
      p.lineShaded(0, y, 0, y + 3.0 + 6.0 * (1.0 - u),
          color: (q) => q < 0.3 ? k[5] : k[3]);
      p.px(0, y, kWhite);
      p.glow(0, y, 7, k[4], 0.5);
    }
    for (final s in stars) {
      final kv = s.age / s.life;
      final pts = s.pts;
      final n = pts.length ~/ 3;
      for (var j = n - 1; j > 0; j--) {
        final u = (t - pts[j * 3 + 2]) / _trail;
        if (u >= 1.0) break;
        final ramp = (s.age - (t - pts[j * 3 + 2]) < _turn) ? s.first : s.ramp;
        final col = u < 0.3 ? ramp[5] : (u < 0.6 ? ramp[4] : ramp[3]);
        p.line(
          pts[j * 3],
          pts[j * 3 + 1],
          pts[j * 3 - 3],
          pts[j * 3 - 2],
          col,
          math.pow(1.0 - u, 0.8).toDouble() * (1.3 - kv * 0.6),
        );
      }
      if (kv > 0.72 && math.sin(t * 60.0 + s.seed) < -0.2) continue;
      final ramp = s.age < _turn ? s.first : s.ramp;
      final head = s.age < 0.04
          ? kWhite
          : (kv < 0.55 ? ramp[s.age < _turn ? 5 : 6] : ramp[5]);
      p.px(s.x, s.y, head);
      if (s.big && kv < 0.6 && s.age > 0.06) {
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          p.px(s.x + dx, s.y + dy, ramp[5]);
        }
      }
      p.glow(s.x, s.y, s.big ? 7 : 5, ramp[4],
          (s.big ? 0.7 : 0.5) * (1.0 - kv * 0.6) * math.min(1.0, s.age / 0.2));
    }
    for (final q in pops) {
      final u = (t - q.t0) / q.life;
      if (u < 0.0 || u > 1.0) continue;
      sparkle(p, q.x, q.y, 2.6 * math.sin(math.pi * u), q.c,
          mix(q.c, c[3], 0.5), 0.5);
    }
    final b = t - _rise;
    if (b >= 0.0 && b < 0.28) {
      final u = b / 0.28;
      final l = 32.0 * math.pow(1.0 - u, 1.3).toDouble();
      _flareRays(p, 0, 0, l, u * 0.6, c, k);
      if (b < 0.07) p.circle(0, 0, 2.6 - b * 20.0, kWhite);
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

void _flareRays(Painter p, double x, double y, double l, double ang,
    List<int> c, List<int> k) {
  if (l < 1.0) return;
  for (var i = 0; i < 8; i++) {
    final diag = i % 2 == 1;
    final an = ang + (i * tau) / 8.0;
    final len = diag ? l * 0.42 : l;
    final ca = math.cos(an);
    final sa = math.sin(an);
    for (var d = 0.0; d <= len; d += 0.5) {
      final u = d / len;
      p.dot(
        x + ca * d,
        y + sa * d,
        diag
            ? (u < 0.5 ? k[5] : k[4])
            : (u < 0.3 ? kWhite : (u < 0.65 ? c[5] : c[4])),
        u < 0.7 ? 1.0 : 1.0 - (u - 0.7) / 0.35,
      );
    }
  }
  p.glow(x, y, 4.0 + l * 1.2, c[4], 0.3);
  p.glow(x, y, 2.0 + l * 0.3, kWhite, 0.25);
}

const EffectMeta _fireworkBurstMeta = EffectMeta(
  id: 'explosions/firework-burst',
  name: 'Firework burst',
  desc:
      'A shell climbs, slows and bursts into a sphere of coloured trailing stars round a gold core; they droop, crackle into white pops and fade, leaving glitter.',
  category: 'explosions',
  tags: ['firework', 'celebration', 'sparkle', 'sky', 'burst', 'one-shot'],
  size: (240, 248),
  origin: (120, 100),
  duration: 3.6,
  loop: false,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': [
      '#3d0a33',
      '#701560',
      '#b0228f',
      '#f53cd1',
      '#ff86e6',
      '#ffd2f6',
      '#ffffff',
    ],
    'core': [
      '#4a2c08',
      '#86520c',
      '#c48412',
      '#f0b424',
      '#ffe066',
      '#fff6c4',
      '#ffffff',
    ],
    'seed': 9,
  },
);

final SimulatedEffect fireworkBurstEffect = SimulatedEffect(
  meta: _fireworkBurstMeta,
  onCreate: (o) => _FireworkBurstSim(_fireworkBurstMeta, o),
);
