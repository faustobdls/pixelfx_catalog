import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'projectiles_lib.dart';

const _head = ['..LL....', '..sLLL..', 'bbsSSSSW', '..dDDD..', '..DD....'];
const _fletch = [
  [
    'AAa.........',
    '.aAAa.......',
    '..aaAAa.....',
    'nkkkkkkkkkkk',
    '..cCCc......',
    '.cCCc.......',
    'CCc.........',
  ],
  [
    '.AAa........',
    '..aAAa......',
    '..aaAAAa....',
    'nkkkkkkkkkkk',
    '..cCCCc.....',
    '..cCCc......',
    '.CCc........',
  ],
  [
    'AAAa........',
    'aAAa........',
    '.aaAAa......',
    'nkkkkkkkkkkk',
    '..ccCc......',
    'cCCc........',
    'CCc.........',
  ],
];

const _arrowMeta = EffectMeta(
  id: 'projectiles/arrow',
  name: 'Arrow',
  desc:
      'An arrow in flight: a steel broadhead catching the light, a wooden shaft, fletching fluttering in the wind, streaks of air peeling off its head and swirling off its feathers.',
  category: 'projectiles',
  tags: ['projectile', 'arrow', 'bow', 'medieval', 'directional', 'loop'],
  size: (112, 32),
  origin: (92, 16),
  duration: 0.6,
  loop: true,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': ['#7a1f2c', '#b8323c', '#e8e2d6', '#ffffff'],
    'wood': ['#3a2414', '#6e4422', '#a8723c', '#d8a868'],
    'steel': ['#2e3648', '#5a6680', '#9aa6ba', '#dfe7f2'],
    'wind': '#b8c8e8',
    'seed': 3,
  },
);

final PixelEffect arrowEffect = PureEffect(
  meta: _arrowMeta,
  onDraw: (p, t, o) {
    final pl = fit(o.palette, 4);
    final w = fit(o.rampOpt('wood'), 4);
    final st = fit(o.rampOpt('steel'), 4);
    final wind = hex(o.strOpt('wind', '#b8c8e8'));
    final s = o.seed;
    const d = 0.6;
    final fr = (t * 30 + 1e-6).floor();
    final ph = t / d;
    final left = -_arrowMeta.origin.$1 + 2.0;
    const len = 36;

    beat(t, d, 9, s, (r) => r.range(0.14, 0.26), (age, life, r, _) {
      final k = age / life;
      final top = r.chance(0.5) ? -1 : 1;
      final from = r.chance(0.6) ? -3.0 : -len + 6.0;
      final x0 = from - age * r.range(160, 240);
      final sl = r.range(8, 16) * (0.5 + k);
      final y = 0.5 + top * (r.range(3, 5) + k * r.range(1, 2.5));
      if (x0 - sl < left) return;
      final c = k < 0.4 ? wind : mix(wind, hex('#2a2540'), (k - 0.4) * 1.2);
      p.lineShaded(
        x0,
        y,
        x0 - sl,
        y,
        color: (u) => (u < 0.25 && k < 0.4 ? mix(wind, kWhite, 0.5) : c),
        alpha: (u) => (u < 0.65 ? 1.0 : (1 - u) / 0.35),
      );
    });

    beat(t, d, 6, s + 3, (r) => r.range(0.15, 0.25), (age, life, r, _) {
      final k = age / life;
      final cx = -len - 2 - age * r.range(100, 150);
      final cy = 0.5 + r.sign() * r.range(2, 4);
      final a = age * 30 + r.range(0, tau);
      final rr = 1.2 + k * 1.5;
      if (cx < left + 4) return;
      for (var i = 0; i < 4; i++) {
        p.dot(
          cx + math.cos(a + i * 0.5) * rr,
          cy + math.sin(a + i * 0.5) * rr,
          wind,
          (1 - k) * (1 - i * 0.2),
        );
      }
    });

    p.line(-len + 11, 0, -7, 0, w[2]);
    for (var x = -len + 14; x < -8; x += 6) {
      p.px(x, 0, w[3]);
    }
    final pose = _fletch[(rand(fr, s) * 3).floor()];
    p.sprite(
      pose,
      {'a': pl[2], 'A': pl[3], 'c': pl[0], 'C': pl[1], 'k': w[1], 'n': w[0]},
      -len,
      -3,
    );
    p.sprite(
      _head,
      {'L': st[3], 's': st[2], 'S': st[2], 'd': st[0], 'D': st[1], 'b': w[0], 'W': kWhite},
      -7,
      -2,
    );
    final g = (ph * 2) % 1;
    if (g < 0.25) {
      sparkle(
        p,
        -5 + g * 16,
        -1,
        1 + (2 * math.sin((g / 0.25) * math.pi) + 0.5).floor().toDouble(),
        kWhite,
        st[3],
        0.25,
      );
    }
  },
);
