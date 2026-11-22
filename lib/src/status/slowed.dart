import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'status_lib.dart';

const double _d = 2.4;
const int _ticks = 4;
const double _step = _d / _ticks;
const double _r = 18.0;

const Pose _s1 = Pose(
  turn: 0.3,
  lean: 3,
  crouch: 3,
  ffx: 11,
  ffy: -5,
  fbx: -9,
  fby: -5,
  toeB: true,
  fx: -5,
  fy: -19,
  bx: 11,
  by: -26,
);
const Pose _s2 = Pose(
  turn: 0.3,
  lean: 3,
  crouch: 3,
  ffx: -9,
  ffy: -5,
  toeF: true,
  fbx: 11,
  fby: -5,
  fx: 13,
  fy: -26,
  bx: -4,
  by: -19,
);

({double ang, double flash, double ph}) _hand(double t) {
  final k = (t / _step).floor();
  final ph = (t - k * _step) / _step;
  final base = -math.pi / 2.0 + (k * tau) / _ticks;
  const q = tau / _ticks;
  if (ph < 0.62) return (ang: base, flash: 0.0, ph: ph);
  if (ph < 0.72) {
    return (
      ang: base - 0.1 * math.sin(((ph - 0.62) / 0.1) * math.pi * 0.5),
      flash: 0.0,
      ph: ph,
    );
  }
  final s = (ph - 0.72) / 0.28;
  final snap = Ease.outBack(clamp(s / 0.35), 2.2);
  final wob = math.exp(-s * 6.0) * math.sin(s * 22.0) * 0.05;
  return (
    ang: base - 0.1 * (1.0 - clamp(s / 0.2)) + q * snap + wob,
    flash: math.exp(-s * 5.0),
    ph: ph,
  );
}

double _afterglow(double t) {
  final s = (((t - _step * 0.72) % _step) + _step) % _step;
  return math.exp(-s * 4.0);
}

void _dial(Painter p, List<int> c, double cx, double cy, double t) {
  final h = _hand(t);
  final fl = math.max(h.flash, _afterglow(t));

  p.disc(cx, cy, _r - 1.0, c[2], 0.2);
  p.disc(cx - _r * 0.25, cy - _r * 0.3, _r * 0.5, c[4], 0.08);
  p.ring(cx, cy, _r + 1.0, 1.0, c[0]);
  p.ringShaded(
    cx,
    cy,
    _r,
    2.0,
    color: (double v, double ang) => math.sin(ang + 0.8) < -0.3
        ? (fl > 0.4 ? c[7] : c[6])
        : (v > 0.5 ? c[5] : c[4]),
  );
  p.ring(cx, cy, _r - 3.5, 1.0, c[3], 0.6);

  for (var i = 0; i < 60; i++) {
    if (i % 5 == 0) continue;
    final a = (i / 60.0) * tau;
    p.dot(
      cx + math.cos(a) * (_r - 2.6),
      cy + math.sin(a) * (_r - 2.6),
      c[4],
      0.8,
    );
  }
  for (var i = 0; i < 12; i++) {
    final a = (i / 12.0) * tau;
    final big = i % 3 == 0;
    const r0 = _r - 2.5;
    final r1 = _r - (big ? 6.0 : 4.5);
    final ca = math.cos(a);
    final sa = math.sin(a);
    p.line(
      cx + ca * r0,
      cy + sa * r0,
      cx + ca * r1,
      cy + sa * r1,
      big ? c[6] : c[5],
    );
  }

  final shud = h.flash * math.sin(t * 60.0) * 0.06;
  final ha = -math.pi / 2.0 + 2.2 + shud;
  p.beam(
    cx,
    cy,
    cx + math.cos(ha) * _r * 0.5,
    cy + math.sin(ha) * _r * 0.5,
    2.2,
    c[5],
  );
  final tx = cx + math.cos(h.ang) * (_r - 4.0);
  final ty = cy + math.sin(h.ang) * (_r - 4.0);
  p.beamShaded(
    cx,
    cy,
    tx,
    ty,
    2.4,
    color: (double u, double _) => u > 0.8 ? c[7] : c[6],
  );
  p.circle(cx, cy, 2.0, c[6]);
  p.px(cx, cy, c[1]);

  p.glow(cx, cy, _r + 8.0, c[4], 0.14 + 0.2 * fl);
  p.glowRing(cx, cy, _r, 3.0, c[5], 0.12 + 0.35 * fl);
  p.glow(tx, ty, 5, c[6], 0.3 + 0.3 * h.flash);
  if (h.flash > 0.02) {
    final s = 1.0 - h.flash;
    p.ring(cx, cy, _r + 2.0 + 10.0 * s, 1.0, c[5], h.flash);
    p.glowRing(cx, cy, _r + 2.0 + 10.0 * s, 3.0, c[4], 0.3 * h.flash);
  }
}

final PureEffect slowedEffect = PureEffect(
  meta: const EffectMeta(
    id: 'status/slowed',
    name: 'Slowed',
    desc:
        'Dragged through time: a glassy clock dial behind the head ticks round in heavy steps, flashing with each, while drops sink in slow motion and spread slow rings.',
    category: 'status',
    tags: ['status', 'slow', 'time', 'clock', 'debuff', 'loop'],
    size: (64, 76),
    origin: (32, 68),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#081a24', '#0e3446', '#165a6e', '#2a8a9a',
        '#52bcc4', '#9ee6e0', '#e2fff8', '#ffffff',
      ],
      'seed': 7,
    },
  ),
  act: const ActSpec(
    onBody: true,
    poses: [
      PoseKey(0.0, _s1),
      PoseKey(1.2, _s2),
      PoseKey(2.4, _s1),
    ],
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final a = o.actor;
    _dial(p, c, 0.0, a.y + 3.0, t);
    final lag = _afterglow(t);
    if (lag > 0.05) {
      p.outline(
        a.mask,
        a.x - 1 - (2.0 * lag + 0.5).floor(),
        a.y,
        c[5],
        0.55 * lag,
      );
    }
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final a = o.actor;
    final s = actorShape(a);
    final fl = math.max(_hand(t).flash, _afterglow(t));

    for (final (mx, my) in s.body) {
      p.blend(a.x + mx, a.y + my, c[5], 0.08 + 0.12 * fl);
    }

    cycle(t, _d, 6, o.seed + 3, (r) => r.range(1.6, 2.2), (age, life, r, _) {
      final side = r.next() < 0.5 ? -1 : 1;
      final x = side * r.range(10.0, 17.0);
      final y0 = a.y + r.range(6.0, 22.0);
      final v0 = r.range(18.0, 30.0);
      const k = 1.1;
      double yAt(double g) => y0 + (v0 * (1.0 - math.exp(-k * g))) / k + 4.0 * g;
      final y = yAt(age);
      final u = age / life;
      if (y < -1.0) {
        for (final (lag, al) in const [(0.22, 0.35), (0.11, 0.6)]) {
          if (age > lag) p.dot(x, yAt(age - lag), c[4], al);
        }
        p.px(x, y - 1.0, c[5]);
        p.px(x, y, c[6]);
        p.px(x, y + 1.0, c[5]);
        p.px(x - 1.0, y + 1.0, c[4]);
        p.px(x - 1.0, y, c[7]);
        p.glow(x, y, 4, c[5], 0.3 * (1.0 - u));
      } else {
        var g = age;
        while (g > 0.0 && yAt(g) >= -1.0) {
          g -= 0.02;
        }
        final st = clamp((age - g) / 0.9);
        if (st < 1.0) {
          final rx = 1.0 + 7.0 * math.sqrt(st);
          final col = st < 0.3 ? c[6] : c[5];
          for (final sd in const [-1, 1]) {
            p.line(
              x + sd * rx,
              -0.5,
              x + sd * (rx - 1.5),
              -0.5,
              col,
              (1.0 - st) * 1.2,
            );
          }
          for (var dx = -rx + 2.0; dx <= rx - 2.0; dx += 1.0) {
            p.dot(
              x + dx,
              -1.5,
              c[4],
              (1.0 - st) * 0.5 * (1.0 - dx.abs() / rx),
            );
          }
          p.glow(x, -1.0, 4.0 + rx, c[4], 0.12 * (1.0 - st));
        }
      }
    });
  },
);
