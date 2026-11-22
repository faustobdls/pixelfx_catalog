import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'status_lib.dart';

const double _d = 1.6;
const double _tick = 0.8;
const double _g = 760.0;

const Pose _sick = Pose(
  turn: 0.8,
  crouch: 4,
  lean: 4,
  hy: 1,
  fx: 2,
  fy: -20,
  bx: 8,
  by: -14,
  ffx: 3,
  fbx: -3,
);

double _since(double t) => ((t % _tick) + _tick) % _tick;

class _Blister {
  final int x;
  final int y;
  final double r;
  const _Blister(this.x, this.y, this.r);
}

class _PoisonBody {
  final List<List<(int x, int y, double u)>> veins;
  final (int x, int y) wound;
  final List<List<_Blister>> blisters;
  final List<(int x, int y)> sweat;
  const _PoisonBody(this.veins, this.wound, this.blisters, this.sweat);
}

final Expando<Map<int, _PoisonBody>> _bodiesCache =
    Expando<Map<int, _PoisonBody>>();

_PoisonBody _body(ActorDefinition a, int seed) {
  var m = _bodiesCache[a.mask];
  if (m == null) {
    m = {};
    _bodiesCache[a.mask] = m;
  }
  final existing = m[seed];
  if (existing != null) return existing;

  final s = actorShape(a);
  final h = s.h;
  final w = s.w;
  final r = Rng(seed * 7 + 3);

  final (l, right) = s.rows[(h * 0.6 + 0.5).floor()];
  final wx = right - 1;
  final wy = (h * 0.6 + 0.5).floor();

  final veins = <List<(int, int, double)>>[];
  void walk(double x, double y, double ang, double len, int depth) {
    final pts = <(int, int, double)>[];
    for (var step = 0; step < len; step++) {
      ang += r.range(-0.5, 0.5);
      x += math.cos(ang);
      y += math.sin(ang);
      final rx = (x + 0.5).floor();
      final ry = (y + 0.5).floor();
      if (!s.on(rx, ry)) break;
      pts.add((rx, ry, step / len));
      if (depth < 2 && step > 2 && r.chance(0.16)) {
        walk(
          x,
          y,
          ang + r.sign() * r.range(0.6, 1.1),
          len * 0.55,
          depth + 1,
        );
      }
    }
    veins.add(pts);
  }

  for (var i = 0; i < 4; i++) {
    walk(
      wx.toDouble(),
      wy.toDouble(),
      math.pi + (i / 4.0 - 0.45) * 2.2,
      11.0,
      0,
    );
  }

  double lum(int x, int y) => luma(colorAt(a, x, y));
  final skin = s.body
      .where((p) => lum(p.$1, p.$2) > 0.55 && s.on(p.$1 - 1, p.$2) && s.on(p.$1 + 1, p.$2))
      .toList();
  (int, int) pick(List<(int, int)> list) => list[(r.next() * list.length).floor()];
  final blisterCand = s.body
      .where(
        (p) =>
            p.$2 > 4 &&
            s.on(p.$1 - 1, p.$2) &&
            s.on(p.$1 + 1, p.$2) &&
            s.on(p.$1, p.$2 - 1),
      )
      .toList();
  final blisters = [
    for (var tick = 0; tick < 2; tick++)
      [
        for (var j = 0; j < 3; j++)
          () {
            final (x, y) = pick(blisterCand);
            return _Blister(x, y, r.range(1.1, 1.8));
          }(),
      ],
  ];

  final eList = actorEyes(a);
  final sweat = <(int, int)>[];
  for (final e in eList) {
    sweat.add((e.x0 < w / 2.0 ? e.x0 - 1 : e.x1 + 1, e.y0 - 1));
  }
  for (final side in const [-1, 1]) {
    final hand = s.body.where(
      (p) =>
          p.$2 > h * 0.5 &&
          p.$2 < h * 0.7 &&
          (side < 0 ? p.$1 <= l + 1 : p.$1 >= right - 1) &&
          !s.on(p.$1, p.$2 + 1),
    );
    if (hand.isNotEmpty) sweat.add(hand.first);
  }
  if (sweat.isEmpty) sweat.add(pick(skin.isNotEmpty ? skin : s.body));

  final out = _PoisonBody(veins, (wx, wy), blisters, sweat);
  m[seed] = out;
  return out;
}

int Function(int my) _offsets(double t, int h) {
  final lean = 1.3 * math.sin((t / _d) * tau);
  final ph = _since(t);
  final wob = ph < 0.12;
  final w = wob ? math.sin((ph / 0.12) * math.pi) : 0.0;
  return (int my) =>
      (lean * (1.0 - my / h) + w * math.sin(my * 0.42 + ph * 40.0) + 0.5).floor();
}

final PureEffect poisonedEffect = PureEffect(
  meta: const EffectMeta(
    id: 'status/poisoned',
    name: 'Poisoned',
    desc:
        'Sick to the bone: green rolls up the body in waves, dark veins creep from a wound, toxic sweat drips and hisses; every 0.8 s it wobbles, blisters pop and a ring pulses out.',
    category: 'status',
    tags: ['status', 'poison', 'toxic', 'dot', 'debuff', 'sick', 'loop'],
    size: (72, 64),
    origin: (36, 54),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#0e1d14', '#173320', '#23552e', '#318232',
        '#55b92f', '#8eea3f', '#cfff63', '#f6ffc2',
      ],
      'veins': '#2c1a3a',
      'seed': 5,
    },
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      PoseKey(0.0, _sick.copyWith(x: -1, crouch: 5, lean: 5)),
      PoseKey(0.2, _sick.copyWith(x: 0)),
      PoseKey(0.5, _sick.copyWith(x: 1)),
      PoseKey(0.8, _sick.copyWith(x: 1, crouch: 5, lean: 5)),
      PoseKey(1.0, _sick.copyWith(x: 0)),
      PoseKey(1.3, _sick.copyWith(x: -1)),
      PoseKey(1.6, _sick.copyWith(x: -1, crouch: 5, lean: 5)),
    ],
  ),
  onActorAlpha: (_, _) => 0.0,
  onDrawBack: (p, t, o) {
    final pCols = fit(o.palette, 8);
    final ph = _since(t);
    final k = ph / 0.55;
    if (k < 1.0) {
      band(
        p,
        0.0,
        0.0,
        5.0 + 22.0 * math.sqrt(k),
        0.18,
        math.max(1.0, 2.5 * (1.0 - k)),
        1.0 - k,
        [pCols[3], pCols[4], pCols[5], pCols[6]],
        keep: (double g) => math.sin(g) < 0.0,
      );
    }
    p.shade(-28, -3, 28, 6, (x, y, out) {
      final d = hypot(x / 24.0, (y - 0.5) / 4.0);
      if (d < 1.0) {
        out.l = pCols[4];
        out.k = (0.14 + 0.2 * math.exp(-ph / 0.2)) * (1.0 - d) * (1.0 - d);
      }
      return null;
    });
  },
  onDraw: (p, t, o) {
    final pCols = fit(o.palette, 8);
    final a = o.actor;
    final s = actorShape(a);
    final h = s.h;
    final b = _body(a, o.seed);
    final off = _offsets(t, h);
    final ph = _since(t);
    final tick = (t / _tick).floor() % 2;
    final vein = hex(o.strOpt('veins', '#2c1a3a'));

    for (final (mx, my) in s.body) {
      final c = colorAt(a, mx, my);
      final l = luma(c);
      final wave =
          0.5 + 0.5 * math.sin(tau * ((my / h) * 1.6 + (t / _d) * 2.0));
      final sick = pCols[clampInt(1 + (l * 6.2 + 0.5).floor(), 1, 7)];
      final k = 0.22 + 0.4 * wave * wave;
      p.px(
        a.x + mx + off(my),
        a.y + my,
        mix(c, wave > 0.85 && l > 0.4 ? mix(sick, pCols[6], 0.3) : sick, k),
      );
    }

    final grow = smooth(0.0, _d * 0.55, t) * (1.0 - smooth(_d * 0.62, _d, t)) * 1.15;
    for (final pts in b.veins) {
      for (final (x, y, u) in pts) {
        if (u < grow) {
          p.px(a.x + x + off(y), a.y + y, u > grow - 0.12 ? pCols[2] : vein);
        }
      }
    }
    final (wx, wy) = b.wound;
    p.px(a.x + wx + off(wy), a.y + wy, pCols[6]);
    p.px(a.x + wx + off(wy) - 1, a.y + wy, pCols[3]);
    p.glow(a.x + wx, a.y + wy, 6, pCols[5], 0.3);

    for (final bl in b.blisters[tick]) {
      final x = a.x + bl.x + off(bl.y);
      final y = a.y + bl.y;
      final grow2 = clamp(ph / 0.16);
      final pop = ph > 0.38;
      if (!pop) {
        final r = bl.r * grow2;
        p.circle(x, y, r + 0.6, pCols[3]);
        p.circle(x - 0.2, y - 0.2, r, pCols[5]);
        if (r > 0.8) p.px(x - 0.5, y - 0.8, kWhite);
        p.glow(x, y, 4, pCols[5], 0.3 * grow2);
      } else if (ph < 0.56) {
        final k = (ph - 0.38) / 0.18;
        for (var j = 0; j < 6; j++) {
          final an = (j / 6.0) * tau + bl.x;
          final d = bl.r + 0.5 + k * 3.5;
          p.dot(
            x + math.cos(an) * d,
            y + math.sin(an) * d - k * 2.0,
            j.isOdd ? pCols[6] : pCols[5],
            1.2 - k,
          );
        }
        p.glow(x, y, 6, pCols[6], 0.4 * (1.0 - k));
      }
    }

    for (var i = 0; i < b.sweat.length; i++) {
      final (sx, sy) = b.sweat[i];
      const per = _d / 2.0;
      final age = (((t - i * 0.37) % per) + per) % per;
      const gather = 0.35;
      final x = a.x + sx + 0.5 + off(sy);
      final y0 = a.y + sy;
      if (age < gather) {
        final k = age / gather;
        final run = (k * 2.0 + 0.5).floor();
        p.px(x, y0 + run, k > 0.5 ? pCols[6] : pCols[5]);
        if (k > 0.5) p.px(x, y0 + run - 1, pCols[4]);
        continue;
      }
      final f = age - gather;
      final fallH = -1.0 - (y0 + 2);
      final tf = math.sqrt((2.0 * math.max(1.0, fallH)) / _g);
      if (f < tf) {
        final y = y0 + 2.0 + 0.5 * _g * f * f;
        p.line(x, y - math.min(3.0, _g * f * 0.012), x, y, pCols[4]);
        p.px(x, y, pCols[6]);
        continue;
      }
      final hh = f - tf;
      if (hh > 0.4) continue;
      final k = hh / 0.4;
      p.line(
        x - 1.0 - k * 2.0,
        -1.0,
        x + 1.0 + k * 2.0,
        -1.0,
        pCols[k < 0.4 ? 6 : 4],
        1.2 - k,
      );
      for (var j = 0; j < 3; j++) {
        p.dot(
          x + (j - 1) * (2.0 + 3.0 * k),
          -2.0 - (j % 2) - 5.0 * k * (1.0 - k),
          pCols[6],
          1.0 - k,
        );
      }
      p.disc(
        x + math.sin(k * 6.0) * 1.5,
        -3.0 - k * 6.0,
        1.0 + 1.5 * k,
        pCols[5],
        0.35 * (1.0 - k),
      );
      p.glow(x, -1.5, 5, pCols[5], 0.35 * (1.0 - k));
    }

    final k = ph / 0.55;
    if (k < 1.0) {
      band(
        p,
        0.0,
        0.0,
        5.0 + 22.0 * math.sqrt(k),
        0.18,
        math.max(1.0, 2.5 * (1.0 - k)),
        1.0 - k,
        [pCols[3], pCols[4], pCols[5], pCols[6]],
        keep: (double g) => math.sin(g) >= 0.0,
      );
    }

    p.glow(0, a.y + h * 0.45, 26, pCols[4], 0.14 + 0.2 * math.exp(-ph / 0.18));
  },
);
