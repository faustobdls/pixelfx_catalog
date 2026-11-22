// The shaded, outlined question marks are
// adapted from Sprite Fusion's open-source heal (https://www.spritefusion.com/pixel-art-vfx/heal),
// MIT License, Copyright (c) 2026 Hugo Duprez.
import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'status_lib.dart';

const double _d = 2.4;

const Pose _shrug = Pose(
  turn: 1,
  fx: -13,
  fy: -26,
  bx: 14,
  by: -26,
  ffx: -3,
  fbx: 4,
);

final List<IconMask> _qs = [
  ['.###.', '#...#', '....#', '...#.', '..#..', '.....', '..#..'],
  [
    '.####.', '##..##', '....##', '...##.', '..##..', '..##..',
    '......', '..##..', '..##..',
  ],
  [
    '.#####.', '##...##', '##...##', '.....##', '....##.', '...##..',
    '...##..', '.......', '...##..', '...##..',
  ],
].map((rows) => bitmap(rows)).toList();

const List<({double x, double y, double t0, int big})> _marks = [
  (x: -12, y: -5, t0: 0.0, big: 2),
  (x: 12, y: -8, t0: 0.8, big: 1),
  (x: 1, y: -17, t0: 1.6, big: 2),
];

void _spiral(Painter p, List<int> c, double cx, double cy, double t) {
  final rot = (t / _d) * tau * 2.0;
  const turns = 1.8;
  const n = 72;
  final breathe = 1.0 + 0.08 * math.sin((t / _d) * tau * 4.0);

  (double, double) at(double u) {
    final th = u * turns * tau - rot;
    final r = (0.8 + 6.6 * u) * breathe;
    return (cx + math.cos(th) * r, cy + math.sin(th) * r * 0.9);
  }

  for (var i = 1; i <= n; i++) {
    final u = i / n;
    final (x0, y0) = at((i - 1) / n);
    final (x1, y1) = at(u);
    if (u > 0.45) p.line(x0 + 0.5, y0 + 0.7, x1 + 0.5, y1 + 0.7, c[1]);
  }
  for (var i = 1; i <= n; i++) {
    final u = i / n;
    final (x0, y0) = at((i - 1) / n);
    final (x1, y1) = at(u);
    p.line(
      x0,
      y0,
      x1,
      y1,
      u > 0.88 ? c[5] : (u > 0.62 ? c[4] : (u > 0.3 ? c[3] : c[2])),
    );
    if (i % 6 == 0) p.light(x1, y1, c[3], 0.4 * u);
  }
  final (hx, hy) = at(1.0);
  sparkle(p, hx, hy, 2, c[4], c[3], 0.5);
  p.glow(cx, cy, 13, c[3], 0.28);
}

final PureEffect confusedEffect = PureEffect(
  meta: const EffectMeta(
    id: 'status/confused',
    name: 'Confused',
    desc:
        'Head in a spin: a glowing spiral whirls over the head, question marks pop up round it and bob, the eyes dart left and right.',
    category: 'status',
    tags: ['status', 'confused', 'confusion', 'dizzy', 'debuff', 'loop'],
    size: (60, 78),
    origin: (30, 70),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#1e0f2e', '#4b2070', '#8a3ab0', '#c66ae0', '#f0a8ff', '#ffffff',
      ],
      'marks': ['#2a1608', '#b0701a', '#ffd84a', '#fff4b8'],
      'seed': 6,
    },
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      PoseKey(0.0, _shrug.copyWith(x: 0, lean: -2)),
      PoseKey(
        0.6,
        _shrug.copyWith(
          x: 1,
          lean: 1,
          crouch: 1,
          fy: -23,
          by: -29,
          fbx: 5,
          fby: -6,
        ),
      ),
      PoseKey(1.2, _shrug.copyWith(x: 2, lean: 2)),
      PoseKey(
        1.8,
        _shrug.copyWith(
          x: 1,
          lean: -1,
          crouch: 1,
          fy: -29,
          by: -23,
          ffx: -4,
          ffy: -6,
        ),
      ),
      PoseKey(2.4, _shrug.copyWith(x: 0, lean: -2)),
    ],
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 6);
    final a = o.actor;
    p.glow(0, a.y - 7, 16, c[3], 0.22);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 6);
    final mCols = fit(o.rampOpt('marks'), 4);
    final a = o.actor;
    final look = ((t / _d) * 6.0).floor().isOdd ? 1 : -1;
    for (final e in actorEyes(a)) {
      for (final (x, y) in e.px) {
        p.px(a.x + x, a.y + y, 0xff17121f);
      }
      p.px(a.x + (look < 0 ? e.x0 : e.x1), a.y + e.y0, kWhite);
    }
    _spiral(p, c, 0.0, a.y - 7.0, t);

    for (final m in _marks) {
      final age = (((t - m.t0) % _d) + _d) % _d;
      const life = 1.9;
      if (age > life) continue;
      final u = age / life;
      final pop = Ease.outBack(clamp(age / 0.16), 3.0);
      final out = clamp((u - 0.82) / 0.18);
      final size = math.max(
        0,
        (m.big * pop * (1.0 - out) + (pop > 1.1 ? 1 : 0) + 0.5).floor(),
      );
      final bob = math.sin(age * 5.0 + m.t0 * 3.0) * 1.6;
      final tilt = math.sin(age * 3.3 + m.t0) * 0.8;
      if (pop < 0.3 || (out > 0.0 && size == 0 && out > 0.6)) continue;
      final x = m.x + tilt;
      final y = a.y + m.y + bob - age * 2.0;
      if (age < 0.2) {
        final k = age / 0.2;
        for (var j = 0; j < 8; j++) {
          final an = (j / 8.0) * tau + 0.2;
          final d0 = 4.0 + 7.0 * k;
          final d1 = d0 + 3.0 * (1.0 - k);
          p.line(
            x + math.cos(an) * d0,
            y + math.sin(an) * d0,
            x + math.cos(an) * d1,
            y + math.sin(an) * d1,
            j.isOdd ? mCols[2] : mCols[3],
            1.0 - k,
          );
        }
        p.glow(x, y, 16, mCols[2], 0.45 * (1.0 - k));
      }
      icon(
        p,
        x,
        y,
        7,
        _qs[math.min(2, size)],
        [mCols[0], mCols[1], mCols[2], mCols[3]],
      );
      p.glow(x, y, 10 + size * 2, mCols[2], 0.28 * (1.0 - out));
    }

    cycle(t, _d, 10, o.seed + 2, (r) => r.range(0.35, 0.6), (age, life, r, _) {
      final th = r.range(0.0, tau);
      final u = age / life;
      final d = 6.0 + age * r.range(12.0, 22.0);
      final x = math.cos(th) * d;
      final y = a.y - 7.0 + math.sin(th) * d * 0.8;
      if (math.sin(math.pi * u) > 0.6 && r.next() < 0.5) {
        sparkle(p, x, y, 1, c[4], c[3], 0.3);
      } else {
        p.dot(x, y, u < 0.5 ? c[5] : c[4], 1.2 - u);
      }
    });
  },
);
