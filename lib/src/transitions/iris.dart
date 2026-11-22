// The motes drifting in the light and the glints follow Sprite Fusion's open-source holy-light and sparkle
// (https://www.spritefusion.com/pixel-art-vfx/sparkle), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'transitions_lib.dart';

const double _duration = 2.2;
const double _close = 0.62;
const double _snap = 0.9;
const double _shut = 0.99;
const double _pop = 1.2;
const double _open = 1.75;
const double _rs = 24.0;
const double _rw = 5.0;
const double _glo = 16.0;

class _IrisSim extends BaseEffectSim {
  final List<int> c;
  final int ink;
  final Rng r;
  final double fx;
  final double fy;
  final double r0;
  final Particles ps;
  final Lights lights = Lights();
  double t = 0.0;
  bool shut = false;
  bool popped = false;
  late double prevR;
  final double end = _duration - 0.05;

  factory _IrisSim.create(Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final ink = hex(o['color'] ?? '#0b0a10');
    final r = Rng(o.seed);
    final focusList = o['focus'] as List?;
    final fx = focusList != null && focusList.isNotEmpty
        ? (focusList[0] as num).toDouble()
        : 160.0;
    final fy = focusList != null && focusList.length > 1
        ? (focusList[1] as num).toDouble()
        : 100.0;
    var r0 = 0.0;
    for (final (cx, cy) in const [
      (0.0, 0.0),
      (kScreenW * 1.0, 0.0),
      (0.0, kScreenH * 1.0),
      (kScreenW * 1.0, kScreenH * 1.0),
    ]) {
      final d = hypot(cx - fx, cy - fy);
      if (d > r0) r0 = d;
    }
    r0 += _rw + 2.0;
    final ps = Particles(rng: r, sparks: [kWhite, c[6], c[5], c[4]]);
    return _IrisSim._(c, ink, r, fx, fy, r0, ps);
  }

  _IrisSim._(this.c, this.ink, this.r, this.fx, this.fy, this.r0, this.ps) {
    prevR = r0;
  }

  double _radius(double t) {
    if (t < _close) {
      return _rs + (r0 - _rs) * (1.0 - Ease.inOutCubic(t / _close));
    }
    if (t < _snap) {
      return _rs +
          math.sin((t - _close) * 22.0) *
              0.8 *
              (1.0 - (t - _close) / (_snap - _close));
    }
    if (t < _shut) {
      return _rs * (1.0 - Ease.inCubic((t - _snap) / (_shut - _snap)));
    }
    if (t < _pop) return 0.0;
    return r0 * Ease.outQuart(clamp((t - _pop) / (_open - _pop)));
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final rad = _radius(t);
    if (t > _close - 0.25 && t < _snap && r.chance(0.25)) {
      final a = r.range(0.0, tau);
      final d = math.sqrt(r.next()) * rad * 0.9;
      ps.spawn(
        P.ember,
        fx + math.cos(a) * d,
        fy + math.sin(a) * d,
        r.range(-6.0, 6.0),
        -r.range(4.0, 14.0),
        r.range(0.4, 0.8),
        0,
        1.0,
      );
    }
    if (t > _close - 0.1 && t < _snap && r.chance(0.3)) {
      final a = r.range(0.0, tau);
      ps.spawn(
        P.star,
        fx + math.cos(a) * (rad + 1.0),
        fy + math.sin(a) * (rad + 1.0),
        0.0,
        0.0,
        r.range(0.2, 0.4),
        r.chance(0.5) ? kWhite : c[6],
        r.range(1.0, 2.4),
      );
    }
    if (!shut && t >= _shut) {
      shut = true;
      lights.add(fx, fy, 50.0, c[5], 0.7, 0.3);
    }
    if (!popped && t >= _pop) {
      popped = true;
      lights.add(fx, fy, 140.0, c[5], 0.7, 0.45);
      lights.add(fx, fy, 50.0, kWhite, 0.9, 0.12);
      for (var i = 0; i < 40; i++) {
        final a = r.range(0.0, tau);
        final v = r.range(150.0, 420.0);
        ps.spawn(
          P.spark,
          fx + math.cos(a) * 3.0,
          fy + math.sin(a) * 3.0,
          math.cos(a) * v,
          math.sin(a) * v,
          r.range(0.2, 0.5),
        );
      }
    }
    if (t > _pop && t < _open - 0.1) {
      final vr = (rad - prevR) / dt;
      for (var k = 0; k < 2; k++) {
        if (!r.chance(0.6)) continue;
        final a = r.range(0.0, tau);
        final x = fx + math.cos(a) * rad;
        final y = fy + math.sin(a) * rad;
        if (x < 0.0 || y < 0.0 || x >= kScreenW || y >= kScreenH) continue;
        ps.spawn(
          P.mote,
          x,
          y,
          math.cos(a) * vr * 0.35,
          math.sin(a) * vr * 0.35,
          math.min(r.range(0.2, 0.45), end - t),
          r.chance(0.5) ? c[6] : c[5],
          0.7,
        );
      }
    }
    prevR = rad;
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p0) {
    final p = clipTo(p0);
    final rad = _radius(t);
    final hot = t >= _pop
        ? 1.0 - smooth(_pop, _open, t)
        : (t < _snap ? 0.45 + 0.25 * smooth(_close - 0.2, _close, t) : 0.7);
    final rw = _rw + (t >= _pop ? 3.0 * hot : 0.0);

    if (t < _open + 0.05 && !(t >= _shut && t < _pop && rad <= 0.0)) {
      for (var y = 0; y < kScreenH; y++) {
        final dy = y + 0.5 - fy;
        final rr = rad + rw;
        final xo = math.sqrt(math.max(0.0, rr * rr - dy * dy));
        if (xo <= 0.0) {
          fastRect(p0, 0.0, y.toDouble(), kScreenW.toDouble(), 1.0, ink);
          continue;
        }
        final a0 = clampInt((fx - xo).floor(), 0, kScreenW);
        final b1 = clampInt((fx + xo).ceil(), 0, kScreenW);
        if (a0 > 0) {
          fastRect(p0, 0.0, y.toDouble(), a0.toDouble(), 1.0, ink);
        }
        if (b1 < kScreenW) {
          fastRect(
            p0,
            b1.toDouble(),
            y.toDouble(),
            (kScreenW - b1).toDouble(),
            1.0,
            ink,
          );
        }
        final g = rad > _glo
            ? math.sqrt(math.max(0.0, (rad - _glo) * (rad - _glo) - dy * dy))
            : 0.0;
        for (var x = a0; x < b1; x++) {
          final dx = x + 0.5 - fx;
          if (dx.abs() < g) continue;
          final d = hypot(dx, dy) - rad;
          if (d >= 0.0) {
            final q = d / rw;
            final lit = 0.5 - 0.5 * (dx * 0.7 + dy * 0.7) / (rad + d + 0.01);
            final h = hot * (0.55 + 0.6 * lit);
            p0.px(
              x.toDouble(),
              y.toDouble(),
              q >= 1.0
                  ? ink
                  : (q < 0.2
                      ? (h > 0.5 ? kWhite : (h > 0.3 ? c[6] : c[5]))
                      : (q < 0.4
                          ? (h > 0.38 ? c[6] : c[5])
                          : (q < 0.65
                              ? (h > 0.3 ? c[5] : c[4])
                              : (q < 0.85 ? c[3] : c[2])))),
            );
            if (q < 0.5) {
              p0.light(x.toDouble(), y.toDouble(), c[5], 0.45 * h * (1.0 - q * 2.0));
            }
          } else if (d > -_glo) {
            final kd = 1.0 + d / _glo;
            p0.light(
              x.toDouble(),
              y.toDouble(),
              c[5],
              (0.18 + 0.3 * hot) * kd * kd,
            );
          }
        }
      }
    } else if (t >= _shut && t < _pop) {
      fastRect(p0, 0.0, 0.0, kScreenW.toDouble(), kScreenH.toDouble(), ink);
    }

    if (rad > 0.0 && rad < 80.0 && t < _shut) {
      final k = 1.0 - rad / 80.0;
      p.glow(fx, fy, rad * 1.15 + 6.0, c[5], 0.18 + 0.32 * k);
      p.glow(fx, fy, rad * 0.6 + 3.0, c[6], 0.25 * k);
    }
    if (t > 0.08 && t < _snap) {
      final a = -2.4 + ((t - 0.08) / (_snap - 0.08)) * tau;
      final gx = fx + math.cos(a) * (rad + 1.0);
      final gy = fy + math.sin(a) * (rad + 1.0);
      if (gx > 2.0 && gy > 2.0 && gx < kScreenW - 2 && gy < kScreenH - 2) {
        transitionGlint(
          p,
          gx,
          gy,
          7.0 + 3.0 * math.sin(t * 9.0),
          t * 3.0,
          c[6],
          c[5],
          0.9,
        );
      }
    }
    final s = t - _shut;
    if (s > -0.06 && s < 0.22) {
      transitionGlint(
        p,
        fx,
        fy,
        14.0 * (1.0 - (s + 0.01).abs() / 0.23),
        s * 4.0,
        c[6],
        c[5],
      );
    }
    final u = t - _pop;
    if (u >= 0.0 && u < 0.18) {
      transitionGlint(
        p,
        fx,
        fy,
        20.0 * (1.0 - u / 0.18),
        0.4 - u * 3.0,
        c[6],
        c[5],
      );
      p.glow(fx, fy, 60.0, kWhite, 0.6 * (1.0 - u / 0.18));
    }
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect irisEffect = SimulatedEffect(
  meta: screenMeta(
    id: 'transitions/iris',
    name: 'Iris',
    desc:
        'A lit iris closes onto a warm spotlight where dust drifts, holds as its rim twinkles, snaps shut into a glint, then pops open from a flash with a white-hot rim throwing sparks.',
    tags: const ['iris', 'circle', 'spotlight', 'wipe'],
    duration: _duration,
    options: const {
      'palette': [
        '#1c140c',
        '#3b2a18',
        '#6e5233',
        '#a8875a',
        '#d9bd8a',
        '#f3e2bd',
        '#fff7e8',
        '#ffffff',
      ],
      'focus': [160, 100],
      'seed': 1,
    },
  ),
  onCreate: _IrisSim.create,
);
