import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const double _tilt = 0.24;
const double _duration = 2.0;

double _radius(double h, double height) =>
    4.0 + 28.0 * math.pow(clamp(h / height), 1.35);

double _axis(double h, double height, double ph) =>
    (5.0 * math.sin(tau * ph + h * 0.05) +
            1.5 * math.sin(tau * ph * 2.0 - h * 0.11)) *
        (h / height) -
    2.0 * (h / height);

void _streaks(
  Painter p,
  List<int> c,
  double t,
  Map<String, Object?> o,
  bool front,
) {
  final height = o.numOpt('height', 80.0);
  final ph = t / _duration;
  cycle(t, _duration, 58, o.seed + 9, (g) => g.range(0.5, 0.9),
      (age, life, r, _) {
    final h0 = r.range(2, height);
    final w = r.range(8, 12) * (1.45 - h0 / height);
    final th = r.range(0, tau) + age * w;
    final k = age / life;
    final fade =
        math.min(1.0, age / 0.08) * (k > 0.7 ? (1.0 - k) / 0.3 : 1.0);
    final len = r.range(0.7, 1.5);
    final m = (len / 0.07).ceil();
    for (var j = 0; j <= m; j++) {
      final a = th - j * 0.07;
      final s = math.sin(a);
      if ((s >= 0.0) != front) continue;
      final h = math.min(height + 4.0, h0 + age * 16.0 - j * 0.25);
      final rad = _radius(math.min(h, height), height) *
          (1.0 + math.min(0.3, math.max(0.0, h - height * 0.84) * 0.03));
      final u = j / m;
      final x = _axis(math.min(h, height), height, ph) + math.cos(a) * rad;
      final y = -h + s * rad * _tilt;
      final col = front
          ? (u < 0.15 ? kWhite : (u < 0.5 ? c[6] : c[5]))
          : (u < 0.3 ? c[5] : (u < 0.6 ? c[4] : c[3]));
      p.dot(
        x,
        y,
        col,
        fade * (u < 0.6 ? 1.0 : 1.5 - u * 1.2) * (front ? 1.0 : 0.85),
      );
    }
  });
}

void _body(Painter p, List<int> c, double ph, double height) {
  p.each(-44, -height - 6.0, 44, 2, (x, y, sx, sy) {
    final h = -y;
    if (h < 0.0 || h > height + 4.0) return;
    final rad = _radius(h, height);
    final dx = x - _axis(h, height, ph);
    final u = dx / rad;
    if (u * u >= 1.0) return;
    final k = h / height;
    final rim = math.pow(u.abs(), 3.0).toDouble();
    final swirl =
        math.sin(math.asin(u) * 3.0 - tau * ph * 2.0 + h * 0.2) * 0.5 + 0.5;
    final a = (0.07 + 0.24 * rim + 0.12 * swirl) *
        clamp((1.0 - u.abs()) / 0.18) *
        (k > 0.7 ? math.max(0.0, (1.0 - k) / 0.3) : 1.0) *
        (h < 4.0 ? h / 4.0 : 1.0);
    if (a < 0.03) return;
    p.blendPx(sx, sy, rim > 0.5 ? c[6] : (swirl > 0.6 ? c[5] : c[4]), a);
    if (rim > 0.3 || swirl > 0.75) {
      p.add(
        sx,
        sy,
        c[5],
        0.16 * math.max(rim, swirl - 0.5) * (1.0 - k * 0.5),
      );
    }
  });
}

void _orbiters(
  Painter p,
  List<int> c,
  double t,
  Map<String, Object?> o,
  bool front,
) {
  final height = o.numOpt('height', 80.0);
  final ph = t / _duration;
  cycle(t, _duration, 76, o.seed, (g) => g.range(0.9, 1.6),
      (age, life, r, i) {
    final h0 = r.range(0, height * 0.6);
    final h = h0 + age * r.range(14, 30);
    final k = age / life;
    if (h > height + 8.0) return;
    final w = r.range(7, 11) * (1.5 - h / height);
    final th = r.range(0, tau) + age * w;
    final out = 1.0 +
        r.range(0.05, 0.3) +
        math.min(0.35, math.max(0.0, h - height * 0.82) * 0.04);
    final rad = _radius(math.min(h, height), height) * out;
    final s = math.sin(th);
    if ((s >= 0.0) != front) return;
    final x = _axis(math.min(h, height), height, ph) + math.cos(th) * rad;
    final y = -h + s * rad * _tilt;
    final big = i % 5 == 0;
    final fade =
        math.min(1.0, age / 0.1) * (k > 0.8 ? (1.0 - k) / 0.2 : 1.0);
    if (fade <= 0.0) return;
    final th2 = th - 0.25;
    final x2 = _axis(math.min(h, height), height, ph) + math.cos(th2) * rad;
    final y2 = -h + 2.0 + math.sin(th2) * rad * _tilt;
    if (front) {
      p.lineShaded(
        x2,
        y2,
        x,
        y,
        color: (u) => u > 0.6 ? c[6] : c[4],
        alpha: (u) => u * fade,
      );
      p.dot(x, y, big ? kWhite : (r.chance(0.5) ? kWhite : c[6]), fade);
      if (big) {
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          p.dot(x + dx, y + dy, c[6], fade);
        }
        p.glow(x, y, 5, c[5], 0.35 * fade);
      }
    } else {
      p.lineShaded(x2, y2, x, y, color: (_) => c[3], alpha: (u) => u * fade * 0.8);
      p.dot(x, y, big ? c[5] : c[4], fade);
    }
  });
}

void _foot(
  Painter p,
  List<int> c,
  double t,
  Map<String, Object?> o,
  bool front,
) {
  final ph = t / _duration;
  cycle(t, _duration, 12, o.seed + 5, (g) => g.range(0.8, 1.2),
      (age, life, r, _) {
    final th = r.range(0, tau) + age * r.range(4, 6);
    final rad = 9.0 + age * r.range(8, 16);
    final s = math.sin(th);
    final k = age / life;
    if ((s >= 0.0) != front) return;
    final x = _axis(0.0, 1.0, ph) + math.cos(th) * rad;
    final y = -2.0 - age * r.range(4, 10) + s * rad * 0.2;
    final puffR = 2.0 + 4.0 * k;
    final a = 0.5 * math.pow(1.0 - k, 1.2) * math.min(1.0, age / 0.1);
    p.discShaded(
      x,
      y,
      puffR,
      color: (_, _) => front ? c[6] : c[5],
      alpha: (d, _) => a * (1.0 - d * d),
    );
    p.discShaded(
      x - puffR * 0.25,
      y - puffR * 0.3,
      puffR * 0.5,
      color: (_, _) => kWhite,
      alpha: (d, _) => a * 0.5 * (1.0 - d * d) * (1.0 - k),
    );
  });
}

final PureEffect blizzardVortexEffect = PureEffect(
  meta: const EffectMeta(
    id: 'ice/blizzard-vortex',
    name: 'Blizzard vortex',
    desc:
        'A swirling snow tornado: wind bands spin up a leaning funnel, flakes and ice crystals orbit in front and behind, snow boils at its foot and cold light fills its throat.',
    category: 'ice',
    tags: ['ice', 'snow', 'blizzard', 'tornado', 'vortex', 'wind', 'loop'],
    size: (128, 116),
    origin: (64, 102),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#151a3d', '#212f6b', '#2c58aa', '#3a8bd8',
        '#62c8f4', '#a6ecff', '#dcfbff', '#ffffff',
      ],
      'height': 80,
      'seed': 17,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    for (var x = -30; x <= 30; x++) {
      final d = x.abs() / 30.0;
      final hgt = ((1.0 - d * d) * (1.5 + rand(x, 3) * 1.5) + 0.5).floor();
      for (var j = 0; j < hgt; j++) {
        p.px(x, -j, j == hgt - 1 ? kWhite : c[5]);
      }
      p.dot(x, 0, c[6], 1.0 - d * 0.5);
      p.dot(x, 1, c[4], 0.8 - d * 0.6);
    }
    p.glow(0, -2, 40, c[4], 0.22);
    _foot(p, c, t, o, false);
    _streaks(p, c, t, o, false);
    _orbiters(p, c, t, o, false);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final height = o.numOpt('height', 80.0);
    final ph = t / _duration;
    _body(p, c, ph, height);
    p.glow(_axis(height * 0.45, height, ph), -height * 0.45, 40, c[4], 0.3);
    p.glow(
      _axis(height * 0.15, height, ph),
      -height * 0.15,
      18,
      c[5],
      0.4 + 0.1 * math.sin(tau * ph * 4.0),
    );
    p.glow(_axis(height * 0.05, height, ph), -3, 10, kWhite, 0.3);
    _streaks(p, c, t, o, true);
    _orbiters(p, c, t, o, true);
    _foot(p, c, t, o, true);
    cycle(t, _duration, 10, o.seed + 3, (g) => g.range(0.9, 1.3),
        (age, life, r, _) {
      final th = r.range(0, tau);
      final rad = _radius(height, height) * (0.6 + age * 0.9);
      final k = age / life;
      final puffR = 3.0 + 6.0 * k;
      final rc = math.min(rad, 36.0);
      final x = _axis(height, height, ph) + math.cos(th) * rc;
      final y = -height - 2.0 - age * 4.0 + math.sin(th) * rc * _tilt;
      final a = 0.24 * (1.0 - k) * math.min(1.0, age / 0.15);
      p.discShaded(
        x,
        y,
        puffR * 0.8,
        color: (_, _) => c[6],
        alpha: (d, _) => a * (1.0 - d * d),
      );
      p.glow(x, y, puffR * 1.5, c[4], 0.08 * (1.0 - k));
    });
  },
);
