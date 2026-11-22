// The hover, floor shadow and glints follow Sprite Fusion's open-source pickup
// (https://www.spritefusion.com/pixel-art-vfx/pickup), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'pickups_lib.dart';

const double _duration = 1.2;
const double _hover = 18.0;
const double _w = 7.2;
const double _lub = 0.04;
const double _dub = 0.24;
const List<String> _mini = ['.a.a.', 'abbba', '.aba.', '..a..'];

final int _ink = hex('#12060c');
final SpriteLayer _heartLayer = SpriteLayer(40, 40);

double _beat(double ph, double at, double s) {
  final u = ph - at;
  if (u < 0.0 || u > 0.3) return 0.0;
  return s * math.exp(-u * 16.0) * math.cos(u * 34.0);
}

double _pulse(double ph) =>
    _beat(ph, _lub, 1.0) + _beat(ph, _dub, 0.55) + _beat(ph + 1.0, _lub, 1.0);

final PureEffect heartPickupEffect = PureEffect(
  meta: const EffectMeta(
    id: 'pickups/heart-pickup',
    name: 'Heart pickup',
    desc:
        'A plump glossy heart hovering over its shadow beats lub-dub: a big squash and stretch, a smaller echo, light and a thin ring pulsing out, tiny hearts drifting off.',
    category: 'pickups',
    tags: ['pickup', 'heart', 'health', 'life', 'loop'],
    size: (56, 60),
    origin: (28, 52),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#1a0408',
        '#4a0a14',
        '#8a1222',
        '#d02436',
        '#ff4a56',
        '#ff8a8e',
        '#ffd0cc',
        '#ffffff',
      ],
      'seed': 4,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _duration;
    final y = -_hover - 1.2 * math.sin(ph * tau);
    blobShadow(p, 0.0, 8.0 + 1.5 * _pulse(ph), 0.8);
    cycle(t, _duration, 4, o.seed, (_) => 0.95, (age, life, r, i) {
      final side = i % 2 != 0 ? 1 : -1;
      final k = age / life;
      final x = side * (r.range(2.0, 5.0) + age * r.range(9.0, 15.0)) +
          math.sin(age * 7.0 + r.range(0.0, tau)) * 1.5;
      final yy = y - 5.0 - age * r.range(14.0, 19.0);
      final a = math.min(1.0, age / 0.12) * (1.0 - k * k);
      p.sprite(
        _mini,
        {'a': k < 0.5 ? c[5] : c[4], 'b': k < 0.3 ? kWhite : c[6]},
        (x - 2.5 + 0.5).floor(),
        (yy - 2.0 + 0.5).floor(),
        a: a * 1.3,
      );
      p.glow(x, yy, 5.0, c[4], 0.3 * a);
    });
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _duration;
    final y = -_hover - 1.2 * math.sin(ph * tau);
    final b = _pulse(ph);
    final sx = 1.0 + 0.16 * b;
    final sy = 1.0 - 0.13 * b;
    final cy = (y + 0.5).floor();
    p.glow(
      0.0,
      cy.toDouble(),
      22.0 + 6.0 * math.max(0.0, b),
      c[4],
      0.26 + 0.3 * math.max(0.0, b),
    );
    _heartLayer.begin(-20, cy - 20);
    pillow(
      _heartLayer,
      -12.0,
      cy - 11.0,
      12.0,
      cy + 11.0,
      (x, yy) => heartSdf(x, yy, 0.0, cy.toDouble(), _w * sx, _w * sy),
      (lt, e, _, _) {
        if (lt > 0.92 && e > 1.2) return kWhite;
        return lt > 0.8
            ? c[6]
            : (lt > 0.6
                ? c[5]
                : (lt > 0.38 ? c[4] : (lt > 0.12 ? c[3] : c[2])));
      },
      bevel: 3.6,
    );
    _heartLayer.outline(_ink).draw(p);
    final u = (((ph - _lub) % 1.0) + 1.0) % 1.0;
    if (u < 0.28) {
      final k = u / 0.28;
      final r = 9.0 + 8.0 * (1.0 - math.pow(1.0 - k, 3).toDouble());
      p.ring(0.0, cy.toDouble(), r, 1.0, k < 0.2 ? c[6] : c[5], 0.85 * (1.0 - k));
      p.glowRing(0.0, cy.toDouble(), r, 4.0, c[4], 0.25 * (1.0 - k));
    }
    final g = (((ph - _lub - 0.08) % 0.5) + 0.5) % 0.5;
    if (g < 0.12) {
      glint(
        p,
        -3.5,
        cy - 4.0,
        2.6 * math.sin((g / 0.12) * math.pi),
        kWhite,
        0.45,
      );
    }
  },
);
