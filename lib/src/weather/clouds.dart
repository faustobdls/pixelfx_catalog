// Banded volumes with a lit crest (light on the top edge, tones stepping down into the body, Bayer at the steps)
// after Sprite Fusion's open-source fog (https://www.spritefusion.com/pixel-art-vfx/fog), MIT License,
// Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'weather_lib.dart';

const double _d = 12.0;
const double _mx = 92.0;
const double _my = -128.0;
const double _mr = 12.0;

class _CloudLayer {
  final int n;
  final (double, double) w;
  final (double, double) h;
  final (double, double) y;
  final double v;
  final (double, double) life;
  final List<int> tone;
  final double alpha;

  const _CloudLayer({
    required this.n,
    required this.w,
    required this.h,
    required this.y,
    required this.v,
    required this.life,
    required this.tone,
    required this.alpha,
  });
}

const List<_CloudLayer> _layers = [
  _CloudLayer(
    n: 7,
    w: (40.0, 70.0),
    h: (6.0, 11.0),
    y: (-150.0, -110.0),
    v: 3.0,
    life: (8.0, 11.0),
    tone: [2, 3, 4, 5],
    alpha: 0.7,
  ),
  _CloudLayer(
    n: 6,
    w: (60.0, 100.0),
    h: (9.0, 15.0),
    y: (-120.0, -70.0),
    v: 6.0,
    life: (8.0, 11.0),
    tone: [1, 2, 4, 6],
    alpha: 0.88,
  ),
  _CloudLayer(
    n: 5,
    w: (90.0, 140.0),
    h: (12.0, 20.0),
    y: (-80.0, -30.0),
    v: 10.0,
    life: (9.0, 12.0),
    tone: [1, 2, 3, 6],
    alpha: 1.0,
  ),
];

void _moon(ClippedWeatherPainter q, List<int> c) {
  q.shade(_mx - _mr - 1.0, _my - _mr - 1.0, _mx + _mr + 1.0, _my + _mr + 1.0,
      (x, y, out) {
    final dx = x - _mx;
    final dy = y - _my;
    final d = math.sqrt(dx * dx + dy * dy) / _mr;
    if (d > 1.0) return null;
    final sea = (dx + 4.0) * (dx + 4.0) + (dy + 2.0) * (dy + 2.0) < 14.0 ||
        (dx - 3.0) * (dx - 3.0) + (dy - 4.0) * (dy - 4.0) < 9.0 ||
        (dx - 5.0) * (dx - 5.0) + (dy + 5.0) * (dy + 5.0) < 4.0;
    out.c = d > 0.86
        ? (dx + dy < 0.0 ? c[6] : kWhite)
        : (sea ? c[5] : (d < 0.5 && dx + dy < 0.0 ? kWhite : c[7]));
    return null;
  });
}

void _cloud(
  ClippedWeatherPainter q,
  double t,
  int s,
  List<int> c,
  _CloudLayer ly,
  int j,
  int i,
) {
  double r(int k) => rand(s, j, i, k);
  final life = ly.life.$1 + r(1) * (ly.life.$2 - ly.life.$1);
  final age = wrap(t - r(2) * _d, _d);
  if (age >= life) return;
  final u = age / life;
  final grow = math.min(1.0, u * 4.0) * math.min(1.0, (1.0 - u) * 4.0);
  final w = (ly.w.$1 + r(3) * (ly.w.$2 - ly.w.$1)) * (0.6 + 0.4 * grow);
  final x0 = -200.0 + r(4) * 330.0 + ly.v * age;
  final base = ly.y.$1 + r(5) * (ly.y.$2 - ly.y.$1);
  final hTotal = (ly.h.$1 + r(6) * (ly.h.$2 - ly.h.$1)) * grow;
  if (hTotal < 1.5) return;

  final n = 4 + (r(7) * 4.0).floor();
  final puffs = <(double, double, double)>[];
  for (var k = 0; k < n; k++) {
    final f = (k + 0.5) / n;
    final rad = hTotal *
        (0.5 + 0.35 * math.sin(math.pi * f)) *
        (0.75 + 0.5 * r(10 + k)) *
        (1.0 + 0.06 * math.sin((tau * t) / _d + k + i));
    puffs.add((
      x0 + w * (f - 0.5) + (r(20 + k) - 0.5) * 6.0,
      base - rad * 0.3 - r(30 + k) * hTotal * 0.15,
      rad,
    ));
  }
  final upperCount = 1 + (r(8) * 3.0).floor();
  for (var k = 0; k < upperCount; k++) {
    final f = 0.3 + r(40 + k) * 0.4;
    final rad = hTotal *
        (0.75 + 0.35 * r(50 + k)) *
        (1.0 + 0.05 * math.sin((tau * t) / _d + k * 2.0 + i));
    puffs.add((x0 + w * (f - 0.5), base - hTotal * 0.55 - rad * 0.2, rad));
  }

  final x1 = x0 - w / 2.0 - hTotal;
  final x2 = x0 + w / 2.0 + hTotal;
  final b = boxOf(_cloudsMeta);
  final minX = math.max(b.x0, x1.floor());
  final maxX = math.min(b.x1 - 1, x2.ceil());
  for (var x = minX; x <= maxX; x++) {
    final cx = x + 0.5;
    var top = double.infinity;
    var top2 = double.infinity;
    for (final (px, py, rad) in puffs) {
      final dx = cx - px;
      if (dx * dx >= rad * rad) continue;
      final y = py - math.sqrt(rad * rad - dx * dx);
      if (y < top) {
        top2 = top;
        top = y;
      } else if (y < top2) {
        top2 = y;
      }
    }
    if (top == double.infinity) continue;
    final end = math.min(cx - x1, x2 - cx) / hTotal;
    final bot = base +
        1.5 +
        math.sin(cx * 0.21 + i) * 0.8 -
        (end < 1.0 ? (1.0 - end) * 4.0 : 0.0);
    if (bot <= top) continue;
    final h = bot - top;
    final inner =
        top2 - top > 2.5 && top2 < bot - 2.0 ? top2.floor() : -999;
    for (var y = top.floor(); y < bot; y++) {
      final d = y + 0.5 - top;
      final v = d / h;
      final th = bayer(x.toDouble(), y.toDouble()) * 0.12;
      final md = math.sqrt((cx - _mx) * (cx - _mx) + (y - _my) * (y - _my));
      var colIdx = d < 1.0
          ? ly.tone[3]
          : (v < 0.25 + th
              ? ly.tone[2]
              : (v < 0.62 + th ? ly.tone[1] : ly.tone[0]));
      if (y == inner) colIdx = math.max(colIdx, ly.tone[2]);
      if (bot - y - 0.5 < 1.0 && v > 0.5) {
        colIdx = math.max(0, ly.tone[0] - 1);
      }
      if (md < 46.0 && (d < 2.0 || y == inner || v < 0.3)) {
        colIdx = math.min(7, colIdx + (md < 24.0 ? 2 : 1));
      }
      final a = ly.alpha * math.min(1.0, grow * 1.5);
      if (a >= 1.0) {
        q.px(x, y, c[colIdx]);
      } else {
        q.blend(x, y, c[colIdx], a);
      }
      if (d < 1.0 && md < 46.0) {
        q.light(x, y, c[6], 0.35 * (1.0 - md / 46.0));
      }
    }
  }
}

const EffectMeta _cloudsMeta = EffectMeta(
  id: 'weather/clouds',
  name: 'Clouds',
  desc:
      'Layers of clouds drift past a bright moon at night: silver-lit tops, dark bellies, edges that flare where they cross the moon, forming and thinning as they go.',
  category: 'weather',
  tags: ['weather', 'clouds', 'moon', 'night', 'sky', 'ambient', 'loop'],
  size: (320, 180),
  origin: (160, 180),
  duration: _d,
  loop: true,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': [
      '#0c0c18',
      '#16172a',
      '#232540',
      '#363a5a',
      '#545a80',
      '#8088ae',
      '#bcc4e2',
      '#f2f4ff',
    ],
    'seed': 7,
  },
);

final PureEffect cloudsEffect = PureEffect(
  meta: _cloudsMeta,
  onDraw: (p, t, o) {
    final q = clip(p, _cloudsMeta);
    final s = o.seed;
    final c = fit(o.palette, 8);
    _moon(q, c);
    for (var j = 0; j < _layers.length; j++) {
      final ly = _layers[j];
      for (var i = 0; i < ly.n; i++) {
        _cloud(q, t, s, c, ly, j, i);
      }
    }
    q.glow(_mx, _my, 110, c[4], 0.14);
    q.glow(_mx, _my, 40, c[5], 0.25);
    q.glow(_mx, _my, 18, c[6], 0.3);
  },
);
