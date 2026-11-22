import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'water_lib.dart';

const double _d = 2.0;
const double _sy = 0.26;
const double _every = 0.5;
const double _life = 2.0;
const double _rmax = 60.0;
const int _patch = 64;

double _radius(double a) => 2.0 + (_rmax - 2.0) * Ease.outCubic(a / _life);
double _power(double a) =>
    math.pow(1.0 - a / _life, 1.5) * math.min(1.0, a / 0.08);

List<(double, int)> _alive(double t) {
  final out = <(double, int)>[];
  for (var k = 0; k * _every < _life; k++) {
    final a = ((t - k * _every) % _d + _d) % _d;
    if (a < _life) {
      final idx = ((((t - a) % _d + _d) % _d) / _every).round();
      out.add((a, idx));
    }
  }
  return out;
}

void _surface(Painter p, List<int> c, double t) {
  final rs = [
    for (final (a, _) in _alive(t)) (_radius(a), _power(a), 3.0 + a * 2.2),
  ];
  for (var yi = (-_patch * _sy).floor(); yi < _patch * _sy; yi++) {
    for (var xi = -_patch; xi < _patch; xi++) {
      final x = xi + 0.5;
      final y = yi + 0.5;
      final z = y / _sy;
      final r = hypot(x, z);
      final e = r / _patch;
      if (e > 1.0) continue;
      final edge = 1.0 - smooth(0.6, 1.0, e);
      p.blend(x, y, c[1], 0.55 * edge);
      var slope = 0.0;
      for (final (rad, k, w) in rs) {
        final d = r - rad;
        if (d > 2.2 * w || d < -2.2 * w) continue;
        slope += k * math.exp(-((d / w) * (d / w))) * -math.sin(d * 1.15) * 1.15;
      }
      if (slope == 0.0) continue;
      final face = slope * (-(x * -0.55 + z * -0.84) / math.max(1.0, r));
      if (face > 0.18) {
        p.blend(
          x,
          y,
          face > 0.6 ? c[5] : c[4],
          math.min(0.9, (face - 0.18) * 2.2) * edge,
        );
      } else if (face < -0.25) {
        p.blend(x, y, c[0], math.min(0.8, (-face - 0.25) * 2.0) * edge);
      }
    }
  }
}

void _rings(Painter p, List<int> c, double t, int half) {
  for (final (a, i) in _alive(t)) {
    final rad = _radius(a);
    final k = _power(a);
    ring(
      p,
      0.0,
      0.0,
      rad,
      _sy,
      0.85 * k,
      c,
      n: 2,
      gap: 3.0 + a * 1.4,
      half: half,
      hot: a < 0.14,
      glint: half > 0 && a > 0.1 ? k : 0.0,
      seed: i + 1,
      wob: 0.4 + a * 1.1,
    );
  }
}

final PureEffect ripplesEffect = PureEffect(
  meta: const EffectMeta(
    id: 'water/ripples',
    name: 'Ripples',
    desc:
        'A drop plinks on still dark water and rings spread out across it at a low angle: the swell of each ring catches the light, crests glint, and they fade into the calm.',
    category: 'water',
    tags: ['water', 'ripples', 'rings', 'surface', 'pond', 'ambient', 'loop'],
    size: (136, 52),
    origin: (68, 30),
    duration: 2.0,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': kWaterPalette,
      'seed': 2,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    _surface(p, c, t);
    _rings(p, c, t, -1);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final s = o.seed;
    _rings(p, c, t, 1);
    for (final (a, _) in _alive(t)) {
      if (a < 0.08) {
        p.px(0, 0, kWhite);
        p.px(-1, 0, c[6]);
        p.px(1, 0, c[6]);
        p.glow(0, 0, 8, c[5], 0.5 * (1.0 - a / 0.08));
      }
      final b = a - 0.04;
      final h = 90.0 * b - 0.5 * 700.0 * b * b;
      if (b > 0.0 && h > 0.0) {
        p.px(0, -h, kWhite);
        p.px(0, -h + 1.0, c[5]);
      }
    }
    cycle(t, _d, 10, s + 5, (g) => g.range(0.25, 0.45), (age, life, r, _) {
      final all = _alive(t);
      final idx = (r.next() * all.length).floor();
      final a = all.isNotEmpty ? all[idx].$1 : 0.0;
      final ang = r.range(0.3, math.pi - 0.3);
      final rad = _radius(a);
      final k = math.sin((math.pi * age) / life) * _power(a);
      if (k < 0.15 || rad < 6.0) return;
      final x = math.cos(ang) * rad;
      final y = math.sin(ang) * rad * _sy;
      p.px(x, y, kWhite);
      if (k > 0.5) {
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          p.px(x + dx, y + dy, c[6]);
        }
      }
      p.glow(x, y, 5, c[5], 0.4 * k);
    });
    p.glow(0, 0, 40, c[4], 0.14);
    p.glow(0, 0, 14, c[5], 0.12);
  },
);
