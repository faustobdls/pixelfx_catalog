// The rays and the white-hearted glints follow Sprite Fusion's open-source sparkle
// (https://www.spritefusion.com/pixel-art-vfx/sparkle), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'pickups_lib.dart';

const double _duration = 1.6;
const double _hover = 25.0;
const double _ro = 11.5;
const double _ri = 5.2;
const List<double> _beats = [0.25, 0.75];
const int _rays = 10;
final double _la = math.atan2(-0.8, -0.6);
final int _ink = hex('#1a0e04');
final SpriteLayer _starLayer = SpriteLayer(44, 44);

double _swell(double ph) {
  var s = 0.0;
  for (final b in _beats) {
    final u = (((ph - b) % 1.0) + 1.0) % 1.0;
    s += math.exp(-u * 14.0) * (1.0 - u * 2.5 > 0.0 ? 1.0 : 0.0);
  }
  return s;
}

void _star(
  Painter p,
  List<int> c,
  double cx,
  double cy,
  double rot,
  double sc,
) {
  final fx = cx.floor();
  final fy = cy.floor();
  _starLayer.begin(fx - 21, fy - 21);
  _starLayer.fill(fx - 21, fy - 21, fx + 20, fy + 20, (px, py) {
    final dx = (px - cx) / sc;
    final dy = (py - cy) / sc;
    final r = hypot(dx, dy);
    if (r > _ro + 0.5) return 0;
    var a = math.atan2(dy, dx) - rot + math.pi / 2.0;
    a = ((a % tau) + tau) % tau;
    final k = (a / (math.pi / 5.0)).floor();
    final half = k % 2;
    final tip = ((k ~/ 2) + half) * ((2.0 * math.pi) / 5.0);
    final tA = tip - math.pi / 2.0 + rot;
    final iA = tA + (half != 0 ? -1.0 : 1.0) * (math.pi / 5.0);
    final tx = math.cos(tA) * _ro;
    final ty = math.sin(tA) * _ro;
    final ix = math.cos(iA) * _ri;
    final iy = math.sin(iA) * _ri;
    final ex = ix - tx;
    final ey = iy - ty;
    final side = (dx - tx) * ey - (dy - ty) * ex;
    final cside = -tx * ey + ty * ex;
    if (side * cside < 0.0) return 0;
    final n = tA + (half != 0 ? -1.0 : 1.0) * (math.pi / 2.0);
    final l = math.cos(n - _la);
    final ridge = math.sin(math.atan2(dy, dx) - tA).abs() * r < 0.6;
    if (r < 1.2) return kWhite;
    final toLight = math.cos(tA - _la);
    if (ridge) return toLight > 0.3 ? kWhite : (toLight > -0.4 ? c[6] : c[5]);
    return c[l > 0.6
        ? 6
        : (l > 0.15 ? 5 : (l > -0.35 ? 4 : (l > -0.75 ? 3 : 2)))];
  });
  _starLayer.outline(_ink).draw(p);
}

final PureEffect powerStarEffect = PureEffect(
  meta: const EffectMeta(
    id: 'pickups/power-star',
    name: 'Power star',
    desc:
        'A fat bevelled star rocks side to side and swells on each beat, rays of light turning slowly behind it, sparks spinning off its points.',
    category: 'pickups',
    tags: ['pickup', 'star', 'power-up', 'invincible', 'bonus', 'loop'],
    size: (88, 84),
    origin: (44, 76),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#2a1604',
        '#5e3208',
        '#a05c0c',
        '#e09414',
        '#ffc626',
        '#ffe866',
        '#fff8c4',
        '#ffffff',
      ],
      'seed': 9,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _duration;
    final y = -_hover - 1.5 * math.sin(ph * tau * 2.0);
    final sw = _swell(ph);
    blobShadow(p, 0.0, 9.0 + 2.0 * sw, 0.7);
    final spin = ph * ((tau / _rays) * 2.0);
    for (var i = 0; i < _rays; i++) {
      final a = spin + (i * tau) / _rays;
      final len = (i % 2 != 0 ? 22.0 : 34.0) * (1.0 + 0.18 * sw);
      final ca = math.cos(a);
      final sa = math.sin(a);
      final w = i % 2 != 0 ? 0.06 : 0.09;
      p.shade(-len - 2.0, y - len - 2.0, len + 2.0, y + len + 2.0,
          (x, yy, out) {
        final rx = x;
        final ry = yy - y;
        final d = rx * ca + ry * sa;
        if (d < 8.0 || d > len) return null;
        final q = (rx * sa - ry * ca).abs();
        final hw = 0.5 + d * w;
        if (q > hw + 1.5) return null;
        out.l = q < hw * 0.5 ? c[6] : c[5];
        out.k = (0.32 + 0.22 * sw) *
            (q < hw ? 1.0 : 1.0 - (q - hw) / 1.5) *
            math.pow(1.0 - d / len, 1.2).toDouble() *
            math.min(1.0, (d - 8.0) / 4.0);
        return null;
      });
      if (i % 2 == 0) {
        const d0 = _ro + 3.0;
        final d1 = math.min(
          len * 0.88,
          sa > 0.05 ? (-2.0 - y) / sa : double.infinity,
        );
        if (d1 > d0) {
          p.lineShaded(
            ca * d0,
            y + sa * d0,
            ca * d1,
            y + sa * d1,
            color: (u) => u < 0.35 ? c[6] : c[5],
            alpha: (u) => (u < 0.5 ? 1.0 : 1.6 - u * 1.4) * (0.75 + 0.35 * sw),
          );
        }
      }
    }
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final seed = o.seed;
    final ph = t / _duration;
    final y = -_hover - 1.5 * math.sin(ph * tau * 2.0);
    final sw = _swell(ph);
    final rot = 0.22 * math.sin(ph * tau);
    final sc = 1.0 + 0.13 * sw;
    p.glowRing(0.0, y, _ro * sc + 3.0, 13.0, c[4], 0.32 + 0.25 * sw);
    p.glow(0.0, y, 6.0, c[6], 0.12 + 0.2 * sw);
    _star(p, c, 0.0, y, rot, sc);
    for (final b in _beats) {
      final age = ((((ph - b) % 1.0) + 1.0) % 1.0) * _duration;
      if (age > 0.45) continue;
      for (var i = 0; i < 5; i++) {
        final a = rot + (i * tau) / 5.0 - math.pi / 2.0;
        final sp = 70.0 + rand(i, (b * 10.0).toInt(), 3) * 30.0;
        const tan = 35.0;
        final vx = math.cos(a) * sp - math.sin(a) * tan;
        final vy = math.sin(a) * sp + math.cos(a) * tan;
        final (x, yy) = fly(
          math.cos(a) * _ro * sc,
          y + math.sin(a) * _ro * sc,
          vx,
          vy,
          age,
          60.0,
          4.0,
        );
        final k = 1.0 - age / 0.45;
        glint(
          p,
          x,
          yy,
          (2.0 * k + 0.5).floorToDouble(),
          k > 0.5 ? kWhite : c[6],
          0.45 * k,
        );
      }
    }
    final f = (ph * 24.0).floor();
    for (var i = 0; i < 18; i++) {
      if (rand(f + i * 3, i, seed) > 0.32) continue;
      final a = rand(i, 1, seed) * tau;
      final d = 13.0 + rand(i, 2, seed) * 20.0;
      final sy = y + math.sin(a) * d * 0.85;
      if (sy < -2.0) {
        p.px(math.cos(a) * d, sy, rand(f, i, 5) < 0.5 ? kWhite : c[6]);
      }
    }
    for (var i = 0; i < 4; i++) {
      const life = 0.3;
      final age = (((t - ((i + 0.3) / 4.0) * _duration) % _duration) +
              _duration) %
          _duration;
      if (age > life) continue;
      final a = rand(i, 7, seed) * tau;
      final d = 15.0 + rand(i, 8, seed) * 12.0;
      final k = math.sin((age / life) * math.pi);
      glint(
        p,
        math.cos(a) * d,
        y + math.sin(a) * d * 0.85,
        (2.5 * k + 0.5).floorToDouble(),
        i % 2 != 0 ? c[6] : kWhite,
        0.4 * k,
      );
    }
    final g = ((ph + 0.1) % 0.5) / 0.5;
    if (g < 0.14) {
      glint(
        p,
        -2.0 + rot * 4.0,
        y - 6.0,
        3.0 * math.sin((g / 0.14) * math.pi),
        kWhite,
        0.5,
      );
    }
  },
);
