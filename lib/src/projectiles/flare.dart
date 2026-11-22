import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'projectiles_lib.dart';

const _flareMeta = EffectMeta(
  id: 'projectiles/flare',
  name: 'Signal flare',
  desc:
      'A signal flare streaks up off the ground trailing sparks and smoke, bursts, and hangs as a pulsing red star that drips sparks under its own red-lit smoke, then gutters out.',
  category: 'projectiles',
  tags: [
    'projectile',
    'flare',
    'signal',
    'fire',
    'smoke',
    'light',
    'one-shot',
  ],
  size: (152, 232),
  origin: (76, 226),
  duration: 5,
  loop: false,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': [
      '#2a0610',
      '#5c0d1c',
      '#9a1428',
      '#d8243a',
      '#ff4d5e',
      '#ff8a94',
      '#ffd0d4',
      '#ffffff',
    ],
    'smoke': [
      '#1e1a26',
      '#2e2938',
      '#433d4d',
      '#5b5466',
      '#77707f',
      '#958e9c',
      '#b3acb9',
    ],
    'height': 150,
    'seed': 2,
  },
);

const _rise = 0.85;
const _burn = 3.1;

final PixelEffect flareEffect = SimulatedEffect(
  meta: _flareMeta,
  onCreate: _FlareSim.new,
);

class _FlareSim extends BaseEffectSim {
  _FlareSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        sm = fit(o.rampOpt('smoke'), 7),
        h = o.numOpt('height', 150),
        r = Rng(o.seed) {
    ps = Particles(
      rng: r,
      ground: (_) => 0,
      sparks: [kWhite, c[6], c[4], c[2]],
    );
    smoke = Smoke(r);
    lights = Lights();
    wr = [
      c[0],
      c[1],
      mix(c[2], sm[2], 0.45),
      mix(c[3], sm[3], 0.35),
      c[4],
      c[5],
      c[6],
    ];
    lights.add(0, -3, 26, c[4], 0.8, 0.25);
    for (var i = 0; i < 5; i++) {
      smoke.add(SmokePuff(
        x: r.range(-3, 3),
        y: -2,
        vx: r.range(-25, 25),
        vy: -r.range(5, 20),
        r0: 2,
        r1: r.range(4, 6),
        life: r.range(1, 1.6),
        a: 0.5,
        warm: 0.8,
        rise: 6,
      ));
    }
  }

  final List<int> c;
  final List<int> sm;
  final double h;
  final Rng r;
  late final Particles ps;
  late final Smoke smoke;
  late final Lights lights;
  late final List<int> wr;

  double t = 0;
  bool burst = false;
  double emit = 0;
  double drip = 0;

  (double, double) _risePos(double time) => (
        math.sin(time * 3) * 2 * (time / _rise),
        -h * Ease.outCubic(clamp(time / _rise)),
      );

  (double, double) _starPos(double time) {
    final u = time - _rise;
    return (
      math.sin(u * 1.6) * 3 + _risePos(_rise).$1,
      -h + u * 9 + math.sin(u * 2.3) * 1.5,
    );
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t < _rise) {
      final (x, y) = _risePos(t);
      final (px, py) = _risePos(math.max(0.0, t - dt));
      for (emit += hypot(x - px, y - py) / 1.5; emit > 1; emit--) {
        smoke.add(SmokePuff(
          x: x + r.range(-0.6, 0.6),
          y: y + 4,
          vx: r.range(-6, 6),
          vy: r.range(0, 8),
          r0: 1.3,
          r1: r.range(3, 4.8),
          life: r.range(1.4, 2.1),
          a: 0.5,
          b: 0.95,
          warm: 0.9,
          rise: 3,
          drag: 2,
          grow: 1.4,
        ));
      }
      if (r.chance(0.5)) {
        ps.spawn(
          P.spark,
          x,
          y + 3,
          r.range(-40, 40),
          r.range(20, 90),
          r.range(0.2, 0.45),
        );
      }
    } else if (!burst) {
      burst = true;
      final (x, y) = _starPos(t);
      lights.add(x, y, 64, c[4], 0.9, 0.5);
      lights.add(x, y, 24, kWhite, 0.8, 0.12);
      for (var i = 0; i < 30; i++) {
        final a = r.range(0, tau);
        final sp = r.range(70, 190);
        ps.spawn(
          P.spark,
          x,
          y,
          math.cos(a) * sp,
          math.sin(a) * sp - 30,
          r.range(0.25, 0.7),
        );
      }
      for (var i = 0; i < 10; i++) {
        smoke.add(SmokePuff(
          x: x + r.range(-3, 3),
          y: y + r.range(-3, 3),
          vx: r.range(-40, 40),
          vy: r.range(-40, 10),
          r0: 2.5,
          r1: r.range(6, 9),
          life: r.range(1.6, 2.4),
          a: 0.55,
          warm: 1,
          rise: 10,
          drag: 2.5,
        ));
      }
    } else if (t < _rise + _burn) {
      final (x, y) = _starPos(t);
      final k = (t - _rise) / _burn;
      final power = 1 - smooth(0.75, 1, k);
      for (drip += dt * 26 * power; drip > 1; drip--) {
        ps.spawn(
          P.spark,
          x + r.range(-1.5, 1.5),
          y + 2,
          r.range(-30, 30),
          r.range(10, 60),
          r.range(0.35, 0.8),
        );
      }
      if (r.chance(dt * 18 * power)) {
        smoke.add(SmokePuff(
          x: x + r.range(-1.5, 1.5),
          y: y - 2,
          vx: r.range(-8, 8),
          vy: -r.range(15, 30),
          r0: 2,
          r1: r.range(6, 10),
          life: r.range(1.6, 2.4) * (1 - 0.4 * k),
          a: 0.5,
          b: 0.85,
          warm: 1,
          rise: 14,
          drag: 1.6,
          grow: 1.2,
        ));
      }
    }
    ps.update(dt);
    smoke.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    final list = smoke.puffs();
    final lit = t > _rise && t < _rise + _burn
        ? 1 - smooth(0.75, 1, (t - _rise) / _burn)
        : 0.0;
    if (lit > 0) {
      final (sx, sy) = _starPos(t);
      for (final q in list) {
        q.w = math.max(q.w, lit * math.exp(-hypot(q.x - sx, q.y - sy) / 26));
      }
    }
    cloud(p, list, sm, wr, dens: 1.4, max: 0.8, lit: 1.3);
    ps.draw(p);
    if (t < _rise) {
      final (x, y) = _risePos(t);
      p.lineShaded(
        x,
        y + 1,
        x,
        y + 5,
        color: (u) => (u < 0.3
            ? c[6]
            : u < 0.7
                ? c[4]
                : c[3]),
      );
      p.px(x, y, kWhite);
      p.px(x, y - 1, c[6]);
      p.glow(x, y, 14, c[4], 0.6);
      p.glow(x, y, 4, kWhite, 0.4);
    } else if (t < _rise + _burn) {
      final (x, y) = _starPos(t);
      final u = t - _rise;
      final k = u / _burn;
      final fr = (t * 30).floor();
      final fl = 0.8 + 0.2 * rand(fr, 3) + 0.08 * math.sin(u * 19);
      final die = 1 - smooth(0.78, 1, k);
      if (u < 0.25) {
        final e = u / 0.25;
        flare(p, x, y, 22 * (1 - e) + 3, 1 - e, c);
        if (e < 0.25) p.circle(x, y, 5 * (1 - e * 3) + 1, kWhite);
      }
      final rVal = (2 + 0.6 * fl) * (0.4 + 0.6 * die);
      p.circle(x, y, rVal + 1.2, c[3]);
      p.circle(x, y, rVal, die > 0.4 ? c[5] : c[4]);
      if (die > 0.25) {
        p.circle(x - 0.3, y - 0.3, rVal * 0.55, die > 0.6 ? kWhite : c[6]);
      }
      if (die > 0.15 && rand(fr, 9) > 0.15) {
        sparkle(
          p,
          x,
          y,
          ((5 + 3 * fl) * die + 0.5).floor().toDouble(),
          c[6],
          c[4],
          0.5 * die,
        );
      }
      p.glow(x, y, 70 * (0.6 + 0.4 * die), c[3], 0.55 * fl * die);
      p.glow(x, y, 22, c[4], 0.5 * fl * die);
      p.glow(x, y, 6, kWhite, 0.35 * die);
    }
    lights.draw(p);
  }
}
