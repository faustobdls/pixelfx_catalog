import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'holy_lib.dart';

class _PuffLobe {
  final double x;
  final double y;
  final double r0;
  final double r1;
  final double life;

  const _PuffLobe(this.x, this.y, this.r0, this.r1, this.life);
}

class _FeatherBurstSim extends BaseEffectSim {
  final List<int> f;
  final int g;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  late final Feathers loose;
  late final List<_PuffLobe> lobes;
  double t = 0.0;

  _FeatherBurstSim(Map<String, Object?> o)
      : f = fit(o.palette, 6),
        g = hex(o['glow'] ?? '#fff0c0'),
        r = Rng(o.seed) {
    ps = Particles(
      rng: r,
      ground: (_) => double.infinity,
      sparks: [kWhite, f[4], f[3], f[2]],
    );
    loose = Feathers(r, 1e6);

    lobes = List.generate(11, (i) {
      final a = (i / 11.0) * tau + r.range(-0.25, 0.25);
      final d = r.range(5.0, 14.0);
      return _PuffLobe(
        math.cos(a) * d,
        math.sin(a) * d * 0.8,
        r.range(2.5, 4.0),
        r.range(6.0, 9.5),
        r.range(0.45, 0.8),
      );
    }, growable: false);

    for (var i = 0; i < 20; i++) {
      final a = (i / 20.0) * tau + r.range(-0.15, 0.15);
      final sp = r.range(110.0, 230.0);
      final up = math.sin(a) < 0.0 ? 0.7 : 0.9;
      final fa = a + r.range(-0.5, 0.5);
      final flen = r.range(10.0, 14.0);
      final fwid = r.range(2.6, 3.4);
      final flife = r.range(1.9, 2.6);
      final fdelay = r.range(0.0, 0.03);
      final fsink = r.range(26.0, 38.0);
      final famp = r.range(8.0, 13.0);
      loose.add(
        x: math.cos(a) * 3.0,
        y: math.sin(a) * 3.0,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp * up - 20.0,
        a: fa,
        len: flen,
        wid: fwid,
        life: flife,
        delay: fdelay,
        sink: fsink,
        amp: famp,
      );
    }

    // Small feathers and down, slower.
    for (var i = 0; i < 10; i++) {
      final a = r.range(0.0, tau);
      final sp = r.range(50.0, 130.0);
      final fa = r.range(0.0, tau);
      final flen = r.range(6.0, 8.0);
      final fwid = r.range(1.8, 2.2);
      final flife = r.range(1.6, 2.4);
      final fsink = r.range(18.0, 28.0);
      loose.add(
        x: 0.0,
        y: 0.0,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp - 20.0,
        a: fa,
        len: flen,
        wid: fwid,
        life: flife,
        back: true,
        sink: fsink,
      );
    }

    for (var i = 0; i < 26; i++) {
      final a = r.range(0.0, tau);
      final sp = r.range(30.0, 140.0);
      final px = r.range(-3.0, 3.0);
      final py = r.range(-3.0, 3.0);
      final life = r.range(1.4, 2.6);
      final col = r.chance(0.6) ? kWhite : f[4];
      final size = r.range(0.6, 1.6);
      ps.spawn(
        P.flake,
        px,
        py,
        math.cos(a) * sp,
        math.sin(a) * sp - 15.0,
        life,
        col,
        size,
      );
    }

    for (var i = 0; i < 10; i++) {
      final a = r.range(0.0, tau);
      final sp = r.range(60.0, 160.0);
      final life = r.range(0.3, 0.6);
      final col = r.chance(0.5) ? kWhite : g;
      final size = r.range(0.8, 2.2);
      ps.spawn(
        P.star,
        0.0,
        0.0,
        math.cos(a) * sp,
        math.sin(a) * sp,
        life,
        col,
        size,
      );
    }

    lights.add(0, 0, 50, g, 0.75, 0.45);
    lights.add(0, 0, 20, kWhite, 0.7, 0.1);
  }

  void _puff(Painter p) {
    for (final l in lobes) {
      final u = t / l.life;
      if (u >= 1.0) continue;
      final e = Ease.outCubic(u);
      final x = l.x * (0.4 + e * 1.3);
      final y = l.y * (0.4 + e * 1.3) - u * 5.0;
      final rad = (l.r0 + (l.r1 - l.r0) * Ease.outCubic(math.min(1.0, u * 3.0))) *
          (1.0 - Ease.inQuad(u));
      if (rad < 0.6) continue;
      p.circle(x, y, rad + 0.8, f[2]);
      p.circleShaded(
        x,
        y,
        rad,
        color: (d, a) => d > 0.55 && math.sin(a + 0.8) > 0.3
            ? f[3]
            : (d < 0.45 && math.sin(a + 0.8) < -0.2 ? kWhite : f[4]),
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    // Feathers catch the light as they turn.
    if (t > 0.3 && t < 2.2 && loose.count > 0 && r.chance(0.14)) {
      final q = r.pick(loose.list);
      if (q.delay <= 0.0) {
        final sx = q.x + r.range(-2.0, 2.0);
        final sy = q.y + r.range(-1.0, 1.0);
        final life = r.range(0.2, 0.4);
        final col = r.chance(0.5) ? kWhite : g;
        final size = r.range(1.0, 2.2);
        ps.spawn(P.star, sx, sy, 0.0, 0.0, life, col, size);
      }
    }
    ps.update(dt);
    loose.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    loose.draw(p, f, 'back');
    ps.draw(p, 'back');
    _puff(p);
  }

  @override
  void draw(Painter p) {
    // The pop: a white flash and a ring of air.
    if (t < 0.07) p.circle(0, 0, 9.0 * (1.0 - t / 0.14), kWhite);
    if (t < 0.25) {
      final u = t / 0.25;
      p.ringShaded(
        0,
        0,
        6.0 + 24.0 * Ease.outCubic(u),
        math.max(1.0, 2.5 * (1.0 - u)),
        color: (v, _) => v > 0.5 ? kWhite : mix(f[4], g, 0.4),
        alpha: (_, _) => 1.1 - u,
      );
    }
    if (t < 0.2) sparkle(p, 0, 0, 10.0 * (1.0 - t / 0.2), kWhite, g, 0.6);
    // The burst's warmth lingers a moment.
    p.glow(0, 4, 46, g, 0.28 * (1.0 - smooth(0.0, 1.3, t)));
    loose.draw(p, f, 'front');
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect featherBurstEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'holy/feather-burst',
    name: 'Feather burst',
    desc:
        'A white puff pops and throws feathers that brake hard, then rock from side to side as they sink and fade, with down drifting after them.',
    category: 'holy',
    tags: ['holy', 'feather', 'burst', 'poof', 'angel', 'bird', 'one-shot'],
    size: (160, 160),
    origin: (80, 60),
    duration: 3.0,
    loop: false,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#4a4560',
        '#7a7494',
        '#aaa5c2',
        '#d6d3e6',
        '#f4f3fa',
        '#ffffff',
      ],
      'glow': '#fff0c0',
      'seed': 4,
    },
  ),
  onCreate: (o) => _FeatherBurstSim(o),
);
