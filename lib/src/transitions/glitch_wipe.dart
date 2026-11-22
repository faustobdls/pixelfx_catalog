// The specks of white, cyan and magenta a body breaks into follow Sprite Fusion's open-source blink
// (https://www.spritefusion.com/pixel-art-vfx/movement), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'transitions_lib.dart';

const double _tick = 1.0 / 18.0;
const double _in0 = 0.03;
const double _in1 = 0.78;
const double _out0 = 0.98;
const double _out1 = 1.66;

class _GlitchBand {
  final int i;
  final int y;
  final int h;
  final int dir;
  final double off;
  final double t0;
  final double t1;
  final double o0;
  final double o1;

  const _GlitchBand({
    required this.i,
    required this.y,
    required this.h,
    required this.dir,
    required this.off,
    required this.t0,
    required this.t1,
    required this.o0,
    required this.o1,
  });
}

final Map<int, List<_GlitchBand>> _bandsCache = {};

List<_GlitchBand> _bands(int seed) {
  final cached = _bandsCache[seed];
  if (cached != null) return cached;
  final out = <_GlitchBand>[];
  var y = 0;
  for (var i = 0; y < kScreenH; i++) {
    final r = rand(i, seed);
    final rawH = r < 0.4
        ? 5 + (rand(i, seed + 1) * 6.0).floor()
        : (r < 0.85
            ? 10 + (rand(i, seed + 1) * 10.0).floor()
            : 20 + (rand(i, seed + 1) * 12.0).floor());
    final h = math.min(kScreenH - y, rawH);
    final a = clamp(
      0.5 + 0.55 * noise(y / 40.0, seed + 9) + (rand(i, seed + 2) - 0.5) * 0.25,
    );
    final b = clamp(
      0.5 +
          0.55 * noise(y / 40.0, seed + 19) +
          (rand(i, seed + 3) - 0.5) * 0.25,
    );
    final span = 0.32 + rand(i, seed + 6) * 0.12;
    final t0 = _in0 + a * (_in1 - _in0 - span);
    final o0 = _out0 + b * (_out1 - _out0 - span);
    out.add(
      _GlitchBand(
        i: i,
        y: y,
        h: h,
        dir: rand(i, seed + 4) < 0.82 ? 1 : -1,
        off: rand(i, seed + 5),
        t0: t0,
        t1: t0 + span,
        o0: o0,
        o1: o0 + span,
      ),
    );
    y += h;
  }
  _bandsCache[seed] = out;
  return out;
}

double _tear(_GlitchBand b, double t, double t0, double t1, int salt) {
  if (t <= t0) return 0.0;
  if (t >= t1) return 1.0;
  var n = ((t + b.off * _tick) / _tick).floor();
  while (n > 0 && rand(n, b.i, salt) < 0.22) {
    n--;
  }
  final tq = n * _tick - b.off * _tick;
  final u = clamp((tq - t0) / (t1 - t0));
  return clamp(
    Ease.inOutQuad(u) +
        (rand(n, b.i, salt + 1) - 0.6) * 0.12 * math.sin(math.pi * u),
  );
}

final PureEffect glitchWipeEffect = PureEffect(
  meta: screenMeta(
    id: 'transitions/glitch-wipe',
    name: 'Glitch wipe',
    desc:
        'Torn bands of black stutter across the screen, freezing and jerking back, their ragged edges split into magenta and cyan ghosts spitting data slivers; then they tear on through.',
    tags: const ['glitch', 'digital', 'rgb', 'bands', 'wipe'],
    duration: 1.8,
    options: const {'palette': Pal.cyber, 'split': '#ff2d6f', 'seed': 1},
  ),
  onDraw: (p0, t, o) {
    final c = fit(o.palette, 8);
    final ink = hex(o['color'] ?? '#0b0a10');
    final red = hex(o['split'] ?? '#ff2d6f');
    final p = clipTo(p0);
    final bList = _bands(o.seed);
    final fr = (t / _tick).floor();
    final out = t >= _out0;
    final speckCols = [kWhite, c[6], c[5], red];

    for (final b in bList) {
      final k = out ? _tear(b, t, b.o0, b.o1, 7) : _tear(b, t, b.t0, b.t1, 3);
      if ((!out && k <= 0.0) || (out && k >= 1.0)) continue;
      final moving = k > 0.0 && k < 1.0;
      final slip = moving && rand(fr, b.i, 11) < 0.12
          ? ((rand(fr, b.i, 12) - 0.5) * 18.0 + 0.5).floor()
          : 0;
      final fwd = b.dir;
      final e = (b.dir > 0 ? k * kScreenW : kScreenW - k * kScreenW) + slip;

      for (var y = b.y; y < b.y + b.h; y++) {
        final jag = moving
            ? ((rand(fr, y, 14) - 0.5) * 6.0 +
                    (rand(fr >> 1, b.i, 15) - 0.5) * 6.0 +
                    0.5)
                .floor()
            : 0;
        final ex = clampInt(((e + jag) + 0.5).floor(), 0, kScreenW);
        final behind = (fwd > 0) != out;
        if (behind) {
          if (ex > 0) {
            fastRect(p0, 0.0, y.toDouble(), ex.toDouble(), 1.0, ink);
          }
        } else {
          if (ex < kScreenW) {
            fastRect(
              p0,
              ex.toDouble(),
              y.toDouble(),
              (kScreenW - ex).toDouble(),
              1.0,
              ink,
            );
          }
        }
        if (!moving) continue;
        final e1 = (behind ? ex - 1 : ex).toDouble();
        final side = behind ? 1 : -1;
        final sp = 2 + ((b.i + fr) % 3);
        p.px(e1, y.toDouble(), kWhite);
        p.px(e1 + side * sp, y.toDouble(), red);
        p.px(e1 + side * (sp + 1), y.toDouble(), red);
        p.px(e1 - side * (sp + 1), y.toDouble(), c[5]);
        p.px(e1 - side * (sp + 2), y.toDouble(), c[4]);
        p.light(e1, y.toDouble(), kWhite, 0.45);
        p.light(e1 + side * (sp + 1), y.toDouble(), red, 0.5);
        p.light(e1 + side * (sp + 3), y.toDouble(), red, 0.22);
        p.light(e1 - side * (sp + 1), y.toDouble(), c[5], 0.45);
        p.light(e1 - side * (sp + 3), y.toDouble(), c[5], 0.22);
      }

      if (!moving) continue;
      final ex = clampInt((e + 0.5).floor(), 0, kScreenW);
      final open = ((fwd > 0) != out) ? 1 : -1;
      p.glow(
        ex.toDouble(),
        b.y + b.h / 2.0,
        b.h * 0.7 + 7.0,
        (b.i & 1) != 0 ? red : c[5],
        0.28,
      );
      for (var s = 0; s < b.h; s++) {
        if (rand(fr, b.i, 100 + s) > 0.55) continue;
        final rDist = rand(fr, b.i, 200 + s);
        final x = ex + open * ((rDist * rDist * 22.0 - 4.0) + 0.5).floor();
        final y = b.y + (rand(fr, b.i, 300 + s) * b.h).floor();
        p.px(
          x.toDouble(),
          y.toDouble(),
          speckCols[(rand(fr, b.i, 400 + s) * 4.0).floor()],
        );
      }
      for (var s = 0; s < 4; s++) {
        if (rand(fr, b.i, 20 + s) > 0.5) continue;
        final rLen = rand(fr, b.i, 30 + s);
        final len = 2 + (rLen * rLen * 60.0).floor();
        final ahead = rand(fr, b.i, 40 + s) < 0.6;
        final d =
            (math.pow(rand(fr, b.i, 50 + s), 1.5) * 70.0).floor() + 4;
        final y = b.y + (rand(fr, b.i, 60 + s) * b.h).floor();
        final x = ahead
            ? (open > 0 ? ex + d : ex - d - len)
            : (open > 0 ? ex - d - len : ex + d);
        final col = speckCols[(rand(fr, b.i, 70 + s) * 4.0).floor()];
        p.rect(x.toDouble(), y.toDouble(), len.toDouble(), 1.0, col);
        for (var q = 0; q < len; q += 3) {
          p.light((x + q).toDouble(), y.toDouble(), col, 0.35);
        }
      }
      if (b.h >= 8 && rand(fr, b.i, 80) < 0.35) {
        final bw = 6 + (rand(fr, b.i, 81) * 10.0).floor();
        final bh =
            3 + (rand(fr, b.i, 82) * math.min(6, b.h - 3)).floor();
        final x = ex +
            open * (rand(fr, b.i, 83) * 24.0 - 4.0).floor() -
            (open < 0 ? bw : 0);
        final y = b.y + (rand(fr, b.i, 84) * (b.h - bh)).floor();
        final col = rand(fr, b.i, 85) < 0.5 ? c[5] : red;
        p.rect(x.toDouble(), y.toDouble(), bw.toDouble(), 1.0, col);
        p.rect(x.toDouble(), (y + bh - 1).toDouble(), bw.toDouble(), 1.0, col);
        p.rect(x.toDouble(), y.toDouble(), 1.0, bh.toDouble(), col);
        p.rect((x + bw - 1).toDouble(), y.toDouble(), 1.0, bh.toDouble(), col);
        for (var q = 0; q < bw; q += 2) {
          p.light((x + q).toDouble(), y.toDouble(), col, 0.25);
        }
      }
    }

    if (t > _in1 && t < _out0 + 0.05) {
      for (var s = 0; s < 3; s++) {
        if (rand(fr, s, 90) > 0.4) continue;
        final y = (rand(fr, s, 91) * kScreenH).floor();
        final x = (rand(fr, s, 92) * kScreenW).floor();
        final rLen = rand(fr, s, 93);
        final len = 3 + (rLen * rLen * 40.0).floor();
        p.rect(
          x.toDouble(),
          y.toDouble(),
          len.toDouble(),
          1.0,
          s == 0 ? c[4] : (s == 1 ? c[3] : red),
        );
      }
    }
  },
);
