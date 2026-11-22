// The charge recipe is adapted from Sprite Fusion's open-source energy charge
// (https://www.spritefusion.com/pixel-art-vfx/energy), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'arcane_lib.dart';

const double _d = 1.6;
const double _hx = 15.0;
const double _hy = -22.0;
const int _rings = 4;
const double _rt = 0.5;

final List<double> _landings =
    List.generate(_rings, (k) => (k * _d) / _rings + _rt, growable: false);

double _sinceLast(double t) {
  var best = double.infinity;
  for (final l in _landings) {
    final diff = (((t - l) % _d) + _d) % _d;
    if (diff < best) best = diff;
  }
  return best;
}

const Pose _hold = Pose(
  x: -3,
  crouch: 4,
  lean: 2,
  fx: 18,
  fy: -22,
  bx: 11,
  by: -17,
  ffx: 10,
  fbx: -8,
);

const List<(double sy, double rot)> _ringShapes = [
  (1.0, 0.0),
  (0.38, 0.55),
  (1.0, 0.0),
  (0.42, -0.7),
];

void _drawOrb(
  Painter p,
  List<int> c,
  double x,
  double y,
  double r,
  double t,
  double ph,
) {
  for (var i = 0; i < 8; i++) {
    final a = (i / 8.0) * tau + ph * (tau / 8.0) * 3.0;
    final l = (1.5 + 4.5 * loopNoise(ph, 3.0, i * 7 + 1).abs()) *
        (i.isOdd ? 0.7 : 1.0);
    final x0 = x + math.cos(a) * (r + 1.2);
    final y0 = y + math.sin(a) * (r + 1.2);
    p.lineShaded(
      x0,
      y0,
      x0 + math.cos(a) * l,
      y0 + math.sin(a) * l,
      color: (u) => u < 0.4 ? c[6] : (i.isOdd ? c[4] : c[5]),
      alpha: (u) => u < 0.6 ? 1.0 : 1.6 - u,
    );
  }
  p.circle(x, y, r + 1.3, c[4]);
  p.circle(x, y, r + 0.3, c[5]);
  p.circle(x - r * 0.12, y - r * 0.12, r * 0.8, c[6]);
  p.circle(x, y, r * 0.5, kWhite);

  final rr = rng((t * 15.0).floor(), 77);
  for (var i = 0; i < 3; i++) {
    final a = rr.range(0.0, tau);
    final pts = arcaneArc(
      rr,
      x + math.cos(a) * r * 0.4,
      y + math.sin(a) * r * 0.4,
      x + math.cos(a + rr.range(-0.6, 0.6)) * (r + 0.6),
      y + math.sin(a + rr.range(-0.6, 0.6)) * (r + 0.6),
      jag: 0.45,
      forks: 0,
    ).first.pts;
    for (var j = 1; j < pts.length; j++) {
      final (ax, ay) = pts[j - 1];
      final (bx, by) = pts[j];
      p.lineShaded(ax, ay, bx, by, color: (u) => u < 0.6 ? kWhite : c[6]);
    }
  }
  p.px(x - r * 0.5, y - r * 0.62, kWhite);
}

void _drawRingAt(
  Painter p,
  List<int> col,
  double x,
  double y,
  double rr,
  double sy,
  double rot,
  double q,
) {
  final n = (rr * tau * 1.4).ceil();
  final c = math.cos(rot);
  final s = math.sin(rot);
  final ringCol = q > 0.85 ? kWhite : (q > 0.55 ? col[6] : col[5]);
  final a = math.min(1.0, q * 3.0);
  for (var j = 0; j < n; j++) {
    final g = (j / n) * tau;
    final lx = math.cos(g) * rr;
    final ly = math.sin(g) * rr * sy;
    final px = x + lx * c - ly * s;
    final py = y + lx * s + ly * c;
    if (py > -0.5) continue;
    p.dot(px, py, ringCol, a);
    if (j % 10 == 0) p.glow(px, py, 5, col[5], 0.12 * a);
  }
}

final PureEffect spellChargeEffect = PureEffect(
  meta: const EffectMeta(
    id: 'arcane/spell-charge',
    name: 'Spell charge',
    desc:
        'Energy gathers in the caster\'s hand: streaks and motes spiral in, rings collapse into a swelling orb that crackles with arcs, ready to fire.',
    category: 'arcane',
    tags: ['arcane', 'charge', 'spell', 'orb', 'cast', 'magic', 'loop'],
    size: (120, 86),
    origin: (44, 80),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'palette': Pal.arcane, 'seed': 5},
  ),
  act: ActSpec(
    poses: [
      PoseKey(-0.46, kReady.copyWith(x: -3)),
      PoseKey(-0.12, _hold.copyWith(crouch: 3)),
      const PoseKey(0.0, _hold),
      PoseKey(0.4, _hold.copyWith(crouch: 5)),
      PoseKey(0.8, _hold.copyWith(lean: 3)),
      PoseKey(1.2, _hold.copyWith(crouch: 5)),
      const PoseKey(1.6, _hold),
    ],
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _d;
    final s = o.seed;
    final f = (t * 30.0).floor();
    final since = _sinceLast(t);
    final swell = math.exp(-math.pow(since / 0.07, 2)) +
        0.5 * math.exp(-math.pow(since / 0.18, 2));
    final r = 6.1 + 0.5 * math.sin(ph * tau * 4.0) + 1.4 * swell;
    final jit = swell > 0.4 ? (f.isOdd ? 1.0 : -1.0) : 0.0;
    final x = _hx + jit;
    const y = _hy;

    cycle(t, _d, 110, s * 3 + 1, (g) => g.range(0.2, 0.34), (age, life, rr, _) {
      final a0 = rr.range(2.8, 5.75);
      final d0 = rr.range(20.0, 52.0);
      final spin = rr.range(0.6, 1.3);
      Point2 pos(double q) {
        final a = a0 + spin * q * q;
        final d = d0 * (1.0 - q * q) + r;
        return (_hx + math.cos(a) * d, _hy + math.sin(a) * d * 0.92);
      }

      final q = age / life;
      final (px, py) = pos(q);
      final (qx, qy) = pos(math.min(1.0, q + 0.02));
      streak(
        p,
        px,
        py,
        (qx - px) / (0.02 * life),
        (qy - py) / (0.02 * life),
        rr.chance(0.55) ? c[6] : c[5],
        math.min(1.0, q * 4.0) * (1.0 - smooth(0.9, 1.0, q)),
        7.0,
        0.4 * (1.0 - smooth(0.6, 0.9, q)),
      );
    });

    cycle(t, _d, 56, s * 3 + 2, (g) => g.range(0.4, 0.7), (age, life, rr, _) {
      final a0 = rr.range(2.6, 5.2);
      final d0 = rr.range(12.0, 32.0);
      final spin = rr.range(1.0, 2.2);
      final size = rr.range(0.6, 1.0);
      Point2 pos(double q) {
        final a = a0 + spin * q;
        final d = d0 * (1.0 - Ease.inQuad(q)) + r;
        return (_hx + math.cos(a) * d, _hy + math.sin(a) * d);
      }

      final q = age / life;
      final (px, py) = pos(q);
      final (qx, qy) = pos(math.min(1.0, q + 0.02));
      mote(
        p,
        px,
        py,
        (qx - px) / (0.02 * life),
        (qy - py) / (0.02 * life),
        rr.pick([c[5], c[6], c[6], kWhite]),
        size,
        math.min(1.0, q * 3.0) * (q > 0.9 ? (1.0 - q) / 0.1 : 1.0),
        0.3 * (1.0 - smooth(0.55, 0.85, q)),
      );
    });

    for (var k = 0; k < _rings; k++) {
      for (final off in const [-_d, 0.0]) {
        final q = (t - (k * _d) / _rings - off) / _rt;
        if (q < 0.0 || q >= 1.0) continue;
        final rr = r + 1.5 + 22.0 * (1.0 - Ease.inQuad(q));
        final shape = _ringShapes[k];
        _drawRingAt(p, c, x, y, rr, shape.$1, shape.$2, q);
      }
    }

    _drawOrb(p, c, x, y, r, t, ph);

    final w = f ~/ 2;
    final rw = rng(s, w, 3);
    final n = (rw.next() < 0.6 ? 1 : 0) + (swell > 0.3 ? 1 : 0);
    final fresh = f.isEven ? 0.8 : 0.4;
    for (var i = 0; i < n; i++) {
      final a = rw.range(0.0, tau);
      final l = rw.range(5.0, 10.0) * (1.0 + swell * 0.4);
      final a1 = a + rw.range(-0.5, 0.5);
      final x0 = x + math.cos(a) * (r + 0.5);
      final y0 = y + math.sin(a) * (r + 0.5);
      final x1 = x0 + math.cos(a1) * l;
      final y1 = math.min(-2.0, y0 + math.sin(a1) * l);
      drawArc(
        p,
        arcaneArc(rw, x0, y0, x1, y1,
            jag: 0.35, forks: rw.next() < 0.5 ? 1 : 0),
        core: kWhite,
        body: c[5],
        halo: c[3],
        glow: c[5],
        k: fresh,
        glowK: 0.3,
      );
    }

    cycleFixed(t, _d, 7, s * 3 + 4, 0.22, (age, life, rr, _) {
      final a = rr.range(0.0, tau);
      final d = rr.range(r + 5.0, r + 15.0);
      final k = math.sin((age / life) * math.pi);
      sparkle(p, x + math.cos(a) * d, y + math.sin(a) * d * 0.9,
          1.0 + 2.5 * k, c[6], c[4], 0.4 * k);
    });
    if (since < 0.07) {
      sparkle(p, x, y, 4.0 + 6.0 * (1.0 - since / 0.07), c[6], c[5], 0.5);
    }

    final pulse = 0.85 + 0.15 * math.sin(ph * tau * 4.0) + 0.2 * swell;
    p.glow(x, y, 46, c[4], 0.26 * pulse);
    p.glowRing(x, y, r + 3.0, 8, c[5], 0.3 * pulse);
    p.glow(x, y, r, c[6], 0.12);
    p.glow(_hx, -1, 22, c[5], 0.16 * pulse);
  },
);
