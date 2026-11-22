// The shaded, outlined letters are
// adapted from Sprite Fusion's open-source heal (https://www.spritefusion.com/pixel-art-vfx/heal),
// MIT License, Copyright (c) 2026 Hugo Duprez.
import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'status_lib.dart';

const double _d = 2.4;
const int _nz = 3;

const Pose _nod = Pose(
  turn: 0.9,
  crouch: 1,
  lean: 1,
  hy: 2,
  fx: -6,
  fy: -14,
  bx: 7,
  by: -14,
  ffx: -2,
  fbx: 3,
);

final List<IconMask> _zs = [
  ['#####', '...#.', '..#..', '.#...', '#####'],
  ['#######', '.....#.', '....#..', '...#...', '..#....', '.#.....', '#######'],
  [
    '.#######.', '#########', '......##.', '.....##..', '....##...',
    '...##....', '..##.....', '#########', '.#######.',
  ],
  [
    '.#########.', '###########', '.......###.', '......###..',
    '.....###...', '....###....', '...###.....', '..###......',
    '.###.......', '###########', '.#########.',
  ],
].map((rows) => bitmap(rows)).toList();

({double x, double y, int size, double k}) _zAt(
  ActorDefinition a,
  int i,
  double u,
) {
  final side = i.isOdd ? 1.0 : 0.6;
  final x0 = a.x + a.w * 0.78;
  final y0 = a.y + 7.0;
  final x = x0 + 13.0 * side * u + 2.5 * math.sin(tau * 1.1 * u + i * 2.1);
  final y = y0 - 32.0 * (1.0 - math.pow(1.0 - u, 1.35));
  final size = u < 0.18 ? 0 : (u < 0.42 ? 1 : (u < 0.68 ? 2 : 3));
  final k = math.min(1.0, u / 0.06);
  return (x: x, y: y, size: size, k: k);
}

void _shut(Painter p, ActorDefinition a) {
  for (final e in actorEyes(a)) {
    for (final (x, y) in e.px) {
      p.px(a.x + x, a.y + y, e.skin);
    }
    final y = a.y + e.y1 - 1;
    for (var x = e.x0; x <= e.x1; x++) {
      p.px(a.x + x, y, 0xff1f1726);
    }
    p.px(a.x + e.x0 - 1, y - 1, 0xff1f1726);
    p.px(a.x + e.x1 + 1, y - 1, 0xff1f1726);
  }
}

final PureEffect sleepEffect = PureEffect(
  meta: const EffectMeta(
    id: 'status/sleep',
    name: 'Sleep',
    desc:
        'Fast asleep: eyes shut, soft outlined Zs float up off the head one after another, swaying and growing as they rise, dream motes drift, a slow breathing glow.',
    category: 'status',
    tags: ['status', 'sleep', 'zzz', 'rest', 'debuff', 'loop'],
    size: (60, 82),
    origin: (26, 74),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#1a1636', '#3c3a7a', '#6f78c8', '#a9b8f0', '#dfe6ff', '#ffffff',
      ],
      'seed': 3,
    },
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      const PoseKey(0.0, _nod),
      PoseKey(1.2, _nod.copyWith(crouch: 2, lean: 2, hy: 3)),
      const PoseKey(2.4, _nod),
    ],
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 6);
    final a = o.actor;
    final breath = 0.5 + 0.5 * math.sin((t / _d) * tau * 2.0);
    _shut(p, a);

    p.glow(0, a.y + 10, 24, c[3], 0.1 + 0.1 * breath);
    cycle(t, _d, 5, o.seed + 6, (_) => _d, (age, life, r, _) {
      final u = age / life;
      final x = a.x +
          a.w * r.range(0.3, 1.1) +
          math.sin(u * tau + r.next() * tau) * 3.0;
      final y = a.y + r.range(-6.0, 8.0) - u * 10.0;
      final rad = r.range(3.0, 5.0) * (0.8 + 0.4 * u);
      final k = math.sin(math.pi * u);
      p.glow(x, y, rad * 2.4, c[3], 0.1 * k);
    });

    cycle(t, _d, 14, o.seed + 4, (r) => r.range(1.2, 2.0), (age, life, r, _) {
      final u = age / life;
      final x = a.x +
          a.w * r.range(0.4, 1.1) +
          math.sin(age * 2.0 + r.next() * tau) * 2.0;
      final y = a.y + r.range(0.0, 10.0) - age * r.range(10.0, 18.0);
      final tw = math.sin(math.pi * u) *
          (0.6 + 0.4 * math.sin(age * 9.0 + r.next() * tau));
      if (tw < 0.15) return;
      sparkle(
        p,
        x,
        y,
        tw > 0.7 && r.next() < 0.4 ? 1 : 0,
        c[4],
        c[3],
        0.3 * tw,
      );
      p.dot(x, y, tw > 0.6 ? c[5] : c[4], tw * 1.3);
    });

    final zs = [
      for (var i = 0; i < _nz; i++)
        (i: i, u: (((t - (i * _d) / _nz) % _d) + _d) % _d / _d),
    ]..sort((p1, p2) => p2.u.compareTo(p1.u));

    for (final item in zs) {
      final i = item.i;
      final u = item.u;
      final z = _zAt(a, i, u);
      if (u > 0.9) {
        final k = (u - 0.9) / 0.1;
        for (var j = 0; j < 7; j++) {
          final an = (j / 7.0) * tau + i;
          final d = 3.0 + 6.0 * math.sqrt(k);
          p.dot(
            z.x + math.cos(an) * d,
            z.y + math.sin(an) * d * 0.8,
            j.isOdd ? c[4] : c[5],
            1.2 - k,
          );
        }
        p.glow(z.x, z.y, 10, c[3], 0.25 * (1.0 - k));
        continue;
      }
      for (var j = 1; j <= 6; j++) {
        final q = _zAt(a, i, math.max(0.0, u - j * 0.025));
        if (j.isEven || u - j * 0.025 < 0.05) continue;
        p.dot(q.x - 1.0, q.y + 4.0 + q.size, c[3], (1.0 - j / 7.0) * 0.9);
      }
      final old = u > 0.78;
      final rCols = old ? [c[0], c[1], c[2], c[3]] : [c[1], c[2], c[3], c[4]];
      icon(p, z.x, z.y, 7, _zs[z.size], rCols, z.k);
      if (!old) p.px(z.x - 2.0 - z.size, z.y - 2.0 - z.size * 0.8, c[5]);
      p.glow(z.x, z.y, 7 + z.size * 3, c[3], (old ? 0.12 : 0.26) * z.k);
    }
  },
);
