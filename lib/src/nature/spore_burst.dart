// The lumpy cloud (puffs that drift off their push, rise, swell from small to large and thin out, lit caps,
// motes with light) is adapted from Sprite Fusion's open-source poison cloud (https://www.spritefusion.com/pixel-art-vfx/poison),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'nature_lib.dart';

const double _grow = 0.32;
const double _puff = 0.8;
const double _sink = 2.15;
const double _dur = 3.2;

const List<(double, double, double)> _spots = [
  (-0.45, 0.45, 1.4),
  (0.1, 0.72, 1.8),
  (0.55, 0.38, 1.2),
  (-0.12, 0.25, 1.0),
  (0.3, 0.12, 0.9),
  (-0.7, 0.16, 0.8),
];

void _toadstool(
  Painter p,
  List<int> k,
  List<int> sm,
  List<int> cs,
  double g,
  double sx,
  double sy,
  double glow,
  double sink,
) {
  final h = 17 * g;
  final cw = 17 * sx * g;
  final ch = 13 * sy * g;
  final base = sink;
  final top = base - h;
  if (g < 0.05) return;

  final yEnd = math.min(0, base.floor());
  for (var y = top.floor(); y <= yEnd; y++) {
    for (var x = -4; x <= 4; x++) {
      final w = 3 + ((y - top) / h) * 1;
      if ((x + 0.5).abs() > w) continue;
      final q = (x + 0.5 + w) / (2 * w);
      p.px(
        x,
        y,
        (x + 0.5).abs() > w - 0.8
            ? sm[1]
            : q < 0.4
                ? sm[4]
                : q < 0.7
                    ? sm[3]
                    : sm[2],
      );
    }
  }
  final ring = top + h * 0.3;
  if (ring <= 0) {
    for (var x = -5; x <= 5; x++) {
      p.px(
        x,
        ring + (x.abs() > 3 ? 1 : 0),
        x.abs() > 4 ? sm[1] : sm[3],
      );
    }
  }
  final gy = top + 1;
  if (gy <= 0) {
    for (var x = (-cw).floor(); x <= cw.ceil(); x++) {
      final d = (x + 0.5).abs() / cw;
      if (d > 0.95) continue;
      p.px(x, gy, d < 0.3 ? cs[0] : ((x & 1) != 0 ? sm[2] : sm[3]));
      if (glow > 0.05) {
        p.px(x, gy, glow > 0.6 && (x & 1) != 0 ? k[7] : k[5]);
      }
    }
  }
  if (glow > 0.05) p.glow(0, gy + 2, cw * 1.5 + 6, k[5], 0.5 * glow);

  p.shade(-cw - 1, top - ch - 1, cw + 1, top + 1, (x, y, out) {
    final dx = x / cw;
    final dy = (top - y) / ch;
    final d = dx * dx + dy * dy;
    if (dy < -0.12 || d > 1.12 || y > 0) return null;
    if (d > 1) {
      out.c = cs[0];
      return null;
    }
    var i = dx < -0.35 && dy > 0.45
        ? 5
        : dx < 0.05 && dy > 0.3
            ? 4
            : dy < 0.18
                ? 2
                : dx > 0.55
                    ? 2
                    : 3;
    for (final (sx0, sy0, r) in _spots) {
      final ex = (dx - sx0) * cw;
      final ey = (dy - sy0) * ch;
      if (ex * ex + ey * ey * 1.6 < r * r * g * g) {
        i = ex < 0 && ey > 0 ? 9 : 8;
      }
    }
    out.c = i == 9 ? sm[4] : (i == 8 ? sm[3] : cs[i]);
    return null;
  });
  p.px(-cw * 0.45, top - ch * 0.8, cs[5]);
}

class _SporeBurstSim extends BaseEffectSim {
  final List<int> k;
  final List<int> cs;
  final List<int> sm;
  final Rng r;
  final Particles ps;
  final Gas gas;
  final Lights lights;

  double t = 0.0;
  bool puffed = false;
  bool grown = false;

  _SporeBurstSim._({
    required this.k,
    required this.cs,
    required this.sm,
    required this.r,
    required this.ps,
    required this.gas,
    required this.lights,
  });

  factory _SporeBurstSim(Map<String, Object?> o) {
    final k = fit(o.palette, 8);
    final cs = fit(o.rampOpt('cap'), 6);
    final sm = fit(o.rampOpt('stem'), 5);
    final r = Rng(o.seed);
    double floorFn(double _) => 0.0;
    final ps = Particles(
      rng: r,
      ground: floorFn,
      sparks: [k[7], k[6], k[5], k[4]],
      haze: k[5],
    );
    return _SporeBurstSim._(
      k: k,
      cs: cs,
      sm: sm,
      r: r,
      ps: ps,
      gas: Gas(),
      lights: Lights(),
    );
  }

  double _g() =>
      Ease.outBack(clamp(t / _grow), 1.6) *
      (1 - Ease.inCubic(clamp((t - _sink) / 0.45)));

  double _charge() => smooth(_grow, _puff, t);

  (double, double) _shape() {
    if (t < _puff) {
      final ch = _charge();
      final j = math.sin(t * 70) * 0.04 * ch;
      return (1 + 0.28 * ch + j, 1 + 0.22 * ch - j);
    }
    final e = t - _puff;
    final sp = math.exp(-e * 7) * math.cos(e * 26);
    return (1 + 0.25 * sp, 1 - 0.35 * sp);
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final f = math.min(1.0, dt * 120);
    if (!grown) {
      grown = true;
      for (var i = 0; i < 10; i++) {
        ps.spawn(
          P.grit,
          r.range(-4, 4),
          -1,
          r.range(-50, 50),
          -r.range(40, 120),
          r.range(0.5, 0.8),
          r.pick([sm[1], sm[2]]),
          1,
        );
      }
      for (var i = 0; i < 4; i++) {
        ps.spawn(
          P.dust,
          r.range(-4, 4),
          -1,
          r.sign() * r.range(10, 40),
          -r.range(4, 12),
          r.range(0.4, 0.7),
          sm[1],
          r.range(2, 3),
        );
      }
    }
    if (t > _grow && t < _puff - 0.05 && r.chance(0.25 * f)) {
      final a = r.range(math.pi * 1.05, math.pi * 1.95);
      final d = r.range(20, 38);
      final x = math.cos(a) * d;
      final y = -18 + math.sin(a) * d * 0.7;
      ps.spawn(P.streak, x, y, -x * 3, (-18 - y) * 3, r.range(0.2, 0.3), k[6]);
    }
    if (!puffed && t >= _puff) {
      puffed = true;
      lights.add(0, -22, 30, kWhite, 0.6, 0.1);
      lights.add(0, -28, 70, k[5], 0.55, 0.9);
      for (var i = 0; i < 30; i++) {
        final a = -math.pi / 2 + r.range(-1.1, 1.1);
        final sp = r.range(15, 95);
        gas.add(
          t,
          r.range(-8, 8),
          -20 + r.range(-3, 3),
          math.cos(a) * sp * 1.3,
          math.sin(a) * sp - 10,
          r.range(3, 5),
          r.range(8, 14),
          t + r.range(1.6, 2.2),
          r.range(5, 10),
        );
      }
      for (var i = 0; i < 6; i++) {
        final sd = r.sign();
        gas.add(
          t,
          sd * r.range(6, 12),
          -5,
          sd * r.range(30, 70),
          -r.range(2, 14),
          r.range(2, 3),
          r.range(4, 6),
          t + r.range(0.8, 1.1),
          r.range(4, 8),
        );
      }
      for (var i = 0; i < 40; i++) {
        final a = -math.pi / 2 + r.range(-1.4, 1.4);
        final sp = r.range(40, 160);
        final mote = r.chance(0.5);
        final scale = mote ? 0.35 : 0.7;
        ps.spawn(
          mote ? P.mote : P.flake,
          r.range(-5, 5),
          -20,
          math.cos(a) * sp * scale,
          math.sin(a) * sp * scale,
          r.range(1, 2),
          r.pick([k[7], k[6], k[6], k[5]]),
          r.range(0.6, 1.6),
        );
      }
      for (var i = 0; i < 6; i++) {
        ps.spawn(
          P.star,
          r.range(-20, 20),
          -r.range(12, 40),
          0,
          -6,
          r.range(0.3, 0.6),
          k[7],
          r.range(1, 2.4),
          r.range(0.05, 0.4),
        );
      }
      for (var i = 0; i < 8; i++) {
        ps.spawn(
          P.dust,
          r.sign() * r.range(4, 10),
          -1,
          r.sign() * r.range(30, 90),
          -r.range(2, 10),
          r.range(0.5, 0.9),
          k[3],
          r.range(2, 3.5),
        );
      }
    }
    if (puffed && t < 2.6 && r.chance(0.12 * f)) {
      ps.spawn(
        P.flake,
        r.range(-40, 40),
        -r.range(30, 70),
        r.range(-8, 8),
        r.range(4, 14),
        math.min(r.range(0.9, 1.5), _dur - 0.05 - t),
        r.chance(0.5) ? k[7] : k[6],
        r.range(0.6, 1.5),
      );
    }
    if (t > _sink && t < _sink + 0.4 && r.chance(0.15 * f)) {
      ps.spawn(
        P.dust,
        r.range(-5, 5),
        -1,
        r.sign() * r.range(10, 30),
        -r.range(2, 8),
        r.range(0.3, 0.5),
        sm[1],
        r.range(1.5, 2.5),
      );
    }
    gas.prune(t);
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final ch = _charge() * (1 - smooth(_puff + 0.2, _puff + 1.2, t));
    if (ch > 0) {
      for (var x = -20; x <= 20; x++) {
        p.dot(x, 0, x.abs() < 10 ? k[5] : k[4], ch * (1 - x.abs() / 21));
      }
    }
    p.glow(0, -2, 30, k[4], 0.25 * ch);
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final (sx, sy) = _shape();
    final gl = t < _puff
        ? _charge() * (0.75 + 0.25 * math.sin(t * (20 + 30 * _charge())))
        : math.max(0.0, 1 - (t - _puff) * 1.5);
    _toadstool(
      p,
      k,
      sm,
      cs,
      _g(),
      sx,
      sy,
      gl,
      Ease.inCubic(clamp((t - _sink) / 0.45)) * 20,
    );
    gas.draw(p, t, k[2], k[4], k[6], k[7], 0.62, k[6]);
    if (gas.list.isNotEmpty) {
      var cx = 0.0;
      var cy = 0.0;
      var n = 0.0;
      for (final q in gas.list) {
        final g2 = gas.at(q, t);
        cx += g2.x * g2.a;
        cy += g2.y * g2.a;
        n += g2.a;
      }
      if (n > 0.2) p.glow(cx / n, cy / n, 46, k[5], math.min(0.32, 0.03 * n));
    }
    final e = t - _puff;
    if (e > 0 && e < 0.1) {
      sparkle(p, 0, -20, 10 * (1 - e / 0.1), k[7], k[6], 0.6);
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final PixelEffect sporeBurst = SimulatedEffect(
  meta: const EffectMeta(
    id: 'nature/spore-burst',
    name: 'Spore burst',
    desc:
        'A toadstool pushes up, swells and trembles as its gills glow, then squashes and puffs a lumpy cloud of glowing spores that billows up and drifts down twinkling.',
    category: 'nature',
    tags: [
      'nature',
      'mushroom',
      'spores',
      'poison',
      'cloud',
      'ground',
      'one-shot',
    ],
    size: (212, 132),
    origin: (106, 118),
    duration: 3.2,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#06141c',
        '#0c2a34',
        '#11484e',
        '#17706a',
        '#22a08a',
        '#4cd0a8',
        '#a8f4d0',
        '#f0fff6',
      ],
      'cap': ['#1a0c1e', '#3a1438', '#62204e', '#8e3462', '#bc5276', '#e88a96'],
      'stem': ['#2a2230', '#5a4e5e', '#9a8e98', '#d8ccd0', '#f6eeee'],
      'seed': 9,
    },
  ),
  onCreate: _SporeBurstSim.new,
);
