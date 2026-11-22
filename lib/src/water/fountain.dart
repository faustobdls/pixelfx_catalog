// The basin's caustic light (two warped sine nets, light where they cross zero) is adapted from Sprite Fusion's
// open-source bubbles (https://www.spritefusion.com/pixel-art-vfx/bubbles), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'water_lib.dart';

const double _d = 2.0;
const double _sy = 0.34;
const double _g = 600.0;
const double _rim = 10.0;
const double _rx = 36.0;
const double _inR = 29.5;
const double _jet = 54.0;
const int _arcsCount = 12;
const double _by = -_rx * _sy;
const double _level = _rim - 1.2;

class _Arc {
  final double a;
  final double vr;
  final double vh;
  final double tl;
  final double ca;
  final double sa;

  _Arc(this.a, this.vr, this.vh, this.tl, this.ca, this.sa);
}

List<_Arc> _buildArcs(int s) => List.generate(_arcsCount, (i) {
      final a = ((i + 0.5) / _arcsCount) * tau + rand(i, s) * 0.25;
      final vr = 38.0 + 14.0 * rand(i, s + 1);
      final vh = 30.0 + 26.0 * rand(i, s + 2);
      final tl = (vh + math.sqrt(vh * vh + 2.0 * _g * (_jet - _level))) / _g;
      return _Arc(a, vr, vh, tl, math.cos(a), math.sin(a));
    });

(double, double, double) _along(_Arc q, double tauStep) {
  final r = q.vr * tauStep;
  final h = _jet + q.vh * tauStep - 0.5 * _g * tauStep * tauStep;
  return (q.ca * r, _by + q.sa * r * _sy - h, h);
}

bool _inEll(double x, double y, double rx, double cy) {
  final ex = x / rx;
  final ey = (y - cy) / (rx * _sy);
  return ex * ex + ey * ey <= 1.0;
}

void _basin(Painter p, List<int> st, int half) {
  const cy = _by - _rim;
  const ry = _rx * _sy;
  p.shade(-_rx - 1.0, cy - ry - 1.0, _rx + 1.0, 1.0, (x, y, _) {
    if (_inEll(x, y, _rx, cy)) {
      if (_inEll(x, y, _inR, cy)) return null;
      final near = y > cy;
      if (near != (half > 0)) return null;
      final outer = !_inEll(x, y - 1.0, _rx, cy) ||
          !_inEll(x, y + 1.0, _rx, cy) ||
          !_inEll(x - 1.0, y, _rx, cy) ||
          !_inEll(x + 1.0, y, _rx, cy);
      final inner = _inEll(x, y - 1.0, _inR, cy) ||
          _inEll(x, y + 1.0, _inR, cy) ||
          _inEll(x - 1.0, y, _inR, cy) ||
          _inEll(x + 1.0, y, _inR, cy);
      final a = math.atan2((y - cy) / ry, x / _rx);
      final lit = -math.cos(a) * 0.65 - math.sin(a) * 0.45;
      return outer
          ? st[0]
          : (inner
              ? (y < cy ? st[2] : st[1])
              : (lit > 0.4
                  ? st[5]
                  : (lit > -0.05 ? st[4] : (lit > -0.45 ? st[3] : st[2]))));
    }
    if (half < 0 || x.abs() >= _rx) return null;
    final dx = x / _rx;
    final top = cy + math.sqrt(1.0 - dx * dx) * ry;
    final base = top + _rim;
    if (y < top || y > base) return null;
    final u = math.asin(clamp(dx)) * _rx * 0.62;
    final row = y - top;
    final course = row > _rim * 0.5 ? 1 : 0;
    final joint =
        ((((u + 40.0 + course * 4.5) / 9.0) % 1.0 + 1.0) % 1.0) < 0.1;
    var col = y > base - 1.0 || x.abs() > _rx - 1.0 || row < 1.0
        ? st[0]
        : (joint || (row - _rim * 0.5).abs() < 0.5
            ? st[1]
            : (dx < -0.4 ? st[4] : (dx < 0.3 ? st[3] : st[2])));
    if (row >= 1.0 && row < 2.0 && !joint) {
      col = dx < 0.0 ? st[2] : st[1];
    }
    return col;
  });
}

void _pool(Painter p, List<int> c, double ph) {
  const rx = _inR;
  const ry = rx * _sy;
  const cy = _by - _level;
  final tt = ph * tau;
  for (var yi = (cy - ry).floor(); yi < cy + ry; yi++) {
    for (var xi = -rx.ceil(); xi < rx; xi++) {
      final x = xi + 0.5;
      final y = yi + 0.5;
      final dx = x / rx;
      final dy = (y - cy) / ry;
      final d = dx * dx + dy * dy;
      if (d > 1.0) continue;
      p.blend(x, y, dy < -0.55 ? c[3] : c[1], dy < -0.55 ? 0.8 : 0.85);
      final u = x * 0.25 + 1.6 * math.sin(y * 0.6 + tt);
      final w = y * 0.7 + 1.6 * math.sin(x * 0.14 - tt * 2.0);
      final f = math.max(
            0.0,
            1.0 - (math.sin(u) + math.sin(w)).abs() * 2.6,
          ) *
          (1.0 - d);
      if (f > 0.35) p.light(x, y, c[5], 0.3 * f);
    }
  }
}

void _drawArc(Painter p, List<int> c, _Arc q, double ph, bool back) {
  (double, double)? prev;
  for (var tauStep = 0.0; tauStep <= q.tl; tauStep += 0.012) {
    final (x, y, _) = _along(q, tauStep);
    final u = tauStep / q.tl;
    if (prev != null && u < 0.66) {
      p.line(
        prev.$1,
        prev.$2,
        x,
        y,
        back
            ? (u < 0.25 ? c[5] : c[4])
            : (u < 0.2 ? kWhite : (u < 0.45 ? c[6] : c[5])),
      );
    }
    prev = (x, y);
  }
  final backColors = back
      ? [c[0], c[1], c[2], c[2], c[3], c[4], c[5], c[5]]
      : c;
  for (var k = 0; k < 6; k++) {
    final u = ((ph * 2.0 + k / 6.0) % 1.0) * 0.42 + 0.58;
    final tauStep = u * q.tl;
    final (x, y, _) = _along(q, tauStep);
    final vy = (q.vh - _g * tauStep) * -1.0 + q.sa * q.vr * _sy;
    bead(
      p,
      x,
      y,
      q.ca * q.vr,
      vy,
      back ? 1 : (k % 3 == 0 ? 2 : 1),
      backColors,
    );
  }
  final g = ((ph * 4.0 + q.a) % 1.0) * 0.6;
  final (gx, gy, _) = _along(q, g * q.tl);
  p.px(gx, gy, kWhite);
  if (!back) p.glow(gx, gy, 3, c[5], 0.3);
}

final PureEffect fountainEffect = PureEffect(
  meta: const EffectMeta(
    id: 'water/fountain',
    name: 'Fountain',
    desc:
        'A stone basin; a jet rises from its spout and blooms into glassy arcs that break into beads, fall back and plink into the water with rings.',
    category: 'water',
    tags: ['water', 'fountain', 'jet', 'basin', 'prop', 'ambient', 'loop'],
    size: (120, 104),
    origin: (60, 96),
    duration: 2.0,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': kWaterPalette,
      'seed': 3,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _d;
    final s = o.seed;
    final st = rockColors();
    final qList = _buildArcs(s);
    _basin(p, st, -1);
    _pool(p, c, ph);
    for (final q in qList) {
      if (q.sa < 0.0) _drawArc(p, c, q, ph, true);
    }
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _d;
    final s = o.seed;
    final st = rockColors();
    final qList = _buildArcs(s);
    final tt = ph * tau;
    p.shade(-3.5, _by - 16.0, 3.5, _by - _level + 0.5, (x, y, _) {
      final w = y < _by - 14.0 ? 3.4 : 2.2;
      if (x.abs() > w) return null;
      return x.abs() > w - 0.8 || y < _by - 15.5
          ? st[0]
          : (x < -0.6 ? st[4] : (x < 0.8 ? st[3] : st[2]));
    });
    p.shade(-3.0, _by - _jet - 1.0, 3.0, _by - 16.0, (x, y, _) {
      final v = (_by - 16.0 - y) / (_jet - 16.0);
      final sway = math.sin(tt * 2.0 + v * 5.0) * 0.5 * v;
      final w = 1.3 + 0.5 * v + 0.3 * math.sin(tt * 3.0 + y * 0.4);
      final q = (x - sway) / w;
      if (q.abs() > 1.0) return null;
      final n = tileNoise(x * 0.9, y * 0.15 + ph * 16.0, 0, 16, s);
      return q < -0.4 ? c[6] : (q < 0.35 ? (n > -0.3 ? kWhite : c[6]) : c[5]);
    });
    p.circle(0, _by - _jet - 1.0, 2.4, c[6]);
    p.circle(-0.4, _by - _jet - 1.5, 1.4, kWhite);
    p.glow(0, _by - _jet, 22, c[5], 0.46 + 0.06 * math.sin(tt * 4.0));
    p.glow(0, _by - _jet - 1.0, 8, kWhite, 0.3);
    cycle(t, _d, 10, s + 30, (g) => g.range(0.2, 0.35), (age, life, r, _) {
      final q = qList[(r.next() * _arcsCount).floor()];
      final u = r.range(0.1, 0.7);
      final (x, y, _) = _along(q, u * q.tl);
      final k = math.sin((math.pi * age) / life);
      if (q.sa < -0.3) return;
      p.px(x, y, kWhite);
      if (k > 0.6) {
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          p.px(x + dx, y + dy, c[6]);
        }
      }
      p.glow(x, y, 5, c[5], 0.4 * k);
    });
    for (var i = 0; i < 4; i++) {
      p.px(
        math.sin(tt * 3.0 + i * 1.7) * 2.5,
        _by - 16.0 - (i % 2),
        i % 2 != 0 ? c[6] : kWhite,
      );
    }
    for (final q in qList) {
      if (q.sa >= 0.0) _drawArc(p, c, q, ph, false);
    }
    for (var i = 0; i < qList.length; i++) {
      final q = qList[i];
      final f = (ph * 2.0 + rand(i, s + 9)) % 1.0;
      final (x, y, _) = _along(q, q.tl);
      ring(
        p,
        x,
        y,
        2.0 + f * 8.0,
        _sy,
        0.8 * math.pow(1.0 - f, 1.3),
        c,
        n: 1,
        half: 1,
        seed: i,
      );
      final g = (ph * 6.0 + rand(i, s + 10)) % 1.0;
      if (g < 0.15) p.px(x, y - 1.0, kWhite);
      if (g < 0.3 && q.sa > -0.2) {
        p.line(
          x,
          y - 1.0,
          x + (rand(i, s + 11) - 0.5) * 2.0,
          y - 1.0 - 3.0 * (1.0 - g / 0.3),
          c[6],
        );
      }
      p.glow(x, y, 6, c[5], 0.18 * (1.0 - g));
    }
    _basin(p, st, 1);
    cycle(t, _d, 16, s + 20, (g) => g.range(0.8, 1.4), (age, life, r, _) {
      final k = age / life;
      final a = r.range(0.0, tau);
      final rr = r.range(4.0, 20.0) + k * 6.0;
      final x = math.cos(a) * rr;
      final y = _by - _jet + r.range(-4.0, 16.0) + k * 10.0;
      if (k > 0.75 && r.next() < (k - 0.75) * 4.0) return;
      p.px(x, y, r.next() < 0.4 ? kWhite : c[6]);
    });
    p.glowLine(0, _by - 16.0, 0, _by - _jet, 10, c[5], 0.18);
    p.glow(0, _by - _level - 2.0, 46, c[4], 0.26 + 0.03 * math.sin(tt * 2.0));
    p.glow(0, _by - _level - 20.0, 30, c[5], 0.12);
  },
);
