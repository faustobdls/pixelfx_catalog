// The flame-puff, smoke and spark recipe is adapted from Sprite Fusion's open-source explosion
// (https://www.spritefusion.com/pixel-art-vfx/explosion), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'fire_lib.dart';

const double _d = 1.6;
final FireNoiseFn _nl = noiseFor(_d);
final int _soot = hex('#2a2430');
const double _cough = 0.55;

double _flow(double te) {
  final u = wrap(te, _d);
  final expArg = (u - _cough - 0.2) / 0.05;
  return 1.0 -
      smooth(_cough, _cough + 0.04, u) *
          (1.0 - smooth(_cough + 0.1, _cough + 0.16, u)) +
      0.25 * math.exp(-(expArg * expArg));
}

class _CurlSeed {
  final double a0, rRad, w, up, dx, fl, sl, s, f;
  _CurlSeed(this.a0, this.rRad, this.w, this.up, this.dx, this.fl, this.sl,
      this.s, this.f);
}

class _DropSeed {
  final double d, vx, vy, life;
  _DropSeed(this.d, this.vx, this.vy, this.life);
}

class _CoughSparkSeed {
  final double born, a, v, life;
  _CoughSparkSeed(this.born, this.a, this.v, this.life);
}

class _CoughBlobSeed {
  final double born, v, vy, life, s;
  _CoughBlobSeed(this.born, this.v, this.vy, this.life, this.s);
}

final PureEffect flamethrowerEffect = PureEffect(
  meta: const EffectMeta(
    id: 'fire/flamethrower',
    name: 'Flamethrower',
    desc:
        'A pressurised jet shooting right: a blue pilot at the nozzle, a tight stream with surges racing down it, a sputter, burning drops falling off, a tip that curls up into smoke.',
    category: 'fire',
    tags: ['fire', 'flamethrower', 'stream', 'weapon', 'directional', 'loop'],
    size: (184, 104),
    origin: (30, 60),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#4a1712', '#8a1f17', '#c9281f', '#f2561d',
        '#ff8a2a', '#ffc23d', '#ffe26b', '#fff3a6', '#ffffff',
      ],
      'pilot': ['#1b2a8a', '#3a62e0', '#a8d4ff'],
      'reach': 112,
      'speed': 280,
      'seed': 3,
    },
  ),
  onDraw: (p, t, o) {
    final f = fit(o.palette, 9);
    final h = hotFirst(f);
    final pl = fit(o.rampOpt('pilot'), 3);
    final s = o.seed;
    final l = o.numOpt('reach', 112.0);
    final v = o.numOpt('speed', 280.0);
    double n(double rate, [int sd = 0, double off = 0.0]) =>
        _nl(t, rate, sd, off);
    final glowCol = mix(mix(h[3], h[4], 0.5), kWhite, 0.25);
    final sparks = [h[1], h[2], h[4], h[5]];
    final smokeCol = mix(_soot, h[7], 0.3);

    double cy(double x) {
      final xr = x / l;
      return 5.0 * xr * xr +
          n(1.2, s + 9, x * 0.02) * 2.2 * math.pow(xr, 1.5);
    }

    double widthAt(double x) =>
        (2.1 + 5.0 * math.pow(x / l, 0.7)) * _flow(t - x / v);

    final fire = <(double u, double x, double y, _CurlSeed q, double k)>[];
    final smoke = <(double u, double x, double y, _CurlSeed q)>[];
    looped<_CurlSeed>(
      t,
      _d,
      80,
      s + 100,
      (r, _) => (
        _CurlSeed(
          r.range(-0.3, 0.5),
          r.range(9.0, 15.0),
          r.range(5.0, 7.5),
          r.range(4.0, 12.0),
          r.range(-6.0, 2.0),
          r.range(0.38, 0.62),
          r.range(0.6, 1.0),
          r.range(2.4, 4.4),
          r.next(),
        ),
        1.6,
      ),
      (q, age, _) {
        final tb = t - age;
        final k = _flow(tb - l / v);
        if (k < 0.4) return;
        final x0 = l + q.dx;
        final y0 = cy(l);
        final a = math.min(age, q.fl) * q.w + q.a0;
        final x = x0 + q.rRad * math.sin(a);
        final y = y0 - q.rRad * (1.0 - math.cos(a)) - q.up * age;
        if (age < q.fl) {
          fire.add((age / q.fl, x, y, q, k));
          return;
        }
        if (age - q.fl < q.sl) {
          smoke.add((
            (age - q.fl) / q.sl,
            x - (age - q.fl) * 6.0,
            y - (age - q.fl) * 16.0,
            q,
          ));
        }
      },
    );

    for (final (u, x, y, q) in smoke) {
      smokePuff(p, x, y, 1.0 - u, q.s * 1.2, smokeCol, true, 0.85);
    }
    fire.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (u, x, y, q, k) in fire) {
      firePuff(p, x, y, 1.0 - u, q.s * (0.8 + 1.1 * u) * k, q.f, h, 0.1);
    }

    for (var i = 0; i < 13; i++) {
      final nn = (s * 3 + i) * 19;
      final ph = (i * 0.618 + t / _d).remainder(1.0);
      final x = 10.0 + ph * (l - 14.0);
      final k = _flow(t - x / v);
      if (k < 0.35) continue;
      final fh = (2.0 + 11.0 * (x / l)) *
          (0.55 + 0.6 * (0.5 + 0.5 * n(5.0, nn + 1))) *
          k *
          math.min(1.0, (1.0 - ph) * 6.0);
      flameTongue(
        p,
        x,
        cy(x) - widthAt(x) * 0.6,
        fh,
        1.1 + 1.6 * (x / l),
        -fh * 0.55,
        n,
        nn,
        h,
        layers: fireLayers,
      );
    }

    final pPeriod = (_d * 3.0 + 0.5).floor();
    final streamCols = [h[0], h[2], h[4], h[6], h[7]];
    for (var x = 0; x <= l; x++) {
      final c = cy(x.toDouble());
      final w = widthAt(x.toDouble()) *
          (1.0 + 0.15 * pnoise(x * 0.4 - (t / _d) * 24.0, 24, s + 4));
      if (w < 0.4) continue;
      final surge = wrap(x * 0.035 - (t / _d) * pPeriod, 1.0) < 0.12 ? 1 : 0;
      final y0 = (c - w - 1.0).floor();
      final y1 = (c + w + 1.0).ceil();
      for (var y = y0; y <= y1; y++) {
        final q = (y + 0.5 - c).abs() / w;
        if (q > 1.15) continue;
        var lvl = (q < 0.3
                ? 0
                : q < 0.55
                    ? 1
                    : q < 0.78
                        ? 2
                        : q < 1.0
                            ? 3
                            : 4) +
            (x > l * 0.45 && q < 0.55 ? 1 : 0);
        lvl = clampInt(lvl - surge, 0, 4);
        if (lvl == 4 &&
            pnoise(x * 0.5 + y * 7.3 - (t / _d) * 40.0, 40, s + 6) < 0.0) {
          continue;
        }
        p.px(x, y, streamCols[lvl]);
      }
      for (final ph in const [0.0, math.pi]) {
        final a = x * 0.22 - (t / _d) * math.pi * 2.0 * 9.0 + ph;
        final sy = c + math.sin(a) * w * 0.55;
        if (math.cos(a) > -0.1 && w > 1.2) {
          p.px(x, sy, math.cos(a) > 0.55 ? h[0] : h[1]);
        }
      }
    }

    final pk = _flow(t);
    for (var x = 0; x < 6; x++) {
      for (var y = -2; y <= 2; y++) {
        if (y.abs() <= 2.0 - x * 0.3) {
          p.px(x, y, y.abs() < 1 ? (x < 2 ? pl[2] : pl[1]) : pl[0]);
        }
      }
    }
    solidDisc(p, 1, 0, 1.6 * pk, kWhite);

    looped<_DropSeed>(
      t,
      _d,
      10,
      s + 200,
      (r, _) {
        final d = r.range(20.0, 95.0);
        final vx = r.range(0.3, 0.6);
        final vy = r.range(-25.0, 15.0);
        final life = r.range(0.35, 0.6);
        return (_DropSeed(d, vx, vy, life), life);
      },
      (q, age, _) {
        final tb = t - age;
        if (_flow(tb - q.d / v) < 0.5) return;
        (double, double, double, double) at(double a) =>
            drift(q.d, cy(q.d), v * q.vx, q.vy, a, 0.0, 260.0, 1.2, 0.5);
        for (var j = 4; j >= 1; j--) {
          final a = age - j * 0.035;
          if (a < 0.0) continue;
          final (x, y, _, _) = at(a);
          firePuff(
            p,
            x,
            y,
            1.0 - math.min(0.99, j * 0.18 + (age / q.life) * 0.4),
            1.8 - j * 0.25,
            0.3,
            h,
            0.06,
          );
        }
        final (x, y, _, _) = at(age);
        final k = 1.0 - age / q.life;
        p.px(x, y, k > 0.5 ? h[0] : h[2]);
        p.px(x + 1.0, y, h[3]);
        p.glow(x, y, 6, h[3], 0.45 * k);
      },
    );

    looped<_CoughSparkSeed>(
      t,
      _d,
      12,
      s + 300,
      (r, _) {
        final born = _cough + r.range(0.0, 0.08);
        final a = r.range(-0.8, 0.8);
        final v = r.range(120.0, 240.0);
        final life = r.range(0.2, 0.45);
        return (_CoughSparkSeed(born, a, v, life), life);
      },
      (q, age, _) {
        final u = wrap(t - age, _d);
        if ((u - q.born).abs() > 0.06) return;
        final (x, y, vx, vy) = drift(
          4.0,
          0.0,
          math.cos(q.a) * q.v,
          math.sin(q.a) * q.v,
          age,
          0.0,
          300.0,
          2.5,
          2.5,
        );
        sparkLine(p, x, y, vx, vy, 1.0 - age / q.life, sparks);
      },
    );

    looped<_CoughBlobSeed>(
      t,
      _d,
      5,
      s + 350,
      (r, _) {
        final born = _cough + r.range(0.01, 0.1);
        final v = r.range(90.0, 170.0);
        final vy = r.range(-30.0, 10.0);
        final life = r.range(0.25, 0.4);
        return (
          _CoughBlobSeed(born, v, vy, life, r.range(1.6, 2.6)),
          life,
        );
      },
      (q, age, _) {
        final u = wrap(t - age, _d);
        if ((u - q.born).abs() > 0.05) return;
        final (x, y, _, _) =
            drift(4.0, 0.0, q.v, q.vy, age, 0.0, 200.0, 2.0, 1.0);
        firePuff(p, x, y, 1.0 - age / q.life, q.s, 0.2, h, 0.1, -0.86, -0.5);
      },
    );

    final u = wrap(t, _d);
    final a = u - _cough;
    if (a > 0.0 && a < 0.7) {
      smokePuff(
          p, 8.0 + a * 20.0, -a * 18.0, 1.0 - a / 0.7, 3.0, smokeCol, false, 0.8);
    }

    p.glow(2, 0, 34 * pk, glowCol, 0.8 * pk);
    p.glow(2, 0, 9, pl[2], 0.45 * pk);
    for (var d = 8; d <= l; d += 8) {
      p.glow(d, cy(d.toDouble()), 12 + d * 0.16, glowCol,
          0.3 * _flow(t - d / v));
    }
    p.glow(l, cy(l) - 10.0, 52, glowCol, 0.34 * _flow(t - l / v));
  },
);
