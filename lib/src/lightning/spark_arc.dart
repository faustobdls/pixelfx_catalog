// The arc's re-struck bowed shape, its halo-body-core inking, its flicker and the nodes where it roots follow
// Sprite Fusion's open-source lightning (https://www.spritefusion.com/pixel-art-vfx/lightning),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'lightning_lib.dart';

const int _fps = 30;
const int _n = 60;
const double _period = 2.0;
const double _snap = 1.42;
const double _h = 58.0;

final List<int> _steel =
    ['#151823', '#262c3b', '#3d4558', '#5f6a82', '#8f9bb2', '#d2daea']
        .map(hex)
        .toList(growable: false);
final List<int> _ceramic =
    ['#4b4458', '#857d96', '#c9c1d6', '#efe9f6'].map(hex).toList(growable: false);
final int _ash = hex('#6a6478');

Point2 _rodAt(int s, double h) => (s * (4.5 + (h / 60.0) * 19.5), -9.0 - h);
double _height(double t) =>
    1.5 + _h * math.pow(clamp(t / _snap), 1.35).toDouble();

final PureEffect sparkArcEffect = PureEffect(
  meta: const EffectMeta(
    id: 'lightning/spark-arc',
    name: 'Spark arc',
    desc:
        'A climbing arc between two rods: it strikes white at their narrow foot, climbs on rising heat as it stretches and bows, sputters and snaps at the top, then strikes again.',
    category: 'lightning',
    tags: [
      'lightning',
      'electric',
      'arc',
      'jacobs-ladder',
      'machine',
      'prop',
      'loop',
    ],
    size: (124, 120),
    origin: (62, 108),
    duration: 2.0,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': voltPalette,
      'sparks': plasmaSparks,
      'seed': 2,
    },
  ),
  onDraw: (Painter p, double t, Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final sparks =
        (o['sparks'] as List).cast<Object>().map(hex).toList(growable: false);
    final seed = o.seed;
    final f = (t * _fps + 1e-6).floor() % _n;
    final r = rng(seed, 1, f);
    final climbing = t < _snap;
    final h = _height(t);
    final u = clamp(t / _snap);
    final a = t - _snap;

    p.glow(0, -14, 50, c[3], climbing ? 0.2 + 0.15 * (1.0 - u) : 0.06);
    p.rect(-18, -3, 36, 3, _steel[1]);
    p.line(-18, -3, 17, -3, _steel[3]);

    for (final s in const [-1, 1]) {
      for (var y = -9; y < -3; y++) {
        final rib = (y & 1) == 0;
        for (var x = 2; x <= 6; x++) {
          p.px(
            s * x - (s < 0 ? 1 : 0),
            y,
            rib
                ? _ceramic[x < 4 ? 3 : (x < 6 ? 2 : 1)]
                : _ceramic[x < 5 ? 1 : 0],
          );
        }
      }
    }

    for (final s in const [-1, 1]) {
      for (var hh = 0.0; hh <= 60.0; hh += 0.5) {
        final (x, y) = _rodAt(s, hh);
        final tp =
            _snap * math.pow(clamp((hh - 1.5) / _h), 1.0 / 1.35).toDouble();
        final age = t >= tp ? t - tp : t - tp + _period;
        final hot = hh > _h + 2.0 ? 0.0 : math.exp(-age / 0.26);
        final hc = heatColor(hot * 1.05 - 0.12);
        p.px(x, y, hc != 0 ? hc : (s < 0 ? _steel[4] : _steel[3]));
        final hc2 = heatColor(hot * 0.6);
        p.px(
          x + s,
          y,
          hc != 0 && hot > 0.35
              ? (hc2 != 0 ? hc2 : _steel[2])
              : (s < 0 ? _steel[2] : _steel[1]),
        );
        if (hot > 0.3 && (jsRound(hh * 2.0) & 3) == 0) {
          p.glow(x, y, 5, hc != 0 ? hc : c[4], 0.25 * hot);
        }
      }
      final (tx, ty) = _rodAt(s, 60.0);
      p.circle(tx + s * 0.5, ty, 1.6, _steel[4]);
      p.px(tx + s * 0.5 - 0.5, ty - 1.0, _steel[5]);
    }

    if (climbing) {
      final (xl, yl) = _rodAt(-1, h);
      final (xr, yr) = _rodAt(1, h);
      final k0 = t < 1.0 / _fps ? 1.0 : 1.0 - 0.22 * u;
      final sput = u > 0.88 && r.next() < 0.25 ? 0.4 : 1.0;
      final k = k0 * sput * (0.82 + 0.18 * r.next());
      final bow = -(1.5 + 13.0 * u * u) * (0.8 + 0.4 * r.next());
      boltStrokeWith(
        p,
        bowed(r, xl, yl, xr, yr, bow, 0.18 + 0.12 * u, 0.12 + 0.25 * u),
        k,
        c,
        s: t < 1.0 / _fps ? 0.95 : 0.8,
        hero: t < 1.0 / _fps,
        light: 0.7,
      );
      p.glowLine(xl, yl + bow * 0.5, xr, yr + bow * 0.5, 12, c[4], 0.22 * k);
      for (final (x, y) in [(xl, yl), (xr, yr)]) {
        p.circle(x, y, 1.8 + 0.6 * k, c[5]);
        p.px(x, y, kWhite);
        p.glow(x, y, 12, c[5], 0.55 * k);
      }
      if (t < 0.1) p.glow(0, -11, 26, c[6], 0.45 * (1.0 - t / 0.1));
    } else if (a < 2.0 / _fps) {
      final (xl, yl) = _rodAt(-1, _h + 1.5);
      final (xr, yr) = _rodAt(1, _h + 1.5);
      for (final (x0, y0, s) in [(xl, yl, 1), (xr, yr, -1)]) {
        crackle(
          p,
          zigzag(
            r,
            x0,
            y0,
            x0 + s * r.range(5.0, 9.0),
            y0 - r.range(2.0, 6.0),
            0.4,
            0.3,
          ),
          0.7,
          c,
          0.4,
        );
      }
      p.glow(0, yl - 8, 30, c[4], 0.5);
    } else if (t > _period - 0.16) {
      if (r.next() < 0.7) {
        crackle(
          p,
          zigzag(
            r,
            -4.5,
            -10.5 - r.range(0.0, 2.0),
            4.5,
            -10.5 - r.range(0.0, 2.0),
            0.5,
            0.0,
          ),
          0.4 + 0.3 * r.next(),
          c,
          0.35,
        );
      }
    }

    for (var j = 0; j < 3; j++) {
      final born = ((j + 1) / 3.2) * _snap;
      final age = (((t - born) % _period) + _period) % _period;
      const life = 1.0;
      if (age >= life) continue;
      final y0 = -9.0 - _height(born) - 6.0;
      lightningPuff(
        p,
        (j % 2 != 0 ? 3.0 : -3.0) + math.sin(age * 3.0 + j) * 2.0,
        y0 - age * 20.0,
        1.8 + j * 0.3,
        age / life,
        mix(_ash, c[5], 0.3),
      );
    }

    void burst(
      double t0,
      int n,
      int salt,
      (double, double, double, double, double, double) Function(Rng q, int j)
          from,
    ) {
      final age = (((t - t0) % _period) + _period) % _period;
      for (var j = 0; j < n; j++) {
        final q = rng(seed, salt, j);
        final life = q.range(0.25, 0.6);
        if (age >= life) continue;
        final (x0, y0, a0, spread, sp0, sp1) = from(q, j);
        final ang = a0 + q.range(-spread, spread);
        final sp = q.range(sp0, sp1);
        final (x, y, vx, vy) = lightningFlight(
          x0,
          y0,
          math.cos(ang) * sp,
          math.sin(ang) * sp,
          age,
          floor: 0.0,
        );
        lightningSpark(p, x, y, vx, vy, 1.0 - age / life, sparks);
      }
    }

    burst(0.0, 12, 11, (q, j) {
      final (rx, ry) = _rodAt(j % 2 != 0 ? 1 : -1, 1.5);
      return (rx, ry, -math.pi / 2.0 + (j % 2 != 0 ? 0.6 : -0.6), 1.0, 60.0, 170.0);
    });
    burst(_snap, 14, 12, (q, j) {
      final (rx, _) = _rodAt(1, _h);
      return (rx * q.range(-0.8, 0.8), -9.0 - _h - 6.0, -math.pi / 2.0, 1.3, 50.0, 160.0);
    });
    for (final (k, tt) in const [(0, 0.45), (1, 0.8), (2, 1.15)]) {
      burst(tt, 2, 20 + k, (q, j) {
        final (rx, ry) = _rodAt(j % 2 != 0 ? 1 : -1, _height(tt));
        return (rx, ry, math.pi / 2.0, 0.5, 5.0, 30.0);
      });
    }

    if (climbing || a < 0.25) {
      p.glow(0, -9.0 - h - 3.0, 26, c[4], climbing ? 0.25 : 0.4 * (1.0 - a / 0.25));
    }
  },
);
