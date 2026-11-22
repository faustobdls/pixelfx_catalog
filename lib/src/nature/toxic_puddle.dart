import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const double _dur = 4.0;

double _surf(double x, double w, double t) {
  final d = math.min(1.0, x.abs() / w);
  final ph = (tau * t) / _dur;
  final lens = math.sqrt(1 - d * d) * 6.6 +
      (d > 0.8 ? 1.6 * smooth(0.8, 0.9, d) : 0);
  final swell = math.pow(math.max(0.0, math.sin(x * 0.09 - ph)), 6) * 1.2 +
      math.pow(math.max(0.0, math.sin(x * 0.06 + ph * 2 + 1)), 8) * 0.9;
  return -(lens + swell * (1 - d) + 0.5).floorToDouble();
}

void _pool(
  Painter p,
  List<int> c,
  List<int> sh,
  double w,
  double t,
  int seed,
) {
  final ph = t / _dur;
  for (var x = (-w - 1).floor(); x <= (w + 1).ceil(); x++) {
    final d = (x + 0.5).abs() / w;
    if (d > 1.03) continue;
    final top = _surf(x + 0.5, w, t).toInt();
    final oil = 0.6 * tileNoise(x * 0.08, ph * 4, 0, 4, seed) +
        0.6 * tileNoise(x * 0.11 - ph * 4, 1, 4, 0, seed + 1);
    final hue = tileNoise(x * 0.05, ph * 2 + 7, 0, 2, seed + 3);
    for (var y = top; y <= 2; y++) {
      if ((y == 2 && d > 0.75) || (y == 1 && d > 0.9)) continue;
      int col;
      if (d > 0.93 && y <= 0) {
        col = y == top ? c[7] : c[6];
      } else if (y == top) {
        final wrapped = (((x * 0.07 - ph * 3) % 1.0) + 1.0) % 1.0;
        final glint = (wrapped - 0.5).abs() < 0.012 ||
            rand(x, (t * 10).floor()) < 0.015;
        col = glint
            ? kWhite
            : oil > 0.55
                ? (hue > 0 ? sh[3] : sh[2])
                : oil > 0.15
                    ? (hue > 0 ? sh[1] : c[5])
                    : c[5];
        if (glint) p.light(x, y, c[7], 0.5);
      } else if (y == top + 1) {
        col = oil > 0.4 ? sh[0] : c[3];
      } else if (y >= 1) {
        col = c[0];
      } else {
        final pulse = 0.5 + 0.5 * math.sin((tau * t) / _dur + x * 0.03);
        final v = (tileNoise(x * 0.09, y * 0.75 + ph * 4, 0, 4, seed + 7) +
                0.2 * math.sin((tau * t * 2) / _dur + x * 0.15))
            .abs();
        final wd = 0.6 + 0.6 * pulse;
        col = v < 0.035 * wd
            ? c[7]
            : v < 0.08 * wd
                ? c[6]
                : v < 0.14 * wd
                    ? c[4]
                    : c[1];
        if (v < 0.08 * wd) p.light(x, y, c[6], 0.25 + 0.3 * pulse);
      }
      p.px(x, y, col);
    }
    if (d > 0.9 && d <= 1.03) p.px(x, top - 1, c[1]);
  }
  for (final s in const [-1, 1]) {
    for (var k = 1; k <= 6; k++) {
      p.dot(s * (w + k), 0, k < 3 ? c[6] : c[5], 1 - k / 7);
    }
  }
}

void _ribbon(
  Painter p,
  List<int> c,
  double x0,
  double y0,
  double age,
  double life,
  Rng r,
  double k,
) {
  final u = age / life;
  final len = r.range(16, 26);
  final rise = r.range(9, 14);
  final amp = r.range(2, 4.5);
  final w = r.range(0.18, 0.3);
  final ph = r.range(0, tau);
  final head = rise * age;
  final tail = math.max(0.0, head - len);
  final fray = smooth(0.35, 0.85, u);
  final fade = smooth(0, 0.12, u) * (1 - smooth(0.5, 1, u)) * k;
  if (fade < 0.02) return;
  final grey = hex('#b4b8ae');
  final n = fray > 0.05 ? 3 : 1;
  for (var h = tail; h <= head; h += 0.5) {
    final s = (h - tail) / math.max(1.0, head - tail);
    final cx = x0 + amp * math.sin(h * w + ph + age * 1.6) * (0.3 + s);
    final y = y0 - h;
    final a = fade * math.sin(math.pi * s) * 0.45;
    final lit = math.max(0.0, 1 - h / 22) * (1 - 0.6 * fray);
    final vap = mix(grey, c[6], 0.75 * lit);
    for (var q = 0; q < n; q++) {
      final off = n == 1
          ? 0.0
          : fray * s * (q - 1) * 3 +
              fray *
                  2.5 *
                  math.sin(h * (0.35 + q * 0.17) + ph * (q + 1) + age * 2);
      p.blend(
        cx + off,
        y,
        vap,
        a * (n == 1 ? 1 : 0.65 - 0.25 * fray) * (0.8 + 0.4 * lit),
      );
    }
  }
}

void _bubbles(
  Painter p,
  List<int> c,
  List<int> sh,
  double w,
  double t,
  int seed,
) {
  cycle(t, _dur, 8, seed, (g) => g.range(2.4, 3.2), (age, l, r, _) {
    final swell = r.range(1, 1.6);
    final x = r.range(-0.7, 0.7) * w;
    final rmax = r.range(4.5, 8);
    final sy = _surf(x, w, t) + 0.5;
    if (age < swell) {
      final k = age / swell;
      final st = smooth(0.65, 1, k);
      final gr = Ease.outCubic(math.min(1.0, k * 1.3));
      final rx = rmax * gr * (1 - 0.18 * st);
      final ry = rmax * gr * (1 + 0.5 * st);
      final cx = (x + 0.5).floor();
      final cy = (sy + 0.5).floor();
      final inner = 0.35 + 0.65 * k;
      for (var j = -ry.ceil() - 1; j <= 0; j++) {
        for (var i = -rx.ceil() - 1; i <= rx.ceil() + 1; i++) {
          final dd = hypot(i / math.max(0.6, rx), j / math.max(0.6, ry));
          if (dd > 1.1) continue;
          int col;
          if (dd > 0.9) {
            col = c[0];
          } else if (dd < 0.55 * inner && j > -ry * 0.75) {
            col = dd < 0.3 * inner ? c[6] : c[5];
          } else if (dd < 0.8 * inner) {
            col = c[4];
          } else {
            col = j < -ry * 0.5 ? c[2] : c[3];
          }
          p.px(cx + i, cy + j, col);
        }
      }
      if (rx > 1.8) {
        for (var a = 3.5; a < 4.7; a += 0.16) {
          p.px(
            cx + math.cos(a) * rx * 0.68,
            cy + math.sin(a) * ry * 0.68,
            a < 3.9 ? sh[3] : (a < 4.3 ? c[7] : sh[1]),
          );
        }
      }
      if (rx > 1.2) {
        final hx = cx - (rx * 0.35 + 0.5).floor();
        final hy = cy - (ry * 0.62 + 0.5).floor();
        p.px(hx, hy, kWhite);
        p.px(hx + 1, hy, c[7]);
      }
      p.glow(x, sy - ry * 0.5, 7 + rx * 1.4, c[6], (0.2 + 0.35 * st) * gr);
      return;
    }
    final e = age - swell;
    if (e < 0.3) {
      final k = e / 0.3;
      final rr = 2 + 14 * Ease.outCubic(k);
      for (var a = 0.0; a < tau; a += 0.5 / rr) {
        final rx2 = x + math.cos(a) * rr;
        final ry2 = sy + math.sin(a) * rr * 0.22;
        if (rx2.abs() < w * 0.95) {
          p.dot(
            rx2,
            ry2,
            k < 0.4 ? kWhite : (k < 0.7 ? c[7] : c[6]),
            (1 - k) * 1.4,
          );
        }
      }
      p.glowRing(x, sy, rr, 3, c[6], 0.35 * (1 - k));
      if (e < 0.1) p.glow(x, sy - 2, 18, c[6], 0.7 * (1 - e / 0.1));
    }
    final xr = (x * 10 + 0.5).floor();
    for (var j = 0; j < 7; j++) {
      final vx = (rand(j, seed, xr) - 0.5) * 80;
      final vy = -45 - rand(j, seed + 3, xr) * 70;
      final (dx, dy) = fly(x, sy - 2, vx, vy, e, 420);
      if (dy < sy && e < 0.6) {
        p.px(dx, dy, c[1]);
        p.px(dx, dy - 1, (j & 1) != 0 ? sh[3] : c[6]);
      }
    }
    _ribbon(p, c, x, sy - 2, e, l - swell, r, 0.9);
  });
}

final PixelEffect toxicPuddle = PureEffect(
  meta: const EffectMeta(
    id: 'nature/toxic-puddle',
    name: 'Toxic puddle',
    desc:
        'Black tar lit from inside by chartreuse veins and a glowing rim, an oily sheen drifting on it; glossy bubbles dome, stretch and pop, vapour curls up in fraying ribbons.',
    category: 'nature',
    tags: [
      'nature',
      'poison',
      'toxic',
      'sludge',
      'tar',
      'puddle',
      'hazard',
      'ground',
      'loop',
    ],
    size: (176, 100),
    origin: (88, 86),
    duration: 4.0,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#06070a',
        '#0c100c',
        '#141a10',
        '#1e2814',
        '#2e3c18',
        '#5a7a1c',
        '#a6d42a',
        '#ecff86',
      ],
      'sheen': ['#2a1648', '#5a2e8e', '#1e7a86', '#6adccc'],
      'width': 42,
      'seed': 2,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final sh = fit(o.rampOpt('sheen'), 4);
    final w = o.numOpt('width', 42.0);
    final pulse = 0.85 + 0.15 * math.sin((tau * t * 2) / _dur);
    p.glow(0, -3, w * 1.25, c[5], 0.22 * pulse);
    p.glow(0, -10, w * 1.1, c[6], 0.1 * pulse);
    for (final s in const [-1, 1]) {
      p.glow(s * w, -1, 12, c[6], 0.35 * pulse);
    }
    _pool(p, c, sh, w, t, o.seed);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final sh = fit(o.rampOpt('sheen'), 4);
    final w = o.numOpt('width', 42.0);
    _bubbles(p, c, sh, w, t, o.seed * 7 + 1);
    cycle(t, _dur, 9, o.seed * 13 + 4, (g) => g.range(2.4, 3.4),
        (age, l, r, _) {
      final x = r.range(-0.85, 0.85) * w;
      _ribbon(p, c, x, _surf(x, w, t) - 1, age, l, r, 0.75);
    });
  },
);
