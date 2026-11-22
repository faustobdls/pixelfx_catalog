// The banded after-images, the dotted speed lines with bright heads and the kicked-up dust are
// adapted from Sprite Fusion's open-source movement dash (https://www.spritefusion.com/pixel-art-vfx/movement),
// MIT License, Copyright (c) 2026 Hugo Duprez.
import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'status_lib.dart';

const double _d = 1.2;

const Pose _r1 = Pose(
  turn: 0.25,
  lean: 4,
  crouch: 3,
  ffx: 12,
  ffy: -5,
  fbx: -10,
  fby: -8,
  toeB: true,
  fx: -7,
  fy: -19,
  bx: 12,
  by: -27,
);
const Pose _r2 = Pose(
  turn: 0.25,
  lean: 4,
  crouch: 1,
  ffx: 4,
  ffy: -8,
  fbx: -1,
  fby: -5,
  fx: 3,
  fy: -18,
  bx: 5,
  by: -19,
);
const Pose _r3 = Pose(
  turn: 0.25,
  lean: 4,
  crouch: 3,
  ffx: -10,
  ffy: -8,
  toeF: true,
  fbx: 12,
  fby: -5,
  fx: 14,
  fy: -27,
  bx: -5,
  by: -19,
);
const Pose _r4 = Pose(
  turn: 0.25,
  lean: 4,
  crouch: 1,
  ffx: -1,
  ffy: -5,
  fbx: 4,
  fby: -8,
  fx: 5,
  fy: -19,
  bx: 3,
  by: -18,
);

final Expando<List<(int x, int y, int v)>> _levelsCache =
    Expando<List<(int x, int y, int v)>>();

List<(int x, int y, int v)> _levels(ActorDefinition a) {
  final cached = _levelsCache[a.mask];
  if (cached != null) return cached;
  final s = actorShape(a);
  final l = [
    for (final (x, y) in s.body)
      () {
        final v = luma(colorAt(a, x, y));
        return (x, y, v < 0.24 ? 1 : (v < 0.66 ? 2 : 3));
      }(),
  ];
  _levelsCache[a.mask] = l;
  return l;
}

void _lines(
  Painter p,
  List<int> c,
  ActorDefinition a,
  double t,
  int seed,
  bool front,
) {
  cycle(
    t,
    _d,
    front ? 5 : 11,
    seed + (front ? 9 : 7),
    (r) => r.range(0.12, 0.26),
    (age, life, r, _) {
      final u = age / life;
      final y = a.y + r.range(2.0, a.h - 3.0);
      final len = r.range(10.0, 26.0) * (front ? 0.7 : 1.0);
      final x = r.range(-14.0, 4.0) - age * r.range(160.0, 240.0);
      for (var d = 0; d < len; d++) {
        if (d > len * 0.45 && d.isOdd) continue;
        p.dot(
          x + d,
          y,
          d < 2 ? c[6] : (d < len * 0.4 ? c[5] : c[3]),
          (1.0 - d / len) * (1.0 - u) * (front ? 0.7 : 1.1),
        );
      }
      p.light(x, y, c[4], 0.4 * (1.0 - u));
    },
  );
}

final PureEffect hasteEffect = PureEffect(
  meta: const EffectMeta(
    id: 'status/haste',
    name: 'Haste',
    desc:
        'Sped up: striped after-images stream out behind, speed lines whip past, dust kicks off the heels and the leading edge catches the wind. Faces right.',
    category: 'status',
    tags: ['status', 'haste', 'speed', 'fast', 'buff', 'directional', 'loop'],
    size: (100, 56),
    origin: (64, 48),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#4c25ab', '#773ae4', '#5b6cff', '#5eb0ff',
        '#a3dcff', '#ccf6ff', '#ffffff',
      ],
      'dust': '#8a8090',
      'seed': 4,
    },
  ),
  act: const ActSpec(
    onBody: true,
    follow: 0,
    poses: [
      PoseKey(0.0, _r1),
      PoseKey(0.1, _r2, PoseEase.snap),
      PoseKey(0.2, _r3, PoseEase.snap),
      PoseKey(0.3, _r4, PoseEase.snap),
      PoseKey(0.4, _r1, PoseEase.snap),
      PoseKey(0.5, _r2, PoseEase.snap),
      PoseKey(0.6, _r3, PoseEase.snap),
      PoseKey(0.7, _r4, PoseEase.snap),
      PoseKey(0.8, _r1, PoseEase.snap),
      PoseKey(0.9, _r2, PoseEase.snap),
      PoseKey(1.0, _r3, PoseEase.snap),
      PoseKey(1.1, _r4, PoseEase.snap),
      PoseKey(1.2, _r1, PoseEase.snap),
    ],
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 7);
    final a = o.actor;
    final l = _levels(a);
    final s = actorShape(a);
    final f = (t * 30.0).floor();

    for (var g = 3; g >= 1; g--) {
      final dx = -g * 14 - (rand(f >> 1, g, 3) * 1.6 + 0.5).floor();
      const everyList = [0, 3, 4, 0];
      final every = everyList[g];
      p.outlineShaded(
        a.mask,
        a.x + dx,
        a.y,
        color: (int mx, int my) => (g == 3 && (mx + my).isOdd) ? 0 : c[5 - g],
      );
      if (every != 0) {
        for (final (x, y, v) in l) {
          if ((((y + f) % every) + every) % every != 0) continue;
          p.px(a.x + x + dx, a.y + y, c[clampInt(5 - g + v - 2, 0, 6)]);
        }
      }
      p.glow(
        a.x + a.w / 2.0 + dx,
        a.y + a.h * 0.45,
        16,
        c[3],
        0.12 * (1.0 - g * 0.25),
      );
    }

    for (final (x, y, dir) in s.side) {
      if (dir > 0 || (y + (f >> 1)) % 3 != 0) continue;
      final len = 3 + (rand(y, f >> 1, 5) * 6.0).floor();
      for (var d = 1; d <= len; d++) {
        p.dot(
          a.x + x - d,
          a.y + y,
          d < 3 ? c[5] : c[4],
          1.0 - d / (len + 1),
        );
      }
    }

    _lines(p, c, a, t, o.seed, false);

    final dust = hex(o.strOpt('dust', '#8a8090'));
    cycle(t, _d, 12, o.seed + 5, (r) => r.range(0.45, 0.7), (age, life, r, i) {
      final u = age / life;
      final foot = i.isOdd ? -7.0 : 3.0;
      final x = foot + travel(-r.range(50.0, 100.0), 0.0, 3.5, age);
      final y = -1.5 - travel(r.range(6.0, 18.0), 0.0, 3.5, age);
      final rad = r.range(2.6, 4.6) * (0.6 + 1.0 * u);
      final k = math.pow(1.0 - u, 1.2) * math.min(1.0, u * 10.0);
      p.disc(x, y, rad, dust, k * 0.5);
      p.disc(x + rad * 0.05, y + rad * 0.08, rad * 0.74, dust, k * 0.62);
      p.disc(x - rad * 0.22, y - rad * 0.3, rad * 0.5, c[5], k * 0.25);
    });
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 7);
    final a = o.actor;
    final s = actorShape(a);
    final ft = (t * 15.0).floor();
    for (final (x, y, dir) in s.side) {
      if (dir > 0 && rand(x, y, ft) < 0.85) {
        p.px(a.x + x, a.y + y, rand(y, ft, 2) < 0.3 ? c[6] : c[5]);
      }
    }
    _lines(p, c, a, t, o.seed, true);
    p.glow(-6, a.y + a.h * 0.5, 22, c[3], 0.16);
    p.glow(0, a.y + a.h * 0.45, 30, c[3], 0.16);
    p.glow(
      a.x + a.w,
      a.y + a.h * 0.5,
      10,
      c[5],
      0.12 + 0.06 * math.sin((t / _d) * tau * 3.0),
    );
  },
);
