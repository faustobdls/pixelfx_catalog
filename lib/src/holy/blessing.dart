import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'holy_lib.dart';

const Pose _open = Pose(
  turn: 1.15,
  fx: -13,
  fy: -31,
  bx: 14,
  by: -31,
  hy: -1,
  ffx: -3,
  fbx: 4,
);

const double _top = -108.0;
const double _tDur = 3.0;

double _halfW(double y) => lerp(5.0, 20.0, (y - _top) / -_top);

// The rays in the cone, each shimmering a whole number of times a loop so it closes.
const List<(double o, double w, int k, double ph)> _rays = [
  (-0.62, 0.16, 1, 0.3),
  (-0.2, 0.2, 2, 1.7),
  (0.22, 0.14, 1, 4.1),
  (0.6, 0.18, 2, 2.6),
];

double _ray(double q, double t) {
  var intensity = 0.3 * math.max(0.0, 1.0 - q * q);
  for (final (o, w, k, ph) in _rays) {
    final d = (q - o) / w;
    intensity += math.exp(-(d * d)) *
        (0.55 + 0.45 * math.sin((t / _tDur) * tau * k + ph)) *
        0.6;
  }
  return intensity * smooth(1.25, 0.75, q.abs());
}

class _SparkleLanding {
  final double q;
  final double v;
  final double sway;
  final double ph;
  final double size;
  final double land;

  const _SparkleLanding({
    required this.q,
    required this.v,
    required this.sway,
    required this.ph,
    required this.size,
    required this.land,
  });
}

final Expando<Map<String, List<_SparkleLanding>>> _lands =
    Expando<Map<String, List<_SparkleLanding>>>();

List<_SparkleLanding> _landings(
  int seed,
  ActorDefinition actor,
  HolyShape s,
) {
  var byKey = _lands[actor.mask];
  if (byKey == null) {
    byKey = {};
    _lands[actor.mask] = byKey;
  }
  final key = '$seed:${s.x}:${s.y}';
  final cached = byKey[key];
  if (cached != null) return cached;

  final out = <_SparkleLanding>[];
  for (var i = 0; i < 20; i++) {
    final r = rng(seed, i);
    final q = r.range(-0.9, 0.9);
    final v = r.range(22.0, 34.0);
    final sway = r.range(1.0, 3.0);
    final ph = r.range(0.0, tau);
    final size = r.range(0.8, 2.4);
    var land = double.infinity;
    for (var a = 0.0; a < 6.0; a += 0.02) {
      final y = _top + 6.0 + v * a;
      final x = q * _halfW(y) + math.sin(a * 2.2 + ph) * sway;
      if (y >= -1.0 || s.at(x, y)) {
        land = a;
        break;
      }
    }
    out.add(_SparkleLanding(
      q: q,
      v: v,
      sway: sway,
      ph: ph,
      size: size,
      land: land,
    ));
  }
  byKey[key] = out;
  return out;
}

final PureEffect blessingEffect = PureEffect(
  meta: const EffectMeta(
    id: 'holy/blessing',
    name: 'Blessing',
    desc:
        'A soft cone of light rests on the character from above; sparkles drift down through it, twinkling, and wink out where they land on the head and shoulders.',
    category: 'holy',
    tags: ['holy', 'blessing', 'buff', 'light', 'sparkle', 'character', 'loop'],
    size: (80, 128),
    origin: (40, 108),
    duration: _tDur,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'palette': kHolyGold, 'seed': 7},
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      const PoseKey(0.0, _open),
      PoseKey(0.75, _open.copyWith(fy: -33, by: -33)),
      PoseKey(1.5, _open.copyWith(crouch: -1, fy: -35, by: -35)),
      PoseKey(2.25, _open.copyWith(fy: -33, by: -33)),
      const PoseKey(3.0, _open),
    ],
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    // The cone: soft light with a faint gold haze in it.
    p.each(-24.0, _top, 24.0, 0.5, (x, y, sx, sy) {
      final intensity =
          _ray(x / _halfW(y), t) * (0.6 + 0.4 * smooth(_top, 0.0, y));
      if (intensity < 0.02) return;
      p.blendPx(sx, sy, c[6], intensity * 0.13);
      p.add(sx, sy, c[4], intensity * 0.22);
    });
    // Two of the rays show as fine lines, light running slowly down them.
    for (final (o2, _, k, ph) in [_rays[1], _rays[2]]) {
      for (var y = _top.toInt(); y < -1; y++) {
        final yd = y.toDouble();
        final pulse = 0.5 + 0.5 * math.sin(yd * 0.11 - (t / _tDur) * tau * 3.0 + ph);
        p.dot(
          o2 * _halfW(yd),
          yd,
          pulse > 0.85 ? kWhite : c[6],
          (0.1 + 0.45 * pulse) *
              (0.5 + 0.5 * math.sin((t / _tDur) * tau * k + ph)) *
              smooth(_top, _top + 20.0, yd),
        );
      }
    }
    p.glow(0, -4, 30, c[4], 0.22);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final seed = o.seed;
    final a = o['actor'] as ActorDefinition?;
    final s = a != null ? shapeOf(a) : null;
    // Light catching the top of the head and the shoulders.
    if (a != null) {
      final m = a.mask;
      if (a.pixels.isNotEmpty) {
        for (var i = 0; i < m.w; i++) {
          for (var j = 0; j < m.h; j++) {
            final col = a.pixels[j * m.w + i];
            if (col == 0 || luma(col) < 0.15) continue;
            p.px(a.x + i, a.y + j, mix(col, c[6], 0.35));
            break;
          }
        }
      }
      p.glow(0, -30, 20, c[5], 0.22);
    }
    // The floor catches it: a lit line and a pool fading out into the stone.
    for (var y = 0; y <= 3; y++) {
      for (var x = -24; x <= 24; x++) {
        final u = hypot(x / 24.0, y / 4.0);
        if (u >= 1.0) continue;
        p.dot(
          x,
          y,
          u < 0.3
              ? (y != 0 ? c[5] : kWhite)
              : (u < 0.6 ? c[5] : (u < 0.85 ? c[4] : c[3])),
          y == 0 ? math.sqrt(1.0 - u) : (1.0 - u) * 0.7,
        );
      }
    }
    // Sparkles drifting down, twinkling, winking out where they land.
    if (a != null && s != null) {
      final lands = _landings(seed, a, s);
      cycle(t, _tDur, lands.length, seed, (_) => 3.0, (age, life, _, i) {
        final item = lands[i];
        final y = _top + 6.0 + item.v * age;
        final x =
            item.q * _halfW(y) + math.sin(age * 2.2 + item.ph) * item.sway;
        final fade = math.min(1.0, age / 0.3);
        if (age > item.land) {
          final w = (age - item.land) / 0.14;
          if (w < 1.0) {
            final ly = _top + 6.0 + item.v * item.land;
            final lx = item.q * _halfW(ly) +
                math.sin(item.land * 2.2 + item.ph) * item.sway;
            sparkle(
              p,
              lx,
              ly,
              3.0 * (1.0 - w) + 1.0,
              kWhite,
              c[6],
              0.5 * (1.0 - w),
            );
          }
          return;
        }
        final tw = 0.6 + 0.4 * math.sin(age * (7.0 + (i % 4)) + item.ph);
        if (item.size > 1.2) {
          sparkle(
            p,
            x,
            y,
            item.size * tw * fade,
            tw > 0.85 ? kWhite : c[6],
            c[5],
            0.35 * fade,
          );
        } else {
          p.dot(x, y, tw > 0.8 ? kWhite : c[6], fade);
          p.glow(x, y, 3, c[5], 0.35 * fade);
        }
      });
    }
    // Fine motes hanging in the light.
    cycle(t, _tDur, 16, seed + 9, (g) => g.range(1.2, 2.4),
        (age, life, r, _) {
      final u = age / life;
      final y = _top + 10.0 + r.range(0.0, 90.0) + u * r.range(6.0, 14.0);
      final q = r.range(-1.0, 1.0);
      final x = q * _halfW(y) + math.sin(age * 1.7 + q * 5.0) * 1.5;
      final k = math.sin(u * math.pi) * _ray(q, t);
      if (k > 0.12) {
        p.dot(x, y, k > 0.45 ? kWhite : c[6], math.min(1.0, k * 2.2));
      }
    });
  },
);
