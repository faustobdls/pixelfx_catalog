// The column (a banded white core, strands running through it, light down its length) and the slam with its
// floor ring follow Sprite Fusion's open-source holy-light (https://www.spritefusion.com/pixel-art-vfx/holy-light),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'water_lib.dart';

const double _sy = 0.22;
const double _g = 820.0;
const double _erupt = 1.15;
const double _fall = 2.6;
const double _gone = 3.3;

// small spurts while it builds, and the sputters after: [time, height]
const List<(double, double)> _spurts = [
  (0.46, 7.0),
  (0.72, 12.0),
  (0.92, 9.0),
  (1.04, 15.0),
  (_gone + 0.15, 15.0),
  (_gone + 0.55, 8.0),
];

class _Pop {
  final double x;
  final double y;
  final double r;
  double age = 0.0;

  _Pop(this.x, this.y, this.r);
}

class _Plink {
  final double x;
  final double y;
  final int s;
  double age = 0.0;

  _Plink(this.x, this.y, this.s);
}

class _GeyserSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final double hMax;
  final int s;
  final Particles ps;
  final Mist mist = Mist();
  final Lights lights = Lights();
  final Ripples rings = Ripples(sy: _sy);
  final List<_Plink> plinks = [];
  final List<_Pop> pops = [];
  final Set<WaterDrop> smallDrops = Set<WaterDrop>.identity();
  final Set<String> done = <String>{};
  final double v0;
  late final Drops drops;
  double t = 0.0;

  _GeyserSim._internal(
    this.c,
    this.r,
    this.hMax,
    this.s,
  )   : ps = Particles(rng: r),
        v0 = math.sqrt(2.0 * _g * hMax) {
    drops = Drops(
      sy: _sy,
      g: _g,
      onLand: (d) {
        final inPool = hypot(d.x, d.z) < _poolR(t);
        rings.add(
          d.x,
          d.z,
          0.6,
          (inPool ? 2.5 : 1.5) + d.s * 1.6,
          0.32 + d.s * 0.1,
          n: 1,
          k: inPool ? 0.95 : 0.7,
          hot: 0.05,
        );
        plinks.add(_Plink(d.x, d.z * _sy, d.s));
        final isSmall = smallDrops.remove(d);
        if (d.s > 1 && !isSmall) {
          for (var i = 0; i < 2; i++) {
            final a = r.range(0.0, tau);
            final v = r.range(8.0, 28.0);
            final vh = r.range(45.0, 95.0);
            final sub = WaterDrop(
              x: d.x,
              z: d.z,
              h: 0.5,
              vx: math.cos(a) * v,
              vz: math.sin(a) * v,
              vh: vh,
              s: 1,
              life: 1.0,
            );
            smallDrops.add(sub);
            drops.add(sub);
          }
        }
      },
    );
  }

  factory _GeyserSim(Map<String, Object?> o) => _GeyserSim._internal(
        fit(o.palette, 8),
        Rng(o.seed),
        o.numOpt('height', 100),
        o.seed,
      );

  double _poolR(double tt) =>
      (12.0 +
          7.0 * smooth(0.0, 1.0, tt) +
          15.0 * Ease.outCubic(clamp((tt - _erupt) / 1.2))) *
      (1.0 - 0.25 * smooth(_gone, 4.6, tt));

  double _poolK(double tt) =>
      smooth(0.0, 0.2, tt) * (1.0 - smooth(4.0, 4.85, tt));

  double _top(double tt) {
    if (tt < _erupt || tt > _gone) return 0.0;
    return hMax *
        Ease.outCubic(clamp((tt - _erupt) / 0.3)) *
        (0.93 + 0.07 * noise(tt * 2.2, s)) *
        (1.0 - Ease.inQuad(clamp((tt - _fall) / (_gone - _fall))));
  }

  double _head(double tt) =>
      smooth(_erupt + 0.08, _erupt + 0.3, tt) *
      (1.0 - smooth(_fall + 0.1, _fall + 0.45, tt));

  double _spurt(double tt) {
    var h = 0.0;
    for (final (s0, hs) in _spurts) {
      h = math.max(
        h,
        hs * math.sin(math.pi * clamp((tt - s0) / 0.2)),
      );
    }
    return h;
  }

  bool _once(String key, double at) =>
      !done.contains(key) && t >= at && done.add(key);

  bool _emit(double rate, double dt) => r.chance(math.min(1.0, rate * dt));

  void _column(Painter p, double hVal, double thin) {
    if (hVal < 1.0) return;
    double tauFn(double h) =>
        (v0 -
            math.sqrt(
                math.max(0.0, v0 * v0 - 2.0 * _g * math.min(h, hMax * 0.96)))) /
        _g;
    final colPalette = [kWhite, c[6], c[5], c[4], c[3]];
    p.shade(-22.0, -hVal - 2.0, 22.0, 0.0, (x, y, _) {
      final h = -y;
      final v = h / hVal;
      final sway = noise(t * 1.6 + h * 0.025, s + 5) * 2.5 * v;
      final rag = noise2(h * 0.2 - t * 11.0, x < sway ? 3.0 : 7.0, s + 6) *
          (0.5 + 1.8 * v);
      final w = (3.6 + 7.5 * math.pow(v, 1.8)) * thin + rag;
      final q = (x - sway) / math.max(1.0, w);
      final aq = q.abs();
      if (aq > 1.0) return null;
      final xi = x.floor();
      final streak = noise2(xi * 1.618 + 0.3, (tauFn(h) - t) * 14.0, s);
      final body = noise2(
        ((x + 40.0) / 2.0).floor() * 2.3,
        (tauFn(h) - t) * 5.0,
        s + 1,
      );
      var lvl = aq < 0.42 ? 0 : (aq < 0.7 ? 1 : (aq < 0.9 ? 2 : 3));
      if (q > 0.38) lvl++;
      if (streak > 0.28) lvl--;
      if (body < -0.4) lvl++;
      return colPalette[lvl.clamp(0, 4)];
    });
    p.glowLine(0, 0, 0, -hVal, 16.0 + 8.0 * thin, c[5], 0.12 * thin);
  }

  void _foamHead(Painter p, double hVal, double k, bool back) {
    if (k <= 0.01 || hVal < 4.0) return;
    if (back) {
      for (var i = 0; i < 16; i++) {
        final side = i % 2 != 0 ? 1 : -1;
        final x0 = side * (5.0 + 9.0 * rand(i, s + 20)) * k;
        final len = (14.0 + 26.0 * rand(i, s + 21)) * k;
        final speed = 70.0 + 50.0 * rand(i, s + 22);
        for (var j = 0; j < 3; j++) {
          final f = ((t * speed / len + j / 3.0 + rand(i, s + 23)) % 1.0 +
                  1.0) %
              1.0;
          final y0 = -hVal + 2.0 + f * len;
          final x = x0 + side * f * f * 6.0;
          final l = 1.0 + 4.0 * f * (1.0 - f) * 2.0;
          if (f < 0.85) {
            p.line(
              x,
              y0,
              x + side * 0.6,
              y0 + l,
              f < 0.4 ? c[6] : (f < 0.7 ? c[5] : c[4]),
            );
          }
        }
      }
    }
    final backBillowPalette = [c[0], c[1], c[2], c[3], c[3], c[4], c[5], c[5]];
    for (var i = 0; i < 12; i++) {
      final a = (i / 12.0) * tau + t * (i % 2 != 0 ? 1.3 : -1.1);
      final z = math.sin(a);
      if ((z < 0.0) != back) continue;
      final rho = (3.0 + 7.0 * rand(i, s)) * k;
      final x = math.cos(a) * rho * 1.25 + noise(t * 3.0 + i, s + 8) * 2.5;
      final y = -hVal +
          z * rho * 0.45 +
          (rho / 10.0) * 4.0 -
          4.0 * (1.0 - rho / (10.0 * k)) +
          noise(t * 3.0 + i + 50, s + 9) * 2.5;
      final rad =
          (2.0 + 2.6 * rand(i, s + 2) + 0.7 * math.sin(t * 7.0 + i)) * k;
      if (back) {
        billow(p, x, y, rad, backBillowPalette);
      } else {
        p.circle(x + rad * 0.15, y + rad * 0.25, rad, c[4]);
        p.circle(x, y, rad * 0.82, rho > 6.0 * k ? c[5] : c[6]);
        p.circle(x - rad * 0.25, y - rad * 0.3, rad * 0.5, kWhite);
      }
    }
    if (!back) p.glow(0, -hVal - 2.0, 38, c[5], 0.34 * k);
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final hVal = _top(t);
    final hk = _head(t);
    final k = t / _erupt;
    if (t < _erupt && _emit(1.5 + 9.0 * k * k, dt)) {
      final a = r.range(0.0, tau);
      final rad = r.range(0.0, 7.0);
      final x = math.cos(a) * rad;
      final z = math.sin(a) * rad;
      final py = z * _sy - r.range(1.0, 3.0);
      final pr = r.range(1.0, 2.0);
      pops.add(_Pop(x, py, pr));
      final rr = r.range(5.0, 9.0);
      rings.add(x, z, 1.0, rr, 0.55, n: 1, k: 0.85);
      for (var i = 0; i < r.intRange(1, 3); i++) {
        final vx = r.range(-25.0, 25.0);
        final vz = r.range(-15.0, 15.0);
        final vh = r.range(50.0, 120.0);
        final sub = WaterDrop(
          x: x,
          z: z,
          h: 2.0,
          vx: vx,
          vz: vz,
          vh: vh,
          s: 1,
          life: 1.0,
        );
        smallDrops.add(sub);
        drops.add(sub);
      }
    }
    if (t < _erupt && _emit(3.0 + 7.0 * k, dt)) {
      final mx = r.range(-8.0, 8.0);
      final my = -r.range(1.0, 5.0);
      final mvx = r.range(-10.0, 10.0);
      final mvy = -r.range(6.0, 18.0);
      final mr1 = r.range(5.0, 9.0);
      final mlife = r.range(0.9, 1.5);
      mist.add(mx, my, mvx, mvy, 2.0, mr1, mlife, c[6], 0.22);
    }
    for (final (s0, hs) in _spurts) {
      if (_once('spurt$s0', s0 + 0.08)) {
        final count = 3 + ((hs / 4.0) + 0.5).floor();
        for (var i = 0; i < count; i++) {
          final a = r.range(0.0, tau);
          final v = r.range(10.0, 40.0);
          final vh = r.range(20.0, 90.0);
          final ds = r.chance(0.3) ? 2 : 1;
          drops.add(WaterDrop(
            x: 0.0,
            z: 0.0,
            h: hs * 0.8,
            vx: math.cos(a) * v,
            vz: math.sin(a) * v,
            vh: vh,
            s: ds,
          ));
        }
      }
    }
    if (_once('erupt', _erupt)) {
      lights.add(0, -26, 64, c[5], 0.85, 0.6);
      lights.add(0, -4, 28, kWhite, 0.75, 0.1);
      rings.add(0, 0, 6, 40, 1.2, n: 2, gap: 3, k: 1.2, hot: 0.12, glint: 1);
      for (var i = 0; i < 44; i++) {
        final a = r.range(0.0, tau);
        final v = r.range(30.0, 120.0);
        final dh = r.range(2.0, 10.0);
        final vx = math.cos(a) * v;
        final vz = math.sin(a) * v;
        final vh = r.range(180.0, 400.0);
        final ds = r.chance(0.15) ? 3 : (r.chance(0.35) ? 2 : 1);
        final delay = r.range(0.0, 0.12);
        drops.add(WaterDrop(
          x: math.cos(a) * 3.0,
          z: math.sin(a) * 3.0,
          h: dh,
          vx: vx,
          vz: vz,
          vh: vh,
          s: ds,
          delay: delay,
        ));
      }
      for (var i = 0; i < 12; i++) {
        final side = i % 2 != 0 ? 1 : -1;
        final mx = side * r.range(3.0, 9.0);
        final my = -r.range(1.0, 6.0);
        final mvx = side * r.range(30.0, 80.0);
        final mvy = -r.range(4.0, 18.0);
        final mr1 = r.range(9.0, 14.0);
        final mlife = r.range(1.2, 1.9);
        final mc = r.chance(0.5) ? c[6] : kWhite;
        final delay = r.range(0.0, 0.15);
        mist.add(mx, my, mvx, mvy, 3.0, mr1, mlife, mc, 0.3, delay);
      }
      for (var i = 0; i < 14; i++) {
        final px = r.range(-16.0, 16.0);
        final py = -r.range(8.0, 80.0);
        final pvx = r.range(-10.0, 10.0);
        final plife = r.range(0.3, 0.7);
        final pc = r.chance(0.5) ? kWhite : c[6];
        final psize = r.range(1.0, 2.6);
        final pdelay = r.range(0.05, 0.5);
        ps.spawn(P.star, px, py, pvx, -6.0, plife, pc, psize, pdelay);
      }
    }
    if (hk > 0.0) {
      if (_emit(60.0 * hk, dt)) {
        final a = r.range(0.0, tau);
        final v = r.range(10.0, 60.0);
        final dx = r.range(-9.0, 9.0);
        final dz = r.range(-4.0, 4.0);
        final dh = hVal + r.range(-8.0, 3.0);
        final vh = r.range(-40.0, 60.0);
        final ds = r.chance(0.08) ? 3 : (r.chance(0.3) ? 2 : 1);
        drops.add(WaterDrop(
          x: dx,
          z: dz,
          h: dh,
          vx: math.cos(a) * v,
          vz: math.sin(a) * v,
          vh: vh,
          s: ds,
        ));
      }
      if (_emit(9.0 * hk, dt)) {
        final mx = r.range(-8.0, 8.0);
        final my = -hVal + r.range(-6.0, 2.0);
        final mvx = r.range(-34.0, 34.0);
        final mvy = -r.range(14.0, 34.0);
        final mr1 = r.range(8.0, 13.0);
        final mlife = r.range(0.9, 1.4);
        final mc = r.chance(0.6) ? c[6] : kWhite;
        mist.add(mx, my, mvx, mvy, 3.0, mr1, mlife, mc, 0.2);
      }
      if (_emit(5.0 * hk, dt)) {
        final s1 = r.sign();
        final mx = s1 * r.range(3.0, 9.0);
        final my = -r.range(1.0, 6.0);
        final s2 = r.sign();
        final mvx = s2 * r.range(20.0, 50.0);
        final mvy = -r.range(2.0, 10.0);
        final mr1 = r.range(8.0, 12.0);
        final mlife = r.range(1.0, 1.6);
        mist.add(mx, my, mvx, mvy, 3.0, mr1, mlife, c[6], 0.22);
      }
      if (_emit(40.0 * hk, dt)) {
        final side = r.sign();
        final hh = r.range(8.0, hVal * 0.95);
        final pvx = side * r.range(10.0, 45.0);
        final pvy = r.range(-20.0, 10.0);
        final plife = r.range(0.6, 1.2);
        final pc = r.chance(0.5) ? kWhite : c[6];
        final psize = r.range(0.6, 1.3);
        ps.spawn(
          P.flake,
          side * (3.0 + 6.0 * math.pow(hh / hVal, 1.8)),
          -hh,
          pvx,
          pvy,
          plife,
          pc,
          psize,
        );
      }
      if (_emit(4.0 * hk, dt)) {
        final rx = r.range(-2.0, 2.0);
        final rz = r.range(-2.0, 2.0);
        final rr1 = _poolR(t) * r.range(0.7, 1.0);
        rings.add(rx, rz, 4.0, rr1, 0.9, n: 1, k: 0.8);
      }
      if (_emit(7.0 * hk, dt)) {
        final px = r.range(-14.0, 14.0);
        final py = -r.range(10.0, hVal + 8.0);
        final pvx = r.range(-6.0, 6.0);
        final plife = r.range(0.25, 0.55);
        final pc = r.chance(0.4) ? kWhite : c[6];
        final psize = r.range(0.8, 2.2);
        ps.spawn(P.star, px, py, pvx, -4.0, plife, pc, psize, 0.0);
      }
    }
    if (_once('collapse', _fall + 0.12)) {
      for (var i = 0; i < 40; i++) {
        final a = r.range(0.0, tau);
        final v = r.range(15.0, 80.0);
        final dx = r.range(-6.0, 6.0);
        final dz = r.range(-3.0, 3.0);
        final dh = _top(t) + r.range(-8.0, 4.0);
        final vh = r.range(-40.0, 60.0);
        final ds = r.chance(0.12) ? 3 : (r.chance(0.35) ? 2 : 1);
        final delay = r.range(0.0, 0.25);
        drops.add(WaterDrop(
          x: dx,
          z: dz,
          h: dh,
          vx: math.cos(a) * v,
          vz: math.sin(a) * v,
          vh: vh,
          s: ds,
          delay: delay,
        ));
      }
      for (var i = 0; i < 6; i++) {
        final mx = r.range(-8.0, 8.0);
        final my = -_top(t) + r.range(-6.0, 6.0);
        final mvx = r.range(-34.0, 34.0);
        final mvy = -r.range(10.0, 26.0);
        final mr1 = r.range(9.0, 13.0);
        final mlife = r.range(0.8, 1.2);
        mist.add(mx, my, mvx, mvy, 4.0, mr1, mlife, c[6], 0.18);
      }
    }
    for (var i = pops.length - 1; i >= 0; i--) {
      if ((pops[i].age += dt) > 0.12) pops.removeAt(i);
    }
    for (var i = plinks.length - 1; i >= 0; i--) {
      if ((plinks[i].age += dt) > 0.14) plinks.removeAt(i);
    }
    drops.update(dt);
    rings.update(dt);
    mist.update(dt);
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final pr = _poolR(t);
    final pk = _poolK(t);
    if (pk > 0.0) {
      p.each(-pr, -pr * _sy, pr, pr * _sy, (x, y, sx, sy) {
        final d = (x / pr) * (x / pr) + (y / (pr * _sy)) * (y / (pr * _sy));
        if (d > 1.0) return;
        p.blendPx(
          sx,
          sy,
          d < 0.15 ? c[2] : c[1],
          0.6 * pk * math.min(1.0, (1.0 - d) * 4.0),
        );
        if (y < 0.0 && d > 0.78 && d < 0.95) {
          p.blendPx(sx, sy, c[4], 0.7 * pk);
        }
      });
    }
    rings.draw(p, c, -1);
    final u = (t - _erupt) / 0.4;
    if (u > 0.0 && u < 1.0) {
      ring(
        p,
        0.0,
        0.5,
        6.0 + 42.0 * Ease.outCubic(u),
        _sy,
        1.5 * (1.0 - u),
        c,
        n: 3,
        gap: 1.6 + 2.0 * u,
        half: -1,
        hot: u < 0.3,
        seed: 9,
      );
    }
    _foamHead(p, _top(t), _head(t), true);
    drops.draw(p, c, 'back');
  }

  @override
  void draw(Painter p) {
    final hVal = _top(t);
    final hk = _head(t);
    final k = clamp(t / _erupt);
    final thin = smooth(_erupt, _erupt + 0.12, t) *
        (1.0 - 0.55 * smooth(_fall, _gone, t));
    rings.draw(p, c, 1);
    final u = (t - _erupt) / 0.4;
    if (u > 0.0 && u < 1.0) {
      ring(
        p,
        0.0,
        0.5,
        6.0 + 42.0 * Ease.outCubic(u),
        _sy,
        1.5 * (1.0 - u),
        c,
        n: 3,
        gap: 1.6 + 2.0 * u,
        half: 1,
        hot: u < 0.3,
        seed: 9,
      );
    }
    final fk = smooth(_erupt, _erupt + 0.3, t) *
        (1.0 - smooth(_gone - 0.3, 4.4, t));
    if (fk > 0.0) {
      lace(p, 0.0, 0.0, 8.0 + 10.0 * fk, (8.0 + 10.0 * fk) * _sy + 0.5, fk,
          c, t, s);
    }
    if (t < _erupt + 0.05) {
      final beat = math.pow(
        math.max(0.0, math.sin(t * (8.0 + 18.0 * k * k))),
        3.0,
      );
      final rd = 4.0 + 3.5 * k + 1.5 * beat;
      final hd = 1.5 + 3.0 * k + 3.0 * beat;
      p.shade(-rd - 1.0, -hd - 1.0, rd + 1.0, 0.5, (x, y, _) {
        final dx = x / rd;
        final dy = y / hd;
        final d = dx * dx + dy * dy;
        if (d > 1.0 || y > 0.5) return null;
        final lit = -dx * 0.7 - dy * 0.7;
        final rim = d > 0.68;
        return rim
            ? (lit > 0.3 ? kWhite : (lit > -0.15 ? c[6] : c[4]))
            : (lit > 0.55
                ? c[6]
                : (lit > 0.12 ? c[5] : (lit > -0.3 ? c[4] : c[3])));
      });
      p.px(-rd * 0.35, -hd * 0.6, kWhite);
      p.glow(
        0,
        -5,
        16.0 + 16.0 * k + 8.0 * beat,
        c[5],
        0.06 + 0.12 * k + 0.12 * beat,
      );
    }
    final sp = _spurt(t);
    if (sp > 1.0 && hVal < 1.0) {
      p.shade(-2.0, -sp - 1.0, 2.0, 0.0, (x, y, _) {
        final q = x / (1.0 + 0.8 * (1.0 + y / sp));
        if (q.abs() > 1.0) return null;
        return q < -0.3 ? c[6] : (q < 0.35 ? kWhite : c[5]);
      });
      p.circle(0, -sp, 1.3, c[6]);
      p.px(0, -sp - 1.0, kWhite);
      p.glowLine(0, 0, 0, -sp, 8, c[5], 0.3);
    }
    _column(p, hVal, thin);
    if (hk > 0.0 || (hVal > 1.0 && t < _gone)) {
      for (var i = 0; i < 7; i++) {
        final a = (i / 7.0) * tau + t * 2.1;
        final rad = 4.0 + 2.0 * math.sin(t * 5.0 + i * 1.7);
        final x = math.cos(a) * rad * 1.3;
        final y = math.sin(a) * rad * _sy - 2.0;
        billow(
          p,
          x,
          y,
          (1.6 + 1.2 * rand(i, s + 4)) * math.max(hk, thin * 0.6),
          c,
        );
      }
    }
    _foamHead(p, hVal, hk, false);
    for (final q in pops) {
      final g = q.age / 0.12;
      for (final (dx, dy) in const [
        (1.0, 0.0),
        (-1.0, 0.0),
        (0.7, -0.7),
        (-0.7, -0.7),
        (0.0, -1.0),
      ]) {
        p.dot(
          q.x + dx * (q.r + 3.0 * g),
          q.y + dy * (q.r + 3.0 * g),
          c[6],
          1.0 - g,
        );
      }
    }
    for (final q in plinks) {
      final g = q.age / 0.14;
      if (g < 0.5) p.px(q.x, q.y, kWhite);
      if (q.s > 1) {
        p.line(
          q.x,
          q.y - 1.0,
          q.x,
          q.y - 1.0 - 3.0 * (1.0 - g),
          g < 0.4 ? kWhite : c[6],
        );
      }
      p.glow(q.x, q.y, 4, c[5], 0.25 * (1.0 - g));
    }
    drops.draw(p, c, 'front');
    final f = (t - _erupt) / 0.07;
    if (f >= 0.0 && f < 1.0) {
      p.circle(0, -4, 7.0 * (1.0 - f * 0.4), kWhite);
      p.ellipseShaded(0, 0, 12, 2.6, color: (d, _) => d < 0.6 ? kWhite : c[6]);
    }
    ps.draw(p);
    mist.draw(p, c[5]);
    lights.draw(p);
    if (hVal > 1.0) p.glowLine(0, 0, 0, -hVal, 26, c[4], 0.2 * thin);
    p.glow(
      0,
      -2,
      46,
      c[4],
      0.24 * math.max(hk, 0.3 * k * (t < _erupt ? 1.0 : 0.0)),
    );
    p.glow(0, 2, 60, c[3], 0.12 * _poolK(t));
  }
}

final SimulatedEffect geyserEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'water/geyser',
    name: 'Geyser',
    desc:
        'A pool heaves and burbles faster and faster, then blasts a white column of water skyward with a churning foam head; it rains back down in drops and steam, slumps and sputters out.',
    category: 'water',
    tags: [
      'water',
      'geyser',
      'eruption',
      'steam',
      'column',
      'nature',
      'one-shot',
    ],
    size: (184, 168),
    origin: (92, 146),
    duration: 5.0,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': kWaterPalette,
      'height': 100,
      'seed': 4,
    },
  ),
  onCreate: _GeyserSim.new,
);
