// The soft lit smoke puffs and the shaded, outlined skull are
// adapted from Sprite Fusion's open-source poison (https://www.spritefusion.com/pixel-art-vfx/poison),
// MIT License, Copyright (c) 2026 Hugo Duprez.
import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'status_lib.dart';

const double _d = 2.4;

const Pose _hunch = Pose(
  turn: 1,
  crouch: 4,
  lean: 3,
  hy: 1,
  fx: -7,
  fy: -33,
  bx: 8,
  by: -33,
  ffx: -3,
  fbx: 4,
);

final IconMask _skull = bitmap([
  '...#####...',
  '.#########.',
  '###########',
  '##eee#eee##',
  '##eEe#eEe##',
  '##eee#eee##',
  '#####.#####',
  '.####.####.',
  '..#######..',
  '..#.#.#.#..',
  '...#####...',
]);

const double _in = 0.5;
const double _hold = 0.75;
const double _out = 1.85;
const double _gone = 2.1;

double _tide(double t) => 0.3 + 0.12 * math.sin((t / _d) * tau);
double _reach(int x, double t, int seed) =>
    _tide(t) + 0.13 * tileFbm(x * 0.35, (t / _d) * 4.0, 0, 4, seed, 2);

void _trails(
  Painter p,
  List<int> c,
  ActorDefinition a,
  ActorShape s,
  double t,
  int seed,
  bool front,
) {
  const spots = [(0.12, -1), (0.1, 1), (0.5, -1), (0.48, 1)];
  for (var j = 0; j < spots.length; j++) {
    if ((j % 2 == 0) != front) continue;
    final (q, side) = spots[j];
    final my = (s.h * q + 0.5).floor();
    final (l, r) = (my >= 0 && my < s.rows.length) ? s.rows[my] : (0, 0);
    final x0 = a.x + (side < 0 ? l : r + 1);
    final y0 = a.y + my;
    const life = 1.6;
    const n = 18;
    for (var i = n - 1; i >= 0; i--) {
      final age = (((t - (i / n) * _d - j * 0.37) % _d) + _d) % _d;
      final tb = t - age;
      final u = age / life;
      if (u >= 1.0) continue;
      final sway =
          math.sin((tb / _d) * tau * 2.0 + j * 1.7) * 4.0 * math.min(1.0, u * 1.6);
      final x = x0 +
          side * u * 7.0 +
          sway +
          (rand(i, j, 71) - 0.5) * 2.5 * u;
      final y = y0 - age * 19.0 - 5.0 * u * u;
      final rad = (1.3 + 3.6 * (1.0 - math.pow(1.0 - u, 3))) *
          (0.7 + 0.6 * rand(i, j, 72));
      final k = smooth(0.0, 0.12, u) *
          (1.0 - smooth(0.45, 1.0, u)) *
          (front ? 0.5 : 0.62);
      final col = mix(
        rand(i, j, 70) < 0.5 ? c[4] : mix(c[4], c[3], 0.4),
        c[1],
        u * 0.85,
      );
      p.disc(x, y, rad * 1.08, col, k * 0.4);
      p.disc(x + rad * 0.05, y + rad * 0.08, rad * 0.76, col, k * 0.55);
      p.disc(
        x - rad * 0.22,
        y - rad * 0.3,
        rad * 0.48,
        mix(col, c[6], 0.25),
        k * 0.38 * (1.0 - u * 0.6),
      );
      if (i % 3 == 0) p.glow(x, y, rad * 1.6, c[4], 0.08 * k);
    }
  }
}

final PureEffect cursedEffect = PureEffect(
  meta: const EffectMeta(
    id: 'status/cursed',
    name: 'Cursed',
    desc:
        'Hexed: violet smoke rises off the body in winding trails, a dark stain creeps up from the feet with a glowing edge, the eyes burn, a skull glitches in overhead.',
    category: 'status',
    tags: ['status', 'curse', 'hex', 'dark', 'debuff', 'shadow', 'loop'],
    size: (64, 84),
    origin: (32, 76),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#0c0612', '#1f0f2e', '#3a1a55', '#5e2a85',
        '#8a3fc0', '#b86ef0', '#e0b0ff', '#ffffff',
      ],
      'seed': 9,
    },
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      const PoseKey(0.0, _hunch),
      PoseKey(0.6, _hunch.copyWith(crouch: 5)),
      PoseKey(1.2, _hunch.copyWith(lean: 2)),
      PoseKey(1.8, _hunch.copyWith(crouch: 5)),
      const PoseKey(2.4, _hunch),
    ],
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final a = o.actor;
    final s = actorShape(a);
    final (fl, fr) = s.rows[s.h - 1];
    final cx = a.x + (fl + fr + 1) / 2.0;
    final rx = (fr - fl) / 2.0 + 7.0 + 2.0 * math.sin((t / _d) * tau);
    final x0 = (cx - rx - 1.0).floor();
    final x1 = cx + rx + 1.0;
    for (var x = x0; x <= x1; x++) {
      final q = (x + 0.5 - cx).abs() / rx;
      final n = rand(x, 31);
      if (q > 1.0 + n * 0.12) continue;
      p.px(x, 0, q > 0.8 ? c[4] : (n < 0.2 ? c[3] : c[2]));
      if (q < 0.85) p.px(x, 1, c[1]);
      if (q < 0.55 && n < 0.7) p.px(x, 2, c[1]);
    }
    p.shade((cx - rx - 6.0).floor(), -4, (cx + rx + 6.0).ceil(), 5, (x, y, out) {
      final d = hypot((x - cx) / (rx + 6.0), y / 4.0);
      if (d < 1.0) {
        out.l = c[4];
        out.k = 0.2 * (1.0 - d) * (1.0 - d);
      }
      return null;
    });
    _trails(p, c, a, s, t, o.seed, false);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final a = o.actor;
    final s = actorShape(a);
    final h = s.h;

    for (final (mx, my) in s.body) {
      final col = colorAt(a, mx, my);
      final up = 1.0 - (my + 0.5) / h;
      final lv = _reach(mx, t, o.seed);
      if (up > lv + 0.035) continue;
      final x = a.x + mx;
      final y = a.y + my;
      if (up > lv - 0.02) {
        p.px(x, y, c[6]);
      } else if (up > lv - 0.06) {
        p.px(x, y, c[4]);
      } else {
        p.px(x, y, mix(c[1], c[3], clamp(luma(col) * 1.6)));
      }
    }
    for (var mx = 0; mx < s.w; mx++) {
      final lv = _reach(mx, t, o.seed);
      final my = ((1.0 - lv) * h).floor();
      if (s.on(mx, my)) p.glow(a.x + mx, a.y + my, 4, c[5], 0.14);
    }

    for (final e in actorEyes(a)) {
      for (final (x, y) in e.px) {
        p.px(a.x + x, a.y + y, y == e.y0 ? c[7] : c[5]);
      }
      p.glow(
        a.x + (e.x0 + e.x1 + 1) / 2.0,
        a.y + (e.y0 + e.y1 + 1) / 2.0,
        5,
        c[5],
        0.4,
      );
    }

    _trails(p, c, a, s, t, o.seed, true);

    if (t >= _in && t < _gone) {
      final glitch = t < _hold
          ? 1.0 - (t - _in) / (_hold - _in)
          : (t > _out ? (t - _out) / (_gone - _out) : 0.0);
      final f = (t * 30.0).floor();
      final on = glitch < 0.15 || rand(f, 3) > glitch * 0.6;
      const x = 0;
      final y = a.y - 12.0 + math.sin((t / _d) * tau * 2.0) * 1.2;
      if (on) {
        String tear(int dx, int dy) {
          final row = dy + 6;
          final shift = glitch > 0.0 && rand(f, row >> 1, 7) < glitch * 0.8
              ? ((rand(f, row, 9) - 0.5) * 6.0 * glitch + 0.5).floor()
              : 0;
          return _skull(dx - shift, dy);
        }

        if (glitch > 0.0) {
          icon(p, x - 2, y, 7, tear, [0, c[2], c[2], c[3]], 0.7 * glitch);
          icon(p, x + 2, y, 7, tear, [0, c[6], c[6], c[6]], 0.5 * glitch);
        }
        icon(
          p,
          x,
          y,
          8,
          tear,
          [c[0], c[4], c[6], c[7]],
          1.0,
          {'e': c[0], 'E': c[7]},
        );
        p.glow(x - 3, y - 1, 5, c[5], 0.6);
        p.glow(x + 3, y - 1, 5, c[5], 0.6);
        p.glow(x, y, 16, c[4], 0.24 + 0.3 * glitch);
      }
      if (glitch > 0.1) {
        for (var k = 0; k < 3; k++) {
          final ly = y - 5.0 + (rand(f, k, 11) * 11.0).floor();
          final lx = ((rand(f, k, 12) - 0.5) * 10.0 + 0.5).floor();
          final len = 3 + (rand(f, k, 13) * 8.0).floor();
          p.line(
            lx - len / 2.0,
            ly,
            lx + len / 2.0,
            ly,
            k.isOdd ? c[6] : c[4],
            glitch,
          );
        }
      }
    }

    p.glow(0, a.y + h * (1.0 - _tide(t)), 24, c[4], 0.2);
    p.glow(0, a.y + h * 0.45, 30, c[3], 0.12);
  },
);
