// The crescent and its cooling ramp are adapted from Sprite Fusion's open-source slash
// (https://www.spritefusion.com/pixel-art-vfx/slash), and the impact star, dust, grit and embers from his
// impact and explosion (https://www.spritefusion.com/pixel-art-vfx), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart' hide star;

import 'melee_lib.dart';

final Pose _rest = kReady.copyWith(
  weapon: 'greatsword',
  two: true,
  sa: -1,
  fx: 11,
  fy: -21,
);

final Pose _over = _rest.copyWith(
  x: -4,
  crouch: 2,
  lean: -2,
  fx: 1,
  fy: -42,
  sa: -2.45,
  ffx: 8,
  fbx: -7,
);

final Pose _floor = _rest.copyWith(
  x: 0,
  crouch: 7,
  lean: 6,
  fx: 17,
  fy: -21,
  sa: 0.72,
  ffx: 11,
  fbx: -10,
  toeB: true,
);

const double _raise = 0.2;
const double _swing = 0.135;
const double _hit = _raise + _swing;
const double _hold = 0.05;
const double _trail = 0.22;

double _head(double t) => Ease.inQuad(clamp((t - _raise) / _swing));
double _passedAt(double f) => _raise + _swing * math.sqrt(clamp(f));

typedef _ShardSpec = ({double a, double r, double v, double arc});

class _HeavyCleaveSim extends BaseEffectSim {
  final List<int> c;
  late final int n;
  final Rng r;
  final StoneColors st;
  late final Particles ps;
  late final Bits bits;
  final Lights lights = Lights();
  late final Swing a;
  late final Swing e;
  late final double u1;
  late final double x;
  late final Point2 glint;
  late final List<CrackLine> lines;
  late final List<Spike> spikes;
  late final List<_ShardSpec> shards;
  final Set<DebrisBit> dusted = {};
  double t = 0.0;
  bool hit = false;

  _HeavyCleaveSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed),
        st = stone(o['stone'] ?? '#4a3f69') {
    n = c.length;
    double floor(double _) => 0.0;
    ps = Particles(
      rng: r,
      ground: floor,
      sparks: [c[6], c[5], c[4], c[3]],
    );
    bits = Bits(ground: floor);
    a = Swing(
      cx: 3,
      cy: -22,
      r: 37,
      sy: 0.88,
      rot: 0.32,
      a0: -2.45,
      dir: 1,
    );
    var uu = 0.0;
    while (onSwing(a, a.r, uu).$2 < -0.5 && uu < 4.0) {
      uu += 0.005;
    }
    u1 = uu;
    e = a.copyWith(r: a.r * 0.76);
    x = onSwing(a, a.r - 2.0, u1).$1;
    glint = onSwing(a, a.r - 3.0, 0.0);
    lines = cracks(r, x, 4, 40.0, 7.0, 0.4);
    const spikeAngles = [-math.pi, -2.7, -2.15, -1.62, -1.05, -0.45, 0.0];
    spikes = [
      for (var i = 0; i < spikeAngles.length; i++)
        (
          a: spikeAngles[i] + r.range(-0.08, 0.08),
          len: (i == 0 || i == 6
                  ? 20.0
                  : i == 3
                      ? 15.0
                      : 9.0) +
              r.range(0.0, 4.0),
          w: 1.6 + r.range(0.0, 0.6),
        ),
    ];
    const shardAngles = [-2.5, -1.9, -1.2, -0.6];
    shards = [
      for (final ang in shardAngles)
        (
          a: ang + r.range(-0.15, 0.15),
          r: 8.0 + r.range(0.0, 3.0),
          v: r.range(80.0, 130.0),
          arc: r.range(0.35, 0.6),
        ),
    ];
  }

  void _arc(Painter p, Swing s, double w0, double lag, bool rim) {
    final tt = t - lag;
    final uEnd = u1 * _head(tt);
    final tStart = u1 * smooth(_hit + _hold, _hit + _hold + _trail, tt);
    if (uEnd < 0.02 || tStart >= uEnd - 0.02) return;
    final gone = smooth(_hit + _hold, _hit + _hold + _trail, tt);
    final shrink = 1.0 - 0.75 * gone;
    smear(p, s, tStart, uEnd, w0, (u, rad, out, _) {
      final age = math.max(0.0, tt - _passedAt(u / u1));
      final v = (u - tStart) / (uEnd - tStart);
      final w = w0 *
          shrink *
          math.pow(math.sin(math.pi * math.pow(v, 2.2)), 0.6);
      if (w < 0.4) return;
      final q = (s.r - rad) / w;
      if (q < 0.0 || q > 1.0) return;
      final ci = rim && q < 0.22 && age < 0.12
          ? 0
          : (q * (n - 1) * 0.62 +
                  age * 7.0 +
                  math.max(0.0, tt - _hit) * 10.0 -
                  v * 0.8 +
                  (rim ? 0.7 : 1.7) +
                  0.5)
              .floor();
      out.c = c[n - 1 - clampInt(ci, 0, n - 1)];
      out.a = math.min(1.0, v / 0.35) * (1.2 - gone);
    });
    if (rim) {
      glowAlong(
        p,
        s,
        s.r - w0 * 0.4,
        tStart,
        uEnd,
        7.0 + w0 * 0.5,
        c[4],
        0.0,
        kFn: (u) =>
            0.26 *
            math.exp(-math.max(0.0, tt - _passedAt(u / u1)) / 0.2) *
            ((u - tStart) / (uEnd - tStart)),
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (t < _raise - 0.04 && r.chance(0.35)) {
      final ang = r.range(0.0, tau);
      final d = r.range(14.0, 26.0);
      final life = r.range(0.14, 0.2);
      final v = (d * 3.0) / (math.exp(3.0 * life) - 1.0);
      ps.spawn(
        P.streak,
        glint.$1 + math.cos(ang) * d,
        glint.$2 + math.sin(ang) * d,
        -math.cos(ang) * v,
        -math.sin(ang) * v,
        life,
        r.chance(0.5) ? c[5] : c[4],
      );
    }
    if (t > _raise && t < _hit && r.chance(0.7)) {
      final u = u1 * _head(t) * r.range(0.6, 1.0);
      final (px, py) = onSwing(a, a.r - r.range(0.0, 6.0), u);
      ps.spawn(
        P.ember,
        px,
        py,
        r.range(-20.0, 20.0),
        r.range(-40.0, -10.0),
        r.range(0.5, 1.1),
        c[4],
        r.range(1.0, 2.0),
      );
    }
    if (!hit && t >= _hit) {
      hit = true;
      lights.add(x, -6.0, 26.0, kWhite, 0.9, 0.1);
      lights.add(x, -12.0, 64.0, c[4], 0.5, 0.8);
      for (var i = 0; i < 26; i++) {
        final ang = -math.pi / 2.0 + r.range(-1.2, 1.35);
        final sp = r.range(140.0, 360.0);
        ps.spawn(
          P.spark,
          x,
          -1.0,
          math.cos(ang) * sp,
          math.sin(ang) * sp - 40.0,
          r.range(0.15, 0.5),
        );
      }
      for (var i = 0; i < 20; i++) {
        final s = i.isOdd ? -1.0 : 1.0;
        ps.spawn(
          P.smoke,
          x + s * r.range(0.0, 8.0),
          -r.range(2.0, 6.0),
          s * r.range(45.0, 135.0),
          -r.range(2.0, 12.0),
          r.range(1.0, 1.45),
          st.dust,
          r.range(5.0, 8.5),
          r.range(0.0, 0.07),
          PF.big,
        );
      }
      for (var i = 0; i < 4; i++) {
        ps.spawn(
          P.smoke,
          x + r.range(-4.0, 4.0),
          -r.range(3.0, 8.0),
          r.range(-15.0, 15.0),
          -r.range(40.0, 90.0),
          r.range(1.0, 1.45),
          st.dust,
          r.range(4.0, 6.5),
          r.range(0.02, 0.1),
          PF.big,
        );
      }
      for (var i = 0; i < 8; i++) {
        ps.spawn(
          P.dust,
          x + r.range(-4.0, 4.0),
          -r.range(1.0, 4.0),
          r.range(-60.0, 60.0),
          -r.range(8.0, 30.0),
          r.range(0.35, 0.7),
          st.dust,
          r.range(2.0, 3.5),
        );
      }
      for (var i = 0; i < 44; i++) {
        final ang = -math.pi / 2.0 + r.range(-0.7, 1.0);
        final sp = r.range(60.0, 230.0);
        ps.spawn(
          P.grit,
          x + r.range(-3.0, 3.0),
          -1.0,
          math.cos(ang) * sp,
          math.sin(ang) * sp,
          r.range(1.0, 1.5),
          r.pick([st.light, st.body, st.body, st.shade]),
          r.chance(0.35) ? 2.0 : 1.0,
        );
      }
      for (var i = 0; i < 6; i++) {
        bits.add(
          DebrisBit(
            kind: B.chunk,
            x: x + r.range(-3.0, 3.0),
            y: -2.0,
            vx: r.range(-50.0, 110.0),
            vy: -r.range(120.0, 260.0),
            g: 1.0,
            drag: 0.4,
            bounce: 0.3,
            life: r.range(1.15, 1.5),
            a: r.range(0.0, tau),
            va: r.range(-14.0, 14.0),
            s: r.intRange(1, 2).toDouble(),
          ),
        );
      }
      for (var i = 0; i < 16; i++) {
        ps.spawn(
          P.ember,
          x + r.range(-8.0, 8.0),
          -r.range(1.0, 6.0),
          r.range(-50.0, 60.0),
          -r.range(30.0, 110.0),
          r.range(0.7, 1.5),
          c[4],
          r.range(1.0, 2.0),
        );
      }
    }
    if (hit && t < _hit + 0.6 && r.chance(0.12)) {
      final cl = r.pick(lines);
      final pt = r.pick(cl.pts);
      ps.spawn(
        P.ember,
        pt.$1,
        pt.$2 - 1.0,
        r.range(-12.0, 12.0),
        -r.range(20.0, 50.0),
        r.range(0.5, 0.9),
        c[4],
        1.0,
      );
    }
    bits.update(dt);
    for (final b in bits.list) {
      if (b.rest && !dusted.contains(b)) {
        dusted.add(b);
        for (var i = 0; i < 2; i++) {
          ps.spawn(
            P.dust,
            b.x + r.range(-1.5, 1.5),
            -0.5,
            r.sign() * r.range(8.0, 30.0),
            -r.range(2.0, 12.0),
            r.range(0.3, 0.6),
            st.dust,
            r.range(1.3, 2.4),
          );
        }
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final q = t - _hit;
    if (q >= 0.0) {
      final fade = 1.0 - smooth(1.0, 1.5, q);
      for (var py = 0; py <= 2; py++) {
        for (var px = -9; px <= 9; px++) {
          final d = hypot((px + 0.5) / 9.0, (py + 0.5) / 3.5);
          if (d > 1.0) continue;
          final heat =
              math.pow(clamp(1.0 - q / 0.8), 1.4) * (1.2 - d) -
              rand(px, py, 3) * 0.3;
          if (heat > 0.08) {
            p.dot(
              x + px,
              py.toDouble(),
              c[clampInt((heat * 9.0 + 0.5).floor(), 1, 7)],
              fade,
            );
          } else {
            p.dot(
              x + px,
              py.toDouble(),
              d < 0.5 ? st.dark : st.shade,
              (d < 0.9 - rand(px, py, 9) * 0.3 ? 1.0 : 1.0 - d) * fade,
            );
          }
        }
      }
      final k = q / 0.45;
      if (k < 1.0) {
        band(
          p,
          x,
          0.5,
          6.0 + 46.0 * Ease.outCubic(k),
          0.16,
          math.max(1.0, 3.0 * (1.0 - k)),
          1.15 - k,
          [st.body, st.light, c[4], c[6]],
          keep: (g) => math.sin(g) < 0.0,
        );
      }
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final q = t - _hit;
    if (t < _raise + 0.03) {
      final g = Ease.outBack(clamp(t / 0.1)) *
          (1.0 + 0.15 * math.sin(t * 60.0)) *
          (t > _raise ? 1.0 - (t - _raise) / 0.03 : 1.0);
      sparkle(p, glint.$1, glint.$2, 1.0 + 7.0 * g, c[6], c[4], 0.5);
      p.glow(glint.$1, glint.$2, 22.0, c[4], 0.3 * g);
    }
    if (q >= 0.0) {
      final heat = math.pow(clamp(1.0 - q / 1.2), 1.2).toDouble();
      final fade = 1.0 - smooth(1.15, 1.5, q);
      for (final cl in lines) {
        final reach = 40.0 *
            Ease.outCubic(clamp((q - cl.at * 0.1) / 0.13)) *
            (cl.fork ? 0.3 : 1.0);
        if (reach <= 0.0) continue;
        along(cl.pts, reach, (x0, y0, x1, y1, d) {
          final h = heat * (1.0 - d / 46.0) - (cl.fork ? 0.12 : 0.0);
          final col = h > 0.72
              ? kWhite
              : h > 0.08
                  ? c[clampInt((h * 8.0 + 0.5).floor(), 1, 6)]
                  : st.dark;
          if (y1 > 0.5) p.line(x0 + 1.0, y0, x1 + 1.0, y1, st.dark, fade);
          p.line(x0, y0, x1, y1, col, fade);
          if (h > 0.25 && d.toInt() % 6 < 2) {
            p.glow(x1, y1, 6.0, c[4], 0.2 * h * fade);
          }
        });
      }
      if (heat > 0.0) p.glow(x, -2.0, 34.0, c[4], 0.32 * heat * fade);
      final k = q / 0.45;
      if (k < 1.0) {
        band(
          p,
          x,
          0.5,
          6.0 + 46.0 * Ease.outCubic(k),
          0.16,
          math.max(1.0, 3.0 * (1.0 - k)),
          1.15 - k,
          [st.body, st.light, c[4], c[6]],
          keep: (g) => math.sin(g) >= 0.0,
        );
      }
    }
    _arc(p, e, 5.0, 0.02, false);
    _arc(p, a, 16.0, 0.0, true);
    final tail = u1 * smooth(_hit + _hold, _hit + _hold + _trail, t);
    final th = 0.8 * (1.0 - clamp((t - _hit - _hold) / (_trail + 0.25)));
    if (tail > 0.02 && th > 0.0) {
      trace(
        p,
        a,
        a.r - 0.5,
        0.0,
        tail,
        c[3],
        0.0,
        aFn: (u) => th * (0.4 + 0.6 * u / u1),
      );
    }
    if (t > _raise && t < _hit + 0.05) {
      final (gx, gy) = onSwing(a, a.r - 5.0, u1 * _head(t));
      p.glow(gx, gy, 40.0, c[4], 0.5);
    }
    if (q >= 0.0 && q < 0.035) {
      star(p, x, -1.0, spikes, 1.0, 1.0, kWhite, c[6], c[7], c[5]);
    } else if (q >= 0.035 && q < 0.07) {
      star(p, x, -1.0, spikes, 1.25, 0.55, c[7], c[6], c[6], c[4]);
    }
    if (q >= 0.05 && q < 0.16) {
      final k = (q - 0.05) / 0.11;
      for (final s in shards) {
        sliver(
          p,
          x,
          -1.0,
          s.a,
          s.r + s.v * (q - 0.05),
          s.arc * (1.0 - 0.4 * k),
          k < 0.4
              ? c[6]
              : k < 0.7
                  ? c[5]
                  : c[4],
          1.0 - k,
        );
      }
    }
    if (q >= 0.0 && q < 0.2) {
      final pop = math.exp(-q / 0.05);
      p.glow(x, -6.0, 30.0, c[5], 0.8 * pop);
      p.glow(x, -2.0, 10.0, kWhite, 0.7 * pop);
    }
    for (final b in bits.list) {
      rock(p, b, st);
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect heavyCleaveEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'melee/heavy-cleave',
    name: 'Heavy cleave',
    desc:
        'A glint over the head, then a thick ember arc accelerates over the top into the floor: a white slam, glowing cracks, dust rolling both ways, grit and rising embers.',
    category: 'melee',
    tags: [
      'melee',
      'slash',
      'cleave',
      'axe',
      'heavy',
      'ground',
      'fire',
      'combat',
      'directional',
      'one-shot',
    ],
    size: (208, 116),
    origin: (68, 96),
    duration: 1.9,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#2a0c10',
        '#5c1414',
        '#a3241a',
        '#e0481c',
        '#ff8a2a',
        '#ffc23d',
        '#fff0a0',
        '#ffffff',
      ],
      'stone': '#4a3f69',
      'seed': 5,
    },
  ),
  act: ActSpec(
    target: const TargetSpec(x: 66),
    poses: [
      PoseKey(-0.42, _rest.copyWith(x: -4)),
      PoseKey(-0.3, _rest.copyWith(x: -3, crouch: 4, fx: 13, fy: -29, sa: -1.3)),
      PoseKey(-0.12, _over.copyWith(crouch: 4)),
      PoseKey(0.2, _over.copyWith(crouch: 3)),
      PoseKey(
        0.27,
        _rest.copyWith(
          x: -1,
          y: -2,
          crouch: 0,
          lean: 2,
          fx: 11,
          fy: -42,
          sa: -1.45,
          ffx: 10,
          ghost: 1,
        ),
        PoseEase.snap,
      ),
      PoseKey(
        0.31,
        _rest.copyWith(
          x: 0,
          y: -1,
          crouch: 3,
          lean: 4,
          fx: 18,
          fy: -33,
          sa: -0.45,
          ffx: 12,
          ghost: 1,
        ),
        PoseEase.snap,
      ),
      PoseKey(0.335, _floor, PoseEase.snap),
      PoseKey(0.85, _floor.copyWith(crouch: 6, lean: 5)),
      PoseKey(
        1.3,
        _rest.copyWith(x: -2, crouch: 4, lean: 2, fx: 15, fy: -23, sa: 0.1),
      ),
      PoseKey(1.7, _rest.copyWith(x: -4)),
    ],
    hits: const [
      HitSpec(
        t: 0.335,
        stop: 0.2,
        shake: 0.34,
        amp: 3,
        push: 3.2,
        straw: 28,
        y: -8,
      ),
    ],
    dust: const [
      DustSpec(t: 0.335, x: 18, n: 8, dir: 1),
      DustSpec(t: 0.335, x: -12, n: 5, dir: -1),
    ],
  ),
  onCreate: (o) => _HeavyCleaveSim(o),
);
