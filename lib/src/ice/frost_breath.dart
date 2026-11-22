import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const double _duration = 1.2;
const double _sink = 9.0;

void _puff(
  Painter p,
  List<int> c,
  double x,
  double y,
  double r,
  double a,
  double k,
  bool front,
) {
  final body = front ? c[5] : c[4];
  final cap = front ? c[7] : c[6];
  double Function(double, double) soft(double q) =>
      (d, _) => q * (1.0 - d * d);
  p.discShaded(x, y, r, color: (_, _) => body, alpha: soft(a * 0.6));
  p.discShaded(
    x + r * 0.06,
    y + r * 0.12,
    r * 0.68,
    color: (_, _) => mix(body, c[3], 0.3),
    alpha: soft(a * 0.5),
  );
  if (k < 0.55) {
    p.discShaded(
      x - r * 0.25,
      y - r * 0.3,
      r * 0.5,
      color: (_, _) => cap,
      alpha: soft(a * 0.7 * (1.0 - k / 0.55)),
    );
  }
  p.glow(x, y, r * 1.7, c[4], 0.1 * a);
}

void _gust(Painter p, List<int> c, double t, Map<String, Object?> o) {
  final ph = t / _duration;
  final sp = math.tan(o.numOpt('spread', 0.21)) * 1.08;
  final s = o.seed;
  p.each(2, -46, 170, 46, (x, y, sx, sy) {
    final u = x / 170.0;
    final hw = 2.5 + x * sp;
    final yc = 7.0 * u * u;
    final v = (y - yc) / hw;
    if (v * v >= 1.0 || u >= 1.0) return;
    final n = tileFbm(x * 0.055 - ph * 10.0, (y - yc) * 0.15 + 7.0, 10, 0, s, 2);
    final edge = (1.0 - v * v) *
        (u < 0.08 ? u / 0.08 : 1.0) *
        math.pow(1.0 - u, 0.8);
    final d = clamp(
            0.5 + n * 1.3 + (1.0 - v.abs()) * 0.35 * math.pow(1.0 - u, 1.5)) *
        edge;
    if (d < 0.08) return;
    p.blendPx(
      sx,
      sy,
      d > 0.72 ? c[7] : (d > 0.52 ? c[6] : (d > 0.32 ? c[5] : c[4])),
      math.min(0.78, d * 0.95) * clamp((d - 0.08) / 0.3),
    );
    if (d > 0.3) p.add(sx, sy, d > 0.6 ? c[6] : c[5], 0.2 * d);
  });
}

final PureEffect frostBreathEffect = PureEffect(
  meta: const EffectMeta(
    id: 'ice/frost-breath',
    name: 'Frost breath',
    desc:
        'A cone of icy wind blowing right: frost puffs billow out, swell and sink, wind streaks race through, ice crystals tumble and glint off a white-hot mouth.',
    category: 'ice',
    tags: ['ice', 'breath', 'frost', 'cone', 'wind', 'directional', 'loop'],
    size: (184, 104),
    origin: (12, 50),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#151a3d', '#212f6b', '#2c58aa', '#3a8bd8',
        '#62c8f4', '#a6ecff', '#dcfbff', '#ffffff',
      ],
      'spread': 0.21,
      'power': 1,
      'seed': 11,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final s = o.seed;
    final sp = o.numOpt('spread', 0.21);
    final power = o.numOpt('power', 1.0);
    _gust(p, c, t, o);
    cycle(t, _duration, 12, s, (g) => g.range(1, 1.25), (age, life, r, _) {
      final th = r.range(-sp, sp);
      final v = r.range(170, 230) * power;
      final (x, y) = fly(
        3,
        r.range(-1, 1),
        v * math.cos(th),
        v * math.sin(th),
        age,
        _sink,
        1.4,
      );
      final k = age / life;
      final rad = 2.0 + 12.0 * math.pow(k, 0.75);
      _puff(
        p,
        c,
        x,
        math.min(y, 40.0 - rad),
        rad,
        0.75 * math.pow(1.0 - k, 1.2) * math.min(1.0, age / 0.08),
        k,
        false,
      );
    });
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final s = o.seed;
    final sp = o.numOpt('spread', 0.21);
    final power = o.numOpt('power', 1.0);
    final ph = t / _duration;
    p.glowLine(4, 0, 120, 6, 24, c[4], 0.26);
    p.glowLine(2, 0, 50, 1, 9, c[6], 0.3);
    p.glow(60, 4, 44, c[3], 0.16);
    cycle(t, _duration, 10, s + 1, (g) => g.range(0.7, 0.95),
        (age, life, r, _) {
      final th = r.range(-sp * 0.8, sp * 0.8);
      final v = r.range(190, 260) * power;
      final (x, y) = fly(
        3,
        r.range(-1, 1),
        v * math.cos(th),
        v * math.sin(th),
        age,
        _sink,
        1.6,
      );
      final k = age / life;
      final rad = 1.5 + 8.0 * math.pow(k, 0.7);
      _puff(
        p,
        c,
        x,
        math.min(y, 40.0 - rad),
        rad,
        0.85 * math.pow(1.0 - k, 1.3) * math.min(1.0, age / 0.06),
        k,
        true,
      );
    });
    cycle(t, _duration, 18, s + 2, (g) => g.range(0.8, 1.1),
        (age, life, r, _) {
      final th = r.range(-sp * 1.1, sp * 1.1);
      final v = r.range(120, 190);
      final (x, y) = fly(
        4,
        0,
        v * math.cos(th),
        v * math.sin(th),
        age,
        _sink * 1.4,
        1.5,
      );
      final k = age / life;
      final sw = math.sin(age * 9.0 + r.range(0, tau)) * 1.5;
      if (k < 0.85 || (age * 30.0).remainder(2.0) < 1.0) {
        p.px(x, y + sw, r.chance(0.5) ? kWhite : c[6]);
      }
    });
    cycle(t, _duration, 26, s + 3, (g) => g.range(0.22, 0.36),
        (age, life, r, _) {
      final th = r.range(-sp * 0.9, sp * 0.9);
      final v = r.range(280, 380);
      final (x, y) = fly(
        6,
        r.range(-2, 2),
        v * math.cos(th),
        v * math.sin(th),
        age,
        0,
        0.9,
      );
      final (vx, vy) = flyV(v * math.cos(th), v * math.sin(th), age, 0, 0.9);
      final spd = hypot(vx, vy);
      final len = 4.0 + spd * 0.03;
      final ux = vx / spd;
      final uy = vy / spd;
      final k = age / life;
      p.lineShaded(
        x - ux * len,
        y - uy * len,
        x,
        y,
        color: (u) => u > 0.8 ? kWhite : (u > 0.4 ? c[6] : c[4]),
        alpha: (u) => (u > 0.35 ? 1.0 : u / 0.35) *
            (k < 0.75 ? 1.0 : (1.0 - k) / 0.25),
      );
      p.glow(x, y, 3, c[5], 0.3 * (1.0 - k));
    });
    cycle(t, _duration, 9, s + 4, (g) => g.range(0.65, 0.9),
        (age, life, r, _) {
      final th = r.range(-sp, sp);
      final v = r.range(150, 230);
      final (x, y) = fly(
        5,
        0,
        v * math.cos(th),
        v * math.sin(th),
        age,
        _sink,
        1.1,
      );
      final k = age / life;
      final a = r.range(0, tau) + age * r.range(9, 15) * r.sign();
      final len = r.range(1.5, 2.6);
      final ca = math.cos(a);
      final sa = math.sin(a);
      if (k > 0.85 && (age * 30.0).remainder(2.0) < 1.0) return;
      p.line(x - ca * len, y - sa * len, x + ca * len, y + sa * len, c[5]);
      p.px(x + ca * len, y + sa * len, kWhite);
      final gl = math.cos(a * 2.0);
      if (gl > 0.92) {
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          p.px(x + dx, y + dy, c[6]);
        }
        p.px(x, y, kWhite);
        p.glow(x, y, 6, c[5], 0.5);
      } else {
        p.glow(x, y, 3, c[5], 0.2);
      }
    });
    for (var i = 0; i < 3; i++) {
      final len = 9.0 + 6.0 * loopNoise(ph, 1.2, s + i * 7);
      final dy = (i - 1) * 1.4;
      p.lineShaded(
        2,
        dy * 0.5,
        2.0 + len,
        dy,
        color: (u) => u < 0.5 ? kWhite : c[6],
        alpha: (u) => u < 0.6 ? 1.0 : 1.0 - (u - 0.6) / 0.4,
      );
    }
    p.ellipse(2.5, 0, 4.6, 3, c[6]);
    p.ellipse(2, 0, 3, 1.8, kWhite);
    final fl = 0.85 + 0.15 * math.sin(ph * tau * 3.0);
    p.glow(2, 0, 24, c[5], 0.7 * fl);
    p.glow(2, 0, 9, kWhite, 0.5 * fl);
  },
);
