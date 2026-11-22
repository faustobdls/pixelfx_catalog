// The flame-puff, smoke and spark recipe is adapted from Sprite Fusion's open-source explosion
// (https://www.spritefusion.com/pixel-art-vfx/explosion), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'fire_lib.dart';

const double _d = 1.5;
final FireNoiseFn _nl = noiseFor(_d);
final int _smoke1 = hex('#5b5566');

const List<(double, double, int)> _coolLayers = [
  (1.0, 1.0, 7),
  (0.72, 0.82, 6),
  (0.44, 0.58, 5),
];

const List<(double len, double w, double a)> _jet = [
  (42.0, 4.2, 0.0),
  (32.0, 3.8, -0.08),
  (30.0, 3.8, 0.08),
  (20.0, 4.6, 0.0),
];

class _ConeSeed {
  final double e, sp, fl, sl, s, f, ox;
  final bool sm;
  _ConeSeed(
      this.e, this.sp, this.fl, this.sm, this.sl, this.s, this.f, this.ox);
}

class _StreakSeed {
  final double e, v, life, l;
  _StreakSeed(this.e, this.v, this.life, this.l);
}

class _SparkSeed {
  final double d, e, v, life;
  _SparkSeed(this.d, this.e, this.v, this.life);
}

class _EmberSeed {
  final double x, y, vx, vy, life, s, ph;
  _EmberSeed(this.x, this.y, this.vx, this.vy, this.life, this.s, this.ph);
}

final PureEffect fireBreathEffect = PureEffect(
  meta: const EffectMeta(
    id: 'fire/fire-breath',
    name: 'Fire breath',
    desc:
        'A roaring cone of fire streaming right from the mouth: white-hot at the lips, billowing out and cooling to red and smoke at its edges, sparks thrown out ahead.',
    category: 'fire',
    tags: [
      'fire', 'breath', 'dragon', 'stream', 'cone', 'directional', 'loop',
    ],
    size: (160, 116),
    origin: (12, 72),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#4a1712', '#8a1f17', '#c9281f', '#f2561d',
        '#ff8a2a', '#ffc23d', '#ffe26b', '#fff3a6', '#ffffff',
      ],
      'spread': 0.24,
      'speed': 320,
      'seed': 6,
    },
  ),
  onDraw: (p, t, o) {
    final f = fit(o.palette, 9);
    final h = hotFirst(f);
    final s = o.seed;
    final aSpread = o.numOpt('spread', 0.24);
    final vSpeed = o.numOpt('speed', 320.0);
    double n(double rate, [int sd = 0, double off = 0.0]) =>
        _nl(t, rate, sd, off);
    final glowCol = mix(mix(h[3], h[4], 0.5), kWhite, 0.25);
    final smokeCol = mix(_smoke1, h[6], 0.3);
    final sparks = [h[1], h[2], h[4], h[5]];
    final emb = [h[1], h[2], h[4], h[6]];

    double roar(double tt) => 0.85 + 0.15 * _nl(tt, 3.0, s + 1);
    double sway(double tt) => _nl(tt, 1.3, s + 2) * 0.05;

    final fire = <(double age, double x, double y, _ConeSeed q)>[];
    final smoke = <(double sa, double x, double y, _ConeSeed q)>[];
    looped<_ConeSeed>(
      t,
      _d,
      260,
      s + 100,
      (r, _) {
        final e = r.range(-1.0, 1.0);
        final fl = r.range(0.42, 0.8) * (1.0 - 0.3 * e.abs());
        final sm = r.chance(0.2 + 0.4 * e.abs());
        return (
          _ConeSeed(
            e,
            r.range(0.75, 1.1),
            fl,
            sm,
            r.range(0.5, 0.85),
            r.range(3.0, 5.2),
            r.next(),
            r.range(4.0, 10.0),
          ),
          fl + (sm ? 0.85 : 0.0),
        );
      },
      (q, age, _) {
        final tb = t - age;
        final ang = q.e * aSpread + sway(tb) - 0.04;
        final vel = vSpeed * q.sp * roar(tb);
        final ta = math.min(age, q.fl);
        final (x, y, vx, vy) = drift(
          q.ox,
          q.e * 1.5,
          math.cos(ang) * vel,
          math.sin(ang) * vel,
          ta,
          0.0,
          -100.0,
          2.0,
          2.4,
        );
        if (age < q.fl) {
          fire.add((age, x, y, q));
          return;
        }
        if (!q.sm || age - q.fl > q.sl) return;
        final sa = age - q.fl;
        final (sx, sy, _, _) =
            drift(x, y, vx * 0.5, vy * 0.6 - 8.0, sa, 0.0, -26.0, 1.8, 1.2);
        smoke.add((sa, sx, sy, q));
      },
    );
    for (final (sa, x, y, q) in smoke) {
      smokePuff(p, x, y, 1.0 - sa / q.sl, q.s * 1.1, smokeCol, true, 0.7);
    }
    fire.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (age, x, y, q) in fire) {
      final u = age / q.fl;
      final edge = q.e.abs();
      final size = q.s * (0.75 + 1.6 * u);
      final heat = math.min(
        0.999,
        math.pow(u, 1.5).toDouble() * (0.85 + 0.2 * edge) +
            0.3 * edge * edge,
      );
      final tear = clamp((u - 0.32) / 0.2);
      firePuff(
          p, x, y, 1.0 - heat, size * (1.0 - 0.55 * tear), q.f, h, 0.1, -0.5, -0.86);
      if (tear > 0.0) {
        final nn = (q.f * 100000.0).floor();
        final th = size *
            (1.5 + 0.5 * n(4.0, nn)) *
            (1.2 - heat * 0.6) *
            tear;
        flameTongue(
          p,
          x,
          y + size * 0.3,
          th,
          size * 0.5 * (1.1 - heat * 0.5),
          -th * 0.4 + n(2.5, nn + 1) * 2.0,
          n,
          nn,
          h,
          layers: heat < 0.45
              ? fireLayers
              : (heat < 0.72 ? fireBackLayers : _coolLayers),
        );
      }
    }

    for (var i = 0; i < 6; i++) {
      final nn = (s * 3 + i) * 19;
      final side = (i % 2 != 0) ? 1.0 : -1.0;
      final d = 18.0 + (i ~/ 2) * 16.0 + n(2.0, nn) * 4.0;
      final l = (9.0 + 5.0 * (0.5 + 0.5 * n(5.0, nn + 1))) * (1.0 - d / 120.0);
      final ex = d;
      final ey = side * d * aSpread * 0.85 - d * 0.06;
      flameBlade(
        p,
        ex,
        ey,
        0.75,
        side * 0.45 - 0.48,
        l,
        1.6 + l * 0.08,
        -side * 3.0,
        n,
        nn,
        h,
        layers: fireLayers,
      );
    }

    looped<_StreakSeed>(
      t,
      _d,
      70,
      s + 250,
      (r, _) {
        final e = r.range(-0.6, 0.6);
        final v = r.range(330.0, 470.0);
        final life = r.range(0.12, 0.26);
        return (_StreakSeed(e, v, life, r.range(4.0, 9.0)), life);
      },
      (q, age, _) {
        final ang = q.e * aSpread - 0.03;
        final (x, y, vx, vy) = drift(
          6.0,
          q.e * 2.0,
          math.cos(ang) * q.v,
          math.sin(ang) * q.v,
          age,
          0.0,
          -60.0,
          2.0,
          2.0,
        );
        final sp = hypot(vx, vy);
        final k = 1.0 - age / q.life;
        final l = q.l * (sp / 400.0);
        p.lineShaded(
          x - (vx / sp) * l,
          y - (vy / sp) * l,
          x,
          y,
          color: (double u) => u > 0.6
              ? (k > 0.5 ? h[0] : h[1])
              : (k > 0.5 ? h[2] : h[3]),
        );
      },
    );

    for (var i = 0; i < _jet.length; i++) {
      final (len, w, a) = _jet[i];
      final nn = (s * 5 + i) * 17;
      final l = len * roar(t) * (0.85 + 0.2 * n(5.0, nn));
      final aa = a + sway(t);
      flameBlade(
        p,
        0,
        0,
        math.cos(aa),
        math.sin(aa),
        l,
        w,
        n(3.0, nn + 3) * 3.0,
        n,
        nn,
        h,
        layers: fireLayers,
        jit: 0.5,
        wob: 1.5,
      );
    }

    looped<_SparkSeed>(
      t,
      _d,
      40,
      s + 300,
      (r, _) {
        final d = r.range(4.0, 60.0);
        final e = r.range(-1.0, 1.0);
        final v = r.range(140.0, 280.0);
        final life = r.range(0.25, 0.55);
        return (_SparkSeed(d, e, v, life), life);
      },
      (q, age, _) {
        final ang = q.e * aSpread * 1.8 - 0.12;
        final (x, y, vx, vy) = drift(
          q.d,
          q.e * q.d * aSpread,
          math.cos(ang) * q.v,
          math.sin(ang) * q.v - 30.0,
          age,
          0.0,
          190.0,
          2.0,
          2.0,
        );
        sparkLine(p, x, y, vx, vy, 1.0 - age / q.life, sparks);
      },
    );

    looped<_EmberSeed>(
      t,
      _d,
      18,
      s + 400,
      (r, _) {
        final px = r.range(50.0, 100.0);
        final py = r.range(-14.0, 6.0);
        final vx = r.range(10.0, 40.0);
        final vy = -r.range(20.0, 50.0);
        final life = r.range(0.8, 1.4);
        return (
          _EmberSeed(
            px,
            py,
            vx,
            vy,
            life,
            r.chance(0.2) ? 2.0 : 1.0,
            r.range(0.0, 6.3),
          ),
          life,
        );
      },
      (q, age, _) {
        final (x, y, _, _) =
            drift(q.x, q.y, q.vx, q.vy, age, 0.0, -30.0, 1.6, 1.6);
        emberDot(
          p,
          x + 5.0 * (math.sin(age * 2.3 + q.ph) - math.sin(q.ph)),
          y,
          1.0 - age / q.life,
          q.s,
          emb,
          age * 40.0 + q.ph,
        );
      },
    );

    final k = roar(t);
    p.glow(3, 0, 34 * k, glowCol, 0.75 * k);
    p.glow(3, 0, 10, h[0], 0.55);
    for (var d = 10; d < 126; d += 8) {
      p.glow(d, -d * 0.1, 10 + d * 0.2, glowCol, 0.32 * k * (1.0 - d / 150.0));
    }
    p.glow(64, -12, 96, glowCol, 0.16 * k);
  },
);
