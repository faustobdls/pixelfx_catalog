// The impact's particle recipe (fire puffs that cool into smoke, sparks, embers, burning brands that land and
// keep burning, rocks, grit, dust, scorch) is adapted from Sprite Fusion's open-source explosion
// (https://www.spritefusion.com/pixel-art-vfx/explosion), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'fire_lib.dart';

const double _hit = 0.62;
const double _fromX = -112.0;
const double _fromY = -142.0;
final int _soot = hex('#0d0a12');
final int _soot2 = hex('#17121d');
final int _outline = hex('#1a1422');
final int _warm = rgb(255, 176, 96);

const List<(double l, double w, double off)> _cometTongues = [
  (36.0, 7.0, 0.0),
  (26.0, 7.5, -2.5),
  (26.0, 7.5, 2.5),
  (16.0, 8.0, 0.0),
];

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

class _MeteorSim extends BaseEffectSim {
  final List<int> h;
  final List<int> rk;
  final _StoneColors st;
  final Rng r;
  final int s;
  late final Particles ps;
  late final Blazes blazes;
  final Bits bits = Bits(ground: (_) => 0.0);
  final Lights lights = Lights();
  late final int glowCol;
  late final double ux;
  late final double uy;
  double t = 0.0;
  bool hit = false;
  late double lastX;
  late double lastY;
  final Set<DebrisBit> dustedBits = {};

  _MeteorSim(Map<String, Object?> o)
      : h = hotFirst(fit(o.palette, 9)),
        rk = fit(o.rampOpt('rock'), 4),
        st = _stone((o['stone'] as String?) ?? '#4a3f69'),
        r = Rng(o.seed),
        s = o.seed * 11 {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [h[1], h[2], h[4], h[5]],
      onLand: (x, y) =>
          blazes.add(x, y - 0.25, r.range(0.9, 1.6), r.range(0.5, 0.85)),
    );
    blazes = Blazes(ps);
    glowCol = mix(mix(h[3], h[4], 0.5), kWhite, 0.25);
    final len = hypot(_fromX, _fromY);
    ux = -_fromX / len;
    uy = -_fromY / len;
    final (x0, y0) = _pos(0.0);
    lastX = x0;
    lastY = y0;
  }

  (double, double) _pos(double tt) {
    final u = clamp(tt / _hit);
    final k = Ease.inQuad(u) * 0.35 + u * 0.65;
    return (_fromX * (1.0 - k), _fromY * (1.0 - k));
  }

  void _meteor(Painter p, double x, double y, double r0, double cool,
      [double alpha = 1.0]) {
    p.shade(x - r0 - 2.0, y - r0 - 2.0, x + r0 + 2.0, y + r0 + 2.0,
        (px, py, out) {
      out.a = alpha;
      final dx = px - x;
      final dy = py - y;
      final d = hypot(dx, dy);
      final a = math.atan2(dy, dx);
      final rr = r0 *
          (1.0 +
              0.18 * noise(a * 2.2 + 3.0, s) +
              0.1 * noise(a * 5.0, s + 1));
      if (d > rr + 1.0) return null;
      if (d > rr) return _outline;
      final face = (dx * ux + dy * uy) / math.max(1.0, d);
      final heat = (1.0 - cool) * (face * 0.6 + 0.5 - (d / rr) * 0.25);
      if (heat > 0.62) return heat > 0.85 ? h[0] : (heat > 0.74 ? h[1] : h[2]);
      if (heat > 0.42) return h[4];
      final hv = rand((px - x).floor(), (py - y).floor(), s + 3);
      if (hv < 0.22 * (1.0 - cool * 0.7)) return (1.0 - cool) > 0.5 ? h[4] : h[6];
      return dx * -0.6 + dy * -0.8 > 0.0
          ? rk[2]
          : (d / rr > 0.6 ? rk[0] : rk[1]);
    });
  }

  void _crater(Painter p) {
    if (t < _hit) return;
    final a = t - _hit;
    final end = 1.0 - smooth(5.0 - 1.0, 5.0 - 0.15, t);
    final rx = 36.0 * math.min(1.0, a / 0.08);
    const ry = 6.0;
    final ramp = [h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8]];
    final x0 = (-rx).floor();
    final x1 = rx.ceil();
    for (var y = -1; y <= 3; y++) {
      for (var x = x0; x <= x1; x++) {
        final dx = (x + 0.5) / rx;
        final dy = (y + 0.5) / ry;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d > 1.0) continue;
        final k = rand(x * 31 + y, s + 5);
        final temp =
            math.pow(clamp(1.0 - a / 2.6), 1.3).toDouble() * (1.25 - d) -
                k * 0.35;
        if (temp > 0.06) {
          final c = ramp[math.min(8, ((1.0 - math.min(1.0, temp)) * 8.0).floor())];
          p.dot(x, y, c, end);
          if ((x & 3) == 0) p.glow(x + 0.5, y, 7, c, 0.2 * temp * end);
        } else {
          p.dot(
            x,
            y,
            d < 0.55 ? _soot : _soot2,
            (d < 0.95 - k * 0.3 ? 1.0 : 1.0 - d) * end,
          );
        }
      }
    }
    for (var x = -40; x <= 40; x++) {
      final e = x.abs() / 40.0;
      final hh = e < 0.7
          ? 0
          : (2.4 *
                  math.sin(((e - 0.7) / 0.3) * math.pi) *
                  (0.6 + 0.4 * rand(x, s + 7)) +
              0.5)
              .floor();
      for (var j = 0; j < hh; j++) {
        p.dot(
          x,
          -1 - j,
          j == hh - 1 ? mix(st.light, h[4], 0.5 * clamp(1.0 - a / 2.0)) : st.shade,
          end,
        );
      }
      if (hh != 0) p.dot(x, 0, _outline, end);
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t < _hit) {
      final (x, y) = _pos(t);
      final vx = dt > 0.0 ? (x - lastX) / dt : 0.0;
      final vy = dt > 0.0 ? (y - lastY) / dt : 0.0;
      lastX = x;
      lastY = y;
      for (var i = 0; i < 3; i++) {
        if (!r.chance(0.8 * dt * 60.0)) continue;
        ps.spawn(
          P.fire,
          x - ux * r.range(2.0, 8.0) + r.range(-3.0, 3.0),
          y - uy * r.range(2.0, 8.0) + r.range(-3.0, 3.0),
          vx * 0.15 + r.range(-20.0, 20.0),
          vy * 0.15 + r.range(-30.0, 10.0),
          r.range(0.3, 0.6),
          0,
          r.range(3.0, 6.0),
          0.0,
          r.chance(0.65) ? (PF.smokes | PF.big) : 0,
        );
      }
      if (r.chance(0.6 * dt * 60.0)) {
        ps.spawn(
          P.spark,
          x,
          y,
          vx * 0.35 + r.range(-80.0, 80.0),
          vy * 0.35 + r.range(-80.0, 40.0),
          r.range(0.2, 0.5),
        );
      }
      if (r.chance(0.3 * dt * 60.0)) {
        ps.spawn(
          P.ember,
          x,
          y,
          vx * 0.1 + r.range(-30.0, 30.0),
          vy * 0.1 + r.range(-40.0, 0.0),
          r.range(0.8, 1.6),
          h[3],
          r.chance(0.2) ? 2.0 : 1.0,
        );
      }
    } else if (!hit) {
      hit = true;
      lights.add(0, -40, 100, _warm, 0.95, 0.9);
      lights.add(0, -20, 46, kWhite, 0.9, 0.12);
      for (var i = 0; i < 34; i++) {
        final a = -math.pi / 2.0 + r.range(-1.3, 1.3) + 0.25;
        final sp = r.range(50.0, 210.0);
        ps.spawn(
          P.fire,
          r.range(-6.0, 6.0),
          -r.range(2.0, 10.0),
          math.cos(a) * sp,
          math.sin(a) * sp * 0.75 - 30.0,
          r.range(0.5, 1.1),
          0,
          r.range(5.0, 9.0),
          0.0,
          r.chance(0.5) ? (PF.smokes | PF.big) : 0,
        );
      }
      for (var i = 0; i < 9; i++) {
        ps.spawn(
          P.fire,
          r.range(-6.0, 6.0),
          -6.0,
          r.range(-14.0, 14.0),
          -r.range(130.0, 220.0),
          r.range(0.8, 1.2),
          0,
          r.range(6.0, 8.5),
          r.range(0.0, 0.12),
          PF.smokes | PF.big,
        );
      }
      for (var i = 0; i < 20; i++) {
        final a = r.range(-math.pi, 0.0);
        final d = r.range(4.0, 18.0);
        ps.spawn(
          P.smoke,
          math.cos(a) * d,
          -r.range(6.0, 24.0),
          math.cos(a) * r.range(10.0, 40.0),
          -r.range(30.0, 110.0),
          r.range(1.8, 2.8),
          0,
          r.range(8.0, 12.0),
          r.range(0.15, 0.5),
          PF.big,
        );
      }
      for (var i = 0; i < 16; i++) {
        final sv = r.sign().toDouble();
        ps.spawn(
          P.smoke,
          sv * r.range(4.0, 18.0),
          -r.range(1.0, 5.0),
          sv * r.range(60.0, 130.0) + 10.0,
          -r.range(2.0, 12.0),
          r.range(1.2, 2.0),
          st.dust,
          r.range(5.0, 8.0),
          r.range(0.0, 0.06),
          PF.big,
        );
      }
      for (var i = 0; i < 90; i++) {
        final a = -math.pi / 2.0 + r.range(-1.3, 1.3) + 0.15;
        final sp = r.range(100.0, 300.0);
        ps.spawn(
          P.spark,
          0.0,
          -4.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.2, 0.7),
        );
      }
      for (var i = 0; i < 36; i++) {
        final a = r.range(0.0, tau);
        final sp = r.range(40.0, 150.0);
        ps.spawn(
          P.ember,
          math.cos(a) * 8.0,
          -8.0 + math.sin(a) * 6.0,
          math.cos(a) * sp,
          math.sin(a) * sp - 70.0,
          r.range(1.2, 2.6),
          h[3],
        );
      }
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2.0 + r.range(-1.0, 1.05);
        final sp = r.range(130.0, 240.0);
        ps.spawn(
          P.brand,
          0.0,
          -6.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.7, 1.3),
        );
      }
      final chunkRamp = [
        _outline,
        st.shade,
        st.body,
        st.light,
        mix(st.light, kWhite, 0.3),
      ];
      for (var i = 0; i < 28; i++) {
        bits.add(
          DebrisBit(
            kind: DebrisKind.chunk,
            x: r.range(-8.0, 8.0),
            y: -3.0,
            vx: r.range(-80.0, 110.0),
            vy: -r.range(140.0, 340.0),
            g: 1.0,
            drag: 0.4,
            bounce: 0.3,
            life: r.range(1.8, 2.8),
            a: r.range(0.0, tau),
            va: r.range(-16.0, 16.0),
            s: r.intRange(1, 3).toDouble(),
            rampColors: chunkRamp,
          ),
        );
      }
      for (var i = 0; i < 80; i++) {
        final u = r.range(-1.0, 1.0);
        final a = -math.pi / 2.0 + u * 0.7 + 0.15;
        final sp = r.range(90.0, 270.0) * (1.0 - 0.4 * u.abs());
        ps.spawn(
          P.grit,
          u * 6.0,
          -1.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(1.2, 2.2),
          r.pick([st.light, st.body, st.body, st.shade]),
          r.chance(0.45) ? 2.0 : 1.0,
        );
      }
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
    blazes.update(dt);
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    _crater(p);
    simDraw(p, ps, h, 'back');
    blazes.drawBack(p);
    final k = (t - _hit) / 0.5;
    if (k > 0.0 && k < 1.0) {
      band(
        p,
        0,
        0.5,
        110 * Ease.outCubic(k),
        0.16,
        math.max(1.0, 5.0 * (1.0 - k)),
        1.15 - k,
        [st.body, st.light, h[4], h[1]],
        keep: (double g) => math.sin(g) < 0.0,
      );
    }
  }

  @override
  void draw(Painter p) {
    final k = (t - _hit) / 0.5;
    if (k > 0.0 && k < 1.0) {
      band(
        p,
        0,
        0.5,
        110 * Ease.outCubic(k),
        0.16,
        math.max(1.0, 5.0 * (1.0 - k)),
        1.15 - k,
        [st.body, st.light, h[4], h[1]],
        keep: (double g) => math.sin(g) >= 0.0,
        hot: k < 0.12,
      );
    }
    for (final b in bits.list) {
      _rock(p, b, st);
    }
    if (t < _hit) {
      final (x, y) = _pos(t);
      double nz(double rate, [int seed = 0, double off = 0.0]) =>
          noise(t * rate + off, seed);
      floorLight(
        p,
        0,
        0.5,
        30 + 40 * (t / _hit),
        7,
        glowCol,
        0.5 * (t / _hit) * (t / _hit),
      );
      for (var i = 0; i < _cometTongues.length; i++) {
        final (l, w, off) = _cometTongues[i];
        final nn = (s + i) * 13;
        flameBlade(
          p,
          x - uy * off,
          y + ux * off,
          -ux,
          -uy,
          l * (0.85 + 0.25 * nz(5.0, nn)),
          w,
          nz(3.0, nn + 3) * 3.0,
          nz,
          nn,
          h,
          layers: fireLayers,
          jit: 0.5,
          wob: 1.6,
        );
      }
      _meteor(p, x, y, 6.5, 0.0);
      p.glow(x, y, 46, glowCol, 0.55);
      p.glow(x, y, 12, h[1], 0.4);
    } else {
      final a = t - _hit;
      final cool = clamp(a / 2.8);
      final end = 1.0 - smooth(5.0 - 1.1, 5.0 - 0.2, t);
      if (end > 0.0) {
        _meteor(p, 0, 0, 5.5, cool, end);
        p.glow(0, -2, 22, glowCol, 0.4 * (1.0 - cool) * end);
      }
    }
    simDraw(p, ps, h, 'front');
    final f = (t - _hit) / 0.08;
    if (f > 0.0 && f < 1.0) {
      p.circle(0, -6, 11 * (1.0 - f * 0.3) + 1.5, h[3]);
      p.circle(0, -6, 11 * (1.0 - f * 0.3), f < 0.5 ? h[1] : h[2]);
      p.circle(0, -6, 7 * (1.0 - f * 0.3), f < 0.5 ? kWhite : h[1]);
    }
    final fr = (t - _hit) / 0.24;
    if (fr > 0.0 && fr < 1.0) {
      flare(
        p,
        0,
        -6,
        44 * math.pow(1.0 - fr, 1.4).toDouble(),
        1.0 - fr,
        [h[6], h[4], h[2], h[1]],
      );
    }
    lights.draw(p);
  }
}

final SimulatedEffect meteorEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'fire/meteor',
    name: 'Meteor',
    desc:
        'A burning rock streaks in from the upper left in a comet of fire and smashes into the floor: a white flash, a fireball, rocks and brands thrown, a glowing crater that cools.',
    category: 'fire',
    tags: ['fire', 'meteor', 'impact', 'explosion', 'spell', 'debris', 'one-shot'],
    size: (272, 232),
    origin: (150, 208),
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
      'rock': ['#120e16', '#2a2230', '#463a4a', '#6a5a66'],
      'seed': 9,
    },
  ),
  onCreate: (o) => _MeteorSim(o),
);
