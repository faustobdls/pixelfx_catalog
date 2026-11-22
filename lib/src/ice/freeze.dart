import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'ice_lib.dart';

const Pose _fear = Pose(
  turn: 0.9,
  lean: -2,
  crouch: 2,
  fx: -8,
  fy: -31,
  bx: 9,
  by: -31,
  ffx: -3,
  fbx: 4,
);
const Pose _free = Pose(
  turn: 1,
  crouch: 5,
  fx: -12,
  fy: -18,
  bx: 12,
  by: -18,
  ffx: -5,
  fbx: 6,
);

const double _duration = 4.0;
const double _snap = 0.16;
const (double, double) _climb = (0.14, 0.62);
const double _seal = 0.6;
const List<double> _sweeps = [1.12, 1.82];
const double _crack = 2.2;
const double _crack2 = 2.34;
const double _flash = 2.46;
const double _burst = 2.52;
const double _thaw = 0.36;
const (double, double) _melt = (2.95, 3.7);
const int _reach = 38;
const (double, double) _core = (0.0, -21.0);

const Map<String, (double, double)> _v = {
  'l0': (-15, 0),
  'l1': (-17, -10),
  'l2': (-17, -31),
  'p1': (-12, -45),
  'n1': (-6, -42),
  'p2': (0, -52),
  'n2': (6, -43),
  'p3': (12, -47),
  'r2': (17, -30),
  'r1': (16, -9),
  'r0': (14, 0),
  'i0': (-6, -36),
  'i1': (6, -35),
  'i2': (-9, -21),
  'i3': (3, -25),
  'i4': (9, -13),
  'i5': (-5, -8),
  'i6': (2, 0),
  'i7': (0, -40),
};

const List<(String, double, double)> _facetSpecs = [
  ('l0 l1 i5 i6', 0.62, 0.0),
  ('i5 i4 i6', 0.42, 0.03),
  ('i4 r2 r1 r0 i6', 0.2, 0.05),
  ('l1 l2 i2 i5', 0.74, 0.08),
  ('i2 i3 i4 i5', 0.5, 0.1),
  ('i1 r2 i4 i3', 0.28, 0.13),
  ('l2 i0 i2', 0.7, 0.15),
  ('i0 i1 i3 i2', 0.58, 0.18),
  ('n1 i7 n2 i1 i0', 0.52, 0.2),
  ('i1 n2 p3 r2', 0.4, 0.23),
  ('l2 p1 n1 i0', 0.88, 0.25),
  ('p2 n2 i7', 0.66, 0.28),
  ('n1 p2 i7', 1.0, 0.31),
];

final List<(double, double)> _outline =
    'l0 l1 l2 p1 n1 p2 n2 p3 r2 r1 r0'.split(' ').map((k) => _v[k]!).toList();

const int _x0 = -18;
const int _x1 = 18;
const int _y0 = -53;
const int _y1 = 0;
const int _bw = _x1 - _x0;

class _Facet {
  final List<(double, double)> pts;
  final double lit;
  final double at;
  final int i;
  late final ({double x, double y, double area}) c;
  late final int tint;
  late final double alpha;
  late final double d;
  late final double len;
  double g = 0.0;

  _Facet(this.pts, this.lit, this.at, this.i);
}

class _Edge {
  final (double, double) a;
  final (double, double) b;
  final List<_Facet> fs = [];
  late final bool outer;
  late final double lit;
  late final bool floor;
  late final double at;

  _Edge(this.a, this.b);
}

class _Feather {
  final int x;
  final int y;
  final int dx;
  final int dy;
  final int l;
  final double at;

  const _Feather(this.x, this.y, this.dx, this.dy, this.l, this.at);
}

void _floorFrost(Painter p, List<int> c, double t, double out) {
  for (var x = -_reach; x <= _reach; x++) {
    final d = (x + 0.5).abs() / _reach;
    final arrive = _snap * (1.0 - d);
    final age = t - arrive;
    if (age < 0.0) continue;
    final a = out * clamp((1.12 - d) / 0.2);
    final g = smooth(0.0, 0.4, age);
    final h = rand(x, 31);
    final s = x < 0 ? -1 : 1;
    if (a <= 0.0) continue;
    p.dot(x, 0, age < 0.05 || h < 0.3 ? kWhite : c[6], a);
    if (h < 0.55) {
      final len = (g * (1.0 + rand(x, 7) * 3.4) * (1.0 - d * 0.55) + 0.5).floor();
      for (var j = 1; j <= len; j++) {
        p.dot(x, -j, j == len ? kWhite : c[5], a);
      }
      if (len >= 2) p.dot(x + s, -len + 1, c[6], a);
      if (len >= 4) p.dot(x - s, -len + 2, c[5], a);
    }
    final depth = g * (2.0 + rand(x, 11) * 4.0) * (1.0 - d * 0.5);
    for (var j = 1; j <= depth; j++) {
      final col = rand(x * 13 + j, 5) < 0.07
          ? kWhite
          : (j < 2 ? c[5] : (j < 4 ? c[4] : c[3]));
      p.dot(x, j, col, a * (1.05 - j / (depth + 1.0)));
    }
  }
}

class _FreezeSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final ActorDefinition actor;
  late final Particles ps;
  final Bits bits = Bits(ground: (_) => 0.0);
  final Lights lights = Lights();
  late final Panes panes;

  late final int w;
  late final int h;
  late final Float32List reach;
  late final Uint32List ice;
  late final List<int> order;
  final List<_Feather> feathers = [];

  late final Int8List fid;
  late final List<_Facet> facets;
  late final List<_Edge> edges;
  late final List<(double, double)> verts;
  late final List<List<(double, double, double)>> cracks;
  late final List<List<(double, double, double)>> cracks2;

  double t = 0.0;
  int formed = 0;
  bool sealed = false;
  int struck = 0;
  bool burst = false;
  bool white = false;

  _FreezeSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed),
        actor = o.actor {
    final seed = o.seed;
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [c[7], c[6], c[5], c[4]],
      haze: c[5],
    );
    panes = Panes(
      ground: (_) => 0.0,
      onLand: (q, x, y, _) {
        for (var i = 0; i < 3; i++) {
          bits.add(DebrisBit(
            kind: B.shard,
            x: x + r.range(-2, 2),
            y: y - 1,
            vx: q.vx * 0.6 + r.range(-50, 50),
            vy: -r.range(30, 100),
            g: 0.8,
            drag: 0.6,
            bounce: 0.35,
            life: r.range(0.4, 0.8),
            a: r.range(0, tau),
            va: r.range(-18, 18),
            s: r.range(1.2, 2.4),
            c: c[r.intRange(5, 7)],
          ));
        }
        ps.spawn(P.vapour, x, y - 1, r.range(-25, 25), -r.range(2, 10),
            r.range(0.4, 0.7), c[6], r.range(1.4, 2.4));
        if (r.chance(0.4)) {
          ps.spawn(P.star, x, y - 2, 0, -6, r.range(0.2, 0.4), kWhite,
              r.range(0.8, 1.6));
        }
      },
    );

    w = actor.w;
    h = actor.h;
    final n = w * h;
    bool on(int x, int y) =>
        x >= 0 && y >= 0 && x < w && y < h && actor.mask.data[y * w + x] > 0;
    final dist = Float32List(n)..fillRange(0, n, double.infinity);
    ice = Uint32List(n);
    final rim = Uint8List(n);
    final open = <int>[];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (!on(x, y)) continue;
        final i = y * w + x;
        rim[i] = !on(x - 1, y) || !on(x + 1, y) || !on(x, y - 1) ? 1 : 0;
        final up = !on(x - 1, y) || !on(x, y - 1);
        final baseIce = iceOf(actor.pixels[i], c);
        ice[i] = mix(
          up ? c[math.min(7, c.indexOf(baseIce) + 1)] : baseIce,
          c[6],
          0.2,
        );
        if (y == h - 1 || !on(x, y + 1)) {
          if (y >= h - 4) {
            dist[i] = r.range(0, 1.5);
            open.add(i);
          }
        }
      }
    }
    final done = Uint8List(n);
    while (open.isNotEmpty) {
      var bi = 0;
      for (var j = 1; j < open.length; j++) {
        if (dist[open[j]] < dist[open[bi]]) bi = j;
      }
      final i = open[bi];
      open[bi] = open.last;
      open.removeLast();
      if (done[i] != 0) continue;
      done[i] = 1;
      final x = i % w;
      final y = i ~/ w;
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, -1), (0, 1)]) {
        final nx = x + dx;
        final ny = y + dy;
        if (!on(nx, ny)) continue;
        final j = ny * w + nx;
        final weight =
            (rim[j] != 0 ? 0.55 : 1.0) * (dy < 0 ? 1.0 : 1.3) + r.range(0, 1.5);
        if (dist[i] + weight < dist[j]) {
          dist[j] = dist[i] + weight;
          open.add(j);
        }
      }
    }
    var maxD = 0.0;
    for (var i = 0; i < n; i++) {
      if (dist[i] < double.infinity && dist[i] > maxD) maxD = dist[i];
    }
    reach = Float32List(n);
    order = <int>[];
    for (var i = 0; i < n; i++) {
      if (dist[i] < double.infinity) {
        reach[i] = _climb.$1 +
            (_climb.$2 - _climb.$1) * math.pow(dist[i] / maxD, 0.85);
        order.add(i);
      }
    }
    order.sort((a, b) {
      final cmp = reach[a].compareTo(reach[b]);
      return cmp != 0 ? cmp : a.compareTo(b);
    });
    for (final i in order) {
      final x = i % w;
      final y = i ~/ w;
      if (rim[i] == 0 || rand(i, seed, 3) > 0.42 || y > h - 3) continue;
      final dx = !on(x - 1, y)
          ? -1
          : (!on(x + 1, y) ? 1 : (rand(i, 9) < 0.5 ? -1 : 1));
      final dy = !on(x, y - 1) ? -1 : (rand(i, 4) < 0.5 ? -1 : 0);
      feathers.add(_Feather(
        actor.x + x + dx,
        actor.y + y + dy,
        dx,
        dy,
        1 + (rand(i, 7) * 2.6).floor(),
        reach[i] + 0.04,
      ));
    }

    facets = [
      for (var i = 0; i < _facetSpecs.length; i++)
        _Facet(
          _facetSpecs[i].$1.split(' ').map((k) => _v[k]!).toList(),
          _facetSpecs[i].$2,
          _seal + _facetSpecs[i].$3,
          i,
        ),
    ];
    for (final f in facets) {
      f.c = centroid(f.pts);
      f.tint = c[3 + (f.lit * 3.0 + 0.5).floor()];
      f.alpha = 0.2 + 0.24 * f.lit;
      f.d = clamp((f.c.x + 0.55 * f.c.y + 36.0) / 46.0);
      var len = 0.0;
      for (var k = 0; k < f.pts.length; k++) {
        final q = f.pts[k];
        final nxt = f.pts[(k + 1) % f.pts.length];
        len += hypot(nxt.$1 - q.$1, nxt.$2 - q.$2);
      }
      f.len = len;
    }

    fid = Int8List(_bw * (_y1 - _y0))..fillRange(0, _bw * (_y1 - _y0), -1);
    for (var y = _y0; y < _y1; y++) {
      for (var x = _x0; x < _x1; x++) {
        if (!_inBlock(x + 0.5, y + 0.5)) continue;
        var fi = facets.indexWhere((f) => inPoly(f.pts, x + 0.5, y + 0.5));
        if (fi < 0) {
          fi = 0;
          var bestD = hypot(facets[0].c.x - x, facets[0].c.y - y);
          for (var k = 1; k < facets.length; k++) {
            final dk = hypot(facets[k].c.x - x, facets[k].c.y - y);
            if (dk < bestD) {
              bestD = dk;
              fi = k;
            }
          }
        }
        fid[(y - _y0) * _bw + (x - _x0)] = fi;
      }
    }

    edges = <_Edge>[];
    for (final f in facets) {
      for (var k = 0; k < f.pts.length; k++) {
        final a = f.pts[k];
        final b = f.pts[(k + 1) % f.pts.length];
        _Edge? found;
        for (final e in edges) {
          if ((e.a == a && e.b == b) || (e.a == b && e.b == a)) {
            found = e;
            break;
          }
        }
        if (found == null) {
          found = _Edge(a, b);
          edges.add(found);
        }
        found.fs.add(f);
      }
    }
    for (final e in edges) {
      final (x0, y0) = e.a;
      final (x1, y1) = e.b;
      final cc = e.fs[0].c;
      var nx = y1 - y0;
      var ny = x0 - x1;
      if (nx * ((x0 + x1) / 2.0 - cc.x) + ny * ((y0 + y1) / 2.0 - cc.y) < 0.0) {
        nx = -nx;
        ny = -ny;
      }
      e.outer = e.fs.length == 1;
      e.lit = (-nx * 0.55 - ny * 0.84) / hypot(nx, ny);
      e.floor = y0 == 0.0 && y1 == 0.0;
      var minAt = e.fs[0].at;
      for (var i = 1; i < e.fs.length; i++) {
        if (e.fs[i].at < minAt) minAt = e.fs[i].at;
      }
      e.at = minAt;
    }

    verts = _v.values.toList();
    cracks = fractures(r, _inBlock, _core.$1, _core.$2, 3,
        len: 9, a0: -2.2, spread: 3.6);
    cracks2 = fractures(r, _inBlock, _core.$1 + 1, _core.$2 - 2, 6,
        len: 16, fork: 0.22);
  }

  bool _inBlock(double x, double y) => inPoly(_outline, x, y);

  int _at(int x, int y) =>
      (x < _x0 || x >= _x1 || y < _y0 || y >= _y1)
          ? -1
          : fid[(y - _y0) * _bw + (x - _x0)];

  int _jolt() {
    if (t >= _crack && t < _crack + 0.06) return 1;
    if (t >= _crack2 && t < _flash) return (t * 40.0).floor().isOdd ? 1 : -1;
    return 0;
  }

  void _drawCharacter(Painter p) {
    final thaw = t >= _burst
        ? Ease.inQuad(seg(t, _burst, _burst + _thaw)) * (h + 2) - 2.0
        : -1.0;
    for (final i in order) {
      final age = t - reach[i];
      if (age < 0.0) break;
      final x = i % w;
      final y = i ~/ w;
      if (y < thaw) continue;
      final col = y < thaw + 1.2 && t >= _burst
          ? c[7]
          : (age < 0.016 ? kWhite : (age < 0.045 ? c[6] : ice[i]));
      p.px(actor.x + x, actor.y + y, col);
      if (age < 0.03) p.light(actor.x + x, actor.y + y, c[6], 0.3);
    }
    if (t >= _burst) return;
    for (final f in feathers) {
      final g = clamp((t - f.at) / 0.08);
      if (g <= 0.0) continue;
      final len = (f.l * g + 0.5).floor();
      for (var j = 0; j < len; j++) {
        p.px(
          f.x + f.dx * j,
          f.y + f.dy * j,
          j == len - 1 ? kWhite : c[6],
        );
      }
    }
  }

  void _drawBlock(Painter p) {
    if (t >= _burst || t < _seal - 0.08) return;
    final jx = _jolt();
    final wh = t >= _flash;
    for (final f in facets) {
      var best = 0.0;
      for (final s0 in _sweeps) {
        final v = math.sin(math.pi * clamp((t - s0 - f.d * 0.32) / 0.13));
        if (v > best) best = v;
      }
      f.g = best * (0.35 + 0.65 * f.lit);
    }
    for (var y = _y0; y < _y1; y++) {
      for (var x = _x0; x < _x1; x++) {
        final fi = _at(x, y);
        if (fi < 0) continue;
        final f = facets[fi];
        final age = t - f.at;
        if (age < 0.0) continue;
        if (wh) {
          p.px(x + jx, y, kWhite);
          continue;
        }
        if (age < 0.03) {
          p.blend(x + jx, y, c[7], 0.55);
          continue;
        }
        final fresh = 1.0 - clamp((age - 0.03) / 0.1);
        final g = f.g;
        p.blend(
          x + jx,
          y,
          fresh > 0.5 || g > 0.5 ? c[6] : f.tint,
          f.alpha + 0.25 * fresh + 0.15 * g,
        );
        if (g > 0.05) p.light(x + jx, y, c[5], 0.42 * g);
      }
    }
    for (final e in edges) {
      if (e.floor || t < e.at) continue;
      final (x0, y0) = e.a;
      final (x1, y1) = e.b;
      final fresh = e.fs.any((f) => t - f.at < 0.1 || f.g > 0.6);
      if (e.outer && e.lit < 0.0 && !wh) {
        p.line(x0 + jx + 1, y0, x1 + jx + 1, y1, c[1]);
      }
      if (e.outer) p.glowLine(x0 + jx, y0, x1 + jx, y1, 5, c[4], 0.1);
      final col = wh
          ? c[6]
          : (fresh
              ? kWhite
              : (e.outer
                  ? (e.lit > 0.3
                      ? kWhite
                      : (e.lit > -0.2 ? c[6] : c[4]))
                  : ((y0 + y1) / 2.0 < -30.0 ? c[6] : c[5])));
      p.line(x0 + jx, y0, x1 + jx, y1, col);
    }
    for (final f in facets) {
      final age = t - f.at;
      if (age < -0.07 || age >= 0.0) continue;
      var left = ((age + 0.07) / 0.07) * f.len;
      for (var k = 0; k < f.pts.length && left > 0.0; k++) {
        final (x0, y0) = f.pts[k];
        final (x1, y1) = f.pts[(k + 1) % f.pts.length];
        final len = hypot(x1 - x0, y1 - y0);
        final v = math.min(1.0, left / len);
        left -= len;
        p.line(x0 + jx, y0, x0 + jx + (x1 - x0) * v, y0 + (y1 - y0) * v, kWhite);
        if (v < 1.0) {
          p.glow(x0 + jx + (x1 - x0) * v, y0 + (y1 - y0) * v, 6, c[6], 0.6);
        }
      }
    }
    if (t >= _crack && !wh) {
      drawFractures(p, cracks, (t - _crack) * 150.0, c, ox: jx.toDouble());
    }
    if (t >= _crack2 && !wh) {
      drawFractures(p, cracks2, (t - _crack2) * 190.0, c, ox: jx.toDouble());
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (t < _snap) {
      for (final s in const [-1, 1]) {
        final x = s * _reach * (1.0 - t / _snap);
        if (r.chance(0.12)) {
          ps.spawn(P.vapour, x, -r.range(0, 2), -s * r.range(40, 90),
              -r.range(0, 5), r.range(0.3, 0.5), c[6], r.range(1.4, 2.4));
        }
        if (r.chance(0.45)) {
          ps.spawn(
            P.streak,
            x + s * r.range(0, 6),
            -r.range(1, 4),
            -s * r.range(50, 90),
            0,
            r.range(0.1, 0.16),
            r.chance(0.5) ? c[6] : c[5],
          );
        }
      }
    }
    if (t > _climb.$1 && t < _climb.$2 + 0.03) {
      var lo = 0;
      while (lo < order.length && reach[order[lo]] < t - 0.06) {
        lo++;
      }
      var hi = lo;
      while (hi < order.length && reach[order[hi]] <= t) {
        hi++;
      }
      if (hi > lo && r.chance(0.45)) {
        final i = order[r.intRange(lo, hi - 1)];
        ps.spawn(
          P.star,
          actor.x + (i % w) + 0.5,
          actor.y + (i ~/ w).toDouble(),
          r.range(-8, 8),
          -r.range(0, 18),
          r.range(0.2, 0.42),
          r.chance(0.5) ? c[6] : kWhite,
          r.range(0.6, 1.9),
        );
      }
      if (hi > lo && r.chance(0.12)) {
        final i = order[r.intRange(lo, hi - 1)];
        ps.spawn(
          P.flake,
          actor.x + (i % w).toDouble(),
          actor.y + (i ~/ w).toDouble(),
          r.range(-20, 20),
          -r.range(10, 30),
          r.range(0.5, 0.9),
          c[6],
          r.range(0.5, 1.2),
        );
      }
    }
    while (formed < facets.length && t >= facets[formed].at) {
      final f = facets[formed++];
      final fc = centroid(f.pts);
      for (var i = 0; i < 3; i++) {
        final a =
            math.atan2(fc.y - _core.$2, fc.x - _core.$1) + r.range(-0.7, 0.7);
        final sp = r.range(50, 120);
        bits.add(DebrisBit(
          kind: B.shard,
          x: fc.x,
          y: fc.y,
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp - 40.0,
          g: 0.8,
          drag: 0.8,
          bounce: 0.3,
          life: r.range(0.35, 0.7),
          a: r.range(0, tau),
          va: r.range(-18, 18),
          s: r.range(1, 2.2),
          c: c[r.intRange(5, 7)],
        ));
      }
      if (fc.y > -14.0) {
        final s = fc.x == 0.0 ? 1.0 : fc.x.sign;
        ps.spawn(P.vapour, fc.x, -1, s * r.range(10, 30), -r.range(2, 8),
            r.range(0.5, 0.8), c[6], r.range(2.2, 3.4));
      }
      ps.spawn(P.star, fc.x + r.range(-2, 2), fc.y + r.range(-2, 2), 0, -4,
          r.range(0.25, 0.45), kWhite, r.range(1.2, 2.2));
      lights.add(fc.x, fc.y, 16, c[6], 0.4, 0.12);
    }
    if (!sealed && formed == facets.length) {
      sealed = true;
      lights.add(0, -26, 70, c[5], 0.6, 0.4);
      for (var i = 0; i < 5; i++) {
        ps.spawn(
          P.star,
          r.range(-15, 15),
          -r.range(6, 44),
          r.range(-6, 6),
          -r.range(0, 8),
          r.range(0.3, 0.6),
          r.chance(0.5) ? kWhite : c[6],
          r.range(1, 2.2),
        );
      }
    }
    if (sealed && t < _crack2) {
      if (r.chance(0.035)) {
        final (vx, vy) = r.pick(verts);
        ps.spawn(P.star, vx + r.range(-1, 1), vy + r.range(-1, 1), 0, -2,
            r.range(0.3, 0.6), r.chance(0.6) ? c[6] : kWhite, r.range(0.8, 2.2));
      }
      if (r.chance(0.025)) {
        final s = r.sign();
        ps.spawn(P.vapour, s * r.range(12, 18), -r.range(1, 3),
            s * r.range(8, 24), -r.range(1, 5), r.range(0.7, 1.1), c[6],
            r.range(1.8, 3));
      }
      if (r.chance(0.012)) {
        ps.spawn(
          P.flake,
          r.range(-30, 30),
          -r.range(56, 76),
          r.range(-4, 4),
          r.range(4, 10),
          r.range(1.2, 1.8),
          r.chance(0.5) ? kWhite : c[6],
          r.range(0.5, 1.4),
        );
      }
    }
    if (struck == 0 && t >= _crack) {
      struck = 1;
      lights.add(_core.$1, _core.$2, 26, kWhite, 0.4, 0.1);
      for (var i = 0; i < 4; i++) {
        bits.add(DebrisBit(
          kind: B.shard,
          x: r.range(-14, 14),
          y: -r.range(10, 40),
          vx: r.range(-40, 40),
          vy: -r.range(10, 60),
          g: 0.9,
          drag: 0.6,
          bounce: 0.3,
          life: r.range(0.5, 0.9),
          a: r.range(0, tau),
          va: r.range(-20, 20),
          s: r.range(1, 2),
          c: c[r.intRange(5, 7)],
        ));
      }
    }
    if (struck == 1 && t >= _crack2) {
      struck = 2;
      lights.add(_core.$1, _core.$2, 40, c[6], 0.35, 0.16);
      for (var i = 0; i < 3; i++) {
        ps.spawn(P.star, r.range(-12, 12), -r.range(8, 40), 0, -3,
            r.range(0.15, 0.3), kWhite, r.range(1, 2));
      }
    }
    if (!white && t >= _flash) {
      white = true;
      lights.add(_core.$1, _core.$2, 60, kWhite, 0.9, 0.1);
    }
    if (!burst && t >= _burst) {
      burst = true;
      lights.add(_core.$1, _core.$2, 64, kWhite, 0.85, 0.14);
      lights.add(_core.$1, _core.$2 - 4, 72, c[4], 0.55, 0.6);
      List<List<(double, double)>> chop(List<(double, double)> pts, int depth) {
        final cc = centroid(pts);
        return cc.area < 20.0 || depth > 2
            ? [pts]
            : splitPoly(pts, cc.x, cc.y, r.range(0, math.pi))
                .expand((q) => chop(q, depth + 1))
                .toList();
      }

      for (final f in facets) {
        for (final part in chop(f.pts, 0)) {
          final m = centroid(part);
          final dx = m.x - _core.$1;
          final dy = m.y - _core.$2;
          final rawD = hypot(dx, dy);
          final d = rawD == 0.0 ? 1.0 : rawD;
          final sp = r.range(40, 85) * (1.2 - math.min(0.5, m.area / 120.0));
          panes.add(IcePane(
            pts: [for (final (px, py) in part) (px - m.x, py - m.y)],
            x: m.x,
            y: m.y,
            vx: (dx / d) * sp + r.range(-15, 15),
            vy: (dy / d) * sp * 0.6 - r.range(90, 190),
            a: 0,
            va: r.range(-9, 9),
            f: r.range(-0.8, 0.8),
            vf: r.sign() * r.range(5, 13),
            lit: f.lit,
            g: 0.85,
            drag: 0.7,
            brittle: 1,
            life: r.range(1, 1.45),
          ));
        }
      }
      for (var i = 0; i < 50; i++) {
        var x = 0;
        var y = 0;
        for (var k = 0; k < 12 && _at(x, y) < 0; k++) {
          x = r.intRange(_x0, _x1 - 1);
          y = r.intRange(_y0, _y1 - 1);
        }
        final dx = x - _core.$1;
        final dy = y - _core.$2;
        final rawD = hypot(dx, dy);
        final d = rawD == 0.0 ? 1.0 : rawD;
        final sp = r.range(50, 130);
        bits.add(DebrisBit(
          kind: B.shard,
          x: x.toDouble(),
          y: y.toDouble(),
          vx: (dx / d) * sp,
          vy: (dy / d) * sp * 0.7 - r.range(60, 170),
          g: 0.85,
          drag: 0.9,
          bounce: 0.3,
          life: r.range(0.8, 1.4),
          a: r.range(0, tau),
          va: r.range(-22, 22),
          s: r.range(1.5, 3.2),
          c: c[r.intRange(4, 7)],
        ));
      }
      for (final f in feathers) {
        if (r.chance(0.5)) {
          bits.add(DebrisBit(
            kind: B.shard,
            x: f.x.toDouble(),
            y: f.y.toDouble(),
            vx: f.dx * r.range(20, 70),
            vy: -r.range(20, 90),
            g: 0.8,
            drag: 0.8,
            bounce: 0.3,
            life: r.range(0.4, 0.8),
            a: r.range(0, tau),
            va: r.range(-20, 20),
            s: r.range(1, 1.8),
            c: kWhite,
          ));
        }
      }
      for (var i = 0; i < 12; i++) {
        final s = r.sign();
        ps.spawn(P.vapour, s * r.range(2, 16), -r.range(1, 6),
            s * r.range(30, 90), -r.range(4, 16), r.range(0.6, 1.1), c[6],
            r.range(2.2, 4));
      }
      for (var i = 0; i < 8; i++) {
        ps.spawn(P.vapour, r.range(-14, 14), -r.range(8, 40), r.range(-30, 30),
            -r.range(10, 30), r.range(0.6, 1), c[6], r.range(3, 5));
      }
      for (var i = 0; i < 18; i++) {
        final a = r.range(-math.pi, 0);
        final sp = r.range(40, 130);
        ps.spawn(
          P.flake,
          r.range(-10, 10),
          _core.$2 + r.range(-12, 12),
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(1, 1.5),
          r.chance(0.6) ? kWhite : c[6],
          r.range(0.5, 1.6),
        );
      }
      for (var i = 0; i < 7; i++) {
        ps.spawn(
          P.star,
          r.range(-26, 26),
          -r.range(6, 52),
          r.range(-12, 12),
          -r.range(4, 16),
          r.range(0.4, 0.8),
          r.chance(0.5) ? kWhite : c[6],
          r.range(1, 2.4),
        );
      }
    }
    if (burst && t < _burst + 0.9 && r.chance(0.07)) {
      final (bx, by) = bits.list.isNotEmpty
          ? (() {
              final picked = r.pick(bits.list);
              return (picked.x, picked.y);
            })()
          : r.pick(const [(0.0, -10.0)]);
      ps.spawn(P.star, bx, by - 1.0, 0, -3, r.range(0.2, 0.4),
          r.chance(0.5) ? kWhite : c[6], r.range(0.6, 1.6));
    }
    if (burst && t < _burst + _thaw && r.chance(0.12)) {
      final y = -h + Ease.inQuad(seg(t, _burst, _burst + _thaw)) * h;
      bits.add(DebrisBit(
        kind: B.drip,
        x: r.range(-9, 9),
        y: y,
        vy: 10,
        g: 0.5,
        life: 0.8,
        c: c[5],
      ));
    }
    ps.update(dt);
    bits.update(dt);
    panes.update(dt);
    lights.update(dt);
    endBy(t, _duration, ps: ps, bits: bits, panes: panes);
  }

  @override
  void drawBack(Painter p) {
    final out = 1.0 - smooth(_melt.$1, _melt.$2, t);
    if (out > 0.0) _floorFrost(p, c, t, out);
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    _drawCharacter(p);
    _drawBlock(p);
    final hold =
        smooth(_climb.$1, _seal, t) * (1.0 - smooth(_burst, _burst + 0.6, t));
    final crk = smooth(_crack, _flash, t);
    if (hold > 0.0) {
      p.glow(0, -2, 34, c[4], 0.22 * hold * (0.85 + 0.15 * math.sin(t * 3.0)));
      p.glow(_core.$1, _core.$2 - 4, 40, c[3], (0.22 + 0.1 * crk) * hold);
    }
    if (t > _climb.$1 && t < _climb.$2) {
      p.glow(0, -38.0 * Ease.outQuad(seg(t, _climb.$1, _climb.$2)), 18, c[5], 0.28);
    }
    final top = facets.last.at;
    final g = t - top;
    if (g > 0.0 && g < 0.3) {
      final p2 = _v['p2']!;
      sparkle(
        p,
        p2.$1,
        p2.$2,
        8.0 * Ease.outBack(math.min(1.0, g / 0.06)) * (1.0 - g / 0.3),
        c[6],
        c[4],
        0.6,
      );
    }
    if (t >= _flash && t < _burst + 0.16) {
      final a = clamp((t - _flash) / 0.22);
      flare(p, _core.$1, _core.$2, 34.0 * math.pow(1.0 - a, 1.4), 1.0 - a, c);
    }
    panes.draw(p, c);
    bits.draw(p);
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect freezeEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ice/freeze',
    name: 'Freeze',
    desc:
        'Frost races in and climbs the character, turning it to ice; a faceted block crystallizes round it pane by pane, glints, cracks and bursts, and the character thaws free.',
    category: 'ice',
    tags: ['ice', 'freeze', 'frozen', 'status', 'crowd-control', 'one-shot'],
    size: (176, 128),
    origin: (88, 108),
    duration: _duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#151a3d', '#212f6b', '#2c58aa', '#3a8bd8',
        '#62c8f4', '#a6ecff', '#dcfbff', '#ffffff',
      ],
      'seed': 5,
    },
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      const PoseKey(-0.2, kReady),
      const PoseKey(0.05, kReady),
      const PoseKey(0.16, _fear, PoseEase.snap),
      PoseKey(0.3, _fear.copyWith(lean: -1, fx: -10, fy: -34)),
      PoseKey(0.45, _fear.copyWith(lean: -3, bx: 11, by: -34, fx: -7, fy: -29)),
      const PoseKey(0.62, _fear),
      const PoseKey(2.52, _fear),
      const PoseKey(2.54, _free, PoseEase.snap),
      PoseKey(2.9, _free.copyWith(crouch: 4)),
      PoseKey(3.1, _free.copyWith(crouch: 3, lean: 1)),
      PoseKey(3.3, _free.copyWith(crouch: 3, lean: -1)),
      const PoseKey(4, kReady),
    ],
    hits: const [
      HitSpec(t: 0.62, stop: 0.03, shake: 0.08, amp: 1),
      HitSpec(t: 2.52, stop: 0.05, shake: 0.2, amp: 2),
    ],
  ),
  onCreate: (o) => _FreezeSim(o),
);
