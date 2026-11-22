// The puddle (a domed wet surface with glints sliding along it, bubbles that swell and pop) is adapted from
// Sprite Fusion's open-source poison puddle (https://www.spritefusion.com/pixel-art-vfx/poison),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'critters_lib.dart';

const double _duration = 1.8;
const double _tSq = 0.5;
const double _tUp = 0.84;
const double _tLift = 0.9;
const double _tLand = 1.44;
const double _snap = 0.965;
const double _w0 = 30.0;
const double _h0 = 22.0;
const double _vc = 0.4;
const double _g = 640.0;
const int _ndrop = 12;
const double _pop = 0.4;
const List<(double, double)> _drips = [(1.02, -4.0), (1.18, 3.0)];

final CritterGrid _slimeGrid = CritterGrid(-30, -64, 60, 66);

class _SlimePose {
  final double s;
  final double by;
  final double lean;
  final double round;
  final double q;
  final double age;
  final double w;
  final double h;

  const _SlimePose({
    required this.s,
    required this.by,
    required this.lean,
    required this.round,
    required this.q,
    required this.age,
    required this.w,
    required this.h,
  });
}

_SlimePose _pose(double t, double hop) {
  final age = wrap(t - _tLand, _duration);
  double s;
  var by = 0.0;
  var lean = 0.0;
  var round = 0.1;
  var q = -1.0;
  if (t >= _tLift && t < _tLand) {
    q = (t - _tLift) / (_tLand - _tLift);
    by = -hop * 4.0 * q * (1.0 - q);
    s = curve(q, const [
      (0.0, 0.36),
      (0.4, 0.02),
      (0.55, -0.05),
      (0.85, 0.08),
      (1.0, 0.16),
    ]);
    round = 0.1 + 0.8 * smooth(0.0, 0.16, q) * (1.0 - smooth(0.86, 1.0, q));
  } else if (t >= _tUp && t < _tLift) {
    s = lerp(-0.3, 0.36, Ease.outCubic(seg(t, _tUp, _tLift)));
  } else if (t >= _tSq && t < _tUp) {
    final u = seg(t, _tSq, _tUp);
    s = -0.3 * Ease.inOutSine(u) +
        0.018 * math.sin(t * tau * 16.0) * smooth(0.55, 1.0, u);
  } else {
    s = age < 0.06 ? -0.46 : -0.46 * spring(age - 0.06, 2.1, 4.6);
    lean = 0.07 * math.exp(-age * 4.0) * math.sin(age * tau * 1.9);
    if (t < _tSq) s += 0.02 * math.sin((t / _tSq) * tau);
  }
  return _SlimePose(
    s: s,
    by: by,
    lean: lean,
    round: round,
    q: q,
    age: age,
    w: _w0 / math.sqrt(1.0 + s),
    h: _h0 * (1.0 + s),
  );
}

double _halfW(double v, _SlimePose p) {
  if (v < 0.0 || v > 1.0) return -1.0;
  final w = p.w;
  final h = p.h;
  final round = p.round;
  if (v >= _vc) {
    final q = (v - _vc) / (1.0 - _vc);
    return (w / 2.0) * math.sqrt(1.0 - q * q);
  }
  final q = (_vc - v) / _vc;
  final hb = v * h;
  const rc = 3.0;
  var hw = (w / 2.0) * math.sqrt(math.max(0.0, 1.0 - round * q * q));
  if (hb < rc) hw -= rc - math.sqrt(rc * rc - (rc - hb) * (rc - hb));
  return hw;
}

bool _inside(_SlimePose p, double x, double y) {
  final v = (p.by - 1.0 - y) / p.h;
  final hw = _halfW(v, p);
  return hw >= 0.0 && (x - p.lean * v * p.h).abs() <= hw;
}

void _body(CritterGrid g, List<int> c, _SlimePose p) {
  final yb = p.by - 1.0;
  final half = p.w / 2.0 + 3.0;
  final cx = p.lean * 0.45 * p.h;
  final cy = yb - p.h * 0.5;
  final lx = cx - p.w * 0.24;
  final ly = cy - p.h * 0.36;
  bool lit(double x, double y, double k) =>
      _inside(p, lx + (x - lx) / k, ly + (y - ly) / k);

  g.clear();
  g.shade(-half, yb - p.h - 1.0, half, yb, (x, y, out) {
    if (!_inside(p, x, y)) return 0;
    out.t = 1;
    out.a = 0.92;
    var i = lit(x, y, 0.42) ? 5 : (lit(x, y, 0.7) ? 4 : 3);
    final v = (yb - y) / p.h;
    if (v < 0.3 && _inside(p, x, y + 1.4)) {
      i = !_inside(p, x, y + 2.4) ? 5 : (v < 0.2 ? 4 : i);
    }
    if (!_inside(p, x + 2.0, y + 2.4)) {
      i = 2;
      out.a = 1.0;
    }
    final ang = math.atan2(y - cy, (x - cx) * (p.h / p.w));
    if (!_inside(p, x - 1.6, y - 1.6) &&
        _inside(p, x - 0.7, y - 0.7) &&
        ang > -2.75 &&
        ang < -1.55) {
      i = (ang > -2.45 && ang < -1.8) ? 6 : 5;
      out.a = 1.0;
    }
    if (i == 2 &&
        _inside(p, x + 1.0, y + 1.2) &&
        !_inside(p, x + 2.0, y + 2.4) &&
        ang > 0.3 &&
        ang < 1.5) {
      i = 4;
    }
    return c[i];
  });

  final hx = (cx - p.w * 0.27).round();
  final hy = (cy - p.h * 0.14).round();
  if (_inside(p, hx - 1.0, hy.toDouble()) &&
      _inside(p, hx + 1.0, hy + 1.0)) {
    g.set(hx, hy, c[6]);
    g.set(hx, hy + 1, c[5]);
  }
}

void _face(CritterGrid g, List<int> c, _SlimePose p, double t) {
  final yb = p.by - 1.0;
  const ev = 0.47;
  final ey = (yb - p.h * ev).round();
  final ex = math.max<int>(3, (p.w * 0.16).round());
  final xc = (p.lean * ev * p.h).round();
  final air = p.q >= 0.0;
  final shut = p.age < 0.16 && !air;
  final blink = t > 0.22 && t < 0.29;
  final wind = (t >= _tSq && t < _tLift) ? seg(t, _tSq, _tUp) : 0.0;
  final look = air ? (p.q < 0.45 ? -1 : (p.q > 0.7 ? 1 : 0)) : 0;
  final eh = clampInt(
    (4.0 * (1.0 + p.s * 0.8) - wind * 2.0 + (air && p.q < 0.6 ? 1.0 : 0.0))
        .round(),
    1,
    5,
  );
  for (final side in const [-1, 1]) {
    final x = xc + side * ex - (side > 0 ? 1 : 0);
    if (shut) {
      final a = side < 0 ? 0 : 1;
      final b = 1 - a;
      g.set(x + a, ey - 1, c[0]);
      g.set(x + b, ey, c[0]);
      g.set(x + a, ey + 1, c[0]);
      continue;
    }
    if (blink) {
      g.set(x, ey + 1, c[0]);
      g.set(x + 1, ey + 1, c[0]);
      continue;
    }
    final top = ey + 2 - eh + look;
    for (var k = 0; k < eh; k++) {
      g.set(x, top + k, c[0]);
      g.set(x + 1, top + k, c[0]);
    }
    g.set(x + (look > 0 ? 1 : 0), top + (look > 0 ? 1 : 0), c[6]);
    if (eh >= 4) g.set(x + 1, top + eh - 1, c[2]);
  }
  final my = (yb - p.h * 0.31).round();
  if (air && p.q < 0.75) {
    g.set(xc, my, c[0]);
    g.set(xc - 1, my, c[0]);
    g.set(xc, my + 1, c[1]);
    g.set(xc - 1, my + 1, c[1]);
  } else if (!shut) {
    g.set(xc, my, c[1]);
    g.set(xc - 1, my, c[1]);
  }
}

void _bubbleIn(CritterGrid g, List<int> c, _SlimePose p, double t) {
  if (t > _pop) return;
  final v = lerp(0.18, 0.86, Ease.inQuad(t / _pop));
  final hw = _halfW(v, p);
  final x = p.lean * v * p.h - hw * lerp(0.35, 0.05, t / _pop);
  final y = p.by - 1.0 - v * p.h;
  g.set(x, y, c[6]);
  g.set(x + 1, y, c[5]);
  g.set(x, y + 1, c[5]);
  g.set(x + 1, y + 1, c[4]);
}

TossResult _droplet(int i, int seed, double age) {
  final r = rng(seed, i, 7);
  final a = -math.pi / 2.0 + r.range(-1.2, 1.2);
  final sp = r.range(60.0, 118.0);
  final size = r.chance(0.35) ? 1 : (r.chance(0.7) ? 2 : 3);
  final fa = a + math.pi / 2.0;
  final x0 = math.sin(fa) * 21.0;
  final y0 = -1.0 - math.cos(fa) * 12.5;
  final f = toss(x0, y0, math.cos(a) * sp * 0.75, math.sin(a) * sp, age, _g, -1.0);
  f.size = size;
  if (f.landed) {
    final home = (f.lx == 0.0 ? 1.0 : f.lx.sign) * (_w0 / 2.0 - 2.0);
    final dur = math.min(0.55, 0.22 + (f.lx - home).abs() / 60.0);
    final u = seg(age - f.at - 0.14, 0.0, dur);
    f.x = lerp(f.lx, home, Ease.inOutSine(u));
    f.k = 1.0 - u;
    f.gone = u >= 1.0;
    f.splat = clamp(1.0 - (age - f.at) / 0.14);
  }
  return f;
}

double _puddleR(double t, _SlimePose p) {
  if (p.q >= 0.0) {
    return (_w0 / math.sqrt(1.36) / 2.0 + 3.0) * (1.0 - 0.22 * p.q);
  }
  return p.w / 2.0 +
      3.0 +
      9.0 *
          math.exp(-p.age * 5.0) *
          (1.0 - math.exp(-p.age * 40.0)) *
          ((t >= _tLand || t < _tSq) ? 1.0 : 0.0);
}

final PureEffect slimeEffect = PureEffect(
  meta: const EffectMeta(
    id: 'critters/slime',
    name: 'Slime',
    desc:
        'A glossy slime hops in place: it squashes to wind up, stretches into the jump, rounds out in the air, splats down flinging droplets that creep back, then wobbles and blinks.',
    category: 'critters',
    tags: ['critter', 'slime', 'monster', 'hop', 'goo', 'loop'],
    size: (112, 88),
    origin: (56, 72),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#061412',
        '#0b2f2b',
        '#12594a',
        '#1f8f4f',
        '#47c752',
        '#a6f06a',
        '#f0ffd2',
      ],
      'hop': 24,
      'seed': 1,
    },
  ),
  onDrawBack: (p, time, o) {
    final seed = o.seed;
    final hop = o.numOpt('hop', 24.0);
    final t = shift(time, _duration, seed);
    final c = fit(o.palette, 7);
    final pose = _pose(t, hop);
    final age = pose.age;

    final r = _puddleR(t, pose);
    final hp = math.min(2.4, 0.9 + r * 0.06);
    final xEnd = r.ceil();
    for (var x = (-r).floor(); x <= xEnd; x++) {
      final d = (x + 0.5).abs() / r;
      if (d > 1.0) continue;
      final top = -1 - (math.sqrt(1.0 - d * d) * hp).round();
      for (var y = top; y <= 0; y++) {
        var col = y == top ? c[5] : (y == 0 ? c[2] : c[4]);
        if (d > 0.88) col = y == top ? c[4] : c[3];
        if (y == top && d < 0.88) {
          final n = lnoise(t, _duration, 7, x * 0.18, 3) +
              lnoise(t, _duration, 4, x * 0.07, 4) * 0.6;
          if (n > 0.55) col = c[6];
        } else if (y == top + 1 &&
            d < 0.8 &&
            lnoise(t, _duration, 3, x * 0.12, 5) > 0.3) {
          col = c[5];
        }
        p.px(x, y, col);
      }
      if (d > 0.96) p.px(x, top - 1, c[1]);
    }

    cycle(t, _duration, 4, seed * 17 + 3, (rv) => rv.range(0.45, 0.75),
        (ag, len, rv, _) {
      final x = rv.range(-0.85, 0.85) * r;
      final k = ag / len;
      final rb = rv.range(1.4, 2.6) *
          (0.3 + 0.7 * Ease.outCubic(math.min(1.0, k * 1.25)));
      if (x.abs() < pose.w / 2.0 + 1.0 && pose.q < 0.0) return;
      final sy = -1 -
          (math.sqrt(math.max(0.0, 1.0 - (x / r) * (x / r))) * hp).round();
      if (k < 0.85) {
        final yEnd = sy;
        final xxStart = (x - rb - 1.0).floor();
        final xxEnd = (x + rb + 1.0).ceil();
        for (var y = (sy - rb).floor(); y <= yEnd; y++) {
          for (var xx = xxStart; xx <= xxEnd; xx++) {
            final dx = xx + 0.5 - x;
            final dy = y + 0.5 - sy;
            final dd = hypot(dx, dy);
            if (dd > rb + 0.5) continue;
            if (dd > rb - 0.7) {
              p.px(xx, y, dx < 0.0 && dy < -rb * 0.3 ? c[6] : c[4]);
            } else {
              p.blend(xx, y, c[5], 0.3);
            }
          }
        }
        p.glow(x, sy - rb * 0.5, rb * 2.0 + 3.0, c[5], 0.2);
      } else {
        final q = (k - 0.85) / 0.15;
        for (final (dx, dy) in const [
          (1.0, 0.0),
          (-1.0, 0.0),
          (0.6, -0.7),
          (-0.6, -0.7),
          (0.0, -1.0),
        ]) {
          p.dot(x + dx * (2.0 + 3.0 * q), sy + dy * (2.0 + 3.0 * q), c[6],
              1.2 - q);
        }
      }
    });

    for (var i = 0; i < _ndrop; i++) {
      final f = _droplet(i, seed, age);
      if (!f.landed || f.gone) continue;
      final x = f.x.round();
      final w = f.size + (f.splat > 0.0 ? 1 : 0);
      for (var j = 0; j < w; j++) {
        p.px(x - (w >> 1) + j, -1, j == 0 ? c[5] : c[4]);
      }
      if (f.size >= 2 && f.splat <= 0.0) {
        p.px(x, -2, c[5]);
        p.px(x - 1, -2, c[4]);
      }
      p.px(x, 0, c[3]);
      final dir = (f.lx - f.x).sign.toInt();
      final jMax = math.min<double>(8.0, (f.lx - f.x).abs());
      for (var j = 1; j < jMax; j++) {
        p.dot(x + dir * j, 0, c[2], 0.7 - j * 0.08);
      }
      p.glow(x, -1, 5, c[4], 0.25 * f.k + 0.1);
    }

    if (t >= _tLift && t < _snap) {
      final bot = pose.by - 1.0;
      final u = (t - _tLift) / (_snap - _tLift);
      for (var y = bot.floor(); y < 0; y++) {
        final m = math.sin(((y - bot) / -bot) * math.pi);
        p.px(-1, y, c[4]);
        if (m * u < 0.45) p.px(0, y, c[3]);
      }
    } else if (t >= _snap && t < _snap + 0.3) {
      final a2 = t - _snap;
      final ys = _pose(_snap, hop).by - 1.0;
      final f = toss(-1.0, ys * 0.45, 0.0, 0.0, a2, _g * 1.3, -2.0);
      if (!f.landed) {
        p.px(-1, f.y, c[5]);
        p.px(-1, f.y - 1.0, c[3]);
      }
      final nub = 3.0 * (1.0 - a2 / 0.12);
      for (var j = 0; j < nub; j++) {
        p.px(-1, pose.by + j, j == 0 ? c[3] : c[4]);
      }
    }
  },
  onDraw: (p, time, o) {
    final seed = o.seed;
    final hop = o.numOpt('hop', 24.0);
    final t = shift(time, _duration, seed);
    final c = fit(o.palette, 7);
    final pose = _pose(t, hop);
    final yb = pose.by - 1.0;
    final age = pose.age;

    final g = _slimeGrid;
    _body(g, c, pose);
    _face(g, c, pose, t);
    _bubbleIn(g, c, pose, t);
    g.outlineShaded((x, y, nx, ny) =>
        (ny < 0 && nx <= 0 && y < yb - pose.h * 0.5) ? c[1] : c[0]);
    g.draw(p);

    if (t >= _pop && t < _pop + 0.16) {
      final k = (t - _pop) / 0.16;
      final x = pose.lean * pose.h - _halfW(0.86, pose) * 0.05;
      final y = yb - pose.h - 0.5;
      for (var a = 0.0; a < tau; a += 0.6) {
        p.dot(x + math.cos(a) * (1.0 + k * 3.0),
            y + math.sin(a) * (1.0 + k * 3.0) * 0.7, c[6], 1.2 - k);
      }
      for (final s in const [-1, 1]) {
        p.dot(x + s * (1.0 + k * 4.0), y - 1.0 - k * 6.0 + k * k * 4.0, c[5],
            1.3 - k);
      }
      p.glow(x, y, 6, c[5], 0.4 * (1.0 - k));
    }

    for (var i = 0; i < _ndrop; i++) {
      final f = _droplet(i, seed, age);
      if (f.landed || _inside(pose, f.x, f.y)) continue;
      final svRaw = hypot(f.vx, f.vy);
      final sv = svRaw == 0.0 ? 1.0 : svRaw;
      final ux = f.vx / sv;
      final uy = f.vy / sv;
      final len = math.min(2.5, sv / 50.0);
      p.line(f.x - ux * len, f.y - uy * len, f.x, f.y, c[3]);
      if (f.size >= 2) {
        p.px(f.x - 1.0, f.y, c[4]);
        p.px(f.x - 1.0, f.y + 1.0, c[3]);
        p.px(f.x, f.y + 1.0, c[2]);
      }
      if (f.size >= 3) {
        p.px(f.x + 1.0, f.y, c[3]);
        p.px(f.x - 1.0, f.y - 1.0, c[4]);
        p.px(f.x, f.y - 1.0, c[5]);
      }
      p.px(f.x, f.y, f.size >= 2 ? c[6] : c[5]);
      p.glow(f.x, f.y, 5 + f.size, c[4], 0.32);
    }

    cycle(t, _duration, 7, seed * 13 + 1, (rv) => rv.range(1.2, 1.8),
        (ag, len, rv, i) {
      final k = ag / len;
      final x = rv.range(-24.0, 24.0) + math.sin(ag * 2.1 + i * 1.7) * 3.0;
      final y = -2.0 - rv.range(9.0, 17.0) * ag - 5.0 * ag * ag;
      final a = math.min(1.0, k * 4.0) * math.min(1.0, (1.0 - k) * 2.5);
      final tw = 0.6 + 0.4 * math.sin(ag * 7.0 + i * 2.3);
      final big = rv.chance(0.35);
      p.dot(x, y, tw > 0.8 ? c[6] : c[5], a);
      if (big) {
        p.dot(x + 1.0, y, c[5], a);
        p.dot(x, y + 1.0, c[4], a);
        p.dot(x + 1.0, y + 1.0, c[4], a * 0.6);
      }
      p.glow(x, y, big ? 9 : 6, c[5], (big ? 0.45 : 0.32) * a * tw);
    });

    for (final (t0, dx) in _drips) {
      final a2 = wrap(t - t0, _duration);
      if (a2 > 0.6) continue;
      final p0 = _pose(t0, hop);
      final f = toss(dx, p0.by - 0.5, 0.0, 12.0, a2, _g, -1.0);
      if (!f.landed) {
        p.px(dx, f.y, c[5]);
        p.px(dx, f.y - 1.0, c[4]);
        p.glow(dx, f.y, 4, c[4], 0.3);
      } else if (a2 - f.at < 0.14) {
        final k = (a2 - f.at) / 0.14;
        for (final s2 in const [-1, 1]) {
          p.dot(dx + s2 * (1.0 + k * 3.0), -2.0 - k * 3.0 + k * k * 3.0, c[5],
              1.2 - k);
        }
      }
    }

    if (pose.q > 0.4 && pose.q < 0.64) {
      final k = math.sin(math.pi * seg(pose.q, 0.4, 0.64));
      sparkle(
        p,
        pose.lean * 0.8 * pose.h - pose.w * 0.21,
        yb - pose.h * 0.8,
        1.0 + 2.5 * k,
        c[6],
        c[5],
        0.5 * k,
      );
    }

    final cx = pose.lean * pose.h * 0.4;
    final cy = yb - pose.h * 0.45;
    final near = clamp(1.0 + pose.by / (hop * 1.1));
    final r = _puddleR(t, pose);
    final br = 0.9 + 0.1 * math.sin((t / _duration) * tau * 2.0);
    p.glow(cx * 0.5, -14, 64, c[3], 0.3 * br);
    p.glow(cx, cy, 30 + pose.w * 0.3, c[4], 0.2);
    p.glow(cx, cy + 3, 14, c[5], 0.16);
    p.glow(0, -2, r * 1.3 + 6, c[4], 0.12 + 0.08 * near);
    if (t >= _tLand || t < _tSq) p.glow(0, -3, 40, c[5], 0.42 * math.exp(-age * 9.0));
  },
);
