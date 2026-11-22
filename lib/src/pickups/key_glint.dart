// The hover, floor shadow and star glints follow Sprite Fusion's open-source pickup and sparkle
// (https://www.spritefusion.com/pixel-art-vfx/pickup), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'pickups_lib.dart';

const double _duration = 2.0;
const double _hover = 19.0;
const double _mid = 8.0;
const double _tip = 17.5;
const double _g0 = 0.18;
const double _g1 = 0.5;

final SpriteLayer _keyLayer = SpriteLayer(48, 40);

({double y, double a}) _pose(double ph) => (
      y: -_hover - 1.6 * math.sin(ph * tau),
      a: 0.42 + 0.11 * math.sin(ph * tau + 0.9),
    );

(double, double) _toWorld(
  double u,
  double v,
  double cx,
  double cy,
  double a,
) =>
    (
      cx + (u - _mid) * math.cos(a) - v * math.sin(a),
      cy + (u - _mid) * math.sin(a) + v * math.cos(a),
    );

int _part(double u, double v) {
  final rb = hypot(u, v);
  if (rb <= 4.6 && rb >= 2.1) return 1;
  if (u >= 4.3 && u <= 6.0 && v.abs() <= 1.9) return 2;
  if (u >= 6.0 && u <= _tip && v.abs() <= 1.0) return 3;
  if (u >= 12.6 &&
      u <= _tip - 0.3 &&
      v > 1.0 &&
      v <= 4.6 &&
      !(u > 14.3 && u < 15.4 && v > 2.7)) {
    return 4;
  }
  return 0;
}

void _drawKey(
  Painter p,
  List<int> c,
  double cx,
  double cy,
  double a,
  double gu,
) {
  final ca = math.cos(a);
  final sa = math.sin(a);
  final fx = cx.floor();
  final fy = cy.floor();
  _keyLayer.begin(fx - 24, fy - 20);
  _keyLayer.fill(fx - 24, fy - 20, fx + 23, fy + 19, (px, py) {
    final dx = px - cx;
    final dy = py - cy;
    final u = dx * ca + dy * sa + _mid;
    final v = -dx * sa + dy * ca;
    final k = _part(u, v);
    if (k == 0) return 0;
    double ny;
    if (k == 1) {
      final rb = hypot(u, v);
      final out = rb > 3.4 ? 1.0 : -1.0;
      final wx = (u / rb) * out;
      final wy = (v / rb) * out;
      ny = -(((wx * ca - wy * sa) * -0.6) + (wx * sa + wy * ca) * -0.8);
    } else if (v < -0.35) {
      ny = 0.8;
    } else if (v > 0.35 && k != 4) {
      ny = -0.6;
    } else if (k == 4) {
      ny = v > 3.6 ? -0.5 : 0.1;
    } else {
      ny = 0.2;
    }
    var col = ny > 0.55 ? 6 : (ny > 0.15 ? 4 : (ny > -0.3 ? 3 : 2));
    if (k == 2) col = math.min(7, col + 1);
    final g = (u + v * 0.45 - gu).abs();
    if (g < 0.8) return kWhite;
    if (g < 2.0) col = math.min(7, col + 2);
    return c[col];
  });
  _keyLayer.outline(c[0]).draw(p);
}

final PureEffect keyGlintEffect = PureEffect(
  meta: const EffectMeta(
    id: 'pickups/key-glint',
    name: 'Key glint',
    desc:
        'An ornate silver key hovering and rocking; a glint runs from its bow down the shaft to the teeth and bursts off the tip as falling sparks.',
    category: 'pickups',
    tags: ['pickup', 'key', 'unlock', 'item', 'loop'],
    size: (72, 60),
    origin: (36, 54),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#0e1018',
        '#222838',
        '#3c4660',
        '#5e6d8e',
        '#8c9cbc',
        '#bccae2',
        '#e6eeff',
        '#ffffff',
      ],
      'seed': 7,
    },
  ),
  onDrawBack: (p, t, o) {
    final (:y, a: _) = _pose(t / _duration);
    blobShadow(p, 0.0, 10.0, 0.8 - (-y - _hover + 1.6) * 0.06);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final seed = o.seed;
    final ph = t / _duration;
    final (:y, :a) = _pose(ph);
    final q = (ph - _g0) / (_g1 - _g0);
    final gu =
        q > 0.0 && q < 1.0 ? -5.0 + (_tip + 7.0) * Ease.inOutSine(q) : -100.0;
    final (bx, by) = _toWorld(0.0, 0.0, 0.0, y, a);
    final (ex, ey) = _toWorld(_tip, 0.0, 0.0, y, a);
    p.glow(0.0, y, 24.0, c[4], 0.3);
    p.glowLine(bx, by, ex, ey, 7.0, c[5], 0.16);
    _drawKey(p, c, 0.0, y, a, gu);
    for (var i = 0; i < 4; i++) {
      const life = 0.4;
      final age = (((t - ((i + 0.6) / 4.0) * _duration) % _duration) +
              _duration) %
          _duration;
      if (age > life) continue;
      final an = rand(i, seed, 8) * tau;
      final d = 9.0 + rand(i, seed, 9) * 6.0;
      final k = math.sin((age / life) * math.pi);
      glint(
        p,
        math.cos(an) * d,
        y + math.sin(an) * d * 0.8 - age * 6.0,
        (1.8 * k + 0.5).floorToDouble(),
        i % 2 != 0 ? c[6] : kWhite,
        0.35 * k,
      );
    }
    if (gu > -6.0) {
      final (gx, gy) = _toWorld(clamp(gu, 0.0, _tip), 0.0, 0.0, y, a);
      p.glow(gx, gy, 10.0, c[6], 0.45 * math.sin(q * math.pi));
    }
    final (tx, ty) = _toWorld(_tip, 0.0, 0.0, y, a);
    final at = (ph - _g1 + 0.02) * _duration;
    if (at > 0.0 && at < 0.3) {
      glint(
        p,
        tx,
        ty,
        4.5 * (1.0 - at / 0.3),
        c[6],
        0.6 * (1.0 - at / 0.3),
      );
    }
    for (var i = 0; i < 9; i++) {
      final life = 0.32 + rand(i, seed, 4) * 0.3;
      final age = at - rand(i, seed, 5) * 0.05;
      if (age < 0.0 || age > life) continue;
      final sp = 25.0 + rand(i, seed, 1) * 45.0;
      final an = a + (rand(i, seed, 2) - 0.5) * 2.2;
      final vx0 = math.cos(an) * sp;
      final vy0 = math.sin(an) * sp - 25.0;
      final (x, yy) = fly(tx, ty, vx0, vy0, age, 380.0, 2.5);
      final (vx, vy) = flyV(vx0, vy0, age, 380.0, 2.5);
      if (yy > -0.5) continue;
      final s = hypot(vx, vy);
      final ss = s == 0.0 ? 1.0 : s;
      final l2 = math.min(4.0, 1.0 + ss * 0.03);
      final k = 1.0 - age / life;
      p.lineShaded(
        x - (vx / ss) * l2,
        yy - (vy / ss) * l2,
        x,
        yy,
        color: (u) => u > 0.6 ? kWhite : c[5],
        alpha: (_) => k * 1.6,
      );
      p.glow(x, yy, 3.0, c[5], 0.4 * k);
    }
  },
);
