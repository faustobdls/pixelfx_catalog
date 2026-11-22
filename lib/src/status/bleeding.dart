// The beads, drops, drying splats and crowns are
// adapted from Sprite Fusion's open-source blood (https://www.spritefusion.com/pixel-art-vfx/blood),
// MIT License, Copyright (c) 2026 Hugo Duprez.
import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'status_lib.dart';

const double _d = 2.4;
const double _beatDur = _d / 2.0;
const double _g = 900.0;

const Pose _clutch = Pose(
  turn: 0.7,
  crouch: 3,
  lean: 2,
  fx: 2,
  fy: -21,
  bx: 8,
  by: -14,
  ffx: 3,
  fbx: -3,
);
const Pose _beatPose = Pose(
  turn: 0.7,
  crouch: 5,
  lean: 4,
  hy: 1,
  fx: 2,
  fy: -21,
  bx: 8,
  by: -14,
  ffx: 3,
  fbx: -3,
);

class _Wound {
  final int mx;
  final int my;
  final int run;
  final int drops;
  final double phase;
  final int side;

  const _Wound({
    required this.mx,
    required this.my,
    required this.run,
    required this.drops,
    required this.phase,
    required this.side,
  });
}

final Expando<List<_Wound>> _woundsCache = Expando<List<_Wound>>();

List<_Wound> _wounds(ActorDefinition a) {
  final cached = _woundsCache[a.mask];
  if (cached != null) return cached;

  final s = actorShape(a);
  final h = s.h;
  final w = s.w;

  _Wound make(int mx, int my, int drops, double phase) {
    var run = 1;
    while (run < 3 && s.on(mx, my + run + 1)) {
      run++;
    }
    return _Wound(
      mx: mx,
      my: my,
      run: run,
      drops: drops,
      phase: phase,
      side: mx < w / 2.0 ? -1 : 1,
    );
  }

  (int, int) edge(double q, int side) {
    final my = (h * q + 0.5).floor();
    final (l, r) = s.rows[my];
    return (side < 0 ? l + 1 : r - 1, my);
  }

  (int, int)? front;
  for (final (x, y) in s.body) {
    if (y > h * 0.5 &&
        y < h * 0.62 &&
        x > w * 0.55 &&
        x < w * 0.75 &&
        s.on(x, y + 3)) {
      front = (x, y);
      break;
    }
  }
  final f = front ?? edge(0.55, 1);
  final e1 = edge(0.57, -1);
  final e2 = edge(0.6, 1);
  final list = [
    make(e1.$1, e1.$2, 3, 0.0),
    make(f.$1, f.$2, 2, 0.35),
    make(e2.$1, e2.$2, 2, 0.7),
  ];
  _woundsCache[a.mask] = list;
  return list;
}

void _drop(Painter p, List<int> c, double x, double y, double v, int s) {
  final tail = math.min(5.0, v * 0.012);
  if (tail >= 1.0) p.line(x, y - tail, x, y - 1.0, s >= 2 ? c[3] : c[2]);
  if (s >= 2) {
    p.px(x, y, c[5]);
    p.px(x + 1.0, y, c[4]);
    p.px(x, y + 1.0, c[3]);
    p.px(x + 1.0, y + 1.0, c[2]);
  } else {
    p.px(x, y, c[4]);
  }
}

void _splat(
  Painter p,
  List<int> c,
  double x,
  double ground,
  double age,
  bool big,
  int seed,
) {
  const life = _d * 0.85;
  if (age < 0.0 || age > life) return;
  final spread = smooth(0.0, 0.1, age);
  final hw = (big ? 2.2 : 1.4) * (0.5 + 0.5 * spread);
  final fade = 1.0 - smooth(life - 0.5, life, age);
  final dry = age < 0.35 ? 4 : (age < 1.0 ? 3 : 2);
  final x0 = (x - hw).floor();
  final x1 = (x + hw).ceil();
  for (var xx = x0; xx <= x1; xx++) {
    p.dot(
      xx,
      ground - 1.0,
      (xx + 0.5 - x).abs() > hw * 0.75 ? c[dry - 1] : c[dry],
      fade,
    );
  }
  if (age < 0.3) p.px(x - 0.5, ground - 1.0, c[5]);
  if (age < 0.4) {
    final count = big ? 3 : 2;
    for (var j = 0; j < count; j++) {
      final vx = (j.isOdd ? 1 : -1) * (18.0 + 24.0 * rand(seed, j, 1));
      final vy = -(40.0 + 40.0 * rand(seed, j, 2));
      final tt = age;
      final dx = vx * tt;
      final dy = vy * tt + 0.5 * _g * tt * tt;
      if (dy <= 0.0) p.px(x + dx, ground - 1.0 + dy, j != 0 ? c[3] : c[4]);
    }
  }
}

final PureEffect bleedingEffect = PureEffect(
  meta: const EffectMeta(
    id: 'status/bleeding',
    name: 'Bleeding',
    desc:
        'Bleeding out: beads swell at three wounds, run, let go and fall to spatter into a glossy pool that ripples; each heartbeat spurts a little and flashes the body red.',
    category: 'status',
    tags: ['status', 'bleed', 'blood', 'dot', 'debuff', 'wound', 'loop'],
    size: (60, 56),
    origin: (30, 46),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#350711', '#5e0c1b', '#931327', '#c71e33', '#f2384a', '#ff8a7a',
      ],
      'seed': 5,
    },
  ),
  act: const ActSpec(
    onBody: true,
    poses: [
      PoseKey(0.0, _beatPose),
      PoseKey(0.18, _clutch),
      PoseKey(1.2, _clutch),
      PoseKey(1.2, _beatPose, PoseEase.snap),
      PoseKey(1.38, _clutch),
      PoseKey(2.4, _clutch),
      PoseKey(2.4, _beatPose, PoseEase.snap),
    ],
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 6);
    final a = o.actor;
    final ws = _wounds(a);
    final wx0 = a.x + ws[0].mx + 0.5;
    final wx2 = a.x + ws[2].mx + 0.5;
    final px = (wx0 + wx2) / 2.0 - 1.0;
    const rx = 6.5;
    final beat = math.exp(-((((t % _beatDur) + _beatDur) % _beatDur) / 0.25));
    final x0 = (px - rx - 1.0).floor();
    final x1 = px + rx + 1.0;
    for (var x = x0; x <= x1; x++) {
      final q = (x + 0.5 - px).abs() / rx;
      if (q > 1.1) continue;
      p.px(x, -1, q > 0.85 ? c[2] : c[1]);
      if (q < 0.8) p.px(x, 0, q < 0.5 ? c[1] : c[0]);
      if (q < 0.45) p.px(x, 1, c[0]);
    }
    p.px(px - 2.0, -1, c[4]);
    p.px(px - 1.0, -1, c[3]);
    p.px(px + 3.0, -1, c[3]);
    p.glow(px, -1, 8, c[3], 0.06 + 0.04 * beat);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 6);
    final a = o.actor;
    final ws = _wounds(a);
    final s = actorShape(a);
    final ph = ((t % _beatDur) + _beatDur) % _beatDur;
    final hurt = math.max(0.0, 1.0 - ph / 0.12);
    if (hurt > 0.0) {
      for (final (mx, my) in s.body) {
        p.blend(a.x + mx, a.y + my, c[4], 0.26 * hurt);
      }
    }
    for (final w in ws) {
      final wx = a.x + w.mx + 0.5;
      final wy0 = a.y + w.my;
      final wyb = a.y + w.my + w.run + 1;
      p.px(wx, wy0 - 1, c[1]);
      p.px(wx - w.side, wy0 - 1, c[0]);
      p.px(wx - w.side, wy0, c[2]);
      for (var y = wy0; y < wyb; y++) {
        p.px(wx, y, y == wy0 ? c[4] : (y >= wyb - 1 ? c[3] : c[2]));
      }
      final period = _d / w.drops;
      for (var k = 0; k < w.drops; k++) {
        final born = w.phase * period + k * period;
        final age = (((t - born) % _d) + _d) % _d;
        final swell = period * 0.62;
        final big = (k + w.mx).isEven;
        final fallH = math.max(1, -1 - wyb);
        final fall = math.sqrt((2.0 * fallH) / _g);
        const ground = 0.0;
        if (age < swell) {
          final u = age / swell;
          final len = u < 0.35 ? 1 : (u < 0.75 ? 2 : 3);
          for (var j = 0; j < len; j++) {
            p.px(wx, wyb + j, j == len - 1 ? c[2] : c[3]);
          }
          if (len == 3) p.px(wx - 1.0, wyb + 2, c[1]);
          p.px(wx, wyb + len - 2, u > 0.5 ? c[5] : c[4]);
        } else if (age < swell + fall) {
          final f = age - swell;
          final y = wyb + 2.0 + 0.5 * _g * f * f;
          _drop(p, c, wx, y, _g * f, big ? 2 : 1);
        } else {
          _splat(p, c, wx, ground, age - swell - fall, big, w.mx * 31 + k);
        }
      }
    }
    final w0 = ws[0];
    final w0x = a.x + w0.mx + 0.5;
    final w0y0 = a.y + w0.my;
    if (ph < 0.5) {
      for (var j = 0; j < 7; j++) {
        final vx = w0.side * (18.0 + 42.0 * rand(j, 7));
        final vy = -(15.0 + 50.0 * rand(j, 8));
        final tt = ph - j * 0.012;
        if (tt <= 0.0) continue;
        final x = w0x + travel(vx, 0.0, 1.2, tt);
        final y = w0y0 + travel(vy, _g * 0.8, 0.6, tt);
        final x2 = w0x + travel(vx, 0.0, 1.2, tt - 0.02);
        final y2 = w0y0 + travel(vy, _g * 0.8, 0.6, tt - 0.02);
        if (y >= -1.0) continue;
        p.line(x2, y2, x, y, j % 3 != 0 ? c[3] : c[2]);
        p.px(x, y, j.isOdd ? c[5] : c[4]);
      }
    }
    p.glow(w0x, w0y0, 6, c[4], 0.25 * hurt);
  },
);
