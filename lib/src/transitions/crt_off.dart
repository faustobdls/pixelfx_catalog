// The glowing line (a white core, a pale fringe, an outer fringe while it's fresh, light along it) follows
// Sprite Fusion's open-source lightning strike (https://www.spritefusion.com/pixel-art-vfx/lightning),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'transitions_lib.dart';

const double _yc = kScreenH / 2.0;
const double _xc = kScreenW / 2.0;
const double _sq0 = 0.06;
const double _sq1 = 0.34;
const double _ln1 = 0.56;
const double _dot1 = 0.86;
const double _on0 = 1.06;
const double _on1 = 1.16;
const double _open1 = 1.42;

({double h, double w}) _shape(double t) {
  if (t < _sq0) return (h: kScreenH.toDouble(), w: _xc);
  if (t < _sq1) {
    return (
      h: math.max(
        1.0,
        kScreenH * (1.0 - Ease.inCubic((t - _sq0) / (_sq1 - _sq0))),
      ),
      w: _xc,
    );
  }
  if (t < _ln1) {
    return (
      h: 1.0,
      w: _xc * (1.0 - Ease.inQuad((t - _sq1) / (_ln1 - _sq1))),
    );
  }
  if (t < _on0) return (h: 0.0, w: 0.0);
  if (t < _on1) {
    return (h: 1.0, w: _xc * Ease.outExpo((t - _on0) / (_on1 - _on0)));
  }
  return (
    h: math.max(
      1.0,
      kScreenH * Ease.outCubic(clamp((t - _on1) / (_open1 - _on1))),
    ),
    w: _xc,
  );
}

final PureEffect crtOffEffect = PureEffect(
  meta: screenMeta(
    id: 'transitions/crt-off',
    name: 'CRT off',
    desc:
        'The picture squeezes into a white-hot glowing line, the line into a dot that lingers as a fading afterglow; then it switches back on, dot to line to picture, with a warm-up glow.',
    tags: const ['crt', 'tv', 'retro', 'switch', 'wipe'],
    duration: 2.0,
    options: const {
      'palette': [
        '#060a14',
        '#0e1a33',
        '#1a3360',
        '#2a5a9a',
        '#4a8fd0',
        '#8cc4f0',
        '#d4ecff',
        '#ffffff',
      ],
      'seed': 1,
    },
  ),
  onDraw: (p0, t, o) {
    final c = fit(o.palette, 8);
    final ink = hex(o['color'] ?? '#0b0a10');
    final seed = o.seed;
    final p = clipTo(p0);
    final (:h, :w) = _shape(t);
    final fl = 0.85 + 0.15 * rand((t * 30.0).floor(), 7, seed);

    if (t >= _open1 + 0.02 && t < _open1 + 0.6) {
      final u = (t - _open1) / 0.6;
      final band = -20.0 + u * (kScreenH + 40.0);
      for (var y = 0; y < kScreenH; y++) {
        final bDist = math.max(0.0, 1.0 - (y - band).abs() / 10.0);
        final k = 0.22 * (1.0 - u) * (1.0 - u) +
            0.3 * bDist * bDist * (1.0 - u) +
            ((y & 1) != 0 ? 0.05 * (1.0 - u) : 0.0);
        if (k > 0.01) {
          for (var x = 0; x < kScreenW; x++) {
            p0.light(x.toDouble(), y.toDouble(), c[5], k);
          }
        }
      }
      return;
    }

    if (h >= kScreenH) return;

    final top = ((_yc - h / 2.0) + 0.5).floor();
    final bot = ((_yc + h / 2.0) + 0.5).floor();
    if (top > 0) {
      fastRect(p0, 0.0, 0.0, kScreenW.toDouble(), top.toDouble(), ink);
    }
    if (bot < kScreenH) {
      fastRect(
        p0,
        0.0,
        bot.toDouble(),
        kScreenW.toDouble(),
        (kScreenH - bot).toDouble(),
        ink,
      );
    }

    if (h > 2.0) {
      final sq = 1.0 - h / kScreenH;
      for (var y = top; y < bot; y++) {
        final e = math.min(y - top, bot - 1 - y);
        final edge = math.max(0.0, 1.0 - e / 6.0);
        final k = 0.55 * sq * sq +
            ((y & 1) != 0 ? 0.08 * sq : 0.0) +
            0.35 * edge * edge;
        for (var x = 0; x < kScreenW; x++) {
          p0.light(x.toDouble(), y.toDouble(), c[5], k * fl);
        }
      }
      for (final y in [top - 1, bot]) {
        if (y >= 0 && y < kScreenH) {
          fastRect(
            p0,
            0.0,
            y.toDouble(),
            kScreenW.toDouble(),
            1.0,
            sq > 0.6 ? c[6] : c[5],
          );
        }
      }
      return;
    }

    final dotPhase = t >= _ln1 && t < _on0;
    final x0 = (_xc - w).floor();
    final x1 = (_xc + w).ceil();
    final fresh = t < _sq1 + 0.08 || (t > _on0 && t < _on1 + 0.04);

    if (h > 0.0 && w >= 1.0) {
      final fr = (t * 30.0).floor();
      final xa = math.max(0, x0);
      final xb = math.min(kScreenW, x1);
      for (var x = xa; x < xb; x++) {
        final u = (x + 0.5 - _xc).abs() / w;
        final nOff =
            (noise(x / 23.0 + t * 9.0, seed) * (0.7 + 0.5 * u) + 0.5).floor();
        final y = _yc + nOff;
        p0.px(x.toDouble(), y, u < 0.85 ? kWhite : c[6]);
        if (u < 0.92) {
          p0.px(x.toDouble(), y - 1.0, c[6]);
          p0.px(x.toDouble(), y + 1.0, u < 0.6 ? c[6] : c[5]);
        }
        if (fresh && u < 0.8) {
          p0.dot(x.toDouble(), y - 2.0, c[4], 0.5);
          p0.dot(x.toDouble(), y + 2.0, c[4], 0.5);
        }
        if (rand(x, fr, seed + 3) < 0.06) {
          final dir = rand(x, fr, seed + 4) < 0.5 ? -1 : 1;
          final distPx = 2 + (rand(x, fr, seed + 5) * 4.0).floor();
          p.px(
            x.toDouble(),
            y + dir * distPx,
            rand(x, fr, 6) < 0.5 ? kWhite : c[5],
          );
        }
        p0.light(x.toDouble(), y, c[6], 0.5 * fl * (1.0 - u * 0.6));
      }
      for (var x = x0; x <= x1; x += 9) {
        p.glow(x.toDouble(), _yc, 10.0, c[5], 0.35 * fl);
      }
      p.glow(_xc, _yc, math.min(70.0, 16.0 + w * 0.4), c[5], 0.4 * fl);
    }

    if (dotPhase) {
      final u = (t - _ln1) / (_dot1 - _ln1);
      if (u < 0.35) {
        transitionGlint(
          p,
          _xc,
          _yc,
          10.0 * (1.0 - u / 0.35) + 3.0,
          0.2 + u * 2.0,
          c[6],
          c[5],
        );
      }
      if (u < 1.0) {
        p.px(_xc, _yc, u < 0.5 ? kWhite : (u < 0.75 ? c[6] : c[4]));
        p.px(_xc - 1.0, _yc, u < 0.4 ? c[6] : c[4]);
        final sm = (9.0 * (1.0 - u) + 0.5).floor();
        for (var k = 2; k <= sm; k++) {
          final a = 1.0 - k / (sm + 1);
          p.dot(_xc - k, _yc, c[4], a);
          p.dot(_xc + k - 1, _yc, c[4], a);
        }
        p.glow(
          _xc,
          _yc,
          22.0 * (1.0 - u * 0.5),
          c[5],
          0.55 * math.pow(1.0 - u, 1.5),
        );
      }
    }

    final s = t - _on0;
    if (s >= 0.0 && s < 0.14) {
      transitionGlint(
        p,
        _xc,
        _yc,
        12.0 * (1.0 - s / 0.14) + 2.0,
        0.4 + s * 6.0,
        c[6],
        c[5],
      );
      p.glow(_xc, _yc, 40.0, kWhite, 0.5 * (1.0 - s / 0.14));
    }
  },
);
