// The impact flash, cracks racing out from the impact, the white flash before the burst, and the glass
// splinters, glints and cold light of the burst are adapted from Sprite Fusion's open-source ice shatter
// (https://www.spritefusion.com/pixel-art-vfx/ice), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'transitions_lib.dart';

const double _duration = 2.8;
const double _land = 0.55;
const double _gp = (2.0 * kScreenH) / (_land * _land);
const double _rest = 0.3;
const double _crack = 1.32;
const double _breakTime = 1.62;
const double _wave = 520.0;
const double _lx = -0.6;
const double _ly = -0.8;
const List<double> _l3 = [-0.42, -0.56, 0.71];

final List<({double t0, double v, double tLen})> _bounces = (() {
  final out = <({double t0, double v, double tLen})>[];
  var t0 = _land;
  var v = _gp * _land * _rest;
  for (var k = 0; k < 3; k++) {
    final tLen = (2.0 * v) / _gp;
    out.add((t0: t0, v: v, tLen: tLen));
    t0 += tLen;
    v *= _rest;
  }
  return out;
})();

double _paneY(double t) {
  if (t < _land) return -kScreenH + 0.5 * _gp * t * t;
  for (final b in _bounces) {
    if (t < b.t0 + b.tLen) {
      final dt = t - b.t0;
      return -(b.v * dt - 0.5 * _gp * dt * dt);
    }
  }
  return 0.0;
}

class _CrackPx {
  final int x;
  final int y;
  final double t0;

  const _CrackPx(this.x, this.y, this.t0);
}

class _ShardCell {
  final List<(double, double)> pts;
  final List<(double, double)> lp;
  double cx;
  double cy;
  final double d;
  final double r;
  final double tb;
  bool broke = false;
  bool gone = false;
  double vx = 0.0;
  double vy = 0.0;
  double a = 0.0;
  double va = 0.0;
  double phi = 0.0;
  double vphi = 0.0;
  double psi = 0.0;
  double z = 0.0;
  double vz = 0.0;
  double g = 0.0;
  bool edgeOn = false;

  _ShardCell({
    required this.pts,
    required this.lp,
    required this.cx,
    required this.cy,
    required this.d,
    required this.r,
    required this.tb,
  });
}

class _ShatterPattern {
  final double ix;
  final double iy;
  final List<_CrackPx> cracks;
  final List<_ShardCell> cells;

  const _ShatterPattern({
    required this.ix,
    required this.iy,
    required this.cracks,
    required this.cells,
  });
}

_ShatterPattern _buildPattern(Rng r) {
  final ix = kScreenW * r.range(0.4, 0.6);
  final iy = kScreenH * r.range(0.36, 0.54);
  const nr = 13;
  const ringR = [0.0, 9.0, 21.0, 37.0, 58.0, 86.0, 122.0, 168.0, 232.0];
  final ang = List<double>.generate(
    nr,
    (i) => ((i + r.range(-0.3, 0.3)) / nr) * tau,
  );
  final speed = List<double>.generate(nr, (_) => r.range(800.0, 1300.0));
  final verts = List<List<(double, double)>>.generate(nr, (i) {
    final a = ang[i];
    return List<(double, double)>.generate(ringR.length, (j) {
      if (j == 0) return (ix, iy);
      final rr = ringR[j] * r.range(0.84, 1.16);
      final aa = a + r.range(-0.07, 0.07);
      return (ix + math.cos(aa) * rr, iy + math.sin(aa) * rr);
    });
  });

  List<(double, double)> jag((double, double) ptA, (double, double) ptB) {
    final dx = ptB.$1 - ptA.$1;
    final dy = ptB.$2 - ptA.$2;
    var len = hypot(dx, dy);
    if (len == 0.0) len = 1.0;
    final n = len > 18.0 ? 2 : 1;
    final out = <(double, double)>[ptA];
    for (var k = 1; k <= n; k++) {
      final f = k / (n + 1) + r.range(-0.08, 0.08);
      final off = r.range(-1.0, 1.0) * math.min(3.0, len * 0.07);
      out.add((
        ptA.$1 + dx * f - (dy / len) * off,
        ptA.$2 + dy * f + (dx / len) * off,
      ));
    }
    out.add(ptB);
    return out;
  }

  final rad = List<List<List<(double, double)>>>.generate(
    nr,
    (i) => List<List<(double, double)>>.generate(
      ringR.length - 1,
      (j) => jag(verts[i][j], verts[i][j + 1]),
    ),
  );
  final ring = List<List<List<(double, double)>?>>.generate(
    nr,
    (i) => List<List<(double, double)>?>.generate(
      ringR.length,
      (j) => j > 0 ? jag(verts[i][j], verts[(i + 1) % nr][j]) : null,
    ),
  );
  final keep = List<List<bool>>.generate(
    nr,
    (_) => List<bool>.generate(
      ringR.length,
      (j) => j <= 2 || j == ringR.length - 1 || r.chance(0.78 - 0.07 * j),
    ),
  );

  final cracks = <_CrackPx>[];
  double reach(int i, double x, double y) =>
      _crack + hypot(x - ix, y - iy) / speed[i];
  void trace(
    List<(double, double)> pts,
    double Function(double x, double y) when,
  ) {
    for (var k = 1; k < pts.length; k++) {
      final (ax, ay) = pts[k - 1];
      final (bx, by) = pts[k];
      final n = (hypot(bx - ax, by - ay) * 2.0).ceil();
      for (var s = 0; s < n; s++) {
        final x = ax + ((bx - ax) * s) / n;
        final y = ay + ((by - ay) * s) / n;
        if (x >= 0.0 && y >= 0.0 && x < kScreenW && y < kScreenH) {
          cracks.add(_CrackPx(x.floor(), y.floor(), when(x, y)));
        }
      }
    }
  }

  for (var i = 0; i < nr; i++) {
    for (final e in rad[i]) {
      trace(e, (x, y) => reach(i, x, y));
    }
  }
  for (var i = 0; i < nr; i++) {
    for (var j = 1; j < ringR.length - 1; j++) {
      if (!keep[i][j]) continue;
      final i2 = (i + 1) % nr;
      final e = ring[i][j]!;
      final (vx1, vy1) = verts[i][j];
      final (vx2, vy2) = verts[i2][j];
      final start = math.max(reach(i, vx1, vy1), reach(i2, vx2, vy2)) +
          r.range(0.02, 0.07);
      final (ax, ay) = e[0];
      trace(e, (x, y) => start + hypot(x - ax, y - ay) / 420.0);
    }
  }
  cracks.sort((a, b) => a.t0.compareTo(b.t0));

  final cells = <_ShardCell>[];
  for (var i = 0; i < nr; i++) {
    for (var j = 0, jb = 0; j < ringR.length - 1; j = jb + 1) {
      jb = j;
      while (!keep[i][jb + 1]) {
        jb++;
      }
      final i2 = (i + 1) % nr;
      List<(double, double)> side(int rIdx) {
        final res = <(double, double)>[];
        for (var k = j; k <= jb; k++) {
          final e = rad[rIdx][k];
          if (k > j) {
            res.addAll(e.skip(1));
          } else {
            res.addAll(e);
          }
        }
        return res;
      }

      final pts = <(double, double)>[
        ...side(i),
        ...ring[i][jb + 1]!.skip(1),
        ...side(i2).reversed.skip(1),
      ];
      if (j > 0) {
        final rev = ring[i][j]!.reversed.toList();
        if (rev.length > 2) {
          pts.addAll(rev.sublist(1, rev.length - 1));
        }
      } else {
        pts.removeLast();
      }

      var x0 = double.infinity;
      var y0 = double.infinity;
      var x1 = double.negativeInfinity;
      var y1 = double.negativeInfinity;
      for (final (x, y) in pts) {
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
      if (x1 < 0.0 || y1 < 0.0 || x0 >= kScreenW || y0 >= kScreenH) continue;
      final cx = (clamp(x0, 0.0, kScreenW.toDouble()) +
              clamp(x1, 0.0, kScreenW.toDouble())) /
          2.0;
      final cy = (clamp(y0, 0.0, kScreenH.toDouble()) +
              clamp(y1, 0.0, kScreenH.toDouble())) /
          2.0;
      final d = hypot(cx - ix, cy - iy);
      cells.add(
        _ShardCell(
          pts: pts,
          lp: [for (final (x, y) in pts) (x - cx, y - cy)],
          cx: cx,
          cy: cy,
          d: d,
          r: hypot(x1 - x0, y1 - y0) / 2.0,
          tb: _breakTime + d / _wave + r.range(0.0, 0.04),
        ),
      );
    }
  }
  return _ShatterPattern(ix: ix, iy: iy, cracks: cracks, cells: cells);
}

void _drawShard(
  Painter p,
  Painter p0,
  _ShardCell s,
  List<int> c,
  int ink,
  bool still,
) {
  List<(double, double)> pts;
  var face = ink;
  var sliver = false;
  var gl = 0.0;

  if (still) {
    pts = s.pts;
  } else {
    final cp = math.cos(s.phi);
    final sp = math.sin(s.phi);
    final ci = math.cos(s.psi);
    final si = math.sin(s.psi);
    final ca = math.cos(s.a);
    final sa = math.sin(s.a);
    final k = 1.0 / (1.0 + s.z);
    pts = [
      for (final (x, y) in s.lp)
        () {
          final u = x * ci + y * si;
          final v = (-x * si + y * ci) * cp;
          final qx = u * ci - v * si;
          final qy = u * si + v * ci;
          return (
            s.cx + (qx * ca - qy * sa) * k,
            s.cy + (qx * sa + qy * ca) * k,
          );
        }(),
    ];
    final nx0 = si * sp;
    final ny0 = -ci * sp;
    final nz = cp;
    final nx = nx0 * ca - ny0 * sa;
    final ny = nx0 * sa + ny0 * ca;
    final d = (nx * _l3[0] + ny * _l3[1] + nz * _l3[2]).abs();
    gl = math.pow(d, 6.0).toDouble();
    final graze = clamp(1.0 - cp.abs() / 0.3);
    face = mix(mix(ink, c[2], 0.12 + 0.4 * gl), c[3], 0.55 * graze * graze);
    sliver = cp.abs() < 0.2;
    if (cp.abs() * s.r < 1.5) face = c[5];
  }

  fillConvex(p0, pts, face);
  var a2 = 0.0;
  for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    a2 += pts[j].$1 * pts[i].$2 - pts[i].$1 * pts[j].$2;
  }
  final sg = a2 > 0.0 ? 1.0 : -1.0;
  for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    final (ax, ay) = pts[j];
    final (bx, by) = pts[i];
    final dx = bx - ax;
    final dy = by - ay;
    final len = hypot(dx, dy);
    if (len < 0.5) continue;
    final mx = (dy / len) * sg;
    final my = (-dx / len) * sg;
    final el = mx * _lx + my * _ly;
    if (still) {
      p.line(ax, ay, bx, by, el > 0.0 ? c[5] : c[4]);
      continue;
    }
    if (el > 0.2 || sliver) {
      p.line(ax - mx, ay - my, bx - mx, by - my, c[4]);
      p.line(ax, ay, bx, by, gl > 0.5 || sliver ? kWhite : c[6]);
      p.glow(
        (ax + bx) / 2.0,
        (ay + by) / 2.0,
        math.min(12.0, 4.0 + len * 0.3),
        c[5],
        0.12 + 0.3 * gl,
      );
    } else {
      p.line(ax, ay, bx, by, el > -0.3 ? c[4] : c[2]);
    }
  }
}

class _ShatterWipeSim extends BaseEffectSim {
  final List<int> c;
  final int ink;
  final Rng r;
  final _ShatterPattern pat;
  final Particles ps;
  final Bits bits = Bits();
  final Lights lights = Lights();
  double t = 0.0;
  int bounce = -1;
  bool struck = false;
  bool burst = false;
  final double end = _duration - 0.05;

  factory _ShatterWipeSim.create(Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final ink = hex(o['color'] ?? '#0b0a10');
    final r = Rng(o.seed);
    final pat = _buildPattern(r);
    final ps = Particles(
      rng: r,
      sparks: [c[7], c[6], c[5], c[4]],
      haze: c[5],
    );
    return _ShatterWipeSim._(c, ink, r, pat, ps);
  }

  _ShatterWipeSim._(this.c, this.ink, this.r, this.pat, this.ps);

  void _splinters(
    double x,
    double y,
    int n,
    double vx,
    double vy,
    double spread,
    double sp0,
    double sp1,
  ) {
    for (var i = 0; i < n; i++) {
      final a = math.atan2(vy, vx) + r.range(-spread, spread);
      final sp = r.range(sp0, sp1);
      final life = math.min(r.range(0.6, 1.2), end - t);
      if (life > 0.2) {
        bits.add(
          DebrisBit(
            kind: DebrisKind.shard,
            x: x,
            y: y,
            vx: math.cos(a) * sp,
            vy: math.sin(a) * sp,
            g: 0.8,
            drag: 0.6,
            life: life,
            a: r.range(0.0, tau),
            va: r.range(-20.0, 20.0),
            s: r.range(1.5, 3.5),
            c: r.pick([c[7], c[6], c[5]]),
          ),
        );
      }
    }
  }

  void _glint(double x, double y, [double? size]) {
    final s = size ?? r.range(1.0, 2.4);
    ps.spawn(
      P.star,
      x,
      y,
      r.range(-8.0, 8.0),
      r.range(-10.0, 4.0),
      math.min(r.range(0.3, 0.6), end - t),
      r.chance(0.5) ? kWhite : c[6],
      s,
    );
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    while (bounce + 1 < _bounces.length && t >= _bounces[bounce + 1].t0) {
      final k = _bounces[++bounce].v / _bounces[0].v;
      if (k < 0.05) continue;
      for (var i = 0; i < 5; i++) {
        lights.add(
          kScreenW * (i + 0.5) / 5.0,
          kScreenH - 2.0,
          70.0,
          c[5],
          0.5 * k,
          0.35,
        );
      }
      final nSplinters = (26.0 * k + 0.5).floor();
      for (var i = 0; i < nSplinters; i++) {
        _splinters(
          r.range(4.0, kScreenW - 4.0),
          kScreenH - 1.0,
          1,
          r.range(-0.4, 0.4),
          -1.0,
          0.5,
          120.0 * k,
          330.0 * k,
        );
      }
      final nGlints = (9.0 * k + 0.5).floor();
      for (var i = 0; i < nGlints; i++) {
        _glint(r.range(8.0, kScreenW - 8.0), kScreenH - r.range(2.0, 10.0));
      }
    }

    if (!struck && t >= _crack) {
      struck = true;
      lights.add(pat.ix, pat.iy, 90.0, c[5], 0.8, 0.35);
      lights.add(pat.ix, pat.iy, 34.0, kWhite, 0.9, 0.1);
      _splinters(pat.ix, pat.iy, 16, 0.0, -1.0, math.pi, 60.0, 240.0);
      for (var i = 0; i < 5; i++) {
        ps.spawn(
          P.vapour,
          pat.ix,
          pat.iy,
          r.range(-40.0, 40.0),
          r.range(-40.0, 30.0),
          r.range(0.35, 0.6),
          c[6],
          r.range(2.0, 3.5),
        );
      }
    }

    if (t > _crack && t < _breakTime && r.chance(0.12)) {
      final ck = pat.cracks[r.intRange(0, pat.cracks.length - 1)];
      if (ck.t0 < t) _glint(ck.x.toDouble(), ck.y.toDouble(), r.range(0.6, 1.6));
    }

    if (!burst && t >= _breakTime) {
      burst = true;
      lights.add(pat.ix, pat.iy, 170.0, c[4], 0.55, 0.5);
      lights.add(pat.ix, pat.iy, 60.0, kWhite, 0.8, 0.14);
      _splinters(pat.ix, pat.iy, 46, 0.0, -1.0, math.pi, 90.0, 340.0);
      for (var i = 0; i < 14; i++) {
        final a = r.range(0.0, tau);
        final sp = r.range(30.0, 110.0);
        ps.spawn(
          P.vapour,
          pat.ix + math.cos(a) * 4.0,
          pat.iy + math.sin(a) * 4.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.45, 0.8),
          r.chance(0.6) ? c[6] : c[5],
          r.range(3.0, 6.0),
        );
      }
    }

    for (final s in pat.cells) {
      if (!s.broke && t >= s.tb) {
        s.broke = true;
        final dx = s.cx - pat.ix;
        final dy = s.cy - pat.iy;
        var d = hypot(dx, dy);
        if (d == 0.0) d = 1.0;
        final sp = r.range(40.0, 130.0) * (1.15 - math.min(1.0, s.d / 260.0));
        s.vx = (dx / d) * sp + r.range(-15.0, 15.0);
        s.vy = (dy / d) * sp * 0.6 - r.range(20.0, 90.0);
        s.a = 0.0;
        s.va = r.range(-2.5, 2.5) * (1.0 + 20.0 / (s.r + 10.0));
        s.phi = 0.0;
        s.vphi = r.sign() * r.range(3.0, 9.0);
        s.psi = r.range(0.0, tau);
        s.z = 0.0;
        s.vz = r.range(0.25, 0.7);
        s.g = r.range(0.85, 1.1);
        s.edgeOn = false;
        _splinters(
          s.cx,
          s.cy,
          s.r > 24.0 ? 4 : 2,
          s.vx,
          s.vy,
          1.2,
          60.0,
          220.0,
        );
        if (r.chance(0.15)) {
          _glint(s.cx + r.range(-4.0, 4.0), s.cy + r.range(-4.0, 4.0));
        }
      }
      if (!s.broke || s.gone) continue;
      s.vy += 950.0 * s.g * dt;
      s.vx -= s.vx * 0.3 * dt;
      s.cx += s.vx * dt;
      s.cy += s.vy * dt;
      s.a += s.va * dt;
      s.phi += s.vphi * dt;
      s.z += s.vz * dt;
      final on = math.cos(s.phi).abs() < 0.2;
      if (on && !s.edgeOn && t < end - 0.3) {
        _glint(s.cx, s.cy, r.range(1.4, 2.6));
      }
      s.edgeOn = on;
      if (s.cy - s.r / (1.0 + s.z) > kScreenH + 2) s.gone = true;
    }

    ps.update(dt);
    bits.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p0) {
    final p = clipTo(p0);
    if (t < _breakTime) {
      final yb = _paneY(t) + kScreenH;
      final r1 = math.min(kScreenH, yb.floor());
      if (r1 > 0) {
        fastRect(p0, 0.0, 0.0, kScreenW.toDouble(), r1.toDouble(), ink);
        final shine = 1.0 - smooth(0.98, 1.22, t);
        final y0 = yb - kScreenH;
        if (shine > 0.0) {
          for (final (off, w, a) in const [
            (0.0, 16.0, 0.05),
            (22.0, 3.0, 0.1),
            (30.0, 1.0, 0.12),
          ]) {
            for (var y = 0; y < r1; y++) {
              final xc = kScreenW * 0.18 + off + (kScreenH - (y - y0)) * 0.7;
              final x0 = math.max(0, (xc - w / 2.0).floor());
              final x1 = math.min(kScreenW, (xc + w / 2.0).ceil());
              for (var x = x0; x < x1; x++) {
                p0.blend(x + 0.5, y + 0.5, c[6], a * shine);
              }
            }
          }
          final st = shine > 0.66 ? 0 : (shine > 0.33 ? 1 : 2);
          for (final (dy, col) in [
            (1, c[6 - st * 2]),
            (2, c[4 - st]),
            (3, c[math.max(1, 2 - st)]),
          ]) {
            if (r1 - dy >= 0 && r1 - dy < kScreenH) {
              fastRect(
                p0,
                0.0,
                (r1 - dy).toDouble(),
                kScreenW.toDouble(),
                1.0,
                col,
              );
            }
          }
          final gx = kScreenW * clamp(t / (_land + 0.25)) * 1.2 - 20.0;
          for (var x = 0; x < kScreenW; x++) {
            final k = math.max(0.0, 1.0 - (x - gx).abs() / 28.0);
            if (k > 0.0 && r1 - 1 < kScreenH) {
              p0.px(x.toDouble(), (r1 - 1).toDouble(), k > 0.5 ? kWhite : c[6]);
              p0.light(x.toDouble(), (r1 - 1).toDouble(), c[6], 0.5 * k);
            }
            for (var d = 0; d < 14 && r1 + d < kScreenH; d++) {
              final dd = 1.0 - d / 14.0;
              p0.light(
                x.toDouble(),
                (r1 + d).toDouble(),
                c[5],
                0.3 * shine * dd * dd * (0.6 + 0.8 * k),
              );
            }
          }
          if (t < _land + 0.25 && gx > 0.0 && gx < kScreenW && r1 - 1 < kScreenH) {
            sparkle(p, gx, (r1 - 1).toDouble(), 6.0, c[6], c[4], 0.5);
          }
        }
      }
      if (t >= _crack) {
        for (final ck in pat.cracks) {
          if (ck.t0 > t) break;
          final age = t - ck.t0;
          if (ck.x + 1 < kScreenW && ck.y + 1 < kScreenH) {
            p0.px((ck.x + 1).toDouble(), (ck.y + 1).toDouble(), c[1]);
          }
          p0.px(
            ck.x.toDouble(),
            ck.y.toDouble(),
            age < 0.04 ? kWhite : (age < 0.18 ? c[6] : c[5]),
          );
          if (age < 0.3) {
            p0.light(
              ck.x.toDouble(),
              ck.y.toDouble(),
              c[5],
              0.55 * (1.0 - age / 0.3),
            );
          }
        }
        final u = (t - _crack) / 0.22;
        if (u < 1.0) {
          flare(p, pat.ix, pat.iy, 30.0 * math.pow(1.0 - u, 1.5), 1.0 - u, c);
          p.glow(pat.ix, pat.iy, 50.0, kWhite, 0.7 * (1.0 - u));
        }
        final w = (t - (_breakTime - 0.07)) / 0.07;
        if (w > 0.0) {
          for (final ck in pat.cracks) {
            p0.px(ck.x.toDouble(), ck.y.toDouble(), kWhite);
            p0.light(ck.x.toDouble(), ck.y.toDouble(), c[6], 0.4 * w);
          }
        }
      }
    } else {
      final fall = [
        for (final s in pat.cells)
          if (s.broke && !s.gone) s,
      ]..sort((a, b) => b.z.compareTo(a.z));
      for (final s in pat.cells) {
        if (!s.broke) _drawShard(p, p0, s, c, ink, true);
      }
      for (final s in fall) {
        _drawShard(p, p0, s, c, ink, false);
      }
    }
    bits.draw(p);
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect shatterWipeEffect = SimulatedEffect(
  meta: screenMeta(
    id: 'transitions/shatter-wipe',
    name: 'Shatter wipe',
    desc:
        'A dark glass pane drops over the screen and bounces; cracks race out from an impact with a flash, then it bursts into tumbling glass shards with lit edges that fall away.',
    tags: const ['shatter', 'glass', 'break', 'shards', 'wipe'],
    duration: _duration,
    options: const {
      'palette': [
        '#0c1430',
        '#162c5c',
        '#1f4f94',
        '#2f7fcc',
        '#58b4ec',
        '#9bdcff',
        '#d8f4ff',
        '#ffffff',
      ],
      'seed': 2,
    },
  ),
  onCreate: _ShatterWipeSim.create,
);
