// The swirl's texture (streaks laid along a differentially wound flow, light on the brightest pixels) is adapted
// from Sprite Fusion's open-source black hole (https://www.spritefusion.com/pixel-art-vfx/black-hole), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'water_lib.dart';

const double _d = 3.0;
const double _r = 60.0;
const double _sy = 0.6;
const double _k = 2.4;
const double _eye = 0.16;

double _foam(double rho, double th, double ph) {
  final s = math.log(math.max(rho, 0.02));
  final a = th + _k * s + ph * tau;
  final b = th + _k * 1.35 * s + ph * tau * 2.0;
  final one = math.pow(0.5 + 0.5 * math.cos(7.0 * a + 0.9 * math.sin(3.0 * a + s * 4.0)), 26.0);
  final two = math.pow(0.5 + 0.5 * math.cos(11.0 * b + 1.3), 34.0) * 0.7;
  final three = math.pow(
        0.5 + 0.5 * math.cos(17.0 * (th + _k * 0.8 * s + ph * tau * 3.0)),
        30.0,
      ) *
      0.8 *
      math.max(0.0, 1.0 - (rho - _eye) * 2.2);
  final dash = 0.55 + 0.45 * math.sin(s * 22.0 - ph * tau * 4.0 + a * 2.0);
  return (one + two + three) * dash;
}

final PureEffect whirlpoolEffect = PureEffect(
  meta: const EffectMeta(
    id: 'water/whirlpool',
    name: 'Whirlpool',
    desc:
        "Seen from above, dark water winds into a vortex: foam arms spiral in, darkening as they're drawn down into a deep eye with a lit far rim, flecks of foam circling in after them.",
    category: 'water',
    tags: [
      'water',
      'whirlpool',
      'vortex',
      'maelstrom',
      'swirl',
      'top-down',
      'loop',
    ],
    size: (128, 84),
    origin: (64, 42),
    duration: 3.0,
    loop: true,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': kWaterPalette,
      'seed': 5,
    },
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _d;
    const ry = _r * _sy;

    p.shade(-_r, -ry, _r, ry, (x, y, out) {
      final dx = x / _r;
      final dy = y / ry;
      final rho = hypot(dx, dy);
      if (rho > 1.0) return null;
      final th = math.atan2(dy, dx);
      if (rho < _eye) {
        final far = -dy / rho;
        final wall = (rho / _eye - 0.35) / 0.65;
        if (far > 0.0) {
          out.c = wall > 0.8
              ? (far > 0.6 ? c[5] : c[4])
              : (wall > 0.45 ? c[3] : (wall > 0.15 ? c[2] : c[0]));
        } else {
          out.c = wall > 0.85 && far > -0.5 ? c[2] : c[0];
        }
        return null;
      }
      final k = (rho - _eye) / (1.0 - _eye);
      final fade = 1.0 - smooth(0.62, 1.0, k);
      p.blend(
        x,
        y,
        k < 0.25 ? c[0] : c[1],
        (0.75 - 0.25 * k) * (1.0 - smooth(0.8, 1.0, k)),
      );
      if (k > 0.3 && k < 0.8) {
        p.blend(x, y, c[2], 0.18 * math.sin(math.pi * (k - 0.3) / 0.5));
      }
      if (k < 0.035) {
        final g = 0.5 + 0.5 * math.cos(th * 9.0 - ph * tau * 6.0);
        out.c = g > 0.7 ? kWhite : (g > 0.3 ? c[6] : c[4]);
        return null;
      }
      final intensity = _foam(rho, th, ph) *
          fade *
          math.min(1.0, (k - 0.08) * 4.0) *
          (0.45 + 0.55 * math.sin(math.pi * math.min(1.0, k * 1.25)));
      if (intensity > 0.12) {
        out.c = intensity > 0.75
            ? kWhite
            : (intensity > 0.45 ? c[6] : (intensity > 0.25 ? c[5] : c[4]));
        if (intensity > 0.25) {
          out.l = c[5];
          out.k = 0.08 + 0.14 * math.min(1.0, intensity);
        }
      }
      return null;
    });

    cycle(t, _d, 30, o.seed, (g) => g.range(1.2, 2.2), (age, life, r, _) {
      final u = age / life;
      final rho = 0.8 - 0.62 * u * u;
      final a0 = r.range(0.0, tau);
      final th = a0 - _k * math.log(rho);
      final ang = th - age * (1.5 + 2.2 / rho);
      final x = math.cos(ang) * rho * _r;
      final y = math.sin(ang) * rho * ry;
      final ang2 = ang + 0.12 / rho;
      final x2 = math.cos(ang2) * rho * _r;
      final y2 = math.sin(ang2) * rho * ry;
      if (u > 0.85 && r.next() < (u - 0.85) * 6.0) return;
      p.line(x2, y2, x, y, u < 0.2 ? c[5] : (u < 0.6 ? kWhite : c[6]));
    });

    cycle(t, _d, 8, o.seed + 3, (g) => g.range(0.25, 0.45), (age, life, r, _) {
      final rho = r.range(0.35, 0.8);
      final th = r.range(0.0, tau) - age * 2.5;
      final k = math.sin((math.pi * age) / life);
      final x = math.cos(th) * rho * _r;
      final y = math.sin(th) * rho * ry;
      if (_foam(rho, th, ph) < 0.35) return;
      p.px(x, y, kWhite);
      if (k > 0.55) {
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          p.px(x + dx, y + dy, c[6]);
        }
      }
      p.glow(x, y, 5, c[5], 0.4 * k);
    });

    p.glow(0, 0, _r * 0.9, c[4], 0.2);
    p.glow(0, 0, _r * _eye * 1.6 + 6.0, c[5], 0.28);
    p.glow(0, -ry * _eye * 0.8, 14, c[5], 0.32);
  },
);
