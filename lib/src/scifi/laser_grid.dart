import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'scifi_lib.dart';

const double _duration = 3.0;
const int _px = 48;
const int _top = -64;
const int _in = _px - 4;

const List<(double, double, double, double)> _slide = [
  (-14.0, 8.0, 1.0, 0.0),
  (-31.0, 12.0, 2.0, 1.3),
  (-48.0, 9.0, 1.0, 3.6),
];

double _sweepX(double t, int s) =>
    s *
    (34.0 -
        68.0 *
            (0.5 -
                0.5 * math.cos(tau * (t / _duration) + (s > 0 ? 0.0 : 1.9))));

double _slideY(double t, (double, double, double, double) b) =>
    b.$1 + b.$2 * math.sin(tau * b.$3 * (t / _duration) + b.$4);

typedef _Beam = (double x0, double y0, double x1, double y1);

List<_Beam> _beams(double t) {
  final out = <_Beam>[
    for (final b in _slide) (-_in.toDouble(), _slideY(t, b), _in.toDouble(), _slideY(t, b)),
  ];
  for (final s in const [-1, 1]) {
    out.add((s * _in.toDouble(), _top + 6.0, _sweepX(t, s), 0.0));
  }
  return out;
}

void _laser(Painter p, _Beam b, List<int> c, double t, int seed) {
  final (x0, y0, x1, y1) = b;
  final steep = (y1 - y0).abs() > (x1 - x0).abs();
  final ox = steep ? 1 : 0;
  final oy = steep ? 0 : 1;
  for (final s in const [-1, 1]) {
    p.line(x0 + s * ox, y0 + s * oy, x1 + s * ox, y1 + s * oy, s < 0 ? c[4] : c[3]);
  }
  p.lineShaded(
    x0,
    y0,
    x1,
    y1,
    color: (u) => ((((u * 5.0 - t * 3.0) % 1.0) + 1.0) % 1.0) < 0.12
        ? c[6]
        : kWhite,
  );
  final l = hypot(x1 - x0, y1 - y0);
  for (var d = 0.0; d <= l; d += 5.0) {
    final x = lerp(x0, x1, d / l);
    final y = lerp(y0, y1, d / l);
    final h =
        0.5 + 0.5 * tileFbm(x / 14.0 + (t / _duration) * 4.0, y / 10.0, 4, 0, seed);
    p.glow(x, y, 6.0 + 4.0 * h, c[3], 0.14 + 0.3 * h * h);
  }
}

Point2? _cross(_Beam a, _Beam b) {
  final (x1, y1, x2, y2) = a;
  final (x3, y3, x4, y4) = b;
  final d = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
  if (d.abs() < 1e-6) return null;
  final u = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / d;
  final v = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / d;
  return u >= 0.0 && u <= 1.0 && v >= 0.0 && v <= 1.0
      ? (x1 + u * (x2 - x1), y1 + u * (y2 - y1))
      : null;
}

double _near(_Beam b, double x, double y) {
  final (x0, y0, x1, y1) = b;
  final dx = x1 - x0;
  final dy = y1 - y0;
  final u = clamp(((x - x0) * dx + (y - y0) * dy) / (dx * dx + dy * dy));
  final ex = x0 + dx * u - x;
  final ey = y0 + dy * u - y;
  return math.sqrt(ex * ex + ey * ey);
}

void _post(Painter p, int s, List<int> h, List<int> c, double t) {
  final x0 = s * _px - 4;
  final bYs = [for (final b in _slide) _slideY(t, b)];
  for (var y = _top + 4; y < 0; y++) {
    var glint = 0.0;
    for (final by in bYs) {
      glint = math.max(
        glint,
        math.exp(-((y - by) / 2.5) * ((y - by) / 2.5)),
      );
    }
    for (var i = 0; i < 8; i++) {
      final x = x0 + i;
      final inner = s < 0 ? i >= 6 : i <= 1;
      var col = i == 0 || i == 7
          ? h[0]
          : (i == 1
              ? h[4]
              : (i == 2
                  ? h[3]
                  : (i == 4 ? h[1] : (i == 6 ? h[2] : h[3]))));
      if (inner && i != 0 && i != 7 && glint > 0.35) {
        col = glint > 0.75 ? c[5] : c[3];
      }
      p.px(x, y, col);
    }
  }
  for (var y = _top + 12; y < -4; y += 9) {
    p.px(x0 + 3, y, h[5]);
  }
  for (var y = _top; y < _top + 10; y++) {
    for (var i = -1; i < 9; i++) {
      p.px(
        x0 + i,
        y,
        i == -1 || i == 8 || y == _top || y == _top + 9
            ? h[0]
            : (y == _top + 1 ? h[5] : (i < 3 ? h[4] : h[2])),
      );
    }
  }
  p.px(s * _in, _top + 6, kWhite);
  p.px(s * _in, _top + 5, c[5]);
  p.px(s * _in, _top + 7, c[4]);
  for (var i = -3; i < 11; i++) {
    p.px(x0 + i, -2, i == -3 || i == 10 ? h[0] : h[4]);
    p.px(x0 + i, -1, i == -3 || i == 10 ? h[0] : h[2]);
    p.px(x0 + i, 0, h[1]);
  }
  for (final by in bYs) {
    final y = (by + 0.5).floor();
    for (var j = -2; j <= 2; j++) {
      for (var i = 0; i < 4; i++) {
        p.px(
          s < 0 ? x0 + 5 + i : x0 - 1 + i,
          y + j,
          j.abs() == 2 || i == (s < 0 ? 3 : 0)
              ? h[0]
              : (j < 0 ? h[5] : h[3]),
        );
      }
    }
    p.px(s * _in, y, kWhite);
    p.glow(s * _in, y, 7, c[4], 0.55);
  }
  p.glow(s * _in, _top + 6, 8, c[4], 0.55);
}

final Map<String, Ghosts> _cache = {};

Ghosts _ghosts(Map<String, Object?> o, List<int> c) {
  final pal = o.palette;
  final key = '${o.seed}:${pal.join(',')}';
  final hit = _cache[key];
  if (hit != null) return hit;

  final rn = Rng(o.seed);
  final g = Ghosts(
    _duration,
    ground: (_) => 0.0,
    sparks: [kWhite, c[6], c[4], c[3]],
    box: (-62.0, -80.0, 62.0, 7.0),
  );
  for (var i = 0; i < 36; i++) {
    final tb = (i / 36.0) * _duration + rn.range(0.0, 0.05);
    final s = i.isOdd ? 1 : -1;
    final x = _sweepX(tb, s);
    final dx = _sweepX(tb + 0.02, s) - x;
    final dir = dx > 0.0 ? 1 : (dx < 0.0 ? -1 : 1);
    final a = -math.pi / 2.0 - dir * rn.range(0.2, 1.1);
    g.add(
      tb,
      P.spark,
      x,
      -1.0,
      math.cos(a) * rn.range(50.0, 140.0),
      math.sin(a) * rn.range(50.0, 140.0),
      rn.range(0.2, 0.45),
    );
    if (i % 4 == 0) {
      g.add(
        tb,
        P.smoke,
        x,
        -2.0,
        rn.range(-4.0, 4.0),
        -rn.range(6.0, 14.0),
        rn.range(0.8, 1.2),
        hex('#3a2a30'),
        rn.range(1.6, 2.4),
      );
    }
  }
  _cache[key] = g;
  return g;
}

void _draw(Painter p, double t, Map<String, Object?> o) {
  final c = fit(o.palette, 8);
  final h = fit(o.rampOpt('metal'), 6);
  final b = _beams(t);
  final s = o.seed;

  for (final side in const [-1, 1]) {
    for (var k = 0; k < 14; k++) {
      final ago = k * 0.025;
      final x = _sweepX(t - ago, side);
      final col = k < 2
          ? kWhite
          : (k < 5 ? c[6] : (k < 9 ? c[4] : c[3]));
      p.dot(x, 0, col, 1.0 - k / 14.0);
      p.dot(x, 1, c[3], 0.6 - k / 24.0);
    }
  }
  for (var x = -40; x <= 40; x += 20) {
    p.glow(x, -2, 20, c[3], 0.12);
  }

  final ph = t / _duration;
  for (var y = -60; y < 0; y++) {
    for (var x = -_in + 1; x < _in; x++) {
      var d = 99.0;
      for (final beam in b) {
        d = math.min(d, _near(beam, x + 0.5, y + 0.5));
      }
      if (d > 11.0) continue;
      final low = 0.35 + 0.65 * clamp((y + 60.0) / 50.0);
      final n = 0.5 +
          0.5 *
              tileFbm(
                (x + 0.5) / 18.0 + ph * 3.0,
                (y + 0.5) / 7.0 + 0.4 * math.sin(tau * ph),
                3,
                0,
                s + 7,
                2,
              );
      final dens = clamp((n - 0.42) * 2.2) * low;
      if (dens <= 0.02) continue;
      final lit = math.exp(-d / 4.5);
      p.blend(
        x + 0.5,
        y + 0.5,
        lit > 0.5 ? c[4] : (lit > 0.15 ? c[3] : c[1]),
        dens * 0.8 * lit,
      );
    }
  }

  for (final side in const [-1, 1]) {
    _post(p, side, h, c, t);
  }
  for (final beam in b) {
    _laser(p, beam, c, t, s);
  }

  for (var i = 0; i < 90; i++) {
    final x = (rand(s, i) * 2.0 - 1.0) * (_in - 3) +
        4.0 * math.sin(tau * (t / _duration) + i);
    final y = -2.0 -
        rand(s, i, 1) * 62.0 +
        3.0 * math.sin(tau * 2.0 * (t / _duration) + i * 1.7);
    var d = 9.0;
    for (final beam in b) {
      d = math.min(d, _near(beam, x, y));
    }
    if (d < 1.6) {
      p.px(x, y, d < 0.9 ? kWhite : c[6]);
      p.glow(x, y, 3, c[5], 0.45);
    }
  }

  for (var i = 0; i < b.length; i++) {
    for (var j = i + 1; j < b.length; j++) {
      final cr = _cross(b[i], b[j]);
      if (cr == null) continue;
      p.glow(cr.$1, cr.$2, 9, c[5], 0.4);
      sparkle(p, cr.$1, cr.$2, 2, c[6], c[5], 0.3);
    }
  }

  for (final side in const [-1, 1]) {
    final x = _sweepX(t, side);
    p.px(x, -1, kWhite);
    p.px(x - 1, 0, c[6]);
    p.px(x + 1, 0, c[6]);
    p.glow(x, -1, 10, c[4], 0.55);
    p.glow(x, -1, 4, kWhite, 0.35);
  }
  _ghosts(o, c).at(t).draw(p);
}

final PixelEffect laserGridEffect = PureEffect(
  meta: const EffectMeta(
    id: 'scifi/laser-grid',
    name: 'Laser grid',
    desc:
        'Security lasers between two steel posts: red beams slide and scissor across, dust and haze light up only where they cut through, and the floor sweepers scorch and spark.',
    category: 'scifi',
    tags: [
      'scifi',
      'laser',
      'security',
      'trap',
      'hazard',
      'beam',
      'ground',
      'loop',
    ],
    size: (128, 84),
    origin: (64, 76),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#1a0408',
        '#4a0a12',
        '#8a1020',
        '#d01c2a',
        '#ff4a4a',
        '#ff9a90',
        '#ffe4e0',
        '#ffffff',
      ],
      'metal': [
        '#0e0d14',
        '#1e1c27',
        '#312e3e',
        '#4b4759',
        '#6f6a82',
        '#9d98b0',
      ],
      'seed': 31,
    },
  ),
  onDraw: _draw,
);
