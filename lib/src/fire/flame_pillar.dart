// The flame-puff, smoke, spark, debris and floor-ring recipe is adapted from Sprite Fusion's open-source explosion
// (https://www.spritefusion.com/pixel-art-vfx/explosion), and the column's levels, pulses and strands from its
// holy light (https://www.spritefusion.com/pixel-art-vfx/holy-light), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'fire_lib.dart';

const double _erupt = 0.55;
const double _rise = 0.12;
const double _fall = 1.95;
const double _gone = 2.45;
final int _soot = hex('#0d0a12');
final int _outline = hex('#1a1422');
final int _warm = rgb(255, 176, 96);

class _StoneColors {
  final int light, body, shade, dust;
  _StoneColors(this.light, this.body, this.shade, this.dust);
}

_StoneColors _stone(String cHex) {
  final c = hex(cHex);
  return _StoneColors(
    mix(scaleColor(c, 1.35), kWhite, 0.08),
    c,
    scaleColor(c, 0.64),
    mix(scaleColor(c, 1.2), rgb(150, 140, 150), 0.3),
  );
}

void _rock(Painter p, DebrisBit b, _StoneColors st) {
  final r = 0.6 + b.s * 0.75;
  final fade = math.min(1.0, b.life / 0.5);
  final lx = math.cos(b.a) * r * 0.4;
  final ly = math.sin(b.a) * r * 0.4;
  p.shade(b.x - r - 1.0, b.y - r - 1.0, b.x + r + 1.0, b.y + r + 1.0,
      (x, y, out) {
    final dx = x - b.x;
    final dy = y - b.y;
    final d = hypot(dx * 1.15, dy);
    if (d > r + 0.9) return null;
    final lit = dx * lx + dy * ly;
    out.a = fade;
    return d > r
        ? _outline
        : lit < -0.4
            ? st.light
            : lit > 0.6
                ? st.shade
                : st.body;
  });
}

class _Crack {
  final List<(double x, double y)> pts;
  final double t0, grow;
  final int w;
  _Crack(this.pts, this.t0, this.grow, this.w);
}

class _Strand {
  final double o, w, f;
  _Strand(this.o, this.w, this.f);
}

class _FlamePillarSim extends BaseEffectSim {
  final List<int> h;
  final double hMax;
  final _StoneColors st;
  final Rng r;
  final int s;
  late final Particles ps;
  final Bits bits = Bits(ground: (_) => 0.0);
  final Lights lights = Lights();
  late final int glowCol;
  final List<_Crack> cracks = [];
  late final List<_Strand> strands;
  final Set<DebrisBit> dustedBits = {};
  double t = 0.0;
  bool erupted = false;
  bool fell = false;

  _FlamePillarSim(Map<String, Object?> o)
      : h = hotFirst(fit(o.palette, 9)),
        hMax = o.numOpt('height', 140.0),
        st = _stone((o['stone'] as String?) ?? '#4a3f69'),
        r = Rng(o.seed),
        s = o.seed * 13 {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [h[1], h[2], h[4], h[5]],
    );
    glowCol = mix(mix(h[3], h[4], 0.5), kWhite, 0.25);

    List<(double, double)> addCrack(
        double x, double y, double a, double len, double t0, int w) {
      final pts = <(double, double)>[(x, y)];
      var px = x;
      var py = y;
      var ang = a;
      for (var d = 0.0; d < len; d += 2.0) {
        ang += r.range(-0.55, 0.55);
        px += math.cos(ang) * 2.0;
        py += math.sin(ang) * 0.76;
        pts.add((px, py));
      }
      cracks.add(_Crack(pts, t0, r.range(0.22, 0.36), w));
      return pts;
    }

    for (var i = 0; i < 9; i++) {
      final a = (i / 9.0) * tau + r.range(-0.25, 0.25);
      final pts = addCrack(
        r.range(-1.0, 1.0),
        r.range(-0.3, 0.3),
        a,
        r.range(20.0, 40.0),
        r.range(0.0, 0.16),
        1,
      );
      final j = 3 + r.intRange(0, pts.length - 6);
      if (pts.length > 8) {
        addCrack(
          pts[j].$1,
          pts[j].$2,
          a + r.sign() * r.range(0.5, 1.0),
          r.range(6.0, 14.0),
          0.18 + r.range(0.0, 0.15),
          0,
        );
      }
    }
    strands = List.generate(
      7,
      (i) => _Strand(
        (rand(i, s, 1) - 0.5) * 1.4,
        0.05 + rand(i, s, 2) * 0.06,
        1.0 + rand(i, s, 3) * 2.0,
      ),
    );
  }

  double _height(double tt) {
    if (tt < _erupt) return 0.0;
    if (tt < _erupt + _rise) {
      return hMax * Ease.outCubic((tt - _erupt) / _rise);
    }
    if (tt < _fall) {
      return hMax * (1.0 + 0.05 * noise(tt * 3.0, s));
    }
    return hMax *
        (1.0 - Ease.inQuad(clamp((tt - _fall) / (_gone - _fall))));
  }

  double _width(double tt) {
    if (tt < _erupt) return 0.0;
    if (tt < _fall) {
      return 12.0 *
          (1.0 + 0.45 * math.exp(-(tt - _erupt) * 7.0)) *
          (0.94 + 0.06 * noise(tt * 9.0, s + 1));
    }
    return 12.0 * (1.0 - smooth(_fall, _gone, tt)) +
        1.5 * (1.0 - smooth(_gone - 0.1, _gone, tt));
  }

  double _heat(double tt) =>
      smooth(0.0, _erupt, tt) * 0.75 +
      0.25 * smooth(_erupt - 0.05, _erupt + 0.1, tt) -
      smooth(_gone - 0.3, 5.0 - 0.6, tt) * 1.05;

  void _column(Painter p) {
    final ch = _height(t);
    final w0 = _width(t);
    if (ch < 1.0 || w0 < 0.3) return;
    if (t < _fall + 0.25) {
      final k = clamp(w0 / 12.0);
      double nz(double rate, [int seed = 0, double off = 0.0]) =>
          noise(t * rate + off, seed);
      for (var i = 0; i < 5; i++) {
        final nn = (s + i) * 17;
        final dx = (i - 2) * w0 * 0.4;
        final th = (12.0 + 12.0 * (0.5 + 0.5 * noise(t * 3.3 + i, nn))) *
            k *
            (i == 2 ? 1.2 : (i % 4 == 0 ? 0.6 : 0.9));
        flameTongue(
          p,
          dx + noise(t * 2.0, nn + 2) * 1.5,
          -ch + 12.0,
          th,
          3.4 * k * (i % 4 == 0 ? 0.7 : 1.0),
          -dx * 0.3 + noise(t * 2.2, nn + 1) * 3.0,
          nz,
          nn,
          h,
          layers: fireLayers,
        );
      }
    }
    final lvlC = [h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7]];
    final tFloor = (t * 20.0).floor();
    for (var y = 0; y >= -ch; y--) {
      final v = -y / ch;
      final cx = noise(-y * 0.04 + t * 1.6, s + 2) * 1.6 * v;
      final footBase = math.max(0.0, 1.0 - (-y) / 12.0);
      final foot = 1.0 + 0.7 * footBase * footBase;
      final top = 1.0 - smooth(0.82, 1.0, v) * 0.7;
      final wl = w0 *
          foot *
          top *
          (1.0 +
              0.65 *
                  math.pow(
                      math.max(0.0, noise(y * 0.2 + t * 8.0, s + 3)), 1.5));
      final wr = w0 *
          foot *
          top *
          (1.0 +
              0.65 *
                  math.pow(
                      math.max(0.0, noise(y * 0.2 + t * 8.0, s + 4)), 1.5));
      final pulse =
          (-y * 0.032 + t * 3.6).remainder(1.0) < 0.09 ? 1 : 0;
      final x0 = (cx - wl * 1.15).floor();
      final x1 = (cx + wr * 1.15).ceil();
      for (var x = x0; x <= x1; x++) {
        final dx = x + 0.5 - cx;
        final q = dx.abs() / (dx < 0.0 ? wl : wr);
        if (q > 1.15) continue;
        var lvl = q < 0.12
            ? 0
            : q < 0.26
                ? 1
                : q < 0.42
                    ? 2
                    : q < 0.56
                        ? 3
                        : q < 0.7
                            ? 4
                            : q < 0.84
                                ? 5
                                : q < 0.96
                                    ? 6
                                    : 7;
        for (final stItem in strands) {
          if ((dx / w0 - stItem.o - 0.06 * math.sin(t * stItem.f * 3.0 + stItem.o * 9.0))
                  .abs() <
              stItem.w) {
            lvl = math.max(0, lvl - 1);
          }
        }
        lvl = math.max(0, lvl - pulse);
        if (lvl == 7 && rand(x, y, tFloor) < 0.5) continue;
        p.px(x, y, lvlC[lvl]);
      }
      if (y % 12 == 0) {
        p.glow(cx, y, w0 * 2.4 + 8.0, glowCol, 0.28 * clamp(w0 / 12.0));
      }
    }
    p.glow(0, -ch * 0.45, 92, glowCol, 0.3 * clamp(w0 / 12.0));
  }

  void _cracksDraw(Painter p) {
    final k = _heat(t);
    if (k <= -0.05) return;
    for (final c in cracks) {
      final n = (c.pts.length * clamp((t - c.t0) / c.grow)).floor();
      for (var i = 1; i < n; i++) {
        final u = i / c.pts.length;
        final hot = k * (1.0 - 0.45 * u);
        final (x0, y0) = c.pts[i - 1];
        final (x1, y1) = c.pts[i];
        if (hot < 0.0) {
          final a = 1.0 + hot * 3.0;
          if (a > 0.0) p.line(x0, y0, x1, y1, _soot, a);
          continue;
        }
        final col = hot > 0.85
            ? h[1]
            : hot > 0.65
                ? h[2]
                : hot > 0.45
                    ? h[4]
                    : hot > 0.25
                        ? h[5]
                        : hot > 0.1
                            ? h[6]
                            : h[7];
        if (c.w != 0 && i < c.pts.length * 0.5 && hot > 0.2) {
          p.line(x0, y0 + 1.0, x1, y1 + 1.0, hot > 0.6 ? h[5] : h[6]);
          p.line(x0, y0 - 1.0, x1, y1 - 1.0, h[7]);
        }
        p.line(x0, y0, x1, y1, col);
        if (i % 2 == 0) p.glow(x1, y1, 5 + 7 * hot, glowCol, 0.3 * hot);
      }
    }
    if (k > 0.0) floorLight(p, 0, 0.5, 44, 8, glowCol, 0.35 * k);
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t < _erupt && r.chance(0.6 * dt * 60.0 * smooth(0.15, _erupt, t))) {
      ps.spawn(
        P.fire,
        r.range(-5.0, 5.0),
        -1.0,
        r.range(-6.0, 6.0),
        -r.range(20.0, 45.0),
        r.range(0.15, 0.3),
        0,
        r.range(1.0, 2.2),
      );
    }
    if (t < _erupt && r.chance(0.5 * dt * 60.0 * smooth(0.0, _erupt, t))) {
      final c = r.pick(cracks);
      final idx =
          r.intRange(0, (c.pts.length * clamp((t - c.t0) / c.grow)).floor() - 1);
      if (idx >= 0) {
        final (x, y) = c.pts[idx];
        if (r.chance(0.5)) {
          ps.spawn(
            P.fire,
            x,
            y - 1.0,
            r.range(-5.0, 5.0),
            -r.range(15.0, 35.0),
            r.range(0.15, 0.3),
            0,
            r.range(0.8, 1.6),
          );
        } else {
          ps.spawn(
            P.ember,
            x,
            y - 1.0,
            r.range(-15.0, 15.0),
            -r.range(30.0, 70.0),
            r.range(0.5, 1.0),
            h[3],
            1.0,
          );
        }
      }
    }
    if (!erupted && t >= _erupt) {
      erupted = true;
      lights.add(0, -40, 90, _warm, 0.7, 0.6);
      lights.add(0, -8, 44, kWhite, 0.7, 0.1);
      for (var i = 0; i < 70; i++) {
        final a = -math.pi / 2.0 + r.range(-1.1, 1.1);
        final sp = r.range(100.0, 260.0);
        ps.spawn(
          P.spark,
          r.range(-4.0, 4.0),
          -2.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.25, 0.7),
        );
      }
      for (var i = 0; i < 18; i++) {
        bits.add(
          DebrisBit(
            kind: DebrisKind.chunk,
            x: r.range(-6.0, 6.0),
            y: -2.0,
            vx: r.range(-110.0, 110.0),
            vy: -r.range(150.0, 330.0),
            g: 1.0,
            drag: 0.4,
            bounce: 0.3,
            life: r.range(1.6, 2.4),
            a: r.range(0.0, tau),
            va: r.range(-16.0, 16.0),
            s: r.intRange(1, 3).toDouble(),
          ),
        );
      }
      for (var i = 0; i < 60; i++) {
        final a = -math.pi / 2.0 + r.range(-0.9, 0.9);
        final sp = r.range(80.0, 260.0);
        ps.spawn(
          P.grit,
          r.range(-5.0, 5.0),
          -1.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(1.0, 1.8),
          r.pick([st.light, st.body, st.body, st.shade]),
          r.chance(0.4) ? 2.0 : 1.0,
        );
      }
      for (var i = 0; i < 14; i++) {
        final signVal = r.sign().toDouble();
        ps.spawn(
          P.smoke,
          signVal * r.range(2.0, 10.0),
          -r.range(1.0, 4.0),
          signVal * r.range(40.0, 110.0),
          -r.range(2.0, 10.0),
          r.range(1.0, 1.8),
          st.dust,
          r.range(4.0, 7.0),
          r.range(0.0, 0.06),
          PF.big,
        );
      }
    }

    final ch = _height(t);
    final w = _width(t);
    if (t > _erupt && t < _gone && ch > 4.0) {
      if (r.chance(0.9 * dt * 60.0)) {
        final signVal = r.sign().toDouble();
        final y = -r.range(4.0, ch * 0.9);
        ps.spawn(
          P.fire,
          signVal * w * r.range(0.7, 1.1),
          y,
          signVal * r.range(15.0, 40.0),
          -r.range(30.0, 70.0),
          r.range(0.25, 0.5),
          0,
          r.range(1.6, 3.2),
          0.0,
          r.chance(0.35) ? PF.smokes : 0,
        );
      }
      if (r.chance(0.7 * dt * 60.0)) {
        ps.spawn(
          P.fire,
          r.range(-w, w),
          -ch + r.range(0.0, 6.0),
          r.range(-20.0, 20.0),
          -r.range(30.0, 80.0),
          r.range(0.35, 0.7),
          0,
          r.range(3.0, 5.5),
          0.0,
          r.chance(0.6)
              ? (PF.smokes | (t < _fall - 0.3 ? PF.big : 0))
              : 0,
        );
      }
      if (t < _fall && r.chance(0.5 * dt * 60.0)) {
        ps.spawn(
          P.ember,
          r.range(-w, w) * 0.6,
          -ch + 4.0,
          r.range(-60.0, 60.0),
          -r.range(50.0, 110.0),
          r.range(0.7, 1.3),
          h[3],
          r.chance(0.2) ? 2.0 : 1.0,
        );
      }
    }

    if (t >= _fall && !fell) fell = true;
    if (fell && t < _gone - 0.1 && r.chance(1.6 * dt * 60.0)) {
      ps.spawn(
        P.fire,
        r.range(-w - 2.0, w + 2.0),
        -ch - r.range(0.0, 8.0),
        r.range(-30.0, 30.0),
        -r.range(10.0, 50.0),
        r.range(0.4, 0.75),
        0,
        r.range(3.5, 6.5),
        0.0,
        PF.smokes,
      );
    }

    bits.update(dt);
    for (final b in bits.list) {
      if (b.rest && dustedBits.add(b)) {
        for (var i = 0; i < 3; i++) {
          ps.spawn(
            P.dust,
            b.x + r.range(-1.5, 1.5),
            -0.5,
            r.sign() * r.range(8.0, 35.0),
            -r.range(2.0, 18.0),
            r.range(0.3, 0.6),
            st.dust,
            r.range(1.3, 2.6),
          );
        }
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    _cracksDraw(p);
    simDraw(p, ps, h, 'back');
    final k = (t - _erupt) / 0.45;
    if (k > 0.0 && k < 1.0) {
      band(
        p,
        0,
        0.5,
        84 * Ease.outCubic(k),
        0.18,
        math.max(1.0, 4.0 * (1.0 - k)),
        1.15 - k,
        [st.body, st.light, h[4], h[1]],
        keep: (double g) => math.sin(g) < 0.0,
      );
    }
  }

  @override
  void draw(Painter p) {
    _column(p);
    for (final b in bits.list) {
      _rock(p, b, st);
    }
    simDraw(p, ps, h, 'front');
    final k = (t - _erupt) / 0.45;
    if (k > 0.0 && k < 1.0) {
      band(
        p,
        0,
        0.5,
        84 * Ease.outCubic(k),
        0.18,
        math.max(1.0, 4.0 * (1.0 - k)),
        1.15 - k,
        [st.body, st.light, h[4], h[1]],
        keep: (double g) => math.sin(g) >= 0.0,
        hot: k < 0.15,
      );
    }
    final f = (t - _erupt) / 0.08;
    if (f > 0.0 && f < 1.0) {
      p.ellipse(0, -2, 16 * (1.0 - f * 0.3), 6, h[2]);
      p.ellipse(0, -3, 11 * (1.0 - f * 0.3), 4, f < 0.5 ? kWhite : h[1]);
    }
    lights.draw(p);
  }
}

final SimulatedEffect flamePillarEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'fire/flame-pillar',
    name: 'Flame pillar',
    desc:
        'The floor cracks and glows, a column of fire erupts white-hot and roars, spewing embers and shedding flame, then collapses into rolling smoke.',
    category: 'fire',
    tags: ['fire', 'pillar', 'eruption', 'spell', 'ground', 'one-shot'],
    size: (184, 256),
    origin: (92, 232),
    duration: 5.0,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#4a1712', '#8a1f17', '#c9281f', '#f2561d',
        '#ff8a2a', '#ffc23d', '#ffe26b', '#fff3a6', '#ffffff',
      ],
      'stone': '#4a3f69',
      'height': 140,
      'seed': 5,
    },
  ),
  onCreate: (o) => _FlamePillarSim(o),
);
