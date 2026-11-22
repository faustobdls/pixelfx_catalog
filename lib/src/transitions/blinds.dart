// The dust drifting in the light and the light squeezing through follow Sprite Fusion's open-source holy light
// (https://www.spritefusion.com/pixel-art-vfx/holy-light), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'transitions_lib.dart';

const int _nSlats = 12;
const double _sh = kScreenH / _nSlats;
const double _shut0 = 0.08;
const double _open0 = 1.02;
const double _step = 0.038;
const double _turn = 0.42;
const double _ostep = 0.03;
const double _oturn = 0.4;
const double _fade0 = 1.72;
const double _fade1 = 1.94;
const double _duration = 2.0;

double _angle(int i, double t) {
  if (t < _open0) {
    return (math.pi / 2.0) *
        Ease.outBack(clamp((t - _shut0 - i * _step) / _turn), 1.6);
  }
  return (math.pi / 2.0) *
      (1.0 - Ease.inOutCubic(clamp((t - _open0 - i * _ostep) / _oturn)));
}

class _BlindsSim extends BaseEffectSim {
  final List<int> c;
  final int ink;
  final Rng r;
  final Particles ps;
  double t = 0.0;
  final double end = _duration - 0.05;

  _BlindsSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        ink = hex(o['color'] ?? '#0b0a10'),
        r = Rng(o.seed),
        ps = Particles(
          rng: Rng(o.seed),
          sparks: [
            kWhite,
            fit(o.palette, 8)[6],
            fit(o.palette, 8)[5],
            fit(o.palette, 8)[4],
          ],
        );

  // Share the exact same Rng instance with Particles to match JS 1:1.
  factory _BlindsSim.create(Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final ink = hex(o['color'] ?? '#0b0a10');
    final r = Rng(o.seed);
    final ps = Particles(rng: r, sparks: [kWhite, c[6], c[5], c[4]]);
    return _BlindsSim._(c, ink, r, ps);
  }

  _BlindsSim._(this.c, this.ink, this.r, this.ps);

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t < _fade0 && r.chance(0.8)) {
      final i = r.intRange(0, _nSlats - 1);
      final th = _angle(i, t);
      if (th > 0.2 && th < 1.45) {
        ps.spawn(
          P.ember,
          r.range(0.0, kScreenW.toDouble()),
          (i + 1) * _sh + r.range(-2.0, 2.0),
          r.range(-8.0, 8.0),
          -r.range(2.0, 8.0),
          math.min(r.range(0.5, 1.0), end - t),
          0,
          1.0,
        );
      }
    }
    ps.update(dt);
  }

  @override
  void draw(Painter p0) {
    final p = clipTo(p0);
    final open = Uint8List(kScreenH)..fillRange(0, kScreenH, 1);
    for (var i = 0; i < _nSlats; i++) {
      final h = math.max(1.0, (_sh + 1.0) * math.sin(_angle(i, t)).abs());
      final yc = (i + 0.5) * _sh;
      final y0 = math.max(0, (yc - h / 2.0 - 0.5).ceil());
      final y1 = math.min(kScreenH - 1, (yc + h / 2.0 - 0.5).floor());
      for (var y = y0; y <= y1; y++) {
        open[y] = 0;
      }
    }
    for (final q in ps.list) {
      final y = q.y.floor();
      final k = q.life / q.max;
      if (q.delay > 0.0 ||
          y < 0 ||
          y >= kScreenH ||
          open[y] == 0 ||
          q.x < 0.0 ||
          q.x >= kScreenW) {
        continue;
      }
      final tw = (q.seed % 1.0) < 0.3 && math.sin(t * 14.0 + q.seed) > 0.0;
      p0.px(q.x, y.toDouble(), tw || k > 0.5 ? kWhite : c[5]);
      if (tw) {
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final ny = y + dy;
          if (ny >= 0 && ny < kScreenH && open[ny] != 0) {
            p.px(q.x + dx, ny.toDouble(), c[6]);
          }
        }
      }
      p0.light(q.x, y.toDouble(), c[6], (tw ? 0.7 : 0.4) * k);
    }

    final fade = 1.0 - clamp((t - _fade0) / (_fade1 - _fade0));
    final appear = clamp(t / _shut0);
    for (var i = 0; i < _nSlats; i++) {
      final th = _angle(i, t);
      final s = math.sin(th);
      final cs = math.cos(th);
      final yc = (i + 0.5) * _sh;
      final h = math.max(1.0, (_sh + 1.0) * s.abs());
      final y0 = math.max(0, (yc - h / 2.0 - 0.5).ceil());
      final y1 = math.min(kScreenH - 1, (yc + h / 2.0 - 0.5).floor());
      final under = th > math.pi / 2.0;

      if (h < 2.5) {
        final k = math.min(appear, fade);
        if (k <= 0.0) continue;
        final yy = ((yc - 0.5) + 0.5).floor();
        fastRect(
          p0,
          0.0,
          yy.toDouble(),
          kScreenW.toDouble(),
          1.0,
          k > 0.66 ? c[6] : (k > 0.33 ? c[4] : c[2]),
        );
        if (h >= 1.5 && yy + 1 < kScreenH) {
          fastRect(
            p0,
            0.0,
            (yy + 1).toDouble(),
            kScreenW.toDouble(),
            1.0,
            k > 0.5 ? c[3] : c[1],
          );
        }
        for (var x = 0; x < kScreenW; x += 2) {
          p0.light(x.toDouble(), yy.toDouble(), c[5], 0.18 * k);
        }
        continue;
      }

      final lit = under ? 0.0 : cs;
      for (var y = y0; y <= y1; y++) {
        final rRow = y - y0;
        final last = y == y1;
        final v = rRow / math.max(1, y1 - y0);
        final f = lit * (1.0 - v * 0.8);
        final col = rRow == 0
            ? (lit > 0.55
                ? kWhite
                : (lit > 0.3 ? c[6] : (lit > 0.12 ? c[4] : ink)))
            : (rRow == 1
                ? (lit > 0.45 ? c[5] : (lit > 0.2 ? c[3] : ink))
                : (last
                    ? ink
                    : (f > 0.55
                        ? c[3]
                        : (f > 0.35 ? c[2] : (f > 0.15 ? c[1] : ink)))));
        fastRect(p0, 0.0, y.toDouble(), kScreenW.toDouble(), 1.0, col);
        if (rRow == 0 && lit > 0.12) {
          for (var x = 0; x < kScreenW; x += 2) {
            p0.light(x.toDouble(), y.toDouble(), c[5], 0.35 * lit);
          }
        }
      }

      final gap = _sh - h;
      if (gap > 0.5 && th > 0.12 && !under) {
        final k = (0.2 + 0.45 * math.pow(1.0 - gap / _sh, 1.5)) *
            math.min(1.0, th / 0.4);
        final gy = y1 + 1;
        final gyEnd = math.min(kScreenH, gy + gap.ceil());
        for (var y = gy; y < gyEnd; y++) {
          final v = (y - gy + 0.5) / gap;
          final kk = k * (1.0 - (v - 0.5).abs() * 1.2);
          if (kk > 0.01) {
            for (var x = 0; x < kScreenW; x++) {
              p0.light(x.toDouble(), y.toDouble(), c[6], kk);
              p0.light(x.toDouble(), y.toDouble(), c[4], kk * 0.5);
            }
          }
        }
      }

      final u = t < _open0
          ? clamp((t - _shut0 - i * _step) / _turn)
          : clamp((t - _open0 - i * _ostep) / _oturn);
      if (lit > 0.3 && u > 0.05 && u < 0.95) {
        transitionGlint(
          p,
          kScreenW * (t < _open0 ? u : 1.0 - u),
          y0.toDouble(),
          6.0 * math.sin(math.pi * u),
          u * 3.0,
          c[6],
          c[5],
        );
      }
    }
  }
}

final SimulatedEffect blindsEffect = SimulatedEffect(
  meta: screenMeta(
    id: 'transitions/blinds',
    name: 'Blinds',
    desc:
        'Slats catch the light edge-on, then tilt shut top to bottom, lit rims glinting as warm light squeezes through the closing gaps with dust in it; then they tilt open and fade.',
    tags: const ['blinds', 'slats', 'light', 'wipe'],
    duration: _duration,
    options: const {
      'palette': [
        '#1a120c',
        '#33241a',
        '#5a4030',
        '#8a6848',
        '#c09a6a',
        '#e8cc98',
        '#fff0cc',
        '#ffffff',
      ],
      'seed': 1,
    },
  ),
  onCreate: _BlindsSim.create,
);
