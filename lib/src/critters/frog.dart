import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'critters_lib.dart';

const double _duration = 2.6;
final CritterGrid _grid = CritterGrid(-22, -40, 44, 44);
final Swarm _swarm = Swarm();

const double _tCrouch = 0.95;
const double _tUp = 1.2;
const double _tLand = 1.62;
const double _tSnap = 1.4;
const double _tBack = 1.95;
const double _g = 1000.0;
const double _hop = (_g * (_tLand - _tUp) * (_tLand - _tUp)) / 8.0;

final List<int> _eye = ['#3a2a08', '#c89420', '#ffd860'].map(hex).toList();
final int _tongue = hex('#e8607a');
final int _flyCol = hex('#141018');
final int _wings = hex('#c8d0e0');
final int _dust = hex('#8a7f92');
final int _gritA = hex('#6a6074');
final int _gritB = hex('#9a90a4');

({
  double by,
  double rot,
  double sq,
  double leg,
  double throat,
  double shut,
  bool air,
}) _pose(double t) {
  var by = 0.0;
  var rot = 0.0;
  var sq = 0.0;
  var leg = 0.0;
  var throat = 0.0;
  var shut = 0.0;
  final age = wrap(t - _tLand, _duration);
  for (final (a, b) in const [(0.05, 0.45), (0.5, 0.85), (1.75, 1.95)]) {
    if (t > a && t < b) {
      throat = math.pow(math.sin(math.pi * ((t - a) / (b - a))), 0.7) *
          (a > 1.0 ? 0.6 : 1.0);
    }
  }
  if (t > 0.88 && t < 0.95) shut = 1.0;
  if (t >= _tCrouch && t < _tUp) {
    final u = Ease.inOutSine(seg(t, _tCrouch, _tUp));
    sq = -0.18 * u;
    rot = -0.12 * u;
  } else if (t >= _tUp && t < _tLand) {
    final q = (t - _tUp) / (_tLand - _tUp);
    by = -_hop * 4.0 * q * (1.0 - q);
    rot = lerp(0.42, -0.25, q);
    sq = lerp(0.18, 0.02, math.min(1.0, q * 2.0));
    leg = q < 0.75 ? 1.0 : 1.0 - (q - 0.75) / 0.25;
  } else {
    sq = -0.24 * spring(age, 2.4, 6.5);
    rot = -0.08 * math.exp(-age * 6.0);
  }
  return (
    by: by,
    rot: rot,
    sq: sq,
    leg: leg,
    throat: throat,
    shut: shut,
    air: t >= _tUp && t < _tLand,
  );
}

(double, double)? _flyPos(double t) {
  if (t > _tSnap && t < _tBack) return null;
  final a = (t / _duration) * tau * 3.0;
  final homeX = 16.0 + 6.0 * math.sin(a);
  final homeY = -40.0 + 3.0 * math.sin(2.0 * a);
  final inn = wrap(t - _tBack, _duration);
  if (inn < 0.45) {
    final u = Ease.outCubic(inn / 0.45);
    return (
      lerp(-52.0, homeX, u),
      lerp(-46.0, homeY, u) + math.sin(inn * 30.0) * 1.5,
    );
  }
  return (homeX, homeY);
}

void _frog(
  CritterGrid g,
  List<int> c,
  List<int> bl,
  ({
    double by,
    double rot,
    double sq,
    double leg,
    double throat,
    double shut,
    bool air,
  }) pz,
) {
  g.clear();
  final cs = math.cos(pz.rot);
  final sn = math.sin(pz.rot);
  final sx = 1.0 + pz.sq * -0.6;
  final sy = 1.0 + pz.sq;
  (double, double) local(double x, double y) {
    final dx = x;
    final dy = y + 7.0;
    return ((dx * cs + dy * sn) / sx, (-dx * sn + dy * cs) / sy - 7.0);
  }

  bool inBody(double x, double y) {
    final bx = (x + 1.0) / 10.5;
    final by = (y + 7.0) / 6.0;
    final hx = (x - 6.0) / 6.2;
    final hy = (y + 8.6) / 4.8;
    return bx * bx + by * by <= 1.0 || hx * hx + hy * hy <= 1.0;
  }

  bool inEye(double x, double y) {
    final dx = x - 5.5;
    final dy = y + 13.2;
    return dx * dx + dy * dy <= 3.2 * 3.2;
  }

  bool lit(double x, double y, double k) =>
      inBody(-4.0 + (x + 4.0) / k, -13.0 + (y + 13.0) / k);

  g.shade(-15, -22, 15, 1, (x, y, _) {
    final (u, v) = local(x, y);
    if (!inBody(u, v) && !inEye(u, v)) return 0;
    if (inEye(u, v)) {
      final d = hypot(u - 5.5, v + 13.2);
      if (pz.shut > 0.0) return v < -13.2 ? c[4] : c[3];
      if ((v + 13.0).abs() < 0.7 && (u - 6.0).abs() < 1.8) return c[0];
      if (u < 4.7 && v < -14.0) return _eye[2];
      return d < 2.4 ? _eye[1] : _eye[0];
    }
    if (v > -5.0 && u > -6.0) return v > -3.0 ? bl[1] : bl[2];
    for (final (px, py, r) in const [
      (-5.0, -10.0, 1.6),
      (0.0, -11.5, 1.3),
      (-8.0, -7.0, 1.2),
      (3.0, -12.5, 0.9),
    ]) {
      if (hypot(u - px, v - py) < r) return c[2];
    }
    if (!inBody(u + 2.0, v + 2.4)) return c[2];
    return lit(u, v, 0.5) ? c[5] : (lit(u, v, 0.8) ? c[4] : c[3]);
  });

  final legs = <List<(double, double)>>[];
  if (pz.leg < 0.5) {
    g.ellipse(
      -7.5,
      -4.5 + (1.0 - sy) * 3.0,
      5,
      3.6,
      (nx, ny) => (nx * -0.6 + ny * -0.8 > 0.35)
          ? c[4]
          : (ny > 0.4 ? c[2] : c[3]),
    );
    legs.add(const [(-4, -1.5), (-9, -1), (-3, -0.5), (4, -0.5)]);
  } else {
    final ex = -8.0 - 10.0 * pz.leg;
    final ey = 4.0 + 6.0 * pz.leg;
    legs.add([(-6, -5), (-10, 0), (ex, ey), (ex - 5.0, ey + 2.0)]);
  }

  for (final l in legs) {
    g.tube(
      l,
      (u) => lerp(2.0, 0.7, u),
      (u, v) => v > 0.55 ? c[2] : (u > 0.66 ? c[3] : c[4]),
    );
    final (fx, fy) = l[l.length - 1];
    final (px, py) = l[l.length - 2];
    final dx = fx - px;
    final dy = fy - py;
    final lenRaw = hypot(dx, dy);
    final len = lenRaw == 0.0 ? 1.0 : lenRaw;
    for (final k in const [-1, 0, 1]) {
      g.line(
        fx,
        fy,
        fx + (dx / len) * 2.0 - (dy / len) * k * 1.6,
        fy + (dy / len) * 2.0 + (dx / len) * k * 1.6,
        c[3],
      );
    }
  }

  if (pz.shut == 0.0) {
    const gx = 4.6;
    const gy = -14.4;
    final x = gx * cs - (gy + 7.0) * sn;
    final y = gx * sn + (gy + 7.0) * cs - 7.0;
    g.set(x, y, c[6]);
  }
  for (var u = 3; u <= 11; u++) {
    final v = -7.8 + (u - 3) * 0.05;
    final x = (u * sx) * cs - ((v + 7.0) * sy) * sn;
    final y = (u * sx) * sn + ((v + 7.0) * sy) * cs - 7.0;
    g.set(x, y, c[1]);
  }

  final fl = pz.air
      ? const [(7.0, -4.0), (9.0, -1.0)]
      : const [(7.0, -4.0), (8.0, -0.5)];
  g.line(fl[0].$1, fl[0].$2, fl[1].$1, fl[1].$2, c[3]);
  g.set(fl[1].$1 + 1.0, fl[1].$2, c[3]);
  g.set(fl[1].$1 - 1.0, fl[1].$2, c[3]);

  if (pz.throat > 0.05) {
    final r = 0.8 + 2.8 * pz.throat;
    const cx = 7.0;
    final cy = -5.2 + r * 0.25;
    g.ellipse(
      cx,
      cy,
      r * 1.1,
      r,
      (nx, ny) => (nx * -0.6 + ny * -0.8 > 0.55)
          ? bl[2]
          : (ny > 0.5 ? bl[1] : mix(bl[2], c[5], 0.4)),
      0.9,
    );
    g.set(cx - r * 0.4, cy - r * 0.45, c[6]);
  }
  g.outline(c[0]);
}

final PureEffect frogEffect = PureEffect(
  meta: const EffectMeta(
    id: 'critters/frog',
    name: 'Frog',
    desc:
        'A frog puffs its throat, blinks, crouches and leaps to snap a buzzing fly out of the air, then lands with a squash and a puff of dust, gulps and settles.',
    category: 'critters',
    tags: ['critter', 'frog', 'animal', 'hop', 'ground', 'loop'],
    size: (112, 88),
    origin: (56, 80),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#0a160c',
        '#173a18',
        '#256024',
        '#3a8a2e',
        '#62b440',
        '#a8e070',
        '#e8ffc0',
      ],
      'belly': ['#5e5a24', '#bdb45a', '#efe9a8'],
      'seed': 1,
    },
  ),
  onDrawBack: (p, time, o) {
    final t = shift(time, _duration, o.seed);
    final c = fit(o.palette, 7);
    final pz = _pose(t);
    final hgt = clamp(-pz.by / _hop);
    shadow(p, 0, -0.2, 13.0 * (1.0 - 0.35 * hgt), 1.6, c[0], 0.6 - 0.3 * hgt);
  },
  onDraw: (p, time, o) {
    final seed = o.seed;
    final t = shift(time, _duration, seed);
    final c = fit(o.palette, 7);
    final bl = fit(o.rampOpt('belly'), 3);
    final pz = _pose(t);

    final g = _grid;
    _frog(g, c, bl, pz);
    g.draw(p, 1.0, 0.0, roundJs(pz.by).toDouble());

    final ts = (t - _tSnap + 0.06) / 0.14;
    if (ts > 0.0 && ts < 1.0) {
      final f = _flyPos(_tSnap - 0.001)!;
      final e = math.sin(math.pi * ts);
      const mx = 11.0;
      final my = pz.by - 8.0;
      final x1 = lerp(mx, f.$1, e);
      final y1 = lerp(my, f.$2, e);
      p.line(mx, my, x1, y1, _tongue);
      p.line(mx, my + 1.0, x1, y1 + 1.0, mix(_tongue, c[0], 0.4));
      p.circle(x1, y1, 1.4, _tongue);
    }

    final f = _flyPos(t);
    if (f != null) {
      final flap = math.sin(t * 90.0) > 0.0;
      p.px(f.$1, f.$2, _flyCol);
      p.px(f.$1 + 1.0, f.$2, _flyCol);
      p.dot(f.$1, f.$2 - (flap ? 1.0 : 0.0), _wings, 0.8);
      p.dot(f.$1 + 1.0, f.$2 - (flap ? 0.0 : 1.0), _wings, 0.8);
      p.glow(f.$1, f.$2, 3, _wings, 0.15);
    }

    final sw = _swarm.begin(t);
    for (final (t0, n, pow) in const [(_tUp, 7, 0.6), (_tLand, 18, 1.0)]) {
      final age = wrap(t - t0, _duration);
      final tKey = roundJs(t0 * 100.0);
      for (var i = 0; i < n; i++) {
        final r = rng(seed, i, tKey);
        final len = r.range(0.6, 1.1) * pow;
        if (age > len) continue;
        final s = r.sign();
        final v = r.range(24.0, 70.0) * pow;
        final x = s * (7.0 + (v / 3.5) * (1.0 - math.exp(-age * 3.5)));
        final y = -1.5 - r.range(1.0, 5.0) * age;
        sw.add(
          P.smoke,
          x,
          y,
          0,
          0,
          age,
          len,
          _dust,
          r.range(2.2, 4.2) * (0.65 + 0.35 * pow),
          2,
        );
      }
      if (pow == 1.0) {
        for (var i = 0; i < 8; i++) {
          final r = rng(seed, i, 909);
          final b = toss(
            r.range(-8.0, 8.0),
            -1.0,
            r.range(-40.0, 40.0),
            -r.range(30.0, 70.0),
            age,
            700.0,
            -0.5,
          );
          if (age < 0.7) {
            p.dot(
              b.x,
              b.y,
              i.isOdd ? _gritA : _gritB,
              b.landed ? 1.4 - age * 2.0 : 1.0,
            );
          }
        }
      }
    }
    sw.draw(p);
  },
);
