// The rocks, grit, rolling dust and floor ring are adapted from Sprite Fusion's open-source explosion, and the
// dome from his ice nova (https://www.spritefusion.com/pixel-art-vfx), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'melee_lib.dart';

final Pose _rest = kReady.copyWith(
  weapon: 'hammer',
  two: true,
  sa: 0.62,
  fx: 11,
  fy: -21,
  crouch: 3,
);
final Pose _top = _rest.copyWith(
  x: -3,
  crouch: 0,
  lean: -3,
  fx: 3,
  fy: -41,
  sa: -2.1,
  ffx: 8,
  ffy: -8,
  fbx: -5,
  toeB: true,
);
final Pose _slam = _rest.copyWith(
  x: -1,
  crouch: 7,
  lean: 6,
  fx: 14,
  fy: -19,
  sa: 0.62,
  ffx: 11,
  fbx: -10,
);

final int _kSoot = hex('#0d0a12');
final List<int> _kHot = ['#fff3a6', '#ffc23d', '#ff8a2a', '#c9281f'].map(hex).toList();
const double _kDrop = 0.15;
const double _kHw = 13.0;

double _head(double t) {
  final x = clamp((t + 0.03) / (_kDrop + 0.03));
  return 0.28 * x + 0.72 * x * x;
}

typedef _RaySpec = ({double a, double l});

class _HammerSmashSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final StoneColors st;
  late final Particles ps;
  late final Bits bits;
  late final Bits chips;
  final Lights lights = Lights();
  late final Swing swingArc;
  late final double u1;
  late final double hitX;
  late final double rm;
  late final List<CrackLine> lines;
  late final List<_RaySpec> rays;
  final Set<DebrisBit> dusted = {};
  double t = 0.0;
  bool hit = false;

  _HammerSmashSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed),
        st = stone(o['stone'] ?? '#4a3f69') {
    double floor(double _) => 0.0;
    ps = Particles(rng: r, ground: floor);
    bits = Bits(ground: floor);
    chips = Bits(ground: floor);
    swingArc = Swing(cx: 5.0, cy: -25.0, r: 32.0, sy: 1.0, rot: 0.0, a0: -2.25, dir: 1.0);
    var uu = 0.0;
    while (onSwing(swingArc, swingArc.r, uu).$2 < -0.5 && uu < 4.0) {
      uu += 0.005;
    }
    u1 = uu;
    rm = swingArc.r - _kHw / 2.0;
    hitX = onSwing(swingArc, rm, u1).$1;
    lines = cracks(r, hitX, 5, 24.0, 6.0, 0.0);
    const rayDirs = [-0.95, -0.6, -0.3, -0.05, 0.22, 0.5, 0.85];
    rays = [
      for (var i = 0; i < rayDirs.length; i++)
        (
          a: -math.pi / 2.0 + rayDirs[i] + r.range(-0.06, 0.06),
          l: (i == 3
                  ? 34.0
                  : (i == 2 || i == 4)
                      ? 26.0
                      : (i == 1 || i == 5)
                          ? 18.0
                          : 12.0) *
              r.range(0.9, 1.1),
        ),
    ];
  }

  void _wedge(Painter p) {
    final n = c.length;
    final h = _head(t);
    final uEnd = u1 * h;
    final after = smooth(_kDrop, _kDrop + 0.07, t);
    final lagU = math.max(0.0, uEnd - (0.3 + 1.05 * h));
    final tStart = lagU + (uEnd - lagU) * after * 0.8;
    if (uEnd - tStart < 0.03 || after >= 1.0) return;
    final len = (uEnd - tStart) * rm;
    smear(p, swingArc, tStart, uEnd, _kHw + 1.0, (u, rad, out, _) {
      final lead = (uEnd - u) * rm;
      final f = lead / len;
      final w = _kHw *
          (lead < 3.0
              ? 1.0
              : math.pow(
                  math.max(0.0, 1.0 - (lead - 3.0) / math.max(1.0, len - 3.0)),
                  0.85,
                )) *
          (1.0 - after * 0.5);
      final off = (rad - rm) / (w / 2.0 + 0.01);
      if (w < 0.6 || off.abs() > 1.0) return;
      final ci = lead < 2.0
          ? 0
          : (1.0 +
                  f * 3.4 +
                  off.abs() * 1.4 -
                  (off > 0.55 ? 1.0 : 0.0) +
                  after * 3.0 +
                  0.5)
              .floor();
      if (ci > n - 3) return;
      out.c = c[n - 1 - math.max(0, ci)];
    });
    if (after < 0.6) {
      const streaks = [
        (-_kHw / 2.0 - 2.0, 3.0, 26.0),
        (-_kHw / 2.0 - 5.0, 9.0, 16.0),
        (_kHw / 2.0 + 2.0, 2.0, 30.0),
        (_kHw / 2.0 + 5.0, 8.0, 18.0),
      ];
      final extra = [
        (-1.0, len + 2.0, 14.0),
        (3.0, len + 4.0, 9.0),
      ];
      for (final (dr, l0, lMax) in [...streaks, ...extra]) {
        final rad = rm + dr;
        for (var d = l0; d < l0 + lMax * (1.0 - after); d += 0.5) {
          final u = uEnd - d / rad;
          final k = (d - l0) / lMax;
          if (u < 0.0) break;
          final (sx, sy) = onSwing(swingArc, rad, u);
          p.dot(
            sx,
            sy,
            k < 0.25
                ? c[6]
                : k < 0.6
                    ? c[5]
                    : c[4],
            (1.0 - k) * (1.0 - after),
          );
        }
      }
    }
    final (hx, hy) = onSwing(swingArc, rm, uEnd);
    p.glow(hx, hy, 34.0, c[4], 0.5 * (1.0 - smooth(_kDrop - 0.03, _kDrop, t)));
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (!hit && t >= _kDrop) {
      hit = true;
      lights.add(hitX, -5.0, 16.0, kWhite, 0.35, 0.08);
      lights.add(hitX, -10.0, 64.0, c[4], 0.42, 0.6);
      for (var i = 0; i < 15; i++) {
        final s = r.sign().toDouble();
        bits.add(
          DebrisBit(
            kind: B.chunk,
            x: hitX + s * r.range(0.0, 5.0),
            y: -2.0,
            vx: s * r.range(20.0, 105.0),
            vy: -r.range(110.0, 300.0),
            g: 1.0,
            drag: 0.35,
            bounce: 0.38,
            life: r.range(1.25, 1.65),
            a: r.range(0.0, tau),
            va: r.range(-16.0, 16.0),
            s: r.pick(const [1.0, 1.0, 2.0, 2.0, 3.0]),
          ),
        );
      }
      for (var i = 0; i < 11; i++) {
        final a = -math.pi / 2.0 + r.range(-1.2, 1.2);
        final sp = r.range(90.0, 230.0);
        chips.add(
          DebrisBit(
            kind: B.shard,
            x: hitX + r.range(-4.0, 4.0),
            y: -2.0,
            vx: math.cos(a) * sp,
            vy: math.sin(a) * sp,
            g: 0.9,
            drag: 0.5,
            bounce: 0.35,
            life: r.range(0.9, 1.5),
            s: 1.0,
          ),
        );
      }
      for (var i = 0; i < 40; i++) {
        final a = -math.pi / 2.0 + r.range(-1.1, 1.1);
        final sp = r.range(50.0, 210.0);
        ps.spawn(
          P.grit,
          hitX + r.range(-4.0, 4.0),
          -1.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.9, 1.5),
          r.pick([st.light, st.body, st.body, st.shade]),
          r.chance(0.4) ? 2.0 : 1.0,
        );
      }
      for (var i = 0; i < 14; i++) {
        final s = i.isOdd ? -1.0 : 1.0;
        final sp = r.range(120.0, 260.0);
        ps.spawn(
          P.mote,
          hitX + s * 6.0,
          -r.range(1.0, 4.0),
          s * sp,
          -r.range(0.0, 30.0),
          r.range(0.18, 0.34),
          r.chance(0.5) ? c[6] : c[5],
          0.8,
          r.range(0.02, 0.05),
        );
      }
      for (var i = 0; i < 24; i++) {
        final a = -math.pi / 2.0 + r.range(-1.4, 1.4);
        final sp = r.range(150.0, 380.0);
        ps.spawn(
          P.spark,
          hitX + math.cos(a) * 6.0,
          -2.0 + math.sin(a) * 4.0,
          math.cos(a) * sp,
          math.sin(a) * sp - 30.0,
          r.range(0.12, 0.42),
          0,
          1.0,
          r.range(0.035, 0.08),
        );
      }
      for (var i = 0; i < 20; i++) {
        final s = i.isOdd ? -1.0 : 1.0;
        ps.spawn(
          P.smoke,
          hitX + s * r.range(2.0, 10.0),
          -r.range(2.0, 7.0),
          s * r.range(40.0, 125.0),
          -r.range(2.0, 14.0),
          r.range(0.95, 1.5),
          st.dust,
          r.range(6.0, 9.0),
          r.range(0.02, 0.08),
          PF.big,
        );
      }
      for (var i = 0; i < 7; i++) {
        ps.spawn(
          P.smoke,
          hitX + r.range(-6.0, 6.0),
          -r.range(3.0, 9.0),
          r.range(-20.0, 20.0),
          -r.range(30.0, 80.0),
          r.range(1.0, 1.4),
          st.dust,
          r.range(5.0, 7.5),
          r.range(0.04, 0.14),
          PF.big,
        );
      }
      for (var i = 0; i < 8; i++) {
        ps.spawn(
          P.dust,
          hitX + r.range(-6.0, 6.0),
          -r.range(1.0, 4.0),
          r.range(-70.0, 70.0),
          -r.range(8.0, 30.0),
          r.range(0.35, 0.7),
          st.dust,
          r.range(2.0, 3.5),
        );
      }
    }
    bits.update(dt);
    chips.update(dt);
    if (hit && t > _kDrop + 0.4 && t < _kDrop + 1.2 && r.chance(0.08)) {
      if (bits.list.isNotEmpty) {
        final b = r.pick(bits.list);
        if (b.rest) {
          ps.spawn(
            P.star,
            b.x + r.range(-1.0, 1.0),
            b.y - 1.5 - b.s,
            0.0,
            -2.0,
            r.range(0.25, 0.45),
            r.chance(0.5) ? _kHot[0] : kWhite,
            r.range(0.6, 1.6),
          );
        }
      }
    }
    for (final b in bits.list) {
      if (b.rest && !dusted.contains(b)) {
        dusted.add(b);
        for (var i = 0; i < 3; i++) {
          ps.spawn(
            P.dust,
            b.x + r.range(-1.5, 1.5),
            -0.5,
            r.sign() * r.range(8.0, 35.0),
            -r.range(2.0, 14.0),
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
    final q = t - _kDrop;
    if (q >= 0.0) {
      final fade = 1.0 - smooth(1.3, 1.7, q);
      for (var x = -11; x <= 11; x++) {
        final u = x / 10.0;
        final d = x.abs() > 10
            ? 0
            : (3.2 * (1.0 - u * u) + (rand(x, 4) - 0.5) * 0.8 + 0.5).floor();
        for (var y = 0; y < d; y++) {
          p.dot(hitX + x, y.toDouble(), y == 0 ? _kSoot : st.dark, fade);
        }
        if (d > 0) {
          p.dot(hitX + x, d.toDouble(), x.abs() < 7 ? st.light : st.body, fade);
        }
        if (x.abs() >= 8) {
          p.dot(hitX + x, -1.0, x.abs() >= 10 ? st.body : st.light, fade);
        }
        if (x.abs() == 9 && rand(x, 7) < 0.7) {
          p.dot(hitX + x, -2.0, st.body, fade);
        }
      }
      final k = q / 0.5;
      if (k < 1.0) {
        band(
          p,
          hitX,
          0.5,
          6.0 + 50.0 * Ease.outCubic(k),
          0.16,
          math.max(1.0, 2.0 * (1.0 - k)),
          1.15 - k,
          [st.body, c[3], c[5], c[7]],
          keep: (double g) => math.sin(g) < 0.0,
        );
      }
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final q = t - _kDrop;
    _wedge(p);
    if (q >= 0.0) {
      final fade = 1.0 - smooth(1.3, 1.7, q);
      for (final cl in lines) {
        final reach = 30.0 *
            Ease.outCubic(clamp((q - cl.at * 0.06) / 0.08)) *
            (cl.fork ? 0.3 : 1.0);
        if (reach > 0.0) {
          along(cl.pts, reach, (x0, y0, x1, y1, _) {
            if (q >= 0.12) {
              p.line(x0, y0 + 3.0, x1, y1 + 3.0, st.shade, fade);
            }
            p.line(
              x0,
              y0 + 2.0,
              x1,
              y1 + 2.0,
              q < 0.05
                  ? kWhite
                  : q < 0.12
                      ? c[5]
                      : _kSoot,
              fade,
            );
          });
        }
      }
      final k = q / 0.5;
      if (k < 1.0) {
        band(
          p,
          hitX,
          0.5,
          6.0 + 50.0 * Ease.outCubic(k),
          0.16,
          math.max(1.0, 2.0 * (1.0 - k)),
          1.15 - k,
          [st.body, c[3], c[5], c[7]],
          keep: (double g) => math.sin(g) >= 0.0,
        );
      }
      final d = (q - 0.045) / 0.4;
      if (d >= 0.0 && d < 1.0) {
        final rad = 12.0 + 30.0 * Ease.outCubic(d);
        final th = math.max(1.0, 3.6 * math.pow(1.0 - d, 0.8));
        final a = d < 0.6 ? 1.0 : (1.0 - d) / 0.4;
        p.shade(hitX - rad - 1.0, -rad - 1.0, hitX + rad + 1.0, 0.0, (x, y, out) {
          final e = rad - hypot(x - hitX, y);
          if (e < 0.0 || e > th || y > -0.5) return null;
          final v = e / th;
          out.c = d < 0.1
              ? (v < 0.6 ? kWhite : c[6])
              : v < 0.34
                  ? (d < 0.45 ? kWhite : c[6])
                  : v < 0.67
                      ? c[5]
                      : c[4];
          out.a = a;
          return null;
        });
        for (var i = 0; i < 7; i++) {
          final g = -math.pi * (0.08 + (i / 6.0) * 0.84);
          p.glow(
            hitX + math.cos(g) * rad,
            math.sin(g) * rad,
            14.0,
            c[4],
            0.36 * (1.0 - d),
          );
        }
      }
      if (q < 0.2) {
        for (final ry in rays) {
          final d1 = ry.l * Ease.outCubic(math.min(1.0, q / 0.05));
          final d0 = ry.l * smooth(0.04, 0.2, q);
          final ca = math.cos(ry.a);
          final sa = math.sin(ry.a);
          if (d1 - d0 < 1.0) continue;
          p.lineShaded(
            hitX + ca * (2.0 + d0),
            -1.0 + sa * (2.0 + d0),
            hitX + ca * d1,
            -1.0 + sa * d1,
            color: (double u) => u < 0.5
                ? kWhite
                : u < 0.8
                    ? c[6]
                    : c[5],
          );
          p.glowLine(
            hitX + ca * d0,
            -1.0 + sa * d0,
            hitX + ca * d1,
            -1.0 + sa * d1,
            4.0,
            c[5],
            0.18 * (1.0 - q / 0.2),
          );
        }
      }
      if (q < 0.07) {
        final hot = q < 0.035;
        final rx = hot ? 16.0 : 12.0;
        final ry = hot ? 3.0 : 2.0;
        p.ellipse(hitX, 0.0, rx + 2.0, ry + 1.0, hot ? c[6] : c[5]);
        p.ellipse(hitX, 0.0, rx, ry, hot ? kWhite : c[7]);
      }
      if (q < 0.2) {
        final pop = math.exp(-q / 0.05);
        p.glow(hitX, -5.0, 26.0, c[5], 0.3 * pop);
      }
      p.glow(hitX, -1.0, 16.0, _kHot[2], 0.28 * math.exp(-q / 0.35));
    }
    for (final b in bits.list) {
      rock(p, b, st);
    }
    for (final b in chips.list) {
      final k = b.life / b.max;
      final col = k > 0.7
          ? _kHot[0]
          : k > 0.45
              ? _kHot[1]
              : k > 0.25
                  ? _kHot[2]
                  : _kHot[3];
      p.dot(b.x, b.y, col, math.min(1.0, k * 4.0));
      if (!b.rest) {
        p.dot(
          b.x - b.vx * 0.012,
          b.y - b.vy * 0.012,
          _kHot[3],
          math.min(1.0, k * 4.0),
        );
      }
      p.glow(b.x, b.y, 4.0, col, 0.35 * k);
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect hammerSmashEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'melee/hammer-smash',
    name: 'Hammer smash',
    desc:
        'A hammer drops in front in a wedge of motion: a white slam with rays, a dome of force, a dent with cracks, rocks thrown up that bounce and settle, and dust.',
    category: 'melee',
    tags: [
      'melee',
      'smash',
      'hammer',
      'heavy',
      'ground',
      'shockwave',
      'debris',
      'combat',
      'directional',
      'one-shot',
    ],
    size: (208, 112),
    origin: (80, 92),
    duration: 2.0,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#141834',
        '#242c5c',
        '#38479a',
        '#5a72d0',
        '#8fa8f0',
        '#c4d4ff',
        '#eef3ff',
        '#ffffff',
      ],
      'stone': '#4a3f69',
      'seed': 9,
    },
  ),
  act: ActSpec(
    target: const TargetSpec(x: 66),
    poses: [
      PoseKey(-0.72, _rest.copyWith(x: -3)),
      PoseKey(
        -0.44,
        _rest.copyWith(x: -3, crouch: 5, lean: -1, fx: 16, fy: -28, sa: -0.9),
      ),
      PoseKey(-0.2, _top),
      PoseKey(-0.03, _top.copyWith(y: -2)),
      PoseKey(
        0.06,
        _rest.copyWith(
          x: 0,
          y: -3,
          crouch: -1,
          lean: 2,
          fx: 13,
          fy: -41,
          sa: -1.2,
          ffx: 11,
          ffy: -8,
          ghost: 1,
        ),
        PoseEase.snap,
      ),
      PoseKey(
        0.11,
        _rest.copyWith(
          x: 0,
          y: -1,
          crouch: 3,
          lean: 5,
          fx: 19,
          fy: -30,
          sa: -0.15,
          ffx: 13,
          ghost: 1,
        ),
        PoseEase.snap,
      ),
      PoseKey(0.15, _slam, PoseEase.snap),
      PoseKey(0.62, _slam.copyWith(crouch: 6, lean: 5)),
      PoseKey(
        1.02,
        _rest.copyWith(x: -2, crouch: 5, lean: 2, fx: 14, fy: -24, sa: 0.3),
      ),
      PoseKey(1.4, _rest.copyWith(x: -3)),
    ],
    hits: const [
      HitSpec(
        t: 0.15,
        stop: 0.2,
        shake: 0.34,
        amp: 3,
        push: 3,
        straw: 26,
        y: -8,
      ),
    ],
    dust: const [
      DustSpec(t: 0.15, x: 10, n: 8),
      DustSpec(t: 0.15, x: -12, n: 5, dir: -1),
    ],
  ),
  onCreate: (o) => _HammerSmashSim(o),
);
