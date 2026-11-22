// The orb's shading and its glow follow Sprite Fusion's open-source pickup orb
// (https://www.spritefusion.com/pixel-art-vfx/pickup), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'pickups_lib.dart';

const double _duration = 1.8;
const double _a = 16.0;
const double _b = 9.0;
const double _hover = 20.0;
const double _tail = 0.48;
final int _ink = hex('#0a1406');

(double, double) _at(double t) {
  final a = (t / _duration) * tau;
  return (
    _a * math.sin(a),
    -_hover + _b * math.sin(a) * math.cos(a) - 1.2 * math.cos(a * 2.0),
  );
}

final PureEffect xpOrbEffect = PureEffect(
  meta: const EffectMeta(
    id: 'pickups/xp-orb',
    name: 'XP orb',
    desc:
        'A small glowing orb races a figure-eight, a comet tail tapering behind it along its path, flecks shed from the tail winking out, its light following it over the floor.',
    category: 'pickups',
    tags: ['pickup', 'xp', 'orb', 'experience', 'energy', 'loop'],
    size: (72, 56),
    origin: (36, 48),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#0c1806',
        '#1e3a0a',
        '#36620e',
        '#5c9614',
        '#8cd024',
        '#c4f060',
        '#effcc0',
        '#ffffff',
      ],
      'seed': 2,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final (x, _) = _at(t);
    blobShadow(p, x, 3.5, 0.55);
    pool(p, x, 0.5, 14.0, 3.0, c[5], 0.3);
    cycle(t, _duration, 16, o.seed, (g) => g.range(0.35, 0.7),
        (age, life, r, _) {
      final (fx, fy) = _at(t - age);
      final k = 1.0 - age / life;
      final tw = math.sin(age * r.range(20.0, 30.0) + r.range(0.0, tau));
      final x2 = fx + r.range(-2.0, 2.0) + age * r.range(-6.0, 6.0);
      final y2 = fy + r.range(-2.0, 2.0) + age * r.range(4.0, 10.0);
      if (tw * k > -0.2) {
        p.px(
          x2,
          y2,
          tw > 0.6 && k > 0.5 ? kWhite : (k > 0.5 ? c[6] : c[5]),
        );
      }
      p.glow(x2 + 0.5, y2 + 0.5, 3.0, c[5], 0.3 * k);
    });
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final (x, y) = _at(t);
    final beat = 0.5 + 0.5 * math.sin((t / _duration) * tau * 3.0);
    const n = 60;
    for (var i = n; i >= 1; i--) {
      final u = i / n;
      final (tx, ty) = _at(t - u * _tail);
      final r = 3.1 * math.pow(1.0 - u, 1.1).toDouble();
      final col = u < 0.25 ? c[5] : (u < 0.55 ? c[4] : c[3]);
      if (r > 0.6) {
        p.circle(tx, ty, r, col, u < 0.7 ? 1.0 : (1.0 - u) * 3.3);
      } else {
        p.dot(tx, ty, col, (1.0 - u) * 3.0);
      }
      if (i % 6 == 0) {
        p.glow(tx, ty, 7.0 * (1.0 - u) + 2.0, c[5], 0.24 * (1.0 - u));
      }
    }
    for (var i = (n * 0.6).floor(); i >= 1; i--) {
      final u = i / n;
      final (tx, ty) = _at(t - u * _tail);
      p.dot(tx, ty, u < 0.2 ? kWhite : c[6], (0.6 - u) * 4.0);
    }
    final xi = (x + 0.5).floor();
    final yi = (y + 0.5).floor();
    p.circle(xi, yi, 4.4, _ink);
    p.circleShaded(
      xi,
      yi,
      3.6,
      color: (d, a) => d > 0.72
          ? (math.cos(a + 2.4) > 0.3 ? c[5] : c[3])
          : (d > 0.4
              ? (math.cos(a + 2.4) > -0.2 ? c[6] : c[5])
              : kWhite),
    );
    p.px(xi - 2, yi - 2, kWhite);
    p.px(xi - 1, yi - 2, c[7]);
    p.glow(x, y, 16.0 + 3.0 * beat, c[5], 0.36 + 0.14 * beat);
    final g = ((t / _duration) * 3.0) % 1.0;
    if (g < 0.12) {
      glint(
        p,
        xi - 2.0,
        yi - 2.0,
        2.4 * math.sin((g / 0.12) * math.pi),
        kWhite,
        0.4,
      );
    }
  },
);
