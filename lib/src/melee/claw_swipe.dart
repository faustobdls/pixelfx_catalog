// The shaded smear, its light and the dotted trace follow Sprite Fusion's open-source slash
// (https://www.spritefusion.com/pixel-art-vfx/slash), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'melee_lib.dart';

final Pose _ready = kReady.copyWith(
  weapon: 'claw',
  offWeapon: 'claw',
  sa: -0.4,
  sb: -0.9,
  crouch: 5,
  lean: 3,
  fx: 14,
  fy: -21,
  bx: 8,
  by: -25,
  ffx: 9,
  fbx: -8,
);

final Pose _high = _ready.copyWith(
  x: -6,
  crouch: 4,
  lean: -3,
  fx: 3,
  fy: -41,
  sa: -1.4,
  bx: 7,
  by: -18,
  sb: -0.3,
  ffx: 10,
);

const double _kRake = 0.05;
const double _kStagger = 0.04;
const double _kClose0 = 0.16;
const double _kClose = 0.3;

class _ClawMark {
  final Swing s;
  final double t0;
  final double w;
  final SwingPoint end;
  bool open = false;

  _ClawMark({
    required this.s,
    required this.t0,
    required this.w,
    required this.end,
  });
}

class _ClawSwipeSim extends BaseEffectSim {
  final List<int> c;
  final Rng rg;
  late final Particles ps;
  late final Bits drips;
  final Lights lights = Lights();
  late final List<_ClawMark> marks;
  double t = 0.0;

  _ClawSwipeSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        rg = Rng(o.seed) {
    double floor(double _) => 0.0;
    ps = Particles(
      rng: rg,
      ground: floor,
      sparks: (o['sparks'] as List).cast<Object>(),
    );
    drips = Bits(ground: floor);
    marks = List.generate(3, (i) {
      final s = through(
        31.0 + i * 8.0,
        -23.0 + i * 2.0,
        1.84,
        1.0,
        40.0,
        0.84 - i * 0.05,
        at: 0.5,
      );
      return _ClawMark(
        s: s,
        t0: i * _kStagger,
        w: 4.2 - i * 0.4,
        end: swingTravel(s, s.span),
      );
    });
  }

  double _heatAt(_ClawMark m) => clamp(1.0 - (t - m.t0) / 0.42);

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    for (final m in marks) {
      if (!m.open && t >= m.t0 + _kRake * 0.7) {
        m.open = true;
        lights.add(m.end.x, m.end.y - 6.0, 34.0, c[4], 0.45, 0.3);
        for (var i = 0; i < 7; i++) {
          final a = math.atan2(m.end.dy, m.end.dx) + rg.range(-0.5, 0.5);
          final sp = rg.range(110.0, 260.0);
          ps.spawn(
            P.spark,
            m.end.x,
            m.end.y,
            math.cos(a) * sp,
            math.sin(a) * sp,
            rg.range(0.12, 0.32),
          );
        }
        for (var i = 0; i < 5; i++) {
          final (x, y) = onSwing(m.s, m.s.r, m.s.span * rg.range(0.15, 0.9));
          ps.spawn(
            P.mote,
            x,
            y,
            rg.range(-60.0, -10.0),
            rg.range(-30.0, 30.0),
            rg.range(0.2, 0.4),
            rg.chance(0.5) ? c[5] : c[4],
            0.5,
          );
        }
        for (var i = 0; i < 2; i++) {
          final (x, y) = onSwing(
            m.s,
            m.s.r - 1.0,
            m.s.span * rg.range(0.35, 0.75),
          );
          drips.add(
            DebrisBit(
              kind: B.drip,
              x: x,
              y: y,
              vx: rg.range(-8.0, 8.0),
              vy: rg.range(10.0, 40.0),
              g: 0.55,
              life: 1.2,
              c: c[3],
            ),
          );
        }
      }
    }
    drips.update(dt);
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    final n = c.length;
    for (final m in marks) {
      final u = t - m.t0;
      if (u < 0.0) continue;
      final sSpan = m.s.span;
      final head = sSpan * Ease.outExpo(clamp(u / _kRake));
      final cl = smooth(_kClose0, _kClose0 + _kClose, u);
      final lo = (sSpan / 2.0) * cl;
      final hi = math.min(head, sSpan - (sSpan / 2.0) * cl);
      final heat = _heatAt(m);
      if (hi - lo > 0.02) {
        smear(p, m.s, lo, hi, m.w, (uu, r, out, _) {
          final v = uu / sSpan;
          final w = m.w *
              math.pow(math.max(0.0, math.sin(math.pi * v)), 1.15) *
              (1.0 - 0.55 * cl);
          final off = (r - (m.s.r - m.w / 2.0)).abs() / (w / 2.0 + 0.01);
          if (w < 0.5 || off > 1.0) return;
          final ci = ((1.0 - heat) * 5.2 +
                  off * 1.6 +
                  (head < sSpan ? (sSpan - uu) / sSpan : 0.0) * 0.5 +
                  0.5)
              .floor();
          out.c = c[n - 1 - clampInt(ci, 0, n - 2)];
        }, pad: 2.0);
        glowAlong(
          p,
          m.s,
          m.s.r - m.w / 2.0,
          lo,
          hi,
          11.0,
          c[4],
          0.42 * heat * heat,
          step: 0.2,
        );
      }
      final k = 0.8 * (1.0 - clamp((u - _kClose0 - _kClose * 0.5) / 0.4));
      if (cl > 0.05 && k > 0.0) {
        trace(p, m.s, m.s.r - m.w / 2.0, 0.04 * sSpan, lo, c[2], k);
        trace(p, m.s, m.s.r - m.w / 2.0, sSpan - lo, 0.96 * sSpan, c[2], k);
      }
      final g = u - _kRake * 0.4;
      if (g > 0.0 && g < 0.16) {
        sparkle(
          p,
          m.end.x,
          m.end.y,
          5.0 * Ease.outBack(math.min(1.0, g / 0.04)) * (1.0 - g / 0.16),
          c[6],
          c[4],
          0.4,
        );
      }
    }
    drips.draw(p);
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect clawSwipeEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'melee/claw-swipe',
    name: 'Claw swipe',
    desc:
        'Three claw marks rake down one after another, white-hot, cooling through orange to red, then close up from both ends and leave a dotted scar, with hot flecks and drips.',
    category: 'melee',
    tags: [
      'melee',
      'claw',
      'swipe',
      'beast',
      'scratch',
      'combat',
      'directional',
      'one-shot',
    ],
    size: (128, 96),
    origin: (36, 84),
    duration: 0.9,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#2a0808',
        '#5c0f12',
        '#a51d1d',
        '#e2401f',
        '#ff8a2a',
        '#ffd166',
        '#fff3c4',
        '#ffffff',
      ],
      'sparks': ['#fff3c4', '#ffd166', '#ff8a2a', '#c42a1a'],
      'seed': 8,
    },
  ),
  act: ActSpec(
    target: const TargetSpec(x: 58),
    poses: [
      PoseKey(-0.46, _ready.copyWith(x: -6)),
      PoseKey(-0.2, _high),
      PoseKey(-0.05, _high.copyWith(crouch: 5)),
      PoseKey(
        0.0,
        _ready.copyWith(
          x: 0,
          crouch: 3,
          lean: 4,
          fx: 19,
          fy: -36,
          sa: -0.9,
          bx: -7,
          by: -24,
          ghost: 1,
        ),
        PoseEase.snap,
      ),
      PoseKey(
        0.05,
        _ready.copyWith(
          x: 2,
          crouch: 5,
          lean: 6,
          fx: 23,
          fy: -24,
          sa: 0.5,
          bx: -7,
          by: -24,
          ffx: 13,
          fbx: -10,
          toeB: true,
        ),
        PoseEase.snap,
      ),
      PoseKey(
        0.1,
        _ready.copyWith(
          x: 3,
          crouch: 7,
          lean: 7,
          fx: 22,
          fy: -12,
          sa: 1.2,
          bx: -7,
          by: -24,
          ffx: 13,
          fbx: -10,
          toeB: true,
        ),
        PoseEase.snap,
      ),
      PoseKey(
        0.42,
        _ready.copyWith(
          x: 3,
          crouch: 6,
          lean: 5,
          fx: 21,
          fy: -13,
          sa: 1.1,
          bx: -6,
          by: -22,
          ffx: 13,
          fbx: -10,
        ),
      ),
      PoseKey(0.9, _ready.copyWith(x: -6)),
    ],
    hits: const [
      HitSpec(
        t: 0.04,
        stop: 0.03,
        push: 0.9,
        straw: 5,
        y: -30,
        flash: 0.03,
      ),
      HitSpec(
        t: 0.08,
        stop: 0.03,
        push: 0.9,
        straw: 5,
        y: -26,
        flash: 0.03,
      ),
      HitSpec(
        t: 0.12,
        stop: 0.08,
        shake: 0.14,
        amp: 2,
        push: 1.4,
        straw: 9,
        y: -18,
      ),
    ],
    dust: const [DustSpec(t: 0.1, x: 12, n: 6, dir: 1)],
  ),
  onCreate: (o) => _ClawSwipeSim(o),
);
