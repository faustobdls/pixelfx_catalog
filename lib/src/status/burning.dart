// The flame tongues, embers and thin smoke are
// adapted from Sprite Fusion's open-source fire (https://www.spritefusion.com/pixel-art-vfx/fire),
// MIT License, Copyright (c) 2026 Hugo Duprez.
import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'status_lib.dart';

const double _d = 1.2;
const double _tick = 0.6;
const double _wind = -14.0;

const Pose _aPose = Pose(
  turn: 1,
  crouch: 2,
  lean: 2,
  fx: -13,
  fy: -38,
  bx: 12,
  by: -17,
  ffx: -3,
  ffy: -7,
  fbx: 5,
);
const Pose _bPose = Pose(
  turn: 0.9,
  crouch: 3,
  lean: -2,
  fx: -12,
  fy: -17,
  bx: 13,
  by: -38,
  ffx: -4,
  fbx: 4,
  fby: -7,
);

double _since(double t) => ((t % _tick) + _tick) % _tick;
double _flare(double t) => math.exp(-_since(t) / 0.12);

class _Tongue {
  final double dx;
  final double h;
  final int n;
  const _Tongue(this.dx, this.h, this.n);
}

class _Spot {
  final double x;
  final double y;
  final List<_Tongue> tongues;
  const _Spot(this.x, this.y, this.tongues);
}

class _Scorch {
  final double x;
  final double y;
  final double r;
  const _Scorch(this.x, this.y, this.r);
}

class _BurnPlan {
  final List<_Spot> list;
  final List<List<_Scorch>> scorch;
  const _BurnPlan(this.list, this.scorch);
}

final Expando<Map<int, _BurnPlan>> _spotsCache = Expando<Map<int, _BurnPlan>>();

_BurnPlan _spots(ActorDefinition a, int seed) {
  var m = _spotsCache[a.mask];
  if (m == null) {
    m = {};
    _spotsCache[a.mask] = m;
  }
  final existing = m[seed];
  if (existing != null) return existing;

  final s = actorShape(a);
  final h = s.h;
  final w = s.w;
  final r = Rng(seed * 13 + 5);

  (int, int) at(double q, int side) {
    final my = (h * q + 0.5).floor();
    final (l, right) = s.rows[my];
    return (side < 0 ? l : right, my);
  }

  final hairCand = s.up.where((p) => p.$1 < w * 0.42).toList()
    ..sort((p, q) {
      final c = p.$2.compareTo(q.$2);
      return c != 0 ? c : p.$1.compareTo(q.$1);
    });
  final hair = hairCand.first;

  final shoulderCand = s.up
      .where((p) => p.$1 > w / 2.0 && p.$2 > h * 0.4 && p.$2 < h * 0.62)
      .toList()
    ..sort((p, q) => p.$2.compareTo(q.$2));
  final shoulder = shoulderCand.isNotEmpty ? shoulderCand.first : at(0.5, 1);

  final specs = [
    (at: hair, n: 3, h: 4.5),
    (at: shoulder, n: 2, h: 4.0),
    (at: at(0.62, -1), n: 2, h: 3.5),
    (at: at(0.6, 1), n: 2, h: 3.5),
  ];

  final list = <_Spot>[];
  for (var i = 0; i < specs.length; i++) {
    final sp = specs[i];
    final x = a.x + sp.at.$1 + 0.5;
    final y = a.y + sp.at.$2 + 1.5;
    final tongues = [
      for (var j = 0; j < sp.n; j++)
        _Tongue(
          (j - (sp.n - 1) / 2.0) * 1.6 + r.range(-0.4, 0.4),
          sp.h * r.range(0.8, 1.2),
          i * 17 + j * 5 + seed,
        ),
    ];
    list.add(_Spot(x, y, tongues));
  }

  double lum(int x, int y) => luma(colorAt(a, x, y));

  final scorch = <List<_Scorch>>[
    for (var tick = 0; tick < 2; tick++)
      [
        for (var k = 0; k < 2; k++)
          () {
            final sp = list[(tick * 2 + k + 1) % list.length];
            var cand = s.body.where((p) {
              final (x, y) = p;
              final d = hypot(a.x + x + 0.5 - sp.x, a.y + y + 0.5 - sp.y);
              if (d >= 9.0 || y <= h * 0.42) return false;
              final l = lum(x, y);
              return l > 0.3 && l < 0.6;
            }).toList();
            if (cand.isEmpty) {
              cand = s.body.where((p) => p.$2 > h * 0.45).toList();
            }
            final (x, y) = cand[(r.next() * cand.length).floor()];
            return _Scorch(a.x + x + 0.5, a.y + y + 0.5, r.range(3.2, 4.4));
          }(),
      ],
  ];

  final out = _BurnPlan(list, scorch);
  m[seed] = out;
  return out;
}

final PureEffect burningEffect = PureEffect(
  meta: const EffectMeta(
    id: 'status/burning',
    name: 'Burning',
    desc:
        'Burning over time: small flames lick from four hot spots, trailing sparks and thin smoke; every 0.6 s they flare, the body flashes white then orange, scorch marks spread.',
    category: 'status',
    tags: ['status', 'fire', 'burn', 'dot', 'debuff', 'loop'],
    size: (72, 80),
    origin: (36, 70),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#4a1712', '#8a1f17', '#c9281f', '#f2561d',
        '#ff8a2a', '#ffc23d', '#ffe26b', '#fff3a6', '#ffffff',
      ],
      'char': ['#120c0a', '#2a1a14', '#4a2c1c'],
      'smoke': '#5b5566',
      'seed': 3,
    },
  ),
  act: const ActSpec(
    onBody: true,
    poses: [
      PoseKey(0.0, _aPose),
      PoseKey(0.15, _bPose, PoseEase.snap),
      PoseKey(0.3, _aPose, PoseEase.snap),
      PoseKey(0.45, _bPose, PoseEase.snap),
      PoseKey(0.6, _aPose, PoseEase.snap),
      PoseKey(0.75, _bPose, PoseEase.snap),
      PoseKey(0.9, _aPose, PoseEase.snap),
      PoseKey(1.05, _bPose, PoseEase.snap),
      PoseKey(1.2, _aPose, PoseEase.snap),
    ],
  ),
  onActorAlpha: (t, _) => _since(t) < 0.034 ? 0.0 : 1.0,
  onDrawBack: (p, t, o) {
    final f = fit(o.palette, 9).reversed.toList();
    final a = o.actor;
    final fl = _flare(t);
    final flick = 0.8 + 0.2 * tnoise(t, _d, 7.5, 3);
    p.shade(-30, -3, 30, 7, (x, y, out) {
      final d = hypot(x / 26.0, (y - 0.5) / 4.5);
      if (d < 1.0) {
        out.l = mix(f[3], f[4], 0.5);
        out.k = (0.16 + 0.22 * fl) * flick * (1.0 - d) * (1.0 - d);
      }
      return null;
    });
    final smokeC = mix(hex(o.strOpt('smoke', '#5b5566')), f[6], 0.2);
    final list = _spots(a, o.seed).list;
    cycle(t, _d, 16, o.seed + 4, (r) => r.range(0.8, 1.2), (age, life, r, i) {
      final sp = list[i % list.length];
      final x = sp.x +
          travel(_wind * 0.6, _wind * 0.5, 0.8, age) +
          math.sin(age * 4.0 + i) * 1.2;
      final y = sp.y - 3.0 - travel(18.0, 6.0, 1.0, age);
      smoke(p, x, y, r.range(1.1, 1.9), age / life, smokeC, 0.9);
    });
  },
  onDraw: (p, t, o) {
    final f = fit(o.palette, 9).reversed.toList();
    final ch = fit(o.rampOpt('char'), 3);
    final a = o.actor;
    final s = actorShape(a);
    final plan = _spots(a, o.seed);
    final list = plan.list;
    final scorch = plan.scorch;
    final ph = _since(t);
    final tick = (t / _tick).floor() % 2;
    final fl = _flare(t);

    if (ph < 0.034) {
      for (final (mx, my) in s.body) {
        p.px(a.x + mx, a.y + my, kWhite);
      }
    } else if (ph < 0.22) {
      final k = 1.0 - (ph - 0.034) / 0.186;
      for (final (mx, my) in s.body) {
        p.blend(a.x + mx, a.y + my, f[4], 0.55 * k);
      }
    }

    for (final sc in scorch[tick]) {
      final grow = clamp(ph / 0.14);
      final fade = 1.0 - clamp((ph - 0.25) / 0.33);
      final r = sc.r * (0.4 + 0.6 * grow);
      if (fade <= 0.0) continue;
      final ft = (t * 20.0).floor();
      for (final (mx, my) in s.body) {
        final x = a.x + mx + 0.5;
        final y = a.y + my + 0.5;
        final d = hypot(x - sc.x, (y - sc.y) * 1.2) + rand(mx, my, 7) * 0.9;
        if (d > r) continue;
        final edge = d > r - 1.0;
        if (edge) {
          p.dot(
            x - 0.5,
            y - 0.5,
            rand(mx, my, ft) < 0.5 ? f[3] : f[4],
            fade * 1.2,
          );
        } else {
          p.dot(x - 0.5, y - 0.5, d < r * 0.5 ? ch[0] : ch[1], fade * 1.1);
        }
      }
      p.glow(sc.x, sc.y, 6, f[4], 0.3 * fade);
    }

    for (final sp in list) {
      for (final tg in sp.tongues) {
        final h = tg.h * (0.85 + 0.25 * tnoise(t, _d, 5.0, tg.n)) * (1.0 + 1.6 * fl);
        tongue(
          p,
          sp.x + tg.dx,
          sp.y,
          h,
          1.1 + 0.3 * fl,
          _wind * 0.08 * h / 4.0 + tnoise(t, _d, 3.0, tg.n + 9) * 0.8,
          f,
          t,
          _d,
          tg.n,
        );
      }
      p.glow(sp.x, sp.y - 2.0, 9.0 + 6.0 * fl, f[4], 0.22 + 0.35 * fl);
    }

    cycle(t, _d, 20, o.seed + 6, (r) => r.range(0.5, 0.9), (age, life, r, i) {
      final sp = list[i % list.length];
      final x = sp.x +
          r.range(-1.5, 1.5) +
          travel(_wind + r.range(-10.0, 6.0), _wind * 0.6, 1.2, age) +
          math.sin(age * 9.0 + i) * 1.2 * age;
      final y = sp.y - 2.0 + travel(-r.range(25.0, 55.0), -18.0, 1.4, age);
      ember(p, x, y, age / life, [f[1], f[3], f[5]], age + i);
    });

    if (ph < 0.3) {
      for (var k = 0; k < list.length; k++) {
        final sp = list[k];
        for (var j = 0; j < 4; j++) {
          final an = -math.pi / 2.0 + (rand(k, j, tick) - 0.5) * 2.2;
          final v = 50.0 + 50.0 * rand(k, j, 2);
          final d = travel(v, 0.0, 3.0, ph);
          final x = sp.x + math.cos(an) * d;
          final y = sp.y - 2.0 + math.sin(an) * d + 60.0 * ph * ph;
          p.px(x, y, ph < 0.12 ? f[1] : f[3]);
          p.light(x, y, f[3], 0.4 * (1.0 - ph / 0.3));
        }
      }
    }
  },
);
