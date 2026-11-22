// The release (a white disc, a cross, two rings, a big light and a spray of motes and stars) is adapted from
// Sprite Fusion's open-source energy charge (https://www.spritefusion.com/pixel-art-vfx/energy),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'arcane_lib.dart';

const double _cy = -28.0;
const double _gather = 0.22;
const int _n = 9;

class _Rune {
  final int g;
  double x;
  double y;
  double vx;
  double vy;
  final double pop;
  bool popped = false;
  final double ph;

  _Rune({
    required this.g,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.pop,
    required this.ph,
  });
}

class _Pop {
  final double t;
  final double x;
  final double y;

  const _Pop(this.t, this.x, this.y);
}

class _ManaBurstSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  late final List<_Rune> runes;
  final List<_Pop> pops = [];
  double t = 0.0;
  bool released = false;

  _ManaBurstSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed) {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [kWhite, c[6], c[5], c[4]],
    );
    runes = List.generate(_n, (i) {
      final a = (i / _n) * tau + r.range(-0.25, 0.25) - math.pi / 2.0;
      final sp = r.range(150.0, 210.0);
      return _Rune(
        g: i,
        x: 0.0,
        y: _cy,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp * (math.sin(a) > 0.0 ? 0.42 : 0.85),
        pop: _gather + 0.42 + i * 0.065 + r.range(0.0, 0.05),
        ph: r.range(0.0, tau),
      );
    }, growable: false);
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t < _gather - 0.03) {
      for (var i = 0; i < 2; i++) {
        final a = r.range(0.0, tau);
        final d = r.range(24.0, 52.0);
        final life = r.range(0.12, 0.18);
        final v = (d * 3.0) / (math.exp(3.0 * life) - 1.0);
        final x = math.cos(a) * d;
        final y = math.min(-2.0, _cy + math.sin(a) * d * 0.85);
        final rawL = hypot(x, y - _cy);
        final l = rawL == 0.0 ? 1.0 : rawL;
        ps.spawn(
          P.streak,
          x,
          y,
          (-x / l) * v,
          ((_cy - y) / l) * v,
          life,
          r.chance(0.5) ? c[6] : c[5],
        );
      }
    }
    if (t >= _gather && !released) {
      released = true;
      lights.add(0, _cy - 12.0, 96, c[5], 1.0, 0.5);
      lights.add(0, _cy, 40, kWhite, 0.9, 0.1);
      for (var i = 0; i < 96; i++) {
        final a = r.range(0.0, tau);
        final sp = r.range(100.0, 250.0);
        final dn = math.sin(a) > 0.0 ? 0.45 : 1.0;
        ps.spawn(
          r.chance(0.65) ? P.mote : P.star,
          0.0,
          _cy,
          math.cos(a) * sp,
          math.sin(a) * sp * dn,
          r.range(0.25, 0.55),
          r.pick([kWhite, c[6], c[5]]),
          r.range(0.8, 1.8),
        );
      }
      for (var i = 0; i < 20; i++) {
        final a = r.range(0.0, tau);
        final sp = r.range(130.0, 280.0);
        ps.spawn(
          P.spark,
          0.0,
          _cy,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.2, 0.45),
        );
      }
    }
    if (released) {
      for (final rune in runes) {
        if (rune.popped) continue;
        rune.vx -= rune.vx * 4.2 * dt;
        rune.vy -= rune.vy * 4.2 * dt + 8.0 * dt;
        rune.x += rune.vx * dt;
        rune.y += rune.vy * dt;
        if (r.chance(0.35)) {
          ps.spawn(
            P.mote,
            rune.x + r.range(-1.5, 1.5),
            rune.y,
            rune.vx * 0.2 + r.range(-10.0, 10.0),
            rune.vy * 0.2 - r.range(5.0, 25.0),
            r.range(0.2, 0.4),
            c[5],
            0.5,
          );
        }
        if (t >= rune.pop) {
          rune.popped = true;
          pops.add(_Pop(t, rune.x, rune.y));
          lights.add(rune.x, rune.y, 34, c[5], 0.9, 0.22);
          lights.add(rune.x, rune.y, 12, kWhite, 0.8, 0.06);
          for (var i = 0; i < 9; i++) {
            final a = r.range(0.0, tau);
            final sp = r.range(70.0, 200.0);
            ps.spawn(
              P.spark,
              rune.x,
              rune.y,
              math.cos(a) * sp,
              math.sin(a) * sp - 40.0,
              r.range(0.15, 0.4),
            );
          }
          for (var i = 0; i < 5; i++) {
            final a = r.range(0.0, tau);
            final sp = r.range(20.0, 80.0);
            ps.spawn(
              i.isOdd ? P.star : P.mote,
              rune.x,
              rune.y,
              math.cos(a) * sp,
              math.sin(a) * sp - 20.0,
              r.range(0.3, 0.6),
              r.pick([kWhite, c[6]]),
              r.range(0.8, 1.6),
            );
          }
        }
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final k = t < _gather
        ? 0.4 * (t / _gather)
        : math.max(0.0, 1.0 - (t - _gather) / 1.1);
    if (k > 0.0) p.glow(0, -1, 50, c[4], 0.3 * k);
  }

  @override
  void draw(Painter p) {
    if (t < _gather) {
      final k = t / _gather;
      final rr = 1.0 + 3.5 * k * k;
      p.circle(0, _cy, rr + 1.2, c[4]);
      p.circle(0, _cy, rr, c[6]);
      p.circle(0, _cy, rr * 0.5, kWhite);
      p.glow(0, _cy, 10.0 + 20.0 * k, c[5], 0.4 + 0.4 * k);
      final q = clamp((t - _gather * 0.35) / (_gather * 0.65));
      if (q > 0.0 && q < 1.0) {
        p.ring(0, _cy, rr + 2.0 + 16.0 * (1.0 - Ease.outCubic(q)), 1,
            q > 0.6 ? kWhite : c[6], 1.0 - q * 0.5);
      }
    } else {
      final q = (t - _gather) / 0.6;
      if (q < 1.0) {
        final e = Ease.outCubic(q);
        if (q < 0.12) {
          p.circle(0, _cy, 12.0 * (1.0 - q / 0.12) + 2.0, c[5]);
          p.circle(0, _cy, 12.0 * (1.0 - q / 0.12), kWhite);
        }
        if (q < 0.32) {
          flare(p, 0, _cy, 30.0 * (1.0 - q / 0.32) + 4.0, 1.0 - q / 0.32, c);
        }
        final rad1 = 4.0 + 62.0 * e;
        p.ringShaded(
          0,
          _cy,
          rad1,
          math.max(1.0, 5.0 * (1.0 - q)),
          color: (_, _) => q < 0.2 ? kWhite : c[6],
          alpha: (_, ang) => _cy + math.sin(ang) * rad1 > 0.0 ? 0.0 : 1.2 - q,
        );
        p.ringShaded(
          0,
          _cy,
          2.0 + 38.0 * Ease.outCubic(math.min(1.0, q * 1.4)),
          math.max(1.0, 2.0 * (1.0 - q)),
          color: (_, _) => c[5],
          alpha: (_, ang) => _cy + math.sin(ang) * 40.0 > 0.0 ? 0.0 : 1.0 - q,
        );
        p.glow(0, _cy, 60.0 * (0.4 + 0.6 * e), c[5], 0.9 * (1.0 - q));
      }
    }

    for (final rune in runes) {
      if (!released || rune.popped) continue;
      final left = rune.pop - t;
      final hot = t - _gather < 0.08 || left < 0.06;
      final bob = math.sin(t * 9.0 + rune.ph) * 0.6;
      sigil(p, rune.g, rune.x, rune.y + bob, hot ? kWhite : c[6], 1.0,
          hot ? c[4] : c[3]);
      p.glow(rune.x, rune.y + bob, 10, c[5], hot ? 0.7 : 0.35);
      if (left < 0.06) {
        sparkle(p, rune.x, rune.y + bob, 3.0 + 4.0 * (1.0 - left / 0.06), c[6],
            c[5], 0.5);
      }
    }

    for (final q in pops) {
      final k = (t - q.t) / 0.32;
      if (k >= 1.0) continue;
      if (k < 0.35) {
        flare(p, q.x, q.y, 11.0 * (1.0 - k / 0.35) + 2.0, 1.0 - k / 0.35, c);
      }
      p.ring(q.x, q.y, 2.0 + 11.0 * Ease.outCubic(k),
          math.max(1.0, 2.0 * (1.0 - k)), k < 0.3 ? kWhite : c[6], 1.15 - k);
    }

    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect manaBurstEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'arcane/mana-burst',
    name: 'Mana burst',
    desc:
        'Energy rushes into a point and blows out in a white flash and rings, flinging glowing runes that flare and pop into sparks one after another.',
    category: 'arcane',
    tags: ['arcane', 'burst', 'mana', 'rune', 'nova', 'magic', 'ground', 'one-shot'],
    size: (208, 150),
    origin: (104, 124),
    duration: 1.8,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {'palette': Pal.arcane, 'seed': 9},
  ),
  onCreate: (o) => _ManaBurstSim(o),
);
