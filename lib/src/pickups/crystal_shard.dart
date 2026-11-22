// The crystal shading (a lit ridge, bright faces turned to the light, a dark rim) and the orbiting motes
// follow Sprite Fusion's open-source ice crystals and pickup (https://www.spritefusion.com/pixel-art-vfx/ice),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'pickups_lib.dart';

const double _duration = 3.2;
const double _half = 6.0;
const double _tilt = 0.18;
const double _lean = 0.2;
const double _hover = 27.0;
const double _rx = 15.0;
const double _ry = 3.8;

final SpriteLayer _shardLayer = SpriteLayer(32, 52);
final SpriteLayer _splinterLayer = SpriteLayer(16, 16);

List<double> _roll(List<double> v) => [
      v[0] * math.cos(_lean) - v[1] * math.sin(_lean),
      v[0] * math.sin(_lean) + v[1] * math.cos(_lean),
      v[2],
    ];

List<double> _unit(double x, double y, double z) {
  final l = math.sqrt(x * x + y * y + z * z);
  return [x / l, y / l, z / l];
}

final GemSolid _solid = () {
  final planes = <GemPlane>[];
  const deg = math.pi / 180.0;
  const jit = [0, 8, -6, 4, -9, 5];
  const rr = [1.0, 0.86, 1.08, 0.94, 0.82, 1.04];
  const low = [6.5, 5.5, 7.0, 6.0, 5.0, 6.8];
  for (var k = 0; k < 6; k++) {
    final a = (k * 60 + jit[k]) * deg;
    final r = 4.8 * rr[k];
    final ct = math.atan2(13.0, r);
    final cb = math.atan2(low[k], r);
    planes.add(GemPlane([math.cos(a), 0.0, math.sin(a)], r, 6));
    planes.add(GemPlane(
      [math.sin(ct) * math.cos(a), math.cos(ct), math.sin(ct) * math.sin(a)],
      math.sin(ct) * r + math.cos(ct) * _half,
      7,
    ));
    planes.add(GemPlane(
      [math.sin(cb) * math.cos(a), -math.cos(cb), math.sin(cb) * math.sin(a)],
      math.sin(cb) * r + math.cos(cb) * _half,
      8,
    ));
  }
  final shear = _unit(0.7, 0.62, 0.34);
  planes.add(GemPlane(shear, shear[1] * 7.2 + shear[0] * -0.6, 9));
  for (final (n, d) in [
    (_unit(-0.7, -0.25, 0.65), 4.0),
    (_unit(0.75, 0.15, 0.6), 3.9),
    (_unit(-0.55, 0.5, 0.3), 6.8),
  ]) {
    planes.add(GemPlane(n, d, 10));
  }
  final rolled = planes.map((q) => GemPlane(_roll(q.n), q.d, q.kind)).toList();
  return GemSolid(planes: rolled, r: 8.0, top: _half + 13.0, bottom: _half + 8.0);
}();

const List<List<List<double>>> _cracks = [
  [
    [0.5, -9.0, 0.3],
    [-0.8, -5.0, 0.5],
    [0.6, -1.0, 0.2],
    [-0.4, 3.0, 0.6],
    [1.4, 6.5, 0.4],
    [2.2, 8.5, 0.6],
  ],
  [
    [0.6, -1.0, 0.2],
    [2.4, 1.5, 1.0],
    [3.4, 4.2, 1.2],
  ],
  [
    [-0.4, 3.0, 0.6],
    [-2.0, 6.5, 0.4],
    [-2.6, 10.5, 0.2],
    [-2.4, 14.5, 0.1],
  ],
  [
    [-0.8, -5.0, 0.5],
    [-2.8, -3.0, 0.8],
  ],
];

({double y, double spin}) _pose(double ph) => (
      y: -_hover - 1.8 * math.sin(ph * tau),
      spin: 0.3 + 0.62 * math.sin(ph * tau),
    );

double _climb(double ph) => ((ph * 2.0) % 1.0) * 1.7 - 0.3;

(double, double) _project(List<double> pt, double spin, double cy) {
  final r = _roll(pt);
  final xr = r[0] * math.cos(spin) - r[2] * math.sin(spin);
  final zr = r[0] * math.sin(spin) + r[2] * math.cos(spin);
  return (xr, cy - (r[1] * math.cos(_tilt) - zr * math.sin(_tilt)));
}

void _drawCracks(
  Painter p,
  List<int> c,
  double spin,
  double cy,
  double ph,
) {
  final s0 = _climb(ph);
  final rim = c[0];
  for (final crack in _cracks) {
    for (var i = 1; i < crack.length; i++) {
      final (x0, y0) = _project(crack[i - 1], spin, cy);
      final (x1, y1) = _project(crack[i], spin, cy);
      final n = (hypot(x1 - x0, y1 - y0) * 2.0).ceil();
      for (var j = 0; j <= n; j++) {
        final u = j / n;
        final x = x0 + (x1 - x0) * u;
        final y = y0 + (y1 - y0) * u;
        final h = crack[i - 1][1] + (crack[i][1] - crack[i - 1][1]) * u;
        final col = _shardLayer.get(x, y);
        if (col == 0 || col == rim) continue;
        final diff = ((h + 9.0) / 22.0 - s0) / 0.14;
        final b = 0.3 + math.exp(-(diff * diff));
        p.px(x, y, b > 0.9 ? kWhite : (b > 0.55 ? c[6] : c[5]));
        if (j % 4 == 0 && b > 0.5) {
          p.glow(x + 0.5, y + 0.5, 2.0 + 3.0 * b, c[5], 0.16 * b);
        }
      }
    }
  }
}

void _splinter(
  Painter p,
  List<int> c,
  double x,
  double y,
  double len,
  double a,
  bool far,
) {
  final ca = math.cos(a);
  final sa = math.sin(a);
  final xi = (x + 0.5).floor();
  final yi = (y + 0.5).floor();
  _splinterLayer.begin(xi - 7, yi - 7);
  _splinterLayer.fill(xi - 7, yi - 7, xi + 6, yi + 6, (px, py) {
    final dx = px - xi;
    final dy = py - yi;
    final u = dx * ca + dy * sa;
    final v = -dx * sa + dy * ca;
    if (u.abs() / len + v.abs() / (u > 0.0 ? 1.7 : 1.1) > 1.0) return 0;
    final lit = -(ca * 0.6 + sa * 0.8) * (v == 0.0 ? 1.0 : v.sign);
    if (far) return v < 0.0 ? c[4] : c[3];
    if (v.abs() < 0.5 && u < 0.0) return kWhite;
    return (v < 0.0) == (lit > 0.0) ? c[6] : c[4];
  });
  _splinterLayer.outline(c[far ? 1 : 0]).draw(p);
}

void _splinters(
  Painter p,
  List<int> c,
  double ph,
  double cy,
  bool back,
) {
  for (var i = 0; i < 3; i++) {
    final a = ph * tau + (i * tau) / 3.0;
    final s = math.sin(a);
    if ((s < 0.0) != back) continue;
    final x = math.cos(a) * _rx;
    final y = cy + 1.0 + s * _ry - math.cos(a) * 1.5;
    final near = (s + 1.0) / 2.0;
    _splinter(p, c, x, y, 3.0 + 1.6 * near, a * 2.0 + i * 1.7, back);
    p.glow(
      x,
      y,
      6.0 + 3.0 * near,
      c[5],
      (back ? 0.18 : 0.32) * (0.6 + 0.4 * near),
    );
    if (!back && s > 0.92) {
      glint(p, x - 1.0, y - 1.0, (2.5 * (s - 0.92)) / 0.08, kWhite, 0.4);
    }
  }
}

final PureEffect crystalShardEffect = PureEffect(
  meta: const EffectMeta(
    id: 'pickups/crystal-shard',
    name: 'Crystal shard',
    desc:
        'A broken amber shard hovers and sways: chipped uneven faces, its top sheared off, light pulsing up through glowing cracks and flaring out of the break; splinters orbit it.',
    category: 'pickups',
    tags: ['pickup', 'crystal', 'shard', 'relic', 'broken', 'loop'],
    size: (64, 76),
    origin: (32, 68),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#1a0a04',
        '#3e1606',
        '#702a08',
        '#a8480c',
        '#e07818',
        '#ffa838',
        '#ffd890',
        '#ffffff',
      ],
      'seed': 8,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _duration;
    final (:y, spin: _) = _pose(ph);
    blobShadow(p, 0.0, 6.0, 0.75);
    pool(p, 0.0, 0.5, 20.0, 3.5, c[4], 0.3);
    p.glowRing(0.0, y, 7.0, 20.0, c[4], 0.22);
    _splinters(p, c, ph, y, true);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final seed = o.seed;
    final ph = t / _duration;
    final (:y, :spin) = _pose(ph);
    final s0 = _climb(ph);
    drawGem(_shardLayer, p, _solid, 0.0, y, spin, c, tilt: _tilt, gain: 0.6);
    _drawCracks(p, c, spin, y, ph);
    final diff = (s0 - 0.45) / 0.45;
    final inside = math.exp(-(diff * diff));
    p.glow(0.0, y, 10.0, c[5], 0.2 * inside);
    _splinters(p, c, ph, y, false);
    final (fx, fy) = _project(const [1.8, 8.4, 0.9], spin, y);
    final out = clamp(1.0 - (s0 - 1.05).abs() / 0.18);
    if (out > 0.0) {
      glint(p, fx, fy, 3.5 * out, kWhite, 0.55 * out);
      p.glow(fx, fy, 12.0, c[5], 0.4 * out);
    }
    const p2 = _duration / 2.0;
    const burst = ((1.05 + 0.3) / 1.7) * p2;
    for (var i = 0; i < 7; i++) {
      final born = burst + rand(i, seed, 1) * 0.12;
      final at = (((t - born) % p2) + p2) % p2;
      final life = 0.6 + rand(i, seed, 2) * 0.45;
      if (at > life) continue;
      final k = 1.0 - at / life;
      final x = fx +
          (rand(i, seed, 3) - 0.5) * 4.0 +
          math.sin(at * 5.0 + i) * 2.0 * (at / life);
      final yy = fy - at * (14.0 + rand(i, seed, 4) * 14.0);
      p.px(x, yy, k > 0.6 ? kWhite : (k > 0.3 ? c[6] : c[5]));
      p.glow(x + 0.5, yy + 0.5, 3.0, c[5], 0.35 * k);
    }
  },
);
