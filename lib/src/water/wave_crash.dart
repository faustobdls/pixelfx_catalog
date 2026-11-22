// The lip's crescent (a thick arc, white on its outer rim, cooling to deep blue underneath, with light along it)
// follows Sprite Fusion's open-source slash (https://www.spritefusion.com/pixel-art-vfx/slash),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'water_lib.dart';

const double _duration = 3.2;
const double _sy = 0.22;
const double _g = 820.0;
const double _crash = 1.2;
const double _lip0 = 0.62;
const int _edge = 110;

double _crestX(double t) => t < _crash
    ? -80.0 + 72.0 * Ease.inOutSine(t / _crash)
    : -8.0 + 30.0 * Ease.outCubic(clamp((t - _crash) / 1.4));

double _crestH(double t) => t < _crash
    ? 5.0 + 33.0 * Ease.inOutSine(clamp(t / (_crash * 0.92)))
    : 38.0 * (1.0 - Ease.outCubic(clamp((t - _crash) / 0.45))) +
        5.0 * (1.0 - smooth(_crash, _crash + 1.6, t));

double _faceW(double t) => t < _crash
    ? 24.0 - 16.0 * smooth(0.3, _crash, t)
    : 8.0 + 14.0 * smooth(_crash, _crash + 0.6, t);

double _lipK(double t) => clamp((t - _lip0) / (_crash - _lip0));

class _Puff {
  double x;
  double y;
  double vx;
  double vy;
  final double r0;
  final double r1;
  double life;
  final double max;
  double delay;

  _Puff(
    this.x,
    this.y,
    this.vx,
    this.vy,
    this.r0,
    this.r1,
    this.life,
    this.delay,
  ) : max = life;
}

class _Plink {
  final double x;
  final double y;
  double age = 0.0;

  _Plink(this.x, this.y);
}

class _LipCell {
  final double x;
  final double y;
  final int c;
  final double q;

  _LipCell(this.x, this.y, this.c, this.q);
}

class _WaveCrashSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final int s;
  final Particles ps;
  final Mist mist = Mist();
  final Lights lights = Lights();
  final Ripples rings = Ripples(sy: _sy);
  final List<_Puff> puffs = [];
  final List<_Plink> plinks = [];
  late final Drops drops;
  double t = 0.0;
  bool crashed = false;

  _WaveCrashSim._internal(this.c, this.r, this.s) : ps = Particles(rng: r) {
    drops = Drops(
      sy: _sy,
      g: _g,
      onLand: (d) {
        rings.add(
          d.x,
          d.z,
          0.6,
          2.0 + d.s * 1.8,
          0.3 + d.s * 0.1,
          n: 1,
          k: 0.9,
          hot: 0.05,
        );
        plinks.add(_Plink(d.x, d.z * _sy));
      },
    );
  }

  factory _WaveCrashSim.fromOptions(Map<String, Object?> o) =>
      _WaveCrashSim._internal(
        fit(o.palette, 8),
        Rng(o.seed),
        o.seed,
      );

  double _height(double x, double tt) {
    final xc = _crestX(tt);
    final a = _crestH(tt);
    final dx = x - xc;
    final denom = dx < 0.0 ? 30.0 : _faceW(tt);
    return a * math.exp(-((dx / denom) * (dx / denom)));
  }

  (double, double, double) _lip(double sVal, double tt) {
    final k = _lipK(tt);
    final xc = _crestX(tt);
    final a = _crestH(tt);
    return (
      xc + 1.0 + sVal * 30.0 * math.pow(k, 0.8),
      -a -
          4.0 * sVal * (1.0 - sVal) * (1.0 + 4.0 * k) +
          sVal * sVal * a * Ease.inQuad(k) * 0.98,
      (11.0 - 8.5 * sVal) * (0.5 + 0.5 * k),
    );
  }

  void _puff(
    double x,
    double y,
    double vx,
    double vy,
    double r0,
    double r1,
    double life, [
    double delay = 0.0,
  ]) {
    puffs.add(_Puff(x, y, vx, vy, r0, r1, life, delay));
  }

  void _body(Painter p, double fade) {
    final xc = _crestX(t);
    final aVal = _crestH(t);
    for (var xi = -_edge; xi < _edge; xi++) {
      final x = xi + 0.5;
      final h = _height(x, t);
      final edge = 1.0 - smooth(_edge - 24.0, _edge.toDouble(), x.abs());
      if (h < 0.6 || edge <= 0.0) continue;
      final face = x > xc;
      final near = math.exp(-(((x - xc) / 9.0) * ((x - xc) / 9.0)));
      final a = fade * edge * 1.4;
      for (var yi = (-h).floor(); yi < 0; yi++) {
        final y = yi + 0.5;
        final u = (y + h) / h;
        final depth = y + h;
        final int col;
        if (depth < 1.0) {
          col = near > 0.5 && aVal > 14.0 && noise(x * 0.6 + t * 9.0, s) > -0.35
              ? kWhite
              : (face ? c[5] : c[6]);
        } else if (depth < 2.4 && near > 0.35 && aVal > 14.0) {
          col = noise2(x * 0.5, y * 0.5 + t * 6.0, s + 1) > -0.1 ? kWhite : c[6];
        } else {
          final win = near * (1.0 - u) * 1.6;
          final up = noise2(
            (x * 0.9 - y * 0.35) * 0.8,
            y * 0.12 + t * 5.0,
            s + 2,
          );
          final wind = noise2(x * 0.18 - t * 2.0, y * 0.9, s + 3);
          final fi = up > 0.55 && u < 0.85
              ? 6
              : (win > 0.8
                  ? 5
                  : (win > 0.45 || up > 0.3
                      ? 4
                      : (win > 0.2 || up > 0.05 ? 3 : (u < 0.6 ? 2 : 1))));
          final bi = u < 0.14
              ? 4
              : (wind > 0.55
                  ? 4
                  : (wind > 0.25 || u < 0.32 ? 3 : (u < 0.7 ? 2 : 1)));
          final idx = ((bi + (fi - bi) * smooth(xc - 5.0, xc + 5.0, x)) + 0.5)
              .floor();
          col = c[idx];
        }
        p.dot(xi, yi, col, a);
      }
    }
  }

  void _curl(Painter p) {
    final k = _lipK(t);
    if (k <= 0.0 || t >= _crash) return;
    final cells = <int, _LipCell>{};
    for (var sVal = 0.0; sVal <= 1.0; sVal += 0.012) {
      final (x, y, w) = _lip(sVal, t);
      final (x2, y2, _) = _lip(math.min(1.0, sVal + 0.012), t);
      final tx = x2 - x;
      final ty = y2 - y;
      final lRaw = hypot(tx, ty);
      final l = lRaw == 0.0 ? 1.0 : lRaw;
      final nx = ty / l;
      final ny = -tx / l;
      for (var q = 0.0; q <= 1.0; q += 0.5 / math.max(1.0, w)) {
        final px = x + nx * (q - 0.5) * w;
        final py = y + ny * (q - 0.5) * w;
        final key = py.floor() * 1024 + px.floor();
        final col = q < 0.18
            ? kWhite
            : (q < 0.36
                ? (sVal > 0.8 ? kWhite : c[6])
                : (q < 0.56 ? c[5] : (q < 0.76 ? c[4] : c[3])));
        final cur = cells[key];
        if (cur == null || q < cur.q) {
          cells[key] = _LipCell(px, py, col, q);
        }
      }
    }
    for (final cell in cells.values) {
      p.px(cell.x, cell.y, cell.c);
    }
    for (var sVal = 0.0; sVal <= 1.0; sVal += 0.125) {
      final (x, y, w) = _lip(sVal, t);
      p.glow(x, y, 6.0 + w, c[5], 0.24 * k);
    }
    final (tx, ty, _) = _lip(1.0, t);
    final g = math.sin(math.pi * clamp((k - 0.55) / 0.45));
    if (g > 0.05) sparkle(p, tx, ty, 6.0 * g, c[6], c[5], 0.5 * g);
    final (bx, by, _) = _lip(0.6, t);
    p.glow(bx - 3.0, by + 8.0, 16, c[4], 0.25 * k);
  }

  void _sea(Painter p, double fade) {
    for (var xi = -_edge; xi < _edge; xi++) {
      final x = xi + 0.5;
      final edge = 1.0 - smooth(_edge - 30.0, _edge.toDouble(), x.abs());
      final a = fade * edge;
      if (a <= 0.02) continue;
      final g = noise(x * 0.3 - t * 3.0, s + 4);
      p.dot(xi, 0, g > 0.55 ? c[6] : c[4], a * 1.2);
      p.blend(x, 1.5, c[2], 0.6 * a);
      p.blend(x, 2.5, c[1], 0.45 * a);
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final k = _lipK(t);
    if (t < _crash && _crestH(t) > 14.0 && r.chance(0.5)) {
      final xc = _crestX(t);
      final aVal = _crestH(t);
      final px = xc + r.range(-4.0, 3.0);
      final py = -aVal - r.range(0.0, 2.0);
      final pvx = -r.range(20.0, 60.0);
      final pvy = -r.range(10.0, 40.0);
      final plife = r.range(0.5, 0.9);
      final pc = r.chance(0.5) ? kWhite : c[6];
      final psize = r.range(0.6, 1.3);
      ps.spawn(P.flake, px, py, pvx, pvy, plife, pc, psize);
    }
    if (k > 0.3 && t < _crash && r.chance(0.35)) {
      final (x, y, _) = _lip(1.0, t);
      final dz = r.range(-3.0, 3.0);
      final vx = r.range(30.0, 90.0);
      final vz = r.range(-10.0, 10.0);
      final vh = r.range(-20.0, 40.0);
      final ds = r.chance(0.3) ? 2 : 1;
      drops.add(WaterDrop(
        x: x,
        z: dz,
        h: -y,
        vx: vx,
        vz: vz,
        vh: vh,
        s: ds,
      ));
    }
    if (!crashed && t >= _crash) {
      crashed = true;
      final (x0, _, _) = _lip(1.0, _crash - 1e-3);
      lights.add(x0, -20, 56, c[5], 0.8, 0.55);
      lights.add(x0, -4, 22, kWhite, 0.6, 0.1);
      for (var i = 0; i < 46; i++) {
        final a = r.range(-0.9, 0.6) * math.pi;
        final v = r.range(30.0, 120.0);
        final dx = x0 + r.range(-6.0, 6.0);
        final dz = r.range(-4.0, 4.0);
        final dh = r.range(2.0, 8.0);
        final vh = r.range(120.0, 320.0);
        final ds = r.chance(0.15) ? 3 : (r.chance(0.35) ? 2 : 1);
        final delay = r.range(0.0, 0.1);
        drops.add(WaterDrop(
          x: dx,
          z: dz,
          h: dh,
          vx: math.cos(a) * v * 0.85 + 18.0,
          vz: math.sin(a) * v * 0.5,
          vh: vh,
          s: ds,
          delay: delay,
        ));
      }
      for (var i = 0; i < 14; i++) {
        final dx = x0 + r.range(-3.0, 3.0);
        final dz = r.range(-2.0, 2.0);
        final dh = r.range(2.0, 6.0);
        final vx = r.range(-15.0, 25.0);
        final vz = r.range(-8.0, 8.0);
        final vh = r.range(220.0, 300.0);
        final ds = r.chance(0.3) ? 2 : 1;
        final delay = r.range(0.04, 0.16);
        drops.add(WaterDrop(
          x: dx,
          z: dz,
          h: dh,
          vx: vx,
          vz: vz,
          vh: vh,
          s: ds,
          delay: delay,
        ));
      }
      for (var i = 0; i < 34; i++) {
        final fx = x0 + r.range(-12.0, 10.0);
        final fy = -r.range(2.0, 12.0);
        final fvx = r.range(-40.0, 130.0);
        final fvy = -r.range(30.0, 150.0);
        final fr0 = r.range(1.0, 2.0);
        final fr1 = r.range(1.8, 4.2);
        final flife = r.range(0.4, 0.95);
        final fdelay = r.range(0.0, 0.14);
        _puff(fx, fy, fvx, fvy, fr0, fr1, flife, fdelay);
      }
      for (var i = 0; i < 34; i++) {
        final a = r.range(-math.pi * 0.95, -math.pi * 0.05);
        final v = r.range(40.0, 160.0);
        final px = x0 + r.range(-8.0, 8.0);
        final py = -r.range(4.0, 14.0);
        final plife = r.range(0.6, 1.3);
        final pc = r.chance(0.5) ? kWhite : c[6];
        final psize = r.range(0.6, 1.4);
        final pdelay = r.range(0.0, 0.1);
        ps.spawn(
          P.flake,
          px,
          py,
          math.cos(a) * v + 25.0,
          math.sin(a) * v,
          plife,
          pc,
          psize,
          pdelay,
        );
      }
      for (var i = 0; i < 12; i++) {
        final mx = x0 + r.range(-10.0, 14.0);
        final my = -r.range(3.0, 16.0);
        final mvx = r.range(-20.0, 70.0);
        final mvy = -r.range(6.0, 24.0);
        final mr1 = r.range(9.0, 15.0);
        final mlife = r.range(1.1, 1.7);
        final mc = r.chance(0.5) ? c[6] : kWhite;
        final mdelay = r.range(0.0, 0.2);
        mist.add(mx, my, mvx, mvy, 3.0, mr1, mlife, mc, 0.26, mdelay);
      }
      for (var i = 0; i < 10; i++) {
        final px = x0 + r.range(-20.0, 24.0);
        final py = -r.range(6.0, 40.0);
        final plife = r.range(0.3, 0.6);
        final psize = r.range(1.0, 2.4);
        final pdelay = r.range(0.05, 0.4);
        ps.spawn(P.star, px, py, 0.0, -5.0, plife, c[6], psize, pdelay);
      }
      rings.add(x0, 0, 6, 40, 1.2, n: 2, gap: 3, k: 1.1, hot: 0.12);
    }
    if (crashed && t < _crash + 1.1 && r.chance(0.45 * (1.0 - (t - _crash) / 1.1))) {
      final x = _crestX(t) + r.range(-6.0, 14.0);
      final fy = -r.range(1.0, 4.0);
      final fvx = r.range(10.0, 40.0);
      final fvy = -r.range(10.0, 40.0);
      final fr0 = r.range(0.9, 1.8);
      final fr1 = r.range(1.8, 3.6);
      final flife = r.range(0.4, 0.8);
      _puff(x, fy, fvx, fvy, fr0, fr1, flife);
    }
    if (crashed && t < _crash + 0.8 && r.chance(0.12)) {
      final mx = _crestX(t) + r.range(-8.0, 8.0);
      final my = -r.range(2.0, 6.0);
      final mvx = r.range(10.0, 40.0);
      final mvy = -r.range(3.0, 10.0);
      final mr1 = r.range(7.0, 11.0);
      final mlife = r.range(0.8, 1.1);
      mist.add(mx, my, mvx, mvy, 3.0, mr1, mlife, c[6], 0.2);
    }
    for (var i = puffs.length - 1; i >= 0; i--) {
      final f = puffs[i];
      if (f.delay > 0.0) {
        f.delay -= dt;
        continue;
      }
      f.life -= dt;
      if (f.life <= 0.0) {
        puffs.removeAt(i);
        continue;
      }
      f.vx -= f.vx * 2.5 * dt;
      f.vy += (160.0 - f.vy * 2.5) * dt;
      f.x += f.vx * dt;
      f.y = math.min(f.y + f.vy * dt, -1.0);
    }
    for (var i = plinks.length - 1; i >= 0; i--) {
      if ((plinks[i].age += dt) > 0.12) plinks.removeAt(i);
    }
    drops.update(dt);
    rings.update(dt);
    mist.update(dt);
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final fade = smooth(0.0, 0.25, t) *
        (1.0 - smooth(_duration - 0.7, _duration - 0.1, t));
    _sea(p, fade);
    rings.draw(p, c, -1);
    drops.draw(p, c, 'back');
  }

  @override
  void draw(Painter p) {
    final fade = smooth(0.0, 0.25, t) *
        (1.0 - smooth(_duration - 0.7, _duration - 0.1, t));
    _body(p, fade);
    _curl(p);
    rings.draw(p, c, 1);
    if (crashed) {
      final k = 1.0 - smooth(_crash + 0.4, _duration - 0.15, t);
      const x0 = -20.0;
      final x1 = _crestX(t) + 10.0;
      for (var xi = x0.floor(); xi < x1; xi++) {
        final x = xi + 0.5;
        final n = 1.0 - noise2(x * 0.35, t * 0.8, s + 7).abs() * 4.0;
        if (n > 1.15 - k * 1.1) p.px(xi, 0, n > 1.4 - k ? kWhite : c[6]);
        if (n > 1.4 - k * 0.9) p.px(xi, 1, c[5]);
      }
    }
    for (final f in puffs) {
      if (f.delay > 0.0) continue;
      final g = 1.0 - f.life / f.max;
      final rad = (f.r0 + (f.r1 - f.r0) * Ease.outCubic(g)) *
          (1.0 - smooth(0.7, 1.0, g));
      if (rad > 0.6) billow(p, f.x, f.y, rad, c);
    }
    for (final q in plinks) {
      if (q.age < 0.06) p.px(q.x, q.y, kWhite);
      p.glow(q.x, q.y, 4, c[5], 0.25 * (1.0 - q.age / 0.12));
    }
    drops.draw(p, c, 'front');
    final f = (t - _crash) / 0.08;
    if (f >= 0.0 && f < 1.0) {
      final (x0, _, _) = _lip(1.0, _crash - 1e-3);
      p.circle(x0, -3.0, 8.0 * (1.0 - f * 0.4), kWhite);
      p.ellipseShaded(x0, 0, 14, 2.6, color: (d, _) => d < 0.6 ? kWhite : c[6]);
    }
    ps.draw(p);
    mist.draw(p, c[5]);
    lights.draw(p);
    if (t < _crash) {
      p.glow(
        _crestX(t) + 4.0,
        -_crestH(t) + 2.0,
        26,
        c[4],
        0.22 * smooth(0.2, _crash, t),
      );
      p.glowLine(
        _crestX(t) - 26.0,
        -_crestH(t) * 0.45,
        _crestX(t),
        -_crestH(t),
        10,
        c[5],
        0.14 * smooth(0.2, _crash, t),
      );
    } else {
      p.glow(
        _crestX(t),
        -10,
        34,
        c[4],
        0.26 * (1.0 - smooth(_crash, _duration - 0.3, t)),
      );
    }
  }
}

final SimulatedEffect waveCrashEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'water/wave-crash',
    name: 'Wave crash',
    desc:
        'A swell rolls in and steepens, its lip throws forward and curls over a dark barrel, then crashes into a burst of white foam and spray that surges on and fades to lace.',
    category: 'water',
    tags: ['water', 'wave', 'crash', 'surf', 'foam', 'spray', 'one-shot'],
    size: (224, 104),
    origin: (112, 86),
    duration: 3.2,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': kWaterPalette,
      'seed': 6,
    },
  ),
  onCreate: _WaveCrashSim.fromOptions,
);
