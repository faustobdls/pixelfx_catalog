import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

final SimulatedEffect impactFrameEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'impacts/impact-frame',
    name: 'Impact frame',
    desc:
        'An anime impact: two frames of white with black burst lines rushing at the hit, two frames inverted, then the lines pull out past the edges and vanish.',
    category: 'impacts',
    tags: [
      'impact',
      'hit',
      'anime',
      'manga',
      'flash',
      'speed-lines',
      'screen',
      'one-shot',
    ],
    size: (320, 180),
    origin: (160, 90),
    duration: 0.3,
    loop: false,
    fps: 30,
    bg: BackdropKind.black,
    defaultOptions: {
      'palette': ['#000000', '#ffffff'],
      'lines': 64,
      'seed': 19,
    },
  ),
  onCreate: (o) => _ImpactFrameSim(o),
);

const double _frame = 1.0 / 30.0;

class _BurstLine {
  final double a;
  final double inner;
  final double w;

  const _BurstLine({required this.a, required this.inner, required this.w});
}

List<_BurstLine> _burst(Rng r, int n) {
  return List<_BurstLine>.generate(n, (i) {
    final thick = r.chance(0.18);
    return _BurstLine(
      a: ((i + r.range(0.1, 0.9)) / n) * tau,
      inner: thick ? r.range(30.0, 48.0) : r.range(18.0, 70.0),
      w: thick ? r.range(5.0, 8.0) : r.range(1.2, 3.6),
    );
  });
}

double _spikes(double a, double ph) =>
    10.0 +
    6.0 * math.sin(a * 5.0 + ph).abs() +
    4.0 * math.sin(a * 11.0 + ph * 2.7).abs() +
    2.0 * math.sin(a * 23.0 + ph);

class _ImpactFrameSim extends BaseEffectSim {
  static const int _w = 320;
  static const int _h = 180;
  static const double _x0 = -160.0;
  static const double _y0 = -90.0;

  late final int ink;
  late final int paper;
  final List<Uint8List> masks = [];
  double t = 0.0;

  _ImpactFrameSim(Map<String, Object?> o) {
    final c = fit(o.palette, 3);
    ink = c[0];
    paper = c[2];
    final r = Rng(o.seed);
    final nLines = o.intOpt('lines', 64);
    final sets = [_burst(r, nLines), _burst(r, nLines)];
    final jit = [
      (
        (r.range(-2.0, 2.0) + 0.5).floor(),
        (r.range(-1.0, 1.0) + 0.5).floor(),
      ),
      (
        (r.range(-2.0, 2.0) + 0.5).floor(),
        (r.range(-1.0, 1.0) + 0.5).floor(),
      ),
    ];
    final ph = [
      r.range(0.0, tau),
      r.range(0.0, tau),
      r.range(0.0, tau),
      r.range(0.0, tau),
    ];

    for (var f = 0; f < 8; f++) {
      final m = Uint8List(_w * _h);
      final set = sets[f % 2];
      final n = set.length;
      final (jx, jy) = f < 4 ? jit[f % 2] : (0, 0);
      final reach = f < 4 ? 0.0 : math.pow((f - 3) / 4.5, 1.5).toDouble();
      final thin = f < 4 ? 1.0 : 1.0 - (f - 3) / 5.5;
      for (var j = 0; j < _h; j++) {
        for (var i = 0; i < _w; i++) {
          final x = _x0 + i + 0.5 - jx;
          final y = _y0 + j + 0.5 - jy;
          final rho = hypot(x, y * 1.35);
          final ang = math.atan2(y * 1.35, x);
          final slot = ((((ang % tau) + tau) % tau) / (tau / n)).floor();
          var line = false;
          for (var k = -1; k <= 1 && !line; k++) {
            final l = set[(slot + k + n) % n];
            var d = (((ang - l.a) % tau) + tau) % tau;
            if (d > math.pi) d = tau - d;
            final inner = l.inner + reach * 150.0;
            final hw = l.w * clamp((rho - inner) / 40.0) * thin;
            line = rho > inner && d * rho < math.max(0.5, hw);
          }
          if (f < 4) {
            final r2 = hypot(x, y * 1.1);
            final core = _spikes(math.atan2(y * 1.1, x), ph[f]) *
                (f == 0 ? 0.85 : 1.0 + f * 0.08);
            m[j * _w + i] =
                r2 < core ? (r2 < 4 + f ? 2 : 1) : (line ? 1 : 2);
          } else {
            m[j * _w + i] = line ? 2 : 0;
          }
        }
      }
      masks.add(m);
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
  }

  @override
  void draw(Painter p) {
    final f = (t / _frame + 1e-6).floor();
    if (f >= 8) return;
    final m = masks[f];
    final inv = f == 2 || f == 3;
    final inkCol = inv ? paper : ink;
    final paperCol = inv ? ink : paper;
    p.shade(_x0, _y0, _x0 + _w, _y0 + _h, (x, y, _) {
      final i = (x - _x0).floor();
      final j = (y - _y0).floor();
      if (i < 0 || j < 0 || i >= _w || j >= _h) return null;
      final v = m[j * _w + i];
      if (v == 1) return inkCol;
      if (v == 2) return f < 4 ? paperCol : paper;
      return null;
    });
  }
}
