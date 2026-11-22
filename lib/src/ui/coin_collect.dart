// The coin's pop (a white disc, then a ring and stars) and the trails of flying coins adapt Sprite Fusion's
// open-source pickup (https://www.spritefusion.com/pixel-art-vfx/pickup), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'ui_lib.dart';

const double _pop = 0.3;
const double _fly0 = 0.58;
const double _gap = 0.075;
const double _fly = 0.28;
const double _fold = 2.0;
const double _cy = -16.0;
const double _hx = 50.0;
const double _hy = -88.0;
const double _hw = 60.0;
const double _hh = 22.0;
const double _ix = _hx + 12.0;
const double _iy = _hy + 11.0;

final PanelColors _ink = PanelColors(
  outline: hex('#0d0a14'),
  rim: hex('#4a4060'),
  top: hex('#2a2338'),
  body: hex('#1e1929'),
  low: hex('#141019'),
);

final int _dustCol = hex('#5a4f6e');
final int _shadowCol = hex('#0d0a14');

void _drawCoin(
  Painter p,
  List<int> c,
  double x,
  double y,
  double r,
  double w, [
  bool white = false,
]) {
  final rx = math.max(0.7, r * w);
  final ry = r;
  p.shade(x - rx - 1.0, y - ry - 1.0, x + rx + 1.0, y + ry + 1.0,
      (px, py, _) {
    final u = (px - x) / rx;
    final v = (py - y) / ry;
    final d = hypot(u, v);
    if (d > 1.0) return null;
    final e = (1.0 - d) * math.min(rx * 1.6, ry);
    if (white) return e < 1.0 ? c[6] : kWhite;
    if (e < 1.0) return c[1];
    if (rx < 2.0) return v < -0.2 ? c[6] : (v < 0.4 ? c[4] : c[3]);
    if (e < 2.0) return u + v < -0.2 ? c[6] : c[3];
    if ((px - x).abs() < 0.55 && v.abs() < 0.5) return c[3];
    if (px - x >= 0.55 && px - x < 1.55 && v.abs() < 0.5) return c[7];
    final l = -(u * 0.6 + v * 0.8);
    return l > 0.4 ? c[7] : (l > 0.05 ? c[6] : (l > -0.35 ? c[5] : c[4]));
  });
}

class _FlyingCoin {
  double x = 0.0;
  double y = _cy;
  double vx;
  double vy;
  double ph;
  final double spin;
  int state = 0;
  final double t0;
  double fx = 0.0;
  double fy = 0.0;
  final List<(double, double)> trail = [];
  final double bob;

  _FlyingCoin({
    required this.vx,
    required this.vy,
    required this.ph,
    required this.spin,
    required this.t0,
    required this.bob,
  });
}

class _CoinCollectSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  late final List<_FlyingCoin> coins;
  static const double _end = 2.45 - 0.05;

  double t = 0.0;
  bool popped = false;
  late int count;
  double bump = 0.0;
  double flash = 0.0;

  _CoinCollectSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed) {
    final n = clampInt((o.numOpt('count', 10) + 0.5).floor(), 1, 12);
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [c[7], c[6], c[5], c[3]],
    );
    coins = List<_FlyingCoin>.generate(n, (i) {
      final s = (i / math.max(1, n - 1)) * 2.0 - 1.0;
      return _FlyingCoin(
        vx: s * r.range(55.0, 90.0) + r.range(-12.0, 12.0),
        vy: -r.range(170.0, 285.0),
        ph: r.range(0.0, tau),
        spin: r.range(9.0, 14.0) * r.sign(),
        t0: _fly0 + i * _gap,
        bob: r.range(0.0, tau),
      );
    });
    count = (o.numOpt('from', 12) + 0.5).floor();
  }

  @override
  void update(double dt, Map<String, Object?> options) {
    t += dt;
    if (!popped && t >= _pop) {
      popped = true;
      lights.add(0, _cy, 46, kWhite, 0.8, 0.14);
      lights.add(0, _cy, 48, c[5], 0.6, 0.5);
      for (var i = 0; i < 14; i++) {
        final an = (i / 14.0) * tau + r.range(-0.2, 0.2);
        final sp = r.range(80.0, 170.0);
        ps.spawn(
          P.spark,
          math.cos(an) * 3.0,
          _cy + math.sin(an) * 3.0,
          math.cos(an) * sp,
          math.sin(an) * sp - 30.0,
          r.range(0.15, 0.35),
        );
      }
      for (var i = 0; i < 4; i++) {
        ps.spawn(
          P.dust,
          r.range(-6.0, 6.0),
          -1.0,
          r.sign() * r.range(15.0, 40.0),
          -r.range(2.0, 8.0),
          r.range(0.3, 0.5),
          _dustCol,
          r.range(1.5, 2.5),
        );
      }
      for (var i = 0; i < 10; i++) {
        final an = (i / 10.0) * tau + r.range(-0.2, 0.2);
        final sp = r.range(70.0, 130.0);
        final down = math.sin(an) > 0.0 ? 0.25 : 1.0;
        ps.spawn(
          P.star,
          math.cos(an) * 6.0,
          _cy + math.sin(an) * 6.0,
          math.cos(an) * sp,
          math.sin(an) * sp * down,
          r.range(0.35, 0.6),
          r.pick([c[7], c[6], c[5]]),
          i % 3 != 0 ? 0.6 : r.range(1.2, 2.0),
        );
      }
    }

    for (final coin in coins) {
      if (!popped || coin.state == 3) continue;
      coin.ph += coin.spin * dt;
      if (coin.state < 2) {
        if (coin.state == 0) {
          coin.vy += 640.0 * dt;
          coin.vx -= coin.vx * 2.2 * dt;
          if (coin.vy > 0.0) coin.state = 1;
        } else {
          coin.vy -= coin.vy * 7.0 * dt;
          coin.vx -= coin.vx * 4.0 * dt;
        }
        coin.x += coin.vx * dt;
        coin.y += coin.vy * dt;
        if (t >= coin.t0) {
          coin.state = 2;
          coin.fx = coin.x;
          coin.fy = coin.y + math.sin(t * 6.0 + coin.bob) * 1.5;
        }
      }
      if (coin.state == 2) {
        final u = clamp((t - coin.t0) / _fly);
        final e = u * u;
        final mx = coin.fx + (_ix - coin.fx) * 0.35;
        final my = math.min(coin.fy, _iy) - 26.0;
        coin.x = (1.0 - e) * (1.0 - e) * coin.fx +
            2.0 * (1.0 - e) * e * mx +
            e * e * _ix;
        coin.y = (1.0 - e) * (1.0 - e) * coin.fy +
            2.0 * (1.0 - e) * e * my +
            e * e * _iy;
        coin.trail.insert(0, (coin.x, coin.y));
        if (coin.trail.length > 7) coin.trail.removeLast();
        if (r.chance(0.25)) {
          ps.spawn(
            P.star,
            coin.x + r.range(-2.0, 2.0),
            coin.y + r.range(-2.0, 2.0),
            r.range(-8.0, 8.0),
            r.range(-4.0, 10.0),
            r.range(0.2, 0.4),
            r.pick([c[7], c[6]]),
            0.6,
          );
        }
        if (u >= 1.0) {
          coin.state = 3;
          count++;
          bump = 1.0;
          flash = 1.0;
          lights.add(_ix, _iy, 26, c[5], 0.6, 0.25);
          for (var i = 0; i < 3; i++) {
            final an = r.range(0.0, tau);
            final sp = r.range(18.0, 40.0);
            ps.spawn(
              P.star,
              _ix + math.cos(an) * 5.0,
              _iy + math.sin(an) * 5.0,
              math.cos(an) * sp,
              math.sin(an) * sp,
              math.min(r.range(0.25, 0.45), _end - t),
              r.pick([c[7], c[6]]),
              i != 0 ? 0.6 : r.range(1.2, 1.8),
            );
          }
        }
      }
    }

    bump = math.max(0.0, bump - dt / 0.14);
    flash = math.max(0.0, flash - dt / 0.07);
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final k = (t - _pop) / 0.45;
    if (k > 0.0 && k < 1.0) {
      band(
        p,
        0,
        0,
        4.0 + 34.0 * Ease.outCubic(k),
        0.22,
        math.max(1.0, 3.0 * (1.0 - k)),
        1.15 - k,
        c,
        keep: (g) => math.sin(g) < 0.0,
      );
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final k = (t - _pop) / 0.45;
    if (k > 0.0 && k < 1.0) {
      band(
        p,
        0,
        0,
        4.0 + 34.0 * Ease.outCubic(k),
        0.22,
        math.max(1.0, 3.0 * (1.0 - k)),
        1.15 - k,
        c,
        keep: (g) => math.sin(g) >= 0.0,
      );
    }

    if (t < _pop + 0.02) {
      final y = _cy + math.sin(t * 9.0) * 1.5;
      final w = math.cos(t * 7.0).abs();
      p.ellipse(0, 0.5, 6.0 - 0.5 * math.sin(t * 9.0), 1.3, _shadowCol, 0.6);
      for (var i = 0; i < 2; i++) {
        final an = t * 7.0 + i * math.pi;
        final ox = math.cos(an) * 11.0;
        final oy = math.sin(an) * 3.0;
        if (math.sin(an) < 0.0) p.px(ox, y + oy, c[4]);
      }
      _drawCoin(p, c, 0.0, y, 7.0, math.max(0.12, w), t > _pop - 0.04);
      for (var i = 0; i < 2; i++) {
        final an = t * 7.0 + i * math.pi;
        final ox = math.cos(an) * 11.0;
        final oy = math.sin(an) * 3.0;
        if (math.sin(an) >= 0.0) {
          p.px(ox, y + oy, c[7]);
          p.glow(ox, y + oy, 4, c[5], 0.4);
        }
      }
      p.glow(0, y, 20, c[5], 0.45 + 0.4 * seg(t, _pop - 0.15, _pop));
      if (t > 0.06 && t < 0.2) {
        sparkle(
          p,
          -3,
          y - 3.0,
          3.5 * math.sin(((t - 0.06) / 0.14) * math.pi),
          c[7],
          c[6],
          0.4,
        );
      }
    }

    final pk = (t - _pop) / 0.1;
    if (pk > 0.0 && pk < 1.0) {
      p.circle(0, _cy, 13.0 * (1.0 - pk) + 1.0, pk < 0.5 ? kWhite : c[6]);
    }
    final fk = (t - _pop) / 0.2;
    if (fk > 0.0 && fk < 1.0) {
      flare(p, 0, _cy, 26.0 * math.pow(1.0 - fk, 1.5), 1.0 - fk, c);
    }
    final rk = (t - _pop - 0.03) / 0.35;
    if (rk > 0.0 && rk < 1.0) {
      p.ring(
        0,
        _cy,
        6.0 + 22.0 * Ease.outCubic(rk),
        math.max(1.0, 2.0 * (1.0 - rk)),
        rk < 0.3 ? kWhite : c[6],
        1.2 - rk,
      );
    }

    for (final coin in coins) {
      if (!popped || coin.state == 3) continue;
      for (var i = 1; i < coin.trail.length; i++) {
        final (x0, y0) = coin.trail[i - 1];
        final (x1, y1) = coin.trail[i];
        p.line(x0, y0, x1, y1, i < 3 ? c[6] : c[4], 1.2 - i / 7.0);
      }
      final hover = coin.state == 1 ? math.sin(t * 6.0 + coin.bob) * 1.5 : 0.0;
      final w = math.cos(coin.ph).abs();
      _drawCoin(p, c, coin.x, coin.y + hover, 5.0, math.max(0.15, w));
      p.glow(
        coin.x,
        coin.y + hover,
        10,
        c[5],
        coin.state == 2 ? 0.5 : 0.32,
      );
      final gl = (t * 1.7 + coin.bob).remainder(1.0);
      if (coin.state == 1 && gl < 0.12 && w > 0.5) {
        sparkle(
          p,
          coin.x - 1.0,
          coin.y + hover - 2.0,
          3.0 * math.sin((gl / 0.12) * math.pi),
          c[7],
          c[6],
          0.4,
        );
      }
    }

    final open = Ease.outBack(seg(t, 0.06, 0.26), 2.2) *
        (1.0 - Ease.inBack(seg(t, _fold, _fold + 0.2), 2.0));
    if (open > 0.04) {
      final h = _hh * open;
      final y0 = _hy + (_hh - h) / 2.0;
      final sh = seg(t, 1.5, 1.76);
      panel(
        p,
        _hx,
        y0,
        _hw,
        h,
        _ink,
        r: math.min(4.0, h / 2.0),
        shine: (sh > 0.0 && sh < 1.0) ? _hx - 6.0 + (_hw + 16.0) * sh : null,
      );
      if (open > 0.7) {
        _drawCoin(p, c, _ix, _iy, 5.5 * (1.0 + 0.3 * bump), 1.0, flash > 0.5);
        p.glow(_ix, _iy, 14, c[5], 0.25 + 0.4 * bump);
        if (bump > 0.0) {
          p.ring(
            _ix,
            _iy,
            7.0 + 8.0 * (1.0 - bump),
            1,
            bump > 0.6 ? kWhite : c[6],
            bump * 1.3,
          );
        }
        final s = 2.0 * (1.0 + 0.22 * bump);
        final word = spell('x$count');
        final w = word.w * s;
        final hWord = 7.0 * s;
        const x0 = _ix + 9.0;
        final ty = _iy - hWord / 2.0;
        final items = [
          for (final l in word.letters)
            if (l.g != null)
              WordLetter(
                g: l.g!,
                x: x0 + l.x * s,
                y: ty,
                sx: s,
                sy: s,
                flash: flash > 0.5 ? 1.0 : 0.0,
              ),
        ];
        drawWord(
          p,
          items,
          WordStyle(
            fill: [c[4], c[5], c[6], c[7]],
            edge: kWhite,
            under: c[3],
            outline: _ink.outline,
          ),
        );
        if (bump > 0.0) p.glow(x0 + w / 2.0, _iy, 16, c[5], 0.3 * bump);
      }
    }

    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect coinCollectEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ui/coin-collect',
    name: 'Coin collect',
    desc:
        'A coin bursts into a fountain of spinning coins that hang, then zip one by one into a HUD counter that pops and ticks up, glints and folds away.',
    category: 'ui',
    tags: ['ui', 'coins', 'pickup', 'reward', 'hud', 'counter', 'one-shot'],
    size: (176, 116),
    origin: (60, 102),
    duration: 2.45,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#2a1405',
        '#5c3008',
        '#9a5a0e',
        '#d48e18',
        '#f5b92c',
        '#ffde5e',
        '#fff4bc',
        '#ffffff',
      ],
      'count': 10,
      'from': 12,
      'seed': 4,
    },
  ),
  onCreate: _CoinCollectSim.new,
);
