// The droplet recipe (shaded beads with tails that fly, land and throw up a little crown of their own) is
// adapted from Sprite Fusion's open-source blood (https://www.spritefusion.com/pixel-art-vfx/blood),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'water_lib.dart';

const double _sy = 0.22;
const double _hit = 0.16;
const double _g = 820.0;
const int _fingers = 12;
const double _jet = 0.3;
const double _tear = 0.11;

double _height(double u) =>
    19.0 *
    Ease.outCubic(clamp(u / 0.09)) *
    (1.0 - Ease.inQuad(clamp((u - 0.12) / 0.3)));

double _foot(double u) => 3.0 + 7.5 * Ease.outCubic(clamp(u / 0.45));

double _lip(double u) =>
    _foot(u) + _height(u) * 0.42 + 3.0 * Ease.outCubic(clamp(u / 0.25));

double _jetH(double u) =>
    26.0 * (Ease.outCubic(clamp(u / 0.12)) - Ease.inQuad(clamp((u - 0.15) / 0.28)));

class _Spike {
  final double a;
  final double len;

  _Spike(this.a, this.len);
}

class _Plink {
  final double x;
  final double y;
  final int s;
  double age = 0.0;

  _Plink(this.x, this.y, this.s);
}

class _Bubble {
  final double x;
  final double z;
  final double t0;
  final double r;
  bool popped = false;

  _Bubble(this.x, this.z, this.t0, this.r);
}

class _Cell {
  final int x;
  final int y;
  final int c;
  final double a;
  final int r;

  _Cell(this.x, this.y, this.c, this.a, this.r);
}

class _SplashSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final int seed;
  final List<int> st;
  final double phi;
  final Particles ps;
  final Mist mist = Mist();
  final Lights lights = Lights();
  final Ripples rings = Ripples(sy: _sy);
  final List<_Plink> plinks = [];
  final List<_Bubble> bubbles = [];
  final List<_Spike> spikes;
  final Set<WaterDrop> smallDrops = Set<WaterDrop>.identity();
  final Set<String> done = <String>{};
  late final Drops drops;
  bool stone;
  double t = 0.0;

  _SplashSim._internal(
    this.c,
    this.r,
    this.seed,
    this.st,
    this.phi,
    this.spikes,
    this.stone,
  ) : ps = Particles(rng: r) {
    drops = Drops(
      sy: _sy,
      g: _g,
      onLand: (d) {
        rings.add(
          d.x,
          d.z,
          0.6,
          2.0 + d.s * 1.8,
          0.34 + d.s * 0.1,
          n: 1,
          k: 0.95,
          hot: 0.06,
        );
        plinks.add(_Plink(d.x, d.z * _sy, d.s));
        final isSmall = smallDrops.remove(d);
        if (d.s > 1 && !isSmall) {
          for (var i = 0; i < d.s; i++) {
            final a = r.range(0.0, tau);
            final v = r.range(10.0, 34.0);
            final vh = r.range(55.0, 110.0);
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

  factory _SplashSim.fromOptions(Map<String, Object?> o) {
    final r = Rng(o.seed);
    final phi = r.range(0.0, tau);
    final spikes = List<_Spike>.generate(
      _fingers,
      (k) => _Spike(((k * tau) / _fingers + phi) % tau, r.range(0.2, 0.36)),
    );
    return _SplashSim._internal(
      fit(o.palette, 8),
      r,
      o.seed,
      rockColors(),
      phi,
      spikes,
      o.boolOpt('stone', true),
    );
  }

  bool _once(String key, double at) =>
      !done.contains(key) && t >= at && done.add(key);

  double _scallop(double a, double h) =>
      h *
      (0.86 +
          0.14 *
              noise(
                math.cos(a) * 2.2 + math.sin(a) * 1.3 + phi * 3.0,
                seed,
              ));

  void _crown(Painter p, bool back) {
    final u = t - _hit;
    final h = _height(u);
    if (u < 0.0 || h < 0.7) return;
    final r0 = _foot(u);
    final rt = _lip(u);
    final white = u < 0.045;
    final cells = <int, _Cell>{};
    void put(double x, double y, int col, double a, int rank) {
      final xi = x.floor();
      final yi = y.floor();
      final key = (yi + 4096) * 8192 + xi + 4096;
      final cur = cells[key];
      if (cur == null || rank > cur.r) {
        cells[key] = _Cell(xi, yi, col, a, rank);
      }
    }

    final n = (rt * tau * 1.6).ceil();
    for (var i = 0; i < n; i++) {
      final a = (i / n) * tau;
      final s = math.sin(a);
      final ca = math.cos(a);
      if ((s < 0.0) != back) continue;
      final lane = (((a + phi) * rt) / 2.2).floor();
      final streak = rand(lane, 31) < 0.3;
      final hA = _scallop(a, h);
      final keep = 1.0 - clamp((u - 0.13 - 0.14 * rand(lane, 7)) / 0.1);
      final steps = (hA * 1.4).ceil() + 2;
      for (var k = 0; k <= steps * keep; k++) {
        final v = k / steps;
        final rad = r0 + (rt - r0) * math.pow(v, 2.2);
        final x = ca * rad;
        final y = s * rad * _sy - hA * v;
        if (white) {
          put(x, y, kWhite, 1.0, 3);
        } else if (back) {
          put(
            x,
            y,
            v > 0.72 ? (streak ? c[5] : c[4]) : (streak ? c[3] : c[2]),
            1.0,
            1,
          );
        } else if (ca.abs() > 0.9) {
          put(
            x,
            y,
            ca < 0.0 ? (ca.abs() > 0.97 ? kWhite : c[6]) : c[4],
            1.0,
            2,
          );
        } else if (v < 0.1) {
          put(x, y, v < 0.05 ? kWhite : c[6], 1.0, 2);
        } else if (streak) {
          put(x, y, ca < -0.2 ? c[6] : c[5], 1.0, 1);
        } else {
          put(x, y, ca < 0.0 ? c[5] : c[4], 0.22, 0);
        }
      }
      if (!white && keep >= 1.0) {
        final x = ca * rt;
        final y = s * rt * _sy - hA;
        put(x, y, back ? c[5] : (ca < 0.45 ? kWhite : c[6]), 1.0, 3);
        if (!back && ca < 0.2) put(x, y + 1.0, c[6], 1.0, 2);
      }
    }
    for (final q in cells.values) {
      if (q.r == 0) {
        p.blendPx(q.x, q.y, q.c, q.a);
      } else {
        p.px(q.x, q.y, q.c);
      }
    }
    final reach = 1.0 - smooth(_tear, _tear + 0.1, u);
    for (final f in spikes) {
      if ((math.sin(f.a) < 0.0) != back || reach <= 0.0) continue;
      final hA = _scallop(f.a, h);
      final len = h * f.len * reach;
      final x0 = math.cos(f.a) * rt;
      final y0 = math.sin(f.a) * rt * _sy - hA;
      final x1 = x0 + math.cos(f.a) * len * 0.45;
      final y1 = y0 - len;
      if (len >= 1.0) {
        p.line(x0, y0, x1, y1, white ? kWhite : (back ? c[4] : c[6]));
      }
      if (u > 0.04 && u < _tear) {
        bead(p, x1 - (back ? 0.0 : 0.5), y1 - 1.0, 0.0, -1.0, back ? 1 : 2, c);
      }
      if (!back && math.sin(f.a) > 0.3) {
        p.glow(x0, y0, 6, c[5], 0.22 * reach);
      }
    }
  }

  void _drawJet(Painter p) {
    final u = t - _hit - _jet;
    final h = _jetH(u);
    if (u < 0.0 || h < 0.8) return;
    final top = -h;
    p.ellipseShaded(
      0,
      0,
      5,
      2.4,
      color: (d, a) => math.sin(a) > 0.0
          ? 0
          : (d < 0.5 ? kWhite : (math.cos(a) < 0.0 ? c[6] : c[5])),
    );
    p.shade(-3.0, top - 2.0, 3.0, 0.0, (x, y, _) {
      final v = clamp((y - top) / h);
      final w = 1.15 + 1.5 * v * v * v;
      final q = x / w;
      if (q.abs() > 1.0) return null;
      return q < -0.5 ? c[6] : (q < 0.3 ? kWhite : (q < 0.72 ? c[5] : c[4]));
    });
    if (u < 0.12) {
      p.circle(0, top - 1.0, 1.7, c[5]);
      p.circle(-0.3, top - 1.3, 1.1, c[6]);
      p.px(-1, top - 2.0, kWhite);
    }
    p.glowLine(0, -1, 0, top, 7, c[5], 0.3);
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    stone = opts.boolOpt('stone', stone);
    t += dt;
    if (_once('hit', _hit)) {
      lights.add(0, -6, 52, c[5], 0.6, 0.45);
      lights.add(0, -4, 16, kWhite, 0.5, 0.08);
      rings.add(0, 0, 8, 56, 2.0,
          n: 2, gap: 3.4, k: 1.35, hot: 0.16, glint: 1);
      rings.add(0, 0, 5, 38, 1.7, n: 1, k: 0.9, delay: 0.14);
      for (var i = 0; i < 20; i++) {
        final a = r.range(0.0, tau);
        final v = r.range(50.0, 125.0);
        final dh = r.range(1.0, 6.0);
        final vh = r.range(160.0, 270.0);
        final ds = r.chance(0.25) ? 2 : 1;
        final delay = r.range(0.0, 0.04);
        drops.add(WaterDrop(
          x: math.cos(a) * 3.0,
          z: math.sin(a) * 3.0,
          h: dh,
          vx: math.cos(a) * v,
          vz: math.sin(a) * v,
          vh: vh,
          s: ds,
          delay: delay,
        ));
      }
      for (var i = 0; i < 9; i++) {
        final side = i % 2 != 0 ? 1 : -1;
        final x = side * r.range(4.0, 12.0);
        final my = -r.range(1.0, 7.0);
        final mvx = side * r.range(25.0, 70.0);
        final mvy = -r.range(4.0, 16.0);
        final mr0 = r.range(2.5, 4.0);
        final mr1 = r.range(7.0, 11.0);
        final mlife = r.range(0.9, 1.5);
        final mc = r.chance(0.5) ? c[6] : c[5];
        final ma = r.range(0.3, 0.42);
        final delay = r.range(0.0, 0.1);
        mist.add(x, my, mvx, mvy, mr0, mr1, mlife, mc, ma, delay);
      }
    }
    if (_once('spray', _hit + 0.04)) {
      for (var i = 0; i < 20; i++) {
        final a = r.range(0.0, tau);
        final py = math.sin(a) * 9.0 * _sy - r.range(6.0, 15.0);
        final pvx = math.cos(a) * r.range(25.0, 90.0);
        final pvy = -r.range(30.0, 100.0);
        final plife = r.range(0.7, 1.3);
        final pc = r.chance(0.5) ? kWhite : c[6];
        final psize = r.range(0.6, 1.5);
        ps.spawn(
          P.flake,
          math.cos(a) * 9.0,
          py,
          pvx,
          pvy,
          plife,
          pc,
          psize,
        );
      }
      for (var i = 0; i < 5; i++) {
        final px = r.range(-13.0, 13.0);
        final py = -r.range(6.0, 20.0);
        final plife = r.range(0.25, 0.55);
        final psize = r.range(1.0, 2.4);
        final pdelay = r.range(0.0, 0.15);
        ps.spawn(P.star, px, py, 0.0, -4.0, plife, c[6], psize, pdelay);
      }
    }
    if (_once('tear', _hit + _tear)) {
      final h = _height(_tear);
      final rt = _lip(_tear);
      for (final f in spikes) {
        final a = f.a + r.range(-0.08, 0.08);
        final v = r.range(32.0, 88.0);
        final len = h * f.len;
        final vh = r.range(90.0, 190.0);
        final ds = r.chance(0.3) ? 3 : 2;
        drops.add(WaterDrop(
          x: math.cos(f.a) * (rt + len * 0.45),
          z: math.sin(f.a) * rt,
          h: h + len + 1.0,
          vx: math.cos(a) * v,
          vz: math.sin(a) * v,
          vh: vh,
          s: ds,
        ));
      }
    }
    final u = t - _hit;
    if (u > 0.13 && u < 0.3 && r.chance(0.3)) {
      final a = r.range(0.0, tau);
      final rt = _lip(u);
      final v = r.range(15.0, 45.0);
      final dh = _scallop(a, _height(u)) * r.range(0.6, 1.0);
      final vh = r.range(-10.0, 45.0);
      final ds = r.chance(0.3) ? 2 : 1;
      drops.add(WaterDrop(
        x: math.cos(a) * rt,
        z: math.sin(a) * rt,
        h: dh,
        vx: math.cos(a) * v,
        vz: math.sin(a) * v,
        vh: vh,
        s: ds,
      ));
    }
    if (_once('fall', _hit + 0.3)) {
      for (var i = 0; i < 8; i++) {
        final a = r.range(0.0, tau);
        final rad = _lip(0.3);
        final v = r.range(15.0, 40.0);
        final dh = r.range(3.0, 7.0);
        final vh = r.range(30.0, 80.0);
        final ds = r.chance(0.4) ? 2 : 1;
        drops.add(WaterDrop(
          x: math.cos(a) * rad,
          z: math.sin(a) * rad,
          h: dh,
          vx: math.cos(a) * v,
          vz: math.sin(a) * v,
          vh: vh,
          s: ds,
        ));
      }
    }
    if (_once('bead', _hit + _jet + 0.12)) {
      drops.add(WaterDrop(
        x: 0.0,
        z: 0.2,
        h: _jetH(0.12) + 1.0,
        vx: r.range(-6.0, 6.0),
        vz: 0.0,
        vh: 55.0,
        s: 3,
      ));
      for (var i = 0; i < 3; i++) {
        final mx = r.range(-3.0, 3.0);
        final my = -_jetH(0.12) + r.range(2.0, 8.0);
        final mvx = r.range(-14.0, 14.0);
        final mvy = -r.range(4.0, 12.0);
        final mr1 = r.range(4.0, 6.0);
        final mlife = r.range(0.6, 1.0);
        mist.add(mx, my, mvx, mvy, 2.0, mr1, mlife, c[6], 0.3);
      }
    }
    if (_once('slump', _hit + _jet + 0.38)) {
      rings.add(0, 0, 3, 30, 1.5, n: 2, gap: 2.6, k: 0.9);
      for (var i = 0; i < 4; i++) {
        final mx = r.range(-6.0, 6.0);
        final my = -r.range(1.0, 4.0);
        final mvx = r.range(-30.0, 30.0);
        final mvy = -r.range(3.0, 10.0);
        final mr1 = r.range(6.0, 9.0);
        final mlife = r.range(0.8, 1.2);
        mist.add(mx, my, mvx, mvy, 2.5, mr1, mlife, c[5], 0.28);
      }
    }
    for (final (i, at) in const [(0, 0.95), (1, 1.2), (2, 1.5)]) {
      if (_once('glug$i', _hit + at)) {
        final bx = r.range(-5.0, 5.0);
        final bz = r.range(-6.0, 6.0);
        final br = r.range(1.3, 2.3);
        bubbles.add(_Bubble(bx, bz, t, br));
      }
    }
    for (final b in bubbles) {
      if (!b.popped && t - b.t0 > 0.2) {
        b.popped = true;
        rings.add(b.x, b.z, 1, 7, 0.6, n: 1, k: 0.9);
        plinks.add(_Plink(b.x, b.z * _sy, 1));
        for (var i = 0; i < 2; i++) {
          final vx = r.range(-20.0, 20.0);
          final vz = r.range(-10.0, 10.0);
          final vh = r.range(50.0, 90.0);
          final sub = WaterDrop(
            x: b.x,
            z: b.z,
            h: 1.0,
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
    final u = t - _hit;
    if (u > 0.0 && u < 0.26) {
      final rad = _foot(u) * 0.85 * (1.0 - smooth(0.12, 0.26, u));
      p.ellipseShaded(
        0,
        0,
        rad,
        rad * _sy + 0.6,
        color: (_, a) => math.sin(a) < 0.0 ? c[1] : c[2],
      );
    }
    rings.draw(p, c, -1);
    _crown(p, true);
    drops.draw(p, c, 'back');
  }

  @override
  void draw(Painter p) {
    final u = t - _hit;
    rings.draw(p, c, 1);
    if (u > 0.2) {
      final rx = 4.0 + 11.0 * Ease.outCubic(clamp((u - 0.2) / 0.7));
      final k = smooth(0.2, 0.32, u) * (1.0 - smooth(0.5, 2.0, u)) * 0.9;
      lace(p, 0.0, 0.0, rx, rx * _sy + 0.5, k, c, t, seed);
    }
    _crown(p, false);
    _drawJet(p);
    for (final b in bubbles) {
      final g = (t - b.t0) / 0.2;
      if (g > 1.0) continue;
      final rad = b.r * Ease.outBack(g);
      final x = b.x;
      final y = b.z * _sy;
      for (var a = math.pi; a <= tau + 0.01; a += 0.5 / math.max(1.0, rad)) {
        p.dot(x + math.cos(a) * rad, y + math.sin(a) * rad, c[6]);
      }
      p.px(x - rad * 0.4, y - rad * 0.6, kWhite);
      p.glow(x, y - 1.0, 4, c[5], 0.25);
    }
    for (final q in plinks) {
      final k = q.age / 0.14;
      if (k < 0.5) p.px(q.x, q.y, kWhite);
      if (q.s > 1) {
        p.line(
          q.x,
          q.y - 1.0,
          q.x,
          q.y - 1.0 - 3.0 * (1.0 - k),
          k < 0.4 ? kWhite : c[6],
        );
      }
      p.glow(q.x, q.y, 4, c[5], 0.3 * (1.0 - k));
    }
    drops.draw(p, c, 'front');
    if (u >= 0.0 && u < 0.07) {
      p.ellipseShaded(0, 0, 10, 2.4, color: (d, _) => d < 0.6 ? kWhite : c[6]);
      sparkle(p, 0, -3, 5.0 * (1.0 - u / 0.07), c[6], c[5], 0.5);
    }
    if (stone && t < _hit) {
      final v = t / _hit;
      final y = -70.0 + 70.0 * (0.4 * v + 0.6 * v * v);
      p.lineShaded(
        0,
        y - 12.0,
        0,
        y - 3.0,
        color: (_) => st[4],
        alpha: (w) => w * 0.8,
      );
      pebble(p, 0, y, 2.6, st);
    }
    mist.draw(p, c[5]);
    ps.draw(p);
    lights.draw(p);
    if (u > 0.0) {
      p.glow(0, -2, 34, c[4], 0.2 * (1.0 - smooth(0.0, 1.6, u)));
      p.glow(0, 2, 64, c[3], 0.16 * (1.0 - smooth(0.1, 2.1, u)));
    }
  }
}

final SimulatedEffect splashEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'water/splash',
    name: 'Splash',
    desc:
        'A stone drops into still water: a white hit, a crown that tears into droplets arcing out to plink down with rings, a jet that bounces back, foam and drifting mist.',
    category: 'water',
    tags: ['water', 'splash', 'impact', 'drop', 'liquid', 'one-shot'],
    size: (176, 100),
    origin: (88, 78),
    duration: 2.5,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': kWaterPalette,
      'stone': true,
      'seed': 3,
    },
  ),
  onCreate: _SplashSim.fromOptions,
);
