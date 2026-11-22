// The bubble shading (a lit rim top-left, a shaded rim bottom-right, a see-through body, a highlight and a
// refraction fleck, 2x2 and 1 px forms when small) and the surface line are adapted from Sprite Fusion's
// open-source bubbles (https://www.spritefusion.com/pixel-art-vfx/bubbles), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'water_lib.dart';

const double _d = 4.0;
const int _top = -92;
const int _half = 48;
const List<int> _mouths = [-5, 1, 6];

int _jsRound(double v) => (v + 0.5).floor();

double _surfaceY(double x, double ph) =>
    _top +
    math.sin(x * 0.13 + ph * tau * 2.0) * 1.1 +
    math.sin(x * 0.051 - ph * tau) * 1.3;

double _shaft(double x, double y, double ph) {
  final u = x + (y - _top) * 0.32;
  final s = math.sin(u * 0.16 + ph * tau) * 0.6 +
      math.sin(u * 0.07 - ph * tau + 1.0) * 0.4;
  return math.max(0.0, s - 0.35) / 0.65;
}

void _bubble(
  Painter p,
  List<int> c,
  double x,
  double y,
  double r,
  double q,
  double lit,
) {
  if (r < 0.9) {
    p.px(x, y, lit > 0.3 ? kWhite : (r < 0.7 ? c[5] : c[6]));
    return;
  }
  if (r < 1.5) {
    final xi = x.floor();
    final yi = y.floor();
    p.px(xi, yi, kWhite);
    p.px(xi + 1, yi, c[6]);
    p.px(xi, yi + 1, c[5]);
    p.px(xi + 1, yi + 1, c[4]);
    p.glow(x + 0.5, y + 0.5, 3, c[5], 0.12 + 0.2 * lit);
    return;
  }
  final rx = r * (1.0 + q);
  final ry = r * (1.0 - q);
  p.shade(x - rx - 1.0, y - ry - 1.0, x + rx + 1.0, y + ry + 1.0, (px, py, _) {
    final dx = (px - x) / rx;
    final dy = (py - y) / ry;
    final d = hypot(dx, dy) * r;
    if (d > r + 0.5) return null;
    final l = (-dx - dy) / math.sqrt2 / math.max(0.01, d / r);
    if (d > r - 0.6) {
      return l > 0.45 ? c[6] : (l < -0.55 ? c[3] : c[4]);
    }
    p.blend(px, py, c[5], 0.16 + 0.2 * lit);
    return null;
  });
  final hx = _jsRound(x - rx * 0.45);
  final hy = _jsRound(y - ry * 0.45);
  p.px(hx, hy, kWhite);
  if (r >= 2.5) p.px(hx + 1, hy, c[6]);
  if (r >= 2.0) p.px(_jsRound(x + rx * 0.5), _jsRound(y + ry * 0.5), c[6]);
  p.glow(x, y, r * 2.4 + 2.0, c[5], 0.12 + 0.3 * lit);
}

void _each(
  double t,
  int s,
  void Function({
    required double x,
    required double y,
    required double r,
    required double q,
    required int i,
    required double age,
    required double vy,
  }) fn,
) {
  cycle(t, _d, 46, s, (g) => g.range(2.2, 3.4), (age, life, r, i) {
    final m = _mouths[i % 3];
    final r0 = r.next() < 0.7 ? r.range(0.5, 1.4) : r.range(1.6, 2.6);
    final vy = 30.0 + 9.0 * r0 + r.range(-4.0, 4.0);
    final wf = r.range(3.0, 6.0);
    final wa = 0.8 + r0 * 1.2;
    final ph0 = r.range(0.0, tau);
    final drift = r.range(-4.0, 4.0);
    final y = -2.0 - vy * age;
    final k = clamp(-y / -_top);
    final x = m + drift * k + math.sin(age * wf + ph0) * wa * k;
    fn(
      x: x,
      y: y,
      r: r0 * (1.0 + 0.45 * k),
      q: 0.12 * math.sin(age * wf * 2.0 + ph0) * math.min(1.0, r0 / 2.0),
      i: i,
      age: age,
      vy: vy,
    );
  });
}

final PureEffect bubblesEffect = PureEffect(
  meta: const EffectMeta(
    id: 'water/bubbles',
    name: 'Bubbles',
    desc:
        'Bubbles stream up from a vent of pebbles, wobbling and swelling as they rise, flare as they cross shafts of light from the surface, then dome up and pop there.',
    category: 'water',
    tags: ['water', 'bubbles', 'underwater', 'vent', 'ambient', 'loop'],
    size: (104, 112),
    origin: (52, 104),
    duration: 4.0,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': kWaterPalette,
      'seed': 4,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _d;
    for (var yi = _top - 2; yi < 0; yi++) {
      for (var xi = -_half; xi < _half; xi++) {
        final x = xi + 0.5;
        final y = yi + 0.5;
        final sy = _surfaceY(x, ph);
        if (y < sy) continue;
        final e = 1.0 - smooth(_half - 14.0, _half.toDouble(), x.abs());
        final depth = (y - _top) / -_top;
        p.blend(x, y, c[1], (0.22 + 0.22 * depth) * e);
        final s = _shaft(x, y, ph) * (1.0 - depth * 0.7) * e;
        if (s > 0.05) p.light(x, y, c[4], 0.2 * s);
      }
    }
    for (var xi = -_half; xi < _half; xi++) {
      final x = xi + 0.5;
      final e = 1.0 - smooth(_half - 14.0, _half.toDouble(), x.abs());
      final s = _shaft(x, -2.0, ph);
      final caust = math.max(
        0.0,
        1.0 -
            (math.sin(
                      x * 0.42 + math.sin(x * 0.11 + ph * tau * 2.0) * 2.2,
                    ))
                    .abs() *
                2.4,
      );
      final w = s * caust * e;
      if (w > 0.05) {
        p.light(x, -1, c[5], 0.5 * w);
        p.light(x, -2, c[4], 0.25 * w);
        p.light(x, 0, c[4], 0.3 * w);
      }
    }
    final st = rockColors();
    for (final (x, y, rr) in const [
      (-9.0, -1.5, 2.4),
      (-4.0, -1.0, 1.8),
      (3.5, -1.2, 2.2),
      (9.0, -1.4, 2.6),
      (0.0, -0.6, 1.4),
      (-12.5, -0.8, 1.6),
    ]) {
      p.shade(x - rr - 1.0, y - rr - 1.0, x + rr + 1.0, y + rr + 1.0,
          (px, py, _) {
        final dx = px - x;
        final dy = py - y;
        final d = hypot(dx * 1.1, dy);
        if (d > rr + 0.7 || py > 0.0) return null;
        return d > rr
            ? st[0]
            : (dx + dy < -rr * 0.6
                ? st[5]
                : (dx + dy < rr * 0.3 ? st[3] : st[2]));
      });
    }
    for (final m in _mouths) {
      p.px(m, -1, st[0]);
    }
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _d;
    final s = o.seed;
    cycleFixed(t, _d, 26, s + 7, _d, (age, life, r, _) {
      final rx = r.range(-_half + 6.0, _half - 6.0);
      final x = rx + math.sin((age / _d) * tau + r.range(0.0, tau)) * 3.0;
      final y = _top + 6.0 + ((r.range(0.0, 86.0) + age * 4.0) % 86.0);
      final sh = _shaft(x, y, ph);
      final tw = math.sin((age / _d) * tau * 3.0 + r.range(0.0, tau));
      if (tw < -0.3 && sh < 0.2) return;
      p.px(x, y, sh > 0.4 ? kWhite : (tw > 0.6 ? c[5] : c[4]));
      if (sh > 0.4) p.glow(x, y, 3, c[5], 0.25 * sh);
    });
    _each(t, s, ({
      required x,
      required y,
      required r,
      required q,
      required i,
      required age,
      required vy,
    }) {
      final sy = _surfaceY(x, ph);
      if (y > sy + r) {
        _bubble(p, c, x, y, r, q, _shaft(x, y, ph));
      } else {
        final since = (sy + r - y) / vy;
        if (since < 0.12 && r >= 1.4) {
          for (var a = math.pi; a <= tau + 0.01; a += 0.4 / r) {
            p.px(x + math.cos(a) * r, sy + math.sin(a) * r * 0.9, c[6]);
          }
          p.px(x - r * 0.4, sy - r * 0.6, kWhite);
        } else if (since < (r >= 1.4 ? 0.32 : 0.2)) {
          final k = clamp((since - (r >= 1.4 ? 0.12 : 0.0)) / 0.2);
          final w = math.max(1.0, r + 1.0 + k * 4.0);
          for (var a = 0.0; a < math.pi; a += 0.5 / w) {
            if (math.sin(a) > 0.15) {
              p.dot(
                x + math.cos(a) * w,
                sy + math.sin(a) * w * 0.3,
                k < 0.4 ? kWhite : c[5],
                1.2 - k,
              );
            }
          }
          if (r >= 1.4 && k < 0.6) {
            p.px(x - 2.0, sy - 2.0 - k * 4.0, c[6]);
            p.px(x + 2.0, sy - 3.0 - k * 5.0, c[6]);
          }
        }
      }
    });
    for (var xi = -_half; xi < _half; xi++) {
      final x = xi + 0.5;
      final y = _surfaceY(x, ph);
      final e = 1.0 - smooth(_half - 12.0, _half.toDouble(), x.abs());
      final glint = math.sin(x * 0.37 - ph * tau * 3.0) *
              math.sin(x * 0.13 + ph * tau) >
          0.55;
      p.dot(xi, y, glint ? kWhite : c[5], e * 1.3);
      p.dot(xi, y + 1.0, c[3], e * 1.3);
      if ((xi & 3) == 0) {
        p.glow(x, y + 1.0, 7, c[5], (glint ? 0.22 : 0.1) * e);
      }
    }
  },
);
