// The smear that trails the lash (white at its leading edge, cooling down the ramp as it thins), the glint and
// crack burst at the tip, are adapted from Sprite Fusion's open-source slash (https://www.spritefusion.com/pixel-art-vfx/slash),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'nature_lib.dart';

const int _n = 24;
const double _ls = 3.3;
const double _lash = 0.36;
const double _lag = 0.0052;
const double _tauS = 0.055;
const double _omega = tau / 0.21;
final double _crack =
    _lash + _lag * _n + (math.pi - math.atan(_omega * _tauS)) / _omega;
const double _dur = 1.4;

double _spring(double u) => u <= 0
    ? 0.0
    : 1 -
        math.exp(-u / _tauS) *
            (math.cos(_omega * u) + math.sin(_omega * u) / (_omega * _tauS));

List<Point2> _pose(double t) {
  final grow = Ease.outCubic(clamp(t / 0.14)) *
      (1 - Ease.inCubic(clamp((t - 1.0) / 0.3)));
  final rear = smooth(0.1, _lash, t);
  final relax = smooth(0.82, 1.0, t);
  final pts = <Point2>[(0.0, (1 - grow) * (_n * _ls + 6))];
  for (var i = 0; i < _n; i++) {
    final s = i / _n;
    final stand = -math.pi / 2 + 0.25 * math.sin(s * 3 + t * 7) * s;
    final back = -math.pi / 2 - 0.3 - 1.65 * math.pow(s, 1.3);
    final out = -1.0 + 0.9 * math.pow(s, 0.6);
    var a = lerp(stand, back, rear);
    a = lerp(a, out, _spring(t - _lash - _lag * i));
    a = lerp(a, stand, relax);
    final (x, y) = pts[i];
    pts.add((x + math.cos(a) * _ls, y + math.sin(a) * _ls));
  }
  return pts;
}

void _haze(Painter p, List<Point2> pts, int c, double a) {
  var x0 = double.infinity;
  var y0 = double.infinity;
  var x1 = double.negativeInfinity;
  var y1 = double.negativeInfinity;
  for (final (x, y) in pts) {
    x0 = math.min(x0, x);
    x1 = math.max(x1, x);
    y0 = math.min(y0, y);
    y1 = math.max(y1, y);
  }
  for (var y = y0.floor(); y <= y1.ceil(); y++) {
    for (var x = x0.floor(); x <= x1.ceil(); x++) {
      var inside = false;
      for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
        final (xi, yi) = pts[i];
        final (xj, yj) = pts[j];
        if ((yi > y + 0.5) != (yj > y + 0.5) &&
            x + 0.5 < ((xj - xi) * (y + 0.5 - yi)) / (yj - yi) + xi) {
          inside = !inside;
        }
      }
      if (inside) p.blend(x, y, c, a);
    }
  }
}

double _width(double s) => 1.2 + 4.8 * math.pow(1 - s, 0.7);

void _vine(Painter p, List<Point2> pts, List<int> c) {
  for (var i = 0; i < _n; i++) {
    final (ax, ay) = pts[i];
    final (bx, by) = pts[i + 1];
    final dx = bx - ax;
    final dy = by - ay;
    final lRaw = hypot(dx, dy);
    final l = lRaw == 0.0 ? 1.0 : lRaw;
    final nx = -dy / l;
    final ny = dx / l;
    final w0 = _width(i / _n) / 2;
    final w1 = _width((i + 1) / _n) / 2;
    final up = nx * -0.6 + ny * -0.8 > 0 ? 1 : -1;
    final x0 = (math.min(ax, bx) - 4).floor();
    final x1 = (math.max(ax, bx) + 4).ceil();
    final y0 = (math.min(ay, by) - 4).floor();
    final y1 = (math.max(ay, by) + 4).ceil();
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (y > 0) continue;
        final px = x + 0.5 - ax;
        final py = y + 0.5 - ay;
        final u = (px * dx + py * dy) / (l * l);
        if (u < -0.15 || u > 1.15) continue;
        final d = px * nx + py * ny;
        final w = lerp(w0, w1, clamp(u)) + 0.35;
        if (d.abs() > w) continue;
        final side = d.sign * up;
        final q = d.abs() / w;
        final arc = (i + u) * _ls;
        var col = q > 0.8
            ? (side > 0 ? c[5] : c[1])
            : side > 0
                ? (q > 0.35 ? c[4] : c[3])
                : (q > 0.4 ? c[2] : c[3]);
        if (w > 1.6 &&
            ((arc + d * 0.8).remainder(5.0) - 2.5).abs() < 0.45 &&
            q < 0.8) {
          col = c[2];
        }
        p.px(x, y, col);
      }
    }
  }
}

void _drawThorns(
  Painter p,
  List<Point2> pts,
  List<int> thC,
  List<int> c,
  double t,
) {
  for (var i = 2; i < _n - 1; i += 2) {
    final (ax, ay) = pts[i];
    final (bx, by) = pts[i + 1];
    final dx = bx - ax;
    final dy = by - ay;
    final lRaw = hypot(dx, dy);
    final l = lRaw == 0.0 ? 1.0 : lRaw;
    final side = ((i ~/ 2) % 2) != 0 ? 1 : -1;
    final nx = (-dy / l) * side;
    final ny = (dx / l) * side;
    final w = _width(i / _n) / 2;
    final len = 1.8 + 2.4 * (1 - i / _n);
    final tx0 = dx / l;
    final ty0 = dy / l;
    final x0 = ax + nx * (w - 0.5);
    final y0 = ay + ny * (w - 0.5);
    final tx = x0 + nx * len - tx0 * len * 0.7;
    final ty = y0 + ny * len - ty0 * len * 0.7;
    if (y0 > 0) continue;
    p.tri(
      x0 - tx0 * 1.6,
      y0 - ty0 * 1.6,
      x0 + tx0 * 1.4,
      y0 + ty0 * 1.4,
      tx,
      ty,
      thC[1],
    );
    p.line(x0 + tx0 * 0.8, y0 + ty0 * 0.8, tx, ty, thC[2]);
    p.px(tx, ty, thC[3]);
  }
  for (final k in const [7, 13, 18]) {
    final (ax, ay) = pts[k];
    final (bx, by) = pts[k + 1];
    final a = math.atan2(by - ay, bx - ax);
    final side = (k % 2) != 0 ? 1 : -1;
    if (ay > -2) continue;
    final la = a + side * 1.1 + math.sin(t * 9 + k) * 0.2;
    final lx = ax + math.cos(la) * 4;
    final ly = ay + math.sin(la) * 4;
    drawLeaf(
      p,
      lx,
      ly,
      7,
      2.2,
      la,
      0.3 + math.sin(t * 5 + k) * 0.4,
      [c[1], c[3], c[5], c[6]],
    );
  }
}

class _Chip {
  double x;
  double y;
  double vx;
  double vy;
  double a;
  double va;
  final double s;
  final List<Point2> pts;
  double life;

  _Chip({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.a,
    required this.va,
    required this.s,
    required this.pts,
    required this.life,
  });
}

class _TornLeaf {
  double x;
  double y;
  double vx;
  double vy;
  double a;
  final double va;
  double fl;
  final double vf;
  double life;

  _TornLeaf({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.a,
    required this.va,
    required this.fl,
    required this.vf,
    required this.life,
  });
}

class _Spot {
  final double x;
  final double t0;
  final double w;

  const _Spot(this.x, this.t0, this.w);
}

class _VineWhipSim extends BaseEffectSim {
  final List<int> c;
  final List<int> thC;
  final List<int> s;
  final Rng r;
  final Particles ps;
  final Drops drops;
  final Lights lights;
  final List<_Chip> chips = [];
  final List<_TornLeaf> torn = [];
  final List<_Spot> spots = [];

  double t = 0.0;
  bool burst = false;
  bool cracked = false;
  bool sunk = false;

  _VineWhipSim._({
    required this.c,
    required this.thC,
    required this.s,
    required this.r,
    required this.ps,
    required this.drops,
    required this.lights,
  });

  factory _VineWhipSim(Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final thC = fit(o.rampOpt('thorn'), 4);
    final s = fit(o.rampOpt('soil'), 8);
    final r = Rng(o.seed);
    double floorFn(double _) => 0.0;
    final ps = Particles(
      rng: r,
      ground: floorFn,
      sparks: [c[7], c[6], c[5], c[4]],
    );
    return _VineWhipSim._(
      c: c,
      thC: thC,
      s: s,
      r: r,
      ps: ps,
      drops: Drops(floorFn),
      lights: Lights(),
    );
  }

  void _dirt(int n, double sp) {
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + r.range(-1.2, 1.2);
      final v = r.range(60, 200) * sp;
      chips.add(_Chip(
        x: r.range(-3, 3),
        y: -1,
        vx: math.cos(a) * v,
        vy: math.sin(a) * v,
        a: r.range(0, tau),
        va: r.range(-15, 15),
        s: r.range(1.4, 2.6),
        pts: stoneShape(r),
        life: math.min(r.range(0.6, 0.9), _dur - 0.05 - t),
      ));
    }
    for (var i = 0; i < n * 3; i++) {
      final a = -math.pi / 2 + r.range(-1, 1);
      final v = r.range(50, 200) * sp;
      ps.spawn(
        P.grit,
        r.range(-3, 3),
        -1,
        math.cos(a) * v,
        math.sin(a) * v,
        math.min(r.range(0.5, 0.9), _dur - 0.05 - t),
        r.pick([s[5], s[4], s[3]]),
        r.chance(0.3) ? 2 : 1,
      );
    }
    for (var i = 0; i < n; i++) {
      ps.spawn(
        P.dust,
        r.range(-4, 4),
        -r.range(0, 3),
        r.sign() * r.range(15, 60),
        -r.range(4, 20),
        math.min(r.range(0.4, 0.8), _dur - 0.05 - t),
        s[5],
        r.range(2, 4),
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (!burst) {
      burst = true;
      _dirt(6, 1);
    }
    if (!cracked && t >= _crack) {
      cracked = true;
      final a = _pose(t);
      final b = _pose(t - 0.01);
      final (x, y) = a[_n];
      final vx = (x - b[_n].$1) / 0.01;
      final vy = (y - b[_n].$2) / 0.01;
      final spRaw = hypot(vx, vy);
      final sp = spRaw == 0.0 ? 1.0 : spRaw;
      lights.add(x, y, 22, kWhite, 0.5, 0.08);
      lights.add(x, y, 50, c[5], 0.35, 0.4);
      for (var i = 0; i < 18; i++) {
        final ang = math.atan2(vy, vx) + r.range(-0.7, 0.7);
        final v = r.range(80, 260);
        drops.add(
          x,
          y,
          math.cos(ang) * v,
          math.sin(ang) * v - r.range(0, 60),
          r.chance(0.3) ? 2 : 1,
        );
      }
      for (var i = 0; i < 4; i++) {
        torn.add(_TornLeaf(
          x: x,
          y: y,
          vx: (vx / sp) * r.range(40, 120) + r.range(-30, 30),
          vy: r.range(-90, -20),
          a: r.range(0, tau),
          va: r.range(-12, 12),
          fl: r.range(0, tau),
          vf: r.range(8, 16),
          life: r.range(0.65, 0.8),
        ));
      }
      for (var i = 0; i < 8; i++) {
        ps.spawn(
          P.star,
          x + r.range(-6, 6),
          y + r.range(-6, 6),
          r.range(-20, 20),
          r.range(-20, 20),
          r.range(0.15, 0.35),
          c[7],
          r.range(0.6, 1.6),
        );
      }
    }
    if (!sunk && t >= 1.08) {
      sunk = true;
      _dirt(3, 0.5);
    }
    drops.update(dt, (d, _) {
      spots.add(_Spot(d.x, t, d.s * 0.7 + r.range(0.2, 1)));
    });
    for (var i = chips.length - 1; i >= 0; i--) {
      final ch = chips[i];
      if ((ch.life -= dt) <= 0) {
        chips.removeAt(i);
        continue;
      }
      ch.vy += 950 * dt;
      ch.x += ch.vx * dt;
      ch.y += ch.vy * dt;
      ch.a += ch.va * dt;
      if (ch.y > 0) {
        ch.y = 0;
        ch.vy *= -0.3;
        ch.vx *= 0.6;
      }
    }
    for (var i = torn.length - 1; i >= 0; i--) {
      final l = torn[i];
      if ((l.life -= dt) <= 0) {
        torn.removeAt(i);
        continue;
      }
      l.vy += 160 * dt;
      l.vx -= l.vx * 2.5 * dt;
      l.vy -= l.vy * 2 * dt;
      l.x += l.vx * dt + math.sin(l.fl) * 20 * dt;
      l.y += l.vy * dt;
      l.a += l.va * dt;
      l.fl += l.vf * dt;
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final k = 1 - smooth(1.15, 1.35, t);
    for (var x = -5; x <= 5; x++) {
      p.dot(x, 0, x.abs() < 3 ? s[0] : s[1], k * (1 - x.abs() / 7));
    }
    for (final sp in spots) {
      final a = (1 - smooth(0.25, 0.6, t - sp.t0)) * (1 - smooth(1.2, 1.35, t));
      for (var x = (sp.x - sp.w).floor(); x <= (sp.x + sp.w).ceil(); x++) {
        p.dot(x, 0, t - sp.t0 < 0.1 ? c[6] : c[4], a);
      }
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final pts = _pose(t);
    if (t > _lash + 0.04 && t < _crack + 0.1) {
      final age = clamp((t - _crack + 0.02) / 0.12);
      final hist = List.generate(12, (k) => _pose(t - k * 0.0045));
      for (var k = 0; k < 6; k++) {
        _haze(
          p,
          [hist[k][_n], hist[k + 1][_n], hist[k + 1][_n - 12], hist[k][_n - 12]],
          k < 2 ? c[6] : c[5],
          0.4 * (1 - k / 6) * (1 - age),
        );
      }
      for (var i = _n - 12; i <= _n; i += 2) {
        final q = (_n - i) / 12;
        final col = q < 0.1
            ? kWhite
            : q < 0.3
                ? c[7]
                : q < 0.55
                    ? c[6]
                    : q < 0.8
                        ? c[5]
                        : c[4];
        final len = (11 * (1 - q * 0.6) + 0.5).floor();
        for (var k = 0; k < len; k++) {
          p.line(
            hist[k][i].$1,
            hist[k][i].$2,
            hist[k + 1][i].$1,
            hist[k + 1][i].$2,
            k < 2 && q < 0.1 ? kWhite : col,
            (1 - age) * (k < len * 0.5 ? 1 : 2 * (1 - k / len)),
          );
        }
      }
      p.glowLine(
        hist[0][_n].$1,
        hist[0][_n].$2,
        hist[6][_n].$1,
        hist[6][_n].$2,
        14,
        c[5],
        0.35 * (1 - age),
      );
    }
    _vine(p, pts, c);
    _drawThorns(p, pts, thC, c, t);
    final lk = smooth(_lash, _crack, t) * (1 - smooth(_crack, _crack + 0.35, t));
    if (lk > 0) {
      for (var i = 6; i <= _n; i += 6) {
        p.glow(pts[i].$1, pts[i].$2, 12, c[5], 0.18 * lk);
      }
    }
    final e = t - _crack;
    if (e >= 0 && e < 0.12) {
      final (x, y) = pts[_n];
      final k = 1 - e / 0.12;
      for (var j = 0; j < 7; j++) {
        final a = (j / 7) * tau + 0.3;
        final r0 = 4 + 10 * (1 - k);
        final r1 = r0 + 5 * k;
        p.line(
          x + math.cos(a) * r0,
          y + math.sin(a) * r0,
          x + math.cos(a) * r1,
          y + math.sin(a) * r1,
          k > 0.5 ? kWhite : c[6],
        );
      }
      p.ring(x, y, 3 + 8 * (1 - k), 1, c[7], k);
      sparkle(p, x, y, 7 * k, c[7], c[5], 0.4);
    }
    for (final ch in chips) {
      drawRock(
        p,
        ch.x,
        ch.y,
        ch.s,
        ch.a,
        ch.pts,
        s,
        math.min(1.0, ch.life / 0.25),
      );
    }
    for (final l in torn) {
      drawLeaf(
        p,
        l.x,
        l.y,
        6,
        2,
        l.a,
        l.fl,
        [c[1], c[3], c[5], c[6]],
        math.min(1.0, l.life / 0.3),
      );
    }
    drops.draw(p, c);
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final PixelEffect vineWhip = SimulatedEffect(
  meta: const EffectMeta(
    id: 'nature/vine-whip',
    name: 'Vine whip',
    desc:
        'A thorny vine bursts from the floor, rears back coiled, then lashes out right in a whip crack that sprays sap and tears off leaves, before sliding back into the ground.',
    category: 'nature',
    tags: [
      'nature',
      'vine',
      'plant',
      'whip',
      'melee',
      'directional',
      'one-shot',
    ],
    size: (216, 128),
    origin: (60, 114),
    duration: 1.4,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#0c1a10',
        '#173a1a',
        '#24582a',
        '#357a34',
        '#52a03e',
        '#86c84e',
        '#c4ec7a',
        '#f4ffd0',
      ],
      'thorn': ['#2a1410', '#5e2a1a', '#a04c2e', '#e89a6a'],
      'soil': [
        '#120c0c',
        '#251917',
        '#3b2a24',
        '#553d31',
        '#715440',
        '#8f6e52',
        '#b8966e',
        '#e6d0a8',
      ],
      'seed': 3,
    },
  ),
  onCreate: _VineWhipSim.new,
);
