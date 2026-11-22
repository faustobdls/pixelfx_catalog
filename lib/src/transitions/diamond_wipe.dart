// The faceted shading (a lit ridge, a bright face toward the light, a dark one away, a bright rim) follows
// Sprite Fusion's open-source ice crystals (https://www.spritefusion.com/pixel-art-vfx/ice), MIT License,
// Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'transitions_lib.dart';

const int _s = 32;
const double _hd = _s / 2.0 + 1.0;
const double _grow = 0.24;
const double _in0 = 0.04;
const double _in1 = 0.66;
const double _out0 = 1.05;
const double _out1 = 1.56;

class _Diamond {
  final double cx;
  final double cy;
  final double tin;
  final double tout;
  final bool glint;
  final double spin;

  const _Diamond({
    required this.cx,
    required this.cy,
    required this.tin,
    required this.tout,
    required this.glint,
    required this.spin,
  });
}

final Map<int, List<_Diamond>> _latticeCache = {};

List<_Diamond> _lattice(int seed) {
  final cached = _latticeCache[seed];
  if (cached != null) return cached;
  final out = <_Diamond>[];
  final jMax = (kScreenH / (_s / 2.0)).ceil() + 1;
  final iMax = (kScreenW / _s).ceil() + 1;
  for (var j = -1; j <= jMax; j++) {
    for (var i = -1; i <= iMax; i++) {
      final cx = i * _s + ((j & 1) != 0 ? _s / 2.0 : 0.0);
      final cy = (j * _s) / 2.0;
      if (cx + _hd < 0.0 ||
          cy + _hd < 0.0 ||
          cx - _hd > kScreenW ||
          cy - _hd > kScreenH) {
        continue;
      }
      final u = clamp((cx + 0.45 * cy) / (kScreenW + 0.45 * kScreenH));
      final jr = rand(i, j, seed);
      out.add(
        _Diamond(
          cx: cx,
          cy: cy,
          tin: _in0 + (_in1 - _in0) * clamp(u + (jr - 0.5) * 0.08),
          tout: _out0 +
              (_out1 - _out0) *
                  clamp(u + (rand(i, j, seed + 1) - 0.5) * 0.08),
          glint: jr < 0.3,
          spin: rand(i, j, seed + 2) * 3.0,
        ),
      );
    }
  }
  _latticeCache[seed] = out;
  return out;
}

final PureEffect diamondWipeEffect = PureEffect(
  meta: screenMeta(
    id: 'transitions/diamond-wipe',
    name: 'Diamond wipe',
    desc:
        'A wave of faceted diamonds swells across the screen, rims bright and ridges lit, cooling to black as they lock; then they rise as gems again and shrink away with glints.',
    tags: const ['diamond', 'lattice', 'geometric', 'wipe'],
    duration: 2.0,
    options: const {'palette': Pal.arcane, 'seed': 1},
  ),
  onDraw: (p0, t, o) {
    final c = fit(o.palette, 8);
    final ink = hex(o['color'] ?? '#0b0a10');
    final p = clipTo(p0);
    final lat = _lattice(o.seed);
    final glints = <(_Diamond, double, double)>[];
    final face = [
      [c[2], c[1], c[0]],
      [c[1], c[0], c[0]],
      [c[1], c[0], c[0]],
      [c[0], c[0], ink],
    ];

    for (final d in lat) {
      final ki = (t - d.tin) / _grow;
      final ko = (t - d.tout) / _grow;
      if (d.glint && ko > 0.7 && ko < 1.5) {
        glints.add((d, (ko - 0.7) / 0.8, 0.0));
      }
      if (ki <= 0.0 || ko >= 1.0) continue;
      final hd = _hd *
          (ko > 0.0
              ? 1.0 - Ease.inBack(ko, 2.0)
              : Ease.outBack(math.min(1.0, ki), 2.2));
      final heat = ko > 0.0
          ? smooth(0.0, 0.35, ko)
          : 1.0 - smooth(0.45, 1.25, ki);
      if (hd < 0.5) continue;
      final settled = heat <= 0.0;
      final y0 = math.max(0, (d.cy - hd).floor());
      final y1 = math.min(kScreenH - 1, (d.cy + hd).ceil());
      for (var y = y0; y <= y1; y++) {
        final dy = y + 0.5 - d.cy;
        final w = hd - dy.abs();
        if (w <= 0.0) continue;
        final x0 = math.max(0, (d.cx - w - 0.5).ceil());
        final x1 = math.min(kScreenW - 1, (d.cx + w - 0.5).floor());
        if (x1 < x0) continue;
        if (settled) {
          fastRect(p0, x0.toDouble(), y.toDouble(), (x1 - x0 + 1).toDouble(), 1.0, ink);
          continue;
        }
        final st = heat > 0.66 ? 0 : (heat > 0.33 ? 1 : 2);
        for (var x = x0; x <= x1; x++) {
          final dx = x + 0.5 - d.cx;
          final e = hd - dx.abs() - dy.abs();
          final q = (dy < 0.0 ? 0 : 2) + (dx < 0.0 ? 0 : 1);
          final vr = dx > -1.0 && dx <= 0.0;
          final hr = dy > -1.0 && dy <= 0.0;
          int col;
          if (e < 1.0) {
            final rimCol = switch (q) {
              0 => heat > 0.5 ? kWhite : c[6],
              1 => heat > 0.5 ? c[6] : c[5],
              2 => heat > 0.5 ? c[5] : c[4],
              _ => heat > 0.5 ? c[4] : c[3],
            };
            col = heat > 0.15 ? rimCol : ink;
            if (heat > 0.15) {
              p0.light(
                x.toDouble(),
                y.toDouble(),
                c[5],
                0.4 * heat * (q == 0 ? 1.0 : 0.6),
              );
            }
          } else if (e < 2.0 && q == 0 && heat > 0.4) {
            col = c[5];
          } else if ((vr || hr) && heat > 0.3) {
            final tip = vr && dy < -hd + 4.0;
            final sheen =
                (((x + y - t * 260.0) % 90.0 + 90.0) % 90.0 - 45.0).abs() < 3.0;
            col = tip || (sheen && heat > 0.5)
                ? kWhite
                : (vr && dy < 0.0
                    ? (heat > 0.6 ? c[6] : c[5])
                    : (heat > 0.6 ? c[3] : c[2]));
          } else {
            col = heat > 0.15 ? face[q][st] : ink;
          }
          p0.px(x.toDouble(), y.toDouble(), col);
        }
      }
      if (!settled) p.glow(d.cx, d.cy, hd + 6.0, c[4], 0.22 * heat);
      if (ki > 0.6 && ki < 1.8 && d.glint) {
        glints.add((d, (ki - 0.6) / 1.2, hd));
      }
    }

    for (final (d, u, hd) in glints) {
      if (u <= 0.0 || u >= 1.0) continue;
      final y = hd != 0.0 ? d.cy - hd : d.cy;
      transitionGlint(
        p,
        d.cx,
        y,
        9.0 * math.pow(math.sin(math.pi * u), 0.7),
        d.spin + u * 1.5,
        c[6],
        c[5],
      );
    }
  },
);
