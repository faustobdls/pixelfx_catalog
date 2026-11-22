import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'status_lib.dart';

const double _d = 2.0;
const double _shiver = 1.0;

const Pose _stiff = Pose(
    turn: 0.9, crouch: 1, fx: -6, fy: -15, bx: 7, by: -15, ffx: -2, fbx: 3);

double _since(double t) => ((t % _shiver) + _shiver) % _shiver;
int _shake(double t) => _since(t) < 0.22 ? ((t * 50.0).floor().isOdd ? 1 : -1) : 0;

class _Icicle {
  final int x, y;
  final double len, phase, period;
  const _Icicle(this.x, this.y, this.len, this.phase, this.period);
}

class _FrozenPlan {
  final List<(int x, int y, double u, int i)> ferns;
  final List<_Icicle> icicles;
  final List<(int x, int y, int d)> snow;
  final (double mx, double my) mouth;
  const _FrozenPlan(this.ferns, this.icicles, this.snow, this.mouth);
}

final Expando<Map<int, _FrozenPlan>> _plans = Expando<Map<int, _FrozenPlan>>();

_FrozenPlan _plan(ActorDefinition a, int seed) {
  var m = _plans[a.mask];
  if (m == null) {
    m = {};
    _plans[a.mask] = m;
  }
  final existing = m[seed];
  if (existing != null) return existing;

  final s = actorShape(a);
  final h = s.h;
  final w = s.w;
  final r = Rng(seed * 11 + 1);

  final ferns = <(int, int, double, int)>[];
  final sideFiltered =
      s.side.where((p) => p.$2 > h * 0.2 && p.$2 < h * 0.85).toList();
  // Match JS comparator-driven shuffle order
  sideFiltered.sort((_, _) => r.next() < 0.5 ? -1 : 1);
  final roots = sideFiltered.take(6).toList();
  for (var i = 0; i < roots.length; i++) {
    final (x0, y0, dir) = roots[i];
    var x = x0.toDouble();
    var y = y0.toDouble();
    var ang = dir < 0 ? -0.5 : math.pi + 0.5;
    ang += r.range(-0.4, 0.4);
    for (var step = 0; step < 9; step++) {
      x += math.cos(ang) * 1.1;
      y += math.sin(ang) * 1.1;
      final px = x.round();
      final py = y.round();
      if (!s.on(px, py)) break;
      ferns.add((px, py, step / 9.0, i));
      if (step % 2 == 1) {
        for (final side in const [-1, 1]) {
          final ba = ang + side * 1.05;
          final l = 1 + (r.range(0.0, 2.0) * (1.0 - step / 9.0)).round();
          for (var k = 1; k <= l; k++) {
            final bx = (x + math.cos(ba) * k).round();
            final by = (y + math.sin(ba) * k).round();
            if (s.on(bx, by)) ferns.add((bx, by, (step + k * 0.6) / 9.0, i));
          }
        }
      }
      ang += r.range(-0.25, 0.25);
    }
  }

  int clearDown(int x, int y) {
    var n = 0;
    while (n < 7 && y + 1 + n < h && !s.on(x, y + 1 + n)) {
      n++;
    }
    return n;
  }

  final hangs = <(int x, int y, int c)>[];
  for (final (x, y) in s.body) {
    if (!s.on(x, y + 1) && s.on(x, y - 1) && y < h * 0.72 && y > 4) {
      final c = clearDown(x, y);
      if (c >= 4) hangs.add((x, y, c));
    }
  }

  (int, int, int)? best(
    bool Function((int, int, int)) f,
    int Function((int, int, int), (int, int, int)) key,
  ) {
    final matching = hangs.where(f).toList()
      ..sort((p, q) {
        final c = key(p, q);
        if (c != 0) return c;
        final yc = p.$2.compareTo(q.$2);
        return yc != 0 ? yc : p.$1.compareTo(q.$1);
      });
    return matching.isEmpty ? null : matching.first;
  }

  final rawIcicles = [
    best((p) => p.$2 < h * 0.36, (p, q) => p.$1.compareTo(q.$1)),
    best((p) => p.$2 < h * 0.36, (p, q) => q.$1.compareTo(p.$1)),
    best((p) => p.$2 >= h * 0.36 && p.$2 < h * 0.5 && p.$1 < w / 2.0,
        (p, q) => q.$1.compareTo(p.$1)),
    best((p) => p.$2 >= h * 0.36 && p.$2 < h * 0.5 && p.$1 >= w / 2.0,
        (p, q) => p.$1.compareTo(q.$1)),
    best((p) => p.$2 >= h * 0.5 && p.$1 < w / 2.0,
        (p, q) => p.$1.compareTo(q.$1)),
    best((p) => p.$2 >= h * 0.5 && p.$1 >= w / 2.0,
        (p, q) => q.$1.compareTo(p.$1)),
  ];

  final icicles = <_Icicle>[];
  for (var i = 0; i < rawIcicles.length; i++) {
    final item = rawIcicles[i];
    if (item == null) continue;
    final (x, y, c) = item;
    icicles.add(_Icicle(
      x,
      y + 1,
      math.min(c - 1.0, r.range(3.0, 5.5)),
      r.next(),
      i.isOdd ? 1.0 : 2.0,
    ));
  }

  final snow = [
    for (final (x, y) in s.up)
      if (y < h * 0.6) (x, y, 1 + (rand(x, seed, 3) < 0.45 ? 1 : 0)),
  ];

  final eList = actorEyes(a);
  final mouth = eList.length == 2
      ? (
          (eList[0].x1 + eList[1].x0 + 1) / 2.0,
          math.max(eList[0].y1, eList[1].y1) + 2.0,
        )
      : (w / 2.0, h * 0.38);

  final out = _FrozenPlan(ferns, icicles, snow, mouth);
  m[seed] = out;
  return out;
}

void _frost(Painter p, List<int> c, double t, double reach) {
  final x0 = -reach.ceil() - 1;
  final x1 = (reach + 1).floor();
  for (var x = x0; x <= x1; x++) {
    final q = (x + 0.5).abs() / reach;
    final h = rand(x, 17);
    final k = 1.0 - q * q;
    if (q > 1.0 + h * 0.15) continue;
    final tw = math.sin((t / _d) * tau * 2.0 + rand(x, 3) * tau) > 0.94;
    p.px(x, 0, tw || h < 0.3 ? c[7] : (q > 0.85 ? c[5] : c[6]));
    if (h < 0.3 * k) p.px(x, -1, c[6]);
    final jMax = 1 + (2.0 * k).round();
    for (var j = 1; j <= jMax; j++) {
      p.dot(x, j, j == 1 ? c[5] : c[4], (1.05 - j / 4.0) * 0.85);
    }
  }
}

final PureEffect frozenEffect = PureEffect(
  meta: const EffectMeta(
    id: 'status/frozen',
    name: 'Frozen',
    desc:
        'Chilled to the bone: frost ferns creep over the body, icicles hang from chin and hands and drip, breath steams, snow settles, a shiver every second, frost spreads underfoot.',
    category: 'status',
    tags: ['status', 'ice', 'freeze', 'frozen', 'cold', 'chill', 'debuff', 'loop'],
    size: (72, 64),
    origin: (36, 54),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#151a3d', '#212f6b', '#2c58aa', '#3a8bd8',
        '#62c8f4', '#a6ecff', '#dcfbff', '#ffffff',
      ],
      'seed': 4,
    },
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      PoseKey(0.0, _stiff.copyWith(crouch: 2)),
      const PoseKey(0.22, _stiff),
      const PoseKey(1.0, _stiff),
      PoseKey(1.0, _stiff.copyWith(crouch: 2), PoseEase.snap),
      const PoseKey(1.22, _stiff),
      PoseKey(2.0, _stiff.copyWith(crouch: 2)),
    ],
  ),
  onActorAlpha: (_, _) => 0.0,
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final reach = 13.0 + 3.5 * math.sin((t / _d) * tau);
    p.shade(-28, -3, 28, 6, (x, y, out) {
      final d = hypot(x / 24.0, (y - 0.5) / 4.0);
      if (d < 1.0) {
        out.l = c[4];
        out.k = 0.24 * (1.0 - d) * (1.0 - d);
      }
      return null;
    });
    _frost(p, c, t, reach);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final a = o.actor;
    final s = actorShape(a);
    final h = s.h;
    final plan = _plan(a, o.seed);
    final dx = _shake(t);
    final ph = _since(t);

    int xAt(num mx) => a.x + mx.round() + dx;
    int yAt(num my) => a.y + my.round();

    for (final (mx, my) in s.body) {
      final col = colorAt(a, mx, my);
      final ice = c[clampInt(1 + (luma(col) * 5.6).round(), 1, 7)];
      final rim =
          !s.on(mx - 1, my) || !s.on(mx, my - 1) || !s.on(mx + 1, my);
      p.px(
        xAt(mx),
        yAt(my),
        rim && luma(col) < 0.3
            ? (my < h * 0.5 || !s.on(mx - 1, my) ? c[5] : c[3])
            : mix(col, ice, 0.38),
      );
    }

    final grow = 0.2 + 0.65 * smooth(0.05, 0.95, ph);
    for (final (x, y, u, _) in plan.ferns) {
      if (u < grow) {
        p.px(
          xAt(x),
          yAt(y),
          u > grow - 0.1
              ? kWhite
              : (rand(x, y, 5) < 0.5 ? c[6] : c[5]),
        );
      }
    }

    for (final (x, y, d) in plan.snow) {
      p.px(xAt(x), yAt(y) - 1, c[7]);
      if (d > 1) p.px(xAt(x), yAt(y) - 2, rand(x, y, 9) < 0.5 ? c[7] : c[6]);
    }

    for (final ic in plan.icicles) {
      final per = ic.period;
      final u = (((t / per + ic.phase) % 1.0) + 1.0) % 1.0;
      final l = ic.len * (0.55 + 0.45 * smooth(0.0, 0.7, u));
      final x = xAt(ic.x);
      final y0 = yAt(ic.y);
      for (var j = 0; j < l; j++) {
        final v = j / l;
        p.px(x, y0 + j, v > 0.75 ? kWhite : (v < 0.3 ? c[7] : c[6]));
        if (v < 0.5) p.px(x + 1, y0 + j, c[4]);
      }
      if (u > 0.7 && u < 0.86) {
        p.px(x, y0 + l, c[6]);
      } else if (u >= 0.86) {
        final f = (u - 0.86) * per;
        final y = y0 + l + 0.5 * 760.0 * f * f;
        if (y < -1.0) {
          p.px(x, y, c[6]);
          p.px(x, y - 1, c[5]);
        }
      }
      p.glow(x, y0 + l * 0.6, 4, c[5], 0.18);
    }

    final (mx0, my0) = plan.mouth;
    for (var i = 0; i < 4; i++) {
      final age = ph - 0.35 - i * 0.05;
      if (age < 0.0 || age > 0.65) continue;
      final u = age / 0.65;
      final x = a.x + mx0 + dx + 1.0 + travel(16.0, 0.0, 2.2, age) + i;
      final y = a.y + my0 - travel(6.0, 3.0, 1.0, age) - i * 0.5;
      final rad = 0.8 + 2.4 * math.sqrt(u);
      p.disc(x, y, rad, c[7], 0.5 * (1.0 - u) * math.min(1.0, u * 8.0));
      p.disc(x - rad * 0.2, y - rad * 0.3, rad * 0.5, kWhite, 0.4 * (1.0 - u));
    }

    cycle(t, _d, 9, o.seed + 2, (r) => r.range(1.2, 1.8), (age, _, r, _) {
      final x = r.range(-14.0, 14.0) +
          math.sin(age * 3.0 + r.next() * tau) * 1.5;
      final y = a.y - 16.0 + age * 14.0;
      if (y > a.y + 2.0) return;
      p.dot(x, y, r.next() < 0.5 ? kWhite : c[6], math.min(1.0, age * 4.0));
    });

    if (ph < 0.5) {
      for (var i = 0; i < 8; i++) {
        final side = i.isOdd ? 1 : -1;
        final vx = side * (20.0 + 30.0 * rand(i, 4));
        final vy = -(20.0 + 30.0 * rand(i, 5));
        final x = side * (6.0 + 6.0 * rand(i, 6)) + vx * ph;
        final y = a.y + 3.0 * rand(i, 7) + vy * ph + 0.5 * 300.0 * ph * ph;
        p.dot(x, y, (i % 3 != 0) ? c[6] : kWhite, 1.2 - ph * 2.0);
      }
    }
    if (ph < 0.25) {
      sparkle(
        p,
        xAt((s.w * 0.3).round()).toDouble(),
        yAt(4).toDouble(),
        (3.0 * (1.0 - ph / 0.25)).roundToDouble(),
        c[6],
        c[5],
        0.4,
      );
    }

    p.glow(0, a.y + h * 0.45, 30, c[4], 0.2 + 0.12 * math.exp(-ph / 0.2));
    p.glow(0, a.y + 2.0, 16, c[5], 0.1);
  },
);
