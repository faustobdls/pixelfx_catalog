// The gathering streaks, the pulse rings and the release (cross flare, rings, light) are adapted from Sprite Fusion's
// open-source energy charge (https://www.spritefusion.com/pixel-art-vfx/energy), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'explosions_lib.dart';

const double _suck = 0.8;
const double _still = 1.02;
final int _voidColor = hex('#05040a');

class _GritMote {
  final double a, d, t0, duration, spin;
  final int c;
  const _GritMote(this.a, this.d, this.t0, this.duration, this.spin, this.c);
}

class _ImplosionSim extends BaseEffectSim {
  final EffectMeta meta;
  final List<int> c;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  late final List<_GritMote> grit;
  late final List<double> rays;
  double t = 0.0;
  bool popped = false;

  _ImplosionSim(this.meta, Map<String, Object?> o)
      : c = fit(o.palette, 7),
        r = Rng(o.seed) {
    ps = Particles(rng: r, sparks: [c[6], c[5], c[4], c[3]]);
    grit = List.generate(70, (_) {
      final t0 = r.range(0, 0.4);
      return _GritMote(
        r.range(0, tau),
        r.range(40, 86),
        t0,
        r.range(0.3, _suck - 0.04 - t0),
        r.sign() * r.range(0.6, 1.6),
        r.pick([c[2], c[3], c[4], hex('#4a4458'), hex('#6e6880')]),
      );
    }, growable: false);
    rays = List.generate(4, (i) => (i * tau) / 4.0 + math.pi / 4.0,
        growable: false);
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (t < _suck - 0.26) {
      final k = t / _suck;
      final count = 1 + (k * 4.0).floor();
      for (var n = 0; n < count; n++) {
        if (!r.chance(0.9)) continue;
        final a = r.range(0, tau);
        final d = r.range(34, 82) * (1.0 - 0.3 * k);
        final duration = r.range(0.14, 0.24);
        final v = (d * 3.0) / (math.exp(3.0 * duration) - 1.0);
        ps.spawn(
          P.streak,
          math.cos(a) * d,
          math.sin(a) * d,
          -math.cos(a) * v,
          -math.sin(a) * v,
          duration,
          r.chance(0.5) ? c[5] : c[4],
        );
      }
      if (r.chance(14.0 * dt)) {
        final a = r.range(0, tau);
        final d = r.range(50, 80);
        ps.spawn(
          P.vapour,
          math.cos(a) * d,
          math.sin(a) * d,
          -math.cos(a) * 90.0,
          -math.sin(a) * 90.0,
          r.range(0.4, 0.6),
          c[3],
          r.range(3, 5),
        );
      }
    }
    if (!popped && t >= _still) {
      popped = true;
      lights.add(0, 0, 90, c[4], 1.0, 0.4);
      lights.add(0, 0, 30, kWhite, 0.9, 0.08);
      for (var i = 0; i < 34; i++) {
        final a = r.range(0, tau);
        final sp = r.range(120, 330);
        ps.spawn(
          r.chance(0.6) ? P.mote : P.star,
          0,
          0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.2, 0.45),
          r.pick([c[6], c[5], c[4]]),
          r.range(0.8, 1.8),
        );
      }
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
  void draw(Painter p) {
    final k = clamp(t / _suck);
    if (t < _still) {
      final vr = 64.0 * (1.0 - Ease.inCubic(k)) + 3.0;
      if (k < 1.0) {
        p.disc(0, 0, vr, _voidColor, 0.35 + 0.35 * k);
        p.ring(0, 0, vr + 1.0, 1, k < 0.5 ? c[3] : c[4], 0.5 + 0.5 * k);
        p.glowRing(0, 0, vr, 5, c[4], 0.18 + 0.3 * k);
      }
      for (var i = 0; i < 4; i++) {
        final u = (t - i * 0.17) / 0.34;
        if (u <= 0.0 || u >= 1.0) continue;
        final rVal = (70.0 - i * 8.0) * (1.0 - Ease.inQuad(u)) + 2.0;
        p.ring(0, 0, rVal, u > 0.7 ? 2 : 1, u > 0.6 ? c[5] : c[3],
            0.4 + 0.6 * u);
      }
      for (final q in grit) {
        final u = (t - q.t0) / q.duration;
        if (u <= 0.0 || u >= 1.0) continue;
        final d = q.d * (1.0 - Ease.inCubic(u));
        final a = q.a + q.spin * Ease.inQuad(u) * 2.0;
        final x = math.cos(a) * d;
        final y = math.sin(a) * d;
        final x2 = math.cos(a - q.spin * 0.1) * (d + 4.0 * u * u + 0.5);
        final y2 = math.sin(a - q.spin * 0.1) * (d + 4.0 * u * u + 0.5);
        p.lineShaded(
          x2,
          y2,
          x,
          y,
          color: (v) => v < 0.5 ? mix(q.c, _voidColor, 0.4) : q.c,
        );
      }
      final still = t > _suck;
      final jit = still ? ((t * 40.0).floor() % 2 != 0 ? 0.5 : -0.5) : 0.0;
      final cr = still ? 1.6 : 1.0 + 3.5 * (1.0 - k) * k * 4.0;
      p.disc(jit, 0, cr + 3.5, _voidColor, 0.85);
      p.circle(jit, 0, cr + 1.2, c[4]);
      p.circle(jit, 0, cr, kWhite);
      p.glow(0, 0, 10.0 + 26.0 * k, c[4], 0.3 + 0.5 * k);
      if (still) p.glow(0, 0, 8, kWhite, 0.4 + 0.2 * math.sin(t * 60.0));
    } else {
      final q = (t - _still) / 0.5;
      final e = Ease.outCubic(clamp(q));
      if (q < 0.08) p.circle(0, 0, 6.0 * (1.0 - q / 0.08) + 1.0, kWhite);
      if (q < 0.35) {
        final l = (1.0 - q / 0.35) * 34.0 + 3.0;
        for (final a in rays) {
          for (var d = 0.0; d <= l; d += 0.5) {
            p.dot(
              math.cos(a) * d,
              math.sin(a) * d,
              d < l * 0.4 ? kWhite : c[5],
              d < l * 0.7 ? 1.0 : 1.0 - (d / l - 0.7) / 0.3,
            );
          }
        }
        for (final a in rays) {
          for (var d = 0.0; d <= l * 0.45; d += 0.5) {
            p.dot(
              math.cos(a + math.pi / 4.0) * d,
              math.sin(a + math.pi / 4.0) * d,
              c[5],
              1.0 - d / (l * 0.45),
            );
          }
        }
      }
      if (q < 1.0) {
        p.ring(0, 0, 4.0 + 74.0 * e, math.max(1.0, 2.5 * (1.0 - q)),
            q < 0.2 ? kWhite : c[5], 1.15 - q);
        p.ring(0, 0, 2.0 + 40.0 * Ease.outCubic(clamp(q * 1.4)), 1, c[4],
            1.0 - q);
      }
      if (q < 0.6) sparkle(p, 0, 0, 5.0 * (1.0 - q / 0.6), kWhite, c[5], 0.6);
    }
    ps.draw(p);
    lights.draw(p);
  }
}

const EffectMeta _implosionMeta = EffectMeta(
  id: 'explosions/implosion',
  name: 'Implosion',
  desc:
      'Everything is sucked in: streaks and grit rush inward, rings contract and a dark sphere collapses onto a crushed white point; a beat of stillness, then a sharp pop.',
  category: 'explosions',
  tags: ['implosion', 'energy', 'magic', 'collapse', 'pop', 'one-shot'],
  size: (208, 184),
  origin: (104, 92),
  duration: 1.65,
  loop: false,
  fps: 30,
  bg: BackdropKind.dark,
  defaultOptions: {
    'palette': [
      '#0a0614',
      '#1c1236',
      '#3a2470',
      '#6a44c0',
      '#a080f0',
      '#d8c8ff',
      '#ffffff',
    ],
    'seed': 2,
  },
);

final SimulatedEffect implosionEffect = SimulatedEffect(
  meta: _implosionMeta,
  onCreate: (o) => _ImplosionSim(_implosionMeta, o),
);
