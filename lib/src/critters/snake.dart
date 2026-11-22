import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'critters_lib.dart';

const double _duration = 2.4;
const double _head = 30.0;
const double _len = 70.0;
final CritterGrid _grid = CritterGrid(-44, -24, 88, 26);
final Swarm _swarm = Swarm();
final int _tongue = hex('#e8304a');
final int _dust = hex('#8a7f92');
const double _k = tau / 30.0;
const double _w = (tau * 2.0) / _duration;

double _lift(double u, double t) {
  final wave = math.pow(math.max(0.0, math.sin(_k * u - _w * t)), 0.85);
  final env = smooth(8.0, 18.0, u) * (1.0 - smooth(_len - 14.0, _len - 2.0, u));
  final neck = u < 12.0 ? 6.0 * (1.0 - u / 12.0) * (1.0 - u / 12.0) : 0.0;
  return 7.0 * wave * env + neck;
}

double _radius(double u) => u < 6.0
    ? 3.3
    : lerp(3.4, 0.6, math.pow((u - 6.0) / (_len - 6.0), 1.3).toDouble());

double _bob(double t) => 0.8 * math.sin(_w * t);

double _tongueExt(double t) {
  for (final t0 in const [0.3, 1.5]) {
    final k = (t - t0) / 0.5;
    if (k >= 0.0 && k < 1.0) {
      return math.pow(math.max(0.0, math.sin(k * math.pi * 3.0)), 0.6).toDouble();
    }
  }
  return 0.0;
}

void _snake(CritterGrid g, List<int> c, List<int> b, double t) {
  g.clear();
  final hb = _bob(t);
  for (var u = _len; u >= 2.0; u -= 0.5) {
    final x = _head - u;
    final r0 = _radius(u);
    final hump = _lift(u, t);
    final cy = -r0 - hump + (u < 12.0 ? hb * (1.0 - u / 12.0) : 0.0);
    final slope = _lift(u + 0.5, t) - _lift(u - 0.5, t);
    final r = r0 * math.sqrt(1.0 + slope * slope);
    final yEnd = (cy + r).ceil();
    for (var y = (cy - r).floor(); y <= yEnd; y++) {
      final v = (y + 0.5 - cy) / r;
      if (v.abs() > 1.0) continue;
      var col = v < -0.5
          ? c[4]
          : (v < 0.1
              ? c[3]
              : (v < 0.45 ? c[2] : (v < 0.8 ? b[1] : b[0])));
      final dm = (((u + 2.0).remainder(7.0)) - 3.5).abs() / 3.5 +
          (v + 0.25).abs() / 0.55;
      if (dm < 0.85 && v < 0.35 && u > 4.0) {
        col = dm < 0.5 ? c[1] : c[2];
      }
      if (v < -0.62 && hump > 4.5 && dm >= 0.85) {
        col = hump > 6.0 ? c[6] : c[5];
      }
      if (v > 0.45 && v < 0.8 && u.floor() % 3 == 0) col = b[2];
      g.set(x, y, col);
    }
  }

  const hx = _head + 2.0;
  final hy = -9.5 + hb;
  g.shade(hx - 5.0, hy - 4.0, hx + 6.0, hy + 4.0, (x, y, _) {
    final dx = (x - hx) / (x > hx ? 5.6 : 4.6);
    final dy = (y - hy) / (3.6 - math.max(0.0, x - hx) * 0.18);
    if (dx * dx + dy * dy > 1.0) return 0;
    if (dy > 0.55) return b[1];
    return dy < -0.3 ? (dx < 0.3 ? c[5] : c[4]) : c[3];
  });
  g.line(hx - 1.0, hy + 1.5, hx + 5.0, hy + 1.2, c[1]);
  g.set(hx + 1.0, hy - 2.0, c[0]);
  g.set(hx + 2.0, hy - 2.0, b[2]);
  g.set(hx + 1.0, hy - 1.0, b[2]);
  g.set(hx + 2.0, hy - 1.0, c[0]);
  g.set(hx + 1.0, hy - 3.0, c[6]);
  g.set(hx + 5.0, hy - 1.0, c[1]);
  g.outline(c[0]);
}

final PureEffect snakeEffect = PureEffect(
  meta: const EffectMeta(
    id: 'critters/snake',
    name: 'Snake',
    desc:
        'A snake slithers along the floor, head raised: humps rise and roll back down its patterned body to the tail, dust puffs where it touches down, its forked tongue flicks.',
    category: 'critters',
    tags: ['critter', 'snake', 'reptile', 'ground', 'loop'],
    size: (136, 56),
    origin: (68, 48),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#081410',
        '#123a1e',
        '#1d5e2a',
        '#2f8a36',
        '#5cb848',
        '#a8e070',
        '#e8ffc0',
      ],
      'belly': ['#4a3a14', '#b08a34', '#f0d878'],
      'seed': 1,
    },
  ),
  onDrawBack: (p, time, o) {
    final t = shift(time, _duration, o.seed);
    final c = fit(o.palette, 7);
    for (var u = 2.0; u <= _len; u += 2.0) {
      final h = _lift(u, t);
      final r = _radius(u);
      shadow(
        p,
        _head - u,
        -0.2,
        2.2 + r * 0.4,
        1.2,
        c[0],
        0.5 * (1.0 - clamp(h / 10.0)) + 0.1,
      );
    }
    shadow(p, _head + 2.0, -0.2, 5.0, 1.2, c[0], 0.35);
  },
  onDraw: (p, time, o) {
    final seed = o.seed;
    final t = shift(time, _duration, seed);
    final c = fit(o.palette, 7);
    final b = fit(o.rampOpt('belly'), 3);
    final hb = _bob(t);

    final e = _tongueExt(t);
    const tx = _head + 7.5;
    final ty = -8.2 + hb;
    if (e > 0.05) {
      final len = 7.0 * e;
      final wig = math.sin(t * 60.0) * 0.6 * e;
      p.line(tx, ty, tx + len, ty + wig, _tongue);
      if (len > 3.0) {
        p.px(tx + len + 1.0, ty + wig - 1.0, _tongue);
        p.px(tx + len + 1.0, ty + wig + 1.0, _tongue);
      }
    }

    final g = _grid;
    _snake(g, c, b, t);
    g.draw(p);

    final sw = _swarm.begin(t);
    cycle(t, _duration, 26, seed * 7 + 1, (r) => r.range(0.6, 1.1),
        (age, len, r, _) {
      final born = wrap(t - age, _duration);
      final m = r.intRange(0, 2);
      final u = (math.pi + _w * born + m * tau) / _k;
      if (u < 18.0 || u > _len - 10.0) return;
      final x = _head - u + r.range(-2.0, 2.0) - r.range(6.0, 16.0) * age;
      sw.add(
        P.smoke,
        x,
        -0.5 - age * r.range(3.0, 8.0),
        0,
        0,
        age,
        len,
        _dust,
        r.range(1.8, 3.4),
      );
    });
    sw.draw(p);

    p.glow(_head + 3.5, -11.0 + hb, 4, b[2], 0.35);
  },
);
