// The release (flash, rings, flare, light) and the arcs are adapted from Sprite Fusion's open-source energy
// (https://www.spritefusion.com/pixel-art-vfx/energy), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'explosions_lib.dart';

const double _ball = 0.55;

class _PlasmaExplosionSim extends BaseEffectSim {
  final EffectMeta meta;
  final List<int> c, v;
  final int seed;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  double t = 0.0;

  _PlasmaExplosionSim(this.meta, Map<String, Object?> o)
      : c = fit(o.palette, 7),
        v = fit(
          (o['accent'] as List<Object?>?)?.cast<Object>() ??
              const ['#1c0a30', '#4a1a8c', '#8a3ce0', '#c48cff', '#f0d8ff'],
          5,
        ),
        seed = o.seed,
        r = Rng(o.seed) {
    ps = Particles(rng: r, sparks: [c[6], c[5], c[4], v[3]]);
    lights.add(0, 0, 96, c[4], 1.0, 0.6);
    lights.add(0, 0, 40, kWhite, 0.9, 0.1);
    lights.add(0, 0, 70, v[2], 0.5, 1.1);
    for (var i = 0; i < 46; i++) {
      final a = r.range(0, tau);
      final sp = r.range(140, 360);
      ps.spawn(
        P.mote,
        math.cos(a) * 4.0,
        math.sin(a) * 4.0,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(0.2, 0.42),
        r.pick([c[6], c[5], c[4], v[3]]),
        r.range(0.7, 1.1),
      );
    }
    for (var i = 0; i < 26; i++) {
      final a = r.range(0, tau);
      final sp = r.range(40, 140);
      ps.spawn(
        P.flake,
        math.cos(a) * 10.0,
        math.sin(a) * 10.0,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(0.8, 1.5),
        r.pick([c[5], v[3], v[4]]),
        r.range(0.6, 1.6),
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (t > 0.12 && t < 0.9 && r.chance(30.0 * dt)) {
      final a = r.range(0, tau);
      final rad = _shell(t);
      ps.spawn(
        P.star,
        math.cos(a) * rad,
        math.sin(a) * rad,
        math.cos(a) * r.range(10, 40),
        math.sin(a) * r.range(10, 40),
        r.range(0.3, 0.6),
        r.chance(0.5) ? c[5] : v[4],
        r.range(0.5, 1.8),
      );
    }
    ps.update(dt);
    cullParticles(
      ps,
      -meta.origin.$1 + 3.0,
      -meta.origin.$2 + 3.0,
      meta.size.$1 - meta.origin.$1 - 3.0,
      meta.size.$2 - meta.origin.$2 - 3.0,
    );
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    _tilted(p, t, c, v, true);
  }

  @override
  void draw(Painter p) {
    if (t < _ball) {
      final u = t / _ball;
      final rVal = _shell(t);
      final hollow = smooth(0.35, 1.0, u);
      final boil = (t * 20.0).floor();
      p.shade(-rVal - 3, -rVal - 3, rVal + 3, rVal + 3, (x, y, out) {
        final d = hypot(x, y);
        final a = math.atan2(y, x);
        final edge = rVal * (1.0 + 0.1 * noise(a * 3.0 + boil * 0.7, 3));
        if (d > edge) return null;
        final val = d / edge;
        if (val < hollow * 0.92) return null;
        final n = noise(a * 4.0 + d * 0.25 + boil * 0.5, 5);
        final w = val + n * 0.14;
        final fil =
            math.sin(a * 5.0 + d * 0.32 - t * 14.0 + n * 2.5).abs() < 0.1;
        out.k = 0.25 * (1.0 - u);
        if (val > 0.9) return v[2];
        if (fil && val > 0.3) return u < 0.5 ? kWhite : c[5];
        return w < 0.32 - u * 0.25
            ? kWhite
            : (w < 0.52
                ? c[5]
                : (w < 0.72
                    ? c[4]
                    : (w < 0.86 ? (u < 0.5 ? c[3] : v[3]) : v[2])));
      });
      p.glow(0, 0, rVal * 1.6 + 6.0, c[4], 0.6 * (1.0 - u));
    }
    if (t < 0.07) p.circle(0, 0, 9.0 - t * 60.0, kWhite);
    if (t < 0.25) {
      flare(p, 0, 0, 52.0 * math.pow(1.0 - t / 0.25, 1.3).toDouble(),
          1.0 - t / 0.25, c);
    }
    final u1 = t / 0.42;
    if (u1 < 1.0) {
      p.ring(0, 0, 8.0 + 84.0 * Ease.outCubic(u1),
          math.max(1.0, 3.0 * (1.0 - u1)), u1 < 0.25 ? kWhite : c[5], 1.15 - u1);
      p.glowRing(0, 0, 8.0 + 84.0 * Ease.outCubic(u1), 5, c[4], 0.35 * (1.0 - u1));
    }
    final u2 = (t - 0.06) / 0.6;
    if (u2 > 0.0 && u2 < 1.0) {
      p.ring(0, 0, 6.0 + 60.0 * Ease.outCubic(u2),
          math.max(1.0, 2.0 * (1.0 - u2)), v[3], 1.1 - u2);
    }
    final left = 1.0 - smooth(0.15, 0.85, t);
    final strike = (t * 18.0).floor();
    if (left > 0.0) {
      final rr = rng(seed, strike, 17);
      final n = 2 + (4.0 * left + 0.5).floor();
      for (var i = 0; i < n; i++) {
        final a = rr.range(0, tau);
        final l = rr.range(26, 58) * (0.45 + 0.55 * left);
        final path = bolt(rr, 0, 0, math.cos(a) * l, math.sin(a) * l,
            jag: 0.28, depth: 4);
        _arc(p, path, c, v, 0.8 * left);
        if (rr.chance(0.5)) {
          for (final fk in forks(rr, path, count: 1, len: 14.0, jag: 0.35)) {
            _arc(p, fk, c, v, 0.5 * left);
          }
        }
      }
      final rs = _shell(t);
      for (var i = 0; i < 3; i++) {
        final a = rr.range(0, tau);
        final b = a + rr.range(0.3, 0.6);
        _arc(
          p,
          bolt(
            rr,
            math.cos(a) * rs,
            math.sin(a) * rs,
            math.cos(b) * rs,
            math.sin(b) * rs,
            jag: 0.4,
            depth: 3,
          ),
          c,
          v,
          0.6 * left,
        );
      }
    }
    _tilted(p, t, c, v, false);
    ps.draw(p);
    lights.draw(p);
  }
}

double _shell(double t) => 5.0 + 30.0 * Ease.outCubic(clamp(t / _ball));

void _tilted(Painter p, double t, List<int> c, List<int> v, bool back) {
  final u = (t - 0.03) / 0.5;
  if (u <= 0.0 || u >= 1.0) return;
  band(
    p,
    0,
    4,
    12.0 + 86.0 * Ease.outCubic(u),
    0.28,
    math.max(1.0, 4.0 * (1.0 - u)),
    1.15 - u,
    [v[1], v[2], c[4], c[5]],
    keep: (g) => (math.sin(g) < 0.0) == back,
    hot: u < 0.15,
  );
}

void _arc(
    Painter p, List<Point2> path, List<int> c, List<int> v, double k) {
  if (k <= 0.05) return;
  for (var i = 1; i < path.length; i++) {
    final (ax, ay) = path[i - 1];
    final (bx, by) = path[i];
    p.glowLine(ax, ay, bx, by, 5, v[2], 0.18 * k);
    p.line(ax + 1.0, ay, bx + 1.0, by, c[4], k * 0.8);
    p.line(ax, ay, bx, by, i < path.length * 0.6 ? kWhite : c[5],
        math.min(1.0, k * 1.4));
  }
}

const EffectMeta _plasmaExplosionMeta = EffectMeta(
  id: 'explosions/plasma-explosion',
  name: 'Plasma explosion',
  desc:
      'A blue-violet energy blast with no smoke: a white flash, a ball of plasma swelling into a thinning shell, shock rings in and out of depth, lightning arcs crackling off it.',
  category: 'explosions',
  tags: [
    'explosion',
    'plasma',
    'energy',
    'electric',
    'magic',
    'sci-fi',
    'one-shot',
  ],
  size: (224, 200),
  origin: (112, 100),
  duration: 1.7,
  loop: false,
  fps: 30,
  bg: BackdropKind.dark,
  defaultOptions: {
    'palette': [
      '#0a0828',
      '#1a1c6e',
      '#2c3cc0',
      '#4a7cf0',
      '#7cc0ff',
      '#c8ecff',
      '#ffffff',
    ],
    'accent': ['#1c0a30', '#4a1a8c', '#8a3ce0', '#c48cff', '#f0d8ff'],
    'seed': 7,
  },
);

final SimulatedEffect plasmaExplosionEffect = SimulatedEffect(
  meta: _plasmaExplosionMeta,
  onCreate: (o) => _PlasmaExplosionSim(_plasmaExplosionMeta, o),
);
