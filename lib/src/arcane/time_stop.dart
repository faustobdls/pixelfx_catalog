// The cracks walking out from a point and the burst into tumbling shards, glints and light are adapted from
// Sprite Fusion's open-source ice shatter (https://www.spritefusion.com/pixel-art-vfx/ice), MIT License,
// Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const double _cy = -42.0;
const double _rc = 26.0;
const double _open = 0.3;
const double _freeze = 1.75;
const double _crack = 2.2;
const double _shatter = 2.42;

const List<double> _ticks = [0.36, 0.46, 0.57, 0.7, 0.85, 1.03, 1.24, 1.49];

double _hand(double t) {
  var a = 0.0;
  for (final tk in _ticks) {
    if (t > tk) a += Ease.outBack(clamp((t - tk) / 0.07), 3.0);
  }
  return -math.pi / 2.0 + a * (tau / 12.0);
}

double _flow(double t) => t < _open
    ? 1.0
    : math.pow(math.max(0.0, 1.0 - (t - _open) / (_freeze - _open)), 1.6)
        .toDouble();

double _clockTime(double t) {
  var s = 0.0;
  final end = math.min(t, _freeze);
  for (var u = 0.0; u < end; u += 1.0 / 120.0) {
    s += _flow(u) / 120.0;
  }
  return s;
}

class _OrbitMote {
  final double a;
  final double r;
  final double w;
  final double tilt;
  final int c;

  const _OrbitMote({
    required this.a,
    required this.r,
    required this.w,
    required this.tilt,
    required this.c,
  });
}

class _TimeStopSim extends BaseEffectSim {
  final List<int> c;
  late final List<int> g;
  final Rng r;
  late final Particles ps;
  final Bits bits = Bits(ground: (_) => 0.0);
  final Lights lights = Lights();
  late final List<_OrbitMote> motes;
  late final double ix;
  late final double iy;
  final List<List<Point2>> cracks = [];
  double t = 0.0;
  double tc = 0.0;
  int ticked = 0;
  bool shattered = false;
  bool frozen = false;

  _TimeStopSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed) {
    g = c.map((col) {
      final l = luma(col) * 255.0;
      return rgb(l * 0.92, l * 0.96, math.min(255.0, l * 1.06));
    }).toList(growable: false);
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [kWhite, c[6], c[5], c[4]],
    );
    motes = List.generate(14, (i) {
      return _OrbitMote(
        a: r.range(0.0, tau),
        r: _rc + r.range(5.0, 14.0),
        w: r.range(1.4, 2.6) * (i.isOdd ? 1.0 : -1.0),
        tilt: r.range(-0.5, 0.5),
        c: r.pick([kWhite, c[6], c[5]]),
      );
    }, growable: false);
    ix = r.range(-6.0, 6.0);
    iy = r.range(-6.0, 6.0);
    void walk(double x, double y, double a, double len, int depth) {
      final pts = <Point2>[(x, y)];
      for (var s = 0; s < len; s++) {
        a += r.range(-0.55, 0.55);
        x += math.cos(a) * r.range(1.6, 2.6);
        y += math.sin(a) * r.range(1.6, 2.6);
        if (hypot(x, y) > _rc - 0.5) break;
        pts.add((x, y));
        if (depth < 1 && pts.length > 3 && r.chance(0.14)) {
          walk(x, y, a + r.sign() * r.range(0.6, 1.1), len / 2.0, depth + 1);
        }
      }
      cracks.add(pts);
    }

    for (var i = 0; i < 7; i++) {
      walk(ix, iy, (i / 7.0) * tau + r.range(-0.3, 0.3), 16.0, 0);
    }
  }

  void _face(Painter p, List<int> kCols, double s, double cracked) {
    const cy = _cy;
    final rr = _rc * s;
    if (rr < 1.0) return;
    p.discShaded(
      0,
      cy,
      rr,
      color: (_, _) => kCols[1],
      alpha: (d, _) => 0.3 + 0.35 * d * d,
    );
    p.ring(0, cy, rr + 0.5, 1, kCols[6]);
    p.ring(0, cy, rr - 1.5, 1, kCols[4]);
    p.ring(0, cy, rr + 2.0, 1, kCols[3], 0.6);
    for (var i = 0; i < 60; i++) {
      final a = (i / 60.0) * tau;
      if (i % 5 != 0) {
        p.dot(math.cos(a) * (rr - 3.5), cy + math.sin(a) * (rr - 3.5),
            kCols[4], 0.8);
      } else {
        final q = i % 15 == 0;
        final r0 = rr - (q ? 8.0 : 6.5);
        p.line(
          math.cos(a) * r0,
          cy + math.sin(a) * r0,
          math.cos(a) * (rr - 3.0),
          cy + math.sin(a) * (rr - 3.0),
          q ? kCols[7] : kCols[6],
        );
      }
    }
    p.ring(0, cy, rr * 0.3, 1, kCols[4], 0.8);
    final ha = -math.pi / 2.0 + (_hand(t) + math.pi / 2.0) / 12.0 + 0.9;
    final sa = _hand(t) + (frozen ? math.sin(t * 70.0) * 0.012 : 0.0);
    p.beamShaded(
      0,
      cy,
      math.cos(ha) * rr * 0.48,
      cy + math.sin(ha) * rr * 0.48,
      2.6,
      color: (_, v) => v < 0.5 ? kCols[6] : kCols[4],
    );
    p.lineShaded(
      -math.cos(sa) * 5.0,
      cy - math.sin(sa) * 5.0,
      math.cos(sa) * (rr - 4.0),
      cy + math.sin(sa) * (rr - 4.0),
      color: (u) => u > 0.75 ? kCols[7] : kCols[6],
    );
    p.line(
      -math.cos(sa) * 5.0 + 0.5,
      cy - math.sin(sa) * 5.0,
      -math.cos(sa) * 2.0,
      cy - math.sin(sa) * 2.0,
      kCols[5],
    );
    p.circle(0, cy, 2.2, kCols[5]);
    p.circle(0, cy, 1.2, kCols[7]);
    if (cracked > 0.0) {
      for (final pts in cracks) {
        final n = (pts.length * cracked).floor();
        for (var i = 0; i < n; i++) {
          final (x, y) = pts[i];
          final fresh = i > n - 3 && cracked < 1.0;
          p.px(x, cy + y, fresh ? kWhite : kCols[7]);
          if (!fresh) p.px(x, cy + y - 1.0, kCols[2]);
        }
      }
    }
  }

  void _drawMote(Painter p, _OrbitMote m, bool isBack) {
    final a = m.a + m.w * tc;
    final z = math.sin(a);
    if ((z < 0.0) != isBack) return;
    final x = math.cos(a) * m.r;
    final y = _cy + math.cos(a) * m.r * m.tilt + z * m.r * 0.3;
    final cold = t >= _freeze;
    final v = _flow(t) * m.w;
    final col = cold ? g[6] : m.c;
    p.dot(x, y, col, isBack ? 0.6 : 1.0);
    if (v.abs() > 0.2) {
      final wSign = m.w.sign;
      for (var k = 1; k <= 3; k++) {
        final b = a - wSign * k * 0.05 * math.min(1.0, v.abs());
        p.dot(
          math.cos(b) * m.r,
          _cy + math.cos(b) * m.r * m.tilt + math.sin(b) * m.r * 0.3,
          k < 2 ? c[5] : c[4],
          (isBack ? 0.5 : 0.9) * (1.0 - k / 4.0),
        );
      }
    }
    if (!isBack) p.glow(x, y, 5, cold ? g[6] : c[6], 0.3);
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    tc = _clockTime(t);
    while (ticked < _ticks.length && t >= _ticks[ticked]) {
      ticked++;
      final a = _hand(t + 0.1);
      lights.add(math.cos(a) * (_rc - 4.0), _cy + math.sin(a) * (_rc - 4.0),
          22, c[6], 0.6, 0.12);
      for (var i = 0; i < 3; i++) {
        ps.spawn(
          P.star,
          math.cos(a) * (_rc + 1.0),
          _cy + math.sin(a) * (_rc + 1.0),
          math.cos(a) * 30.0 + r.range(-15.0, 15.0),
          math.sin(a) * 30.0 + r.range(-15.0, 15.0),
          r.range(0.2, 0.4),
          r.pick([kWhite, c[6]]),
          r.range(0.7, 1.3),
        );
      }
    }
    if (!frozen && t >= _freeze) {
      frozen = true;
      lights.add(0, _cy, 70, kWhite, 0.7, 0.2);
    }
    if (!shattered && t >= _shatter) {
      shattered = true;
      lights.add(0, _cy, 80, kWhite, 0.8, 0.16);
      lights.add(0, _cy, 100, c[5], 0.6, 0.6);
      for (var i = 0; i < 64; i++) {
        final a = r.range(0.0, tau);
        final d = r.range(0.0, _rc);
        final x = math.cos(a) * d;
        final y = _cy + math.sin(a) * d;
        final sp = r.range(40.0, 140.0);
        final dx = x - ix;
        final dy = y - _cy - iy;
        final rawL = hypot(dx, dy);
        final l = rawL == 0.0 ? 1.0 : rawL;
        bits.add(DebrisBit(
          kind: B.shard,
          x: x,
          y: y,
          vx: (dx / l) * sp + r.range(-25.0, 25.0),
          vy: (dy / l) * sp * 0.7 - r.range(40.0, 120.0),
          g: 0.9,
          drag: 0.5,
          bounce: 0.25,
          life: r.range(0.8, 1.15),
          a: r.range(0.0, tau),
          va: r.range(-22.0, 22.0),
          s: r.range(1.5, 3.6),
          c: r.pick([g[7], g[6], g[6], g[5]]),
        ));
      }
      for (var i = 0; i < 10; i++) {
        final a = r.range(0.0, tau);
        final sp = r.range(40.0, 110.0);
        bits.add(DebrisBit(
          kind: B.chunk,
          x: math.cos(a) * _rc * 0.6,
          y: _cy + math.sin(a) * _rc * 0.6,
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp * 0.6 - r.range(60.0, 130.0),
          g: 1.0,
          drag: 0.4,
          bounce: 0.3,
          life: r.range(0.9, 1.15),
          a: r.range(0.0, tau),
          va: r.range(-14.0, 14.0),
          s: r.range(1.6, 3.0),
          rampColors: [g[1], g[3], g[4], g[6], g[7]],
        ));
      }
      for (var i = 0; i < 26; i++) {
        final a = r.range(0.0, tau);
        final sp = r.range(30.0, 110.0);
        ps.spawn(
          i.isOdd ? P.star : P.mote,
          0.0,
          _cy,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.4, 0.8),
          r.pick([kWhite, c[6], c[5]]),
          r.range(0.8, 1.8),
        );
      }
      for (var i = 0; i < 18; i++) {
        final a = r.range(0.0, tau);
        final sp = r.range(90.0, 200.0);
        ps.spawn(
          P.spark,
          0.0,
          _cy,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.2, 0.45),
        );
      }
      for (var i = 0; i < 12; i++) {
        final a = r.range(0.0, tau);
        final d = r.range(0.0, _rc * 0.8);
        ps.spawn(
          P.vapour,
          math.cos(a) * d,
          _cy + math.sin(a) * d,
          math.cos(a) * r.range(10.0, 40.0),
          math.sin(a) * r.range(10.0, 30.0) - r.range(5.0, 20.0),
          r.range(0.6, 1.0),
          r.chance(0.5) ? g[5] : c[4],
          r.range(3.0, 6.0),
        );
      }
    }
    bits.update(dt);
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final k = smooth(0.0, _open, t) * (1.0 - smooth(_shatter, _shatter + 0.5, t));
    final cold = t >= _freeze;
    if (k > 0.0) p.glow(0, -1, 40, cold ? g[5] : c[4], 0.25 * k);
    if (t < _shatter) {
      for (final m in motes) {
        _drawMote(p, m, true);
      }
    }
  }

  @override
  void draw(Painter p) {
    final cold = t >= _freeze;
    final s = t < _open ? Ease.outBack(t / _open, 2.6) : 1.0;
    if (t < _shatter) {
      final white = (t >= _freeze && t < _freeze + 0.06) || t >= _shatter - 0.05;
      final rampCols = white
          ? List<int>.filled(g.length, kWhite, growable: false)
          : (cold ? g : c);
      _face(p, rampCols, s, clamp((t - _crack) / 0.18));
      p.glow(0, _cy, _rc * 1.9, cold ? g[5] : c[4], 0.32 * s);
      p.glowRing(0, _cy, _rc, 7, cold ? g[6] : c[5], 0.28 * s);
      for (final m in motes) {
        _drawMote(p, m, false);
      }
    }
    if (t < 0.35) {
      final q = t / 0.35;
      p.ring(
        0,
        _cy,
        _rc * (0.4 + 1.2 * Ease.outCubic(q)),
        math.max(1.0, 3.0 * (1.0 - q)),
        q < 0.3 ? kWhite : c[6],
        1.2 - q,
      );
      if (q < 0.5) {
        flare(p, 0, _cy, 26.0 * (1.0 - q * 2.0) + 2.0, 1.0 - q * 2.0, c);
      }
    }
    if (t < _shatter) {
      for (final tk in _ticks) {
        if (t < tk) continue;
        final q = (tc - _clockTime(tk)) / 0.32;
        if (q >= 1.0) continue;
        p.ring(
          0,
          _cy,
          _rc + 3.0 + 24.0 * Ease.outCubic(q),
          1,
          cold ? g[5] : c[5],
          (cold ? 0.6 : 0.8) * math.pow(1.0 - q, 1.6),
        );
      }
    }
    if (t >= _shatter && t < _shatter + 0.2) {
      final q = (t - _shatter) / 0.2;
      flare(p, 0, _cy, 34.0 * (1.0 - q) + 2.0, 1.0 - q, c);
      p.ring(0, _cy, _rc + 30.0 * Ease.outCubic(q),
          math.max(1.0, 3.0 * (1.0 - q)), kWhite, 1.2 - q);
    }
    bits.draw(p);
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect timeStopEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'arcane/time-stop',
    name: 'Time stop',
    desc:
        'A clock face springs open, ticks slower and slower, freezes drained of colour, cracks, then shatters into falling shards.',
    category: 'arcane',
    tags: ['arcane', 'time', 'clock', 'freeze', 'stop', 'shatter', 'magic', 'one-shot'],
    size: (196, 136),
    origin: (98, 118),
    duration: 3.6,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {'palette': Pal.arcane, 'seed': 14},
  ),
  onCreate: (o) => _TimeStopSim(o),
);
