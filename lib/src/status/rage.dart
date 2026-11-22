// The shaded, outlined anger mark and the embers are
// adapted from Sprite Fusion's open-source heal and fire (https://www.spritefusion.com/pixel-art-vfx/heal),
// MIT License, Copyright (c) 2026 Hugo Duprez.
import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'status_lib.dart';

const double _d = 1.2;
const double _lub = 0.05;
const double _dub = 0.29;
const double _g = 760.0;

const Pose _seethe = Pose(
  turn: 1,
  crouch: 4,
  fx: -13,
  fy: -19,
  bx: 13,
  by: -19,
  ffx: -8,
  fbx: 9,
);
const Pose _thud = Pose(
  turn: 1,
  crouch: 6,
  fx: -13,
  fy: -23,
  bx: 13,
  by: -23,
  ffx: -8,
  fbx: 9,
);

double _pulse(double t, double at, [double w = 0.06]) {
  final d = (((((t - at) % _d) + _d + _d / 2.0) % _d) - _d / 2.0) / w;
  return math.exp(-(d * d));
}

double _beat(double t) => _pulse(t, _lub) + 0.65 * _pulse(t, _dub);
double _since(double t, double at) => (((t - at) % _d) + _d) % _d;
bool _shaking(double t) =>
    _since(t, _lub - 0.02) < 0.13 || _since(t, _dub - 0.02) < 0.09;

final List<IconMask> _mark = [
  bitmap([
    '..#.#..',
    '..#.#..',
    '##...##',
    '.......',
    '##...##',
    '..#.#..',
    '..#.#..',
  ]),
  bitmap([
    '...#.#...',
    '...#.#...',
    '..##.##..',
    '###...###',
    '.........',
    '###...###',
    '..##.##..',
    '...#.#...',
    '...#.#...',
  ]),
];

final Expando<Map<int, List<List<(double x, double y)>>>> _cracksCache =
    Expando<Map<int, List<List<(double x, double y)>>>>();

List<List<(double x, double y)>> _cracks(ActorDefinition a, int seed) {
  var m = _cracksCache[a.mask];
  if (m == null) {
    m = {};
    _cracksCache[a.mask] = m;
  }
  final existing = m[seed];
  if (existing != null) return existing;

  final s = actorShape(a);
  final (fl, fr) = s.rows[s.h - 1];
  final r = Rng(seed * 31 + 7);
  final out = <List<(double, double)>>[];

  final roots = [
    (a.x + fl + 2.0, -1),
    (a.x + fr - 1.0, 1),
    (a.x + (fl + fr) / 2.0, -1),
    (a.x + (fl + fr) / 2.0 + 1.0, 1),
  ];
  for (final (x0, dir) in roots) {
    var x = x0;
    var y = 0.5;
    final pts = <(double, double)>[(x, y)];
    final n = r.intRange(5, 9);
    for (var i = 0; i < n; i++) {
      x += dir * r.range(1.2, 2.4);
      y = clamp(y + r.range(-0.9, 0.9), 0.0, 2.5);
      pts.add((x, y));
      if (i > 1 && r.chance(0.3)) {
        out.add([
          (x, y),
          (
            x + dir * r.range(1.0, 2.0),
            clamp(y + r.sign() * r.range(0.6, 1.4), 0.0, 3.0),
          ),
        ]);
      }
    }
    out.add(pts);
  }
  m[seed] = out;
  return out;
}

final PureEffect rageEffect = PureEffect(
  meta: const EffectMeta(
    id: 'status/rage',
    name: 'Rage',
    desc:
        'Seething: the body judders on every heartbeat, an anger mark throbs at the temple, eyes burn, steam jets off the head, stress lines flash out and the floor cracks hot underfoot.',
    category: 'status',
    tags: ['status', 'rage', 'berserk', 'anger', 'buff', 'loop'],
    size: (80, 80),
    origin: (40, 70),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#1a0208', '#4a0612', '#8a0c1c', '#c81828',
        '#ff3040', '#ff7a7a', '#ffc8c8', '#ffffff',
      ],
      'heat': ['#5a0a0a', '#c8281a', '#ff7a2a', '#ffd27a'],
      'steam': '#f2e8ee',
      'seed': 6,
    },
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      const PoseKey(0.0, _seethe),
      const PoseKey(0.05, _thud, PoseEase.snap),
      const PoseKey(0.17, _seethe, PoseEase.snap),
      PoseKey(0.29, _thud.copyWith(crouch: 5), PoseEase.snap),
      const PoseKey(0.4, _seethe, PoseEase.snap),
      const PoseKey(1.2, _seethe),
    ],
  ),
  onActorAlpha: (t, _) => _shaking(t) ? 0.0 : 1.0,
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final hh = fit(o.rampOpt('heat'), 4);
    final a = o.actor;
    final b = _beat(t);
    final stamp = math.exp(-_since(t, _lub) / 0.18);

    cycle(t, _d, 9, o.seed + 2, (r) => r.range(0.7, 1.1), (age, life, r, _) {
      final u = age / life;
      final x0 = r.range(-16.0, 16.0);
      final y = a.y + r.range(10.0, 40.0) - age * r.range(14.0, 22.0);
      final len = r.range(6.0, 11.0);
      final ph = r.range(0.0, tau);
      final k = math.sin(math.pi * u) * 0.55;
      for (var d = 0; d < len; d++) {
        final wy = (math.sin(d * 0.9 + ph + age * 12.0) * 0.8 + 0.5).floor();
        p.dot(
          x0 - len / 2.0 + d,
          y + wy,
          d % 3 != 0 ? c[2] : c[1],
          k * (1.0 - (d / len - 0.5).abs() * 1.4),
        );
      }
    });

    p.shade(-30, -4, 30, 8, (x, y, out) {
      final d = hypot(x / 28.0, (y - 0.5) / 4.5);
      if (d < 1.0) {
        out.l = c[3];
        out.k = (0.2 + 0.3 * b) * (1.0 - d) * (1.0 - d);
      }
      return null;
    });

    final heat = 0.25 + 0.75 * stamp;
    for (final pts in _cracks(a, o.seed)) {
      for (var i = 1; i < pts.length; i++) {
        final (x0, y0) = pts[i - 1];
        final (x1, y1) = pts[i];
        final far = i / pts.length;
        final col = heat * (1.0 - far * 0.6) > 0.6
            ? hh[3]
            : (heat * (1.0 - far * 0.5) > 0.35 ? hh[2] : hh[1]);
        p.line(x0, y0, x1, y1, col);
        if (i.isOdd) p.glow(x1, y1, 4, hh[2], 0.25 * heat * (1.0 - far * 0.5));
      }
    }
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final hh = fit(o.rampOpt('heat'), 4);
    final a = o.actor;
    final s = actorShape(a);
    final b = _beat(t);
    final steam = hex(o.strOpt('steam', '#f2e8ee'));
    final shake = _shaking(t);
    final dx = shake ? ((t * 60.0).floor().isOdd ? 1 : -1) : 0;
    final dy = shake && _since(t, _lub - 0.02) < 0.06 ? -1 : 0;

    for (final (mx, my) in s.body) {
      final col = colorAt(a, mx, my);
      final l = luma(col);
      final skin = l > 0.55 && (col & 255) > ((col >>> 16) & 255) + 30;
      if (skin) {
        p.px(a.x + mx + dx, a.y + my + dy, mix(col, c[4], 0.22 + 0.3 * b));
      } else if (shake) {
        p.px(a.x + mx + dx, a.y + my + dy, col);
      }
    }

    for (final e in actorEyes(a)) {
      final ex = a.x + dx;
      final ey = a.y + dy;
      final inner = (e.x0 + e.x1) / 2.0 < a.w / 2.0 ? 1 : -1;
      for (final (x, y) in e.px) {
        p.px(ex + x, ey + y, y == e.y0 ? c[7] : (y == e.y0 + 1 ? c[6] : c[4]));
      }
      final xi = inner > 0 ? e.x1 : e.x0;
      final xo = inner > 0 ? e.x0 : e.x1;
      p.px(ex + xo - inner, ey + e.y0 - 2, 0xff1f1726);
      p.px(ex + xo, ey + e.y0 - 2, 0xff1f1726);
      p.px(ex + xi, ey + e.y0 - 1, 0xff1f1726);
      p.glow(ex + (e.x0 + e.x1 + 1) / 2.0, ey + e.y0 + 1, 5, c[5], 0.35 + 0.35 * b);
    }

    final big = _pulse(t, _lub + 0.02, 0.05) > 0.35 ||
        _pulse(t, _dub + 0.02, 0.04) > 0.6;
    final mx = a.x + a.w * 0.86 + dx;
    final my = a.y + 3.0 + dy;
    icon(p, mx, my, 5, _mark[big ? 1 : 0], [c[0], c[3], c[4], c[5]]);
    p.px(mx - (big ? 3 : 2), my - (big ? 3 : 2), c[6]);
    p.glow(mx, my, 8, c[4], 0.25 + 0.4 * b);

    for (final (at, n, power) in const [
      (_lub + 0.04, 7, 1.0),
      (_dub + 0.04, 4, 0.75),
    ]) {
      for (final side in const [-1, 1]) {
        for (var i = 0; i < n; i++) {
          final age = _since(t, at + i * 0.016);
          final life = 0.22 + 0.12 * rand(i, side, 3);
          if (age >= life) continue;
          final u = age / life;
          final ang =
              -math.pi / 2.0 + side * (0.5 + 0.2 * rand(i, side, 5));
          final sp = (90.0 + 40.0 * rand(i, side, 7)) * power;
          final d = travel(sp, 0.0, 7.0, age);
          final x = side * a.w * 0.36 + math.cos(ang) * d;
          final y = a.y + 3.0 + math.sin(ang) * d - 8.0 * age;
          final rad =
              (1.0 + 3.2 * math.sqrt(u)) * (0.8 + 0.4 * rand(i, side, 9));
          final k = math.min(1.0, u * 12.0) * (1.0 - u) * (1.0 - u);
          p.disc(x, y, rad, steam, 0.7 * k);
          p.disc(x - rad * 0.2, y - rad * 0.25, rad * 0.6, kWhite, 0.6 * k);
          if (u < 0.3) p.dot(x, y, kWhite, 1.0 - u / 0.3);
        }
      }
    }

    for (final (at, n, len) in const [(_lub, 8, 7.0), (_dub, 6, 5.0)]) {
      final age = _since(t, at);
      if (age > 0.2) continue;
      final k = age / 0.2;
      for (var i = 0; i < n; i++) {
        final ang = -math.pi / 2.0 + ((i + 0.5) / n - 0.5) * 4.4;
        final r0 = 15.0 + 6.0 * k;
        final ca = math.cos(ang);
        final sa = math.sin(ang);
        const cx = 0.0;
        final cy = a.y + 12.0;
        final pts = <(double, double)>[];
        for (var j = 0; j <= 3; j++) {
          final r = r0 + (j / 3.0) * len;
          final off = j.isOdd ? 1.3 : -0.4;
          pts.add((cx + ca * r - sa * off, cy + sa * r + ca * off));
        }
        for (var j = 1; j < pts.length; j++) {
          p.lineShaded(
            pts[j - 1].$1,
            pts[j - 1].$2,
            pts[j].$1,
            pts[j].$2,
            color: (double su) {
              final u = (j - 1 + su) / 3.0;
              return u > 0.66 ? c[7] : (u > 0.33 ? c[5] : c[4]);
            },
            alpha: (_) => 1.2 - k,
          );
        }
        p.glowLine(
          pts[0].$1,
          pts[0].$2,
          pts[3].$1,
          pts[3].$2,
          3,
          c[4],
          0.3 * (1.0 - k),
        );
      }
    }

    final st = _since(t, _lub);
    for (var i = 0; i < 10; i++) {
      final life = 0.5 + 0.5 * rand(i, 11);
      final age = st - 0.02 * rand(i, 12);
      if (age < 0.0 || age > life) continue;
      final x = (rand(i, 13) - 0.5) * 30.0 +
          math.sin(age * 9.0 + i) * 1.5 * age;
      final y =
          -1.0 + travel(-(40.0 + 50.0 * rand(i, 14)), -20.0, 1.6, age);
      ember(p, x, y, age / life, [hh[3], hh[2], hh[1]], age + i);
    }
    for (var i = 0; i < 12; i++) {
      final vx = (rand(i, 21) - 0.5) * 90.0;
      final vy = -(40.0 + 70.0 * rand(i, 22));
      final tt = st;
      final x = (rand(i, 23) - 0.5) * 18.0 + vx * tt;
      final y = -1.0 + vy * tt + 0.5 * _g * tt * tt;
      if (tt > 0.6 || y > 0.0) continue;
      p.px(x, y, i % 3 != 0 ? c[2] : 0xff6a5e72);
    }

    p.glow(0, a.y + 10, 26, c[4], 0.12 + 0.4 * b);
    p.glow(0, a.y + 22, 34, c[3], 0.08 + 0.18 * b);
  },
);
