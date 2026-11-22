// The arc's halo-body-core inking, its flicker and the light that strobes as it dies follow Sprite Fusion's
// open-source lightning (https://www.spritefusion.com/pixel-art-vfx/lightning), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'lightning_lib.dart';

const double _snap = 0.05;
final int _ash = hex('#6a6680');

class _FernBranch {
  final List<(double x, double y, double d)> pts;
  final double w;
  const _FernBranch(this.pts, this.w);
}

List<_FernBranch> _fern(Rng r) {
  final out = <_FernBranch>[];
  void grow(
    double x,
    double y,
    double a,
    double len,
    double w,
    double d,
    int depth,
  ) {
    final pts = <(double, double, double)>[(x, y, d)];
    var side = r.sign();
    for (var s = 0.0; s < len; s += 1.4) {
      a += r.range(-0.3, 0.3);
      x += math.cos(a) * 1.4;
      y += math.sin(a) * 1.4;
      d += 1.4;
      pts.add((x, y, d));
      if (depth < 2 && s > 2.0 && r.chance(0.24)) {
        side = -side;
        grow(
          x,
          y,
          a + side * r.range(0.55, 1.05),
          (len - s) * r.range(0.3, 0.55),
          w * 0.6,
          d,
          depth + 1,
        );
      }
    }
    out.add(_FernBranch(pts, w));
  }

  for (var i = 0; i < 6; i++) {
    grow(
      0.0,
      0.0,
      (i / 6.0) * tau + r.range(-0.35, 0.35),
      r.range(18.0, 32.0),
      1.0,
      0.0,
      0,
    );
  }
  return out;
}

class _KinkedSpark {
  double x = 0.0;
  double y = 0.0;
  double vx;
  double vy;
  final double life;
  double age = -_snap;
  double next;
  final List<Point2> trail = [];

  _KinkedSpark(this.vx, this.vy, this.life, this.next);
}

class _ZapHitSim extends BaseEffectSim {
  final List<int> c;
  final int seed;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  late final List<_FernBranch> tree;
  late final double y0;
  late final List<_KinkedSpark> kinked;
  double t = 0.0;
  bool hit = false;

  _ZapHitSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        seed = o.seed,
        r = Rng(o.seed) {
    ps = Particles(rng: r);
    tree = _fern(r);
    y0 = r.range(-14.0, 6.0);
    kinked = List.generate(16, (_) {
      final a = r.range(-1.2, 1.2) + (r.chance(0.7) ? 0.0 : math.pi);
      final sp = r.range(130.0, 250.0);
      return _KinkedSpark(
        math.cos(a) * sp,
        math.sin(a) * sp - 40.0,
        r.range(0.2, 0.36),
        r.range(0.02, 0.05),
      );
    });
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (!hit && t >= _snap) {
      hit = true;
      lights.add(0, 0, 60, c[4], 0.7, 0.3);
      lights.add(0, 0, 14, kWhite, 0.5, 0.07);
      for (var i = 0; i < 3; i++) {
        ps.spawn(
          P.smoke,
          r.range(-3.0, 5.0),
          r.range(-4.0, 2.0),
          r.range(-5.0, 8.0),
          -r.range(8.0, 16.0),
          r.range(0.55, 0.75),
          mix(_ash, c[4], 0.3),
          r.range(2.5, 3.8),
          r.range(0.08, 0.16),
        );
      }
    }
    for (final s in kinked) {
      s.age += dt;
      if (s.age < 0.0 || s.age >= s.life) continue;
      s.next -= dt;
      if (s.next <= 0.0) {
        s.next = r.range(0.025, 0.055);
        final sp = hypot(s.vx, s.vy);
        final a = math.atan2(s.vy, s.vx) + r.sign() * r.range(0.6, 1.3);
        s.vx = math.cos(a) * sp;
        s.vy = math.sin(a) * sp;
        s.trail.add((s.x, s.y));
        if (s.trail.length > 4) s.trail.removeAt(0);
      }
      s.vx -= s.vx * 3.0 * dt;
      s.vy -= s.vy * 3.0 * dt - 140.0 * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    if (t < _snap) return;
    final cool = smooth(0.45, 0.85, t);
    final fade = 1.0 - smooth(0.78, 0.88, t);
    for (final br in tree) {
      for (var i = 1; i < br.pts.length; i++) {
        final (x0, y0, _) = br.pts[i - 1];
        final (x, y, d) = br.pts[i];
        final age = t - _snap - d / 260.0;
        if (age < 0.0) break;
        final k = math.exp(-age / 0.22) - cool * 0.3;
        final col = k > 0.75
            ? kWhite
            : (k > 0.45
                ? c[6]
                : (k > 0.25
                    ? c[5]
                    : (k > 0.1 ? c[4] : (k > -0.05 ? c[2] : c[1]))));
        p.line(x0, y0, x, y, col, fade);
        if (br.w >= 1.0 && d < 9.0) {
          p.line(x0 + 1.0, y0, x + 1.0, y, k > 0.45 ? c[5] : c[2], fade);
        }
        if ((i & 3) == 0 && k > 0.0) p.glow(x, y, 5, c[5], 0.35 * k * fade);
      }
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final f = (t * 30.0 + 1e-4).floor();
    if (t < 0.32) {
      final rr = rng(seed, 2, f);
      final b = zigzag(rr, -66.0, y0, 0.0, 0.0, 0.22, 0.35);
      final u = clamp(t / _snap);
      final k = t < _snap
          ? 1.0
          : (t < 0.2
              ? (f % 2 != 0 ? 0.7 : 1.0)
              : 0.55 * (1.0 - (t - 0.2) / 0.12));
      boltStrokeWith(
        p,
        u < 1.0 ? BoltTree([b.paths[0]]) : b,
        k,
        c,
        s: t < _snap + 0.034 ? 0.95 : 0.7,
        upTo: u,
        hero: t >= _snap && t < _snap + 0.034,
      );
      if (u < 1.0) {
        final tp = b.paths[0].pts;
        final (hx, hy) = tp[(u * (tp.length - 1)).floor()];
        p.circle(hx, hy, 2, kWhite);
        p.glow(hx, hy, 14, c[5], 0.6);
      }
    }
    if (t >= _snap && t < 0.45) {
      final a = (t - _snap) / 0.4;
      final rr = rng(seed, 5, f);
      final r0 = 8.0 * (1.0 - a * 0.6);
      final m = jsRound(11.0 * (1.0 - a * 0.5));
      for (var i = 0; i < m; i++) {
        final ang = rr.range(0.0, tau);
        final d0 = rr.range(0.5, r0 * 0.5);
        final ang2 = ang + rr.range(-1.2, 1.2);
        final d1 = rr.range(r0 * 0.55, r0);
        crackle(
          p,
          zigzag(
            rr,
            math.cos(ang) * d0,
            math.sin(ang) * d0,
            math.cos(ang2) * d1,
            math.sin(ang2) * d1,
            0.5,
            0.0,
          ),
          0.75 * (1.0 - a) + 0.25,
          c,
          0.25,
        );
      }
      p.circle(0, 0, 3.0 * (1.0 - a) + 1.0, c[5]);
      p.circle(0, 0, 2.0 * (1.0 - a) + 0.5, kWhite);
      p.glow(0, 0, 20, c[4], 0.55 * (1.0 - a));
      if (t < _snap + 0.07) p.glow(0, 0, 9, kWhite, 0.4);
    }
    for (final s in kinked) {
      if (s.age < 0.0 || s.age >= s.life) continue;
      final k = 1.0 - s.age / s.life;
      final path = [...s.trail, (s.x, s.y)];
      for (var i = 0; i < path.length - 1; i++) {
        p.line(
          path[i].$1,
          path[i].$2,
          path[i + 1].$1,
          path[i + 1].$2,
          i == path.length - 2
              ? (k > 0.5 ? kWhite : c[6])
              : (k > 0.5 ? c[5] : c[4]),
          0.6 + 0.4 * (i / path.length),
        );
      }
      p.px(s.x, s.y, k > 0.4 ? kWhite : c[5]);
      p.glow(s.x, s.y, 4, c[5], 0.4 * k);
    }
    if (t >= _snap) {
      p.glow(
        0,
        0,
        40.0 * math.max(0.0, 1.0 - t / 0.85),
        c[3],
        0.45 * math.exp(-(t - _snap) * 5.0) * (f % 2 != 0 ? 0.7 : 1.0),
      );
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect zapHitEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'lightning/zap-hit',
    name: 'Zap hit',
    desc:
        'A contact zap: an arc snaps in from the left, the hit point overloads into a knot of tiny crackling zigzags, a fern of burn marks glows outward, sparks jink away, ozone puffs.',
    category: 'lightning',
    tags: [
      'lightning',
      'electric',
      'hit',
      'impact',
      'combat',
      'directional',
      'one-shot',
    ],
    size: (144, 112),
    origin: (76, 56),
    duration: 0.9,
    loop: false,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': voltPalette,
      'seed': 3,
    },
  ),
  onCreate: (o) => _ZapHitSim(o),
);
