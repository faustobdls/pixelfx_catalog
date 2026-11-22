// Shared by the nature effects: faceted stones that tumble and break, the stone spike they break from, leaves,
// droplets, bubbles and gas. The gas (puffs that drift off their push, rise, swell and thin, a lit cap) is adapted
// from Sprite Fusion's open-source poison (https://www.spritefusion.com/pixel-art-vfx/poison), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

class RockBit extends DebrisBit {
  final List<Point2> pts;
  bool dusted = false;

  RockBit({
    super.kind = DebrisKind.chunk,
    required super.x,
    required super.y,
    super.vx = 0.0,
    super.vy = 0.0,
    super.g = 1.0,
    super.drag = 0.0,
    super.bounce = 0.0,
    super.life = 1.0,
    super.a = 0.0,
    super.va = 0.0,
    super.s = 1.0,
    required this.pts,
  });
}

/// Corners of an irregular stone, unit size, in angular order.
List<Point2> stoneShape(Rng r, [int? n]) {
  final count = n ?? r.intRange(5, 7);
  final pts = <Point2>[];
  final a0 = r.range(0, tau);
  final squash = r.range(0.7, 1);
  for (var i = 0; i < count; i++) {
    final a = a0 + ((i + r.range(-0.28, 0.28)) * tau) / count;
    final rad = r.range(0.72, 1.12);
    pts.add((math.cos(a) * rad, math.sin(a) * rad * squash));
  }
  return pts;
}

const double _lx = -0.6;
const double _ly = -0.8;

bool _inPoly(List<Point2> v, double x, double y) {
  var inside = false;
  for (var i = 0, j = v.length - 1; i < v.length; j = i++) {
    final (xi, yi) = v[i];
    final (xj, yj) = v[j];
    if ((yi > y) != (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

final Uint8List _mask = Uint8List(64 * 64);
final Int8List _face = Int8List(64 * 64);
const int _rows = 400;
final Float32List _rl = Float32List(_rows);
final Float32List _rr = Float32List(_rows);
final Float32List _ru = Float32List(_rows);

/// A faceted stone at (x, y): corners [pts] (from [stoneShape]) scaled by [s] and turned by [a]. Each wedge
/// between neighbouring corners is a facet, lit by how squarely it faces the top left; edges facing the light
/// catch a bright rim, a dark rim goes round the rest. [rampColors]: stone ramp, dark to bright (7+ steps).
/// [alpha] dithers it out.
void drawRock(
  Painter p,
  double x,
  double y,
  double s,
  double a,
  List<Point2> pts,
  List<int> rampColors, [
  double alpha = 1.0,
  bool white = false,
]) {
  final n = rampColors.length;
  final top = n - 2;
  final ca = math.cos(a);
  final sa = math.sin(a);
  if (s < 1.4) {
    p.dot(x, y, rampColors[top - 1], alpha);
    p.dot(x + 1, y, rampColors[top - 3], alpha);
    return;
  }
  final v = pts
      .map((pt) => ((pt.$1 * ca - pt.$2 * sa) * s, (pt.$1 * sa + pt.$2 * ca) * s))
      .toList(growable: false);
  final ang = v.map((pt) => math.atan2(pt.$2, pt.$1)).toList(growable: false);
  final lit = List<double>.generate(v.length, (i) {
    final (ax, ay) = v[i];
    final (bx, by) = v[(i + 1) % v.length];
    final ex = bx - ax;
    final ey = by - ay;
    final l = hypot(ex, ey);
    final len = l == 0.0 ? 1.0 : l;
    var nx = ey / len;
    var ny = -ex / len;
    if (nx * (ax + bx) + ny * (ay + by) < 0) {
      nx = -nx;
      ny = -ny;
    }
    return nx * _lx + ny * _ly;
  }, growable: false);

  final x0 = x.floor() - (s * 1.25).ceil() - 1;
  final y0 = y.floor() - (s * 1.25).ceil() - 1;
  final box = math.min(62, 2 * (s * 1.25).ceil() + 3);
  for (var j = 0; j < box; j++) {
    for (var i = 0; i < box; i++) {
      final dx = x0 + i + 0.5 - x;
      final dy = y0 + j + 0.5 - y;
      final k = j * 64 + i;
      _mask[k] = _inPoly(v, dx, dy) ? 1 : 0;
      if (_mask[k] == 0) continue;
      final g = math.atan2(dy, dx);
      var f = 0;
      for (var q = 0; q < ang.length; q++) {
        final a0 = ang[q];
        final a1 = ang[(q + 1) % ang.length];
        var d = (g - a0).remainder(tau);
        var span = (a1 - a0).remainder(tau);
        if (d < 0) d += tau;
        if (span < 0) span += tau;
        if (d <= span) {
          f = q;
          break;
        }
      }
      _face[k] = f;
    }
  }

  bool at(int i, int j) =>
      i >= 0 && j >= 0 && i < box && j < box && _mask[j * 64 + i] == 1;

  for (var j = -1; j <= box; j++) {
    for (var i = -1; i <= box; i++) {
      final px = x0 + i;
      final py = y0 + j;
      if (!at(i, j)) {
        if (at(i - 1, j) || at(i + 1, j) || at(i, j - 1) || at(i, j + 1)) {
          p.dot(px, py, rampColors[0], alpha);
        }
        continue;
      }
      if (white) {
        p.dot(px, py, kWhite, alpha);
        continue;
      }
      final lVal = lit[_face[j * 64 + i]];
      final edge =
          !at(i - 1, j) || !at(i + 1, j) || !at(i, j - 1) || !at(i, j + 1);
      var c = lVal > 0.55
          ? rampColors[top]
          : lVal > 0.15
              ? rampColors[top - 1]
              : lVal > -0.3
                  ? rampColors[top - 2]
                  : rampColors[top - 3];
      if (edge) {
        c = lVal > 0.3
            ? rampColors[top + 1]
            : lVal < -0.2
                ? rampColors[math.max(1, top - 4)]
                : c;
      }
      p.dot(px, py, c, alpha);
    }
  }
}

class SpikeNotch {
  final double u;
  final int side;
  final double d;

  const SpikeNotch({required this.u, required this.side, required this.d});
}

class SpikeLook {
  final List<SpikeNotch> notches;
  final List<double> strata;
  final double slope;
  final int seed;

  const SpikeLook({
    required this.notches,
    required this.strata,
    required this.slope,
    required this.seed,
  });
}

class SpikeDrawOpts {
  final double a;
  final bool white;
  final double glint;
  final double clip;
  final int half;
  final double floor;
  final List<List<Point2>>? cracks;
  final double crack;
  final double heat;
  final List<int>? glowRamp;

  const SpikeDrawOpts({
    this.a = 1.0,
    this.white = false,
    this.glint = -1.0,
    this.clip = 1.0,
    this.half = 0,
    this.floor = double.infinity,
    this.cracks,
    this.crack = 0.0,
    this.heat = 0.0,
    this.glowRamp,
  });
}

/// A faceted stone spike standing on (x, base): [h] tall, [w] wide at the base, its tip [lean] px over.
void drawSpike(
  Painter p,
  double x,
  double base,
  double h,
  double w,
  double lean,
  SpikeLook sp,
  List<int> rampColors, [
  SpikeDrawOpts opts = const SpikeDrawOpts(),
]) {
  if (h < 1.5) return;
  final a = opts.a;
  final white = opts.white;
  final glint = opts.glint;
  final clip = opts.clip;
  final floorY = opts.floor;

  double hw(double u, int side) {
    var v = (w / 2.0) * math.pow(math.max(0.0, 1.0 - u), 0.85) + 0.3;
    for (final n in sp.notches) {
      if (n.side == side && u > n.u && u < n.u + 0.07) {
        v -= n.d * (1.0 - u * 0.5);
      }
    }
    return math.max(0.0, v);
  }

  final half = opts.half;
  final y0 = (base - h).floor() - 2;
  final nr = math.min(_rows, base.ceil() - y0 + 2);
  for (var k = 0; k < nr; k++) {
    final u = (base - (y0 + k + 0.5)) / h;
    _ru[k] = u;
    if (u < 0 || u > 1 || y0 + k + 0.5 > floorY) {
      _rl[k] = double.infinity;
      _rr[k] = double.negativeInfinity;
    } else {
      _rl[k] = x + lean * u - hw(u, -1);
      _rr[k] = x + lean * u + hw(u, 1);
    }
  }

  bool inside(int px, int py) {
    final k = py - y0;
    final fx = px + 0.5;
    if (k < 0 || k >= nr || fx < _rl[k] || fx > _rr[k]) return false;
    if (clip < 1 && _ru[k] > clip + (rand(px, 77) - 0.5) * 0.07) return false;
    if (half == 0) return true;
    final q = ((fx - _rl[k]) / math.max(0.5, _rr[k] - _rl[k])) * 2 - 1;
    return half < 0 ? q < -0.18 : q >= -0.18;
  }

  final x0 = (x - w / 2 - lean.abs() - 2).floor();
  final x1 = (x + w / 2 + lean.abs() + 2).ceil();
  for (var py = (base - h).floor() - 1; py < base.ceil(); py++) {
    for (var px = x0; px <= x1; px++) {
      if (!inside(px, py)) {
        if (py + 0.5 <= floorY &&
            (inside(px - 1, py) ||
                inside(px + 1, py) ||
                inside(px, py + 1) ||
                (inside(px, py - 1) && py < base - 1))) {
          p.dot(px, py, rampColors[0], a);
        }
        continue;
      }
      if (white) {
        p.dot(px, py, kWhite, a);
        continue;
      }
      final k0 = py - y0;
      final u = _ru[k0];
      final c = x + lean * u;
      final l = _rl[k0];
      final r = _rr[k0];
      final fx = px + 0.5;
      var band = 0;
      var st = false;
      for (final s in sp.strata) {
        final d = u * h - s * h - sp.slope * (fx - c);
        if (d > 0) band++;
        if (d.abs() < 0.5) st = true;
      }
      final jog = (rand(band, sp.seed) - 0.5) * 0.3;
      final q = ((fx - l) / math.max(0.5, r - l)) * 2 - 1;
      final qr = -0.18 + jog;
      int idx;
      if (u > 0.93) {
        idx = q < qr + 0.3 ? 7 : 5;
      } else if ((q - qr).abs() < math.max(0.09, 0.55 / math.max(1.0, r - l))) {
        idx = 7;
      } else if (q < qr) {
        idx = fx - l < 1 ? 7 : (q < -0.5 + jog ? 6 : 5);
      } else {
        idx = r - fx < 1 ? 3 : (q < 0.38 + jog ? 4 : 2);
      }
      if (st && idx < 7) idx -= 1;
      final fleck = rand(px * 7 + 3, py * 13 + 5);
      if (fleck < 0.035) {
        idx = q < qr ? 7 : idx - 1;
      } else if (fleck > 0.965) {
        idx -= 1;
      }
      if (glint >= 0 && q < qr + 0.1) {
        final g = (u - glint).abs();
        if (g < 0.035) {
          idx = 8;
        } else if (g < 0.07) {
          idx = math.max(idx, 7);
        }
      }
      p.dot(
        px,
        py,
        idx >= 8 ? kWhite : rampColors[clampInt(idx, 0, rampColors.length - 1)],
        a,
      );
    }
  }

  if (opts.cracks != null && opts.crack > 0) {
    for (final path in opts.cracks!) {
      final m = math.max(1, (path.length * opts.crack).floor());
      for (var k = 1; k < m; k++) {
        final (u0, v0) = path[k - 1];
        final (u1, v1) = path[k];
        final ax = x + lean * u0 + v0 * hw(u0, v0 < 0 ? -1 : 1);
        final ay = base - u0 * h;
        final bx = x + lean * u1 + v1 * hw(u1, v1 < 0 ? -1 : 1);
        final by = base - u1 * h;
        if (u1 > clip) break;
        if (!inside(ax.floor(), ay.floor()) || !inside(bx.floor(), by.floor())) {
          continue;
        }
        final hot = opts.heat;
        final gl = opts.glowRamp;
        if (hot > 0.05 && gl != null) {
          p.line(ax + 1, ay, bx + 1, by, rampColors[0], a);
          p.line(
            ax,
            ay,
            bx,
            by,
            hot > 0.7
                ? gl[4]
                : hot > 0.4
                    ? gl[3]
                    : hot > 0.2
                        ? gl[2]
                        : gl[1],
            a,
          );
          if (k % 2 == 0) p.glow(bx, by, 7, gl[2], 0.35 * hot);
        } else {
          p.line(ax, ay, bx, by, rampColors[0], a);
          p.dot(bx + 1, by - 1, rampColors[6], a * 0.7);
        }
      }
    }
  }
}

/// The random look of one spike: notches on its edges, strata across it.
SpikeLook spikeLook(Rng r) {
  final notches = <SpikeNotch>[];
  final strata = <double>[];
  for (var i = 0, n = r.intRange(3, 5); i < n; i++) {
    notches.add(SpikeNotch(
      u: r.range(0.1, 0.8),
      side: r.sign(),
      d: r.range(0.8, 1.8),
    ));
  }
  for (var i = 0, n = r.intRange(2, 4); i < n; i++) {
    strata.add(r.range(0.12, 0.8));
  }
  return SpikeLook(
    notches: notches,
    strata: strata,
    slope: r.range(-0.25, 0.25),
    seed: r.intRange(1, 9999),
  );
}

/// A crack that branches up a spike: points [u (height 0..1), v (-1 left edge..1 right edge)].
List<Point2> spikeCrack(Rng r, double u0, double v0, int dir) {
  final pts = <Point2>[(u0, v0)];
  var u = u0;
  var v = v0;
  for (var i = 0; i < 9; i++) {
    u += r.range(0.03, 0.08);
    v += dir * r.range(0.05, 0.28) + r.range(-0.12, 0.12);
    if (u > 0.95 || v.abs() > 1) break;
    pts.add((u, v));
  }
  return pts;
}

/// A jagged floor crack from x = 0 out to side * len: points [x, y], y 0..3 into the floor.
List<Point2> floorCrack(Rng r, int side, double len) {
  final pts = <Point2>[(0.0, 0.0)];
  for (var x = 0.0; x.abs() < len;) {
    x += side * r.range(2, 5);
    pts.add((x, r.intRange(0, 2).toDouble()));
  }
  return pts;
}

/// A leaf [len] px long and [wid] px across at its widest, centered on (x, y), turned by [ang] and flipping
/// about its midrib by [fl]. [pal]: [dark, shade, body, light] (dark to bright). [alpha] dithers it out.
void drawLeaf(
  Painter p,
  double x,
  double y,
  double len,
  double wid,
  double ang,
  double fl,
  List<int> pal, [
  double alpha = 1.0,
]) {
  final ca = math.cos(ang);
  final sa = math.sin(ang);
  final sq = math.cos(fl);
  final w = math.max(0.55, sq.abs() * wid);
  final under = sq < 0;
  final rad = (len / 2 + 2).ceil();
  final cx = (x + 0.5).floor();
  final cy = (y + 0.5).floor();

  int inside(int i, int j) {
    final u = (i + 0.5) * ca + (j + 0.5) * sa + len / 2;
    final v = -(i + 0.5) * sa + (j + 0.5) * ca;
    if (u < 0 || u > len) return 0;
    final half = w * math.pow(math.sin((math.pi * u) / len), 0.75);
    return v.abs() <= half ? (v < 0 ? 1 : 2) : 0;
  }

  for (var j = -rad; j <= rad; j++) {
    for (var i = -rad; i <= rad; i++) {
      final s = inside(i, j);
      if (s == 0) {
        if (inside(i - 1, j) != 0 ||
            inside(i + 1, j) != 0 ||
            inside(i, j - 1) != 0 ||
            inside(i, j + 1) != 0) {
          p.dot(cx + i, cy + j, pal[0], alpha);
        }
        continue;
      }
      final u = (i + 0.5) * ca + (j + 0.5) * sa + len / 2;
      final v = -(i + 0.5) * sa + (j + 0.5) * ca;
      final rib = v.abs() < 0.5 && u > len * 0.12 && u < len * 0.88 && w > 1.2;
      p.dot(
        cx + i,
        cy + j,
        rib
            ? pal[1]
            : ((s == 1) != under ? pal[3] : pal[2]),
        alpha,
      );
    }
  }
  p.dot(cx - ca * (len / 2 + 1), cy - sa * (len / 2 + 1), pal[1], alpha);
}

class Drop {
  double x;
  double y;
  double vx;
  double vy;
  final double s;
  double delay;

  Drop(this.x, this.y, this.vx, this.vy, this.s, this.delay);
}

/// Droplets of liquid: arc under gravity with a little drag, drawn as a bright bead with a short tail along
/// their motion, and land on the floor.
class Drops {
  final List<Drop> list = [];
  final double Function(double x) ground;

  Drops([double Function(double x)? ground]) : ground = ground ?? ((_) => 0.0);

  void add(
    double x,
    double y,
    double vx,
    double vy, [
    double s = 1.0,
    double delay = 0.0,
  ]) {
    list.add(Drop(x, y, vx, vy, s, delay));
  }

  void update(double dt, [void Function(Drop d, double g)? onLand]) {
    for (var i = list.length - 1; i >= 0; i--) {
      final d = list[i];
      if (d.delay > 0) {
        d.delay -= dt;
        continue;
      }
      final drag = 0.6 / d.s;
      final py = d.y;
      d.vy += kGravity * dt;
      d.vx -= d.vx * drag * dt;
      d.vy -= d.vy * drag * 0.5 * dt;
      d.x += d.vx * dt;
      d.y += d.vy * dt;
      final g = ground(d.x);
      if (d.vy > 0 && py <= g && d.y >= g) {
        onLand?.call(d, g);
        list.removeAt(i);
      }
    }
  }

  void draw(Painter p, List<int> c) {
    final n = c.length;
    for (final d in list) {
      if (d.delay > 0) continue;
      final sp = hypot(d.vx, d.vy);
      final spd = sp == 0.0 ? 1.0 : sp;
      final ux = d.vx / spd;
      final uy = d.vy / spd;
      final len = math.min(5.0, 0.5 + spd * 0.012);
      p.line(d.x - ux * len, d.y - uy * len, d.x - ux, d.y - uy, c[n - 4]);
      p.px(d.x, d.y, c[n - 1]);
      if (d.s > 1) {
        p.px(d.x - ux, d.y - uy, c[n - 2]);
        p.px(d.x + 1, d.y, c[n - 3]);
      }
      p.glow(d.x, d.y, 3 + d.s * 1.5, c[n - 2], 0.3);
    }
  }
}

/// A puff of gas: a darker belly hanging low, a body, a denser core, a lit cap up and to the left.
void gasPuff(
  Painter p,
  double x,
  double y,
  double r,
  double a,
  int belly,
  int body,
  int cap, [
  int hi = 0,
]) {
  if (a < 0.02 || r < 0.6) return;
  p.disc(x + r * 0.06, y + r * 0.28, r * 0.9, belly, a * 0.55);
  p.disc(x, y, r, body, a * 0.45);
  p.disc(x + r * 0.03, y - r * 0.02, r * 0.76, body, a * 0.5);
  p.disc(x - r * 0.2, y - r * 0.34, r * 0.52, cap, a * 0.45);
  if (hi != 0) p.disc(x - r * 0.3, y - r * 0.55, r * 0.26, hi, a * 0.32);
}

/// A bubble of radius [r] centered at (x, y): a 1 px skin, a translucent belly, a white glint.
void bubble(
  Painter p,
  double x,
  double y,
  double r,
  int c1,
  int c2,
  int fill, [
  double a = 1.0,
  bool dome = false,
]) {
  final rad = r.ceil() + 1;
  final cx = (x + 0.5).floor();
  final cy = (y + 0.5).floor();
  final jMax = dome ? 0 : rad;
  for (var j = -rad; j <= jMax; j++) {
    for (var i = -rad; i <= rad; i++) {
      final d = hypot(i.toDouble(), j.toDouble());
      if (d > r + 0.45) continue;
      if (d > r - 0.6) {
        p.dot(cx + i, cy + j, i < 0 && j < -r * 0.2 ? c1 : c2, a);
      } else {
        p.blend(cx + i, cy + j, fill, 0.3 * a);
      }
    }
  }
  if (r >= 1.5) {
    p.dot(
      cx - (r * 0.45 + 0.5).floor(),
      cy - (r * 0.5 + 0.5).floor(),
      kWhite,
      a,
    );
  }
}

class GasPuff {
  final double x;
  final double y;
  final double vx;
  final double vy;
  final double r0;
  final double r1;
  final double t0;
  final double end;
  final double rise;
  final double seed;

  const GasPuff({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.r0,
    required this.r1,
    required this.t0,
    required this.end,
    required this.rise,
    required this.seed,
  });
}

/// Puffs of gas with their own clock.
class Gas {
  final List<GasPuff> list = [];
  int _n = 0;

  void add(
    double t,
    double x,
    double y,
    double vx,
    double vy,
    double r0,
    double r1,
    double end, [
    double rise = 0.0,
  ]) {
    list.add(GasPuff(
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      r0: r0,
      r1: r1,
      t0: t,
      end: end,
      rise: rise,
      seed: ((_n++ * 37.7) % 100.0),
    ));
  }

  void prune(double t) {
    for (var i = list.length - 1; i >= 0; i--) {
      if (t > list[i].end) list.removeAt(i);
    }
  }

  ({double x, double y, double r, double a, double u}) at(
    GasPuff q,
    double t,
  ) {
    final age = t - q.t0;
    final e = 1 - math.exp(-age * 2.2);
    final sw = math.min(1.0, age);
    final x = q.x + (q.vx / 2.2) * e + math.sin(t * 1.7 + q.seed) * 2.5 * sw;
    final y = q.y +
        (q.vy / 2.2) * e -
        q.rise * age +
        math.sin(t * 1.3 + q.seed * 2) * 1.5 * sw;
    final u = clamp(age / math.max(0.01, q.end - q.t0));
    final r = q.r0 +
        (q.r1 - q.r0) * (1 - math.pow(1 - math.min(1.0, age / 1.2), 3));
    final a = clamp(age / 0.15) * (1 - clamp((u - 0.4) / 0.6));
    return (x: x, y: y, r: r, a: a, u: u);
  }

  void draw(
    Painter p,
    double t,
    int belly,
    int body,
    int cap, [
    int hi = 0,
    double k = 1.0,
    int glow = 0,
  ]) {
    for (final q in list) {
      final g = at(q, t);
      if (g.a <= 0.02) continue;
      gasPuff(p, g.x, g.y, g.r, g.a * k, belly, body, cap, g.u < 0.5 ? hi : 0);
      if (glow != 0 && g.r > 4) {
        p.glow(g.x, g.y, g.r * 1.6, glow, 0.07 * g.a * k);
      }
    }
  }
}
