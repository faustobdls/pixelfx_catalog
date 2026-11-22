// The hover, floor shadow and twinkle glints follow Sprite Fusion's open-source pickup and sparkle
// (https://www.spritefusion.com/pixel-art-vfx/pickup), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'pickups_lib.dart';

const double _duration = 2.4;
const double _hover = 19.0;
final GemSolid _gem = brilliant(
  r: 7.5,
  crown: 3.2,
  table: 0.5,
  pavilion: 9.5,
  girdle: 0.9,
);
final SpriteLayer _gemLayer = SpriteLayer(32, 32);

({double y, double spin}) _pose(double t) => (
      y: -_hover - 1.8 * math.sin((t / _duration) * tau),
      spin: (t / _duration) * math.pi,
    );

final PureEffect gemSpinEffect = PureEffect(
  meta: const EffectMeta(
    id: 'pickups/gem-spin',
    name: 'Gem spin',
    desc:
        'A brilliant-cut ruby turning on its axis: real facets catch the light in turn, flashes roll over the crown, refracted light slides across the floor, sparkles wink round it.',
    category: 'pickups',
    tags: ['pickup', 'gem', 'jewel', 'treasure', 'ruby', 'loop'],
    size: (64, 64),
    origin: (32, 56),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#16040e',
        '#3e0a1e',
        '#760e2e',
        '#b8163c',
        '#ec3250',
        '#ff7482',
        '#ffc4c8',
        '#ffffff',
      ],
      'seed': 6,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final (:y, :spin) = _pose(t);
    final lift = (-y - _hover + 2.0) / 4.0;
    blobShadow(p, 0.0, 8.0 - lift * 1.5, 0.75 - lift * 0.2);
    for (var k = 0; k < 3; k++) {
      final a = spin * 4.0 + (k * tau) / 3.0;
      final x = math.sin(a) * 9.0;
      final k2 = 0.5 + 0.5 * math.cos(a);
      if (k2 < 0.15) continue;
      p.dot(x, 0.0, k2 > 0.7 ? c[6] : c[5], k2 * 1.2);
      p.dot(x + 1.0, 0.0, c[4], k2 * 0.8);
      p.dot(x - 1.0, 0.0, c[4], k2 * 0.6);
      p.glow(x + 0.5, 0.0, 6.0, c[5], 0.3 * k2);
    }
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final seed = o.seed;
    final (:y, :spin) = _pose(t);
    p.glowRing(0.0, y - 1.0, 5.0, 15.0, c[4], 0.34);
    p.glow(0.0, y, 26.0, c[3], 0.14);
    drawGem(_gemLayer, p, _gem, 0.0, y, spin, c, tilt: 0.22);
    final f = ((spin * 4.0) / tau) % 1.0;
    final fk = math.max(0.0, 1.0 - (f - 0.5).abs() / 0.08);
    if (fk > 0.0) {
      glint(p, -3.0, y - 3.0, 3.4 * Ease.outQuad(fk), c[6], 0.45 * fk);
    }
    for (var i = 0; i < 8; i++) {
      const life = 0.4;
      final age = (((t - (i / 8.0) * _duration - rand(i, seed, 3) * 0.1) %
                  _duration) +
              _duration) %
          _duration;
      if (age > life) continue;
      final a = rand(i, seed, 1) * tau + i * 2.4;
      final d = 10.0 + rand(i, seed, 2) * 7.0;
      final k = math.sin((age / life) * math.pi);
      glint(
        p,
        math.cos(a) * d,
        y + math.sin(a) * d * 0.8 - age * 6.0,
        (2.4 * k * (0.6 + 0.4 * rand(i, 9)) + 0.5).floorToDouble(),
        i % 3 != 0 ? c[6] : kWhite,
        0.4 * k,
      );
    }
  },
);
