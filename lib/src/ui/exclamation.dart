import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const double _head = -40.0;
const double _rest = -45.0;
const double _pop = 1.1;
const double _duration = 1.4;

const Pose _startled = Pose(
  turn: 1,
  y: -5,
  crouch: -1,
  fx: -14,
  fy: -34,
  bx: 15,
  by: -34,
  ffx: -3,
  ffy: -6,
  fbx: 4,
  fby: -6,
);

void _drawBang(
  Painter p,
  List<int> c,
  double x,
  double y,
  double sx,
  double sy,
  double a,
  bool white,
) {
  final ca = math.cos(a);
  final sa = math.sin(a);
  double hw(double v) => 2.3 + (-v - 10.0) * 0.09;
  bool inBar(double u, double v) =>
      v > -24.0 && v < -9.5 && u.abs() < hw(v);
  bool inDot(double u, double v) => hypot(u, v + 3.6) < 3.3;
  bool inside(double u, double v) => inBar(u, v) || inDot(u, v);

  p.shade(x - 16.0, y - 34.0, x + 16.0, y + 6.0, (px, py, _) {
    final dx = px - x;
    final dy = py - y;
    final u = (dx * ca + dy * sa) / sx;
    final v = (-dx * sa + dy * ca) / sy;
    final ex = 1.0 / sx;
    final ey = 1.0 / sy;
    if (!inside(u, v)) {
      return (inside(u - ex, v) ||
              inside(u + ex, v) ||
              inside(u, v - ey) ||
              inside(u, v + ey))
          ? c[0]
          : null;
    }
    if (white) return kWhite;
    if (inDot(u, v)) {
      if (hypot(u + 1.2, v + 4.8) < 1.2) return kWhite;
      if (u + v + 3.6 < -0.5) return c[6];
      if (u + v + 3.6 < 1.5) return c[5];
      return c[4];
    }
    final w = hw(v);
    final q = (u + w) / (2.0 * w);
    if (q < 0.28) return v < -20.0 ? kWhite : c[7];
    if (q > 0.74) return c[4];
    return v < -18.0 ? c[6] : (v < -13.0 ? c[5] : c[5]);
  });
}

class _ExclamationSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  static const double _end = _duration - 0.05;

  double my = _head;
  double mvy = -420.0;
  double sq = 0.0;
  bool landed = false;

  double t = 0.0;
  bool popped = false;
  bool sprung = false;

  _ExclamationSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed) {
    ps = Particles(rng: r, sparks: [c[7], c[6], c[5], c[3]]);
  }

  @override
  void update(double dt, Map<String, Object?> options) {
    t += dt;
    if (t < _pop) {
      mvy += (-(my - _rest) * 900.0 - mvy * 14.0) * dt;
      my += mvy * dt;
      if (!landed && mvy > 0.0) {
        landed = true;
        sq = 1.0;
      }
    }
    sq = math.max(0.0, sq - dt / 0.12);

    if (!sprung && t >= 0.04) {
      sprung = true;
      lights.add(0, _head - 4.0, 26, c[5], 0.6, 0.25);
      for (var i = 0; i < 8; i++) {
        final an = -math.pi / 2.0 + r.range(-1.3, 1.3);
        final sp = r.range(40.0, 90.0);
        ps.spawn(
          P.star,
          r.range(-4.0, 4.0),
          _head - 2.0,
          math.cos(an) * sp,
          math.sin(an) * sp,
          r.range(0.2, 0.4),
          r.pick([c[7], c[6], c[5]]),
          i % 3 != 0 ? 0.6 : 1.3,
        );
      }
    }

    if (!popped && t >= _pop + 0.05) {
      popped = true;
      lights.add(0, _rest - 13.0, 28, c[5], 0.5, 0.2);
      for (var i = 0; i < 7; i++) {
        final an = (i / 7.0) * tau + r.range(-0.2, 0.2);
        final sp = r.range(30.0, 60.0);
        ps.spawn(
          P.star,
          math.cos(an) * 5.0,
          _rest - 13.0 + math.sin(an) * 9.0,
          math.cos(an) * sp,
          math.sin(an) * sp,
          math.min(r.range(0.2, 0.35), _end - t),
          r.pick([c[7], c[6], c[5]]),
          i % 3 != 0 ? 0.6 : 1.4,
        );
      }
    }

    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    final k = t;
    for (final (t0, len) in const [(0.04, 6.0), (0.48, 4.5)]) {
      final u = (k - t0) / 0.24;
      if (u <= 0.0 || u >= 1.0) continue;
      for (final s in const [-1, 1]) {
        for (var i = 0; i < 3; i++) {
          final an = -math.pi / 2.0 + s * (0.55 + i * 0.42);
          final r0 = 14.0 + 7.0 * Ease.outCubic(u);
          final l = len * math.sin(u * math.pi) * (i == 1 ? 1.0 : 0.75);
          if (l < 0.8) continue;
          const cy = _rest - 13.0;
          final ca = math.cos(an);
          final sa = math.sin(an);
          p.lineShaded(
            ca * r0,
            cy + sa * r0,
            ca * (r0 + l),
            cy + sa * (r0 + l),
            color: (q) => q < 0.5 ? kWhite : c[5],
          );
        }
      }
    }

    final pu = (k - _pop) / 0.06;
    if (pu < 1.0) {
      final speed = math.min(1.0, mvy.abs() / 420.0);
      final up = mvy < 0.0 ? speed : 0.0;
      var sx = 1.0 - 0.3 * up + 0.3 * sq;
      var sy = 1.0 + 0.45 * up - 0.28 * sq;
      if (k < 0.05) {
        sx *= k / 0.05;
        sy *= k / 0.05;
      }
      if (pu > 0.0) {
        sx = sy = 1.0 + 0.3 * pu;
      }
      final wob = 0.28 * math.exp(-k * 4.0) * math.sin(k * 26.0);
      final white = k < 0.06 || pu > 0.0;
      if (sx > 0.1) _drawBang(p, c, 0.0, my, sx, sy, wob, white);
      p.glow(0, my - 13.0, 20, c[5], 0.35 + (white ? 0.3 : 0.0));
      if (k > 0.6 && k < 0.85) {
        sparkle(
          p,
          -3,
          my - 22.0,
          3.5 * math.sin(((k - 0.6) / 0.25) * math.pi),
          c[7],
          c[6],
          0.4,
        );
      }
    }

    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect exclamationEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ui/exclamation',
    name: 'Exclamation',
    desc:
        'A bold ! springs up off the hero\'s head, stretching as it shoots up and squashing as it lands; surprise ticks flick out, it wobbles, then pops away.',
    category: 'ui',
    tags: ['ui', 'alert', 'surprise', 'emote', 'character', 'one-shot'],
    size: (84, 104),
    origin: (42, 92),
    duration: _duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#2a1405',
        '#6a2e06',
        '#b85a0a',
        '#f08c14',
        '#ffc23a',
        '#ffe580',
        '#fff6c8',
        '#ffffff',
      ],
      'seed': 3,
    },
  ),
  act: ActSpec(
    poses: [
      const PoseKey(-0.08, kReady),
      const PoseKey(0.0, _startled, PoseEase.snap),
      PoseKey(
        0.14,
        _startled.copyWith(y: 0, crouch: 4, ffy: -4, fby: -4, fy: -26, by: -26),
        PoseEase.inEase,
      ),
      const PoseKey(
        0.3,
        Pose(turn: 1, fx: -10, fy: -23, bx: 11, by: -23, ffx: -3, fbx: 4),
      ),
      const PoseKey(
        1.1,
        Pose(turn: 1, fx: -10, fy: -23, bx: 11, by: -23, ffx: -3, fbx: 4),
      ),
      const PoseKey(1.4, kReady),
    ],
    dust: const [DustSpec(t: 0.14, x: 0.0, n: 4)],
  ),
  onCreate: _ExclamationSim.new,
);
