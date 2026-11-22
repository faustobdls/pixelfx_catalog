import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'scifi_lib.dart';

const double _duration = 2.0;
const int _gap = 8;
const int _fr = 30;
final int _nf = ((_duration * _fr) + 0.5).floor();

final Map<String, Ghosts> _cache = {};

Ghosts _ghosts(Map<String, Object?> o, List<int> f) {
  final pal = o.palette;
  final l = o.numOpt('length', 26.0);
  final key = '${o.seed}:${pal.join(',')}:$l';
  final hit = _cache[key];
  if (hit != null) return hit;

  final rn = Rng(o.seed);
  final g = Ghosts(
    _duration,
    sparks: [kWhite, f[6], f[5], f[4]],
    box: (-46.0, -28.0, 46.0, 84.0),
  );
  for (final s in const [-1, 1]) {
    for (var i = 0; i < 26; i++) {
      g.add(
        rn.range(0.0, _duration),
        P.fire,
        s * _gap + rn.range(-1.5, 1.5),
        l * rn.range(0.55, 0.85),
        rn.range(-10.0, 10.0),
        rn.range(70.0, 130.0),
        rn.range(0.22, 0.4),
        0,
        rn.range(2.2, 3.4),
        PF.smokes | (rn.chance(0.5) ? PF.big : 0),
      );
    }
    for (var i = 0; i < 10; i++) {
      g.add(
        rn.range(0.0, _duration),
        P.smoke,
        s * _gap + rn.range(-3.0, 3.0),
        l + rn.range(2.0, 8.0),
        s * rn.range(0.0, 14.0),
        rn.range(40.0, 80.0),
        rn.range(1.1, 1.6),
        0,
        rn.range(3.0, 5.0),
        PF.big,
      );
    }
    for (var i = 0; i < 10; i++) {
      g.add(
        rn.range(0.0, _duration),
        P.spark,
        s * _gap + rn.range(-1.0, 1.0),
        l * rn.range(0.3, 0.7),
        s * rn.range(-40.0, 60.0),
        rn.range(80.0, 200.0),
        rn.range(0.2, 0.45),
      );
    }
    for (var i = 0; i < 5; i++) {
      g.add(
        rn.range(0.0, _duration),
        P.ember,
        s * _gap + rn.range(-2.0, 2.0),
        l * rn.range(0.6, 1.0),
        s * rn.range(10.0, 40.0),
        rn.range(20.0, 60.0),
        rn.range(0.6, 1.1),
        f[4],
        rn.range(0.8, 1.6),
      );
    }
  }
  _cache[key] = g;
  return g;
}

void _pack(Painter p, List<int> h, List<int> f, int dy) {
  for (final s in const [-1, 1]) {
    final cx = s * _gap;
    p.shade(cx - 5, -24 + dy, cx + 5, -3 + dy, (x, y, out) {
      final u = (x - cx) / 4.5;
      final top = -19.0 + dy;
      final v = y < top ? (y - top) / 4.5 : 0.0;
      if (u * u + v * v > 1.0) return null;
      final l = -u * 0.8 - v * 0.6;
      out.c = u * u + v * v > 0.78
          ? h[0]
          : ((y - (-12 + dy)).abs() < 0.6
              ? h[1]
              : (l > 0.55
                  ? h[5]
                  : (l > 0.15 ? h[4] : (l > -0.35 ? h[3] : h[2]))));
      return null;
    });
    for (var y = -3; y <= 0; y++) {
      final w = 2.0 + (y + 3) * 0.7;
      for (var x = (cx - w).floor(); x <= (cx + w).ceil(); x++) {
        final inner = (x + 0.5 - cx).abs() < w - 1.2 && y >= -1;
        p.px(
          x,
          y + dy,
          inner
              ? (y == 0 ? f[6] : f[4])
              : ((x + 0.5 - cx).abs() > w - 0.6
                  ? h[0]
                  : (x < cx ? h[3] : h[1])),
        );
      }
    }
  }
  for (var y = -20; y <= -6; y++) {
    p.px(-1, y + dy, h[1]);
    p.px(0, y + dy, h[2]);
    p.px(1, y + dy, h[0]);
  }
  p.px(0, -16 + dy, f[5]);
}

void _draw(Painter p, double t, Map<String, Object?> o) {
  final f = fit(o.palette, 8);
  final h = fit(o.rampOpt('metal'), 6);
  final ph = t / _duration;
  final frame = (t * _fr).floor() % _nf;
  final s = o.seed;
  final length = o.numOpt('length', 26.0);
  final dy = (math.sin(tau * 12.0 * ph) * 0.6 + 0.5).floor();
  final g = _ghosts(o, f).at(t);
  g.draw(p, 'back');

  for (final side in const [-1, 1]) {
    final cx = side * _gap + (rand(s, frame, side) < 0.15 ? side * 0.5 : 0.0);
    final l = length *
        (0.92 +
            0.08 * math.sin(tau * 7.0 * ph + side) +
            0.06 * (rand(s, frame, side, 1) - 0.5));
    p.shade(cx - 7, dy, cx + 7, dy + l + 4, (x, y, out) {
      final v = (y - dy) / l;
      final w = lerp(3.4, 0.6, v) +
          1.4 * math.sin(v * math.pi) * (v < 1.0 ? 1.0 : 0.0);
      final n = tileFbm(
        (x - cx) / 3.0 + side * 5.0,
        (y - dy) / 4.0 - ph * 20.0,
        0,
        10,
        s + (side > 0 ? 9 : 0),
        2,
      );
      final q = (x - cx).abs() / w + n * 0.45;
      if (v > 1.15 || q > 1.2) return null;
      final heat = (1.0 - v) * 1.15 - q * 0.9 + n * 0.25;
      if (q > 0.95) {
        out.c = heat > 0.2 ? f[3] : f[2];
        if (heat < -0.3) out.a = 0.5;
        return null;
      }
      out.c = heat > 0.82
          ? kWhite
          : (heat > 0.62
              ? f[6]
              : (heat > 0.42
                  ? f[5]
                  : (heat > 0.22
                      ? f[4]
                      : (heat > 0.02 ? f[3] : f[2]))));
      return null;
    });
    for (var i = 0; i < 3; i++) {
      final y = (dy + 5.0 + i * 6.5 + math.sin(tau * 4.0 * ph + i) * 0.5 + 0.5)
          .floor();
      final r =
          (2.2 - i * 0.45 + 0.4 * math.sin(tau * 8.0 * ph + i * 2) + 0.5)
              .floor();
      if (y > dy + l * 0.75 || r < 1) break;
      for (var yy = -r; yy <= r; yy++) {
        for (var xx = -r; xx <= r; xx++) {
          final d = xx.abs() + yy.abs();
          if (d <= r) {
            p.px(cx + xx, y + yy, d < r ? kWhite : (i == 0 ? f[6] : f[5]));
          }
        }
      }
      p.glow(cx, y, 6, f[6], 0.35);
    }
    p.glow(cx, dy + 2, 9, kWhite, 0.45);
    p.glow(cx, dy + l * 0.45, l * 0.8, f[4], 0.35);
  }
  _pack(p, h, f, dy);
  g.draw(p, 'front');
  p.glow(0, length + 14, 34, f[4], 0.16);
  p.glow(0, length * 0.4, 30, f[5], 0.18);
}

final PixelEffect jetpackEffect = PureEffect(
  meta: const EffectMeta(
    id: 'scifi/jetpack',
    name: 'Jetpack',
    desc:
        'Twin thrusters fire straight down: white-hot cores with shock diamonds inside ragged flames, puffs that cool into smoke billowing below, lit by the fire.',
    category: 'scifi',
    tags: [
      'scifi',
      'jetpack',
      'thrust',
      'rocket',
      'fire',
      'smoke',
      'flight',
      'loop',
    ],
    size: (96, 116),
    origin: (48, 30),
    duration: _duration,
    loop: true,
    fps: _fr,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#2a0e12',
        '#5c1818',
        '#a02818',
        '#e0501a',
        '#ff8a2a',
        '#ffc23d',
        '#fff3a6',
        '#ffffff',
      ],
      'metal': [
        '#0e0d14',
        '#1e1c27',
        '#312e3e',
        '#4b4759',
        '#6f6a82',
        '#9d98b0',
      ],
      'length': 26,
      'seed': 30,
    },
  ),
  onDraw: _draw,
);
