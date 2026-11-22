// The column recipe (ramp bands out from a white core, drifting strands, dithered edges, light every few rows)
// is adapted from Sprite Fusion's open-source holy light (https://www.spritefusion.com/pixel-art-vfx/holy-light),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'pickups_lib.dart';

const double _duration = 2.4;
const int _h = 150;
const List<double> _rings = [0.08, 0.58];
const int _ox = 4;

final List<int> _steel = [
  '#151726',
  '#2c3149',
  '#4f5775',
  '#8a93b3',
  '#d6dcef',
  '#ffffff',
].map(hex).toList();
final List<int> _gold = [
  '#3a2008',
  '#7a4a10',
  '#b8801c',
  '#e8b432',
  '#ffe27a',
  '#fff6cc',
].map(hex).toList();
final List<int> _leather = ['#1e0f0e', '#3e2016', '#633620'].map(hex).toList();
final int _ink = hex('#0d0b14');
final SpriteLayer _swordLayer = SpriteLayer(40, 24);

double _since(double ph, int k) =>
    (((ph - _rings[k]) % 1.0) + 1.0) % 1.0;

int _axis(int x) => (-4.0 + (x + 4) / 7.0 + 0.5).floor();

void _sword(Painter p, List<int> c, double ph) {
  int edgeLit(int x) =>
      (x + _ox - 0.5).abs() < 6.0 ? c[6] : mix(_steel[4], c[6], 0.45);

  _swordLayer.begin(-16, -12);
  void setPx(int x, int y, int col) => _swordLayer.set(x + _ox, y, col);

  for (var x = -11; x <= 10; x++) {
    final a = _axis(x);
    if (x <= -9) {
      final m = x + 10;
      if (m == 0) {
        setPx(x, a - 1, c[6]);
        setPx(x, a, kWhite);
        setPx(x, a + 1, c[4]);
      } else {
        setPx(x, a, m < 0 ? c[5] : c[3]);
      }
    } else if (x <= -5) {
      setPx(x, a, _leather[x % 2 != 0 ? 2 : 1]);
      setPx(x, a + 1, _leather[x % 2 != 0 ? 1 : 0]);
    } else if (x <= -3) {
      for (var y = a - 3; y <= a + 3; y++) {
        final end = y == a - 3 || y == a + 3;
        setPx(
          x,
          y,
          y == a
              ? (x == -4 ? c[6] : c[4])
              : (x == -4
                  ? (end ? _gold[3] : mix(_gold[4], c[6], 0.3))
                  : (end ? _gold[0] : _gold[1])),
        );
      }
    } else {
      final tip = x - 8;
      if (tip < 1) setPx(x, a - 1, edgeLit(x));
      if (tip < 2) {
        setPx(x, a, tip == 1 ? edgeLit(x) : mix(_steel[3], c[4], 0.2));
      }
      setPx(x, a + 1, tip == 2 ? _steel[2] : _steel[0]);
    }
  }
  _swordLayer.outline(_ink).draw(p);
  final g = (ph - 0.72) / 0.16;
  if (g > 0.0 && g < 1.0) {
    final x = -1.0 + 9.0 * Ease.inOutSine(g);
    glint(
      p,
      x + _ox,
      _axis((x + 0.5).floor()) - 1.0,
      2.6 * math.sin(g * math.pi),
      kWhite,
      0.5,
    );
  }
}

void _ring(Painter p, List<int> c, double a, bool back) {
  const l1 = 1.1;
  final k = a / l1;
  if (k >= 1.0) return;
  final r = 3.0 + 24.0 * Ease.outCubic(k);
  final th = math.max(1.0, 3.2 * (1.0 - k));
  band(
    p,
    0.5,
    0.0,
    r,
    0.2,
    th,
    math.min(1.0, 1.25 * (1.0 - k)),
    [c[2], c[4], c[5], c[6]],
    keep: (g) => (math.sin(g) < 0.0) == back,
    hot: k < 0.12,
  );
  if (!back) {
    for (final s in const [-1, 1]) {
      p.glow(0.5 + s * r, -1.0, 8.0, c[5], 0.35 * (1.0 - k));
    }
  }
}

void _column(Painter p, List<int> c, double t) {
  final ph = t / _duration;
  var beat = 0.0;
  for (var k = 0; k < _rings.length; k++) {
    final s = _since(ph, k) * _duration;
    beat = math.max(
      beat,
      math.max(
        math.exp(-s * 7.0) * (s < 0.5 ? 1.0 : 0.0),
        math.exp(-((_duration - s) * 30.0)),
      ),
    );
  }
  final gq = (ph - 0.22) / 0.42;
  final gh = gq > 0.0 && gq < 1.0 ? 4.0 + (_h - 4) * Ease.inQuad(gq) : -100.0;
  final shimmer = (ph * 24.0).floor();
  for (var y = -1; y >= -_h; y--) {
    final h = -y - 0.5;
    final u = h / _h;
    final fade = 1.0 - smooth(0.25, 1.0, u);
    final w = (4.2 * (1.0 - 0.45 * u) + 3.2 * math.exp(-h / 7.0)) *
        (1.0 + 0.2 * beat);
    final seg = (h / 3.0 + rand((h / 9.0).floor(), 5) * 2.0).floor();
    final flick = (ph * 12.0).floor();
    if (u > 0.66 && rand(seg, flick, 7) > 1.75 - u * 1.65) continue;
    final thread = u > 0.58 && rand(seg, flick, 9) < (u - 0.58) * 3.0;
    final climb =
        ((((h / 30.0 - ph * 3.0) % 1.0) + 1.0) % 1.0) < 0.1 ? 1 : 0;
    final trail = gh - h > 0.0 && gh - h < 18.0 ? 1.0 - (gh - h) / 18.0 : 0.0;
    final xLim = thread ? 0 : (w * 1.6).ceil();
    for (var x = -xLim; x <= xLim; x++) {
      final q = x.abs() / w;
      final cw = 0.2 + 0.18 * (1.0 - smooth(0.0, 0.5, u));
      var lvl = q < cw ? 0 : (q < 0.47 ? 1 : (q < 0.72 ? 2 : (q < 1.0 ? 3 : 4)));
      for (var s = 0; s < 3; s++) {
        final sx = (s - 1) * w * 0.55 +
            math.sin(h * 0.09 + ph * tau * (s + 1) + s * 2.0) * 0.9;
        if ((x - sx).abs() < 0.5) lvl = math.max(0, lvl - 1);
      }
      if (rand(y, shimmer, 3) < 0.05 && lvl > 0) lvl--;
      if (q < 0.72) lvl = math.max(0, lvl - climb - (trail > 0.3 ? 1 : 0));
      final a = lvl <= 2 ? 1.0 : ((1.55 - q) / 0.75) * fade * 1.2;
      if (a <= 0.0) continue;
      final col = thread
          ? (u > 0.85 ? c[6] : kWhite)
          : (lvl == 0 ? (u > 0.8 ? c[6] : kWhite) : c[7 - lvl]);
      p.dot(x, y, col, a);
    }
    final near = smooth(8.0, 20.0, h);
    if ((y & 3) == 0) {
      p.glow(
        0.5,
        y.toDouble(),
        w * 2.6 + 6.0,
        c[5],
        0.36 * near * (0.3 + 0.7 * fade) * (1.0 + 0.4 * beat),
      );
    }
    if ((y & 15) == 0) {
      p.glow(0.5, y.toDouble(), 34.0, c[4], 0.2 * near * (0.25 + 0.75 * fade));
    }
  }
  if (gh > 0.0) {
    glint(p, 0.0, -gh, 3.5 * (1.0 - gq * 0.5), c[6], 0.6);
    p.glow(0.5, -gh, 14.0, c[5], 0.45);
  }
  flare(
    p,
    0.5,
    -5.0,
    8.0 + 3.0 * beat + math.sin(ph * tau * 4.0) * 0.8,
    0.6 + 0.4 * beat,
    c,
  );
  p.glow(0.5, -16.0, 16.0, c[4], 0.12 + 0.25 * beat);
}

void _motes(Painter p, List<int> c, double t, int seed) {
  cycle(t, _duration, 30, seed, (g) => g.range(1.0, 2.2), (age, life, r, _) {
    final inner = r.chance(0.3);
    final side = r.sign();
    final x0 = inner ? r.range(-3.0, 3.0) : side * r.range(4.0, 15.0);
    final vy = r.range(22.0, 52.0) * (inner ? 1.5 : 1.0);
    final x = x0 +
        math.sin(age * r.range(1.5, 3.5) + r.range(0.0, tau)) * 1.6;
    final y = -r.range(1.0, 10.0) - vy * age;
    final k = math.min(1.0, math.min(age / 0.25, (life - age) / 0.5));
    if (k <= 0.0 || y < -_h) return;
    if (r.chance(0.22)) {
      final tw = 0.5 + 0.5 * math.sin(age * r.range(9.0, 14.0) + r.range(0.0, tau));
      if (tw * k > 0.3) {
        glint(p, x, y, tw > 0.75 ? 2.0 : 1.0, c[6], 0.4 * k);
      }
      return;
    }
    p.dot(x, y, inner ? kWhite : c[6], k * 1.5);
    p.dot(x, y + 1.0, inner ? c[6] : c[4], k);
    p.dot(x, y + 2.0, c[3], k * 0.6);
    p.glow(x + 0.5, y + 0.5, 3.5, c[5], 0.35 * k);
  });
}

final PureEffect lootBeamEffect = PureEffect(
  meta: const EffectMeta(
    id: 'pickups/loot-beam',
    name: 'Loot beam',
    desc:
        'A dropped sword in a tall pillar of rarity light: a white core thinning to the sky, rings pulsing across the floor, motes streaming up, a glint racing up the shaft.',
    category: 'pickups',
    tags: ['pickup', 'loot', 'beam', 'rarity', 'drop', 'item', 'loop'],
    size: (96, 176),
    origin: (48, 162),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#140a24',
        '#2c1250',
        '#4b1d86',
        '#7330c0',
        '#a050f0',
        '#c890ff',
        '#ecd4ff',
        '#ffffff',
      ],
      'seed': 4,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _duration;
    pool(p, 0.5, 0.0, 34.0, 5.0, c[4], 0.14);
    p.shade(-30.0, -0.5, 31.0, 6.0, (x, y, out) {
      final dx = (x - 0.5) / 30.0;
      final dy = y / 6.0;
      final d = dx * dx + dy * dy;
      if (d >= 1.0) return null;
      out.l = c[5];
      final f = 1.0 - math.sqrt(d);
      out.k = 0.4 * f * f;
      return null;
    });
    for (var x = -16; x <= 16; x++) {
      final q = x.abs() / 16.5;
      final a = 1.35 - q * 1.25;
      p.dot(x, 0, q < 0.3 ? kWhite : (q < 0.6 ? c[6] : c[5]), a);
      if (q < 0.75) {
        p.dot(x, 1, q < 0.3 ? c[6] : (q < 0.55 ? c[5] : c[4]), a * 0.8);
      }
      if (q < 0.4) p.dot(x, 2, c[4], a * 0.5);
    }
    for (var k = 0; k < _rings.length; k++) {
      _ring(p, c, _since(ph, k) * _duration, true);
    }
    _column(p, c, t);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _duration;
    blobShadow(p, _ox - 0.5, 12.5, 0.95);
    _sword(p, c, ph);
    for (var k = 0; k < _rings.length; k++) {
      _ring(p, c, _since(ph, k) * _duration, false);
    }
    _motes(p, c, t, o.seed);
  },
);
