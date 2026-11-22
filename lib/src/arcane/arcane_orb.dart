// The orb (a glassy bubble that thickens towards its rim, a hot core, a double rim, a highlight arc and spot,
// motes orbiting in front and behind) is adapted from Sprite Fusion's open-source energy orb
// (https://www.spritefusion.com/pixel-art-vfx/energy), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'arcane_lib.dart';

const double _d = 2.4;
const double _rad = 17.0;
const double _y0 = -52.0;

class _RingSpec {
  final double r;
  final double sy;
  final double rot;
  final int beads;
  final int turn;
  final int c;

  const _RingSpec({
    required this.r,
    required this.sy,
    required this.rot,
    required this.beads,
    required this.turn,
    required this.c,
  });
}

const List<_RingSpec> _rings = [
  _RingSpec(r: 31, sy: 0.24, rot: 0.36, beads: 3, turn: 2, c: 0),
  _RingSpec(r: 27, sy: 0.3, rot: -0.55, beads: 2, turn: -3, c: 1),
];

({double ph, double cx, double cy}) _setup(double t) {
  final ph = t / _d;
  return (ph: ph, cx: 0.0, cy: _y0 + math.sin(ph * tau) * 2.0);
}

void _drawRing(
  Painter p,
  List<int> c,
  ({double ph, double cx, double cy}) s,
  _RingSpec ring,
  bool near,
) {
  final ph = s.ph;
  final cx = s.cx;
  final cy = s.cy;
  final rot = ring.rot + 0.12 * math.sin(ph * tau + ring.c);
  final cr = math.cos(rot);
  final sr = math.sin(rot);
  final n = (ring.r * tau * 1.5).ceil();

  Point2 pos(double g) {
    final lx = math.cos(g) * ring.r;
    final ly = math.sin(g) * ring.r * ring.sy;
    return (cx + lx * cr - ly * sr, cy + lx * sr + ly * cr);
  }

  for (var j = 0; j < n; j++) {
    final g = (j / n) * tau;
    final z = math.sin(g);
    if ((z > 0.0) != near) continue;
    final (x, y) = pos(g);
    p.dot(x, y, near ? c[5] : c[4], near ? 0.7 : 0.4);
  }
  final turnSign = ring.turn.sign;
  for (var b = 0; b < ring.beads; b++) {
    final g = ph * tau * ring.turn + (b * tau) / ring.beads;
    for (var k = 0; k < 7; k++) {
      final gg = g - turnSign * k * 0.07;
      final z = math.sin(gg);
      if ((z > 0.0) != near) continue;
      final (x, y) = pos(gg);
      p.dot(
        x,
        y,
        k == 0
            ? kWhite
            : k < 3
                ? c[6]
                : c[5],
        k < 4 ? 1.0 : 1.0 - (k - 3) / 4.0,
      );
      if (k == 0) {
        p.glow(x, y, near ? 7 : 5, c[6], near ? 0.5 : 0.25);
      }
    }
  }
}

void _drawOrb(
  Painter p,
  List<int> c,
  ({double ph, double cx, double cy}) s,
) {
  final ph = s.ph;
  final cx = s.cx;
  final cy = s.cy;

  p.discShaded(
    cx,
    cy,
    _rad,
    color: (d, _) => d > 0.82 ? c[2] : c[1],
    alpha: (d, _) => 0.32 + 0.5 * d * d,
  );

  for (final arm in const [
    (0.0, true),
    (math.pi, true),
    (math.pi / 2.0, false),
    ((3.0 * math.pi) / 2.0, false),
  ]) {
    final s0 = arm.$1;
    final main = arm.$2;
    for (var u = 0.08; u <= 0.85; u += 0.012) {
      final a = ph * tau * 2.0 + s0 + u * 3.4;
      final r = u * _rad * 0.92;
      final x = cx + math.cos(a) * r;
      final y = cy + math.sin(a) * r;
      final fade = u < 0.6 ? 1.0 : 1.0 - (u - 0.6) / 0.25;
      if (!main) {
        p.dot(x, y, c[4], fade * 0.8);
        continue;
      }
      final b = a - 0.16;
      final xb = cx + math.cos(b) * r;
      final yb = cy + math.sin(b) * r;
      p.dot(xb, yb, u < 0.4 ? c[6] : c[5], fade);
      p.dot(
        x,
        y,
        u < 0.3
            ? kWhite
            : u < 0.55
                ? c[6]
                : c[5],
        fade,
      );
    }
  }

  final pulse = 0.85 + 0.15 * math.sin(ph * tau * 3.0);
  p.circle(cx, cy, 3.6 * pulse + 1.0, c[5]);
  p.circle(cx, cy, 2.8 * pulse, c[6]);
  p.circle(cx, cy, 1.7 * pulse, kWhite);

  p.ring(cx, cy, _rad + 0.4, 1, c[5]);
  p.ring(cx, cy, _rad + 1.3, 1, c[2], 0.8);
  for (var a = 3.5; a < 4.7; a += 0.03) {
    p.dot(
      cx + math.cos(a) * (_rad - 2.4),
      cy + math.sin(a) * (_rad - 2.4),
      a > 3.85 && a < 4.35 ? kWhite : c[6],
    );
  }
  p.circle(cx - _rad * 0.42, cy - _rad * 0.5, 1.3, kWhite);
  p.dot(cx + _rad * 0.52, cy + _rad * 0.55, c[6]);
  p.glow(cx, cy, 20, c[6], 0.26 * pulse);
  p.glowRing(cx, cy, _rad, 6, c[5], 0.25);
}

void _drawMotes(
  Painter p,
  List<int> c,
  ({double ph, double cx, double cy}) s,
  int seed,
  bool near,
) {
  final ph = s.ph;
  final cx = s.cx;
  final cy = s.cy;
  for (var i = 0; i < 8; i++) {
    final a = ((i * 2.4 + seed) % tau) +
        ph * tau * (i.isOdd ? 1 : -1) * (1 + (i % 3));
    final rr = _rad + 5.0 + ((i * 0.37) % 1.0) * 12.0;
    final tilt = (((i * 0.71) % 1.0) - 0.5) * 1.4;
    final x0 = math.cos(a) * rr;
    final z = math.sin(a);
    if ((z > 0.0) != near) continue;
    final x = cx + x0 * math.cos(tilt);
    final y = cy + x0 * math.sin(tilt) + z * rr * 0.28;
    final dir = i.isOdd ? 1.0 : -1.0;
    p.dot(x, y, near ? kWhite : c[5]);
    p.dot(x - dir, y, near ? c[6] : c[4], near ? 1.0 : 0.6);
    if (near) {
      p.dot(x - 2.0 * dir, y, c[4], 0.6);
      p.glow(x, y, 5, c[6], 0.35);
    }
  }
  if (!near) return;
  cycle(ph * _d, _d, 10, seed * 3 + 1, (g) => g.range(0.6, 1.0),
      (age, life, r, _) {
    final a = r.range(0.0, tau);
    final q = age / life;
    final d = _rad + 1.0 + q * r.range(8.0, 18.0);
    final x = cx + math.cos(a) * d;
    final y = cy + math.sin(a) * d - q * 10.0;
    mote(p, x, y, math.cos(a) * 25.0, math.sin(a) * 25.0 - 12.0,
        r.chance(0.5) ? c[6] : c[5], 0.6, 1.0 - q, 0.3);
  });
}

final PureEffect arcaneOrbEffect = PureEffect(
  meta: const EffectMeta(
    id: 'arcane/arcane-orb',
    name: 'Arcane orb',
    desc:
        'A floating orb of smoky violet glass with a swirl turning round a white-hot heart, two tilted rings of light orbiting behind and in front.',
    category: 'arcane',
    tags: ['arcane', 'orb', 'sphere', 'magic', 'floating', 'loop'],
    size: (136, 112),
    origin: (68, 104),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {'palette': Pal.arcane, 'seed': 6},
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final s = _setup(t);
    final lift = (s.cy - _y0) / 2.0;
    p.glow(0, -1, 36, c[4], 0.26 - 0.04 * lift);
    for (var x = -20; x <= 20; x++) {
      final u = (x + 0.5).abs() / 20.0;
      p.dot(
        x.toDouble(),
        0,
        u < 0.3 ? c[6] : c[5],
        (1.1 - u) * (0.9 - 0.15 * lift),
      );
    }
    p.glow(s.cx, s.cy, 60, c[4], 0.36);
    for (final ring in _rings) {
      _drawRing(p, c, s, ring, false);
    }
    _drawMotes(p, c, s, o.seed, false);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final s = _setup(t);
    _drawOrb(p, c, s);
    for (final ring in _rings) {
      _drawRing(p, c, s, ring, true);
    }
    _drawMotes(p, c, s, o.seed, true);
    sparkle(
      p,
      s.cx - _rad * 0.42,
      s.cy - _rad * 0.5,
      1.5 + math.max(0.0, math.sin(s.ph * tau * 2.0)) * 2.0,
      c[6],
      c[5],
      0.3,
    );
  },
);
