import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const double _cy = -16;

// an original coin: a rim, a lit face, a raised mark in the middle
const List<String> _coinSprite = [
  '..oooo..',
  '.ohhlmo.',
  'ohlmmmdo',
  'ohmdhmdo',
  'olmdhmdo',
  'olmmmmdo',
  '.oddddo.',
  '..oooo..',
];

// lying flat on the floor, seen from the side
const List<String> _flatSprite = ['.lhhhl.', 'olmmmdo', '.odddo.'];

final PixelEffect coinDropEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'spawn/coin-drop',
    name: 'Coin drop',
    desc:
        'An enemy goes up in a soft poof and gold coins spin out of it, bounce with a glint on each hit, settle on the floor, twinkle, and wink out one by one.',
    category: 'spawn',
    tags: [
      'spawn',
      'death',
      'loot',
      'coins',
      'gold',
      'drop',
      'pickup',
      'ground',
      'one-shot',
    ],
    size: (160, 88),
    origin: (80, 78),
    duration: 3,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#2a1606',
        '#5c3208',
        '#9a5a0c',
        '#d48c14',
        '#f5b82a',
        '#ffe066',
        '#fff6c4',
        '#ffffff',
      ],
      'smoke': ['#3a3450', '#6c6688', '#a8a2c0', '#dcd8ea'],
      'coins': 7,
      'seed': 23,
    },
  ),
  onCreate: (o) => _CoinDropSim(o),
);

class _Coin {
  _Coin({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.ph,
    required this.w,
    required this.out,
    required this.glint,
    required this.born,
  });

  double x;
  double y;
  double vx;
  double vy;
  double ph;
  double w;
  bool rest = false;
  bool gone = false;
  int hits = 0;
  final double out;
  final double glint;
  final double born;
  double restAt = 0;
}

class _Ball {
  _Ball({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.r,
    required this.life,
    required this.max,
  });

  double x;
  double y;
  double vx;
  double vy;
  final double r;
  double life;
  final double max;
}

class _CoinDropSim extends BaseEffectSim {
  _CoinDropSim(Map<String, Object?> o) {
    cRamp = fit(o.palette, 8);
    sm = fit(o.rampOpt('smoke'), 4);
    rng = Rng(o.seed);
    pal = {'o': cRamp[1], 'h': cRamp[6], 'l': cRamp[5], 'm': cRamp[4], 'd': cRamp[3]};
    ps = Particles(
      rng: rng,
      ground: (_) => 0,
      sparks: [kWhite, cRamp[6], cRamp[5], cRamp[3]],
    );
    lights = Lights();

    // the poof the enemy goes up in
    for (var i = 0; i < 10; i++) {
      final a = (i / 10) * tau + rng.range(-0.25, 0.25);
      final sp = rng.range(60, 100);
      final life = rng.range(0.55, 0.85);
      balls.add(
        _Ball(
          x: math.cos(a) * 2,
          y: _cy + math.sin(a) * 2,
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp * 0.7 - 10,
          r: rng.range(4, 6),
          life: life,
          max: life,
        ),
      );
    }

    // the coins: thrown up and out, each spinning at its own rate
    final n = o.intOpt('coins', 7);
    for (var i = 0; i < n; i++) {
      final u = n > 1 ? i / (n - 1) - 0.5 : 0.0;
      final a = -math.pi / 2 + u * 1.6 + rng.range(-0.1, 0.1);
      final sp = rng.range(230, 300);
      coins.add(
        _Coin(
          x: rng.range(-3, 3),
          y: _cy,
          vx: math.cos(a) * sp * 0.4,
          vy: math.sin(a) * sp,
          ph: rng.range(0, tau),
          w: rng.range(9, 15) * rng.sign(),
          out: 2.15 + i * 0.07 + rng.range(0, 0.1),
          glint: rng.range(1.2, 1.9),
          born: rng.range(0.04, 0.12),
        ),
      );
    }

    for (var i = 0; i < 8; i++) {
      final a = rng.range(0, tau);
      final sp = rng.range(50, 120);
      ps.spawn(
        P.star,
        0,
        _cy,
        math.cos(a) * sp,
        math.sin(a) * sp - 20,
        rng.range(0.3, 0.6),
        rng.pick([kWhite, cRamp[6], cRamp[5]]),
        rng.range(0.8, 1.8),
      );
    }

    lights.add(0, _cy, 44, cRamp[4], 0.7, 0.4);
    lights.add(0, _cy, 20, kWhite, 0.7, 0.1);
  }

  late final List<int> cRamp;
  late final List<int> sm;
  late final Rng rng;
  late final Map<String, int> pal;
  late final Particles ps;
  late final Lights lights;
  final List<_Coin> coins = [];
  final List<_Ball> balls = [];
  double t = 0;

  void _drawCoin(Painter p, double x, double y, double ph) {
    final c = math.cos(ph);
    final sx = c.abs();
    if (sx < 0.28) {
      for (var dy = -3; dy <= 3; dy++) {
        p.px(
          x,
          y + dy,
          dy.abs() == 3 ? cRamp[1] : (dy < 0 ? cRamp[6] : cRamp[5]),
        );
      }
      if (sx > 0.12) {
        for (var dy = -2; dy <= 2; dy++) {
          p.px(x + (c > 0 ? 1 : -1), y + dy, cRamp[3]);
        }
      }
      return;
    }
    final half = 4 * sx;
    for (var px = (x - half).floor(); px < (x + half).ceil(); px++) {
      var col = ((px + 0.5 - x) / sx + 4).floor();
      if (col < 0 || col > 7) continue;
      if (c < 0) col = 7 - col;
      for (var row = 0; row < 8; row++) {
        final ch = _coinSprite[row][col];
        if (ch != '.') {
          p.px(px, (y - 4 + row + 0.5).floor(), pal[ch]!);
        }
      }
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    for (var i = balls.length - 1; i >= 0; i--) {
      final b = balls[i];
      b.life -= dt;
      if (b.life <= 0) {
        balls.removeAt(i);
        continue;
      }
      b.vx -= b.vx * 7 * dt;
      b.vy -= b.vy * 7 * dt + 26 * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
    }
    for (final c in coins) {
      if (!c.gone && t >= c.out) {
        c.gone = true;
        for (var j = 0; j < 5; j++) {
          final a = rng.range(-math.pi, 0);
          final sp = rng.range(25, 60);
          ps.spawn(
            P.star,
            c.x,
            -3,
            math.cos(a) * sp,
            math.sin(a) * sp,
            rng.range(0.3, 0.55),
            rng.pick([kWhite, cRamp[6], cRamp[5]]),
            rng.range(0.7, 1.4),
          );
        }
        lights.add(c.x, -3, 14, cRamp[5], 0.6, 0.2);
      }
      if (t < c.born || t > c.out || c.rest) continue;
      c.vy += 820 * dt;
      c.vx -= c.vx * 0.4 * dt;
      c.x += c.vx * dt;
      c.y += c.vy * dt;
      c.ph += c.w * dt;
      if (c.y >= -1.5 && c.vy > 0) {
        c.y = -1.5;
        c.hits++;
        ps.spawn(P.star, c.x, -3, 0, -8, 0.25, kWhite, c.hits == 1 ? 2.2 : 1.4);
        for (var j = 0; j < 2; j++) {
          ps.spawn(
            P.dust,
            c.x + rng.range(-1, 1),
            -0.5,
            rng.sign() * rng.range(8, 24),
            -rng.range(2, 8),
            rng.range(0.25, 0.45),
            sm[1],
            rng.range(1, 1.8),
          );
        }
        lights.add(c.x, -3, 12, cRamp[5], 0.5, 0.15);
        if (c.vy > 110) {
          c.vy *= -0.45;
          c.vx *= 0.7;
          c.w = c.w * 0.8 + rng.range(-2, 2);
        } else {
          c.rest = true;
          c.vx = 0;
          c.vy = 0;
          c.restAt = t;
        }
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    for (final c in coins) {
      if (c.rest && t < c.out) {
        p.glow(c.x, -1, 7, cRamp[4], 0.18);
      }
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    for (var layer = 0; layer < 3; layer++) {
      for (final b in balls) {
        final age = b.max - b.life;
        final k = b.life / b.max;
        final r =
            b.r *
            (0.6 + 0.6 * Ease.outCubic(clamp(age / 0.2))) *
            (k < 0.35 ? k / 0.35 : 1.0);
        if (r < 0.6) continue;
        if (layer == 0) {
          p.disc(b.x + r * 0.15, b.y + r * 0.2, r, sm[1], 0.8);
        } else if (layer == 1) {
          p.disc(
            b.x - r * 0.06,
            b.y - r * 0.08,
            r * 0.86,
            b.y > _cy + 2 ? sm[1] : sm[2],
            0.85,
          );
        } else if (b.y < _cy + 2) {
          p.disc(b.x - r * 0.28, b.y - r * 0.34, r * 0.4, sm[3], 0.85);
        }
      }
    }
    if (t < 0.07) {
      final k = t / 0.07;
      p.circle(0, _cy, 8 + 2 * k, cRamp[6]);
      p.circle(0, _cy, 6 + 2 * k, kWhite);
      flare(p, 0, _cy, 16 * (1 - k * 0.5), 1 - k, cRamp);
    }
    for (final c in coins) {
      if (t < c.born || t > c.out + 0.12) continue;
      if (t > c.out) {
        final k = (t - c.out) / 0.12;
        sparkle(
          p,
          c.x,
          -2.0,
          (5 * (1 - k) + 0.5).floorToDouble(),
          kWhite,
          cRamp[5],
          0.5,
        );
        p.ring(c.x, -3, 2 + 5 * Ease.outCubic(k), 1, cRamp[6], 1.1 - k);
        continue;
      }
      if (c.rest) {
        p.sprite(_flatSprite, pal, (c.x + 0.5).floor() - 3, -3);
        p.glow(c.x, -2, 6, cRamp[5], 0.25);
        final g = ((t - c.restAt + c.glint) % 0.95) / 0.95;
        if (g < 0.2) {
          sparkle(
            p,
            c.x - 1,
            -3.0,
            (3 * math.sin((g / 0.2) * math.pi) + 0.5).floorToDouble(),
            kWhite,
            cRamp[5],
            0.4,
          );
        }
      } else {
        _drawCoin(p, c.x, c.y, c.ph);
        p.glow(c.x, c.y, 8, cRamp[4], 0.3);
        if (math.cos(c.ph).abs() > 0.96) {
          p.px(c.x - 1, c.y - 2, kWhite);
        }
      }
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}
