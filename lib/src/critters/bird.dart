import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'critters_lib.dart';

const double _duration = 2.4;
final CritterGrid _grid = CritterGrid(-26, -26, 52, 46);
final int _beak = hex('#f0b030');
final int _beakD = hex('#a86a18');

const List<(double, double)> _poseUp = [
  (0, 0), (-1, -8), (-5, -15), (-8, -13.5),
  (-10.5, -10.5), (-11, -7), (-9, -3), (-6, 1),
];
const List<(double, double)> _poseMid = [
  (0, 0), (-3, -2.5), (-9, -2.5), (-10.5, -0.5),
  (-10, 1.2), (-8.5, 2), (-7, 2.2), (-5, 2),
];
const List<(double, double)> _poseDown = [
  (0, 0), (-1, 6), (-3.5, 12), (-6, 11),
  (-7.5, 8.5), (-8, 6), (-7, 3), (-5, 2),
];
const List<(double, double)> _poseFold = [
  (0, 0), (-3, -4), (-10, -5.5), (-11, -4),
  (-10, -2.5), (-8.5, -1), (-7, 0.5), (-5, 1.5),
];
const List<(double, double)> _poseGlide = [
  (0, 0), (-2, -5), (-7, -10), (-10, -9),
  (-12, -6.5), (-11.5, -3.5), (-9, -1), (-6, 1),
];

List<(double, double)> _mixPose(
  List<(double, double)> a,
  List<(double, double)> b,
  double u,
) =>
    [
      for (var i = 0; i < a.length; i++)
        (lerp(a[i].$1, b[i].$1, u), lerp(a[i].$2, b[i].$2, u)),
    ];

const int _flaps = 4;
const double _glide = 1.5;

({List<(double, double)> pts, bool down, double u}) _wing(double time) {
  final t = wrap(time, _duration);
  if (t < _glide) {
    final u = ((t / _glide) * _flaps).remainder(1.0);
    if (u < 0.4) {
      final k = Ease.inOutSine(u / 0.4);
      return (
        pts: k < 0.5
            ? _mixPose(_poseUp, _poseMid, k * 2.0)
            : _mixPose(_poseMid, _poseDown, k * 2.0 - 1.0),
        down: true,
        u: u,
      );
    }
    final k = Ease.inOutSine((u - 0.4) / 0.6);
    return (
      pts: k < 0.5
          ? _mixPose(_poseDown, _poseFold, k * 2.0)
          : _mixPose(_poseFold, _poseUp, k * 2.0 - 1.0),
      down: false,
      u: u,
    );
  }
  final g = (t - _glide) / (_duration - _glide);
  final into = smooth(0.0, 0.15, g);
  final out = smooth(0.85, 1.0, g);
  return (
    pts: _mixPose(_mixPose(_poseUp, _poseGlide, into), _poseUp, out),
    down: false,
    u: 0.0,
  );
}

double _lift(double time) {
  final t = wrap(time, _duration);
  var y = 0.0;
  for (var k = 0; k < 6; k++) {
    if (_wing(t - k * 0.02).down) y -= 0.45;
  }
  if (t >= _glide) {
    y += 2.2 * math.sin(math.pi * ((t - _glide) / (_duration - _glide)));
  }
  return y + 1.2;
}

const (double, double) _sh = (1.0, -2.0);

List<(double, double)> _wingPts(
  ({List<(double, double)> pts, bool down, double u}) w,
  bool far,
) =>
    [
      for (final (x, y) in w.pts)
        (
          _sh.$1 + x - (far ? 1.0 : 0.0),
          _sh.$2 + y * (far ? 0.85 : 1.0) - (far ? 1.0 : 0.0),
        ),
    ];

bool _inBody(double x, double y) {
  final bx = (x + 1.0) / 8.5;
  final by = y / 5.2;
  final hx = x - 6.5;
  final hy = y + 3.0;
  return bx * bx + by * by <= 1.0 || hx * hx + hy * hy <= 4.6 * 4.6;
}

void _bird(
  CritterGrid g,
  List<int> c,
  List<int> br,
  double t,
  ({List<(double, double)> pts, bool down, double u}) w,
) {
  g.clear();
  g.poly(_wingPts(w, true), c[1]);

  final tf = 0.25 + 0.35 * math.sin((t / _duration) * tau * 2.0);
  for (var i = 0; i < 3; i++) {
    final a = math.pi + (i - 1) * tf * 0.5 + 0.1;
    final len = 9.0 - (i - 1).abs();
    final tx = -7.0 + math.cos(a) * len;
    final ty = -1.0 + math.sin(a) * len;
    g.poly(
      [(-7.0, -2.4), (tx, ty - 1.2), (tx, ty + 1.2), (-7.0, 0.6)],
      i == 0 ? c[3] : c[2],
    );
  }

  g.shade(-10, -9, 12, 6, (x, y, _) {
    if (!_inBody(x, y)) return 0;
    final top = !_inBody(x, y - 2.2);
    final under = !_inBody(x + 0.5, y + 1.6);
    if (y > -0.5 && x > -2.5) {
      return under ? br[1] : (x > 3.0 && y < 2.0 ? br[3] : br[2]);
    }
    if (y > 1.5) return under ? c[4] : c[5];
    if (top) return x > 2.0 ? c[5] : c[4];
    return (y < -3.5 && x > 3.0) ? c[4] : c[3];
  });

  g.polyFn(
    const [(10.5, -4.5), (14.5, -3.0), (10.5, -2.0)],
    (_, y) => y < -3.0 ? _beak : _beakD,
  );
  g.set(8, -4, c[0]);
  g.set(8, -5, c[6]);
  g.set(9, -4, c[0]);
  g.line(5, -7, 9, -6.5, c[2]);

  final wp = _wingPts(w, false);
  double edge(double x, double y) {
    var m = double.infinity;
    for (var i = 1; i < 3; i++) {
      final (ax, ay) = wp[i - 1];
      final (bx, by) = wp[i];
      final dx = bx - ax;
      final dy = by - ay;
      final l2Raw = dx * dx + dy * dy;
      final l2 = l2Raw == 0.0 ? 1.0 : l2Raw;
      final u = clamp(((x - ax) * dx + (y - ay) * dy) / l2);
      m = math.min(m, hypot(ax + dx * u - x, ay + dy * u - y));
    }
    return m;
  }

  g.polyFn(wp, (x, y) {
    final d = edge(x, y);
    return d < 1.2 ? c[5] : (d < 3.0 ? c[4] : c[3]);
  });
  for (var i = 3; i < 7; i++) {
    g.line(
      wp[1].$1,
      wp[1].$2,
      lerp(wp[1].$1, wp[i].$1, 0.92),
      lerp(wp[1].$2, wp[i].$2, 0.92),
      c[2],
    );
  }
  g.outline(c[0]);
}

final PureEffect birdEffect = PureEffect(
  meta: const EffectMeta(
    id: 'critters/bird',
    name: 'Bird',
    desc:
        'A songbird flies in place: bursts of wingbeats that lift its body on each downstroke, a glide on spread wings, its tail fanning, a loose feather drifting away.',
    category: 'critters',
    tags: ['critter', 'bird', 'flying', 'animal', 'loop'],
    size: (112, 80),
    origin: (56, 40),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.sky,
    defaultOptions: {
      'palette': [
        '#0a0e1e',
        '#18244a',
        '#24407a',
        '#3466aa',
        '#5a94d4',
        '#9cc8f0',
        '#eaf6ff',
      ],
      'breast': ['#4a1a0e', '#a8441c', '#e8783a', '#ffb070'],
      'seed': 1,
    },
  ),
  onDraw: (p, time, o) {
    final t = shift(time, _duration, o.seed);
    final c = fit(o.palette, 7);
    final br = fit(o.rampOpt('breast'), 4);
    final w = _wing(t);
    final y = _lift(t);
    final g = _grid;

    if (w.down && w.u > 0.1) {
      final s = t - 0.05;
      final ws = _wing(s);
      g.clear();
      g.poly(_wingPts(ws, false), c[6]);
      g.fillAlpha(0.42);
      g.draw(p, 1.0, 0.0, roundJs(_lift(s)).toDouble());
    }
    _bird(g, c, br, t, w);
    g.draw(p, 1.0, 0.0, roundJs(y).toDouble());

    final fa = wrap(t - 0.45, _duration);
    if (fa < 1.8) {
      final fx = -6.0 - 14.0 * fa - 3.0 * math.sin(fa * 5.0);
      final fy = 4.0 + 9.0 * fa + 1.5 * math.cos(fa * 5.0) * fa;
      final rock = math.sin(fa * 5.0) * 0.8;
      final a = math.min(1.0, (1.8 - fa) * 2.0);
      for (var i = -2; i <= 2; i++) {
        p.dot(
          fx + i * math.cos(rock),
          fy + i * math.sin(rock) * 0.8,
          i < 0 ? c[5] : c[4],
          a,
        );
      }
      p.dot(
        fx + 2.6 * math.cos(rock),
        fy + 2.6 * math.sin(rock) * 0.8,
        c[3],
        a,
      );
    }
    p.glow(2, y - 6, 16, c[5], 0.12);
  },
);
