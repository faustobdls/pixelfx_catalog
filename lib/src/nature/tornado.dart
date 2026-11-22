import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'nature_lib.dart';

const double _dur = 2.0;
const double _sy = 0.28;

class _Geo {
  final double fh;
  final double ph;

  const _Geo(this.fh, this.ph);

  double ax(double u) =>
      8.5 * math.sin(ph - 2.6 * u) * (0.2 + 0.8 * u) +
      3 * math.sin(2 * ph + 1.3 - 4.5 * u) * u;

  double rad(double u) =>
      3.0 +
      20.0 * math.pow(u, 1.5).toDouble() +
      17.0 * math.pow(smooth(0.78, 1, u), 2).toDouble();
}

_Geo _geo(Map<String, Object?> o, double t) =>
    _Geo(o.numOpt('height', 112.0), (tau * t) / _dur);

void _body(
  Painter p,
  List<int> c,
  List<int> dst,
  _Geo g,
  double t,
  int seed,
) {
  final fh = g.fh;
  for (var y = -fh.ceil() + 2; y <= 0; y++) {
    final u = -y / fh;
    final cx = g.ax(u);
    final r = g.rad(u);
    final kLoop = 2 + (rand(y, seed) < 0.35 ? 1 : 0);
    final rot = (tau * kLoop * t) / _dur;
    final fade = math.min(1.0, u * 8 + 0.25) * (1 - smooth(0.9, 1.02, u));
    for (var x = (cx - r).floor(); x <= (cx + r).ceil(); x++) {
      final cv = (x + 0.5 - cx) / r;
      if (cv.abs() > 1) continue;
      final n = tileNoise(((math.acos(cv) + rot) * 6) / tau, y * 0.34, 6, 0, seed);
      final v = -cv * 0.55 + 0.15 + n * 0.55;
      var col = v > 0.6
          ? c[6]
          : v > 0.28
              ? c[5]
              : v > -0.05
                  ? c[4]
                  : v > -0.4
                      ? c[3]
                      : c[2];
      if (u < 0.3) {
        col = mix(
          col,
          dst[v > 0.3 ? 3 : (v > -0.2 ? 2 : 1)],
          0.7 * (1 - u / 0.3),
        );
      }
      p.blend(x, y, col, (0.14 + 0.36 * math.sqrt(1 - cv * cv)) * fade);
    }
  }
}

void _bands(
  Painter p,
  List<int> c,
  _Geo g,
  double t,
  int seed,
  bool back,
) {
  final fh = g.fh;
  for (var j = 0; j < 58; j++) {
    final r = rng(seed, j);
    final u = (j + r.range(0.1, 0.9)) / 58;
    final kLoop = r.intRange(2, 4);
    final span = r.range(0.7, 2.1);
    final lvl = r.next();
    final cx = g.ax(u);
    final rad = g.rad(u) * r.range(1.0, 1.1);
    final y0 = -u * fh;
    final head = r.range(0, tau) + (tau * kLoop * t) / _dur;
    if (u > 0.97) continue;
    for (var s = 0.0; s <= span; s += 0.5 / math.max(2.0, rad)) {
      final th = head - s;
      final sn = math.sin(th);
      if ((sn > 0) == back) continue;
      final k = s / span;
      final x = cx + rad * math.cos(th);
      final y = y0 + rad * _sy * sn;
      final lit = math.cos(th) < 0.2;
      var i = lvl < 0.18
          ? 2
          : k < 0.15 && lvl > 0.55
              ? 7
              : k < 0.45
                  ? (lit ? 6 : 5)
                  : (lit ? 5 : 4);
      if (back) i = math.max(1, i - 2);
      if (k < 0.5) {
        p.dot(x, y, c[i]);
      } else {
        p.blend(x, y, c[i], 2 * (1 - k));
      }
    }
    if (!back && lvl > 0.6 && math.sin(head) > 0) {
      final hx = cx + rad * math.cos(head);
      final hy = y0 + rad * _sy * math.sin(head);
      p.dot(hx, hy, kWhite);
      p.glow(hx, hy, 5, c[6], 0.3);
    }
  }
}

void _blob(
  Painter p,
  double cx,
  double cy,
  double rx,
  double ry,
  int c,
  double a,
) {
  for (var y = (cy - ry).floor(); y <= (cy + ry).ceil(); y++) {
    for (var x = (cx - rx).floor(); x <= (cx + rx).ceil(); x++) {
      final dx = (x + 0.5 - cx) / rx;
      final dy = (y + 0.5 - cy) / ry;
      if (dx * dx + dy * dy <= 1) p.blend(x, y, c, a);
    }
  }
}

void _crown(
  Painter p,
  List<int> c,
  _Geo g,
  double t,
  int seed,
  bool back,
  double flash,
) {
  final fh = g.fh;
  final cx = g.ax(1);
  final rad = g.rad(1);
  int litMix(int col) => mix(col, c[7], flash * 0.6);
  final y0 = -fh - 3;
  if (back) {
    _blob(p, cx, y0 + 1, rad * 0.85, 6, c[1], 0.6);
    _blob(p, cx - 4, y0 - 3, rad * 0.6, 3.5, litMix(c[3]), 0.45);
  }
  for (var j = 0; j < 16; j++) {
    final r = rng(seed, j);
    final rr = rad * r.range(0.4, 1.15);
    final kLoop = r.intRange(1, 2);
    final span = r.range(1.4, 2.8);
    final head = r.range(0, tau) + (tau * kLoop * t) / _dur;
    final th0 = r.range(3.2, 6);
    final lift = r.range(-4, 3) - (1 - rr / (rad * 1.15)) * 5;
    for (var s2 = 0.0; s2 <= span; s2 += 0.6 / rr) {
      final th = head - s2;
      final sn = math.sin(th);
      if ((sn > 0) == back) continue;
      final k = s2 / span;
      final th2 = th0 * math.sin(math.pi * math.pow(1 - k, 0.7));
      final x = cx + rr * math.cos(th);
      final y = y0 + lift + rr * _sy * sn;
      final thickness = math.max(1, (th2 + 0.5).floor());
      final d = back ? 1 : 0;
      final lit = math.cos(th) < 0.3;
      for (var i = 0; i < thickness; i++) {
        final col = i == 0
            ? litMix(c[(lit ? 6 : 5) - d])
            : i == thickness - 1 && thickness > 2
                ? c[1]
                : litMix(c[(i == 1 ? 4 : 3) - d]);
        p.blend(
          x,
          y - thickness / 2 + i,
          col,
          (0.55 + 0.35 * (1 - k)) * (back ? 0.75 : 1),
        );
      }
    }
  }
}

void _debris(
  Painter p,
  List<int> c,
  List<int> l,
  _Geo g,
  double t,
  int seed,
  bool back,
  List<int> s,
) {
  final fh = g.fh;
  cycle(t, _dur, 24, seed, (q) => q.range(1.3, 1.95), (age, life, r, _) {
    final k = age / life;
    final sk = r.range(0.15, 0.3);
    final q = clamp((k - sk) / (1 - sk));
    final u = lerp(0.03, 0.98, math.pow(q, 0.85).toDouble());
    final th = r.range(0, tau) + r.range(2, 3.2) * tau * k;
    final sn = math.sin(th);
    if ((sn > 0) == back) return;
    final fling = smooth(0.78, 1, q);
    final inward = 1 - smooth(0, sk, k);
    final far = r.range(26, 44);
    final rr = lerp(
      math.min(68.0, g.rad(u) * (1.12 + fling * 1.1) + r.range(2, 7)),
      far,
      inward,
    );
    final x = g.ax(u) + rr * math.cos(th);
    final y = math.min(-1.0, -u * fh + rr * _sy * sn - fling * 8);
    final a = math.min(1.0, k * 8) * (1 - smooth(0.85, 1, k));
    final kind = r.next();
    final spin = r.range(-14, 14) * age;
    final dk = back ? 1 : 0;
    if (kind < 0.62) {
      final o = r.next() < 0.5 ? 0 : 4;
      final pal = [l[o], l[o + 1], l[o + 2 - dk], l[o + 3 - dk]];
      drawLeaf(p, x, y, r.range(6, 9), r.range(1.8, 2.6), spin,
          age * r.range(5, 10), pal, a);
    } else if (kind < 0.8) {
      final ca = math.cos(spin) * 2.5;
      final sa = math.sin(spin) * 2.5;
      p.line(x - ca, y - sa, x + ca, y + sa, back ? l[0] : l[1], a);
      p.dot(x + ca, y + sa, l[2], a);
    } else {
      drawRock(p, x, y, r.range(1.6, 2.6), spin, stoneShape(r, 5), s, a);
    }
  });
}

void _skirt(
  Painter p,
  List<int> d,
  _Geo g,
  double t,
  int seed,
  bool back,
) {
  final cx0 = g.ax(0);
  cycle(t, _dur, 40, seed, (q) => q.range(0.7, 1.3), (age, life, r, _) {
    final k = age / life;
    final th = r.range(0, tau) + r.range(5, 9) * age;
    final sn = math.sin(th);
    if ((sn > 0) == back) return;
    final rr = 4 + k * r.range(14, 28);
    final x = cx0 + rr * math.cos(th);
    final y = -1.5 - k * r.range(4, 16) + rr * 0.3 * sn;
    final s = r.range(3, 6) * (0.6 + 0.8 * k);
    final a = math.min(1.0, k * 6) * (1 - k) * 0.6;
    p.disc(x, y + s * 0.2, s, d[back ? 1 : 2], a);
    p.disc(x - s * 0.2, y - s * 0.3, s * 0.55, d[back ? 2 : 3], a * 0.8);
  });
  if (back) return;
  cycle(t, _dur, 16, seed + 7, (q) => q.range(0.35, 0.6), (age, life, r, _) {
    final th = r.range(0, tau);
    final v = r.range(25, 55);
    final x = cx0 + math.cos(th) * (4 + v * age);
    final y = math.sin(th) * 2 - r.range(40, 80) * age + 260 * age * age;
    if (y < 0.5) {
      p.dot(
        x,
        math.min(0.0, y),
        r.next() < 0.5 ? d[3] : d[4],
        1 - age / life,
      );
    }
  });
  for (var j = 0; j < 7; j++) {
    final r = rng(seed + 3, j);
    final rr = r.range(12, 28);
    final th0 = r.range(0, tau) + (tau * 3 * t) / _dur;
    final span = r.range(0.5, 1.1);
    for (var s = 0.0; s < span; s += 0.6 / rr) {
      final th = th0 - s;
      p.dot(
        cx0 + rr * math.cos(th),
        0.5 + rr * 0.18 * math.sin(th),
        d[s < span * 0.4 ? 3 : 2],
        1 - s / span,
      );
    }
  }
}

double _flashAt(double t) {
  final q = t / _dur;
  return math.max(0.0, 1 - (q - 0.62).abs() / 0.025) +
      0.6 * math.max(0.0, 1 - (q - 0.69).abs() / 0.015);
}

final PixelEffect tornado = PureEffect(
  meta: const EffectMeta(
    id: 'nature/tornado',
    name: 'Tornado',
    desc:
        'A snaking funnel of spinning wind bands under a flared, churning top that flickers with lightning; leaves and debris whirl round it front and back, dust boils at its foot.',
    category: 'nature',
    tags: ['nature', 'wind', 'tornado', 'storm', 'hazard', 'ground', 'loop'],
    size: (196, 168),
    origin: (98, 152),
    duration: 2.0,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#141221',
        '#231f33',
        '#36314a',
        '#4d4762',
        '#68617d',
        '#8a839e',
        '#b3adc4',
        '#e2def0',
      ],
      'dust': ['#2a2018', '#4e3e2e', '#76624a', '#a08a6a', '#cbb894'],
      'leaves': [
        '#4a200c',
        '#a8541c',
        '#e8962e',
        '#ffd27a',
        '#123818',
        '#2f7a2a',
        '#6cb83a',
        '#c8f070',
      ],
      'height': 112,
      'seed': 4,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final d = fit(o.rampOpt('dust'), 5);
    final g = _geo(o, t);
    final f = _flashAt(t);
    _skirt(p, d, g, t, o.seed * 5 + 1, true);
    _crown(p, c, g, t, o.seed * 7 + 2, true, f);
    _bands(p, c, g, t, o.seed * 3 + 5, true);
    _debris(p, c, fit(o.rampOpt('leaves'), 8), g, t, o.seed * 11 + 3, true, c);
    _body(p, c, d, g, t, o.seed);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final d = fit(o.rampOpt('dust'), 5);
    final g = _geo(o, t);
    final f = _flashAt(t);
    final cx = g.ax(1);
    _bands(p, c, g, t, o.seed * 3 + 5, false);
    _crown(p, c, g, t, o.seed * 7 + 2, false, f);
    _skirt(p, d, g, t, o.seed * 5 + 1, false);
    _debris(p, c, fit(o.rampOpt('leaves'), 8), g, t, o.seed * 11 + 3, false, c);
    p.glowLine(g.ax(0.1), -g.fh * 0.1, cx, -g.fh * 0.9, 26, c[5], 0.08);
    p.glow(g.ax(0), -2, 30, d[3], 0.12);
    if (f > 0.05) {
      final r = rng(o.seed, 99, (t / _dur * 7).floor());
      final path = bolt(
        r,
        cx - 18,
        -g.fh - 6,
        cx + 16,
        -g.fh + 2,
        jag: 0.3,
        depth: 3,
      );
      p.polyline(path, f > 0.6 ? kWhite : c[7], math.min(1.0, f * 1.5));
      p.glow(cx, -g.fh - 2, 70, c[7], 0.45 * f);
    }
  },
);
