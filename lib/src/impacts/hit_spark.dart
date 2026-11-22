// The two-tone spark spray and the light pop are adapted from Sprite Fusion's open-source impact
// (https://www.spritefusion.com/pixel-art-vfx/impact), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

void _ray(
  Painter p,
  double x,
  double y,
  double a,
  double len,
  double w,
  List<int> c, [
  double from = 0.0,
]) {
  final cs = math.cos(a);
  final sn = math.sin(a);
  for (var d = from * len; d <= len; d += 0.5) {
    final u = d / len;
    final hw = w * math.pow(1.0 - u, 1.6);
    final col = u < 0.3
        ? kWhite
        : u < 0.62
            ? c[5]
            : u < 0.88
                ? c[4]
                : c[3];
    p.px(x + cs * d, y + sn * d, col);
    if (hw > 0.45) {
      for (var o = 0.5; o <= hw; o += 0.5) {
        for (final e in [-o, o]) {
          p.px(
            x + cs * d - sn * e,
            y + sn * d + cs * e,
            u < 0.3 && o < 1.0 ? c[5] : c[4],
          );
        }
      }
    }
  }
}

void _diamond(Painter p, double x, double y, int r, List<int> c) {
  for (var dy = -r - 1; dy <= r + 1; dy++) {
    for (var dx = -r - 1; dx <= r + 1; dx++) {
      final m = dx.abs() + dy.abs();
      if (m <= r) {
        p.px(x + dx, y + dy, kWhite);
      } else if (m == r + 1) {
        p.px(x + dx, y + dy, c[3]);
      }
    }
  }
}

typedef _RaySpec = ({double a, double l, double w});

class _HitSparkSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final double x = 0.0;
  late final double y;
  late final double a;
  late final Particles ps;
  final Lights lights = Lights();
  late final List<_RaySpec> rays;
  double t = 0.0;

  _HitSparkSim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        r = Rng(o.seed) {
    y = -o.numOpt('height', 20.0);
    a = o.numOpt('aim', 0.1);
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [c[6], c[5], c[4], c[2]],
    );
    final tilt = r.range(-0.08, 0.08);
    rays = [
      (a: a + tilt, l: r.range(33.0, 37.0), w: 2.2),
      (a: a + math.pi + tilt, l: r.range(8.0, 10.0), w: 2.2),
      (a: a - math.pi / 2.0 + tilt, l: r.range(15.0, 18.0), w: 2.6),
      (a: a + math.pi / 2.0 + tilt, l: r.range(10.0, 12.0), w: 2.3),
      (a: a - math.pi / 4.0 + tilt, l: r.range(5.0, 7.0), w: 1.0),
    ];

    lights.add(x, y, 38.0, c[4], 0.35, 0.18);
    lights.add(
      x + math.cos(a) * 10.0,
      y + math.sin(a) * 10.0,
      22.0,
      c[5],
      0.45,
      0.1,
    );
    lights.add(x, -2.0, 26.0, c[3], 0.22, 0.22);

    for (var i = 0; i < 9; i++) {
      final ang = a + r.range(-0.6, 0.6) - 0.15;
      final v = r.range(170.0, 360.0);
      ps.spawn(
        P.spark,
        x + 1.0,
        y,
        math.cos(ang) * v,
        math.sin(ang) * v - 40.0,
        r.range(0.25, 0.45),
        kWhite,
        1.0,
        i > 6 ? r.range(0.01, 0.03) : 0.0,
      );
    }
    for (var i = 0; i < 6; i++) {
      final ang = a + r.range(-1.1, 0.5) - 0.3;
      final v = r.range(70.0, 170.0);
      final vx = math.cos(ang) * v;
      final vy = math.sin(ang) * v - r.range(30.0, 80.0);
      final life = r.range(0.35, 0.45);
      final col = r.pick([c[5], c[4], c[4], c[3]]);
      ps.spawn(P.grit, x + 1.0, y, vx, vy, life, col, 1.0);
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    ps.draw(p);
    if (t < 0.025) {
      for (final raySpec in rays) {
        _ray(p, x, y, raySpec.a, raySpec.l, raySpec.w, c);
      }
      _diamond(p, x, y, 4, c);
    } else if (t < 0.058) {
      for (final raySpec in rays) {
        _ray(p, x, y, raySpec.a, raySpec.l * 1.2, raySpec.w * 0.55, c, 0.12);
      }
      _diamond(p, x, y, 3, c);
    } else if (t < 0.092) {
      final r0 = rays[0];
      _ray(
        p,
        x,
        y,
        r0.a,
        r0.l * 1.3,
        0.6,
        [c[0], c[1], c[2], c[3], c[3], c[4]],
        0.4,
      );
    }
    final pop = math.exp(-t / 0.045);
    if (pop > 0.02) {
      p.glow(x, y, 22.0, c[4], 0.3 * pop);
      p.glow(x, y, 7.0, kWhite, 0.15 * pop);
      p.glowLine(
        x,
        y,
        x + math.cos(a) * 26.0,
        y + math.sin(a) * 26.0,
        4.0,
        c[5],
        0.25 * pop,
      );
    }
    lights.draw(p);
  }
}

final SimulatedEffect hitSparkEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'impacts/hit-spark',
    name: 'Hit spark',
    desc:
        'The everyday hit: a sharp, lopsided cross flare with one long ray along the blow round a white diamond core, then a cone of sparks and hot chips that fall and bounce.',
    category: 'impacts',
    tags: ['impact', 'hit', 'spark', 'combat', 'directional', 'one-shot'],
    size: (136, 80),
    origin: (44, 64),
    duration: 0.5,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#4a1712',
        '#c9281f',
        '#f2561d',
        '#ff8a2a',
        '#ffe26b',
        '#fff3a6',
        '#ffffff',
      ],
      'height': 20,
      'aim': 0.1,
      'seed': 4,
    },
  ),
  onCreate: (o) => _HitSparkSim(o),
);
