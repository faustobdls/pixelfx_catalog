// The leaves' tumble (turning as they go, flipping over through edge-on, palettes of autumn and green) is adapted
// from Sprite Fusion's open-source falling leaves (https://www.spritefusion.com/pixel-art-vfx/falling-leaves),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'nature_lib.dart';

const double _dur = 2.4;
const double _sy = 0.3;
const double _top = 64.0;

const Pose _up = Pose(
  turn: 1.1,
  crouch: 0,
  fx: -13,
  fy: -37,
  bx: 13,
  by: -37,
  ffx: -3,
  fbx: 4,
);

double _ringR(double y) => 15 + 9 * clamp(-y / _top);

void _leaves(
  Painter p,
  List<int> l,
  double t,
  int seed,
  bool back,
) {
  cycle(t, _dur, 28, seed, (g) => g.range(1.5, 2.3), (age, life, r, _) {
    final k = age / life;
    final turns = r.range(1.4, 2.2);
    final th = r.range(0, tau) + turns * tau * k;
    final sn = math.sin(th);
    if ((sn > 0) == back) return;
    final y = -lerp(1, _top, math.pow(k, 0.9).toDouble()) - r.range(0, 6);
    final fling = smooth(0.75, 1, k);
    final rr = _ringR(y) * r.range(0.85, 1.15) + fling * 22;
    final x = math.cos(th) * rr;
    final yy = y + sn * rr * _sy;
    final a = math.min(1.0, k * 7) * (1 - smooth(0.85, 1, k));
    final spin = r.range(-9, 9) * age + th;
    final fl = age * r.range(5, 11);
    final o = r.intRange(0, 2) * 4;
    final pal = back
        ? [l[o], l[o], l[o + 1], l[o + 2]]
        : [l[o], l[o + 1], l[o + 2], l[o + 3]];
    drawLeaf(p, x, yy, r.range(6.5, 9), r.range(2.4, 3.3), spin, fl, pal, a);
    if (!back && math.cos(fl).abs() > 0.97) {
      p.px(x, yy, kWhite);
      p.glow(x, yy, 5, l[o + 3], 0.35 * a);
    }
  });
}

void _wind(
  Painter p,
  List<int> c,
  double t,
  int seed,
  bool back,
) {
  for (var j = 0; j < 16; j++) {
    final r = rng(seed, j);
    final y0 = -r.range(4, _top - 4);
    final rad = _ringR(y0) * r.range(1.0, 1.25);
    final kLoop = r.intRange(2, 3);
    final span = r.range(1.1, 2.4);
    final head = r.range(0, tau) + (tau * kLoop * t) / _dur;
    final rise = r.range(-0.18, 0.18);
    for (var s = 0.0; s <= span; s += 0.45 / rad) {
      final th = head - s;
      final sn = math.sin(th);
      if ((sn > 0) == back) continue;
      final k = s / span;
      final x = math.cos(th) * rad;
      final y = y0 + sn * rad * _sy + (th - head) * rise * 4;
      final col = back
          ? (k < 0.3 ? c[3] : c[2])
          : (k < 0.06 && r.next() < 2
              ? kWhite
              : k < 0.15
                  ? c[5]
                  : k < 0.4
                      ? c[4]
                      : c[3]);
      if (k < 0.45) {
        p.dot(x, y, col);
      } else {
        p.blend(x, y, col, 1.6 * (1 - k));
      }
    }
    if (!back && math.sin(head) > 0) {
      p.glow(math.cos(head) * rad, y0 + math.sin(head) * rad * _sy, 5, c[4], 0.25);
    }
  }
}

void _swirl(
  Painter p,
  List<int> c,
  List<int> l,
  double t,
  int seed,
  bool back,
) {
  cycle(t, _dur, 14, seed, (g) => g.range(0.6, 1.1), (age, life, r, _) {
    final k = age / life;
    final th = r.range(0, tau) + r.range(6, 9) * age;
    final sn = math.sin(th);
    if ((sn > 0) == back) return;
    final rr = r.range(10, 22) + k * 8;
    final x = math.cos(th) * rr;
    final y = -1 - k * r.range(2, 8) + sn * rr * 0.25;
    final s = r.range(2, 3.5) * (0.6 + k);
    p.disc(x, y, s, back ? c[2] : c[3], (1 - k) * math.min(1.0, k * 6) * 0.3);
  });
  for (var j = 0; j < 6; j++) {
    final r = rng(seed + 9, j);
    final rr = r.range(12, 24);
    final th0 = r.range(0, tau) + (tau * 3 * t) / _dur;
    final span = r.range(0.5, 1);
    for (var s = 0.0; s < span; s += 0.6 / rr) {
      final th = th0 - s;
      if ((math.sin(th) > 0) == back) continue;
      p.dot(
        math.cos(th) * rr,
        0.5 + rr * 0.2 * math.sin(th),
        s < span * 0.4 ? c[3] : c[2],
        1 - s / span,
      );
    }
  }
}

final PixelEffect leafStorm = PureEffect(
  meta: const EffectMeta(
    id: 'nature/leaf-storm',
    name: 'Leaf storm',
    desc:
        'Leaves tumble up a rising spiral round the character, passing behind and in front, turning and flipping, wrapped in bright bands of wind; litter swirls at their feet.',
    category: 'nature',
    tags: ['nature', 'wind', 'leaves', 'buff', 'aura', 'actor', 'loop'],
    size: (112, 104),
    origin: (56, 92),
    duration: 2.4,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#1a2420',
        '#2e4038',
        '#4a6656',
        '#7a9a84',
        '#b4d0b8',
        '#eef8e8',
      ],
      'leaves': [
        '#123818',
        '#2f7a2a',
        '#6cb83a',
        '#c8f070',
        '#4a2a08',
        '#a8701c',
        '#e8b42e',
        '#fff09a',
        '#3a1010',
        '#9a2e1c',
        '#e0642a',
        '#ffb070',
      ],
      'seed': 5,
    },
  ),
  act: ActSpec(
    poses: [
      const PoseKey(0, _up),
      PoseKey(0.6, _up.merge(const Pose(lean: 2, fy: -40, by: -33))),
      PoseKey(1.2, _up.merge(const Pose(crouch: -1))),
      PoseKey(1.8, _up.merge(const Pose(lean: -2, fy: -33, by: -40))),
      const PoseKey(2.4, _up),
    ],
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 6);
    final l = fit(o.rampOpt('leaves'), 12);
    p.glow(0, -30, 46, c[4], 0.12);
    p.glow(0, -2, 26, l[2], 0.12);
    _swirl(p, c, l, t, o.seed * 3 + 1, true);
    _wind(p, c, t, o.seed * 5 + 2, true);
    _leaves(p, l, t, o.seed * 7 + 3, true);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 6);
    final l = fit(o.rampOpt('leaves'), 12);
    _swirl(p, c, l, t, o.seed * 3 + 1, false);
    _wind(p, c, t, o.seed * 5 + 2, false);
    _leaves(p, l, t, o.seed * 7 + 3, false);
  },
);
