// The pop (a white flash, a ring snapping out, star sparks with short trails) follows Sprite Fusion's
// open-source pickup (https://www.spritefusion.com/pixel-art-vfx/pickup), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'pickups_lib.dart';

const double _cy = -30.0;

class _Star {
  double x = 0.0;
  double y = _cy;
  double a;
  double sp;
  final double turn;
  final double life;
  double age = 0.0;
  final double size;
  final List<(double, double)> tr = [];
  final int c;
  final double ph;

  _Star({
    required this.a,
    required this.sp,
    required this.turn,
    required this.life,
    required this.size,
    required this.c,
    required this.ph,
  });
}

class _Mote {
  final double x;
  final double y;
  final double vy;
  final double life;
  final double d;
  final double w;

  const _Mote({
    required this.x,
    required this.y,
    required this.vy,
    required this.life,
    required this.d,
    required this.w,
  });
}

class _CollectBurstSim extends BaseEffectSim {
  late final List<int> c;
  final Lights lights = Lights();
  late final List<_Star> stars;
  late final List<_Mote> motes;
  double t = 0.0;

  _CollectBurstSim(Map<String, Object?> o) {
    c = fit(o.palette, 8);
    final r = Rng(o.seed);
    lights.add(0.0, _cy, 36.0, c[5], 0.85, 0.32);
    lights.add(0.0, _cy, 14.0, kWhite, 0.75, 0.08);
    stars = List.generate(14, (i) {
      final a = (i / 14.0) * tau + r.range(-0.2, 0.2);
      final sp = r.range(145.0, 225.0) * (i % 3 == 0 ? 1.12 : 0.85);
      return _Star(
        a: a,
        sp: sp,
        turn: (i % 2 != 0 ? 1 : -1) * r.range(2.5, 5.0),
        life: r.range(0.75, 1.15),
        size: i % 3 == 0 ? 2.6 : r.range(1.2, 2.0),
        c: i % 4 == 0 ? kWhite : (i % 2 != 0 ? c[6] : c[5]),
        ph: r.range(0.0, tau),
      );
    });
    motes = List.generate(7, (_) {
      return _Mote(
        x: r.range(-8.0, 8.0),
        y: _cy + r.range(-4.0, 6.0),
        vy: -r.range(12.0, 30.0),
        life: r.range(0.5, 0.9),
        d: r.range(0.05, 0.25),
        w: r.range(0.0, tau),
      );
    });
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    for (final s in stars) {
      if (s.age > s.life) continue;
      s.age += dt;
      s.tr.insert(0, (s.x, s.y));
      if (s.tr.length > 4) s.tr.removeLast();
      s.a += s.turn * dt * math.max(0.0, 1.0 - s.age * 1.5);
      s.sp -= s.sp * 4.3 * dt;
      s.x += math.cos(s.a) * s.sp * dt;
      s.y += math.sin(s.a) * s.sp * dt + 6.0 * s.age * dt;
      if (s.y > -2.0) {
        s.y = -2.0;
        s.a = -s.a.abs();
        s.sp *= 0.5;
      }
    }
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    if (t < 0.07) p.circle(0.0, _cy, 5.5 * (1.0 - t / 0.07) + 1.0, kWhite);
    if (t < 0.16) {
      final k = 1.0 - t / 0.16;
      final lLen = 26.0 * Ease.outCubic(math.min(1.0, t / 0.03 + 0.4)) * k;
      const dirs = [
        (1.0, 0.0, 1.0),
        (-1.0, 0.0, 1.0),
        (0.0, 1.0, 0.6),
        (0.0, -1.0, 0.6),
      ];
      for (final (dx, dy, l) in dirs) {
        p.lineShaded(
          0.0,
          _cy,
          dx * lLen * l,
          _cy + dy * lLen * l,
          color: (u) => u < 0.3 ? kWhite : (u < 0.65 ? c[6] : c[5]),
          alpha: (u) => (u < 0.5 ? 1.0 : (1.0 - u) * 2.0) * (0.5 + k),
        );
      }
      p.glow(0.0, _cy, 20.0 * k + 4.0, c[5], 0.6 * k);
    }
    final u1 = t / 0.32;
    if (u1 < 1.0) {
      final r = 3.0 + 23.0 * Ease.outExpo(u1);
      p.ring(0.0, _cy, r, 1.0, u1 < 0.3 ? kWhite : c[6], 1.3 - u1 * 1.2);
      p.glowRing(0.0, _cy, r, 4.0, c[5], 0.4 * (1.0 - u1));
    }
    final u2 = (t - 0.04) / 0.5;
    if (u2 > 0.0 && u2 < 1.0) {
      final r = 2.0 + 16.0 * Ease.outCubic(u2);
      p.ring(0.0, _cy, r, math.max(1.0, 2.6 * (1.0 - u2)), c[5], 1.0 - u2);
    }
    for (final s in stars) {
      if (s.age > s.life) continue;
      final k = 1.0 - s.age / s.life;
      final tw = 0.65 + 0.35 * math.sin(s.age * 26.0 + s.ph);
      for (var i = 1; i < s.tr.length; i++) {
        final (tx, ty) = s.tr[i];
        p.dot(tx, ty, i < 2 ? c[5] : c[4], (1.0 - i / 4.0) * k * 1.4);
      }
      if (k < 0.3 && math.sin(s.age * 40.0 + s.ph) < 0.0) continue;
      glint(
        p,
        s.x,
        s.y,
        (s.size * tw * math.min(1.0, k * 2.5) + 0.5).floorToDouble(),
        s.c,
        0.45 * k,
      );
    }
    for (final m in motes) {
      final a = t - m.d;
      if (a < 0.0 || a > m.life) continue;
      final k = 1.0 - a / m.life;
      final x = m.x + math.sin(a * 6.0 + m.w) * 1.5;
      final y = m.y + m.vy * a;
      p.dot(x, y, k > 0.5 ? c[6] : c[5], k * 1.5);
      p.glow(x + 0.5, y + 0.5, 3.0, c[5], 0.3 * k);
    }
    lights.draw(p);
  }
}

final SimulatedEffect collectBurstEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'pickups/collect-burst',
    name: 'Collect burst',
    desc:
        'The moment of pickup: a white flash and a cross of light, a thin ring snapping out ahead of a softer one, twinkles thrown wide on curving paths that brake, hang and wink out.',
    category: 'pickups',
    tags: ['pickup', 'collect', 'burst', 'sparkle', 'reward', 'one-shot'],
    size: (112, 108),
    origin: (56, 94),
    duration: 1.35,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#1a0516',
        '#3d0a33',
        '#701560',
        '#b0228f',
        '#f53cd1',
        '#ff86e6',
        '#ffd2f6',
        '#ffffff',
      ],
      'seed': 3,
    },
  ),
  onCreate: _CollectBurstSim.new,
);
