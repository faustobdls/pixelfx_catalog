// The shaded, outlined hearts are
// adapted from Sprite Fusion's open-source heal (https://www.spritefusion.com/pixel-art-vfx/heal),
// MIT License, Copyright (c) 2026 Hugo Duprez.
import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'status_lib.dart';

const double _d = 2.4;
const double _beatDur = _d / 2.0;

const Pose _swoon = Pose(
  turn: 1.1,
  fx: -2,
  fy: -28,
  bx: 2,
  by: -28,
  armsFront: true,
  ffx: -3,
  fbx: 4,
);

final IconMask _heart5 = bitmap(['.#.#.', '#####', '#####', '.###.', '..#..']);
final IconMask _heart7 = bitmap(['.##.##.', '#######', '#######', '.#####.', '..###..', '...#...']);

double _thump(double ph) {
  final a = (ph - 0.04) / 0.07;
  final b = (ph - 0.26) / 0.07;
  return math.exp(-(a * a)) + 0.6 * math.exp(-(b * b));
}

void _hearts(
  Painter p,
  List<int> c,
  ActorDefinition a,
  double t,
  int seed,
  bool back,
) {
  cycle(t, _d, 12, seed + 4, (r) => r.range(1.3, 1.9), (age, life, r, i) {
    if ((i % 3 == 0) != back) return;
    final u = age / life;
    final side = r.next() < 0.5 ? -1 : 1;
    final ph = r.range(0.0, tau);
    final big = r.next() < 0.3;
    final x = side * r.range(4.0, 15.0) + math.sin(age * 4.0 + ph) * 2.2;
    final y = a.y + r.range(8.0, 30.0) - age * r.range(14.0, 22.0);
    final k = math.min(1.0, u * 6.0);
    if (u > 0.88) {
      final q = (u - 0.88) / 0.12;
      sparkle(
        p,
        x,
        y,
        (2.0 * (1.0 - q) + 0.5).floorToDouble(),
        c[5],
        c[4],
        0.4 * (1.0 - q),
      );
      return;
    }
    final rCols = back ? [c[0], c[1], c[2], c[3]] : [c[0], c[2], c[3], c[4]];
    icon(p, x, y, 4, big ? _heart7 : _heart5, rCols, k);
    if (!back) p.px(x - (big ? 2.0 : 1.0), y - 1.0, c[6]);
    p.glow(x, y, 6, c[3], (back ? 0.12 : 0.22) * k);
  });
}

final PureEffect charmedEffect = PureEffect(
  meta: const EffectMeta(
    id: 'status/charmed',
    name: 'Charmed',
    desc:
        'Smitten: a big heart beats over the head, throwing a ring and a flush of light with every beat, little hearts float up, the eyes go pink and the cheeks blush.',
    category: 'status',
    tags: ['status', 'charm', 'love', 'hearts', 'debuff', 'loop'],
    size: (60, 76),
    origin: (30, 68),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#3a0a1e', '#7a1238', '#c4245a', '#f04e86',
        '#ff8ab0', '#ffc8da', '#ffffff',
      ],
      'seed': 8,
    },
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      PoseKey(0.0, _swoon.copyWith(lean: -2)),
      PoseKey(0.6, _swoon.copyWith(lean: 0, crouch: 1)),
      PoseKey(1.2, _swoon.copyWith(lean: 2)),
      PoseKey(1.8, _swoon.copyWith(lean: 0, crouch: 1)),
      PoseKey(2.4, _swoon.copyWith(lean: -2)),
    ],
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 7);
    final a = o.actor;
    final ph = ((t % _beatDur) + _beatDur) % _beatDur;
    final th = _thump(ph);
    p.glow(0, a.y - 8, 26.0 + 8.0 * th, c[3], 0.16 + 0.22 * th);
    _hearts(p, c, a, t, o.seed, true);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 7);
    final a = o.actor;
    final ph = ((t % _beatDur) + _beatDur) % _beatDur;
    final th = _thump(ph);

    for (final e in actorEyes(a)) {
      for (final (x, y) in e.px) {
        p.px(a.x + x, a.y + y, y == e.y0 ? c[3] : c[2]);
      }
      p.px(a.x + e.x0, a.y + e.y0 + 1, c[6]);
      final blush = mix(e.skin, c[3], 0.55);
      final out = e.x0 < a.w / 2.0 ? -1 : 1;
      final bx = out < 0 ? e.x0 - 1 : e.x1;
      p.px(a.x + bx, a.y + e.y1 + 1, blush);
      p.px(a.x + bx + 1, a.y + e.y1 + 1, blush);
    }

    _hearts(p, c, a, t, o.seed, false);

    const hx = 0;
    final hy = a.y - 10;
    final s = 5.6 * (1.0 + 0.24 * th);

    for (final (t0, kk) in const [(0.04, 1.0), (0.26, 0.6)]) {
      final u = (ph - t0) / 0.5;
      if (u < 0.0 || u > 1.0) continue;
      final s1 = 5.6 * (1.25 + 1.3 * u);
      final outer = shaped(heartShape, s1);
      final inner = shaped(heartShape, s1 - 1.3);
      final ext = (s1 * 1.2).ceil() + 1;
      for (var dy = -ext; dy <= ext; dy++) {
        for (var dx = -ext; dx <= ext; dx++) {
          if (outer(dx, dy).isNotEmpty && inner(dx, dy).isEmpty) {
            p.dot(hx + dx, hy + dy, u < 0.3 ? c[5] : c[4], (1.0 - u) * kk * 1.3);
          }
        }
      }
    }

    icon(p, hx, hy, 9, shaped(heartShape, s), [c[0], c[2], c[3], c[4]]);
    final gx = hx - (s * 0.55 + 0.5).floor();
    final gy = hy - (s * 0.45 + 0.5).floor();
    p.px(gx, gy, c[6]);
    p.px(gx + 1, gy, c[5]);
    p.px(gx, gy + 1, c[5]);
    p.glow(hx, hy, 12.0 + 6.0 * th, c[4], 0.3 + 0.4 * th);
    if (th > 0.5) {
      sparkle(
        p,
        hx + s * 0.9,
        hy - s * 0.8,
        (3.0 * th + 0.5).floorToDouble(),
        c[5],
        c[4],
        0.4 * th,
      );
    }

    cycle(t, _d, 8, o.seed + 2, (r) => r.range(0.3, 0.5), (age, life, r, _) {
      final an = r.range(0.0, tau);
      final d = r.range(8.0, 15.0);
      final u = age / life;
      final sw = math.sin(math.pi * u);
      sparkle(
        p,
        hx + math.cos(an) * d,
        hy + math.sin(an) * d * 0.8,
        (1.6 * sw + 0.5).floorToDouble(),
        c[5],
        c[4],
        0.3 * sw,
      );
    });
  },
);
