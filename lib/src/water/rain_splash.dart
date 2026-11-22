// The streaks falling in (a dim body, a bright head) follow Sprite Fusion's open-source rain
// (https://www.spritefusion.com/pixel-art-vfx/rain), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'water_lib.dart';

const double _d = 2.4;
const double _sy = 0.3;
const double _rx = 92.0;
const double _g = 640.0;
const int _n = 8;
const double _lamp = 34.0;

class _DropData {
  final double x;
  final double z;
  final double t0;
  final double h;
  final double j;
  final double spin;
  final int i;

  _DropData({
    required this.x,
    required this.z,
    required this.t0,
    required this.h,
    required this.j,
    required this.spin,
    required this.i,
  });
}

class _ActiveRing {
  final _DropData q;
  final double a;
  final double r;
  final double k;

  _ActiveRing(this.q, this.a, this.r, this.k);
}

List<_DropData> _drops(int s) => List.generate(_n, (i) {
      return _DropData(
        x: (rand(i, s) - 0.5) * 120.0,
        z: (rand(i, s + 1) - 0.5) * 50.0,
        t0: ((i + 0.25 * rand(i, s + 2)) / _n) * _d,
        h: 10.0 + 4.0 * rand(i, s + 3),
        j: 7.0 + 4.0 * rand(i, s + 4),
        spin: rand(i, s + 5) * tau,
        i: i,
      );
    });

double _ageOf(double t, double t0) => (((t - t0) % _d) + _d) % _d;
double _ringR(double a) => 3.0 + 34.0 * math.pow(a / 1.8, 0.7);
double _ringK(double a) => a < 1.8
    ? 1.3 * math.pow(1.0 - a / 1.8, 1.3) * math.min(1.0, a / 0.06)
    : 0.0;
double _crownH(double a, double h) =>
    h * math.pow(math.sin(math.pi * clamp(a / 0.3)), 0.8) * (a < 0.3 ? 1.0 : 0.0);
double _crownR(double a) => 1.5 + 4.5 * math.sqrt(clamp(a / 0.3));
double _jetH(double a, double j) => (a > 0.26 && a < 0.56)
    ? j * math.sin((math.pi * (a - 0.26)) / 0.3)
    : 0.0;

double _field(double x, double z, List<_ActiveRing> list) {
  var h = 0.0;
  for (final item in list) {
    final dx = x - item.q.x;
    if (dx > item.r + 10.0 || dx < -item.r - 10.0) continue;
    final d = hypot(dx, z - item.q.z) - item.r;
    final w = 3.6 + item.a * 3.0;
    if (d > 2.0 * w || d < -3.0 * w) continue;
    h += item.k * math.cos(d * 1.1) * math.exp(-((d / w) * (d / w)));
  }
  return h;
}

void _crown(Painter p, List<int> c, _DropData q, double a, bool back) {
  final h = _crownH(a, q.h);
  if (h < 1.0) return;
  final r0 = _crownR(a);
  final cy = q.z * _sy;
  for (var f = 0; f < 10; f++) {
    final ang = q.spin + (f / 10.0) * tau;
    final s = math.sin(ang);
    if ((s < 0.0) != back) continue;
    final tip = h * (0.75 + 0.25 * rand(q.i, f, 7));
    final lean = 0.35 * tip;
    final x0 = q.x + math.cos(ang) * r0;
    final y0 = cy + s * r0 * _sy;
    final x1 = q.x + math.cos(ang) * (r0 + lean);
    final y1 = cy + s * (r0 + lean) * _sy - tip;
    p.lineShaded(
      x0,
      y0,
      x1,
      y1,
      color: back
          ? (u) => u > 0.7 ? c[5] : c[3]
          : (u) => u > 0.75 ? kWhite : (u > 0.35 ? c[6] : c[5]),
    );
    if (a > 0.08 && a < 0.17) p.px(x1, y1 - 1.0, back ? c[5] : kWhite);
  }
  if (!back) p.glow(q.x, cy - h * 0.6, 6.0 + h * 0.6, c[5], 0.3 * (h / q.h));
}

final PureEffect rainSplashEffect = PureEffect(
  meta: const EffectMeta(
    id: 'water/rain-splash',
    name: 'Rain splash',
    desc:
        "A low close-up on one puddle in the rain: big drops land in crowns that throw beads and a rebound jet, rings spread and interfere, a lamp's reflection wobbles on the water.",
    category: 'water',
    tags: ['water', 'rain', 'splash', 'puddle', 'close-up', 'ambient', 'loop'],
    size: (176, 80),
    origin: (88, 50),
    duration: 2.4,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': kWaterPalette,
      'seed': 9,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final s = o.seed;
    const ry = _rx * _sy;
    final ph = t / _d;
    final dropList = _drops(s);
    final list = <_ActiveRing>[
      for (final q in dropList)
        if (_ageOf(t, q.t0) < 1.8)
          _ActiveRing(
            q,
            _ageOf(t, q.t0),
            _ringR(_ageOf(t, q.t0)),
            _ringK(_ageOf(t, q.t0)),
          ),
    ];
    for (var yi = (-ry).floor(); yi < ry; yi++) {
      final y = yi + 0.5;
      final z = y / _sy;
      final act = <_ActiveRing>[
        for (final item in list)
          if ((z - item.q.z).abs() <= item.r + 12.0) item,
      ];
      final far = (y + ry) / (2.0 * ry);
      final dashW = (1.5 + far * 4.0) *
          (0.35 +
              0.65 *
                  (0.5 +
                      0.5 *
                          math.sin(
                            yi * 1.73 + ph * tau * 3.0 + math.sin(yi * 0.61) * 3.0,
                          )));
      var hPrev = 0.0;
      for (var xi = -88; xi < 88; xi++) {
        final x = xi + 0.5;
        final d = (x / _rx) * (x / _rx) + (y / ry) * (y / ry);
        if (d > 1.0) continue;
        final edge = math.min(1.0, (1.0 - d) * 6.0);
        p.blend(x, y, c[0], (0.62 + 0.2 * far) * edge);
        if (far < 0.45) p.blend(x, y, c[2], 0.3 * (1.0 - far / 0.45) * edge);
        final h = act.isNotEmpty ? _field(x, z, act) : 0.0;
        final hx = h - hPrev;
        hPrev = h;
        if (h > 0.24) {
          p.blend(
            x,
            y,
            h > 0.75 ? c[5] : c[4],
            math.min(0.95, (h - 0.24) * 2.2) * edge,
          );
        } else if (h < -0.4) {
          p.blend(x, y, c[0], math.min(0.85, (-h - 0.4) * 1.8) * edge);
        }
        if (x < _lamp - 14.0 || x > _lamp + 14.0) continue;
        final lx = (x -
                _lamp -
                hx * 9.0 -
                math.sin(y * 0.8 + ph * tau * 2.0) * 1.4)
            .abs();
        if (lx < dashW) {
          final k = (1.0 - lx / dashW) * edge;
          p.px(xi, yi, k > 0.72 ? kWhite : (k > 0.35 ? c[6] : c[5]));
          p.light(x, y, c[5], 0.2 * k);
        }
      }
    }
    for (var xi = -82; xi < 82; xi++) {
      final x = xi + 0.5;
      final y = -math.sqrt(math.max(0.0, 1.0 - (x / _rx) * (x / _rx))) * ry;
      p.px(xi, y + 0.5, (x - _lamp).abs() < 10.0 ? c[6] : c[3]);
    }
    for (final q in dropList) {
      _crown(p, c, q, _ageOf(t, q.t0), true);
    }
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final s = o.seed;
    final dropList = _drops(s);
    for (final q in dropList) {
      final a = _ageOf(t, q.t0);
      final cy = q.z * _sy;
      final pre = _d - a;
      if (pre < 0.14 && cy - pre * 520.0 - 10.0 > -48.0) {
        final y = cy - pre * 520.0;
        p.line(q.x, y - 10.0, q.x, y - 4.0, c[4]);
        p.line(q.x, y - 4.0, q.x, y, c[6]);
      }
      if (a < 0.05) {
        p.px(q.x, cy, kWhite);
        p.glow(q.x, cy - 2.0, 12, c[5], 0.5 * (1.0 - a / 0.05));
      }
      _crown(p, c, q, a, false);
      if (a > 0.16 && a < 0.8) {
        for (var f = 0; f < 10; f += 2) {
          final ang = q.spin + (f / 10.0) * tau;
          final tip = _crownH(0.16, q.h) * (0.75 + 0.25 * rand(q.i, f, 7));
          final r0 = _crownR(0.16) + tip * 0.35;
          final v = 22.0 + 18.0 * rand(q.i, f, 8);
          final vh = 40.0 + 30.0 * rand(q.i, f, 9);
          final tt = a - 0.16;
          final hh = tip + vh * tt - 0.5 * _g * tt * tt;
          final bx = q.x + math.cos(ang) * (r0 + v * tt);
          final bz = q.z + math.sin(ang) * (r0 + v * tt);
          final by = bz * _sy;
          if (hh > 0.0) {
            bead(
              p,
              bx,
              by - hh,
              math.cos(ang) * v,
              -(vh - _g * tt) + math.sin(ang) * v * _sy,
              rand(q.i, f, 10) < 0.4 ? 2 : 1,
              c,
            );
          } else {
            final land = (vh + math.sqrt(vh * vh + 2.0 * _g * tip)) / _g;
            final since = tt - land;
            if (since < 0.05) p.px(bx, by, kWhite);
            if (since < 0.35) {
              ring(
                p,
                bx,
                by,
                1.0 + since * 12.0,
                _sy,
                1.0 - since / 0.35,
                c,
                n: 1,
                half: 1,
                seed: q.i * 10 + f,
              );
            }
          }
        }
      }
      final jh = _jetH(a, q.j);
      if (jh > 0.8) {
        p.lineShaded(
          q.x,
          cy - 1.0,
          q.x,
          cy - jh,
          color: (u) => u > 0.6 ? kWhite : c[6],
        );
        p.px(q.x + 1.0, cy - 1.0, c[5]);
        if (a < 0.41) p.circle(q.x, cy - jh - 0.5, 1.2, c[6]);
        p.glow(q.x, cy - jh * 0.6, 6, c[5], 0.3);
      }
      final ba = a - 0.41;
      final bh = q.j + 1.0 + 24.0 * ba - 0.5 * _g * ba * ba;
      if (ba > 0.0 && bh > 0.0) {
        p.circle(q.x, cy - bh, 1.1, c[6]);
        p.px(q.x, cy - bh - 1.0, kWhite);
      }
    }
    for (final q in dropList) {
      final a = _ageOf(t, q.t0);
      if (a < 1.8) {
        ring(
          p,
          q.x,
          q.z * _sy,
          _ringR(a),
          _sy,
          0.75 * _ringK(a),
          c,
          n: 1,
          half: 1,
          hot: a < 0.1,
          seed: q.i,
          wob: 0.5 + a,
        );
      }
    }
    cycleFixed(t, _d, 16, s + 20, 0.5, (age, life, r, _) {
      final x = r.range(-80.0, 80.0);
      final z = r.range(-26.0, 26.0);
      final y = z * _sy;
      final st = age - 0.1;
      if (st < 0.0) {
        final yy = y - (0.1 - age) * 600.0;
        if (yy - 6.0 < -48.0) return;
        p.lineShaded(x, yy - 6.0, x, yy, color: (u) => u > 0.6 ? c[5] : c[3]);
      } else if (st < 0.4 &&
          (x / _rx) * (x / _rx) + (y / (_rx * _sy)) * (y / (_rx * _sy)) < 0.9) {
        if (st < 0.04) p.px(x, y, c[6]);
        ring(
          p,
          x,
          y,
          1.0 + st * 9.0,
          _sy,
          0.8 * (1.0 - st / 0.4),
          c,
          n: 1,
          half: 1,
          seed: 40,
        );
      }
    });
    p.glow(_lamp, -6, 30, c[4], 0.16);
  },
);
