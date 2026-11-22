import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const double _cy = -17;

final PixelEffect poofEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'spawn/poof',
    name: 'Poof',
    desc:
        'A cartoon death poof: a white pop, a ring of soft round smoke balls bursting out between speed lines, little stars spinning off, and the cloud lifting and thinning away.',
    category: 'spawn',
    tags: [
      'spawn',
      'death',
      'despawn',
      'smoke',
      'poof',
      'cartoon',
      'one-shot',
    ],
    size: (112, 92),
    origin: (56, 80),
    duration: 1.6,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#2a2440',
        '#5e5878',
        '#9a94b4',
        '#cdc8e0',
        '#f2f0fa',
        '#ffffff',
      ],
      'stars': ['#ffd84a', '#fff3a6', '#ffffff'],
      'seed': 21,
    },
  ),
  onCreate: (o) => _PoofSim(o),
);

class _Ball {
  _Ball({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.r0,
    required this.r1,
    required this.life,
    required this.delay,
  }) : max = life;

  double x;
  double y;
  double vx;
  double vy;
  final double r0;
  final double r1;
  double life;
  final double max;
  double delay;
}

class _SpeedLine {
  const _SpeedLine({required this.a, required this.r1, required this.d});

  final double a;
  final double r1;
  final double d;
}

class _PoofSim extends BaseEffectSim {
  _PoofSim(Map<String, Object?> o) {
    cRamp = fit(o.palette, 6);
    sRamp = fit(o.rampOpt('stars'), 3);
    rng = Rng(o.seed);
    ps = Particles(
      rng: rng,
      ground: (_) => 0,
      sparks: [kWhite, sRamp[1], sRamp[0], cRamp[2]],
    );
    lights = Lights();

    const ring = 9;
    for (var i = 0; i < ring; i++) {
      final a = (i / ring) * tau + rng.range(-0.2, 0.2);
      final sp = rng.range(95, 140);
      final r = rng.range(5, 7);
      balls.add(
        _Ball(
          x: math.cos(a) * 3,
          y: _cy + math.sin(a) * 3,
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp * 0.8 - 12,
          r0: r * 0.5,
          r1: r,
          life: rng.range(0.7, 1.05),
          delay: rng.range(0, 0.03),
        ),
      );
    }
    for (var i = 0; i < 5; i++) {
      final a = rng.range(0, tau);
      final sp = rng.range(20, 60);
      balls.add(
        _Ball(
          x: math.cos(a) * 2,
          y: _cy + math.sin(a) * 2,
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp - 16,
          r0: 4,
          r1: rng.range(6.5, 8.5),
          life: rng.range(0.85, 1.2),
          delay: rng.range(0.02, 0.06),
        ),
      );
    }
    for (var i = 0; i < 7; i++) {
      final a = rng.range(0, tau);
      final sp = rng.range(170, 240);
      final r = rng.range(2.2, 3.6);
      balls.add(
        _Ball(
          x: math.cos(a) * 4,
          y: _cy + math.sin(a) * 4,
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp * 0.75 - 10,
          r0: r * 0.6,
          r1: r,
          life: rng.range(0.32, 0.5),
          delay: rng.range(0.01, 0.04),
        ),
      );
    }

    for (var i = 0; i < 12; i++) {
      final a = (i / 12) * tau + rng.range(-0.12, 0.12) + 0.13;
      final sa = math.sin(a);
      lines.add(
        _SpeedLine(
          a: a,
          r1: math.min(rng.range(24, 34), sa > 0.1 ? (-2 - _cy) / sa : 99.0),
          d: rng.range(0, 0.04),
        ),
      );
    }

    for (var i = 0; i < 7; i++) {
      final a = rng.range(-math.pi, 0.3);
      final sp = rng.range(70, 125);
      ps.spawn(
        P.star,
        math.cos(a) * 6,
        _cy + math.sin(a) * 6,
        math.cos(a) * sp,
        math.sin(a) * sp - 30,
        rng.range(0.55, 0.95),
        rng.pick([sRamp[2], sRamp[1], sRamp[1], sRamp[0]]),
        rng.range(1.3, 2.4),
        rng.range(0.02, 0.1),
      );
    }
    for (var i = 0; i < 10; i++) {
      final a = rng.range(0, tau);
      final sp = rng.range(40, 110);
      ps.spawn(
        P.star,
        math.cos(a) * 5,
        _cy + math.sin(a) * 5,
        math.cos(a) * sp,
        math.sin(a) * sp - 20,
        rng.range(0.3, 0.6),
        rng.pick([kWhite, sRamp[1]]),
        0.6,
        rng.range(0, 0.08),
      );
    }
    for (var i = 0; i < 6; i++) {
      final s = rng.sign();
      ps.spawn(
        P.dust,
        s * rng.range(1, 6),
        -1,
        s * rng.range(25, 70),
        -rng.range(2, 10),
        rng.range(0.4, 0.7),
        cRamp[2],
        rng.range(1.6, 3),
        rng.range(0.02, 0.08),
      );
    }
    lights.add(0, _cy, 46, cRamp[4], 0.8, 0.4);
    lights.add(0, _cy, 22, kWhite, 0.8, 0.1);
  }

  late final List<int> cRamp;
  late final List<int> sRamp;
  late final Rng rng;
  late final Particles ps;
  late final Lights lights;
  final List<_Ball> balls = [];
  final List<_SpeedLine> lines = [];
  double t = 0;

  double _radius(_Ball b) {
    final age = b.max - b.life;
    final u = age / b.max;
    final grow = b.r0 + (b.r1 - b.r0) * Ease.outBack(clamp(age / 0.22), 2);
    final breathe = 1 + 0.06 * math.sin(age * 14 + b.r1);
    return grow *
        breathe *
        (u < 0.62 ? 1.0 : 1 - Ease.inBack(clamp((u - 0.62) / 0.38), 1.4));
  }

  void _drawBall(Painter p, _Ball b, String layer) {
    final age = b.max - b.life;
    final r = _radius(b);
    final a = math.min(1.0, age * 20);
    final lit = age < 0.12;
    if (r < 0.6) return;
    final hy = (b.y - _cy + 6) / 14;
    final lo = hy > 0.4;
    final hi = hy < -0.3;
    if (layer == 'shade') {
      p.disc(
        b.x + r * 0.16,
        b.y + r * 0.2,
        r,
        lit ? cRamp[3] : (lo ? cRamp[1] : cRamp[2]),
        0.8 * a,
      );
    } else if (layer == 'body') {
      p.disc(
        b.x - r * 0.06,
        b.y - r * 0.08,
        r * 0.86,
        lit ? cRamp[4] : (lo ? cRamp[2] : cRamp[3]),
        0.88 * a,
      );
    } else if (!lo || lit) {
      p.disc(
        b.x - r * 0.28,
        b.y - r * 0.34,
        r * 0.42,
        lit || hi ? kWhite : cRamp[4],
        0.85 * a,
      );
      if (age < 0.25) {
        p.disc(
          b.x - r * 0.3,
          b.y - r * 0.38,
          r * 0.2,
          kWhite,
          0.9 * a * (1 - age / 0.25),
        );
      }
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    for (var i = balls.length - 1; i >= 0; i--) {
      final b = balls[i];
      if (b.delay > 0) {
        b.delay -= dt;
        continue;
      }
      b.life -= dt;
      if (b.life <= 0) {
        if (b.r1 > 4) ps.spawn(P.star, b.x, b.y, 0, -8, 0.22, kWhite, 0.6);
        balls.removeAt(i);
        continue;
      }
      b.vx -= b.vx * 7 * dt;
      b.vy -= b.vy * 7 * dt + 30 * dt;
      b.x += b.vx * dt;
      b.y = math.min(b.y + b.vy * dt, -_radius(b) * 0.7);
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final s = 1 - smooth(0.1, 0.9, t);
    if (s > 0) p.glow(0, -1, 26, cRamp[4], 0.25 * s);
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final live = balls.where((b) => b.delay <= 0).toList();
    for (final layer in const ['shade', 'body', 'cap']) {
      for (final b in live) {
        _drawBall(p, b, layer);
      }
    }
    if (t < 0.07) {
      final k = t / 0.07;
      p.circle(0, _cy, 9 + 3 * k, cRamp[4]);
      p.circle(0, _cy, 7 + 3 * k, kWhite);
      flare(p, 0, _cy, 20 * (1 - k * 0.5), 1 - k, cRamp);
    }
    final rk = (t - 0.03) / 0.2;
    if (rk > 0 && rk < 1) {
      p.ring(
        0,
        _cy,
        8 + 18 * Ease.outCubic(rk),
        math.max(1.0, 2.5 * (1 - rk)),
        rk < 0.3 ? kWhite : cRamp[4],
        1.1 - rk,
      );
    }
    for (final l in lines) {
      final u = (t - l.d) / 0.2;
      if (u <= 0 || u >= 1) continue;
      final head = 8 + (l.r1 - 8) * Ease.outExpo(clamp(u / 0.6));
      final tail = 8 + (l.r1 - 8) * Ease.inCubic(u);
      final ca = math.cos(l.a);
      final sa = math.sin(l.a);
      p.lineShaded(
        ca * tail,
        _cy + sa * tail,
        ca * head,
        _cy + sa * head,
        color: (double v) => v > 0.6 ? kWhite : cRamp[4],
      );
      p.glowLine(
        ca * tail,
        _cy + sa * tail,
        ca * head,
        _cy + sa * head,
        3,
        cRamp[4],
        0.25,
      );
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}
