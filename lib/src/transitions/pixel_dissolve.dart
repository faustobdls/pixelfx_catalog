// The glints and the twinkling pixel dust follow Sprite Fusion's open-source sparkle
// (https://www.spritefusion.com/pixel-art-vfx/sparkle), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'transitions_lib.dart';

const double _pFade = 0.17;
const double _in0 = 0.04;
const double _in1 = 0.8;
const double _out0 = 1.12;
const double _out1 = 1.85;
const int _cell = 20;

class _DissolveBlock {
  final int x;
  final int y;
  final int s;
  late double tin;
  late double tout;
  late bool hasGlint;
  late double gx;
  late double gy;
  late double spin;
  late double glintLen;

  _DissolveBlock(this.x, this.y, this.s);
}

final Map<int, List<_DissolveBlock>> _layoutCache = {};

List<_DissolveBlock> _layout(int seed) {
  final cached = _layoutCache[seed];
  if (cached != null) return cached;

  final blocks = <_DissolveBlock>[];
  for (var cy = 0; cy < kScreenH ~/ _cell; cy++) {
    for (var cx = 0; cx < kScreenW ~/ _cell; cx++) {
      final h = rand(cx, cy, seed);
      final n = h < 0.32 ? 1 : (h < 0.74 ? 2 : 4);
      final s = _cell ~/ n;
      for (var j = 0; j < n; j++) {
        for (var i = 0; i < n; i++) {
          blocks.add(_DissolveBlock(cx * _cell + i * s, cy * _cell + j * s, s));
        }
      }
    }
  }

  Float32List rank(double Function(_DissolveBlock b) keyFn) {
    final v = [for (final b in blocks) keyFn(b)];
    final order = List<int>.generate(v.length, (i) => i);
    order.sort((a, b) {
      final cmp = v[a].compareTo(v[b]);
      return cmp != 0 ? cmp : a.compareTo(b);
    });
    final out = Float32List(v.length);
    for (var k = 0; k < order.length; k++) {
      out[order[k]] = k / (v.length - 1);
    }
    return out;
  }

  double at(_DissolveBlock b, int sd) =>
      fbm((b.x + b.s / 2.0) / 64.0, (b.y + b.s / 2.0) / 64.0, sd, 3);

  final uin = rank((b) =>
      at(b, seed) +
      0.22 * rand(b.x, b.y, seed + 1) +
      (b.s == 20 ? 0.12 : (b.s == 5 ? -0.08 : 0.0)));
  final uout = rank((b) =>
      at(b, seed + 7) +
      0.22 * rand(b.x, b.y, seed + 2) +
      (b.s == 20 ? -0.14 : (b.s == 5 ? 0.1 : 0.0)));

  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    b.tin = _in0 + uin[i] * (_in1 - _in0);
    b.tout = _out0 + uout[i] * (_out1 - _out0);
    b.hasGlint = rand(b.x, b.y, seed + 3) < (b.s >= 10 ? 0.32 : 0.1);
    b.gx = b.x + (rand(b.x, b.y, seed + 4) < 0.5 ? 0.0 : b.s.toDouble());
    b.gy = b.y + (rand(b.x, b.y, seed + 5) < 0.5 ? 0.0 : b.s.toDouble());
    b.spin = (rand(b.x, b.y, seed + 6) - 0.5) * 3.0;
    b.glintLen = (b.s == 20 && rand(b.x, b.y, seed + 8) < 0.45)
        ? 9.0 + 6.0 * rand(b.x, b.y, seed + 9)
        : 2.5 + b.s * 0.32;
  }

  _layoutCache[seed] = blocks;
  return blocks;
}

void _mote(Painter p, double x, double y, int c, bool cross) {
  p.px(x, y, c);
  if (cross) {
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      p.px(x + dx, y + dy, c);
    }
  }
}

void _square(Painter p, double x, double y, double s, int fill, [int? rim]) {
  final xi = x.round();
  final yi = y.round();
  final si = math.max(1, s.round());
  if (fill != 0) fastRect(p, xi.toDouble(), yi.toDouble(), si.toDouble(), si.toDouble(), fill);
  if (rim != null && si > 2) {
    fastRect(p, xi.toDouble(), yi.toDouble(), si.toDouble(), 1.0, rim);
    fastRect(p, xi.toDouble(), (yi + si - 1).toDouble(), si.toDouble(), 1.0, rim);
    fastRect(p, xi.toDouble(), yi.toDouble(), 1.0, si.toDouble(), rim);
    fastRect(p, (xi + si - 1).toDouble(), yi.toDouble(), 1.0, si.toDouble(), rim);
  }
}

final PureEffect pixelDissolveEffect = PureEffect(
  meta: screenMeta(
    id: 'transitions/pixel-dissolve',
    name: 'Pixel dissolve',
    desc:
        'Clumps of blocks wink in, each drawn in a white outline that fills black and cools, with glints; then they wink out, outlines collapsing, the last small ones sparkling away.',
    tags: const ['dissolve', 'pixel', 'blocks', 'glint'],
    duration: 2.2,
    options: {'palette': Pal.neon, 'seed': 1},
  ),
  onDraw: (p0, t, o) {
    final c = fit(o.palette, 8);
    final ink = hex(o['color'] ?? '#0b0a10');
    final p = clipTo(p0);
    final blocks = _layout(o.seed);
    final glints = <(_DissolveBlock, double, int)>[];
    final frame = (t * 15.0).floor();

    for (var n = 0; n < blocks.length; n++) {
      final b = blocks[n];
      final ki = (t - b.tin) / _pFade;
      final ko = (t - b.tout) / _pFade;
      final x = b.x.toDouble();
      final y = b.y.toDouble();
      final s = b.s.toDouble();
      final cx = x + s / 2.0;
      final cy = y + s / 2.0;
      if (ki < 0.0 || ko >= 1.6) continue;
      if (ko < 0.0) {
        if (ki >= 1.0) {
          _square(p0, x, y, s, ink);
        } else {
          final g = ki < 0.35 ? 0.35 + 0.65 * Ease.outBack(ki / 0.35) : 1.0;
          final h = s * g;
          final rim = ki < 0.45
              ? kWhite
              : (ki < 0.6
                  ? c[6]
                  : (ki < 0.75 ? c[5] : (ki < 0.9 ? c[4] : c[3])));
          _square(p, cx - h / 2.0, cy - h / 2.0, h, ki > 0.2 ? ink : 0, rim);
          if (ki < 0.3 && s >= 10.0) {
            for (final (dx, dy) in const [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]) {
              p.px(cx - 0.5 + dx, cy - 0.5 + dy, (dx != 0 || dy != 0) ? c[6] : kWhite);
            }
          }
          p.glow(cx, cy, s * 0.8 + 4.0, c[5], 0.45 * (1.0 - ki));
        }
        if (b.hasGlint && ki > 0.15 && ki < 1.6) {
          glints.add((b, (ki - 0.15) / 1.45, 1));
        }
        if (ki < 1.4 && rand(frame, n, 9) < 0.35) {
          _mote(
            p,
            x + rand(frame, n, 10) * (s + 6.0) - 3.0,
            y + rand(frame, n, 11) * (s + 6.0) - 3.0,
            rand(frame, n, 12) < 0.5 ? kWhite : c[6],
            rand(frame, n, 17) < 0.25,
          );
        }
      } else {
        if (ko < 0.35) {
          final q = ko / 0.35;
          _square(
            p0,
            x,
            y,
            s,
            ink,
            q < 0.4 ? c[4] : (q < 0.75 ? c[5] : c[6]),
          );
          p.glow(cx, cy, s * 0.8 + 3.0, c[4], 0.35 * q);
        } else if (ko < 0.75) {
          final q = (ko - 0.35) / 0.4;
          final h = s * (1.0 - Ease.inQuad(q) * 0.85);
          _square(p, cx - h / 2.0, cy - h / 2.0, h, 0, q < 0.5 ? kWhite : c[6]);
          p.glow(cx, cy, s * 0.8 + 4.0, c[5], 0.45 * (1.0 - q * 0.5));
        } else if (ko < 1.0) {
          final q = (ko - 0.75) / 0.25;
          for (final (dx, dy) in const [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]) {
            if ((dx == 0 && dy == 0) || q < 0.5) {
              p.px(cx - 0.5 + dx, cy - 0.5 + dy, (dx != 0 || dy != 0) ? c[6] : kWhite);
            }
          }
          p.glow(cx, cy, s * 0.5 + 3.0, c[5], 0.35 * (1.0 - q));
        }
        if (b.hasGlint && ko > 0.3) glints.add((b, (ko - 0.3) / 1.3, -1));
        if (ko > 0.3 && ko < 1.5 && rand(frame, n, 13) < 0.3) {
          _mote(
            p,
            x + rand(frame, n, 14) * (s + 6.0) - 3.0,
            y + rand(frame, n, 15) * (s + 6.0) - 3.0,
            rand(frame, n, 16) < 0.5 ? kWhite : c[6],
            rand(frame, n, 18) < 0.25,
          );
        }
      }
    }

    for (final (b, u, dir) in glints) {
      if (u <= 0.0 || u >= 1.0) continue;
      final len = b.glintLen * math.pow(math.sin(math.pi * u), 0.7);
      transitionGlint(p, b.gx, b.gy, len, b.spin * u * dir + 0.4, c[5], c[4]);
      if (b.glintLen > 8.0) {
        p.glow(b.gx, b.gy, 18.0 + len, c[5], 0.25 * math.sin(math.pi * u));
      }
    }
  },
);
