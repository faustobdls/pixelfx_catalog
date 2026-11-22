import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'critters_lib.dart';

const double _duration = 3.2;
final CritterGrid _grid = CritterGrid(-22, -20, 44, 40);

const List<(double, double)> _fore = [
  (0, -1), (3, -6), (8, -11), (13, -12.5),
  (16.5, -10.5), (16.5, -6), (13, -1.5), (7, 1), (2, 1.5),
];
const List<(double, double)> _hind = [
  (0, 1), (6, 1.5), (11, 4), (12.5, 8.5),
  (10.5, 12.5), (6.5, 13.5), (3, 11), (0.5, 6),
];

const List<(double, double)> _bursts = [(0.0, 0.95), (1.5, 2.55)];

bool _flapping(double t) {
  for (final (a, b) in _bursts) {
    if (t >= a && t < b) return true;
  }
  return false;
}

double _fold(double time) {
  final t = wrap(time, _duration);
  for (final (a, b) in _bursts) {
    if (t >= a && t < b) {
      final n = roundJs((b - a) * 6.3);
      final ph = ((t - a) / (b - a)) * n;
      return 0.14 + 0.86 * (0.5 + 0.5 * math.cos(ph * tau));
    }
  }
  return 1.0;
}

({double x, double y, double vx}) _at(double time) {
  final t = wrap(time, _duration);
  final a = (t / _duration) * tau;
  var lift = 0.0;
  for (final (s, e) in _bursts) {
    lift += -3.0 * math.sin(math.pi * clamp((t - s) / (e - s)));
  }
  return (
    x: 30.0 * math.sin(a) + 6.0 * math.sin(3.0 * a),
    y: 12.0 * math.sin(2.0 * a + 0.4) + lift,
    vx: math.cos(a),
  );
}

bool _inPoly(List<(double, double)> pts, double x, double y) {
  var inside = false;
  for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    final (xi, yi) = pts[i];
    final (xj, yj) = pts[j];
    if ((yi > y) != (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

double _edgeDist(List<(double, double)> pts, double x, double y) {
  var m = double.infinity;
  for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    final (ax, ay) = pts[j];
    final (bx, by) = pts[i];
    final dx = bx - ax;
    final dy = by - ay;
    final l2Raw = dx * dx + dy * dy;
    final l2 = l2Raw == 0.0 ? 1.0 : l2Raw;
    final u = clamp(((x - ax) * dx + (y - ay) * dy) / l2);
    final px = ax + dx * u - x;
    final py = ay + dy * u - y;
    m = math.min(m, hypot(px, py));
  }
  return m;
}

const List<(double, double)> _fspots = [
  (13.2, -10.2), (15.2, -8.4), (14.6, -5.6), (11.6, -11.4),
];

int _wingColor(
  List<int> c,
  List<int> sp,
  bool hind,
  double u,
  double v,
) {
  final pts = hind ? _hind : _fore;
  final e = _edgeDist(pts, u, v);
  final r = hypot(u, v);
  final ang = math.atan2(v, u);
  if (e < 1.0) return c[0];
  if (!hind) {
    if (u + v * -0.45 > 14.2 || (r > 12.5 && v < -4.0)) {
      for (final (sx, sy) in _fspots) {
        if (hypot(u - sx, v - sy) < 0.9) return c[6];
      }
      return c[0];
    }
  } else {
    if (e < 2.0 && r > 8.0) return math.sin(ang * 10.0) > 0.5 ? c[5] : c[1];
    final d = hypot(u - 7.6, v - 9.4);
    if (d < 0.7) return c[6];
    if (d < 1.4) return c[0];
    if (d < 2.2) return sp[2];
  }
  const hindVeins = [0.5, 1.0, 1.45];
  const foreVeins = [-1.2, -0.75, -0.3];
  for (final va in hind ? hindVeins : foreVeins) {
    if ((ang - va).abs() * r < 0.45 && r > 3.5) return c[1];
  }
  if (r < 3.0) return c[2];
  if (r < 6.0) return c[3];
  if (!hind && e < 2.4 && v < -3.0) return c[5];
  return c[4];
}

void _butterfly(
  CritterGrid g,
  List<int> c,
  List<int> sp,
  double w,
  double t,
) {
  g.clear();
  for (final s in const [-1, 1]) {
    for (final hind in const [true, false]) {
      final pts = hind ? _hind : _fore;
      g.shade(-20, -15, 20, 16, (x, y, _) {
        if ((x + 0.001).sign != s.toDouble()) return 0;
        final u = (x.abs() - 1.0) / w;
        final v = y;
        if (u < 0.0 || !_inPoly(pts, u, v)) return 0;
        var col = _wingColor(c, sp, hind, u, v);
        if (w < 0.5 && col != c[0]) col = mix(col, c[1], (0.5 - w) * 1.6);
        return col;
      });
    }
  }

  g.ellipse(0, 0.5, 1.6, 2.6, (nx, ny) => nx + ny < -0.4 ? c[3] : c[1]);
  for (var y = 3; y < 10; y++) {
    g.set(-1, y, y < 6 ? c[2] : c[1]);
    if (y < 8) g.set(0, y, c[1]);
  }
  g.set(-1, -3, c[3]);
  g.set(0, -3, c[2]);
  g.set(-1, -4, c[2]);
  g.set(0, -4, c[1]);
  for (final s in const [-1, 1]) {
    final tipX = s * 4.0 - (s > 0 ? 0.0 : 1.0);
    const tipY = -9.5;
    g.line(s > 0 ? 0 : -1, -5, tipX, tipY, c[2]);
    g.set(tipX, tipY, c[6]);
  }
  g.outlineShaded((_, _, _, _) => c[0]);
}

final PureEffect butterflyEffect = PureEffect(
  meta: const EffectMeta(
    id: 'critters/butterfly',
    name: 'Butterfly',
    desc:
        'An iridescent butterfly wanders a loop in bursts of quick wingbeats and open-winged glides, its veined, spotted wings shedding a twinkling trail of glowing dust.',
    category: 'critters',
    tags: ['critter', 'butterfly', 'insect', 'flying', 'magic', 'glow', 'loop'],
    size: (128, 88),
    origin: (64, 44),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.sky,
    defaultOptions: {
      'palette': [
        '#0b0f24',
        '#16224f',
        '#1f3f8a',
        '#2f74c8',
        '#4fb4f0',
        '#a0e6ff',
        '#ffffff',
      ],
      'spots': ['#3a1a08', '#c8641a', '#ffb43c', '#fff0b0'],
      'seed': 1,
    },
  ),
  onDraw: (p, time, o) {
    final seed = o.seed;
    final t = shift(time, _duration, seed);
    final c = fit(o.palette, 7);
    final sp = fit(o.rampOpt('spots'), 4);
    final s = _at(t);
    final w = _fold(t);

    cycle(t, _duration, 56, seed * 7 + 1, (r) => r.range(1.0, 1.8),
        (age, len, r, i) {
      final born = wrap(t - age, _duration);
      final b = _at(born);
      final k = age / len;
      if (!_flapping(born) && r.chance(0.45)) return;
      final x = b.x + r.range(-9.0, 9.0) + math.sin(age * 3.0 + i) * 1.5;
      final y = b.y + r.range(-4.0, 8.0) + 7.0 * age + 3.0 * age * age;
      final tw = 0.5 + 0.5 * math.sin(age * 11.0 + i * 2.1);
      final a = math.min(1.0, k * 8.0) * (1.0 - k);
      final dotCol = tw > 0.7 ? c[6] : (r.chance(0.3) ? sp[2] : c[5]);
      p.dot(x, y, dotCol, a * 1.2);
      p.glow(x, y, 6, c[4], 0.5 * a * tw);
      if (i % 9 == 0 && tw > 0.85 && k < 0.5) {
        sparkle(p, x, y, 2, c[6], c[5], 0.3 * a);
      }
    });

    final g = _grid;
    _butterfly(g, c, sp, w, t);
    g.draw(p, 1.0, s.x, s.y);

    p.glow(s.x, s.y, 38, c[4], 0.16 + 0.14 * w);
    p.glow(s.x, s.y, 12, c[5], 0.12 + 0.1 * w);
  },
);
