import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const double _duration = 4.0;
const double _oy = -50.0;
const double _rad = 16.0;
const double _lens = -6.0;

final List<(double, double, double)> _verts = [
  (0.0, 1.45, 0.0),
  (0.0, -1.45, 0.0),
  for (var i = 0; i < 6; i++)
    (
      math.cos((i / 6.0) * tau) * 0.9,
      0.12,
      math.sin((i / 6.0) * tau) * 0.9,
    ),
];

final List<(int, int, int)> _faces = [
  for (var i = 0; i < 6; i++) ...[
    (0, 2 + i, 2 + ((i + 1) % 6)),
    (1, 2 + ((i + 1) % 6), 2 + i),
  ],
];

final List<(int, int)> _edges = [
  for (var i = 0; i < 6; i++) ...[
    (0, 2 + i),
    (1, 2 + i),
    (2 + i, 2 + ((i + 1) % 6)),
  ],
];

const List<(double, double, double)> _glitches = [
  (0.92, 0.12, 1.0),
  (2.55, 0.2, 1.4),
  (3.42, 0.06, 0.7),
];

void _draw(Painter p, double t, Map<String, Object?> o) {
  final c = fit(o.palette, 8);
  final h = fit(o.rampOpt('metal'), 6);
  final split = hex(o['split'] ?? '#ff4fd8');
  final s = o.seed;
  final ph = t / _duration;
  final frame = (t * 30.0).floor();

  var gl = 0.0;
  for (final (g0, len, k) in _glitches) {
    if (t >= g0 && t < g0 + len) gl = math.max(gl, k);
  }
  final flick = gl > 0.0 && rand(s, frame) < 0.5;
  final cx = gl != 0.0 ? (rand(s, frame, 2) < 0.5 ? -2.0 : 2.0) * gl : 0.0;
  final cy = _oy + 1.5 * math.sin(tau * ph * 2.0);

  final tears = <(int y0, int h, int dx)>[];
  if (gl != 0.0) {
    for (var i = 0; i < 2; i++) {
      tears.add((
        (cy - _rad + rand(s, frame, i) * _rad * 2.0).floor(),
        2 + (rand(s, frame, i, 1) * 4.0).floor(),
        (((rand(s, frame, i, 2) - 0.5) * 10.0 * gl) + 0.5).floor(),
      ));
    }
  }
  int tearAt(int y) {
    for (final tr in tears) {
      if (y >= tr.$1 && y < tr.$1 + tr.$2) return tr.$3;
    }
    return 0;
  }

  void put(double x, double y, int col, [double a = 1.0]) {
    final yy = y.floor();
    if (flick && (yy & 1) != 0) return;
    final dx = tearAt(yy);
    if (dx != 0) {
      p.dot(x + dx, y, split, a * 0.8);
      p.dot(x + dx + (dx > 0 ? 1 : -1), y, col, a);
      return;
    }
    p.dot(x, y, col, a);
  }

  p.shade(-16, -8, 16, 2, (x, y, out) {
    final topEq = (x / 15.0) * (x / 15.0) + ((y + 5.0) / 3.0) * ((y + 5.0) / 3.0);
    final top = topEq <= 1.0;
    final side = x.abs() <= 15.0 && y > -5.0 && y <= 0.0;
    if (!top && !side) return null;
    if (top) {
      out.c = topEq > 0.8 ? h[0] : (y < -6.0 ? h[5] : h[3]);
    } else {
      out.c = x.abs() > 14.0 || y == 0.0
          ? h[0]
          : (y == -4.0
              ? h[4]
              : (x < -6.0 ? h[3] : (x > 6.0 ? h[1] : h[2])));
    }
    return null;
  });
  p.ellipseShaded(
    0,
    _lens + 0.5,
    5.5,
    1.6,
    color: (d, _) => d < 0.4 ? kWhite : (d < 0.8 ? c[6] : c[4]),
  );
  for (var i = 0; i < 4; i++) {
    final k = 0.5 + 0.5 * math.cos(tau * (2.0 * ph - i / 4.0));
    p.px(-9 + i * 6, -2, k > 0.7 ? c[6] : c[3]);
  }

  final top = cy + _rad * 1.3;
  final yStart = top.ceil();
  for (var y = yStart; y < _lens; y++) {
    final v = (y - _lens) / (top - _lens);
    final w = lerp(4.0, _rad + 4.0, v);
    final lineOn = ((((y + t * 24.0) % 5.0) + 5.0) % 5.0) < 1.0;
    for (var x = (-w).floor(); x <= w.ceil(); x++) {
      final q = (x + 0.5).abs() / w;
      if (q > 1.0) continue;
      if (q > 1.0 - 1.0 / w) {
        put(x.toDouble(), y.toDouble(), v < 0.5 ? c[5] : c[4]);
      } else {
        p.blend(
          x + 0.5,
          y + 0.5,
          lineOn ? c[5] : c[4],
          (0.05 + 0.12 * (1.0 - v)) * (1.0 - 0.6 * q * q) +
              (lineOn ? 0.06 : 0.0),
        );
      }
    }
  }
  p.glow(0, _lens, 12, c[5], 0.6);

  for (var i = 0; i < 56; i++) {
    final a = (i / 56.0) * tau - ph * tau;
    final x = math.cos(a) * (_rad + 4.0);
    final y = top + math.sin(a) * 3.0;
    if (i % 7 < 5) {
      put(
        x,
        y,
        math.sin(a) > 0.0 ? c[6] : c[4],
        math.sin(a) > 0.0 ? 1.0 : 0.7,
      );
    }
  }
  p.glowLine(-_rad - 4.0, top, _rad + 4.0, top, 4, c[4], 0.2);

  cycle(t, _duration, 18, s + 1, (r) => r.range(0.8, 1.4),
      (age, life, r, _) {
    final k = age / life;
    final y = lerp(_lens - 2.0, top, k);
    final w = lerp(4.0, _rad + 2.0, k);
    put(
      r.range(-0.8, 0.8) * w,
      y,
      r.chance(0.3) ? kWhite : c[5],
      math.min(1.0, (1.0 - k) * 2.0),
    );
  });

  final spin = tau * ph;
  const tilt = 0.32;
  final cs = math.cos(spin);
  final ss = math.sin(spin);
  final ct = math.cos(tilt);
  final st = math.sin(tilt);
  final p3 = [
    for (final (vx, vy, vz) in _verts)
      () {
        final x1 = vx * cs + vz * ss;
        final z1 = -vx * ss + vz * cs;
        final y2 = vy * ct - z1 * st;
        final z2 = vy * st + z1 * ct;
        return (cx + x1 * _rad, cy - y2 * _rad, z2);
      }(),
  ];

  final scanY =
      lerp(cy + _rad * 1.5, cy - _rad * 1.5, ((ph * 2.0) % 1.0) / 0.8);
  for (final (i0, i1, i2) in _faces) {
    final a = p3[i0];
    final b = p3[i1];
    final d = p3[i2];
    final nz =
        (b.$1 - a.$1) * (d.$2 - a.$2) - (b.$2 - a.$2) * (d.$1 - a.$1);
    if (nz >= 0.0) continue;
    final shade = clamp(0.3 + 0.7 * ((a.$3 + b.$3 + d.$3) / 3.0 + 0.5));
    p.polyShaded(
      [(a.$1, a.$2), (b.$1, b.$2), (d.$1, d.$2)],
      color: (_, y) => (y - scanY).abs() < 2.0
          ? c[6]
          : (shade > 0.6 ? c[4] : c[3]),
      alpha: (_, y) {
        final yy = y.floor();
        return ((yy % 3 == 0 && !(flick && (yy & 1) != 0)) ||
                (y - scanY).abs() < 1.5)
            ? 1.0
            : 0.0;
      },
    );
  }

  final edges = [
    for (final (i, j) in _edges)
      (p3[i], p3[j], (p3[i].$3 + p3[j].$3) / 2.0),
  ]..sort((a, b) => a.$3.compareTo(b.$3));

  for (final (a, b, z) in edges) {
    final l = hypot(b.$1 - a.$1, b.$2 - a.$2);
    for (var d = 0.0; d <= l; d += 0.5) {
      final x = lerp(a.$1, b.$1, d / l);
      final y = lerp(a.$2, b.$2, d / l);
      final hot = (y - scanY).abs() < 1.5;
      if (z < -0.15) {
        put(x, y, hot ? c[5] : c[3], 0.7);
      } else {
        put(x, y, hot ? kWhite : (z > 0.4 ? c[6] : c[5]));
      }
    }
  }
  for (final (x, y, z) in p3) {
    if (z < -0.15) continue;
    put(x, y, kWhite);
    p.glow(x, y, 4, c[5], 0.3);
  }

  for (var i = 0; i < 64; i++) {
    final a = (i / 64.0) * tau + ph * tau * 2.0;
    final x = cx + math.cos(a) * (_rad + 9.0);
    final y = cy + 3.0 + math.sin(a) * 4.0;
    if ((i ~/ 3) % 3 == 2) continue;
    put(
      x,
      y,
      math.sin(a) > 0.0 ? (i % 9 == 0 ? kWhite : c[5]) : c[3],
      math.sin(a) > 0.0 ? 1.0 : 0.6,
    );
  }

  final lk = flick ? 0.5 : 1.0;
  p.glow(cx, cy, _rad * 2.2, c[4], 0.36 * lk);
  p.glow(cx, cy - _rad * 0.6, _rad, c[5], 0.15 * lk);
  if ((scanY - cy).abs() < _rad * 1.4) {
    p.glowLine(cx - _rad, scanY, cx + _rad, scanY, 5, c[5], 0.3 * lk);
  }
  p.glow(0, -2, 22, c[4], 0.2);
}

final PixelEffect hologramEffect = PureEffect(
  meta: const EffectMeta(
    id: 'scifi/hologram',
    name: 'Hologram',
    desc:
        'A floor projector throws a cone of light holding a turning wireframe model: scanlines roll through it, a data ring circles it, and it flickers, tears and jitters.',
    category: 'scifi',
    tags: [
      'scifi',
      'hologram',
      'projector',
      'wireframe',
      'display',
      'glitch',
      'ground',
      'loop',
    ],
    size: (112, 104),
    origin: (56, 92),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#050c1e',
        '#0a1f48',
        '#123b80',
        '#1d64b8',
        '#2e98e8',
        '#6cd0ff',
        '#c8f0ff',
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
      'split': '#ff4fd8',
      'seed': 21,
    },
  ),
  onDraw: _draw,
);
