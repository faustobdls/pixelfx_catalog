// The layered ball, its tapering wake and the zap to the floor with stars where it lands follow Sprite Fusion's
// open-source energy orb and bolt (https://www.spritefusion.com/pixel-art-vfx/energy),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'lightning_lib.dart';

const int _fps = 30;
const int _n = 120;
const double _period = 4.0;
const int _zapFrame = 62;

Point2 _at(double t) {
  final a = (t / _period) * tau;
  return (
    38.0 * math.sin(a) + 9.0 * math.sin(2.0 * a + 1.0),
    -42.0 + 13.0 * math.sin(2.0 * a + 0.4) + 6.0 * math.sin(3.0 * a + 0.5),
  );
}

final PureEffect ballLightningEffect = PureEffect(
  meta: const EffectMeta(
    id: 'lightning/ball-lightning',
    name: 'Ball lightning',
    desc:
        'A crackling ball of plasma drifts on a wandering loop, spitting arcs off its skin and leaving a wake of fading motes, and zaps the floor when it dips low.',
    category: 'lightning',
    tags: ['lightning', 'electric', 'plasma', 'orb', 'wisp', 'ambient', 'loop'],
    size: (136, 104),
    origin: (68, 92),
    duration: 4.0,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': voltPalette,
      'sparks': plasmaSparks,
      'seed': 9,
    },
  ),
  onDraw: (Painter p, double t, Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final s = (o['sparks'] as List).cast<Object>().map(hex).toList(growable: false);
    final seed = o.seed;
    final f = (t * _fps + 1e-6).floor() % _n;
    final r = rng(seed, 1, f);
    final (x, y) = _at(t);

    p.glow(x, -2, 30, c[3], 0.12 + 0.3 * clamp((y + 60.0) / 40.0));

    for (var i = 14; i >= 1; i--) {
      final (wx, wy) = _at(t - i * 0.034);
      final u = i / 14.0;
      final rr = 3.0 * (1.0 - u) + 0.3;
      if (u > 0.6 && (i + f) % 2 != 0) continue;
      p.circle(wx, wy, rr + 0.8, u < 0.35 ? c[3] : c[2]);
      p.circle(wx, wy, rr, u < 0.35 ? c[6] : (u < 0.7 ? c[5] : c[4]));
      p.glow(wx, wy, 7.0 * (1.0 - u) + 3.0, c[4], 0.25 * (1.0 - u));
    }

    cycle(t, _period, 40, seed + 5, (g) => g.range(0.5, 1.0), (age, life, q, _) {
      final born = t - age;
      final (bx, by) = _at(born);
      final k = 1.0 - age / life;
      final a = q.range(0.0, tau);
      final sp = q.range(4.0, 14.0);
      final mx = bx + math.cos(a) * sp * age + q.range(-3.0, 3.0);
      final my = by + math.sin(a) * sp * age + 6.0 * age + q.range(-3.0, 3.0);
      if (k > 0.25 || f % 2 != 0) {
        p.px(mx, my, k > 0.6 ? c[6] : (k > 0.3 ? c[4] : c[3]));
      }
      p.glow(mx, my, 3, c[4], 0.3 * k);
    });

    final r0 = 5.2 + 0.6 * math.sin(t * 9.0) + 0.4 * r.range(-1.0, 1.0);
    p.circle(x, y, r0 + 1.3, c[2]);
    p.circle(x, y, r0, c[4]);
    p.circle(x - 0.4, y - 0.4, r0 * 0.72, c[5]);
    for (var i = 0; i < 3; i++) {
      final a = t * (5.0 + i * 2.3) + i * 2.1;
      final d = r0 * 0.6;
      p.circle(
        x + math.cos(a) * d,
        y + math.sin(a) * d * 0.8,
        1.2,
        i != 0 ? c[6] : kWhite,
      );
    }
    p.circle(x - 0.6, y - 0.6, r0 * 0.32, kWhite);
    for (var i = 0; i < 8; i++) {
      if (r.next() < 0.35) continue;
      final a = (i / 8.0) * tau + t * 2.0 + r.range(-0.2, 0.2);
      final l = r.range(1.5, 4.0);
      p.line(
        x + math.cos(a) * (r0 + 1.0),
        y + math.sin(a) * (r0 + 1.0),
        x + math.cos(a) * (r0 + 1.0 + l),
        y + math.sin(a) * (r0 + 1.0 + l),
        i % 2 != 0 ? c[5] : c[4],
      );
    }
    p.glow(x, y, 30, c[4], 0.3);
    p.glow(x, y, 9, c[6], 0.1);

    for (var i = 0; i < 2 + (r.next() < 0.4 ? 1 : 0); i++) {
      final a = r.range(0.0, tau);
      final l = r.range(5.0, 11.0);
      final x0 = x + math.cos(a) * (r0 + 1.0);
      final y0 = y + math.sin(a) * (r0 + 1.0);
      final b = a + r.range(-0.7, 0.7);
      crackle(
        p,
        zigzag(r, x0, y0, x0 + math.cos(b) * l, y0 + math.sin(b) * l, 0.4, 0.3),
        r.range(0.4, 0.7),
        c,
        0.25,
      );
    }

    final za = f - _zapFrame;
    final (zx, _) = _at(_zapFrame / _fps);
    final gx = zx + rng(seed, 3).range(-10.0, 10.0);
    if (za >= 0 && za < 4) {
      final k = const [1.0, 0.6, 0.9, 0.4][za];
      boltStrokeWith(
        p,
        zigzag(rng(seed, 4, f), x, y + r0, gx, 0.0, 0.28, 0.4),
        k,
        c,
        s: 0.7,
        hero: za == 0,
      );
      p.circle(gx, -1, 2.5 * k + 1.0, c[5]);
      p.px(gx, -1, kWhite);
      p.glow(gx, -4, 34, c[4], 0.6 * k);
    }

    final sa = (((t - _zapFrame / _fps) % _period) + _period) % _period;
    for (var j = 0; j < 14; j++) {
      final q = rng(seed, 7, j);
      final life = q.range(0.25, 0.55);
      if (sa >= life) continue;
      final a = -math.pi / 2.0 + q.range(-1.3, 1.3);
      final sp = q.range(50.0, 170.0);
      final (sx, sy, vx, vy) = lightningFlight(
        gx,
        -1.0,
        math.cos(a) * sp,
        math.sin(a) * sp,
        sa,
        floor: 0.0,
      );
      lightningSpark(p, sx, sy, vx, vy, 1.0 - sa / life, s);
    }
  },
);
