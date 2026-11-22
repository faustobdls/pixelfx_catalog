// The cut's tapered smear (white at the rim, cooling down the ramp with age), the dotted trace it leaves, the
// tip glint, the sparks off the end and the shavings flung off the line are adapted from Sprite Fusion's
// open-source slash (https://www.spritefusion.com/pixel-art-vfx/slash), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'transitions_lib.dart';

const double _duration = 1.7;
const double _sl = 0.55;
final double _cs = 1.0 / hypot(1.0, _sl);
const double _halo = 18.0;
const double _t0 = 0.06;
const double _sweep = 0.62;
const double _e0 = -(kScreenH / 2.0) * _sl - 4.0;
const double _e1 = kScreenW + (kScreenH / 2.0) * _sl + 24.0;
const double _cut = 0.84;
const double _csw = 0.07;
const double _chold = 0.05;
const double _ctrail = 0.12;
const double _slip = _cut + 0.12;
const double _split = _cut + _csw + _chold + _ctrail;

double _edgeAt(double t) =>
    _e0 + (_e1 - _e0) * Ease.outCubic(clamp((t - _t0) / _sweep));

double _speedAt(double t) {
  if (t < _t0 || t > _t0 + _sweep) return 0.0;
  final d = 1.0 - (t - _t0) / _sweep;
  return ((_e1 - _e0) * 3.0 * d * d) / _sweep;
}

double _xAt(double e, double y) => e + (kScreenH / 2.0 - y) * _sl;

class _SlashHalf {
  final int s;
  final List<(double, double)> pts;
  final double mx;
  final double my;
  final double spin;

  const _SlashHalf({
    required this.s,
    required this.pts,
    required this.mx,
    required this.my,
    required this.spin,
  });
}

class _SlashWipeSim extends BaseEffectSim {
  final List<int> c;
  final int ink;
  final Rng r;
  final Particles ps;
  final Lights lights = Lights();
  final double ux;
  final double uy;
  final double nx;
  final double ny;
  final (double, double) ptA;
  final (double, double) ptB;
  final double lc;
  final List<_SlashHalf> halves;
  double t = 0.0;
  double acc = 0.0;
  bool entered = false;
  bool tipped = false;
  bool split = false;
  final double end = _duration - 0.05;

  factory _SlashWipeSim.create(Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final ink = hex(o['color'] ?? '#0b0a10');
    final r = Rng(o.seed);
    final sparksOpt = (o['sparks'] as List<Object?>?) ??
        const ['#fff3a6', '#ffe26b', '#ff8a2a', '#f2561d'];
    final ps = Particles(
      rng: r,
      sparks: [for (final s in sparksOpt) if (s != null) hex(s)],
    );
    final th = r.range(0.42, 0.56);
    final ux = math.cos(th);
    final uy = math.sin(th);
    final nx = uy;
    final ny = -ux;
    final cx = kScreenW / 2.0 + r.range(-24.0, 24.0);
    final cy = kScreenH / 2.0 + r.range(-10.0, 10.0);
    const area = <(double, double)>[
      (-24.0, -24.0),
      (kScreenW + 24.0, -24.0),
      (kScreenW + 24.0, kScreenH + 24.0),
      (-24.0, kScreenH + 24.0),
    ];
    final ends = [-1, 1].map((s) {
      var lo = 0.0;
      var hi = 400.0;
      for (var k = 0; k < 30; k++) {
        final m = (lo + hi) / 2.0;
        final x = cx + s * ux * m;
        final y = cy + s * uy * m;
        if (x >= 0.0 && x <= kScreenW && y >= 0.0 && y <= kScreenH) {
          lo = m;
        } else {
          hi = m;
        }
      }
      return (cx + s * ux * lo, cy + s * uy * lo);
    }).toList();
    final ptA = ends[0];
    final ptB = ends[1];
    final lc = hypot(ptB.$1 - ptA.$1, ptB.$2 - ptA.$2);
    final halves = [1, -1].map((s) {
      final pts = halfPlane(area, cx, cy, s * nx, s * ny);
      var mx = 0.0;
      var my = 0.0;
      for (final (x, y) in pts) {
        mx += x / pts.length;
        my += y / pts.length;
      }
      return _SlashHalf(
        s: s,
        pts: pts,
        mx: mx,
        my: my,
        spin: s * r.range(0.5, 0.9),
      );
    }).toList();
    return _SlashWipeSim._(
      c: c,
      ink: ink,
      r: r,
      ps: ps,
      ux: ux,
      uy: uy,
      nx: nx,
      ny: ny,
      ptA: ptA,
      ptB: ptB,
      lc: lc,
      halves: halves,
    );
  }

  _SlashWipeSim._({
    required this.c,
    required this.ink,
    required this.r,
    required this.ps,
    required this.ux,
    required this.uy,
    required this.nx,
    required this.ny,
    required this.ptA,
    required this.ptB,
    required this.lc,
    required this.halves,
  });

  ({double dx, double dy, double rot, double sep}) _placeOf(_SlashHalf hf) {
    final slip = 5.0 *
        Ease.outCubic(clamp((t - _slip) / 0.12)) *
        (hf.s > 0 ? 1.0 : -0.4);
    final u = math.max(0.0, t - _split);
    final sep = 30.0 * u + 0.5 * 1500.0 * u * u;
    final rot = hf.spin * u * u;
    return (
      dx: ux * slip + hf.s * nx * sep,
      dy: uy * slip + hf.s * ny * sep,
      rot: rot,
      sep: sep,
    );
  }

  (double, double) _moved(
    _SlashHalf hf,
    ({double dx, double dy, double rot, double sep}) pl,
    (double, double) pt,
  ) {
    final cs = math.cos(pl.rot);
    final sn = math.sin(pl.rot);
    final lx = pt.$1 - hf.mx;
    final ly = pt.$2 - hf.my;
    return (
      hf.mx + lx * cs - ly * sn + pl.dx,
      hf.my + lx * sn + ly * cs + pl.dy,
    );
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final sp = _speedAt(t);
    final e = _edgeAt(t);
    if (!entered && t >= _t0) {
      entered = true;
      lights.add(4.0, 4.0, 60.0, c[5], 0.6, 0.25);
    }
    for (acc += sp * dt * 0.035; acc > 1.0; acc--) {
      final y = r.range(4.0, kScreenH - 4.0);
      final x = _xAt(e, y) - 1.0;
      final a0 = math.pi + r.range(-0.1, 0.6);
      final n = r.intRange(5, 10);
      if (x < 0.0 || x >= kScreenW) continue;
      for (var i = 0; i < n; i++) {
        final a = a0 + r.range(-0.75, 0.75);
        final v = r.range(0.2, 1.0) * (140.0 + 0.22 * sp);
        ps.spawn(
          P.spark,
          x,
          y + r.range(-2.0, 2.0),
          math.cos(a) * v,
          math.sin(a) * v,
          r.range(0.15, 0.4),
        );
        if (r.chance(0.4)) {
          ps.spawn(
            P.mote,
            x,
            y,
            math.cos(a) * v * 0.45,
            math.sin(a) * v * 0.45 - 20.0,
            r.range(0.2, 0.5),
            r.chance(0.5) ? c[6] : c[5],
            0.7,
          );
        }
      }
      lights.add(x, y, r.range(30.0, 46.0), c[5], 0.35, 0.14);
    }

    if (!tipped && t >= _cut + _csw) {
      tipped = true;
      for (var i = 0; i < 12; i++) {
        final a = math.atan2(uy, ux) + r.range(-0.5, 0.5);
        final v = r.range(150.0, 400.0);
        ps.spawn(
          P.spark,
          ptB.$1 - ux * 2.0,
          ptB.$2 - uy * 2.0,
          math.cos(a) * v,
          math.sin(a) * v,
          r.range(0.12, 0.35),
        );
      }
      for (var i = 0; i < 18; i++) {
        final k = r.range(0.1, 1.0);
        final x = ptA.$1 + (ptB.$1 - ptA.$1) * k;
        final y = ptA.$2 + (ptB.$2 - ptA.$2) * k;
        final s = r.sign();
        final v = r.range(30.0, 100.0);
        ps.spawn(
          P.mote,
          x,
          y,
          s * nx * v + ux * 20.0,
          s * ny * v - 10.0,
          r.range(0.25, 0.55),
          r.chance(0.5) ? c[5] : c[4],
          0.6,
        );
      }
      for (var i = 0; i < 5; i++) {
        final k = (i + 0.5) / 5.0;
        lights.add(
          ptA.$1 + (ptB.$1 - ptA.$1) * k,
          ptA.$2 + (ptB.$2 - ptA.$2) * k,
          46.0,
          c[5],
          0.45,
          0.3,
        );
      }
    }

    if (!split && t >= _split) {
      split = true;
      for (var i = 0; i < 46; i++) {
        final k = r.range(0.0, 1.0);
        final x = ptA.$1 + (ptB.$1 - ptA.$1) * k;
        final y = ptA.$2 + (ptB.$2 - ptA.$2) * k;
        final s = r.sign();
        final v = r.range(80.0, 320.0);
        final a = math.atan2(s * ny, s * nx) + r.range(-0.7, 0.7);
        ps.spawn(
          P.spark,
          x,
          y,
          math.cos(a) * v,
          math.sin(a) * v,
          math.min(r.range(0.15, 0.45), end - t),
        );
      }
      for (var i = 0; i < 6; i++) {
        final k = (i + 0.5) / 6.0;
        lights.add(
          ptA.$1 + (ptB.$1 - ptA.$1) * k,
          ptA.$2 + (ptB.$2 - ptA.$2) * k,
          56.0,
          c[5],
          0.5,
          0.35,
        );
      }
    }

    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p0) {
    final p = clipTo(p0);
    final n = c.length;
    if (t < _cut + _csw + _chold + 0.02 || t < _slip) {
      final e = _edgeAt(t);
      final sp = _speedAt(t);
      final ls = clamp(sp * 0.0065, 1.5, 8.0);
      final echo = clamp(sp / 900.0) * 0.6;
      for (var y = 0; y < kScreenH; y++) {
        final xe = _xAt(e, y + 0.5);
        final ia = clampInt((xe - (ls + 10.0) / _cs).floor(), 0, kScreenW);
        final ib = clampInt((xe + _halo / _cs).ceil(), 0, kScreenW);
        if (ia > 0) fastRect(p0, 0.0, y.toDouble(), ia.toDouble(), 1.0, ink);
        for (var x = ia; x < ib; x++) {
          final d = (xe - (x + 0.5)) * _cs;
          if (d < 0.0) {
            final u = 1.0 + d / _halo;
            p0.light(x.toDouble(), y.toDouble(), c[5], 0.32 * u * u);
            if (d > -4.0) {
              final d4 = 1.0 + d / 4.0;
              p0.light(x.toDouble(), y.toDouble(), kWhite, 0.3 * d4 * d4);
            }
            continue;
          }
          if (d < 1.0) {
            p0.px(x.toDouble(), y.toDouble(), kWhite);
          } else if (d < 2.0) {
            p0.px(x.toDouble(), y.toDouble(), c[6]);
          } else {
            final q = (d - 2.0) / ls;
            p0.px(
              x.toDouble(),
              y.toDouble(),
              q < 0.3
                  ? c[5]
                  : (q < 0.55
                      ? c[4]
                      : (q < 0.8 ? c[3] : (q < 1.0 ? c[2] : ink))),
            );
            if (echo > 0.0 && (d - ls - 7.0).abs() < 0.5 && (x + y) % 3 == 0) {
              p0.dot(x.toDouble(), y.toDouble(), c[4], echo);
            }
          }
          if (d < ls + 2.0) {
            p0.light(x.toDouble(), y.toDouble(), c[5], 0.3 * (1.0 - d / (ls + 2.0)));
          }
        }
      }
    }

    if (t >= _slip) {
      final heat = 1.0 - clamp((t - _cut - 0.05) / 0.5);
      for (final hf in halves) {
        final pl = _placeOf(hf);
        final pts = [for (final q in hf.pts) _moved(hf, pl, q)];
        final a = _moved(hf, pl, ptA);
        final b = _moved(hf, pl, ptB);
        final cs = math.cos(pl.rot);
        final sn = math.sin(pl.rot);
        final mx = hf.s * (nx * cs - ny * sn);
        final my = hf.s * (nx * sn + ny * cs);
        final rim = [
          heat > 0.55 ? kWhite : (heat > 0.25 ? c[6] : c[5]),
          heat > 0.4 ? c[6] : c[4],
          heat > 0.3 ? c[5] : c[3],
          heat > 0.3 ? c[4] : ink,
        ];
        final deep = clamp(1.0 + pl.sep * 0.5, 1.0, 4.0);
        fillConvexFn(p0, pts, (x, y) {
          final d = (x - a.$1) * mx + (y - a.$2) * my;
          if (d < deep) {
            if (d < 2.0) {
              p0.light(x, y, c[5], 0.4 * heat * (1.0 - d / 2.0));
            }
            return rim[math.max(0, d.floor())];
          }
          return ink;
        });
        if (heat > 0.0) {
          for (var i = 0; i < 8; i++) {
            final k = (i + 0.5) / 8.0;
            p.glow(
              a.$1 + (b.$1 - a.$1) * k,
              a.$2 + (b.$2 - a.$2) * k,
              12.0 + pl.sep * 0.15,
              c[5],
              0.3 * heat,
            );
          }
        }
      }
    }

    final u = t - _cut;
    if (u >= 0.0 && u < _csw + _chold + _ctrail + 0.25) {
      final head = lc * Ease.outExpo(clamp(u / _csw));
      final tail = lc * smooth(_csw + _chold, _csw + _chold + _ctrail, u);
      final age = clamp(u / (_csw + _chold + _ctrail));
      final wc = 3.6 * (1.0 - (tail / lc) * 0.55);
      final span = head - tail;
      final sn = nx.abs();
      if (span > 1.0 && tail < lc - 1.0 && t < _split) {
        for (var y = 0; y < kScreenH; y++) {
          final x0 = ptA.$1 + ((y + 0.5 - ptA.$2) * ux) / uy;
          final hw = (wc + 1.0) / sn;
          final xa = math.max(0, (x0 - hw).floor());
          final xb = math.min(kScreenW, (x0 + hw).ceil());
          for (var x = xa; x < xb; x++) {
            final px = x + 0.5 - ptA.$1;
            final py = y + 0.5 - ptA.$2;
            final s = px * ux + py * uy;
            final v = (s - tail) / span;
            if (v < 0.0 || v > 1.0) continue;
            final w = wc *
                math.pow(math.sin(math.pi * math.pow(v, 2.2)), 0.6);
            if (w < 0.35) continue;
            final q = (px * nx + py * ny).abs() / w;
            if (q > 1.0) continue;
            final ci = q < 0.34 && age < 0.5
                ? 0
                : (q * (n - 1) * 0.75 + age * 2.4 - v * 0.8 + 0.4 + 0.5)
                    .floor();
            p0.dot(
              x.toDouble(),
              y.toDouble(),
              c[n - 1 - clampInt(ci, 0, n - 1)],
              math.min(1.0, v / 0.4),
            );
            if (q < 0.5) {
              p0.light(x.toDouble(), y.toDouble(), c[5], 0.4 * (1.0 - age));
            }
          }
        }
      }
      if (tail > 2.0 && t < _split) {
        for (var s = 0.0; s < tail; s += 1.6) {
          p.dot(
            ptA.$1 + ux * s,
            ptA.$2 + uy * s,
            c[5],
            0.7 * (0.4 + (0.6 * s) / lc),
          );
        }
      }
      if (u < 0.3) {
        final hx = ptA.$1 + ux * head;
        final hy = ptA.$2 + uy * head;
        p.glow(hx, hy, 46.0, c[4], 0.55 * (1.0 - u / 0.3));
      }
      final g = u - _csw * 0.6;
      if (g > 0.0 && g < 0.24) {
        sparkle(
          p,
          ptB.$1 - ux * 3.0,
          ptB.$2 - uy * 3.0,
          11.0 * Ease.outBack(math.min(1.0, g / 0.05)) * (1.0 - g / 0.24),
          c[6],
          c[4],
          0.7,
        );
      }
    }
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect slashWipeEffect = SimulatedEffect(
  meta: screenMeta(
    id: 'transitions/slash-wipe',
    name: 'Slash wipe',
    desc:
        'A white-hot blade edge slices across the screen, light ahead of it and sparks spraying back over the cover; a second cut flashes through and the cover splits apart.',
    tags: const ['slash', 'blade', 'cut', 'sparks', 'wipe'],
    duration: _duration,
    options: const {
      'palette': [
        '#151a3d',
        '#212f6b',
        '#2c58aa',
        '#3a8bd8',
        '#62c8f4',
        '#b8c9e8',
        '#e8f1ff',
        '#ffffff',
      ],
      'sparks': ['#fff3a6', '#ffe26b', '#ff8a2a', '#f2561d'],
      'seed': 2,
    },
  ),
  onCreate: _SlashWipeSim.create,
);
