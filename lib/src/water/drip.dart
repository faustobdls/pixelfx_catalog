// The bead swelling at the tip and the falling drop's tail follow Sprite Fusion's open-source blood
// (https://www.spritefusion.com/pixel-art-vfx/blood), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'water_lib.dart';

const double _sy = 0.28;
const double _g = 760.0;
const double _let = 0.78;
const int _prx = 20;
const double _rebound = 0.06;
const double _back = 0.2;

final List<int> _wet = [hex('#5d6a86'), hex('#9fb6d6')];

double _landAt(double h) => _let + math.sqrt((2.0 * h) / _g);

void _dripstone(Painter p, double h) {
  final st = rockColors();
  final top = -h - 14.0;
  p.shade(-24.0, top, 22.0, -h + 0.5, (x, y, _) {
    final under = top +
        7.0 +
        math.sin(x * 0.45) * 1.2 +
        math.sin(x * 1.3 + 1.0) * 0.6 -
        (x + 4.0).abs() * 0.12;
    final cone = -h - x.abs() * 1.25;
    final bottom = math.max(under, math.min(cone, -h));
    final span = x < 0.0 ? 24.0 : 22.0;
    if (y > bottom ||
        x.abs() > span - math.max(0.0, top + 3.0 - y) * 4.0) {
      return null;
    }
    final rim = y > bottom - 1.0 || x.abs() > span - 1.0;
    final lx = (x + 24.0) / 46.0;
    final v = (y - top) / 14.0;
    var col = rim
        ? st[0]
        : (v < 0.25
            ? st[1]
            : (y > under && x.abs() < 6.0
                ? (x < 0.0 ? st[4] : st[2])
                : (lx < 0.3 ? st[4] : (lx < 0.62 ? st[3] : st[2]))));
    if (!rim &&
        (x - 9.0 - (y - top) * 0.4).abs() < 0.5 &&
        v > 0.3 &&
        v < 0.7) {
      col = st[0];
    }
    return col;
  });
  for (var y = -h - 7.0; y < -h; y += 1.0) {
    p.px(-1, y, y > -h - 3.0 ? _wet[1] : _wet[0]);
  }
  p.px(-1, -h - 2.0, kWhite);
}

void _puddle(Painter p, List<int> c) {
  const ry = _prx * _sy;
  for (var yi = (-ry).floor(); yi < ry; yi++) {
    for (var xi = -_prx; xi < _prx; xi++) {
      final x = xi + 0.5;
      final y = yi + 0.5;
      final d = (x / _prx) * (x / _prx) + (y / ry) * (y / ry);
      if (d > 1.0) continue;
      p.blend(x, y, c[1], 0.72 * math.min(1.0, (1.0 - d) * 5.0));
    }
  }
  for (var xi = -_prx + 3; xi < _prx - 3; xi++) {
    final x = xi + 0.5;
    final y = -math.sqrt(1.0 - (x / _prx) * (x / _prx)) * ry;
    p.dot(x, y + 0.5, x.abs() < _prx * 0.5 ? c[4] : c[3], 0.95);
  }
}

final PureEffect dripEffect = PureEffect(
  meta: const EffectMeta(
    id: 'water/drip',
    name: 'Drip',
    desc:
        'A bead swells under a wet stone tip and catches the light, pinches off, falls stretched by its speed and plinks into a puddle with a crown, a ring and a tiny rebound.',
    category: 'water',
    tags: ['water', 'drip', 'drop', 'puddle', 'cave', 'ambient', 'loop'],
    size: (72, 88),
    origin: (36, 78),
    duration: 1.6,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': kWaterPalette,
      'height': 62,
      'source': true,
      'seed': 1,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final h = o.numOpt('height', 62);
    _puddle(p, c);
    final land = _landAt(h);
    final u = t - land;
    if (u >= 0.0) {
      ring(
        p,
        0.0,
        0.0,
        2.0 + 17.0 * Ease.outCubic(u / 0.75),
        _sy,
        1.1 * (1.0 - u / 0.75),
        c,
        n: 2,
        gap: 2.5,
        half: -1,
        seed: 1,
        wob: 0.4,
      );
    }
    final v = t - land - _rebound - _back;
    if (v >= 0.0) {
      ring(
        p,
        0.0,
        0.0,
        1.5 + 9.0 * Ease.outCubic(v / 0.5),
        _sy,
        0.9 * (1.0 - v / 0.5),
        c,
        n: 1,
        half: -1,
        seed: 2,
      );
    }
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final h = o.numOpt('height', 62);
    final land = _landAt(h);
    if (o.boolOpt('source', true)) _dripstone(p, h);
    if (t < _let) {
      final k = t / _let;
      final r = 0.7 + 2.3 * Ease.inQuad(k);
      final wob = 0.15 * math.sin(t * 26.0) * k;
      final neck = smooth(0.82, 1.0, k) * 2.5;
      final cy = -h + r + neck;
      if (neck > 0.2) p.line(0, -h, 0, cy - r, c[5]);
      p.ellipseShaded(
        0,
        cy,
        r * (1.0 - wob),
        r * (1.0 + wob) + 0.3 * k,
        color: (d, a) => d > 0.72
            ? (math.cos(a) < 0.0 && math.sin(a) < 0.3 ? c[5] : c[3])
            : (d < 0.35 && math.cos(a) > 0.0 ? c[6] : c[4]),
      );
      if (r > 1.0) p.px(-r * 0.4, cy - r * 0.45, kWhite);
      p.glow(0, cy, 4.0 + r * 2.0, c[5], 0.14 + 0.14 * k);
    } else {
      final s = (t - _let) / 0.15;
      if (s < 1.0) {
        p.ellipse(
          0,
          -h + 0.8,
          1.2 * (1.0 - s * 0.6),
          1.0 + math.sin(s * math.pi) * 0.8,
          c[4],
        );
      }
    }
    final f = t - _let;
    if (f > 0.0 && t < land) {
      final y = -h + 3.0 + 0.5 * _g * f * f;
      final vy = _g * f;
      bead(p, 0.0, y, 0.0, vy, 3, c);
      p.glow(0, y, 6, c[5], 0.2);
    }
    final u = t - land;
    if (u >= 0.0) {
      ring(
        p,
        0.0,
        0.0,
        2.0 + 17.0 * Ease.outCubic(u / 0.75),
        _sy,
        1.1 * (1.0 - u / 0.75),
        c,
        n: 2,
        gap: 2.5,
        half: 1,
        hot: u < 0.08,
        seed: 1,
        wob: 0.4,
        glint: u < 0.5 ? 1.0 - u * 2.0 : 0.0,
      );
      if (u < 0.06) {
        p.px(0, 0, kWhite);
        p.px(-1, 0, c[6]);
        p.px(1, 0, c[6]);
        p.glow(0, -1, 10, c[5], 0.5 * (1.0 - u / 0.06));
      }
      for (final (vx, vh) in const [(-26.0, 70.0), (24.0, 64.0), (-6.0, 90.0)]) {
        final ch = vh * u - 0.5 * _g * u * u;
        if (ch > 0.0 && u < 0.3) {
          p.px(vx * u, -ch, u < 0.1 ? kWhite : c[6]);
        }
      }
      final rb = u - _rebound;
      final rh = 52.0 * rb - 0.5 * _g * 0.5 * rb * rb * 2.0;
      if (rb > 0.0 && rh > 0.0) {
        p.line(0, -1, 0, -rh + 1.0, c[5]);
        p.circle(0, -rh, 1.1, c[6]);
        p.px(0, -rh - 1.0, kWhite);
      }
      final v = u - _rebound - _back;
      if (v >= 0.0) {
        ring(
          p,
          0.0,
          0.0,
          1.5 + 9.0 * Ease.outCubic(v / 0.5),
          _sy,
          0.9 * (1.0 - v / 0.5),
          c,
          n: 1,
          half: 1,
          seed: 2,
          hot: v < 0.06,
        );
      }
      p.glow(0, 0, 18, c[4], 0.22 * (1.0 - clamp(u / 0.6)));
    }
    final sh = math.sin(t * 20.0) > 0.0 ? 0 : 1;
    p.px(-1 + sh, 2, c[4]);
    if (f > 0.0 && t < land) {
      final ry = 2.0 + 0.5 * _g * f * f * 0.04;
      p.px(sh, math.min(4.0, ry), c[5]);
    }
    p.glow(0, -h + 2.0, 8, c[5], 0.16);
    p.glow(0, 0, 26, c[3], 0.14);
  },
);
