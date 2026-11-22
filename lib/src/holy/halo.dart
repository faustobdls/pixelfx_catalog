import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'holy_lib.dart';

const Pose _pray = Pose(
  turn: 1.1,
  fx: -1,
  fy: -26,
  bx: 2,
  by: -26,
  armsFront: true,
  hy: 1,
  ffx: -3,
  fbx: 4,
);

const double _dur = 2.0;
const double _hy = -46.0;
const double _rx = 9.5;
const double _ry = 2.6;

// How far apart two angles are (0..pi).
double _apart(double a, double b) =>
    (wrap(a - b + math.pi, tau) - math.pi).abs();

final PureEffect haloEffect = PureEffect(
  meta: const EffectMeta(
    id: 'holy/halo',
    name: 'Halo',
    desc:
        'A ring of gold light floats over the head with a glint running round it; fine dust sifts down from it and the head catches its light.',
    category: 'holy',
    tags: ['holy', 'halo', 'saint', 'buff', 'glow', 'character', 'loop'],
    size: (56, 80),
    origin: (28, 70),
    duration: _dur,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'palette': kHolyGold, 'seed': 5},
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      const PoseKey(0.0, _pray),
      PoseKey(0.5, _pray.copyWith(crouch: 1)),
      PoseKey(1.0, _pray.copyWith(crouch: 1, hy: 2)),
      PoseKey(1.5, _pray.copyWith(crouch: 1)),
      const PoseKey(2.0, _pray),
    ],
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = (t / _dur) * tau;
    final a = o['actor'] as ActorDefinition?;
    final seed = o.seed;
    final y0 = _hy + (math.sin(ph) > 0.55 ? -1.0 : 0.0);
    final gl = math.pi / 2.0 + ph;

    // The hair under it catches the light.
    if (a != null && a.pixels.isNotEmpty) {
      final m = a.mask;
      final maxJ = math.min(m.h, 9);
      for (var i = 0; i < m.w; i++) {
        for (var j = 0; j < maxJ; j++) {
          final col = a.pixels[j * m.w + i];
          // Skip empty space and the dark outline, light the first pixel of hair under it.
          if (col == 0 || luma(col) < 0.15) continue;
          final x = a.x + i;
          final y = a.y + j;
          p.px(x, y, mix(col, c[6], 0.45));
          if (j + 1 < m.h) {
            final c2 = a.pixels[(j + 1) * m.w + i];
            if (c2 != 0 && luma(c2) >= 0.15) {
              p.px(x, y + 1, mix(c2, c[5], 0.18));
            }
          }
          for (var d = 0; d <= 4; d++) {
            p.light(x, y + d, c[4], 0.3 * (1.0 - d / 5.0));
          }
          break;
        }
      }
    }

    // The ring: a thick bright near side, a thin far side, a slow shimmer running round, the glint.
    const n = 92;
    for (var j = 0; j < n; j++) {
      final g = (j / n) * tau;
      final x = math.cos(g) * _rx;
      final y = y0 + math.sin(g) * _ry;
      final near = math.sin(g) >= 0.0;
      final shimmer = math.sin(g * 3.0 - ph * 2.0) > 0.7;
      final hot = _apart(g, gl) < 0.3;
      if (near) {
        p.px(x, y, hot ? kWhite : (shimmer ? kWhite : c[6]));
        p.px(x, y + 1.0, hot ? c[6] : c[4]);
      } else {
        p.dot(x, y, hot ? kWhite : (shimmer ? c[6] : c[5]), 0.9);
      }
    }
    p.glow(0, y0, 20, c[4], 0.4);
    p.glow(0, y0 + 1.0, 9, kWhite, 0.16);
    final gx = math.cos(gl) * _rx;
    final gy = y0 + math.sin(gl) * _ry;
    if (math.sin(gl) > -0.2) {
      sparkle(
        p,
        gx,
        gy + 0.5,
        1.5 + 2.5 * math.max(0.0, math.sin(gl)),
        kWhite,
        c[6],
        0.45,
      );
    } else {
      p.glow(gx, gy, 5, c[6], 0.3);
    }

    // Light falls from it onto the head.
    p.glowLine(0, y0 + 2.0, 0, y0 + 9.0, 9, c[4], 0.16);

    // Little stars wink on and off about the ring.
    cycle(t, _dur, 6, seed + 3, (g) => g.range(0.3, 0.5),
        (age, life, rr, _) {
      final g = rr.range(0.0, tau);
      final d = rr.range(1.1, 1.5);
      final k = math.sin((age / life) * math.pi);
      final dy = rr.range(1.0, 4.0);
      sparkle(
        p,
        math.cos(g) * _rx * d,
        y0 + math.sin(g) * _ry * d - dy,
        1.0 + 2.0 * k,
        kWhite,
        c[6],
        0.4 * k,
      );
    });

    // Dust sifting down off the ring.
    cycle(t, _dur, 16, seed, (g) => g.range(0.8, 1.5), (age, life, rr, _) {
      final g = rr.range(0.0, tau);
      final u = age / life;
      final x = math.cos(g) * _rx * rr.range(0.8, 1.0) +
          math.sin(u * 5.0 + g) * 1.2;
      final y = y0 + math.sin(g) * _ry + 1.0 + u * rr.range(7.0, 14.0);
      final tw = 0.6 + 0.4 * math.sin(age * 18.0 + g * 7.0);
      final k = math.sin(u * math.pi) * tw;
      p.dot(x, y, tw > 0.85 ? kWhite : c[6], math.min(1.0, k * 1.5));
      p.light(x, y, c[5], 0.5 * k);
    });
  },
);
