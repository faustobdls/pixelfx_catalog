// The shaded, outlined icons and the twinkles are
// adapted from Sprite Fusion's open-source heal (https://www.spritefusion.com/pixel-art-vfx/heal),
// MIT License, Copyright (c) 2026 Hugo Duprez.
import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'status_lib.dart';

const double _d = 2.0;
const int _turns = 2;
const int _n = 5;

const Pose _daze = Pose(
  turn: 1,
  fx: -7,
  fy: -15,
  bx: 8,
  by: -15,
  ffx: -3,
  fbx: 4,
);

const List<String> _star7 = [
  '...#...',
  '..###..',
  '#######',
  '.#####.',
  '..###..',
  '.##.##.',
  '.#...#.',
];
final IconMask _star7Mask = bitmap(_star7);

final List<IconMask> _bird = [true, false].map((up) {
  const wing = <(int, int)>[
    (-1, -1), (-1, -2), (-2, -2), (-2, -3), (-3, -3), (-3, -4),
  ];
  const downWing = <(int, int)>[
    (-1, 1), (-1, 2), (-2, 2), (-2, 3), (0, 1),
  ];
  final wList = up ? wing : downWing;
  return (int dx, int dy) {
    final x = dx + 0.5;
    final y = dy + 0.5;
    if (dx == 3 && dy == -2) return 'e';
    if ((dx == 5 || dx == 4) && dy == -1) return dx == 5 ? 'b' : '#';
    for (final (wx, wy) in wList) {
      if (wx == dx && wy == dy) return 'w';
    }
    final bx = x / 3.3;
    final by = (y - 0.6) / 1.9;
    final hx = x - 2.8;
    final hy = y + 1.2;
    if (bx * bx + by * by <= 1.0 || hx * hx + hy * hy <= 1.7 * 1.7) return '#';
    if ((dx == -4 && (dy == -1 || dy == 0)) || (dx == -5 && dy == -1)) {
      return '#';
    }
    return '';
  };
}).toList();

final bool Function(double u, double v) _starShape = starShape(0.44);
IconMask _starMask(double s, double ang) => shaped(_starShape, s, ang);

typedef _RingItem = ({
  int i,
  double th,
  double x,
  double y,
  bool near,
  double depth,
  bool bird,
  double rx,
  double ry,
  double cy,
});

List<_RingItem> _ring(double t, ActorDefinition a) {
  final cy = a.y + 2.0;
  final rx = a.w * 0.62;
  const ry = 4.5;
  return [
    for (var i = 0; i < _n; i++)
      () {
        final th = tau * ((_turns * t) / _d + i / _n);
        final s = math.sin(th);
        return (
          i: i,
          th: th,
          x: math.cos(th) * rx,
          y: cy + s * ry,
          near: s >= 0.0,
          depth: 0.5 + 0.5 * s,
          bird: i.isOdd,
          rx: rx,
          ry: ry,
          cy: cy,
        );
      }(),
  ];
}

void _draw1(Painter p, double t, Map<String, Object?> o, bool far) {
  final c = fit(o.palette, 7);
  final bd = fit(o.rampOpt('birds'), 4);
  final beak = hex(o.strOpt('beak', '#ffae35'));
  final a = o.actor;
  int dim(int col) => far ? mix(col, bd[0], 0.3) : col;

  for (final it in _ring(t, a)) {
    if (it.near == far) continue;
    if (!it.bird) {
      for (var k = 1; k <= 12; k++) {
        final th = it.th - k * 0.085;
        final x = math.cos(th) * it.rx;
        final y = it.cy - 1.0 + math.sin(th) * it.ry;
        if ((math.sin(th) >= 0.0) == far ||
            rand(it.i, k, (((t / _d) * _turns + k * 0.37) * 9.0).floor()) <
                0.25) {
          continue;
        }
        p.dot(
          x,
          y,
          dim(k < 4 ? c[6] : (k < 8 ? c[5] : c[4])),
          1.1 - k / 13.0,
        );
        if (k < 6) p.light(x, y, c[4], 0.3 * (1.0 - k / 6.0));
      }
    }
    if (it.bird) {
      final up = (t * 8.0 + it.i * 0.5).floor().isEven;
      final bob = math.sin((t / _d) * tau * 4.0 + it.i) * 0.7;
      final flip = it.near;
      final f = _bird[up ? 0 : 1];
      String ins(int dx, int dy) => flip ? f(-dx, dy) : f(dx, dy);
      icon(
        p,
        it.x,
        it.y - 3.0 + bob,
        7,
        ins,
        [bd[0], dim(bd[1]), dim(bd[2]), dim(bd[3])],
        1.0,
        {'e': bd[0], 'b': dim(beak), 'w': dim(bd[1])},
      );
    } else {
      final spin = (t / _d) * tau * 3.0 + it.i;
      final rCols = [c[0], dim(c[3]), dim(c[4]), dim(c[5])];
      if (it.depth > 0.55) {
        icon(p, it.x, it.y - 1.0, 7, _starMask(4.0 + 0.8 * it.depth, spin), rCols);
      } else {
        icon(p, it.x, it.y - 1.0, 5, _star7Mask, rCols);
      }
      p.px(it.x, it.y - 1.0, far ? c[5] : c[6]);
      p.glow(it.x, it.y - 1.0, 11, c[4], 0.24 + 0.3 * it.depth);
      p.glow(it.x, it.y - 1.0, 4, c[6], 0.3 * it.depth);
      final angDiff = math.atan2(
        math.sin(it.th - math.pi / 2.0),
        math.cos(it.th - math.pi / 2.0),
      );
      final fr = math.exp(-((angDiff / 0.32) * (angDiff / 0.32)));
      if (!far && fr > 0.08) {
        flare(p, it.x, it.y - 1.0, 9.0 * fr, fr, [c[3], c[4], c[5], c[6]]);
      }
    }
  }
}

final PureEffect stunnedEffect = PureEffect(
  meta: const EffectMeta(
    id: 'status/stunned',
    name: 'Stunned',
    desc:
        'Seeing stars: three spinning stars and two little birds circle the head on a tilted ring, ducking behind it and sweeping round in front, trailing glitter.',
    category: 'status',
    tags: [
      'status', 'stun', 'dizzy', 'daze', 'stars', 'birds', 'debuff', 'loop',
    ],
    size: (60, 64),
    origin: (30, 56),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#3a1e0c', '#8a4a12', '#d88a1c', '#f5c030',
        '#ffe36e', '#fff6c8', '#ffffff',
      ],
      'birds': ['#1a1422', '#6a7fae', '#b8c8e8', '#f4f8ff'],
      'beak': '#ffae35',
      'seed': 2,
    },
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      PoseKey(0.0, _daze.copyWith(x: -1, lean: -3, hx: -1)),
      PoseKey(0.5, _daze.copyWith(x: 0, lean: 0, crouch: 2, hy: 1, ffx: -2)),
      PoseKey(1.0, _daze.copyWith(x: 1, lean: 3, hx: 1)),
      PoseKey(1.5, _daze.copyWith(x: 0, lean: 0, crouch: 2, hy: 1, fbx: 3)),
      PoseKey(2.0, _daze.copyWith(x: -1, lean: -3, hx: -1)),
    ],
  ),
  onDrawBack: (p, t, o) => _draw1(p, t, o, true),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 7);
    final a = o.actor;
    _draw1(p, t, o, false);
    cycle(t, _d, 14, o.seed + 3, (r) => r.range(0.25, 0.5), (age, life, r, _) {
      final th = r.range(0.0, tau);
      final u = age / life;
      final x = math.cos(th) * a.w * r.range(0.45, 0.95);
      final y = a.y + 1.0 + math.sin(th) * 7.0 - r.range(0.0, 9.0);
      final sw = math.sin(math.pi * u);
      final arm = (r.range(1.0, 2.6) * sw + 0.5).floorToDouble();
      if (arm < 1.0) p.dot(x, y, c[6], sw * 1.4);
      sparkle(p, x, y, arm, c[5], c[4], 0.35 * sw);
    });
    p.glow(0, a.y + 1, 26, c[4], 0.13);
  },
);
