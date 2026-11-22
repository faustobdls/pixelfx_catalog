// The slanted streaks landing with a ring and a kick of bits follow Sprite Fusion's open-source rain
// (https://www.spritefusion.com/pixel-art-vfx/rain), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const int _n = 11;
const double _spread = 46.0;
const double _h = 124.0;
const double _slant = 0.38;
const double _trail = 0.17;

class _Star {
  final double x;
  final double y;
  final double sx;
  final double sy;
  final double t0;
  final double dur;
  bool landed = false;
  final bool big;
  final double ph;

  _Star({
    required this.x,
    required this.y,
    required this.sx,
    required this.sy,
    required this.t0,
    required this.dur,
    required this.big,
    required this.ph,
  });
}

class _Hit {
  final double x;
  final double y;
  final double t;
  final bool big;

  const _Hit(this.x, this.y, this.t, this.big);
}

class _StarFallSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  late final List<_Star> stars;
  final List<_Hit> hits = [];
  double t = 0.0;

  _StarFallSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed) {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [kWhite, c[6], c[5], c[4]],
    );
    final xs = List.generate(
      _n,
      (i) => -_spread + ((i + r.range(0.2, 0.8)) * 2.0 * _spread) / _n,
      growable: false,
    );
    for (var i = _n - 1; i > 0; i--) {
      final j = r.intRange(0, i);
      final tmp = xs[i];
      xs[i] = xs[j];
      xs[j] = tmp;
    }
    stars = List.generate(_n, (i) {
      final x = xs[i];
      final y = r.range(-3.0, 2.0);
      final h = _h * r.range(0.85, 1.0);
      return _Star(
        x: x,
        y: y,
        sx: x - h * _slant,
        sy: y - h,
        t0: 0.04 + i * 0.105 + r.range(0.0, 0.05),
        dur: r.range(0.3, 0.4),
        big: r.chance(0.35),
        ph: r.range(0.0, tau),
      );
    }, growable: false);
  }

  (double x, double y, double q) _at(_Star s, double tt) {
    final q = clamp((tt - s.t0) / s.dur);
    final e = q * (0.35 + 0.65 * q);
    return (s.sx + (s.x - s.sx) * e, s.sy + (s.y - s.sy) * e, q);
  }

  double _star(Painter p, _Star s) {
    final (x, y, q) = _at(s, t);
    const n = 20;
    for (var k = n; k >= 1; k--) {
      final (ax, ay, _) = _at(s, t - (k * _trail) / n);
      final (bx, by, _) = _at(s, t - ((k - 1) * _trail) / n);
      final u = k / n;
      if (t - (k * _trail) / n < s.t0) continue;
      final col = u < 0.15
          ? kWhite
          : u < 0.4
              ? c[6]
              : u < 0.7
                  ? c[5]
                  : c[4];
      if (u < (s.big ? 0.55 : 0.35)) {
        p.line(ax + 1.0, ay, bx + 1.0, by, u < 0.2 ? c[6] : c[5],
            1.1 - u * 1.4);
      }
      p.line(ax, ay, bx, by, col, 1.3 - u);
      if (k % 3 == 0) {
        p.glow(ax, ay, 7.0 * (1.0 - u) + 2.0, c[5], 0.3 * (1.0 - u));
      }
    }
    if (s.big) {
      flare(p, x, y, 7.0 + 1.5 * math.sin(t * 40.0 + s.ph), 0.8, c);
    } else {
      sparkle(
          p, x, y, 3.5 + math.sin(t * 40.0 + s.ph), c[6], c[5], 0.6);
    }
    p.circle(x, y, s.big ? 1.6 : 1.1, kWhite);
    p.glow(x, y, s.big ? 18 : 13, c[5], 0.6);
    p.glow(x, y, 5, kWhite, 0.35);
    return q;
  }

  void _hit(Painter p, _Hit h, bool far) {
    final k = (t - h.t) / 0.45;
    if (k < 0.0 || k >= 1.0) return;
    band(
      p,
      h.x,
      h.y,
      3.0 + (h.big ? 22.0 : 16.0) * Ease.outCubic(k),
      0.26,
      math.max(1.0, 2.5 * (1.0 - k)),
      1.15 - k,
      [c[3], c[5], c[6], kWhite],
      keep: (g) => (math.sin(g) < 0.0) == far,
      hot: k < 0.2,
    );
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    for (final s in stars) {
      if (t < s.t0 || s.landed) continue;
      final (x, y, q) = _at(s, t);
      if (r.chance(0.55)) {
        ps.spawn(
          P.star,
          x + r.range(-1.5, 1.5),
          y + r.range(-1.5, 1.5),
          r.range(-12.0, 12.0),
          r.range(-8.0, 4.0),
          r.range(0.35, 0.7),
          r.pick([kWhite, c[6], c[5]]),
          r.chance(0.7) ? r.range(0.4, 0.9) : r.range(1.2, 1.8),
        );
      }
      if (q >= 1.0) {
        s.landed = true;
        hits.add(_Hit(s.x, s.y, t, s.big));
        lights.add(s.x, s.y - 12.0, s.big ? 46 : 38, c[5], 0.9, 0.32);
        lights.add(s.x, s.y - 3.0, 16, kWhite, 0.8, 0.08);
        for (var i = 0; i < (s.big ? 14 : 9); i++) {
          final a = -math.pi / 2.0 + r.range(-1.35, 1.35);
          final sp = r.range(50.0, 150.0);
          ps.spawn(
            P.spark,
            s.x,
            math.min(-1.0, s.y - 1.0),
            math.cos(a) * sp,
            math.sin(a) * sp,
            r.range(0.2, 0.5),
          );
        }
        for (var i = 0; i < 4; i++) {
          ps.spawn(
            P.star,
            s.x + r.range(-4.0, 4.0),
            s.y - r.range(2.0, 8.0),
            r.range(-15.0, 15.0),
            -r.range(10.0, 35.0),
            r.range(0.4, 0.8),
            r.pick([kWhite, c[6]]),
            r.range(0.8, 2.0),
          );
        }
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final k = clamp(t / 0.3) * (1.0 - clamp((t - 1.7) / 0.7));
    if (k > 0.0) {
      for (final x in const [-36.0, 0.0, 36.0]) {
        p.glow(x, -1, 40, c[4], 0.14 * k);
      }
    }
    for (final h in hits) {
      _hit(p, h, true);
    }
    for (final h in hits) {
      final k2 = 1.0 - (t - h.t) / 0.7;
      if (k2 <= 0.0) continue;
      p.dot(h.x, h.y, k2 > 0.6 ? kWhite : c[6], k2 * 1.5);
      for (final dx in const [-1.0, 1.0]) {
        p.dot(h.x + dx, h.y, c[5], k2 * 1.2);
      }
      p.glow(h.x, h.y - 1.0, 10, c[5], 0.35 * k2);
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    for (final s in stars) {
      if (t >= s.t0 && !s.landed) _star(p, s);
    }
    for (final h in hits) {
      _hit(p, h, false);
      final k = (t - h.t) / 0.22;
      if (k < 0.0 || k >= 1.0) continue;
      if (k < 0.35) {
        p.circle(h.x, h.y - 2.0, 5.0 * (1.0 - k / 0.35) + 1.0, kWhite);
      }
      flare(
        p,
        h.x,
        h.y - 2.0,
        (h.big ? 16.0 : 12.0) * math.pow(1.0 - k, 1.5) + 2.0,
        1.0 - k,
        c,
      );
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect starFallEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'arcane/star-fall',
    name: 'Star fall',
    desc:
        'Stars streak down on long trails across an area, each landing with a white flash, a ring across the floor and a kick of sparks.',
    category: 'arcane',
    tags: ['arcane', 'star', 'meteor', 'rain', 'aoe', 'magic', 'ground', 'one-shot'],
    size: (232, 172),
    origin: (124, 150),
    duration: 2.5,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {'palette': Pal.arcane, 'seed': 13},
  ),
  onCreate: (o) => _StarFallSim(o),
);
