// The flame-puff, smoke and ember recipe is adapted from Sprite Fusion's open-source fire
// (https://www.spritefusion.com/pixel-art-vfx/fire), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'fire_lib.dart';

const double _d = 2.0;
final FireNoiseFn _nl = noiseFor(_d);
final int _smoke1 = hex('#5b5566');
const int _spin = 3;

class _OrbitEmberSeed {
  final double v0, rise, a, w, out, life;
  final bool big;
  _OrbitEmberSeed(
      this.v0, this.rise, this.a, this.w, this.out, this.life, this.big);
}

class _OrbitEmber {
  final double x, y, z, k, vx, vy;
  final bool big;
  _OrbitEmber(this.x, this.y, this.z, this.k, this.vx, this.vy, this.big);
}

class _SmokeSeed {
  final double a, life, s, vy;
  _SmokeSeed(this.a, this.life, this.s, this.vy);
}

class _FlungSeed {
  final double v, side, sp, life, s, f;
  _FlungSeed(this.v, this.side, this.sp, this.life, this.s, this.f);
}

final PureEffect fireTornadoEffect = PureEffect(
  meta: const EffectMeta(
    id: 'fire/fire-tornado',
    name: 'Fire tornado',
    desc:
        'A spinning funnel of fire: spiral bands turning round it, licks flung off its sides, a ring of flame whirling at its foot, embers orbiting it in and out of view.',
    category: 'fire',
    tags: ['fire', 'tornado', 'vortex', 'spell', 'aoe', 'loop'],
    size: (120, 152),
    origin: (60, 136),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#4a1712', '#8a1f17', '#c9281f', '#f2561d',
        '#ff8a2a', '#ffc23d', '#ffe26b', '#fff3a6', '#ffffff',
      ],
      'height': 80,
      'seed': 4,
    },
  ),
  onDraw: (p, t, o) {
    final f = fit(o.palette, 9);
    final h = hotFirst(f);
    final s = o.seed;
    final ht = o.numOpt('height', 80.0);
    final ph = t / _d;
    double n(double rate, [int sd = 0, double off = 0.0]) =>
        _nl(t, rate, sd, off);
    final glowCol = mix(mix(h[3], h[4], 0.5), kWhite, 0.25);
    final smokeCol = mix(_smoke1, h[6], 0.25);
    final emb = [h[1], h[2], h[4], h[6]];

    double cx(double v, [double? tt]) {
      final tm = tt ?? t;
      return 3.2 * math.sin(v * 4.2 - (tm / _d) * tau * 2.0) * v +
          2.0 * math.sin((tm / _d) * tau) * v;
    }

    double rad(double v) => 3.5 + 15.0 * math.pow(v, 1.35);
    double spin(double v, [double? tt]) =>
        ((tt ?? t) / _d) * tau * _spin + v * 5.5;

    final orbit = <_OrbitEmber>[];
    looped<_OrbitEmberSeed>(
      t,
      _d,
      30,
      s + 500,
      (r, _) {
        final v0 = r.range(0.02, 0.7);
        final rise = r.range(0.12, 0.3);
        final a = r.range(0.0, tau);
        final w = r.range(4.0, 7.0);
        final out = r.range(4.0, 12.0);
        final life = r.range(1.2, 2.4);
        return (
          _OrbitEmberSeed(v0, rise, a, w, out, life, r.chance(0.2)),
          life,
        );
      },
      (q, age, _) {
        final v = q.v0 + q.rise * age;
        final vv = math.min(1.0, v);
        final rRad = rad(vv) + q.out + age * 4.0;
        final a = q.a + q.w * age;
        final k = 1.0 - age / q.life;
        final ex = cx(vv, t) + math.cos(a) * rRad;
        final ey = -v * ht + math.sin(a) * rRad * 0.28;
        final ez = math.sin(a);
        orbit.add(
          _OrbitEmber(
            ex,
            ey,
            ez,
            k,
            -math.sin(a) * rRad * q.w,
            math.cos(a) * rRad * q.w * 0.28,
            q.big,
          ),
        );
      },
    );

    void embers(bool front) {
      for (final e in orbit) {
        if ((e.z >= 0.0) != front || e.k <= 0.0) continue;
        final rawSp = hypot(e.vx, e.vy);
        final sp = rawSp == 0.0 ? 1.0 : rawSp;
        final l = math.min(5.0, 1.0 + sp * 0.025);
        final c = e.k > 0.6 ? emb[0] : (e.k > 0.3 ? emb[1] : emb[2]);
        p.lineShaded(
          e.x - (e.vx / sp) * l,
          e.y - (e.vy / sp) * l,
          e.x,
          e.y,
          color: (double u) => u > 0.6 ? c : (front ? emb[3] : h[7]),
        );
        if (front) {
          p.glow(e.x, e.y, 4, c, 0.4 * e.k);
        } else {
          p.glow(e.x, e.y, 3, c, 0.15 * e.k);
        }
      }
    }

    void ring(bool front) {
      for (var i = 0; i < 12; i++) {
        final a = (i / 12.0) * tau + (t / _d) * tau * 2.0;
        final z = math.sin(a);
        if ((z >= 0.0) != front) continue;
        final nn = (s * 3 + i) * 19;
        final rRad = 12.0 + 2.0 * n(2.0, nn);
        final x = math.cos(a) * rRad;
        final y = z * rRad * 0.25;
        final fh = (5.0 + 5.0 * (0.5 + 0.5 * n(5.0, nn + 1))) *
            (front ? 1.0 : 0.8);
        flameTongue(
          p,
          x,
          y,
          fh,
          1.6,
          -math.cos(a + math.pi / 2.0) * 3.0,
          n,
          nn,
          h,
          layers: front ? fireLayers : fireBackLayers,
        );
      }
    }

    looped<_SmokeSeed>(
      t,
      _d,
      20,
      s + 300,
      (r, _) {
        final a = r.range(0.0, tau);
        final life = r.range(1.2, 2.0);
        return (_SmokeSeed(a, life, r.range(2.5, 4.0), -r.range(12.0, 22.0)), life);
      },
      (q, age, _) {
        final rRad = rad(1.0) * (0.8 + age * 0.5);
        final a = q.a + age * 3.0;
        final sx = cx(1.0, t - age) + math.cos(a) * rRad;
        final sy = -ht - 2.0 + q.vy * age + math.sin(a) * rRad * 0.25;
        smokePuff(p, sx, sy, 1.0 - age / q.life, q.s, smokeCol);
      },
    );

    floorLight(p, 0, 0.5, 40, 8, glowCol, 0.4);
    embers(false);
    ring(false);

    final fl = 0.85 + 0.15 * n(7.0, s + 1);
    for (var y = 0; y >= -ht * 1.2; y--) {
      final v = -y / ht;
      final vv = math.min(1.0, v);
      final c = cx(vv);
      final rRad = rad(vv) * (1.0 + 0.08 * n(3.0, s + 2, y * 0.1));
      final sp = spin(v);
      final cut = clamp((v - 0.72) / 0.42);
      final lickL = 0.3 *
          math.max(0.0, pnoise(-y * 0.22 + ph * 18.0, 18, s + 3));
      final lickR = 0.3 *
          math.max(0.0, pnoise(-y * 0.22 + ph * 18.0 + 9.0, 18, s + 4));
      final x0 = (c - rRad * 1.35).floor();
      final x1 = (c + rRad * 1.35).ceil();
      for (var x = x0; x <= x1; x++) {
        final dx = (x + 0.5 - c) / rRad;
        final edge = 1.0 + (dx < 0.0 ? lickL : lickR);
        if (dx.abs() > edge) continue;
        final th = math.asin(clamp(dx, -1.0, 1.0));
        final depth = math.cos(th);
        final tear =
            0.18 * pnoise(y * 0.45 + dx * 2.0 - ph * 30.0, 30, s + 6);
        final bandVal = 0.5 + 0.5 * math.sin((th + sp + tear) * 3.0);
        final streak = bandVal * bandVal * bandVal;
        if (cut > 0.0 &&
            bandVal <
                0.35 +
                    cut * 0.6 +
                    0.1 * pnoise(x * 0.7 + ph * 20.0, 20, s + 5)) {
          continue;
        }
        var heat = 0.22 +
            0.36 * depth +
            0.5 * streak -
            0.22 * vv +
            0.1 * (1.0 - vv) -
            0.25 * cut;
        if (dx.abs() > 1.0) heat = 0.3 - (dx.abs() - 1.0) * 1.5;
        heat *= fl;
        final col = heat > 0.95
            ? h[0]
            : heat > 0.82
                ? h[1]
                : heat > 0.7
                    ? h[2]
                    : heat > 0.58
                        ? h[3]
                        : heat > 0.46
                            ? h[4]
                            : heat > 0.34
                                ? h[5]
                                : heat > 0.2
                                    ? h[6]
                                    : h[7];
        p.px(x, y, col);
      }
      if (y % 10 == 0 && v <= 1.0) {
        p.glow(c, y, rRad * 2.0 + 8.0, glowCol, 0.22 * fl);
      }
    }

    looped<_FlungSeed>(
      t,
      _d,
      70,
      s + 200,
      (r, _) {
        final v = r.range(0.05, 0.95);
        final side = r.sign().toDouble();
        final sp = r.range(20.0, 50.0);
        final life = r.range(0.25, 0.5);
        return (_FlungSeed(v, side, sp, life, r.range(1.4, 2.8), r.next()), life);
      },
      (q, age, _) {
        final tb = t - age;
        final x0 = cx(q.v, tb) + q.side * rad(q.v);
        final y0 = -q.v * ht;
        final (x, y, _, _) =
            drift(x0, y0, q.side * q.sp, -q.sp * 0.6, age, 0.0, -60.0, 3.0, 3.0);
        firePuff(
            p, x, y, 1.0 - age / q.life, q.s, q.f, h, 0.1, -q.side * 0.6, -0.8);
      },
    );

    ring(true);
    embers(true);
    p.glow(0, -ht * 0.5, 80, glowCol, 0.28 * fl);
    p.glow(0, -6, 18, h[2], 0.3 * fl);
  },
);
