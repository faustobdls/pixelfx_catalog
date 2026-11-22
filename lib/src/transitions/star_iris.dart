// The twinkles (spinning glints at the tips, motes shed as it turns) follow Sprite Fusion's open-source sparkle
// (https://www.spritefusion.com/pixel-art-vfx/sparkle), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'transitions_lib.dart';

const double _duration = 2.2;
const double _close = 0.98;
const double _open0 = 1.16;
const double _open1 = 2.0;
const double _rmax = 430.0;
const double _inner = 0.46;
const double _rw = 4.0;

({double r, double a}) _starAt(double t) {
  if (t < _close) {
    return (
      r: _rmax * math.pow(1.0 - Ease.inOutQuad(t / _close), 1.3),
      a: -math.pi / 2.0 + Ease.inOutCubic(t / _close) * 1.6 * tau,
    );
  }
  if (t < _open0) return (r: 0.0, a: 0.0);
  final u = clamp((t - _open0) / (_open1 - _open0));
  return (
    r: _rmax * math.pow(Ease.inOutCubic(u), 1.15),
    a: -math.pi / 2.0 - Ease.inOutCubic(u) * 1.6 * tau,
  );
}

List<(double, double)> _points(double fx, double fy, double r, double a) {
  return List<(double, double)>.generate(10, (i) {
    final rr = i.isOdd ? r * _inner : r;
    final an = a + (i * math.pi) / 5.0;
    return (fx + math.cos(an) * rr, fy + math.sin(an) * rr);
  });
}

class _StarIrisSim extends BaseEffectSim {
  final List<int> c;
  final int ink;
  final Rng r;
  final double fx;
  final double fy;
  final Particles ps;
  final Lights lights = Lights();
  double t = 0.0;
  bool shut = false;
  bool opened = false;
  ({double r, double a}) prev = _starAt(0.0);
  final double end = _duration - 0.05;

  factory _StarIrisSim.create(Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final ink = hex(o['color'] ?? '#0b0a10');
    final r = Rng(o.seed);
    final focusList = o['focus'] as List?;
    final fx = focusList != null && focusList.isNotEmpty
        ? (focusList[0] as num).toDouble()
        : 160.0;
    final fy = focusList != null && focusList.length > 1
        ? (focusList[1] as num).toDouble()
        : 96.0;
    final ps = Particles(rng: r, sparks: [kWhite, c[6], c[5], c[4]]);
    return _StarIrisSim._(c, ink, r, fx, fy, ps);
  }

  _StarIrisSim._(this.c, this.ink, this.r, this.fx, this.fy, this.ps);

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final s = _starAt(t);
    final pts = _points(fx, fy, s.r, s.a);
    final spin = (s.a - prev.a) / dt;
    if (s.r > 2.0) {
      for (var i = 0; i < 10; i += 2) {
        final (x, y) = pts[i];
        if (x < 0.0 ||
            y < 0.0 ||
            x >= kScreenW ||
            y >= kScreenH ||
            !r.chance(0.35)) {
          continue;
        }
        final an = s.a + (i * math.pi) / 5.0;
        final v = spin * s.r * 0.25;
        ps.spawn(
          r.chance(0.6) ? P.star : P.mote,
          x,
          y,
          -math.sin(an) * v + math.cos(an) * 20.0,
          math.cos(an) * v + math.sin(an) * 20.0,
          math.min(r.range(0.25, 0.55), end - t),
          r.chance(0.5) ? c[6] : c[5],
          r.range(0.6, 1.8),
        );
      }
    }
    if (!shut && t >= _close) {
      shut = true;
      lights.add(fx, fy, 60.0, c[5], 0.7, 0.3);
    }
    if (!opened && t >= _open0) {
      opened = true;
      lights.add(fx, fy, 120.0, c[5], 0.7, 0.4);
      lights.add(fx, fy, 40.0, kWhite, 0.8, 0.12);
      for (var i = 0; i < 24; i++) {
        final a = r.range(0.0, tau);
        final v = r.range(60.0, 200.0);
        ps.spawn(
          P.star,
          fx,
          fy,
          math.cos(a) * v,
          math.sin(a) * v,
          r.range(0.3, 0.6),
          r.chance(0.5) ? kWhite : c[6],
          r.range(0.6, 2.0),
        );
      }
    }
    prev = s;
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p0) {
    final p = clipTo(p0);
    final s = _starAt(t);
    if (t >= _close && t < _open0) {
      fastRect(p0, 0.0, 0.0, kScreenW.toDouble(), kScreenH.toDouble(), ink);
    } else if (s.r < _rmax - 2.0) {
      final pts = _points(fx, fy, s.r, s.a);
      for (var y = 0; y < kScreenH; y++) {
        final yc = y + 0.5;
        final xs = <double>[];
        for (var i = 0, j = 9; i < 10; j = i++) {
          final (xi, yi) = pts[i];
          final (xj, yj) = pts[j];
          if ((yi > yc) != (yj > yc)) {
            xs.add(xi + ((yc - yi) * (xj - xi)) / (yj - yi));
          }
        }
        xs.sort();
        var x = 0;
        for (var k = 0; k + 1 < xs.length; k += 2) {
          final a = clampInt((xs[k] + 0.5).floor(), 0, kScreenW);
          if (a > x) {
            fastRect(p0, x.toDouble(), y.toDouble(), (a - x).toDouble(), 1.0, ink);
          }
          x = math.max(x, clampInt((xs[k + 1] + 0.5).floor(), 0, kScreenW));
        }
        if (x < kScreenW) {
          fastRect(
            p0,
            x.toDouble(),
            y.toDouble(),
            (kScreenW - x).toDouble(),
            1.0,
            ink,
          );
        }
      }

      for (var i = 0, j = 9; i < 10; j = i++) {
        final (ax, ay) = pts[j];
        final (bx, by) = pts[i];
        final len = hypot(bx - ax, by - ay);
        if (len < 0.5) continue;
        final ux = (bx - ax) / len;
        final uy = (by - ay) / len;
        final nx = -uy;
        final ny = ux;
        final lit = nx * -0.6 + ny * -0.8 > 0.1;
        for (var sx = 0.0; sx <= len; sx += 0.5) {
          final x0 = ax + ux * sx;
          final y0 = ay + uy * sx;
          if (x0 < -_rw ||
              y0 < -_rw ||
              x0 > kScreenW + _rw ||
              y0 > kScreenH + _rw) {
            continue;
          }
          for (var d = 0.0; d < _rw; d += 0.5) {
            final col = d < 1.0
                ? (lit ? kWhite : c[6])
                : (d < 2.0 ? c[5] : (d < 3.0 ? c[4] : c[3]));
            p.px(x0 + nx * d, y0 + ny * d, col);
          }
          if (sx % 2.0 == 0.0) p.light(x0, y0, c[5], 0.5);
        }
      }

      for (var i = 0; i < 10; i += 2) {
        final (x, y) = pts[i];
        if (x < 2.0 || y < 2.0 || x > kScreenW - 2 || y > kScreenH - 2) {
          continue;
        }
        transitionGlint(
          p,
          x,
          y,
          5.0 + 3.0 * math.sin(t * 13.0 + i),
          t * 2.0 + i,
          c[6],
          c[5],
        );
      }
      if (s.r < 140.0) {
        p.glow(fx, fy, s.r * 0.7 + 8.0, c[5], 0.35 * (1.0 - s.r / 140.0));
      }
    }

    final u = t - _close;
    if (u > -0.05 && u < 0.2) {
      transitionGlint(
        p,
        fx,
        fy,
        14.0 * (1.0 - u.abs() / 0.2),
        u * 4.0,
        c[6],
        c[5],
      );
    }
    final v = t - _open0;
    if (v >= 0.0 && v < 0.16) {
      transitionGlint(
        p,
        fx,
        fy,
        18.0 * (1.0 - v / 0.16),
        0.3 - v * 5.0,
        c[6],
        c[5],
      );
      p.glow(fx, fy, 50.0, kWhite, 0.5 * (1.0 - v / 0.16));
    }
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect starIrisEffect = SimulatedEffect(
  meta: screenMeta(
    id: 'transitions/star-iris',
    name: 'Star iris',
    desc:
        'A five-point star iris spins shut on the middle of the screen, its gold rim lit and its tips twinkling and shedding motes; it closes on a glint and spins open again from a flash.',
    tags: const ['iris', 'star', 'gold', 'wipe'],
    duration: _duration,
    options: const {'palette': Pal.gold, 'focus': [160, 96], 'seed': 1},
  ),
  onCreate: _StarIrisSim.create,
);
