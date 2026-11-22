// The flame-puff, smoke and spark recipe is adapted from Sprite Fusion's open-source explosion
// (https://www.spritefusion.com/pixel-art-vfx/explosion), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'fire_lib.dart';

const double _d = 1.2;
final FireNoiseFn _nl = noiseFor(_d);
final int _smoke1 = hex('#5b5566');

const List<(double len, double w, double dy)> _body = [
  (30.0, 4.2, 0.0),
  (23.0, 4.4, -1.6),
  (22.0, 4.4, 1.6),
  (15.0, 4.6, 0.0),
];

const List<(double a, double len, double w)> _corona = [
  (-1.3, 6.0, 1.1),
  (-1.8, 8.0, 1.2),
  (-2.3, 7.0, 1.1),
  (1.3, 6.0, 1.1),
  (1.8, 8.0, 1.2),
  (2.3, 7.0, 1.1),
];

class _TailSeed {
  final double x, y, v, vy, fl, sl, s, f;
  final bool sm;
  _TailSeed(this.x, this.y, this.v, this.vy, this.fl, this.sm, this.sl,
      this.s, this.f);
}

class _MoteSeed {
  final double a, v, life;
  _MoteSeed(this.a, this.v, this.life);
}

class _EmberSeed {
  final double x, y, v, vy, life, ph;
  final bool big;
  _EmberSeed(this.x, this.y, this.v, this.vy, this.life, this.big, this.ph);
}

void _drawHead(
  Painter p,
  List<int> h,
  double t,
  double r0,
  int s,
  double hx,
  double hy,
) {
  final ph = t / _d;
  p.shade(hx - r0 * 2.4, hy - r0 * 1.7, hx + r0 * 1.5, hy + r0 * 1.7,
      (x, y, _) {
    final lx = x - hx;
    final ly = y - hy;
    final d = hypot(lx, ly);
    final th = math.atan2(ly, lx);
    final back = math.max(0.0, -math.cos(th));
    final a = th / tau;
    final bump = 0.55 * pnoise(a * 9.0 + ph * 9.0, 9, s) +
        0.35 * pnoise(a * 5.0 - ph * 10.0, 5, s + 1);
    final rim = r0 * (1.0 + 0.55 * back * back) + bump;
    if (d > rim) return null;
    final swirl = pnoise(a * 5.0 - ph * 10.0 + d * 0.45, 5, s + 2);
    final heat = 1.0 - d / rim + 0.26 * swirl + 0.1 * (1.0 - back);
    if (rim - d < 1.0 && back < 0.3) return heat > 0.3 ? h[3] : h[5];
    return heat > 0.74
        ? h[0]
        : heat > 0.58
            ? h[1]
            : heat > 0.42
                ? h[2]
                : heat > 0.27
                    ? h[4]
                    : heat > 0.13
                        ? h[5]
                        : h[6];
  });
}

final PureEffect fireballEffect = PureEffect(
  meta: const EffectMeta(
    id: 'fire/fireball',
    name: 'Fireball',
    desc:
        'A fireball flying right: a churning white-hot head with a corona of flame, a long torn tail of flame puffs cooling into smoke, embers shed behind.',
    category: 'fire',
    tags: ['fire', 'fireball', 'projectile', 'magic', 'directional', 'loop'],
    size: (136, 56),
    origin: (112, 28),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#4a1712', '#8a1f17', '#c9281f', '#f2561d',
        '#ff8a2a', '#ffc23d', '#ffe26b', '#fff3a6', '#ffffff',
      ],
      'radius': 5,
      'speed': 120,
      'seed': 5,
    },
  ),
  onDraw: (p, t, o) {
    final f = fit(o.palette, 9);
    final h = hotFirst(f);
    final s = o.seed;
    final r0 = o.numOpt('radius', 5.0);
    final v = o.numOpt('speed', 120.0);
    double n(double rate, [int sd = 0, double off = 0.0]) =>
        _nl(t, rate, sd, off);
    final glowCol = mix(mix(h[3], h[4], 0.5), kWhite, 0.25);
    final smokeCol = mix(_smoke1, h[6], 0.3);
    final sparks = [h[1], h[2], h[4], h[5]];
    final emb = [h[1], h[2], h[4], h[6]];

    final hx = n(3.0, s + 50) * 0.5;
    final hy = n(2.5, s + 51) * 0.7;

    final fire = <(double age, double x, double y, _TailSeed q)>[];
    final smoke = <(double sa, double x, double y, _TailSeed q)>[];
    looped<_TailSeed>(
      t,
      _d,
      130,
      s + 100,
      (r, _) {
        final fl = r.range(0.22, 0.55);
        final sm = r.chance(0.55);
        final x = -r.range(2.0, 24.0);
        return (
          _TailSeed(
            x,
            r.range(-1.0, 1.0) * (r0 - 0.1 * -x),
            v * r.range(0.3, 0.6),
            r.range(-16.0, 16.0),
            fl,
            sm,
            r.range(0.25, 0.45),
            r.range(1.3, 2.9),
            r.next() * 0.5 + 0.5 * (-x / 24.0),
          ),
          fl + (sm ? 0.45 : 0.0),
        );
      },
      (q, age, _) {
        final ta = math.min(age, q.fl);
        final (wx, y, wvx, vy) = drift(0.0, q.y, q.v, q.vy, ta, 0.0, -70.0, 4.5, 3.0);
        final x = q.x + wx - v * ta;
        if (age < q.fl) {
          fire.add((age, x, y, q));
          return;
        }
        if (!q.sm || age - q.fl > q.sl) return;
        final sa = age - q.fl;
        final (sx, sy, _, _) =
            drift(x, y, wvx - v, vy * 0.6 - 6.0, sa, v * 2.0, -30.0, 2.0, 1.2);
        smoke.add((sa, sx, sy, q));
      },
    );
    for (final (sa, x, y, q) in smoke) {
      smokePuff(p, x, y, 1.0 - sa / q.sl, q.s * 0.9, smokeCol);
    }
    fire.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (age, x, y, q) in fire) {
      final u = age / q.fl;
      firePuff(p, x, y, 1.0 - u, q.s * (1.0 + 1.3 * u), q.f, h, 0.07, -0.86, -0.5);
    }

    for (var i = 0; i < _body.length; i++) {
      final (len, w, dy) = _body[i];
      final nn = (s * 5 + i) * 17;
      final l = len *
          (0.82 + 0.25 * n(4.0, nn)) *
          (1.0 + 0.3 * math.max(0.0, n(2.4, nn + 3)));
      flameBlade(
        p,
        hx + 1.0,
        hy + dy * 0.5,
        -1.0,
        dy * 0.02,
        l,
        w * r0 / 5.0,
        n(3.0, nn + 5) * 3.0 + dy,
        n,
        nn,
        h,
        layers: fireLayers,
        jit: 0.5,
        wob: 1.1 + l * 0.05,
      );
    }
    for (var i = 0; i < _corona.length; i++) {
      final (a, len, w) = _corona[i];
      final nn = (s * 5 + i + 20) * 17;
      final l = len * (0.7 + 0.4 * (0.5 + 0.5 * n(6.0, nn)));
      final ox = math.cos(a) * r0 * 0.85;
      final oy = math.sin(a) * r0 * 0.85;
      final dx = math.cos(a) * 0.55 - 1.0;
      final dy = math.sin(a) * 0.55;
      final dl = hypot(dx, dy);
      flameBlade(
        p,
        hx + ox,
        hy + oy,
        dx / dl,
        dy / dl,
        l,
        w,
        -(a < 0.0 ? -1.0 : (a > 0.0 ? 1.0 : 0.0)) * 1.5,
        n,
        nn,
        h,
        layers: fireLayers,
      );
    }
    _drawHead(p, h, t, r0, s, hx, hy);

    looped<_MoteSeed>(
      t,
      _d,
      26,
      s + 200,
      (r, _) {
        final a = r.range(-2.4, 2.4);
        final spd = r.range(30.0, 70.0);
        final life = r.range(0.08, 0.18);
        return (_MoteSeed(a, spd, life), life);
      },
      (q, age, _) {
        final ca = math.cos(q.a);
        final sa = math.sin(q.a);
        final dd = r0 * 0.9 + q.v * age;
        final x = hx + ca * dd - v * 0.4 * age;
        final y = hy + sa * dd;
        final k = 1.0 - age / q.life;
        final l = 1.0 + 2.0 * k;
        p.line(x - ca * l + v * 0.02, y - sa * l, x, y, k > 0.5 ? h[1] : h[3]);
        p.glow(x, y, 3, h[2], 0.4 * k);
      },
    );

    looped<_EmberSeed>(
      t,
      _d,
      30,
      s + 300,
      (r, _) {
        final ex = -r.range(2.0, 16.0);
        final ey = r.range(-3.0, 3.0);
        final ev = v * r.range(0.3, 0.8);
        final evy = r.range(-20.0, 20.0);
        final life = r.range(0.25, 0.55);
        final big = r.chance(0.25);
        final ph = r.range(0.0, 6.3);
        return (_EmberSeed(ex, ey, ev, evy, life, big, ph), life);
      },
      (q, age, _) {
        final (wx, y, wvx, vy) = drift(0.0, q.y, q.v, q.vy, age, 0.0, 50.0, 3.0, 2.0);
        final x = q.x + wx - v * age;
        final k = 1.0 - age / q.life;
        if (q.big) {
          emberDot(p, x, y, k, 2.0, emb, age * 40.0 + q.ph);
        } else {
          sparkLine(p, x, y, wvx - v, vy, k, sparks);
        }
      },
    );

    final fl = 0.85 + 0.15 * n(9.0, s + 7);
    p.glowLine(hx - 6.0, hy, -50.0, -2.0, 12, glowCol, 0.2 * fl);
    p.glow(hx - 2.0, hy, 42, glowCol, 0.42 * fl);
    p.glow(hx, hy, 13, h[1], 0.3 * fl);
  },
);
