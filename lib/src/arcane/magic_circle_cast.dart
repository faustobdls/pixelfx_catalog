// The column of light (banded across, strands wandering in it, pulses and halos climbing it, stars thrown off,
// rings shocking out across the floor) is adapted from Sprite Fusion's open-source holy light
// (https://www.spritefusion.com/pixel-art-vfx/holy-light), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'arcane_lib.dart';

const double _r = 40.0;
const double _r2 = 35.0;
const double _ri = 24.0;
const double _rr = 30.0;
const double _sy = 0.3;
const double _top = 192.0;
const double _w = 11.0;
const int _nrune = 8;

const (double, double) _pen = (0.04, 0.42);
const (double, double) _pen2 = (0.1, 0.48);
const (double, double) _inner = (0.3, 0.6);
const (double, double) _star = (0.52, 0.88);
const (double, double) _runes = (0.9, 1.3);

const double _flash = 1.52;
const double _breakT = 2.42;
const double _gone = 3.45;
const double _end = 3.9;

double _wrap(double a) => ((a % tau) + tau) % tau;

double _fromFront(double g) =>
    math.atan2(math.sin(g - math.pi / 2.0), math.cos(g - math.pi / 2.0)).abs();

double _outerAt(double g, (double, double) w) =>
    w.$1 + (_fromFront(g) / math.pi) * (w.$2 - w.$1);

double _innerAt(double g) =>
    _inner.$1 + (_wrap(g + math.pi / 2.0) / tau) * (_inner.$2 - _inner.$1);

double _runeAngle(int k) => -math.pi / 2.0 + ((k + 0.5) * tau) / _nrune;

double _runeLit(int k) =>
    _runes.$1 + (k * (_runes.$2 - _runes.$1)) / (_nrune - 1);

double _runeOut(int k) => _breakT + 0.2 + k * 0.08;

double _level(double t) {
  if (t < _runes.$1) return 0.55;
  if (t < _flash) return 0.55 + 0.4 * smooth(_runes.$1, _flash, t);
  if (t < _flash + 0.07) return 1.2;
  if (t < _breakT) return 0.92;
  return 0.92 * (1.0 - smooth(_breakT, _gone, t));
}

class _Strand {
  final double o;
  final double w;
  final double f;

  const _Strand(this.o, this.w, this.f);
}

class _Edge {
  final Point2 p0;
  final Point2 p1;
  final double t0;
  final double dur;

  const _Edge(this.p0, this.p1, this.t0, this.dur);
}

class _MagicCircleCastSim extends BaseEffectSim {
  final List<int> c;
  final int seed;
  final Rng rg;
  late final Particles ps;
  final Lights lights = Lights();
  late final List<int> col;
  late final List<_Strand> strands;
  late final List<_Edge> edges;
  double t = 0.0;
  bool flashed = false;
  bool broke = false;
  final List<bool> out = List.filled(_nrune, false);

  _MagicCircleCastSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        seed = o.seed,
        rg = Rng(o.seed) {
    ps = Particles(
      rng: rg,
      ground: (_) => 0.0,
      sparks: [kWhite, c[6], c[5], c[4]],
    );
    col = [kWhite, c[6], c[5], c[4], c[3]];
    strands = List.generate(
      9,
      (_) => _Strand(
        rg.range(-0.85, 0.85),
        rg.range(0.04, 0.1),
        rg.range(1.0, 3.0),
      ),
      growable: false,
    );
    List<Point2> tri(double a0) => List.generate(3, (k) {
          final a = a0 + (k * tau) / 3.0;
          return (math.cos(a) * _ri, math.sin(a) * _ri);
        }, growable: false);
    final aTri = tri(-math.pi / 2.0);
    final bTri = tri(math.pi / 2.0);
    edges = [];
    for (var k = 0; k < 3; k++) {
      for (final triPts in [aTri, bTri]) {
        edges.add(_Edge(
          triPts[k],
          triPts[(k + 1) % 3],
          _star.$1 + (k * (_star.$2 - _star.$1)) / 3.0,
          (_star.$2 - _star.$1) / 3.0,
        ));
      }
    }
  }

  int _lineCol(double lvl, double age) => age < 0.05
      ? kWhite
      : age < 0.16
          ? c[6]
          : lvl > 1.0
              ? kWhite
              : lvl > 0.8
                  ? c[6]
                  : lvl > 0.45
                      ? c[5]
                      : lvl > 0.28
                          ? c[4]
                          : c[3];

  double _lineA(double lvl) => clamp(lvl / 0.3);

  void _planeLine(
    Painter p,
    Point2 p0,
    Point2 p1,
    double t0,
    double dur,
    double lvl,
    bool far,
  ) {
    final s = clamp((t - t0) / dur);
    if (s <= 0.0) return;
    var u0 = 0.0;
    var u1 = s;
    final v0 = p0.$2;
    final v1 = p1.$2;
    if ((v0 < 0.0) != (v1 < 0.0)) {
      final uc = v0 / (v0 - v1);
      if ((v0 < 0.0) == far) {
        u1 = math.min(u1, uc);
      } else {
        u0 = uc;
      }
    } else if ((v0 < 0.0) != far) {
      return;
    }
    if (u1 <= u0) return;
    Point2 pt(double u) =>
        (p0.$1 + (p1.$1 - p0.$1) * u, (v0 + (v1 - v0) * u) * _sy);
    final (xa, ya) = pt(u0);
    final (xb, yb) = pt(u1);
    p.lineShaded(
      xa,
      ya,
      xb,
      yb,
      color: (q) => _lineCol(lvl, t - (t0 + (u0 + (u1 - u0) * q) * dur)),
      alpha: (_) => _lineA(lvl),
    );
  }

  void _circle(Painter p, bool far) {
    if (t >= _gone) return;
    final lvl = _level(t);
    final keep = far ? (double g) => math.sin(g) < 0.0 : (double g) => math.sin(g) >= 0.0;
    final a = _lineA(lvl);

    void ring(
      double r,
      double Function(double) when, [
      bool Function(double)? chase,
    ]) {
      floorRing(
        p,
        0,
        0,
        r,
        _sy,
        (g) => (chase != null && chase(g)) ? kWhite : _lineCol(lvl, t - when(g)),
        (g) => t < when(g) ? 0.0 : a,
        keep,
      );
    }

    final run = (t > _runes.$1 && t < _breakT)
        ? (t - _runes.$1) * 5.0 + (t - _runes.$1) * (t - _runes.$1) * 4.0
        : null;
    final chase = run == null
        ? null
        : (double g) {
            for (final off in const [0.0, math.pi]) {
              if (math.atan2(math.sin(g - run - off), math.cos(g - run - off))
                      .abs() <
                  0.22) {
                return true;
              }
            }
            return false;
          };

    ring(_r, (g) => _outerAt(g, _pen), chase);
    ring(_r2, (g) => _outerAt(g, _pen2));
    ring(_ri, _innerAt);

    for (var j = 0; j < 32; j++) {
      final g = ((j + 0.5) * tau) / 32.0;
      if ((math.sin(g) < 0.0) != far) continue;
      final when = _outerAt(g, _pen2) + 0.03;
      if (t < when) continue;
      p.line(
        math.cos(g) * _r2,
        math.sin(g) * _r2 * _sy,
        math.cos(g) * _r,
        math.sin(g) * _r * _sy,
        _lineCol(lvl, t - when),
        a * (j.isOdd ? 0.6 : 1.0),
      );
    }
    for (final e in edges) {
      _planeLine(p, e.p0, e.p1, e.t0, e.dur, lvl, far);
    }
  }

  void _runesDraw(Painter p, bool far) {
    for (var k = 0; k < _nrune; k++) {
      final g = _runeAngle(k);
      if ((math.sin(g) < 0.0) != far) continue;
      final x = math.cos(g) * _rr;
      final y0 = math.sin(g) * _rr * _sy;
      final lit = t - _runeLit(k);
      final gone = clamp((t - _runeOut(k)) / 0.25);
      if (t < _innerAt(g) || gone >= 1.0) continue;
      if (lit < 0.0) {
        arcaneGlyph(p, k, x, y0 - 1.0, c[3]);
        continue;
      }
      final rise = 3.0 * Ease.outBack(clamp(lit / 0.2), 2.4);
      final bob = lit > 0.2 ? math.sin(t * 5.0 + k) * 0.5 : 0.0;
      final y = y0 - 1.0 - rise + bob;
      final hot = lit < 0.07 || (t > _flash && t < _flash + 0.07);
      final lvl = _level(t);
      arcaneGlyph(
        p,
        k,
        x,
        y,
        hot ? kWhite : (lvl > 0.8 ? kWhite : c[6]),
        1.0 - gone,
        hot ? c[6] : c[4],
      );
      if (lit < 0.1) {
        sparkle(p, x, y - 2.0, 4.0 * (1.0 - lit / 0.1) + 1.0, c[6], c[5], 0.5);
      }
      p.glow(x, y - 2.0, 8, c[5], (0.3 + 0.3 * lvl) * (1.0 - gone));
      p.glow(x, y0, 6, c[4], 0.2 * (1.0 - gone));
    }
  }

  void _column(Painter p) {
    if (t < _flash - 0.22 || t > _breakT + 0.6) return;
    if (t < _flash) {
      final a = smooth(_flash - 0.22, _flash - 0.04, t);
      final top = -(_top - 10.0) * Ease.outCubic(a);
      for (var y = -1.0; y >= top; y--) {
        p.dot(
          0,
          y,
          y > top + 6.0 ? c[6] : kWhite,
          a * (0.35 + 0.65 * (1.0 + y / _top)),
        );
      }
      p.glow(0, top, 9, c[6], 0.5 * a);
      p.glow(0, -6, 24, c[5], 0.4 * a);
      return;
    }
    final u = t - _flash;
    final brk = clamp((t - _breakT) / 0.45);
    final top = -_top * Ease.outExpo(clamp(u / 0.09));
    final w = t < _breakT
        ? _w * (1.0 + 0.38 * math.exp(-u * 9.0))
        : _w * (1.0 - Ease.outCubic(brk) * 0.85);
    final fade = 1.0 - smooth(_breakT + 0.25, _breakT + 0.55, t);
    final white = u < 0.067;
    if (fade <= 0.0) return;

    for (var y = 3; y >= top.ceil(); y--) {
      final h = -y;
      final ww = w * (1.0 + 0.5 * math.exp(-math.max(0, h) / 6.0));
      final pulse = fract(h * 0.022 - u * 2.6) < 0.07 ? 1 : 0;
      for (var x = (-ww * 1.3).floor(); x <= (ww * 1.3).ceil(); x++) {
        final q = (x + 0.5).abs() / ww;
        if (brk > 0.0 &&
            noise2(x * 0.32, h * 0.11 - (t - _breakT) * 6.0, seed) * 0.5 +
                    0.5 <
                brk * 1.25 - 0.1) {
          continue;
        }
        var lv = q < 0.2
            ? 0
            : q < 0.42
                ? 1
                : q < 0.66
                    ? 2
                    : q < 0.88
                        ? 3
                        : 4;
        for (final s in strands) {
          if (((x + 0.5) / ww - s.o - 0.05 * math.sin(t * s.f + s.o * 9.0))
                  .abs() <
              s.w) {
            lv = math.max(0, lv - 1);
          }
        }
        lv = white ? 0 : math.max(0, lv - pulse);
        final a = (q < 0.88 ? 1.0 : (1.3 - q) / 0.42) * fade;
        if (a <= arcaneBayer(x.toDouble(), y.toDouble()) * (q < 0.66 ? 0.2 : 1.0)) {
          continue;
        }
        p.px(x, y, col[lv]);
      }
      if ((h & 7) == 0 && h < _top - ww * 2.4 - 8.0) {
        p.glow(0, y, ww * 2.4 + 6.0, c[5], 0.3 * fade);
      }
    }

    for (var i = 0; i < 6; i++) {
      final k = (t - (_flash + 0.08 + i * 0.16)) / 0.8;
      if (k < 0.0 || k > 1.0) continue;
      final rx = w * 1.4 * (1.0 + k * 0.35);
      final ry = rx * 0.3;
      final yc = -3.0 - Ease.outQuad(k) * 120.0;
      final n = (rx * 7.0).ceil();
      for (var j = 0; j < n; j++) {
        final g = (j / n) * tau;
        p.dot(
          math.cos(g) * rx,
          yc + math.sin(g) * ry,
          k < 0.3 ? kWhite : c[6],
          (1.0 - k) * fade * (math.sin(g) < 0.0 ? 0.6 : 1.0),
        );
      }
    }
    p.glow(0, -4, 34, c[6], 0.45 * fade);
    p.glow(0, -60, 70, c[4], 0.25 * fade);
  }

  void _shock(Painter p, bool far) {
    for (final spec in const [
      (0.0, _r * 0.6, _r * 2.0, 6.0, 0.5),
      (0.08, _r * 0.4, _r * 1.4, 3.0, 0.4),
    ]) {
      final (d, r0, r1, th, dur) = spec;
      final k = (t - _flash - d) / dur;
      if (k < 0.0 || k >= 1.0) continue;
      band(
        p,
        0,
        0,
        r0 + (r1 - r0) * Ease.outCubic(k),
        _sy,
        math.max(1.0, th * (1.0 - k)),
        1.15 - k,
        [c[3], c[5], c[6], kWhite],
        keep: (g) => (math.sin(g) < 0.0) == far,
        hot: k < 0.2,
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t > _pen.$1 && t < _star.$2 && rg.chance(0.5)) {
      final double x;
      final double y;
      if (t < _pen.$2) {
        final g = math.pi / 2.0 +
            rg.sign() * ((t - _pen.$1) / (_pen.$2 - _pen.$1)) * math.pi;
        x = math.cos(g) * _r;
        y = math.sin(g) * _r * _sy;
      } else if (t < _inner.$2) {
        final g = -math.pi / 2.0 +
            ((t - _inner.$1) / (_inner.$2 - _inner.$1)) * tau;
        x = math.cos(g) * _ri;
        y = math.sin(g) * _ri * _sy;
      } else {
        final active =
            edges.where((e) => t >= e.t0 && t < e.t0 + e.dur).toList();
        final e = active.isNotEmpty ? rg.pick(active) : edges[0];
        final s = clamp((t - e.t0) / e.dur);
        x = e.p0.$1 + (e.p1.$1 - e.p0.$1) * s;
        y = (e.p0.$2 + (e.p1.$2 - e.p0.$2) * s) * _sy;
      }
      ps.spawn(
        P.ember,
        x,
        y - 1.0,
        rg.range(-12.0, 12.0),
        rg.range(-30.0, -8.0),
        rg.range(0.25, 0.55),
        c[6],
        1.0,
      );
    }

    if (t > _runes.$2 - 0.1 && t < _flash - 0.05 && rg.chance(0.7)) {
      final g = rg.range(0.0, tau);
      final d = rg.range(_r * 0.7, _r * 1.1);
      final life = rg.range(0.16, 0.24);
      final v = (d * 3.0) / (math.exp(3.0 * life) - 1.0);
      final x = math.cos(g) * d;
      final y = math.sin(g) * d * _sy - 1.0;
      final rawL = hypot(x, y + 2.0);
      final l = rawL == 0.0 ? 1.0 : rawL;
      ps.spawn(
        P.streak,
        x,
        y,
        (-x / l) * v,
        ((-2.0 - y) / l) * v,
        life,
        rg.chance(0.5) ? c[6] : c[5],
      );
    }

    if (!flashed && t >= _flash) {
      flashed = true;
      lights.add(0, -56, 104, c[5], 0.9, 0.6);
      lights.add(0, -5, 36, kWhite, 0.8, 0.14);
      for (var i = 0; i < 36; i++) {
        final s = rg.sign();
        final sp = rg.range(80.0, 175.0);
        ps.spawn(
          P.spark,
          s * rg.range(0.0, _r * 0.5),
          -1.0,
          s * sp,
          -rg.range(30.0, 180.0),
          rg.range(0.25, 0.7),
        );
      }
      for (var i = 0; i < 26; i++) {
        ps.spawn(
          P.star,
          rg.range(-_r, _r),
          -rg.range(1.0, 6.0),
          rg.range(-20.0, 20.0),
          -rg.range(40.0, 130.0),
          rg.range(0.5, 1.1),
          rg.pick([kWhite, c[6], c[5]]),
          rg.range(0.8, 2.3),
        );
      }
      for (var i = 0; i < 34; i++) {
        final s = rg.sign();
        ps.spawn(
          P.star,
          s * rg.range(0.0, 14.0),
          -rg.range(1.0, 4.0),
          s * rg.range(50.0, 140.0),
          -rg.range(10.0, 90.0),
          rg.range(0.4, 0.95),
          rg.pick([kWhite, c[6], c[6], c[5]]),
          rg.range(0.7, 2.2),
        );
      }
    }

    if (t > _runes.$1 && t < _breakT + 0.2 && rg.chance(0.12)) {
      final g = rg.range(0.0, tau);
      final r = rg.pick([_r, _r2, _ri]);
      ps.spawn(
        P.star,
        math.cos(g) * r,
        math.sin(g) * r * _sy - 0.5,
        0.0,
        -rg.range(2.0, 8.0),
        rg.range(0.25, 0.45),
        rg.pick([kWhite, c[6]]),
        rg.range(0.8, 2.0),
      );
    }

    if (t > _flash && t < _breakT) {
      if (rg.chance(0.5)) {
        ps.spawn(
          P.star,
          rg.range(-1.0, 1.0) * _w * 1.5,
          -rg.range(0.0, 120.0),
          rg.range(-10.0, 10.0),
          -rg.range(30.0, 85.0),
          rg.range(0.5, 1.1),
          rg.pick([kWhite, c[6], c[5]]),
          rg.range(0.7, 2.0),
        );
      }
      if (rg.chance(0.35)) {
        ps.spawn(
          P.mote,
          rg.range(-1.0, 1.0) * _w * 0.8,
          -rg.range(0.0, 50.0),
          0.0,
          -rg.range(160.0, 300.0),
          rg.range(0.2, 0.35),
          rg.chance(0.5) ? kWhite : c[6],
          0.8,
        );
      }
    }

    if (!broke && t >= _breakT) {
      broke = true;
      for (var i = 0; i < 46; i++) {
        ps.spawn(
          P.star,
          rg.range(-1.0, 1.0) * _w * 0.9,
          -rg.range(2.0, _top * 0.8),
          rg.range(-12.0, 12.0),
          -rg.range(8.0, 40.0),
          rg.range(0.5, 1.15),
          rg.pick([kWhite, kWhite, c[6], c[5]]),
          rg.range(0.6, 2.4),
        );
      }
    }
    if (t > _breakT && t < _breakT + 0.4 && rg.chance(0.8)) {
      ps.spawn(
        P.star,
        rg.range(-1.0, 1.0) * _w * 0.7,
        -rg.range(2.0, _top * 0.78),
        rg.range(-8.0, 8.0),
        -rg.range(10.0, 50.0),
        rg.range(0.4, 0.9),
        rg.pick([kWhite, c[6], c[5]]),
        rg.range(0.6, 1.8),
      );
      if (rg.chance(0.4)) {
        ps.spawn(
          P.mote,
          rg.range(-1.0, 1.0) * _w * 0.5,
          -rg.range(2.0, _top * 0.7),
          0.0,
          -rg.range(60.0, 140.0),
          rg.range(0.2, 0.4),
          c[6],
          0.7,
        );
      }
    }

    for (var k = 0; k < _nrune; k++) {
      if (!out[k] && t >= _runeOut(k)) {
        out[k] = true;
        final g = _runeAngle(k);
        final x = math.cos(g) * _rr;
        final y = math.sin(g) * _rr * _sy - 5.0;
        for (var i = 0; i < 4; i++) {
          ps.spawn(
            P.star,
            x + rg.range(-2.0, 2.0),
            y + rg.range(-2.0, 2.0),
            rg.range(-14.0, 14.0),
            -rg.range(10.0, 40.0),
            rg.range(0.3, 0.55),
            rg.pick([kWhite, c[6]]),
            rg.range(0.6, 1.6),
          );
        }
      }
    }

    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final lvl = _level(t);
    if (t < _gone) {
      final k = lvl * smooth(_pen.$1, _pen.$2 + 0.2, t);
      p.glow(0, 0, _r * 1.3, c[4], 0.28 * k);
      for (final s in const [-1.0, 1.0]) {
        p.glow(s * _r * 0.6, 1, _r * 0.7, c[5], 0.12 * k);
      }
    }
    _shock(p, true);
    _circle(p, true);
    _runesDraw(p, true);
    _column(p);
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    _shock(p, false);
    _circle(p, false);
    _runesDraw(p, false);
    void pen(double x, double y) {
      sparkle(p, x, y, 2, c[6], c[5], 0.5);
      p.glow(x, y, 7, c[6], 0.45);
    }

    if (t > _pen.$1 && t < _pen.$2) {
      for (final s in const [-1.0, 1.0]) {
        final g =
            math.pi / 2.0 + s * ((t - _pen.$1) / (_pen.$2 - _pen.$1)) * math.pi;
        pen(math.cos(g) * _r, math.sin(g) * _r * _sy);
      }
    }
    if (t > _inner.$1 && t < _inner.$2) {
      final g =
          -math.pi / 2.0 + ((t - _inner.$1) / (_inner.$2 - _inner.$1)) * tau;
      pen(math.cos(g) * _ri, math.sin(g) * _ri * _sy);
    }
    for (final e in edges) {
      if (t > e.t0 && t < e.t0 + e.dur) {
        final s = (t - e.t0) / e.dur;
        pen(e.p0.$1 + (e.p1.$1 - e.p0.$1) * s,
            (e.p0.$2 + (e.p1.$2 - e.p0.$2) * s) * _sy);
      }
    }
    if (t >= _flash && t < _flash + 0.24) {
      final a = (t - _flash) / 0.24;
      flare(p, 0, -8, 34.0 * math.pow(1.0 - a, 1.5), 1.0 - a, c);
      p.glow(0, -26, 56, kWhite, 0.5 * (1.0 - a));
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect magicCircleCastEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'arcane/magic-circle-cast',
    name: 'Magic circle cast',
    desc:
        'A circle draws itself on the floor, runes ignite one by one, it flashes, and a column of light fires up and breaks apart into glints.',
    category: 'arcane',
    tags: [
      'arcane',
      'magic',
      'circle',
      'rune',
      'cast',
      'column',
      'summon',
      'ground',
      'one-shot',
    ],
    size: (200, 220),
    origin: (100, 192),
    duration: _end,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {'palette': Pal.arcane, 'seed': 6},
  ),
  onCreate: (o) => _MagicCircleCastSim(o),
);
