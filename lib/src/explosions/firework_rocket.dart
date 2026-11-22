// The flare, the twinkling glitter and the crackle are adapted from Sprite Fusion's open-source sparkle
// (https://www.spritefusion.com/pixel-art-vfx/sparkle), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'explosions_lib.dart';

const double _fly = 1.05;
const double _high = 192.0;
const double _drag = 1.35;
const double _g = 105.0;
const double _trail = 1.15;

class _Frond {
  double x, y, vx, vy, age, acc;
  final double life, seed;
  final List<double> pts = [];

  _Frond({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.acc,
    required this.seed,
  }) : age = 0.0;
}

class _Pop {
  final double x, y, t0, life;
  final int c;
  const _Pop(this.x, this.y, this.t0, this.life, this.c);
}

class _FireworkRocketSim extends BaseEffectSim {
  final EffectMeta meta;
  final List<int> c, tipColors;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  final List<_Frond> fronds = [];
  final List<_Pop> pops = [];
  double t = 0.0;
  bool burst = false;
  double bx = 0.0;
  double by = 0.0;
  double acc = 0.0;

  _FireworkRocketSim(this.meta, Map<String, Object?> o)
      : c = fit(o.palette, 7),
        tipColors = fit(
          (o['tips'] as List<Object?>?)?.cast<Object>() ??
              const [
                '#0c2a3a',
                '#1a5a78',
                '#36a2c8',
                '#7cd8f0',
                '#c8f4ff',
                '#ffffff',
              ],
          6,
        ),
        r = Rng(o.seed) {
    ps = Particles(rng: r, sparks: [c[6], c[5], c[4], c[3]]);
    lights.add(0, -14, 24, c[4], 0.7, 0.35);
    for (var i = 0; i < 18; i++) {
      final a = -math.pi / 2 + r.range(-1.2, 1.2);
      final sp = r.range(60, 180);
      ps.spawn(P.spark, 0, -2, math.cos(a) * sp, math.sin(a) * sp * 0.6,
          r.range(0.15, 0.4));
    }
    for (var i = 0; i < 5; i++) {
      ps.spawn(P.vapour, r.range(-3, 3), -2, r.range(-20, 20), -r.range(2, 10),
          r.range(0.6, 1), hex('#5a5468'), r.range(3, 5));
    }
  }

  (double, double) _at(double time) => (
        math.sin(time * 8.0) * 1.6 * (time / _fly),
        -8.0 - _high * Ease.outQuad(clamp(time / _fly)),
      );

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (t < _fly) {
      final (x, y) = _at(t);
      final (x2, y2) = _at(math.max(0.0, t - 0.02));
      final vy = (y - y2) / 0.02;
      final vx = (x - x2) / 0.02;
      for (acc += dt * 90.0; acc > 1.0; acc -= 1.0) {
        final a = math.pi / 2 + r.range(-0.45, 0.45);
        final sp = r.range(30, 110);
        ps.spawn(
          P.spark,
          x,
          y + 4.0,
          math.cos(a) * sp + vx * 0.2,
          math.sin(a) * sp + vy * 0.15,
          r.range(0.15, 0.4),
        );
        if (r.chance(0.25)) {
          ps.spawn(
            P.star,
            x + r.range(-1.5, 1.5),
            y + r.range(2, 6),
            r.range(-6, 6),
            r.range(5, 20),
            r.range(0.4, 0.9),
            r.chance(0.5) ? c[5] : kWhite,
            r.chance(0.15) ? 1.2 : 0.5,
          );
        }
        if (r.chance(0.18)) {
          ps.spawn(
            P.vapour,
            x,
            y + 5.0,
            r.range(-4, 4),
            r.range(4, 12),
            r.range(0.6, 1.1),
            hex('#4a4458'),
            r.range(1.2, 2.2),
          );
        }
      }
    } else if (!burst) {
      burst = true;
      final (x, y) = _at(_fly);
      bx = x;
      by = y;
      lights.add(bx, by, 82, c[4], 0.8, 1.6);
      lights.add(bx, by, 40, kWhite, 0.6, 0.08);
      for (var i = 0; i < 9; i++) {
        final a =
            -math.pi / 2 + ((i - 4) / 4.0) * 1.4 + r.range(-0.1, 0.1);
        final sp = r.range(180, 210) * (1.0 - 0.12 * (i - 4).abs() / 4.0);
        fronds.add(_Frond(
          x: bx,
          y: by,
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp,
          life: r.range(1.8, 2.15),
          acc: r.next(),
          seed: r.range(0, 100),
        ));
      }
      for (var i = 0; i < 6; i++) {
        ps.spawn(
          P.vapour,
          bx + r.range(-4, 4),
          by + r.range(-4, 4),
          r.range(-20, 20),
          r.range(-15, 15),
          r.range(1.8, 2.6),
          hex('#4a4458'),
          r.range(6, 10),
        );
      }
      for (var i = 0; i < 30; i++) {
        final a = r.range(0, tau);
        final sp = r.range(40, 160);
        ps.spawn(P.spark, bx, by, math.cos(a) * sp, math.sin(a) * sp,
            r.range(0.15, 0.35));
      }
    }
    for (var i = fronds.length - 1; i >= 0; i--) {
      final f = fronds[i];
      f.age += dt;
      final k = f.age / f.life;
      if (k >= 1.0) {
        for (var j = 0; j < 4; j++) {
          pops.add(_Pop(
            f.x + r.range(-5, 5),
            f.y + r.range(-5, 5),
            t + r.range(0, 0.2),
            r.range(0.06, 0.12),
            r.chance(0.5) ? kWhite : tipColors[3],
          ));
        }
        fronds.removeAt(i);
        continue;
      }
      f.vx -= f.vx * _drag * dt;
      f.vy -= f.vy * _drag * dt - _g * dt;
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      f.pts
        ..add(f.x)
        ..add(f.y)
        ..add(t);
      while (f.pts.length > 3 && t - f.pts[2] > _trail) {
        f.pts.removeRange(0, 3);
      }
      for (f.acc += dt * 34.0; f.acc > 1.0; f.acc -= 1.0) {
        ps.spawn(
          P.star,
          f.x + r.range(-1, 1),
          f.y + r.range(-1, 1),
          f.vx * 0.1 + r.range(-5, 5),
          r.range(0, 14),
          r.range(0.5, 1.1),
          r.chance(0.6) ? c[5] : kWhite,
          r.chance(0.12) ? r.range(1, 1.5) : 0.5,
        );
      }
    }
    for (var i = pops.length - 1; i >= 0; i--) {
      if (t > pops[i].t0 + pops[i].life) pops.removeAt(i);
    }
    ps.update(dt);
    cullParticles(
      ps,
      -meta.origin.$1 + 2.0,
      -meta.origin.$2 + 2.0,
      meta.size.$1 - meta.origin.$1 - 2.0,
      meta.size.$2 - meta.origin.$2 - 2.0,
    );
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    if (t < _fly) {
      final (x, y) = _at(t);
      p.line(x, y + 4.0, x, y + 12.0, hex('#5a4030'));
      p.rect(x - 1.0, y - 3.0, 3, 7, hex('#b8303a'));
      p.px(x - 1.0, y - 3.0, hex('#e86070'));
      p.px(x, y - 4.0, hex('#d8d0c0'));
      final fl = 2.0 + (math.sin(t * 70.0) > 0.0 ? 1.0 : 0.0);
      p.lineShaded(x, y + 4.0, x, y + 4.0 + fl,
          color: (u) => u < 0.4 ? kWhite : c[5]);
      p.glow(x, y + 5.0, 9, c[4], 0.6);
    }
    for (final f in fronds) {
      final k = f.age / f.life;
      final pts = f.pts;
      final n = pts.length ~/ 3;
      for (var j = n - 1; j > 0; j--) {
        final u = (t - pts[j * 3 + 2]) / _trail;
        if (u >= 1.0) break;
        final col = u < 0.08
            ? c[6]
            : (u < 0.25 ? c[5] : (u < 0.5 ? c[4] : (u < 0.75 ? c[3] : c[2])));
        final a = math.pow(1.0 - u, 0.6).toDouble() * (1.25 - k * 0.45);
        p.line(pts[j * 3], pts[j * 3 + 1], pts[j * 3 - 3], pts[j * 3 - 2], col, a);
        if (u < 0.7) {
          p.line(
            pts[j * 3] + 1.0,
            pts[j * 3 + 1],
            pts[j * 3 - 3] + 1.0,
            pts[j * 3 - 2],
            u < 0.25 ? c[5] : (u < 0.5 ? c[3] : c[2]),
            a * 0.85,
          );
        }
        if (u < 0.35) {
          p.line(pts[j * 3], pts[j * 3 + 1] + 1.0, pts[j * 3 - 3],
              pts[j * 3 - 2] + 1.0, c[3], a * 0.6);
        }
      }
      if (k > 0.8 && math.sin(t * 55.0 + f.seed) < 0.0) continue;
      p.rect(f.x - 0.5, f.y - 0.5, 2, 2, k < 0.5 ? kWhite : c[6]);
      if (k < 0.6) {
        for (final (dx, dy) in const [(-1, 0), (2, 0), (0, -1), (0, 2)]) {
          p.px(f.x + dx, f.y + dy, c[5]);
        }
      }
      p.glow(f.x, f.y, 10, c[4], 0.6 * (1.0 - k * 0.5));
    }
    for (final q in pops) {
      final u = (t - q.t0) / q.life;
      if (u < 0.0 || u > 1.0) continue;
      sparkle(
          p, q.x, q.y, 2.8 * math.sin(math.pi * u), q.c, tipColors[2], 0.5);
    }
    final b = t - _fly;
    if (b >= 0.0 && b < 0.26) {
      final u = b / 0.26;
      final l = 30.0 * math.pow(1.0 - u, 1.3).toDouble();
      for (var i = 0; i < 8; i++) {
        final diag = i % 2 == 1;
        final an = u * 0.5 + (i * tau) / 8.0;
        final len = diag ? l * 0.45 : l;
        final ca = math.cos(an);
        final sa = math.sin(an);
        for (var d = 0.0; d <= len; d += 0.5) {
          final v = d / len;
          p.dot(
            bx + ca * d,
            by + sa * d,
            v < 0.3 ? kWhite : (v < 0.65 ? c[5] : c[4]),
            v < 0.7 ? 1.0 : 1.0 - (v - 0.7) / 0.35,
          );
        }
      }
      if (b < 0.07) p.circle(bx, by, 2.5, kWhite);
      p.glow(bx, by, 4.0 + l * 1.2, c[4], 0.35);
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

const EffectMeta _fireworkRocketMeta = EffectMeta(
  id: 'explosions/firework-rocket',
  name: 'Firework rocket',
  desc:
      'A rocket fizzes off the ground on a sparkling gold trail, coasts, and bursts into a palm: heavy gold fronds arc out, droop on glittering trails and crackle at the tips.',
  category: 'explosions',
  tags: ['firework', 'rocket', 'celebration', 'sparkle', 'sky', 'one-shot'],
  size: (300, 300),
  origin: (150, 288),
  duration: 3.8,
  loop: false,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': [
      '#2a1406',
      '#6a3a0c',
      '#b8701a',
      '#f0a830',
      '#ffd860',
      '#fff2b0',
      '#ffffff',
    ],
    'tips': [
      '#0c2a3a',
      '#1a5a78',
      '#36a2c8',
      '#7cd8f0',
      '#c8f4ff',
      '#ffffff',
    ],
    'seed': 12,
  },
);

final SimulatedEffect fireworkRocketEffect = SimulatedEffect(
  meta: _fireworkRocketMeta,
  onCreate: (o) => _FireworkRocketSim(_fireworkRocketMeta, o),
);
