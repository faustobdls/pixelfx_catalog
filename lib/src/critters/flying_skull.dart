import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'critters_lib.dart';

const double _duration = 2.4;
final CritterGrid _grid = CritterGrid(-14, -20, 28, 40);
final int _socket = hex('#120a0c');
final int _smokeBase = hex('#5b5566');
final int _shadowBg = hex('#0d0a12');
final Swarm _swarm = Swarm();

({double x, double y, double vx, double vy}) _at(double t, double hover) {
  final a = (t / _duration) * tau;
  return (
    x: 3.0 * math.sin(a),
    y: -hover + 3.0 * math.sin(2.0 * a + 0.5),
    vx: (3.0 * tau * math.cos(a)) / _duration,
    vy: (6.0 * tau * math.cos(2.0 * a + 0.5)) / _duration,
  );
}

double _burst(double t, double a, double b) => (t <= a || t >= b)
    ? 0.0
    : math.sqrt(math.sin(math.pi * ((t - a) / (b - a))));

int _jaw(double t) {
  final ch = math.max(0.0, math.sin((t / _duration) * tau * 22.0));
  final b1 = _burst(t, 0.15, 0.75);
  final b2 = _burst(t, 1.3, 1.95);
  final gape = _burst(t, 1.95, 2.3);
  return roundJs(math.max(ch * 2.4 * math.max(b1, b2), gape * 3.4));
}

double _flick(double t) =>
    0.74 + 0.16 * lnoise(t, _duration, 18, 0, 1) + 0.1 * lnoise(t, _duration, 46, 0, 2);

bool _inCranium(double x, double y) =>
    (x / 11.0) * (x / 11.0) + ((y + 6.0) / 10.5) * ((y + 6.0) / 10.5) <= 1.0;

bool _inFace(double x, double y) =>
    y >= -3.0 &&
    y <= 6.5 &&
    x.abs() <= lerp(10.2, 7.2, (y + 3.0) / 9.5);

bool _inSkull(double x, double y) => _inCranium(x, y) || _inFace(x, y);

double _browY(double x) => -6.6 + (8.5 - x.abs()) * 0.3;

bool _inSocket(double x, double y) {
  final sx = (x.abs() - 5.1) / 3.3;
  final sy = (y + 2.9) / 3.3;
  return sx * sx + sy * sy <= 1.0 && y > _browY(x);
}

const List<(int, int)> _nose = [
  (-1, 1), (0, 1), (-2, 2), (-1, 2), (0, 2), (1, 2), (-2, 3), (1, 3),
];
const List<(int, int)> _crack = [
  (4, -16), (4, -15), (5, -14), (5, -13), (4, -12), (5, -11), (6, -10), (6, -9),
];

double _topY(double x) =>
    -6.0 - 10.5 * math.sqrt(math.max(0.0, 1.0 - (x / 11.0) * (x / 11.0)));

bool _inJaw(double x, double y, double jy) {
  final v = y - jy;
  final hw = 7.4 - v * 0.45 - (v > 4.0 ? (v - 4.0) * 1.2 : 0.0);
  return v >= 0.0 && v <= 5.5 && x.abs() <= hw;
}

void _skull(CritterGrid g, List<int> b, List<int> f, int open, double t) {
  final warm = mix(b[6], f[6], 0.45);
  final rim = mix(b[5], f[5], 0.3);
  const lx = -4.0;
  const ly = -15.0;
  bool lit(double x, double y, double k) =>
      _inSkull(lx + (x - lx) / k, ly + (y - ly) / k);

  g.clear();
  g.shade(-12, -17, 12, 8, (x, y, _) {
    if (!_inSkull(x, y)) return 0;
    var c = lit(x, y, 0.45) ? b[5] : (lit(x, y, 0.74) ? b[4] : b[3]);
    if (x.abs() > 8.2 && y > -7.0 && y < -1.0) c = x < 0.0 ? b[3] : b[2];
    if (!_inSkull(x + 2.0, y + 2.2) || (x > 0.0 && !_inSkull(x + 2.6, y))) {
      c = b[2];
    }
    if (!_inSkull(x + 1.0, y + 1.2) && y > 2.0) c = b[1];
    if (!_inSkull(x, y - 1.5)) {
      c = x.abs() < 7.0 ? warm : rim;
    } else if (!_inSkull(x, y - 2.5) && x.abs() < 6.0) {
      c = rim;
    }
    final by = _browY(x);
    if (y > by - 1.2 && y < by + 0.4 && x.abs() > 1.6 && x.abs() < 8.6) {
      c = x < 0.0 ? b[4] : b[3];
    }
    if (x.abs() > 6.2 && x.abs() < 9.2 && y > 0.0 && y < 2.0) {
      c = x < 0.0 ? b[5] : b[3];
    }
    if (y > 6.0) {
      if (x.abs() > 6.4) return 0;
      final cx = x.floor();
      final gap = cx == -6 || cx == -3 || cx == 2 || cx == 5;
      c = gap
          ? b[1]
          : (y < 7.0
              ? (x < 0.0 ? b[5] : b[4])
              : ((cx == -1 || cx == 0) ? b[3] : b[4]));
    }
    return c;
  });

  g.shade(-9, -7, 9, 1, (x, y, _) {
    if (!_inSocket(x, y)) return 0;
    if (!_inSocket(x, y + 1.3)) return mix(b[2], f[4], 0.55);
    return _socket;
  });

  for (final (x, y) in _nose) {
    g.set(x, y, y == 3 ? b[1] : _socket);
  }
  g.set(-1, 3, b[2]);
  g.set(0, 3, b[2]);
  for (final (x, y) in _crack) {
    g.set(x, y, b[1]);
    g.set(x - 1, y, b[5]);
  }
  g.set(7, -7, b[1]);
  g.set(8, -6, b[1]);

  final jy = 8.0 + open;
  g.shade(-8, 4, 8, jy + 6.0, (x, y, _) {
    final ax = x.abs();
    if (ax > 6.6 && ax < 8.1 && y > 4.0 && y < jy + 2.0) {
      return x < 0.0 ? b[3] : b[2];
    }
    if (y < jy || y > jy + 5.5) return 0;
    final v = y - jy;
    final hw = 7.4 - v * 0.45 - (v > 4.0 ? (v - 4.0) * 1.2 : 0.0);
    if (ax > hw) return 0;
    if (v < 1.5) {
      if (ax > 6.0) return x < 0.0 ? b[4] : b[3];
      final cx = x.floor();
      final gap = cx == -5 || cx == -2 || cx == 1 || cx == 4;
      return gap ? b[1] : (v < 1.0 ? b[5] : b[4]);
    }
    if (!_inJaw(x + 1.6, y + 1.6, jy)) return b[1];
    return (v < 2.5 && x < 0.0) ? b[4] : b[3];
  });

  if (open > 0) {
    final jyInt = jy.toInt();
    for (var y = 8; y < jyInt; y++) {
      for (var x = -6; x <= 5; x++) {
        g.set(x, y, y == jyInt - 1 ? mix(_socket, f[3], 0.5) : _socket);
      }
    }
  }
  g.outlineShaded(
    (_, _, _, ny) => ny < 0 ? mix(b[0], f[1], 0.75) : b[0],
  );
}

class _CrownTongue {
  final double x;
  final double? y;
  final double h;
  final double w;
  final double n;
  final bool front;

  const _CrownTongue({
    required this.x,
    this.y,
    required this.h,
    required this.w,
    required this.n,
    required this.front,
  });
}

List<_CrownTongue> _crown(int seed) {
  final out = <_CrownTongue>[];
  for (var x = -10; x <= 10; x += 2) {
    out.add(
      _CrownTongue(
        x: x.toDouble(),
        h: 13.0 + 13.0 * (1.0 - (x / 11.0) * (x / 11.0)),
        w: 2.3 + rand(x + 20, seed, 3) * 0.8,
        n: (37 + x * 3 + seed * 11).toDouble(),
        front: false,
      ),
    );
  }
  for (final s in const [-1, 1]) {
    out.add(
      _CrownTongue(
        x: s * 11.0,
        y: -5.0,
        h: 10.0,
        w: 1.8,
        n: (61 + s * 13 + seed * 5).toDouble(),
        front: false,
      ),
    );
  }
  for (var x = -5.0; x <= 5.0; x += 2.5) {
    out.add(
      _CrownTongue(
        x: x,
        h: 5.0 + 3.0 * rand(roundJs(x * 4.0) + 20, seed, 5),
        w: 1.6,
        n: 91.0 + x * 5.0 + seed * 7.0,
        front: true,
      ),
    );
  }
  return out;
}

double _tongueHeight(_CrownTongue f, double t, double k) {
  final leap =
      math.max(0.0, lnoise(t, _duration, 6, f.n * 3.1, 70) - 0.55) * 1.6;
  return (f.h + 0.25 * f.h * lnoise(t, _duration, 8, f.n * 1.7, 5) + f.h * leap) *
      (0.9 + 0.1 * k);
}

void _particles(
  Painter p,
  double t,
  int seed,
  double hover,
  bool floor,
  List<int> heat,
  List<int> f,
  bool back,
) {
  final sw = _swarm.begin(t);
  sw.setSparks([f[7], f[6], f[4], f[2]]);
  if (back) {
    cycle(t, _duration, 15, seed * 7 + 1, (r) => r.range(1.7, 2.5),
        (age, len, r, _) {
      final s0 = _at(wrap(t - age, _duration), hover);
      final x0 = s0.x + r.range(-6.0, 6.0);
      final y0 = s0.y - 22.0 - r.range(0.0, 8.0);
      final (x, y) = fly(x0, y0, r.range(-5.0, 5.0), -r.range(16.0, 26.0), age, -12.0, 1.2);
      sw.add(
        P.smoke,
        x + math.sin(age * 1.3 + r.next() * 6.0) * 3.0 * age,
        y,
        0,
        0,
        age,
        len,
        mix(_smokeBase, f[2], 0.3),
        r.range(2.8, 4.4),
        PF.big,
      );
    });
    sw.draw(p);
    return;
  }

  cycle(t, _duration, 40, seed * 7 + 2, (r) => r.range(0.18, 0.36),
      (age, len, r, _) {
    final s0 = _at(wrap(t - age, _duration), hover);
    final side = r.chance(0.3);
    final a = side ? r.sign() * r.range(0.9, 1.45) : r.range(-0.8, 0.8);
    final x0 = s0.x + math.sin(a) * 10.5;
    final y0 = s0.y - 6.0 - math.cos(a) * 10.0 - (side ? 0.0 : r.range(2.0, 10.0));
    final (x, y) = fly(
      x0,
      y0,
      r.range(-6.0, 6.0) + math.sin(a) * 6.0,
      -r.range(18.0, 34.0),
      age,
      -95.0,
      3.2,
    );
    firePuff(
      p,
      x + math.sin(age * 17.0 + r.next() * 6.0) * 0.8,
      y,
      1.0 - age / len,
      r.range(1.0, 2.2),
      r.next() * 100.0,
      heat,
    );
  });

  cycle(t, _duration, 18, seed * 7 + 3, (_) => 0.26, (age, len, r, _) {
    final s0 = _at(wrap(t - age, _duration), hover);
    final fx = r.range(-10.0, 10.0);
    final x0 = s0.x + fx;
    final y0 = s0.y + _topY(fx) - r.range(4.0, 16.0) * (1.0 - fx.abs() / 14.0);
    final kk = 1.0 - age / len;
    final x = x0 + r.range(-3.0, 3.0) * age;
    final y = y0 - r.range(12.0, 20.0) * age;
    final rr = r.range(0.9, 1.7) * (0.4 + 0.6 * kk);
    p.circle(x, y, rr + 0.6, kk > 0.5 ? heat[5] : heat[6]);
    if (kk > 0.35) {
      p.circle(x, y - 0.3, rr * 0.6, kk > 0.7 ? heat[2] : heat[4]);
    }
  });

  cycle(t, _duration, 24, seed * 7 + 4, (r) => r.range(1.0, 2.4),
      (age, len, r, _) {
    final s0 = _at(wrap(t - age, _duration), hover);
    final x0 = s0.x + r.range(-11.0, 11.0);
    final y0 = s0.y - r.range(6.0, 24.0);
    final s = r.next() * 100.0;
    final (x, y) = fly(x0, y0, r.range(-22.0, 22.0), -r.range(25.0, 70.0), age, -20.0, 1.6);
    sw.add(
      P.ember,
      x + math.sin(age * 2.3 + s) * 4.0 * math.min(1.0, age),
      y,
      0,
      0,
      age,
      len,
      f[4],
      r.chance(0.3) ? 2.0 : 1.0,
      0,
      s,
    );
  });

  if (floor) {
    cycle(t, _duration, 5, seed * 7 + 5, (r) => r.range(0.9, 1.4),
        (age, len, r, _) {
      final s0 = _at(wrap(t - age, _duration), hover);
      final b = bounce(
        s0.x + r.range(-6.0, 6.0),
        s0.y - r.range(10.0, 18.0),
        r.range(-28.0, 28.0),
        -r.range(50.0, 110.0),
        age,
        430.0,
        -0.5,
        0.42,
      );
      sw.add(
        P.spark,
        b.x,
        b.y,
        b.rest ? 0.1 : b.vx,
        b.rest ? 0.0 : b.vy,
        age,
        len,
        0,
        1.0,
        0,
        r.next() * 100.0,
      );
    });
  }
  sw.draw(p);
}

final PureEffect flyingSkullEffect = PureEffect(
  meta: const EffectMeta(
    id: 'critters/flying-skull',
    name: 'Flying skull',
    desc:
        'A cracked bone skull bobs in the air, jaw chattering, eyes burning, a fire roaring off its crown that sheds flame puffs, embers and smoke and throws warm light.',
    category: 'critters',
    tags: ['critter', 'skull', 'undead', 'fire', 'flying', 'monster', 'loop'],
    size: (96, 132),
    origin: (48, 120),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#4a1712',
        '#8a1f17',
        '#c9281f',
        '#f2561d',
        '#ff8a2a',
        '#ffc23d',
        '#ffe26b',
        '#fff3a6',
        '#ffffff',
      ],
      'bone': [
        '#1a1114',
        '#3e2b2a',
        '#6b5144',
        '#9e8467',
        '#cdb892',
        '#efe2bf',
        '#fffaea',
      ],
      'hover': 40,
      'floor': true,
      'seed': 1,
    },
  ),
  onDrawBack: (p, time, o) {
    if (!o.boolOpt('floor', true)) return;
    final t = shift(time, _duration, o.seed);
    final f = fit(o.palette, 9);
    final s = _at(t, o.numOpt('hover', 40.0));
    final k = _flick(t);
    shadow(p, s.x, 0, 9, 1.6, _shadowBg, 0.6);
    final col = mix(f[4], f[5], 0.5);
    for (var x = -30; x <= 30; x += 6) {
      p.glow(s.x + x, -1, 20, col, 0.15 * k * (1.0 - x.abs() / 40.0));
    }
  },
  onDraw: (p, time, o) {
    final seed = o.seed;
    final hover = o.numOpt('hover', 40.0);
    final floor = o.boolOpt('floor', true);
    final t = shift(time, _duration, seed);
    final f = fit(o.palette, 9);
    final heat = f.reversed.toList(growable: false);
    final b = fit(o.rampOpt('bone'), 7);
    final s = _at(t, hover);
    final k = _flick(t);
    final lean = clamp(-s.vx / 60.0, -0.8, 0.8);
    final stretch = clamp(s.vy / 90.0, -0.3, 0.45);
    final tongues = _crown(seed)
      ..sort((a, bb) => bb.x.abs().compareTo(a.x.abs()));
    final x = roundJs(s.x);
    final y = roundJs(s.y);
    double lick(_CrownTongue tg) =>
        lnoise(t, _duration, 5, tg.n, 40) * 2.0 +
        lean * _tongueHeight(tg, t, k) * 0.9 -
        clamp(tg.x * 0.25, -2.0, 2.0);

    for (var li = 0; li < 4; li++) {
      for (final tg in tongues) {
        if (!tg.front) {
          tongue(
            p,
            x + tg.x,
            y + (tg.y ?? (_topY(tg.x) + 3.0)),
            _tongueHeight(tg, t, k) * (1.0 + stretch),
            tg.w * (1.0 - 0.25 * lean.abs()),
            lick(tg),
            t,
            _duration,
            tg.n,
            heat,
            li,
          );
        }
      }
    }

    _particles(p, t, seed, hover, floor, heat, f, true);

    final open = _jaw(t);
    final g = _grid;
    _skull(g, b, f, open, t);
    g.draw(p, 1.0, x.toDouble(), y.toDouble());

    for (final side in const [-1, 1]) {
      final ex = x + side * 5.1 - 0.5;
      final ey = y - 2.4;
      final fl = 0.75 + 0.25 * lnoise(t, _duration, 30, side * 9.0, 12);
      p.px(ex, ey, heat[0]);
      p.px(ex + 1.0, ey, heat[1]);
      p.px(ex, ey + 1.0, heat[2]);
      p.px(ex + 1.0, ey + 1.0, heat[3]);
      if (fl > 0.8) {
        p.px(ex, ey - 1.0, heat[3]);
        p.px(ex + 1.0, ey - 1.0, heat[5]);
      }
      p.glow(ex + 1.0, ey + 1.0, 6, f[5], 0.45 * fl);
      p.glow(ex + 1.0, ey + 0.5, 3, f[7], 0.5 * fl);
    }

    if (open > 0) {
      p.glow(x, y + 8.0 + open * 0.5, 4.0 + open * 2.0, f[5], 0.25 * open);
    }

    for (var i = 0; i < 9; i++) {
      final r = rng(seed, i, 21);
      final born = 1.98 + i * 0.03;
      final age = wrap(t - born, _duration);
      final len = r.range(0.25, 0.45);
      if (age >= len) continue;
      final s0 = _at(born, hover);
      final (px, py) = fly(
        s0.x + r.range(-3.0, 3.0),
        s0.y + 11.0,
        r.range(-22.0, 22.0),
        r.range(40.0, 75.0),
        age,
        -70.0,
        3.5,
      );
      firePuff(p, px, py, 1.0 - age / len, r.range(1.1, 2.0), r.next() * 100.0, heat);
    }

    for (var li = 0; li < 4; li++) {
      for (final tg in tongues) {
        if (tg.front) {
          tongue(
            p,
            x + tg.x,
            y + _topY(tg.x) + 1.5,
            _tongueHeight(tg, t, k) * (1.0 + stretch),
            tg.w,
            lick(tg) * 0.6,
            t,
            _duration,
            tg.n,
            heat,
            li,
          );
        }
      }
    }

    _particles(p, t, seed, hover, floor, heat, f, false);

    final br = 0.92 + 0.08 * math.sin((t / _duration) * tau * 2.0);
    p.glow(
      x + lean * 4.0,
      y - 20.0,
      74.0 * br * (0.9 + 0.1 * k),
      mix(f[4], f[5], 0.5),
      0.48 * k,
    );
    p.glow(x, y - 21.0, 24, f[6], 0.3 * k);
    p.glow(x, y - 15.0, 9, f[8], 0.16 * k);
  },
);
