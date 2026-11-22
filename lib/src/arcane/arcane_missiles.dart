// The bolt and its pop (a layered head with spinning rays, a flash disc, a cross, a ring, plasma sparks and stars)
// are adapted from Sprite Fusion's open-source energy bolt (https://www.spritefusion.com/pixel-art-vfx/energy),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const double _hx = 15.0;
const double _hy = -24.0;
const double _tx = 152.0;
const double _ty = -22.0;
const int _trail = 18;

final Pose _open = kReady.copyWith(
  x: -3,
  crouch: 4,
  lean: 4,
  fx: 18,
  fy: -24,
  bx: -6,
  by: -22,
  ffx: 11,
  fbx: -9,
);

final Pose _kick = _open.copyWith(fx: 15, fy: -26, lean: 2);

final Pose _gather = kReady.copyWith(
  x: -3,
  crouch: 4,
  lean: -2,
  fx: 6,
  fy: -24,
  bx: 8,
  by: -24,
  ffx: 9,
  fbx: -7,
);

class _Bolt {
  final double t0;
  double x;
  double y;
  double vx;
  double vy;
  final List<Point2> trail = [];
  double hit = -1.0;
  bool on = false;
  final double tx;
  final double ty;
  final double tw;
  double acc = 0.0;

  _Bolt({
    required this.t0,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.tx,
    required this.ty,
    required this.tw,
  });
}

class _Pop {
  final double t;
  final double x;
  final double y;

  const _Pop(this.t, this.x, this.y);
}

class _ArcaneMissilesSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  late final List<_Bolt> bolts;
  final List<_Pop> pops = [];
  double t = 0.0;

  _ArcaneMissilesSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed) {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [kWhite, c[6], c[5], c[4]],
    );
    const fan = [-1.05, 0.7, -0.5, 1.1, -1.4];
    bolts = List.generate(fan.length, (i) {
      final a = fan[i] + r.range(-0.12, 0.12);
      final sp = r.range(130.0, 165.0);
      return _Bolt(
        t0: 0.05 + i * 0.1,
        x: _hx,
        y: _hy,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp,
        tx: _tx + r.range(-3.0, 3.0),
        ty: _ty + r.range(-6.0, 6.0),
        tw: r.range(0.0, tau),
      );
    }, growable: false);
  }

  void _ribbon(Painter p, _Bolt b) {
    final pts = b.trail;
    final n = pts.length;
    final fade = b.hit < 0.0 ? 1.0 : 1.0 - clamp((t - b.hit) / 0.16);
    if (n < 2 || fade <= 0.0) return;
    for (var i = 0; i < n - 1; i++) {
      final (x0, y0) = pts[i];
      final (x1, y1) = pts[i + 1];
      final rawL = hypot(x1 - x0, y1 - y0);
      final l = rawL == 0.0 ? 1.0 : rawL;
      final nx = -(y1 - y0) / l;
      final ny = (x1 - x0) / l;
      for (var d = 0.0; d < l; d += 0.5) {
        final u = (i + d / l) / (n - 1);
        final x = x0 + ((x1 - x0) * d) / l;
        final y = y0 + ((y1 - y0) * d) / l;
        final a = (1.0 - u) * 1.7 * fade;
        final w = 2.6 * math.pow(1.0 - u, 0.8) + 0.3;
        for (var q = -w; q <= w; q += 0.5) {
          final v = q.abs() / w;
          final col = v < 0.35
              ? (u < 0.25 ? kWhite : c[6])
              : v < 0.7
                  ? (u < 0.4 ? c[6] : c[5])
                  : (u < 0.5 ? c[5] : c[4]);
          p.dot(x + nx * q, y + ny * q, col, a * (v < 0.7 ? 1.0 : 0.75));
        }
        for (final s in const [0.0, math.pi]) {
          final ph = u * 10.0 - t * 26.0 + b.tw + s;
          final off = math.sin(ph) * (w + 1.4);
          if (math.cos(ph) > -0.2) {
            p.dot(
              x + nx * off,
              y + ny * off,
              math.cos(ph) > 0.4 ? (u < 0.35 ? kWhite : c[6]) : c[4],
              a,
            );
          }
        }
      }
      if (i % 3 == 0) {
        p.glow(x0, y0, 9.0 * (1.0 - i / n) + 3.0, c[5],
            0.3 * (1.0 - i / n) * fade);
      }
    }
  }

  void _head(Painter p, _Bolt b) {
    final x = b.x;
    final y = b.y;
    for (var i = 0; i < 4; i++) {
      final a = t * 24.0 + (i * tau) / 4.0 + b.tw;
      final l = 5.5 + 1.5 * math.sin(t * 50.0 + i);
      p.line(
        x + math.cos(a) * 3.2,
        y + math.sin(a) * 3.2,
        x + math.cos(a) * l,
        y + math.sin(a) * l,
        c[6],
      );
    }
    p.circle(x, y, 3.8, c[4]);
    p.circle(x, y, 3.0, c[5]);
    p.circle(x, y, 2.1, c[6]);
    p.circle(x, y, 1.2, kWhite);
    p.glow(x, y, 24, c[5], 0.6);
    p.glow(x, y, 7, kWhite, 0.4);
  }

  void _pop(Painter p, double q, double x, double y) {
    if (q < 0.16) {
      final rr = 9.0 * (1.0 - q / 0.16) + 1.5;
      p.circle(x, y, rr + 1.5, c[5]);
      p.circle(x, y, rr, kWhite);
    }
    if (q < 0.4) {
      final l = 15.0 * (1.0 - q / 0.4) + 3.0;
      for (var d = -l; d <= l; d++) {
        final a = d.abs() / l;
        final col = a < 0.3
            ? kWhite
            : a < 0.65
                ? c[6]
                : c[5];
        p.dot(x + d, y, col, 1.15 - a);
        p.dot(x, y + d * 0.7, col, 1.15 - a);
      }
    }
    final rr = 3.0 + 18.0 * Ease.outCubic(q);
    p.ring(x, y, rr + 0.5, math.max(1.0, 3.0 * (1.0 - q)),
        q < 0.3 ? kWhite : c[6], 1.2 - q);
  }

  void _lock(Painter p) {
    final k = smooth(0.0, 0.22, t) * (1.0 - smooth(1.15, 1.45, t));
    if (k <= 0.0) return;
    var kick = 0.0;
    for (final q in pops) {
      final d = (t - q.t) / 0.06;
      kick = math.max(kick, math.exp(-(d * d)));
    }
    final rr =
        9.0 + 10.0 * (1.0 - Ease.outCubic(smooth(0.0, 0.22, t))) + 3.0 * kick;
    final spin = t * 1.5;
    for (var i = 0; i < 4; i++) {
      final a0 = spin + (i * tau) / 4.0 - 0.38;
      for (var a = a0; a <= a0 + 0.76; a += 0.06) {
        p.dot(
          _tx + math.cos(a) * rr,
          _ty + math.sin(a) * rr,
          kick > 0.4 ? kWhite : c[5],
          k,
        );
      }
    }
    p.glow(_tx, _ty, 12, c[4], 0.2 * k);
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    for (final b in bolts) {
      if (t < b.t0 || b.hit >= 0.0) continue;
      if (!b.on) {
        b.on = true;
        lights.add(_hx, _hy, 28, c[5], 0.7, 0.14);
        final baseAng = math.atan2(b.vy, b.vx);
        for (var i = 0; i < 4; i++) {
          final vx =
              math.cos(baseAng + r.range(-0.6, 0.6)) * r.range(60.0, 140.0);
          final vy =
              math.sin(baseAng + r.range(-0.6, 0.6)) * r.range(60.0, 140.0);
          ps.spawn(
            P.mote,
            _hx,
            _hy,
            vx,
            vy,
            r.range(0.12, 0.25),
            c[6],
            0.6,
          );
        }
      }
      final age = t - b.t0;
      final dx = b.tx - b.x;
      final dy = b.ty - b.y;
      final rawD = hypot(dx, dy);
      final d = rawD == 0.0 ? 1.0 : rawD;
      final sp = 150.0 + 560.0 * age * age;
      final steer = math.min(1.0, (1.4 + 15.0 * age) * dt);
      b.vx += ((dx / d) * sp - b.vx) * steer;
      b.vy += ((dy / d) * sp - b.vy) * steer;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.trail.insert(0, (b.x, b.y));
      if (b.trail.length > _trail) b.trail.removeLast();
      if ((b.acc += dt) > 0.012) {
        b.acc = 0.0;
        if (r.chance(0.6)) {
          ps.spawn(
            P.mote,
            b.x,
            b.y,
            -b.vx * 0.08 + r.range(-25.0, 25.0),
            -b.vy * 0.08 + r.range(-25.0, 25.0),
            r.range(0.2, 0.4),
            r.chance(0.5) ? c[6] : c[5],
            0.55,
          );
        }
      }
      if (d < 3.0 || age > 1.3) {
        b.hit = t;
        pops.add(_Pop(t, b.x, b.y));
        lights.add(b.x, b.y, 70, c[5], 0.9, 0.3);
        lights.add(b.x, b.y, 24, kWhite, 0.85, 0.09);
        for (var i = 0; i < 16; i++) {
          final a = r.range(0.0, tau);
          final v = r.range(80.0, 230.0);
          ps.spawn(P.spark, b.x, b.y, math.cos(a) * v, math.sin(a) * v - 40.0,
              r.range(0.15, 0.45));
        }
        for (var i = 0; i < 7; i++) {
          final a = r.range(-math.pi, 0.3);
          final v = r.range(40.0, 140.0);
          ps.spawn(
            i.isOdd ? P.star : P.mote,
            b.x,
            b.y,
            math.cos(a) * v,
            math.sin(a) * v,
            r.range(0.25, 0.48),
            r.pick([kWhite, c[6], c[5]]),
            r.range(0.8, 1.6),
          );
        }
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    for (final q in pops) {
      final k = 1.0 - clamp((t - q.t) / 0.5);
      if (k > 0.0) p.glow(q.x, -1, 22, c[5], 0.25 * k * k);
    }
  }

  @override
  void draw(Painter p) {
    _lock(p);
    for (final b in bolts) {
      if (b.on) _ribbon(p, b);
    }
    for (final b in bolts) {
      if (b.on && b.hit < 0.0) _head(p, b);
    }
    for (final q in pops) {
      final k = (t - q.t) / 0.35;
      if (k < 1.0) _pop(p, k, q.x, q.y);
    }
    if (t < 0.55) {
      sparkle(p, _hx, _hy, 3.0 + 2.0 * math.sin(t * 40.0), c[6], c[5],
          0.45 * (1.0 - t / 0.55));
    }
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect arcaneMissilesEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'arcane/arcane-missiles',
    name: 'Arcane missiles',
    desc:
        'A volley of violet bolts fans out of the hand, curls round on twisting ribbons and pops on the target one after another.',
    category: 'arcane',
    tags: [
      'arcane',
      'missile',
      'projectile',
      'homing',
      'volley',
      'magic',
      'directional',
      'one-shot',
    ],
    size: (240, 116),
    origin: (26, 88),
    duration: 1.75,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'palette': Pal.arcane, 'seed': 3},
  ),
  act: ActSpec(
    target: const TargetSpec(x: 152),
    poses: [
      PoseKey(-0.52, kReady.copyWith(x: -3)),
      PoseKey(-0.24, _gather),
      PoseKey(0.0, _gather.copyWith(crouch: 5)),
      PoseKey(0.05, _kick, PoseEase.snap),
      PoseKey(0.1, _open, PoseEase.snap),
      PoseKey(0.15, _kick, PoseEase.snap),
      PoseKey(0.2, _open, PoseEase.snap),
      PoseKey(0.25, _kick, PoseEase.snap),
      PoseKey(0.29, _open, PoseEase.snap),
      PoseKey(0.33, _kick, PoseEase.snap),
      PoseKey(0.38, _open, PoseEase.snap),
      PoseKey(0.43, _kick, PoseEase.snap),
      PoseKey(0.48, _open, PoseEase.snap),
      PoseKey(1.2, _open.copyWith(crouch: 3)),
      PoseKey(1.7, kReady.copyWith(x: -3)),
    ],
    hits: const [
      HitSpec(t: 0.77, stop: 0.02, push: 0.7, straw: 4, y: -24, flash: 0.03),
      HitSpec(t: 0.85, stop: 0.02, push: 0.7, straw: 4, y: -24, flash: 0.03),
      HitSpec(t: 0.95, stop: 0.02, push: 0.7, straw: 4, y: -24, flash: 0.03),
      HitSpec(t: 1.08, stop: 0.02, push: 0.7, straw: 4, y: -24, flash: 0.03),
      HitSpec(t: 1.2, stop: 0.07, shake: 0.14, amp: 1, push: 1.4, straw: 9, y: -24),
    ],
  ),
  onCreate: (o) => _ArcaneMissilesSim(o),
);
