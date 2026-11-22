import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const _magicMissileMeta = EffectMeta(
  id: 'projectiles/magic-missile',
  name: 'Magic missile',
  desc:
      'Motes gather into an arcane orb at a hand `height` px above the floor (the origin); it weaves to its target trailing a twisting ribbon and bursts into a star of light.',
  category: 'projectiles',
  tags: [
    'projectile',
    'magic',
    'arcane',
    'missile',
    'spell',
    'directional',
    'one-shot',
  ],
  size: (208, 112),
  origin: (24, 104),
  duration: 1.9,
  loop: false,
  fps: 30,
  bg: BackdropKind.ground,
  defaultOptions: {
    'palette': [
      '#140a26',
      '#2b1252',
      '#481c88',
      '#6b2cc0',
      '#9a48ec',
      '#c684ff',
      '#ecc8ff',
      '#ffffff',
    ],
    'height': 26,
    'reach': 112,
    'seed': 6,
  },
);

const _charge = 0.2;
const _fly = 0.62;

final PixelEffect magicMissileEffect = SimulatedEffect(
  meta: _magicMissileMeta,
  onCreate: _MagicMissileSim.new,
);

class _TrailPt {
  const _TrailPt(this.x, this.y, this.t);

  final double x;
  final double y;
  final double t;
}

class _MagicMissileSim extends BaseEffectSim {
  _MagicMissileSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        h = o.numOpt('height', 26),
        x1 = o.numOpt('reach', 112),
        r = Rng(o.seed) {
    ps = Particles(
      rng: r,
      ground: (_) => 0,
      sparks: [kWhite, c[6], c[5], c[4]],
    );
    lights = Lights();
  }

  final List<int> c;
  final double h;
  final double x1;
  final Rng r;
  late final Particles ps;
  late final Lights lights;
  final List<_TrailPt> trail = [];
  double t = 0;
  bool burst = false;

  (double, double) _pos(double u) => (
        x1 * Ease.inOutSine(u) + math.sin(u * math.pi) * 6,
        -h + math.sin(u * tau * 1.5) * 9 * math.sin(u * math.pi),
      );

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t < _charge) {
      if (r.chance(0.8)) {
        final a = r.range(0, tau);
        final d = r.range(12, 26);
        final sp = d / 0.14;
        ps.spawn(
          P.mote,
          math.cos(a) * d,
          -h + math.sin(a) * d,
          -math.cos(a) * sp - math.sin(a) * sp * 0.5,
          -math.sin(a) * sp + math.cos(a) * sp * 0.5,
          0.14,
          r.pick([c[5], c[6], kWhite]),
          0.8,
        );
      }
    } else if (t < _charge + _fly) {
      final u = (t - _charge) / _fly;
      final (x, y) = _pos(u);
      trail.add(_TrailPt(x, y, t));
      if (r.chance(0.6)) {
        ps.spawn(
          P.mote,
          x,
          y,
          r.range(-50, 50),
          r.range(-50, 50),
          r.range(0.2, 0.4),
          r.pick([c[4], c[5], c[6]]),
          0.7,
        );
      }
      if (r.chance(0.25)) {
        ps.spawn(
          P.star,
          x + r.range(-3, 3),
          y + r.range(-3, 3),
          r.range(-10, 10),
          r.range(-10, 10),
          r.range(0.25, 0.5),
          c[6],
          r.range(0.6, 1.6),
        );
      }
    } else if (!burst) {
      burst = true;
      final y = -h;
      lights.add(x1, y, 52, c[4], 0.95, 0.55);
      lights.add(x1, y, 22, kWhite, 0.8, 0.12);
      for (var i = 0; i < 26; i++) {
        final a = r.range(0, tau);
        final sp = r.range(60, 150) * (1 - 0.65 * math.max(0.0, math.sin(a)));
        ps.spawn(
          i % 3 != 0 ? P.mote : P.star,
          x1,
          y,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.25, 0.45),
          r.pick([c[5], c[6], kWhite]),
          r.range(0.8, 1.8),
        );
      }
      for (var i = 0; i < 18; i++) {
        final a = r.range(0, tau);
        final sp = r.range(110, 240) * (1 - 0.5 * math.max(0.0, math.sin(a)));
        ps.spawn(
          P.spark,
          x1,
          y,
          math.cos(a) * sp,
          math.sin(a) * sp - 30,
          r.range(0.12, 0.3),
        );
      }
      for (var i = 0; i < 14; i++) {
        final a = r.range(0, tau);
        final d = r.range(4, 22);
        ps.spawn(
          P.star,
          x1 + math.cos(a) * d,
          y + math.sin(a) * d * 0.8,
          0,
          -r.range(2, 8),
          r.range(0.5, 1.1),
          r.pick([c[6], kWhite, c[5]]),
          r.range(0.8, 2.6),
          r.range(0.05, 0.45),
        );
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    final now = t;
    final keep = [
      for (final q in trail)
        if (now - q.t < 0.32) q,
    ];
    for (var i = 1; i < keep.length; i++) {
      final a = keep[i - 1];
      final b = keep[i];
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final l0 = hypot(dx, dy);
      final l = l0 == 0 ? 1.0 : l0;
      final nx = -dy / l;
      final ny = dx / l;
      for (var f = 0.0; f < 1; f += 0.5 / l) {
        final tt = a.t + (b.t - a.t) * f;
        final k = 1 - (now - tt) / 0.32;
        final tw = math.sin(tt * 26);
        final w = 3.2 * k * tw.abs() + 0.4;
        final face = tw > 0;
        final x = a.x + dx * f;
        final y = a.y + dy * f;
        for (var s = -w; s <= w; s += 0.5) {
          final edge = s.abs() > w - 0.8;
          final col = face
              ? (edge
                  ? c[6]
                  : k > 0.6
                      ? c[5]
                      : c[4])
              : (edge ? c[4] : c[2]);
          p.dot(x + nx * s, y + ny * s, col, k > 0.35 ? 1.0 : k / 0.35);
        }
      }
      if (i % 3 == 0) p.glow(b.x, b.y, 6, c[4], 0.25 * (1 - (now - b.t) / 0.32));
    }
    ps.draw(p);
    if (t < _charge + _fly) {
      final k = t < _charge ? t / _charge : 1.0;
      final (x, y) = t < _charge ? (0.0, -h) : _pos((t - _charge) / _fly);
      final rad = 1 + 3 * Ease.outBack(k);
      p.circle(x, y, rad + 1.4, c[3]);
      p.circle(x, y, rad + 0.4, c[5]);
      p.circle(x - 0.4, y - 0.4, rad * 0.55, kWhite);
      for (var i = 0; i < 3; i++) {
        final a = t * 14 + (i * tau) / 3;
        p.px(
          x + math.cos(a) * (rad + 3),
          y + math.sin(a) * (rad + 3) * 0.6,
          i != 0 ? c[6] : kWhite,
        );
      }
      p.glow(x, y, 20, c[4], 0.65 * k);
      p.glow(x, y, 7, c[6], 0.5 * k);
    }
    final q = t - _charge - _fly;
    if (q >= 0 && q < 0.5) {
      final e = q / 0.5;
      if (e < 0.5) {
        flare(p, x1, -h, 26 * math.pow(1 - e * 2, 1.2) + 2, 1 - e * 2, c);
      }
      if (e < 0.12) p.circle(x1, -h, 6 * (1 - e / 0.12) + 1, kWhite);
      p.ring(
        x1,
        -h,
        4 + 20 * Ease.outCubic(e),
        math.max(1.0, 2.5 * (1 - e)),
        e < 0.3 ? c[6] : c[5],
        math.min(1.0, (1 - e) * 1.5),
      );
      if (e < 0.4) {
        sparkle(p, x1, -h, 7 * (1 - e / 0.4), c[6], c[4], 0.6 * (1 - e / 0.4));
      }
    }
    lights.draw(p);
  }
}
