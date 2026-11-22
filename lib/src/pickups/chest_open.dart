// The collection pop (white squash, a ring snapping out, star sparks) and the glints follow Sprite Fusion's
// open-source pickup (https://www.spritefusion.com/pixel-art-vfx/pickup), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'pickups_lib.dart';

final List<List<int>> _gems = [
  ['#2a0612', '#6e0f2a', '#b81c3c', '#f0405a', '#ff8a96', '#ffd2d6'],
  ['#06200f', '#0f4a26', '#1a8040', '#34c060', '#8af0a0', '#d8ffe0'],
  ['#0a1030', '#142a70', '#2050c0', '#3a8cf0', '#8ccaff', '#dcf0ff'],
  ['#1a0a2a', '#3e1466', '#6a28a8', '#a050e0', '#d09cff', '#f0e0ff'],
].map((g) => g.map(hex).toList()).toList();

const double _tOpen = 0.8;
const double _tCollect = 2.55;
const double _tPoof = 3.3;
const List<(double, double)> _rattles = [
  (0.1, 0.4),
  (0.32, 0.62),
  (0.5, 0.8),
  (0.64, 1.0),
];
const int _hw = 12;
const int _fh = 9;
const double _cs = 0.94;
const double _sn = 0.34;
const double _hb = _fh / _cs;
const double _la = 6.0;
const double _lb = 5.5;
const List<int> _straps = [-9, 7];

final SpriteLayer _chestLayer = SpriteLayer(40, 44);
final SpriteLayer _itemLayer = SpriteLayer(16, 16);

final List<int> _iron = [
  '#0e0d16',
  '#1d1c28',
  '#2f2e3e',
  '#474658',
  '#6a6a7e',
  '#9898ac',
].map(hex).toList();

class _LidRow {
  final int row;
  final double al;
  final double dep;
  final bool out;
  final double lit;
  bool crest = false;
  bool seam = false;

  _LidRow({
    required this.row,
    required this.al,
    required this.dep,
    required this.out,
    required this.lit,
  });
}

List<_LidRow> _lidRows(double th) {
  final best = <int, _LidRow>{};
  final ct = math.cos(th);
  final st = math.sin(th);
  for (var i = 0; i <= 260; i++) {
    final al = (i / 260.0) * math.pi;
    final dz = _la + _la * math.cos(al);
    final dy = _lb * math.sin(al);
    final z = -_la + dz * ct - dy * st;
    final y = _hb + dz * st + dy * ct;
    if (y < _hb - 0.05) continue;
    var nz = math.cos(al) / _la;
    var ny = math.sin(al) / _lb;
    final nl = hypot(nz, ny);
    nz /= nl;
    ny /= nl;
    final nzz = nz * ct - ny * st;
    final nyy = nz * st + ny * ct;
    final v = y * _cs + (_la - z) * _sn;
    final dep = z * _cs + y * _sn;
    final row = (-v).floor();
    final cur = best[row];
    if (cur == null || dep > cur.dep) {
      best[row] = _LidRow(
        row: row,
        al: al,
        dep: dep,
        out: nzz * _cs + nyy * _sn > 0.0,
        lit: nyy * 0.95 + nzz * 0.3 - 0.2,
      );
    }
  }
  final rows = best.values.toList()..sort((a, b) => a.row.compareTo(b.row));
  _LidRow? hi;
  for (final r in rows) {
    if (r.out && (hi == null || r.lit > hi.lit)) hi = r;
  }
  if (hi != null && hi.lit > 0.5) hi.crest = true;
  for (final s in [math.pi / 3.0, (2.0 * math.pi) / 3.0]) {
    _LidRow? k;
    for (final r in rows) {
      if (k == null || (r.al - s).abs() < (k.al - s).abs()) k = r;
    }
    if (k != null && (k.al - s).abs() < 0.4) k.seam = true;
  }
  return rows;
}

int _tone(List<int> r, double l, List<int> steps) => r[steps[
    l > 0.6
        ? 0
        : (l > 0.25 ? 1 : (l > -0.1 ? 2 : (l > -0.45 ? 3 : 4)))]];

void _paintHoard(List<int> c, List<int> w, double g) {
  int heat(int k) => c[clampInt((k + g * 2.2 + 0.5).floor(), 0, 7)];
  for (var y = -13; y <= -10; y++) {
    for (var x = -_hw; x < _hw; x++) {
      final h = rand(x, y, 7);
      final k = h < 0.18 ? 5 : (h < 0.55 ? 4 : 3);
      _chestLayer.set(
        x,
        y,
        y == -13 && (x + 0.5).abs() > 9.0
            ? w[2]
            : heat(k - (y == -13 ? 1 : 0)),
      );
    }
  }
  for (var x = -9; x < 9; x++) {
    final top = -13 -
        (2.2 *
                math.pow(
                  math.cos(((x + 0.5) / 10.0) * (math.pi / 2.0)),
                  1.4,
                ) +
            0.5)
            .floor();
    for (var y = top; y < -13; y++) {
      _chestLayer.set(
        x,
        y,
        heat(y == top ? 5 : 4 + (rand(x, y, 3) < 0.3 ? 1 : 0)),
      );
    }
  }
}

void _paintLid(List<int> c, List<int> w, double th, double g) {
  final rows = _lidRows(th);
  int heat(int k) => c[clampInt((k + g * 2.2 + 0.5).floor(), 0, 7)];
  final top = rows.isNotEmpty ? rows[0].row : 0;
  for (final r in rows) {
    final u = r.al;
    for (var x = -_hw; x < _hw; x++) {
      final strap = _straps.any((s) => x == s || x == s + 1);
      final left = _straps.any((s) => x == s);
      final side = (x + _hw + 0.5) / (2 * _hw);
      final corner = x == -_hw || x == _hw - 1;
      int col;
      if (r.out) {
        if (r.row == top && corner && th < 0.6) continue;
        final l = r.lit + 0.2 - side * 0.35 - (r.row == top ? 0.45 : 0.0);
        if (u < 0.3 || (u < 0.55 && x >= -2 && x <= 1)) {
          col = _tone(
            c,
            l + (x >= -2 && x <= 1 ? 0.15 : 0.1),
            const [6, 5, 5, 4, 3],
          );
        } else if (corner) {
          col = x < 0 ? _iron[4] : _iron[2];
        } else if (strap) {
          col = _tone(_iron, l + (left ? 0.3 : -0.3), const [5, 4, 3, 2, 1]);
        } else if (r.seam) {
          col = w[0];
        } else {
          col = r.crest && side < 0.62
              ? w[6]
              : _tone(w, l, const [5, 4, 3, 2, 1]);
          if (rand(x >> 1, (u * 6.0 + 0.5).floor(), 11) < 0.2) {
            col = w[math.max(0, w.indexOf(col) - 1)];
          }
        }
      } else {
        final k = g * math.pow(u / math.pi, 1.3).toDouble();
        if (u < 0.3) {
          col = heat(1);
        } else if (r.seam) {
          col = w[0];
        } else {
          col = k > 0.6
              ? mix(w[4], c[5], 0.3)
              : (k > 0.35 ? w[3] : (k > 0.15 ? w[2] : w[1]));
        }
        if (corner) col = w[0];
      }
      _chestLayer.set(x, r.row, col);
    }
  }
}

void _paintFront(List<int> c, List<int> w, double g) {
  for (var y = -_fh; y <= -1; y++) {
    for (var x = -_hw; x < _hw; x++) {
      final side = (x + _hw + 0.5) / (2 * _hw);
      int col;
      if (y == -_fh) {
        col = side < 0.3 ? c[6] : (side < 0.7 ? c[5] : c[4]);
      } else if (y == -1) {
        col = w[1];
      } else if (y == -5) {
        col = w[0];
      } else {
        final top = y == -8 || y == -4;
        final bot = y == -6 || y == -2;
        col = w[top ? (side < 0.45 ? 4 : 3) : (bot ? 2 : 3)];
        if (!top && rand(x >> 1, y, 5) < 0.2) col = w[bot ? 1 : 2];
      }
      if (x == -_hw) col = y == -_fh ? c[5] : _iron[4];
      if (x == _hw - 1) col = y == -_fh ? c[3] : _iron[2];
      for (final s in _straps) {
        if (x == s && y > -_fh) {
          col = y == -7 || y == -3 ? _iron[5] : _iron[4];
        }
        if (x == s + 1 && y > -_fh) col = _iron[2];
      }
      _chestLayer.set(x, y, col);
    }
  }
  for (var y = -_fh; y <= -4; y++) {
    for (var x = -2; x <= 1; x++) {
      _chestLayer.set(
        x,
        y,
        x == 1 || y == -4
            ? c[3]
            : (x == -2 && y == -_fh ? c[7] : c[5]),
      );
    }
  }
  final kh = g < 0.15
      ? w[0]
      : (g < 0.4 ? c[4] : (g < 0.7 ? c[6] : kWhite));
  _chestLayer.set(-1, -7, kh);
  _chestLayer.set(0, -7, kh);
  _chestLayer.set(-1, -6, kh);
  _chestLayer.set(0, -6, scaleColor(kh, 0.85));
}

void _paintChest(List<int> c, List<int> w, double th, double g) {
  if (th > 1.2) {
    _paintLid(c, w, th, g);
    _paintHoard(c, w, g);
  } else {
    _paintHoard(c, w, g);
    _paintLid(c, w, th, g);
  }
  _paintFront(c, w, g);
}

class _Ray {
  final double a;
  final double len;
  final double w;
  final double d;
  final double f;
  final double ph;

  const _Ray({
    required this.a,
    required this.len,
    required this.w,
    required this.d,
    required this.f,
    required this.ph,
  });
}

class _LootItem {
  final bool gem;
  final List<int>? g;
  double x;
  double y;
  double vx;
  double vy;
  final double t0;
  bool up = false;
  bool rest = false;
  final double r;
  final double ax;
  double spin;
  double vs;
  double settle = 0.0;
  final double ph;
  double pop = 0.0;
  bool gone = false;

  _LootItem({
    required this.gem,
    required this.g,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.t0,
    required this.r,
    required this.ax,
    required this.spin,
    required this.vs,
    required this.ph,
  });
}

class _Ring {
  final double x;
  final double y;
  final double t0;

  const _Ring(this.x, this.y, this.t0);
}

class _ChestBit {
  final int x;
  final int y;
  final int c;
  final double td;
  final bool mote;
  bool done = false;

  _ChestBit({
    required this.x,
    required this.y,
    required this.c,
    required this.td,
    required this.mote,
  });
}

class _ChestOpenSim extends BaseEffectSim {
  late final List<int> c;
  late final List<int> w;
  late final Rng r;
  late final Particles ps;
  late final Particles dust;
  final Lights lights = Lights();
  late final List<_Ray> rays;
  final List<_LootItem> loot = [];
  final List<_Ring> rings = [];
  final List<_ChestBit> bits = [];
  final int dustCol = hex('#5e5068');

  double t = 0.0;
  bool opened = false;
  bool poofed = false;

  _ChestOpenSim(Map<String, Object?> o) {
    c = fit(o.palette, 8);
    w = fit(o.rampOpt('wood'), 7);
    r = Rng(o.seed);
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [c[7], c[6], c[5], c[4]],
      haze: c[4],
    );
    dust = Particles(rng: r, sparks: [c[5], c[5], c[4], c[3]]);
    rays = List.generate(9, (i) {
      final u = (i / 8.0) * 2.0 - 1.0;
      return _Ray(
        a: u * 1.05 + r.range(-0.06, 0.06),
        len: r.range(46.0, 64.0) * (1.2 - 0.4 * u.abs()),
        w: r.range(0.035, 0.08),
        d: r.range(0.0, 0.06),
        f: r.range(5.0, 10.0),
        ph: r.range(0.0, tau),
      );
    });
    final n = o.intOpt('coins', 12);
    for (var i = 0; i < n + 4; i++) {
      final gem = i >= n;
      final s = i % 2 != 0 ? 1 : -1;
      final a = s * r.range(0.1, 0.5);
      final sp = r.range(190.0, 270.0);
      loot.add(_LootItem(
        gem: gem,
        g: gem ? _gems[(i - n) % _gems.length] : null,
        x: r.range(-7.0, 7.0),
        y: -12.0,
        vx: math.sin(a) * sp,
        vy: -math.cos(a) * sp,
        t0: _tOpen + 0.03 + r.range(0.0, 0.2),
        r: gem ? 2.6 : 3.0,
        ax: r.range(-0.6, 0.6),
        spin: r.range(0.0, tau),
        vs: r.sign() * r.range(14.0, 24.0),
        ph: r.next(),
      ));
    }
    final sorted = [...loot]
      ..sort((a, b) => b.vx.abs().compareTo(a.vx.abs()));
    for (var k = 0; k < sorted.length; k++) {
      sorted[k].pop = _tCollect + k * 0.04 + r.range(0.0, 0.02);
    }
  }

  ({int dx, int hop, double lid}) _shake() {
    var dx = 0.0;
    var hop = 0;
    var lid = 0.0;
    for (final (t0, s) in _rattles) {
      final u = t - t0;
      if (u < 0.0 || u > 0.18) continue;
      final e = 1.0 - u / 0.18;
      dx += math.sin(u * 90.0) * 1.6 * s * e;
      if (u < 0.06 && s > 0.5) hop = 1;
      lid = math.max(lid, math.max(0.0, math.sin(u * 38.0)) * 0.13 * s * e);
    }
    if (t >= _tOpen && t < _tOpen + 0.08) hop = 1;
    final strain = smooth(_tOpen - 0.14, _tOpen, t);
    if (t < _tOpen) {
      lid = math.max(lid, 0.07 * strain);
      if (strain > 0.2) {
        dx += ((t * 60.0).floor() % 2 != 0 ? 1 : -1) * 0.6;
      }
    }
    return (dx: (dx + 0.5).floor(), hop: hop, lid: lid);
  }

  double _lidAngle(double lid) {
    if (t < _tOpen) return lid;
    final u = t - _tOpen;
    const wVal = 30.0;
    const z = 0.55;
    final wd = wVal * math.sqrt(1.0 - z * z);
    return 1.98 *
        (1.0 -
            math.exp(-z * wVal * u) *
                (math.cos(wd * u) + ((z * wVal) / wd) * math.sin(wd * u)));
  }

  double _inner() {
    if (t < _tOpen) {
      var k = 0.1 +
          0.45 * smooth(0.0, _tOpen, t) +
          0.5 * smooth(_tOpen - 0.14, _tOpen, t);
      for (final (t0, s) in _rattles) {
        if (t > t0) k += 0.45 * s * math.exp(-(t - t0) * 9.0);
      }
      return k;
    }
    return (0.62 + 0.3 * math.exp(-(t - _tOpen) * 5.0)) *
            (1.0 - smooth(_tCollect - 0.3, _tPoof, t)) +
        0.05 * math.sin(t * 9.0);
  }

  double _rayK(_Ray ray) {
    final u = t - _tOpen - ray.d;
    if (u < 0.0) return 0.0;
    return Ease.outCubic(clamp(u / 0.1)) *
        (1.0 - smooth(1.0, 2.1, u)) *
        (0.72 + 0.28 * math.sin(t * ray.f + ray.ph));
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final g = _inner();
    for (final (t0, s) in _rattles) {
      if (s > 0.5 && t - dt < t0 + 0.05 && t >= t0 + 0.05) {
        for (var i = 0; i < 4; i++) {
          final sd = i % 2 != 0 ? 1 : -1;
          ps.spawn(
            P.dust,
            sd * r.range(9.0, 13.0),
            -1.0,
            sd * r.range(20.0, 50.0),
            -r.range(2.0, 8.0),
            r.range(0.3, 0.5),
            dustCol,
            r.range(1.2, 2.2) * s,
          );
        }
      }
    }
    if (t < _tOpen && r.chance(g * 0.08)) {
      final x = r.range(-11.0, 11.0);
      ps.spawn(
        P.star,
        x,
        -10.0,
        x * 1.5,
        -r.range(8.0, 30.0),
        r.range(0.3, 0.6),
        r.chance(0.5) ? c[6] : c[5],
        r.range(0.4, 1.2),
      );
    }
    if (!opened && t >= _tOpen) {
      opened = true;
      lights.add(0.0, -18.0, 64.0, c[5], 0.45, 0.7);
      lights.add(0.0, -16.0, 22.0, kWhite, 0.35, 0.1);
      for (var i = 0; i < 7; i++) {
        final a = -math.pi / 2.0 + r.range(-1.1, 1.1);
        final sp = r.range(120.0, 260.0);
        ps.spawn(
          P.spark,
          r.range(-8.0, 8.0),
          -13.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.12, 0.26),
        );
      }
      for (var i = 0; i < 8; i++) {
        final s = r.sign();
        ps.spawn(
          P.dust,
          s * r.range(10.0, 14.0),
          -1.0,
          s * r.range(30.0, 80.0),
          -r.range(2.0, 10.0),
          r.range(0.4, 0.7),
          dustCol,
          r.range(1.6, 3.0),
        );
      }
    }
    if (t > _tOpen && t < _tCollect) {
      if (r.chance(0.22)) {
        ps.spawn(
          P.ember,
          r.range(-9.0, 9.0),
          -13.0,
          r.range(-12.0, 12.0),
          -r.range(25.0, 60.0),
          r.range(0.8, 1.5),
          c[5],
          r.range(0.8, 1.6),
        );
      }
      if (r.chance(0.12)) {
        final a = r.range(-1.0, 1.0);
        final d = r.range(10.0, 40.0);
        ps.spawn(
          P.star,
          math.sin(a) * d,
          -12.0 - math.cos(a) * d,
          0.0,
          -r.range(4.0, 12.0),
          r.range(0.3, 0.7),
          r.chance(0.5) ? kWhite : c[6],
          r.range(0.5, 2.0),
        );
      }
    }
    for (final it in loot) {
      if (it.gone || t < it.t0) continue;
      it.up = true;
      if (t >= it.pop + 0.13) {
        it.gone = true;
        final y = it.y - 6.0;
        if (it.gem) rings.add(_Ring(it.x, y, t));
        lights.add(it.x, y, 18.0, it.gem ? it.g![4] : c[5], 0.65, 0.25);
        for (var i = 0; i < 4; i++) {
          final a = r.range(0.0, tau);
          final sp = r.range(25.0, 55.0);
          ps.spawn(
            P.star,
            it.x,
            y,
            math.cos(a) * sp - it.x * 0.25,
            math.sin(a) * sp - 20.0,
            r.range(0.3, 0.55),
            i != 0 ? (it.gem ? it.g![5] : c[6]) : kWhite,
            r.range(0.6, 1.5),
          );
        }
        continue;
      }
      if (it.rest) {
        it.settle += dt;
        it.vx -= it.vx * 9.0 * dt;
        it.x = clamp(it.x + it.vx * dt, -74.0, 74.0);
        continue;
      }
      it.vy += 950.0 * dt;
      it.x += it.vx * dt;
      if (it.x.abs() > 74.0) {
        it.x = it.x.sign * 74.0;
        it.vx *= -0.3;
      }
      it.y += it.vy * dt;
      it.spin += it.vs * dt;
      final bottom = it.y + it.r;
      if (bottom >= -0.5 && it.vy > 0.0) {
        it.y = -0.5 - it.r;
        if (it.vy > 110.0) {
          ps.spawn(
            P.dust,
            it.x,
            -1.0,
            r.range(-20.0, 20.0),
            -r.range(4.0, 12.0),
            r.range(0.25, 0.45),
            dustCol,
            r.range(1.0, 1.8),
          );
          if (it.vy > 220.0) {
            for (var i = 0; i < 2; i++) {
              ps.spawn(
                P.spark,
                it.x,
                -1.0,
                r.range(-90.0, 90.0),
                -r.range(60.0, 140.0),
                r.range(0.1, 0.22),
              );
            }
            lights.add(it.x, -2.0, 9.0, c[5], 0.5, 0.12);
          }
          it.vy = -it.vy * 0.42;
          it.vx *= 0.5;
          it.vs *= 0.55;
        } else {
          it.rest = true;
          it.vy = 0.0;
        }
      }
    }
    for (var i = rings.length - 1; i >= 0; i--) {
      if (t - rings[i].t0 > 0.3) rings.removeAt(i);
    }
    if (!poofed && t >= _tPoof) {
      poofed = true;
      lights.add(0.0, -12.0, 40.0, c[5], 0.5, 0.6);
      _chestLayer.begin(-20, -32);
      _paintChest(c, w, _lidAngle(0.0), 0.3);
      _chestLayer.outline(w[0]);
      final f = _chestLayer.f;
      var top = 0;
      for (var i = 0; i < f.color.length; i++) {
        if (f.color[i] != 0) {
          top = math.min(top, (i ~/ f.w) + f.oy);
        }
      }
      for (var i = 0; i < f.color.length; i++) {
        final col = f.color[i];
        if (col == 0) continue;
        final x = (i % f.w) + f.ox;
        final y = (i ~/ f.w) + f.oy;
        bits.add(_ChestBit(
          x: x,
          y: y,
          c: col,
          td: _tPoof + ((y - top) / -top) * 0.32 + rand(x, y, 21) * 0.05,
          // JS hex() returns signed Int32 while Uint32Array returns unsigned, so `c !== W[0]` is always true in upstream JS.
          mote: rand(x, y, 23) < 0.14,
        ));
      }
    }
    for (final b in bits) {
      if (!b.done && t >= b.td) {
        b.done = true;
        if (b.mote) {
          dust.spawn(
            P.ember,
            b.x + 0.5,
            b.y + 0.5,
            r.range(-28.0, 28.0),
            -r.range(14.0, 50.0),
            r.range(0.4, 0.8),
            c[5],
            r.range(0.5, 1.1),
          );
        }
      }
    }
    ps.update(dt);
    dust.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    if (t < _tPoof + 0.2) {
      blobShadow(p, 0.0, 15.0, 1.0 - smooth(_tPoof, _tPoof + 0.2, t));
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final g = _inner();
    final sh = _shake();
    final th = _lidAngle(sh.lid);
    final open = t >= _tOpen ? 1.0 : 0.0;
    pool(p, 0.0, 0.0, 30.0 + 10.0 * g, 4.0, c[4], (0.1 + 0.18 * open) * g);
    p.glow(0.0, -16.0, 24.0 + 8.0 * g, c[4], (0.1 + 0.2 * open) * g);
    if (t < _tPoof) {
      _chestLayer.begin(-20, -32);
      _paintChest(c, w, th, math.min(1.2, g));
      _chestLayer.outline(w[0]);
      _chestLayer.draw(p, sh.dx.toDouble(), -sh.hop.toDouble());
    } else {
      for (final b in bits) {
        if (!b.done) {
          p.px(
            b.x,
            b.y,
            b.td - t < 0.04 ? c[6] : b.c,
          );
        }
      }
    }
    if (t < _tOpen) {
      p.glowLine(
        -11.0,
        -9.5 - sh.hop,
        11.0,
        -9.5 - sh.hop,
        5.0,
        c[5],
        0.22 * g,
      );
      if (g > 0.35 && sh.lid < 0.015) {
        p.lineShaded(
          -10.0 + sh.dx,
          -10.0 - sh.hop,
          9.0 + sh.dx,
          -10.0 - sh.hop,
          color: (u) => (u - 0.5).abs() < 0.2 ? kWhite : c[6],
          alpha: (u) => (g - 0.35) * 2.2 * (1.0 - (u - 0.5).abs() * 0.9),
        );
      }
      p.glow(sh.dx.toDouble(), -7.0 - sh.hop, 6.0, c[6], 0.35 * g);
      if (sh.lid > 0.015) {
        for (var i = 0; i < 8; i++) {
          final x = -10.5 + i * 3.0 + sh.dx + (rand(i, 3) - 0.5) * 1.5;
          final a = -math.pi / 2.0 + (x / 11.0) * 1.25;
          final l = (7.0 + rand(i, (t * 30.0).floor(), 1) * 12.0) *
              math.min(1.0, sh.lid / 0.05);
          final y0 = -10.0 - sh.hop;
          p.lineShaded(
            x,
            y0,
            x + math.cos(a) * l,
            y0 + math.sin(a) * l,
            color: (u) => u < 0.25 ? kWhite : (u < 0.6 ? c[6] : c[5]),
            alpha: (u) => 1.15 - u,
          );
          p.glowLine(
            x,
            y0,
            x + math.cos(a) * l * 0.7,
            y0 + math.sin(a) * l * 0.7,
            3.0,
            c[5],
            0.25,
          );
        }
      }
    }
    for (final ray in rays) {
      final k = _rayK(ray);
      if (k <= 0.01) continue;
      final ox = math.sin(ray.a) * 7.0;
      const oy = -12.0;
      final dx = math.sin(ray.a);
      final dy = -math.cos(ray.a);
      final len = ray.len * (0.88 + 0.12 * math.sin(t * ray.f * 0.7 + ray.ph));
      final tw = math.tan(ray.w);
      final x1 = ox + dx * len;
      final y1 = oy + dy * len;
      p.shade(
        math.min(ox, x1) - 8.0,
        math.min(oy, y1) - 8.0,
        math.max(ox, x1) + 8.0,
        math.max(oy, y1) + 8.0,
        (x, y, out) {
          final rx = x - ox;
          final ry = y - oy;
          final d = rx * dx + ry * dy;
          if (d < 0.0 || d > len) return null;
          final q = (rx * dy - ry * dx).abs();
          final hw = 0.6 + d * tw;
          final f = q < hw ? 1.0 - 0.35 * (q / hw) : 0.65 * (1.0 - (q - hw) / 1.6);
          if (f <= 0.0) return null;
          out.l = q < hw * 0.45 ? c[6] : c[5];
          out.k = k *
              0.55 *
              f *
              math.pow(1.0 - d / len, 1.4).toDouble() *
              smooth(5.0, 14.0, d);
          return null;
        },
      );
    }
    if (t >= _tOpen && t < _tOpen + 0.2) {
      final a = (t - _tOpen) / 0.2;
      flare(p, 0.0, -14.0, 22.0 * math.pow(1.0 - a, 1.4).toDouble(), 1.0 - a, c);
    }
    for (final it in loot) {
      if (!it.up || it.gone) continue;
      final pu = t - it.pop;
      final lift = pu > 0.0 ? 6.0 * Ease.outCubic(clamp(pu / 0.1)) : 0.0;
      final wh = pu > 0.095;
      var y = it.y - lift;
      var ax = it.ax;
      var spin = it.spin;
      var flat = false;
      if (it.rest && !it.gem) {
        final wVal =
            math.exp(-it.settle * 8.0) * math.cos(it.settle * 22.0).abs();
        ax = 0.0;
        spin = math.acos(clamp(0.5 + 0.5 * wVal, 0.0, 1.0));
        flat = wVal < 0.12;
        y = flat ? -1.5 - lift : -it.r * math.cos(spin) - lift;
      }
      if (it.y > -10.0) {
        blobShadow(p, it.x, 3.0, 0.7 * (1.0 - clamp(-it.y / 30.0)));
      }
      if (it.gem) {
        gemlet(
          _itemLayer,
          p,
          it.x,
          y,
          it.r,
          it.rest ? 0.4 * it.vs.sign : it.spin,
          it.g!,
          white: wh,
        );
      } else {
        coin(
          _itemLayer,
          p,
          flat ? (it.x + 0.5).floor() + 0.5 : it.x,
          y,
          it.r,
          ax,
          flat ? math.acos(0.5) : spin,
          c,
          white: wh,
          a: 1.0,
          snap: !flat,
        );
      }
      p.glow(it.x, y, 9.0, it.gem ? it.g![4] : c[5], it.rest ? 0.26 : 0.18);
      p.glow(it.x, y, 3.0, kWhite, 0.12);
      if (it.rest && t < it.pop) {
        final u = (t * 0.9 + it.ph) % 1.0;
        if (u < 0.16) {
          glint(
            p,
            it.x - 1.0,
            y - 1.5,
            2.6 * math.sin((u / 0.16) * math.pi),
            it.gem ? it.g![5] : c[6],
            0.5,
          );
        }
      }
    }
    for (final ring in rings) {
      final k = (t - ring.t0) / 0.3;
      final e = Ease.outCubic(k);
      p.ring(
        ring.x,
        ring.y,
        2.0 + 5.0 * e,
        1.0,
        k < 0.3 ? kWhite : c[6],
        1.15 - k,
      );
      p.glow(ring.x, ring.y, 12.0, c[5], 0.45 * (1.0 - k));
      if (k < 0.5) {
        glint(p, ring.x, ring.y, 3.4 * (1.0 - k / 0.5), c[6], 0.55);
      }
    }
    ps.draw(p, 'front');
    dust.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect chestOpenEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'pickups/chest-open',
    name: 'Chest open',
    desc:
        'A banded chest rattles with gold light leaking from its seam, the lid kicks open, rays fan up, and coins and gems arc out, bounce, glint and get collected.',
    category: 'pickups',
    tags: ['pickup', 'chest', 'treasure', 'loot', 'reward', 'gold', 'one-shot'],
    size: (176, 112),
    origin: (88, 96),
    duration: 4.6,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#1e1206',
        '#4a2c08',
        '#86520c',
        '#c48412',
        '#f0b424',
        '#ffe066',
        '#fff6c4',
        '#ffffff',
      ],
      'wood': [
        '#110a10',
        '#24131a',
        '#3a1f1f',
        '#552d24',
        '#73402c',
        '#925737',
        '#b07246',
      ],
      'coins': 12,
      'seed': 3,
    },
  ),
  onCreate: _ChestOpenSim.new,
);
