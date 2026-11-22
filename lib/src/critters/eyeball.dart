import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'critters_lib.dart';

const double _duration = 3.2;
final CritterGrid _grid = CritterGrid(-18, -18, 36, 38);
final CritterGrid _nerve = CritterGrid(-20, -70, 40, 64);
const double _r = 13.0;
final int _vein = hex('#c42a3a');
final int _shadowBg = hex('#0d0a12');

const List<(double, double, double)> _looks = [
  (0.0, 0.0, 0.0),
  (0.55, 4.2, -1.2),
  (1.15, -4.4, 0.8),
  (1.95, 1.2, 3.4),
  (2.5, -2.0, -3.4),
  (3.0, 0.0, 0.0),
];

(double, double) _look(double t) {
  var i = _looks.length - 1;
  while (i > 0 && t < _looks[i].$1) {
    i--;
  }
  final (t0, x1, y1) = _looks[i];
  final (_, x0, y0) = _looks[(i + _looks.length - 1) % _looks.length];
  final u = Ease.outBack(clamp((t - t0) / 0.08), 2.2);
  return (lerp(x0, x1, u), lerp(y0, y1, u));
}

double _lid(double t) => (t > 1.74 && t < 1.92)
    ? math.sin(math.pi * ((t - 1.74) / 0.18))
    : 0.0;

({double x, double y}) _at(double t, double hover) {
  final a = (t / _duration) * tau;
  return (
    x: 1.5 * math.sin(a),
    y: -hover - 3.0 * math.sin(2.0 * a + 0.4),
  );
}

List<List<(double, double)>> _veins(int seed) {
  final out = <List<(double, double)>>[];
  final r = rng(seed, 77);
  for (var i = 0; i < 7; i++) {
    var a = (i / 7.0) * tau + r.range(-0.3, 0.3);
    var d = _r - 0.5;
    final pts = <(double, double)>[(math.cos(a) * d, math.sin(a) * d)];
    for (var k = 0; k < 4; k++) {
      a += r.range(-0.35, 0.35);
      d -= r.range(1.2, 2.1);
      pts.add((math.cos(a) * d, math.sin(a) * d));
    }
    out.add(pts);
  }
  return out;
}

void _eye(
  CritterGrid g,
  List<int> c,
  List<int> fl,
  List<int> iris,
  double t,
  int seed,
) {
  g.clear();
  final (lx, ly) = _look(t);
  final l = _lid(t);
  final v = _veins(seed);
  bool lit(double x, double y, double k) =>
      hypot(-4.0 + (x + 4.0) / k, -4.5 + (y + 4.5) / k) <= _r;

  g.shade(-_r, -_r, _r, _r, (x, y, _) {
    final d = hypot(x, y);
    if (d > _r) return 0;
    if (hypot(x + 2.0, y + 2.2) > _r) return c[2];
    return lit(x, y, 0.5) ? c[5] : (lit(x, y, 0.8) ? c[4] : c[3]);
  });

  for (final pts in v) {
    final sh = <(double, double)>[
      for (final (px, py) in pts)
        (
          px + lx * 0.35 * (1.0 - hypot(px, py) / _r),
          py + ly * 0.35 * (1.0 - hypot(px, py) / _r),
        ),
    ];
    for (var k = 1; k < sh.length; k++) {
      g.line(
        sh[k - 1].$1,
        sh[k - 1].$2,
        sh[k].$1,
        sh[k].$2,
        k < 2 ? _vein : mix(_vein, c[3], 0.45),
      );
    }
  }

  final fx = 1.0 - 0.32 * math.pow(lx.abs() / _r, 1.4) * 3.0;
  final fy = 1.0 - 0.32 * math.pow(ly.abs() / _r, 1.4) * 3.0;
  const ir = 6.4;
  final pr = 2.0 + 0.4 * math.sin((t / _duration) * tau * 2.0);
  g.shade(lx - ir - 1.0, ly - ir - 1.0, lx + ir + 1.0, ly + ir + 1.0,
      (x, y, _) {
    final dx = (x - lx) / (ir * fx);
    final dy = (y - ly) / (ir * fy);
    final d = hypot(dx, dy);
    if (d > 1.0 || hypot(x, y) > _r - 0.5) return 0;
    final pd = hypot((x - lx) / fx, (y - ly) / fy);
    if (pd < pr) return c[0];
    if (d > 0.86) return iris[0];
    final ang = math.atan2(dy, dx);
    final streak = math.sin(ang * 9.0 + d * 4.0) > 0.5;
    if (d < 0.5) return streak ? iris[4] : iris[3];
    if (d < 0.7) return streak ? iris[3] : iris[2];
    return streak ? iris[2] : iris[1];
  });

  if (l < 0.5) {
    g.set(-4, -5, c[5]);
    g.set(-3, -5, c[5]);
    g.set(-4, -4, c[5]);
    g.set(1, -2, c[5]);
  }

  final up = lerp(-_r + 3.0, _r * 0.42, l);
  final dn = lerp(_r - 2.2, _r * 0.42, l);
  bool flit(double x, double y, double k) =>
      hypot(-4.0 + (x + 4.0) / k, -5.0 + (y + 5.0) / k) <= _r + 0.6;
  g.shade(-_r - 1.0, -_r - 1.0, _r + 1.0, _r + 1.0, (x, y, _) {
    final d = hypot(x, y);
    if (d > _r + 0.6) return 0;
    final ue = up + 1.8 * math.pow(x / _r, 2);
    final de = dn - 1.4 * math.pow(x / _r, 2);
    final tone = hypot(x + 2.0, y + 2.2) > _r + 0.6
        ? fl[1]
        : (flit(x, y, 0.55)
            ? fl[4]
            : (flit(x, y, 0.85) ? fl[3] : fl[2]));
    if (y < ue) return y > ue - 1.2 ? fl[0] : tone;
    if (y > de) return y < de + 1.1 ? fl[0] : (tone == fl[4] ? fl[3] : tone);
    return 0;
  });
  g.outline(c[0]);
}

final PureEffect eyeballEffect = PureEffect(
  meta: const EffectMeta(
    id: 'critters/eyeball',
    name: 'Eyeball',
    desc:
        'A bloodshot eyeball floats in its fleshy lids: its glowing iris snaps from one look to the next, it blinks, and its nerve sways behind it as it bobs.',
    category: 'critters',
    tags: ['critter', 'eyeball', 'eye', 'monster', 'spooky', 'float', 'loop'],
    size: (96, 108),
    origin: (48, 100),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#2a1420',
        '#6a3040',
        '#b07078',
        '#dcbcb4',
        '#f4e9de',
        '#ffffff',
      ],
      'flesh': ['#1e0c16', '#4a1a2c', '#7c2c40', '#b04a58', '#e07a80'],
      'iris': ['#0c2a14', '#1f6a2a', '#3fae3a', '#9be05a', '#e8ffb0'],
      'hover': 48,
      'seed': 1,
    },
  ),
  onDrawBack: (p, time, o) {
    final t = shift(time, _duration, o.seed);
    final iris = fit(o.rampOpt('iris'), 5);
    final s = _at(t, o.numOpt('hover', 48.0));
    shadow(p, s.x, 0, 10, 1.5, _shadowBg, 0.5);
    for (var x = -26; x <= 26; x += 6) {
      p.glow(s.x + x, -1, 18, iris[2], 0.15 * (1.0 - x.abs() / 34.0));
    }
  },
  onDraw: (p, time, o) {
    final seed = o.seed;
    final hover = o.numOpt('hover', 48.0);
    final t = shift(time, _duration, seed);
    final c = fit(o.palette, 6);
    final fl = fit(o.rampOpt('flesh'), 5);
    final iris = fit(o.rampOpt('iris'), 5);
    final s = _at(t, hover);

    final ng = _nerve.clear();
    for (var ss = 0.0; ss <= 20.0; ss += 0.5) {
      final b = _at(t - ss * 0.035, hover);
      final sw = 2.6 *
          math.pow(ss / 20.0, 1.3) *
          math.sin((t / _duration) * tau * 2.0 - ss * 0.16);
      final r = lerp(2.0, 0.6, ss / 20.0);
      final cx = b.x + 1.0 + sw;
      final cy = b.y + _r - 2.0 + ss;
      ng.shade(cx - r - 1.0, cy - 1.0, cx + r + 1.0, cy + 1.0, (x, y, _) {
        final v = (x - cx) / math.max(0.6, r);
        if (v.abs() > 1.0 || (y - cy).abs() > 0.5) return 0;
        return v < -0.35 ? fl[4] : (v < 0.4 ? fl[3] : fl[2]);
      });
    }
    ng.outline(fl[0]);
    ng.draw(p);

    final g = _grid;
    _eye(g, c, fl, iris, t, seed);
    g.draw(p, 1.0, s.x, s.y);

    final (lx, ly) = _look(t);
    var snap = 0.0;
    for (final (t0, _, _) in _looks) {
      final v = math.max(
        0.0,
        1.0 - (wrap(t - t0 + _duration / 2.0, _duration) - _duration / 2.0).abs() / 0.2,
      );
      if (v > snap) snap = v;
    }
    final open = 1.0 - _lid(t);
    p.glow(s.x + lx, s.y + ly, 15, iris[3], (0.5 + 0.3 * snap) * open);
    p.glow(s.x + lx, s.y + ly, 5, iris[4], 0.4 * open);
    p.glow(s.x, s.y, 50, iris[1], 0.3);

    for (var i = 0; i < 8; i++) {
      final sp = (i.isOdd ? 1 : -1) * (i % 3 != 0 ? 1 : 2);
      final a0 = (i * tau) / 8.0;
      final rr = 19.0 + (i % 3) * 2.0;
      (double, double)? prev;
      for (var k = 5; k >= 0; k--) {
        final a = (t / _duration) * tau * sp + a0 - sp * k * 0.035;
        final z = math.sin(a);
        final x = s.x + math.cos(a) * rr;
        final y = s.y + z * 5.0 - math.cos(a) * 3.0;
        if (z < 0.0 && hypot(x - s.x, y - s.y) < _r + 1.0) {
          prev = null;
          continue;
        }
        if (prev != null && k > 0) {
          p.line(prev.$1, prev.$2, x, y, iris[2], 0.4 + (5 - k) * 0.12);
        }
        if (k == 0) {
          p.px(x, y, z > 0.0 ? iris[4] : iris[3]);
          p.glow(x, y, 5, iris[3], 0.45);
        }
        prev = (x, y);
      }
    }
  },
);
