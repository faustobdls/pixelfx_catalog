import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart' hide star;

import 'impacts_lib.dart';

final SimulatedEffect bulletImpactEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'impacts/bullet-impact',
    name: 'Bullet impact',
    desc:
        'A bullet hits a wall on the right: a hot half-star, sparks sprayed back in a cone, a puff of grit, chips that fall and bounce, a pock mark cooling to soot.',
    category: 'impacts',
    tags: [
      'impact',
      'bullet',
      'gun',
      'wall',
      'sparks',
      'debris',
      'directional',
      'one-shot',
    ],
    size: (152, 100),
    origin: (116, 84),
    duration: 1.4,
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
      'stone': '#5b5079',
      'height': 24,
      'seed': 6,
    },
  ),
  onCreate: (o) => _BulletImpactSim(o),
);

class _BulletImpactSim extends BaseEffectSim {
  static double _floor(double _) => 0.0;

  final List<int> c;
  final StonePalette st;
  final Rng r;
  final double x = 0.0;
  final double y;
  final double duration = 1.4;
  late final Particles ps;
  final Lights lights = Lights();
  late final List<ImpactSpike> sp;
  final List<(int, int, int)> rim = [];
  final List<(double, double, double, double)> cracks = [];
  double t = 0.0;

  static const double _n = math.pi;
  static const double _in = 0.08;
  static const double _b = math.pi - _in;

  static bool _open(double a) => math.cos(a - _n) > -0.25;

  _BulletImpactSim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        st = stone(o['stone'] ?? '#5b5079'),
        r = Rng(o.seed),
        y = -o.numOpt('height', 24.0) {
    ps = Particles(rng: r, ground: _floor, sparks: [c[6], c[5], c[4], c[2]]);
    sp = spikes(r, 9, _b, len: (7.0, 10.5), w: (1.6, 2.1), fwd: 1.8, back: 0.4);
    for (final s in sp) {
      if (math.cos(s.a - _n) < -0.2) s.len *= 0.3;
    }
    final seed = o.seed;
    for (var py = -2; py <= 2; py++) {
      for (var px = 0; px <= 3; px++) {
        final d = hypot((px - 1) / 1.6, py / 2.1) + rand(px, py, seed) * 0.35;
        if (d < 0.75) {
          rim.add((px, py, 0));
        } else if (d < 1.25) {
          rim.add((px, py, 1));
        }
      }
    }
    for (var i = 0; i < 3; i++) {
      final a = r.range(-1.2, 1.2);
      final l = r.range(2.0, 4.5);
      cracks.add((
        math.cos(a) * 2.2 + 1.0,
        math.sin(a) * 2.2,
        math.cos(a) * (2.2 + l) + 1.0,
        math.sin(a) * (2.2 + l),
      ));
    }

    lights.add(x - 4.0, y, 40.0, c[4], 0.6, 0.22);
    lights.add(x - 2.0, y, 14.0, kWhite, 0.6, 0.06);

    for (var i = 0; i < 18; i++) {
      final a = _b + r.range(-1.0, 1.0) * 0.8;
      final v = r.range(170.0, 450.0);
      ps.spawn(
        P.spark,
        x - 1.0,
        y,
        math.cos(a) * v,
        math.sin(a) * v - 30.0,
        r.range(0.12, 0.4),
        kWhite,
        1.0,
        i > 13 ? r.range(0.01, 0.04) : 0.0,
      );
    }
    for (var i = 0; i < 8; i++) {
      final a = _n + r.range(-0.8, 0.6);
      final v = r.range(60.0, 190.0);
      ps.spawn(
        P.grit,
        x - 1.0,
        y + r.range(-1.0, 1.0),
        math.cos(a) * v,
        math.sin(a) * v - r.range(20.0, 70.0),
        r.range(0.9, 1.3),
        r.pick([st.light, st.body, st.body, st.lip]),
        i < 3 ? 2.0 : 1.0,
      );
    }
    for (var i = 0; i < 9; i++) {
      final a = _n + r.range(-1.1, 1.1);
      final v = r.range(15.0, 60.0);
      ps.spawn(
        P.dust,
        x - 2.0,
        y + r.range(-1.5, 1.5),
        math.cos(a) * v,
        math.sin(a) * v,
        r.range(0.3, 0.55),
        r.chance(0.5) ? st.dust : mix(st.dust, kWhite, 0.25),
        r.range(1.2, 2.3),
      );
    }
    ps.spawn(
      P.smoke,
      x - 4.0,
      y,
      r.range(-10.0, -4.0),
      r.range(-16.0, -8.0),
      r.range(0.8, 1.2),
      st.dust,
      r.range(1.8, 2.4),
      0.05,
    );
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final heat = math.pow(clamp(1.0 - t / 0.9), 1.3).toDouble();
    final fade = 1.0 - smooth(duration - 0.45, duration - 0.1, t);
    if (fade > 0.0) {
      for (final (x0, y0, x1, y1) in cracks) {
        p.line(
          x + x0,
          y + y0,
          x + x1,
          y + y1,
          heat > 0.5 ? c[3] : st.shade,
          fade * (heat > 0.5 ? 1.0 : 0.85),
        );
      }
      for (final (rx, ry, k) in rim) {
        final h = heat * (k != 0 ? 0.85 : 1.15);
        p.dot(
          x + rx,
          y + ry,
          k == 0 && h < 0.75
              ? kSoot
              : (h > 0.85
                  ? kWhite
                  : (h > 0.6
                      ? c[5]
                      : (h > 0.4
                          ? c[4]
                          : (h > 0.22
                              ? c[3]
                              : (h > 0.1 ? c[2] : st.shade))))),
          fade,
        );
      }
      if (heat > 0.0) {
        p.glow(x + 1.0, y, 6.0 + 6.0 * heat, c[3], 0.5 * heat);
      }
    }

    final u = (t - 0.03) / 0.18;
    if (u >= 0.0 && u < 1.0) {
      final rad = 5.0 + 12.0 * Ease.outCubic(u);
      final col = u < 0.3 ? c[5] : (u < 0.6 ? c[4] : c[3]);
      final n = (rad * tau * 1.3).ceil();
      for (var j = 0; j < n; j++) {
        final g = (j / n) * tau;
        if (_open(g)) {
          p.dot(x + math.cos(g) * rad, y + math.sin(g) * rad, col, 1.15 - u);
        }
      }
    }

    ps.draw(p, 'front');
    if (t < 0.03) {
      star(p, x, y, sp, 1.0, 1.0, [c[2], c[5], c[4], kWhite], 1.0, 2.2);
    } else if (t < 0.06) {
      star(p, x, y, sp, 1.25, 0.55, [c[1], c[4], c[3], c[5]], 1.0, 2.2);
    }
    final pop = math.exp(-t / 0.045);
    if (pop > 0.02) {
      p.glow(x - 2.0, y, 22.0, c[3], 0.6 * pop);
      p.glow(x - 1.0, y, 8.0, kWhite, 0.5 * pop);
      p.glowLine(x + 1.0, y - 16.0, x + 1.0, y + 16.0, 4.0, c[4], 0.4 * pop);
    }
    lights.draw(p);
  }
}
