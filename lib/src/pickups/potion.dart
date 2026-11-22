// The bubbles (lit and shaded rims, a highlight, a dotted pop) follow Sprite Fusion's open-source bubbles
// (https://www.spritefusion.com/pixel-art-vfx/bubbles), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'pickups_lib.dart';

const double _duration = 2.4;
const double _rb = 7.0;
const double _hover = 17.0;
const double _neck = 2.0;
const double _lip = -12.0;
const double _corkTop = -16.0;

final int _ink = hex('#120d1a');
final int _glass = hex('#2a2236');
final List<int> _cork = [
  '#2a160c',
  '#4e2c16',
  '#7a4a26',
  '#a8703a',
  '#d09a5a',
].map(hex).toList();
final SpriteLayer _flaskLayer = SpriteLayer(40, 44);

({double y, double tilt}) _pose(double ph) => (
      y: -_hover - 1.4 * math.sin(ph * tau),
      tilt: 0.13 * math.sin(ph * tau + 0.4),
    );

double _surface(double x, double ph) =>
    -0.5 +
    0.17 * math.sin(ph * tau - 0.9) * x +
    0.45 * math.sin(x * 0.85 + ph * tau * 3.0);

void _flask(
  Painter p,
  List<int> c,
  double t,
  double ph,
  double cy,
  double tilt,
  int seed,
) {
  final ct = math.cos(tilt);
  final st = math.sin(tilt);
  final cyFloor = cy.floor();
  _flaskLayer.begin(-20, cyFloor - 22);
  _flaskLayer.fill(-20, cyFloor - 22, 19, cyFloor + 12, (px, py) {
    final wx = px;
    final wy = py - cy;
    final fx = wx * ct + wy * st;
    final fy = -wx * st + wy * ct;
    final d = hypot(fx, fy);
    if (fy < _lip - 0.5 && fy >= _corkTop && fx.abs() <= _neck + 0.2) {
      return _cork[
          fy < _corkTop + 1.0 ? 4 : (fx < -0.6 ? 3 : (fx > 1.0 ? 1 : 2))];
    }
    if (fy >= _lip - 0.5 && fy < _lip + 1.0 && fx.abs() <= _neck + 1.4) {
      return fx < 0.0 ? mix(kWhite, c[6], 0.4) : mix(_glass, c[5], 0.45);
    }
    final inNeck =
        fy >= _lip + 1.0 && fy < -_rb + 2.0 && fx.abs() <= _neck + 0.6;
    if (d > _rb && !inNeck) return 0;
    final wall = inNeck ? fx.abs() > _neck - 0.5 : d > _rb - 1.0;
    final s = _surface(wx, ph);
    final depth = wy - s;
    if (!wall && !inNeck && depth > 0.0) {
      final core = 1.0 - hypot(wx * 0.85, wy - 1.8) / _rb;
      if (depth < 0.9) return wx < -1.5 && wx > -4.5 ? kWhite : c[6];
      var k = core > 0.62 ? 5 : (core > 0.38 ? 4 : (core > 0.18 ? 3 : 2));
      if (depth < 1.9 && k < 5) k++;
      if (wx > 1.5 && wy > 2.0) k--;
      return c[clampInt(k, 2, 6)];
    }
    if (wall) {
      final lit = (-fx * 0.75 - fy * 0.66) / math.max(1.0, d);
      if (inNeck) {
        return fx < 0.0 ? mix(_glass, c[6], 0.55) : mix(_glass, c[5], 0.3);
      }
      if (lit > 0.82) return mix(kWhite, c[6], 0.3);
      if (lit > 0.3) return mix(_glass, c[6], 0.5);
      return depth > 0.0 ? c[3] : mix(_glass, c[5], 0.28);
    }
    return _glass;
  });
  _flaskLayer.outline(_ink).draw(p);
  for (var a = 3.45; a < 4.35; a += 0.04) {
    final lx = math.cos(a + tilt) * (_rb - 2.2);
    final ly = math.sin(a + tilt) * (_rb - 2.2);
    p.px(
      lx,
      cy + ly,
      a > 3.7 && a < 4.1 ? kWhite : mix(kWhite, c[6], 0.5),
    );
  }
  p.px(
    (2.0 * math.cos(tilt) + 3.0 * math.sin(tilt) + 0.5).floor(),
    (cy - 3.0 + 0.5).floor(),
    kWhite,
  );
  cycle(t, _duration, 10, seed, (g) => g.range(0.7, 1.3), (age, life, r, _) {
    final x0 = r.range(-4.0, 4.0);
    final r0 = r.range(0.6, 1.7);
    final vy = r.range(7.0, 13.0);
    final x = x0 +
        math.sin(age * r.range(5.0, 9.0) + r.range(0.0, tau)) * 0.7;
    final y = cy + 5.5 - vy * age;
    final ph2 = (t + age) / _duration;
    final top = cy + _surface(x, ph2);
    if (y > top + 0.8) {
      final rr = r0 * (0.7 + 0.5 * (age / life));
      if (hypot(x, y - cy) > _rb - 1.5) return;
      if (rr < 0.95) {
        p.px(x, y, c[6]);
      } else {
        p.px(x, y, c[3]);
        p.px(x + 1.0, y, c[6]);
        p.px(x, y - 1.0, kWhite);
        p.px(x + 1.0, y - 1.0, c[6]);
        if (rr > 1.4) {
          p.px(x - 1.0, y, c[5]);
          p.px(x, y + 1.0, c[4]);
        }
      }
      p.glow(x + 0.5, y, 3.0, c[6], 0.15);
    } else {
      final k = clamp((top + 0.8 - y) / 3.0);
      if (k >= 1.0) return;
      for (var a = math.pi; a < tau; a += 0.6) {
        p.dot(
          x + math.cos(a) * (1.0 + k * 2.0),
          top - 0.5 + math.sin(a) * (1.0 + k * 2.0) * 0.5,
          k < 0.5 ? kWhite : c[6],
          1.2 - k,
        );
      }
      p.dot(x - 1.0, top - 1.5 - k * 3.0, c[6], 1.0 - k);
      p.dot(x + 1.5, top - 2.0 - k * 4.0, kWhite, 1.0 - k);
    }
  });
}

final PureEffect potionEffect = PureEffect(
  meta: const EffectMeta(
    id: 'pickups/potion',
    name: 'Potion',
    desc:
        'A round glass flask of glowing brew rocks in the air: the brew sloshes behind the rock, bubbles rise and pop, light glows through the glass, wisps curl off the cork.',
    category: 'pickups',
    tags: ['pickup', 'potion', 'flask', 'brew', 'magic', 'loop'],
    size: (56, 72),
    origin: (28, 64),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#1a0516',
        '#3d0a33',
        '#701560',
        '#b0228f',
        '#f53cd1',
        '#ff86e6',
        '#ffd2f6',
        '#ffffff',
      ],
      'seed': 5,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _duration;
    final (:y, tilt: _) = _pose(ph);
    blobShadow(p, 0.0, 7.5, 0.8 - (-y - _hover + 1.4) * 0.06);
    pool(p, 0.0, 0.5, 18.0, 3.0, c[5], 0.3);
    cycle(t, _duration, 7, o.seed + 1, (g) => g.range(1.2, 1.8),
        (age, life, r, _) {
      final side = r.sign();
      final f = r.range(3.0, 4.5);
      final ph0 = r.range(0.0, tau);
      final vy = r.range(11.0, 16.0);
      final x0 = r.range(-1.0, 1.0);
      (double, double) at(double a) => (
            x0 + math.sin(a * f + ph0) * (0.8 + a * 3.2) * side,
            y + _corkTop - 1.0 - a * vy,
          );
      for (var i = 0; i < 9; i++) {
        final a = age - i * 0.04;
        if (a < 0.0) break;
        final (x, yy) = at(a);
        final k =
            (1.0 - a / life) * math.min(1.0, a / 0.15) * (1.0 - i / 9.0);
        p.dot(x, yy, i == 0 ? kWhite : (i < 3 ? c[6] : c[5]), k * 1.4);
        if (i == 0) p.glow(x, yy, 4.0, c[5], 0.3 * k);
      }
    });
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _duration;
    final (:y, :tilt) = _pose(ph);
    p.glow(0.0, y + 1.5, 26.0, c[4], 0.22);
    _flask(p, c, t, ph, y, tilt, o.seed);
    p.glow(0.0, y + 2.0, 10.0, c[5], 0.38 + 0.08 * math.sin(ph * tau * 2.0));
    final g = ((ph + 0.2) % 0.5) / 0.5;
    if (g < 0.16) {
      glint(
        p,
        -4.0,
        y - 4.0,
        2.6 * math.sin((g / 0.16) * math.pi),
        kWhite,
        0.4,
      );
    }
  },
);
