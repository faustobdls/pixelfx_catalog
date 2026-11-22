// The re-struck filaments, the glass shell with its specular arc and the core follow Sprite Fusion's open-source
// energy orb (https://www.spritefusion.com/pixel-art-vfx/energy), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'lightning_lib.dart';

const int _fps = 30;
const int _n = 90;
const double _gx = 0.0;
const double _gy = -55.0;
const double _rg = 24.0;
final List<int> _baseCols =
    ['#0d0b12', '#17131f', '#231d2d', '#342b43', '#4b3f60', '#6b5c87']
        .map(hex)
        .toList(growable: false);

class _Tendril {
  final double a;
  final bool front;
  final double ex;
  final double ey;
  final bool rim;
  final double w1;
  final double w2;

  const _Tendril({
    required this.a,
    required this.front,
    required this.ex,
    required this.ey,
    required this.rim,
    required this.w1,
    required this.w2,
  });
}

_Tendril _tendril(int i, int n, double ph, int seed) {
  final a = ((i + 0.5) / n) * tau + 0.9 * loopNoise(ph, 0.9, seed + i * 7);
  final z = loopNoise(ph, 0.7, seed + i * 7 + 3);
  final rho =
      _rg * (0.72 + 0.28 * math.sqrt(1.0 - math.min(1.0, z * z * 1.6)));
  return _Tendril(
    a: a,
    front: z > -0.15,
    ex: _gx + math.cos(a) * rho,
    ey: _gy + math.sin(a) * rho,
    rim: rho > _rg * 0.93,
    w1: loopNoise(ph, 1.1, seed + i * 7 + 5),
    w2: loopNoise(ph, 1.3, seed + i * 7 + 6),
  );
}

void _pedestal(Painter p, List<int> c, double glow) {
  p.shade(-18, -32, 18, 0, (x, y, out) {
    final hw = y < -27.0 ? 7.0 : (y < -2.0 ? 9.0 + ((y + 27.0) / 25.0) * 6.0 : 16.0);
    if (x.abs() > hw) return null;
    final u = (x / hw + 1.0) / 2.0;
    if (y < -27.0) {
      out.c = y < -30.0
          ? (u < 0.6 ? c[4] : _baseCols[5])
          : (u < 0.3 ? _baseCols[5] : (u < 0.75 ? _baseCols[3] : _baseCols[1]));
      return null;
    }
    if (y >= -2.0) {
      out.c = y < -1.0 ? (u < 0.55 ? _baseCols[4] : _baseCols[2]) : _baseCols[1];
      return null;
    }
    final i = u < 0.1
        ? 2
        : u < 0.2
            ? 3
            : u < 0.3
                ? 5
                : u < 0.42
                    ? 4
                    : u < 0.6
                        ? 3
                        : u < 0.8
                            ? 2
                            : u < 0.92
                                ? 1
                                : 0;
    out.c = y < -24.0 && u < 0.5
        ? mix(_baseCols[i], c[4], 0.3 * glow)
        : (y > -5.0 ? _baseCols[math.max(0, i - 1)] : _baseCols[i]);
    return null;
  });
  p.px(9, -9, c[5]);
  p.glow(9, -9, 3, c[5], 0.5);
}

final PureEffect plasmaBallEffect = PureEffect(
  meta: const EffectMeta(
    id: 'lightning/plasma-ball',
    name: 'Plasma ball',
    desc:
        'A glass globe on a dark pedestal: wandering plasma tendrils reach from the core to the glass and fan out in bright feet where they touch it, lighting the stand and floor.',
    category: 'lightning',
    tags: ['lightning', 'electric', 'plasma', 'lamp', 'prop', 'loop'],
    size: (112, 104),
    origin: (56, 96),
    duration: 3.0,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#1a0828',
        '#3b0f5e',
        '#6a1d9c',
        '#a03ad6',
        '#d46cf2',
        '#f2a8ff',
        '#ffe2ff',
        '#ffffff',
      ],
      'tendrils': 9,
      'seed': 6,
    },
  ),
  onDraw: (Painter p, double t, Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final seed = o.seed;
    final f = (t * _fps + 1e-6).floor() % _n;
    final ph = f / _n;
    final n = o.intOpt('tendrils', 9);
    final r = rng(seed, 3, f);
    final pulse = 0.85 +
        0.15 * math.sin(ph * tau * 6.0) +
        0.1 * (r.next() - 0.5);
    final ts = [for (var i = 0; i < n; i++) _tendril(i, n, ph, seed)];

    p.glow(0, -6, 52, c[3], 0.22 * pulse);
    _pedestal(p, c, pulse);

    p.shade(_gx - _rg, _gy - _rg, _gx + _rg, _gy + _rg, (x, y, _) {
      final d = hypot(x - _gx, y - _gy);
      if (d < _rg - 0.5) {
        final ratio = d / _rg;
        final ratio4 = ratio * ratio * ratio * ratio;
        p.blend(x, y, d > _rg - 4.0 ? c[1] : c[0], 0.22 + 0.4 * ratio4);
      }
      return null;
    });
    p.glow(_gx, _gy, _rg + 14.0, c[3], 0.32 * pulse);
    p.glowRing(_gx, _gy, _rg - 1.0, 5, c[3], 0.22 * pulse);

    void drawTendril(_Tendril q, int i, bool bright) {
      final sx = _gx + math.cos(q.a) * 4.5;
      final sy = _gy + math.sin(q.a) * 4.5;
      final dx = q.ex - sx;
      final dy = q.ey - sy;
      final l = hypot(dx, dy);
      final nx = -dy / l;
      final ny = dx / l;
      final rr = rng(seed, 17, i, f);
      final m = math.max(4, jsRound(l / 2.2));
      final pts = <Point2>[];
      for (var j = 0; j <= m; j++) {
        final u = j / m;
        final w = 3.2 * q.w1 * math.sin(math.pi * u) +
            1.6 * q.w2 * math.sin(tau * u + i);
        final jit = j != 0 && j < m ? rr.range(-0.7, 0.7) : 0.0;
        pts.add((sx + dx * u + nx * (w + jit), sy + dy * u + ny * (w + jit)));
      }
      final paths = <BoltPath>[BoltPath(pts, 1.0)];
      for (var k = 0; k < 3; k++) {
        final (bx, by) = pts[m - 2];
        final a = q.a + (k - 1) * rr.range(0.25, 0.45);
        final fl = rr.range(2.5, 5.0);
        paths.add(
          BoltPath([
            (bx, by),
            (
              bx + math.cos(a) * fl * 0.5 + rr.range(-0.6, 0.6),
              by + math.sin(a) * fl * 0.5 + rr.range(-0.6, 0.6),
            ),
            (bx + math.cos(a) * fl, by + math.sin(a) * fl),
          ], 0.5),
        );
      }
      final hot = rr.next() < 0.2;
      for (final q2 in paths) {
        for (var j = 0; j < q2.pts.length - 1; j++) {
          final (ax, ay) = q2.pts[j];
          final (bx, by) = q2.pts[j + 1];
          final u = j / (q2.pts.length - 1);
          if (bright && q2.w >= 1.0) {
            p.line(ax + 1.0, ay + 1.0, bx + 1.0, by + 1.0, c[3]);
          }
          final col = !bright
              ? (q2.w >= 1.0 ? c[3] : c[2])
              : q2.w < 1.0
                  ? c[6]
                  : (hot || u > 0.75 || u < 0.2 ? c[6] : c[5]);
          p.line(ax, ay, bx, by, col);
          if (q2.w >= 1.0 && j % 3 == 0) {
            p.glow(
              ax,
              ay,
              bright ? 6 : 4,
              c[4],
              bright ? (hot ? 0.4 : 0.24) : 0.12,
            );
          }
        }
      }
      if (bright) {
        p.circle(q.ex, q.ey, 1.6, c[6]);
        p.px(q.ex, q.ey, kWhite);
        p.glow(q.ex, q.ey, 9, c[5], 0.55);
        if (q.rim) {
          for (var s = -1; s <= 1; s += 2) {
            p.px(
              _gx + math.cos(q.a + s * 0.09) * (_rg - 0.5),
              _gy + math.sin(q.a + s * 0.09) * (_rg - 0.5),
              c[6],
            );
          }
        }
      } else {
        p.glow(q.ex, q.ey, 6, c[4], 0.25);
      }
    }

    for (var i = 0; i < ts.length; i++) {
      if (!ts[i].front) drawTendril(ts[i], i, false);
    }

    final cr = 3.6 + 0.5 * pulse;
    p.circle(_gx, _gy, cr + 1.3, c[3]);
    p.circle(_gx, _gy, cr, c[5]);
    p.circle(_gx - 0.6, _gy - 0.6, cr * 0.55, c[6]);
    p.circle(_gx - 0.8, _gy - 0.8, cr * 0.25, kWhite);
    p.glow(_gx, _gy, 16, c[5], 0.65 * pulse);

    for (var i = 0; i < ts.length; i++) {
      if (ts[i].front) drawTendril(ts[i], i, true);
    }

    p.ring(_gx, _gy, _rg + 1.6, 1, c[1]);
    p.ringShaded(
      _gx,
      _gy,
      _rg + 0.6,
      1.1,
      color: (_, a) => a > 2.2 && a < 3.3
          ? c[5]
          : (a > 0.3 && a < 1.3 ? c[4] : c[3]),
    );
    p.arcShaded(
      _gx,
      _gy,
      _rg - 1.6,
      3.55,
      4.55,
      width: (_) => 1.3,
      color: (u, _) => u > 0.25 && u < 0.7 ? kWhite : c[6],
    );
    for (var a = 0.35; a < 1.15; a += 0.045) {
      p.dot(
        _gx + math.cos(a) * (_rg - 2.6),
        _gy + math.sin(a) * (_rg - 2.6),
        c[4],
        0.85,
      );
    }
    p.px(_gx - _rg * 0.42, _gy - _rg * 0.62, kWhite);
  },
);
