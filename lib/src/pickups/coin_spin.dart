// The hover, floor shadow and glints follow Sprite Fusion's open-source pickup
// (https://www.spritefusion.com/pixel-art-vfx/pickup), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'pickups_lib.dart';

const double _duration = 1.6;
const double _r = 7.0;
const double _th = 3.0;
const double _hover = 17.0;
final SpriteLayer _coinLayer = SpriteLayer(32, 32);

final PureEffect coinSpinEffect = PureEffect(
  meta: const EffectMeta(
    id: 'pickups/coin-spin',
    name: 'Coin spin',
    desc:
        'A thick gold coin turning on its edge: an embossed star face, a reeded rim showing as it goes edge-on, a flash sweeping the face, bobbing over its shadow.',
    category: 'pickups',
    tags: ['pickup', 'coin', 'gold', 'money', 'loop'],
    size: (56, 56),
    origin: (28, 48),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#1e1206',
        '#4a2c08',
        '#86520c',
        '#c48412',
        '#f0b424',
        '#ffe066',
        '#fff6c4',
        '#ffffff',
      ],
      'seed': 3,
    },
  ),
  onDrawBack: (p, t, o) {
    final ph = t / _duration;
    final th = ph * tau;
    final y = -_hover - 2.0 * math.sin(ph * tau);
    blobShadow(
      p,
      0.0,
      2.5 + 4.5 * math.cos(th).abs() + 1.5 * math.sin(th).abs(),
      0.85 - (-y - _hover + 2.0) * 0.06,
    );
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final seed = o.seed;
    final ph = t / _duration;
    final th = ph * tau;
    final y = -_hover - 2.0 * math.sin(ph * tau);
    final facing = math.cos(th).abs();
    p.glow(0, y, 20, c[4], 0.3 + 0.12 * facing);
    final flash = coin3d(_coinLayer, p, 0.0, y, _r, _th, th, c);
    p.glow(-1, y - 1, 12, c[6], 0.35 * flash);
    if (flash > 0.3) {
      glint(p, -4.0, y - 4.0, 1.0 + 3.2 * flash, c[6], 0.5 * flash);
    }
    for (var i = 0; i < 5; i++) {
      const life = 0.35;
      final age = (((t - (i / 5.0) * _duration - rand(i, seed, 3) * 0.08) %
                  _duration) +
              _duration) %
          _duration;
      if (age > life) continue;
      final a = rand(i, seed, 1) * tau + i * 2.1;
      final d = 10.0 + rand(i, seed, 2) * 5.0;
      final k = math.sin((age / life) * math.pi);
      glint(
        p,
        math.cos(a) * d,
        y + math.sin(a) * d * 0.85 - age * 8.0,
        (2.0 * k).roundToDouble(),
        i % 2 != 0 ? c[6] : kWhite,
        0.35 * k,
      );
    }
  },
);
