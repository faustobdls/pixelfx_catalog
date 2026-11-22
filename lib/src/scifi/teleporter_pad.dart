import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'scifi_lib.dart';

const double _duration = 2.4;
const double _rx = 31.0;
const double _ry = 7.0;
const double _py = -3.0;
const double _inner = 0.78;
const double _high = -84.0;

final Map<String, Ghosts> _cache = {};

Ghosts _ghosts(Map<String, Object?> o, List<int> c) {
  final pal = o.palette;
  final key = '${o.seed}:${pal.join(',')}';
  final hit = _cache[key];
  if (hit != null) return hit;

  final rn = Rng(o.seed);
  final g = Ghosts(_duration, box: (-46.0, -90.0, 46.0, 10.0));
  for (var i = 0; i < 40; i++) {
    final a = rn.range(0.0, tau);
    final r = math.sqrt(rn.next()) * _rx * _inner * 0.9;
    final star = i % 3 == 0;
    g.add(
      rn.range(0.0, _duration),
      star ? P.star : P.mote,
      math.cos(a) * r,
      _py + math.sin(a) * r * (_ry / _rx),
      rn.range(-4.0, 4.0),
      -rn.range(30.0, 75.0),
      rn.range(0.7, 1.3),
      rn.pick([kWhite, c[6], c[5]]),
      star ? rn.range(1.8, 3.4) : rn.range(0.6, 1.2),
    );
  }
  _cache[key] = g;
  return g;
}

void _pad(Painter p, double t, List<int> c, List<int> h) {
  final ph = t / _duration;
  p.shade(-_rx - 1, _py - _ry - 1, _rx + 1, 2, (x, y, out) {
    final u = x / _rx;
    final v = (y - _py) / _ry;
    final d = math.sqrt(u * u + v * v);
    if (d > 1.0) {
      final sideV = (y - 3.0 - _py) / _ry;
      if (x.abs() <= _rx &&
          y > _py &&
          y <= 1.0 &&
          math.sqrt(u * u + sideV * sideV) <= 1.0) {
        out.c = y == 1.0 || x.abs() > _rx - 1.0
            ? h[0]
            : (x < -_rx * 0.4 ? h[3] : (x > _rx * 0.4 ? h[1] : h[2]));
      }
      return null;
    }
    if (d > 0.97) {
      out.c = h[0];
      return null;
    }
    if (d > _inner) {
      out.c = (d - (_inner + 0.1)).abs() < 0.03
          ? h[1]
          : (d < _inner + 0.03
              ? c[3]
              : (v < -0.3 ? h[5] : (v < 0.2 ? h[4] : h[3])));
      return null;
    }
    final r = d / _inner;
    final ring = ((((r * 3.0 - ph * 3.0) % 1.0) + 1.0) % 1.0) < 0.16;
    final heat = math.pow(1.0 - r, 1.5).toDouble();
    out.c = r > 0.94
        ? c[3]
        : (ring
            ? (heat > 0.3 ? kWhite : c[6])
            : (heat > 0.55
                ? c[6]
                : (heat > 0.25 ? c[5] : (r > 0.8 ? c[3] : c[4]))));
    return null;
  });

  for (var i = 0; i < 10; i++) {
    final a = (i / 10.0) * tau + 0.15;
    final x = math.cos(a) * _rx * 0.885;
    final y = _py + math.sin(a) * _ry * 0.885;
    final k = 0.5 + 0.5 * math.cos(tau * (2.0 * ph - i / 10.0));
    p.px(x, y, k > 0.7 ? kWhite : (k > 0.4 ? c[5] : c[2]));
    if (k > 0.5) p.glow(x, y, 4, c[4], 0.35 * k);
  }
}

void _lift(Painter p, double t, List<int> c, bool near) {
  for (var i = 0; i < 4; i++) {
    final k = since(t, (i / 4.0) * _duration, _duration) / 1.25;
    if (k >= 1.0) continue;
    final y = lerp(_py, _high + 12.0, math.pow(k, 0.85).toDouble());
    final rx = _rx * _inner * (1.0 + 0.08 * k);
    final ry = rx * (_ry / _rx);
    final col = k < 0.12
        ? kWhite
        : (k < 0.4 ? c[6] : (k < 0.65 ? c[5] : (k < 0.85 ? c[4] : c[3])));
    final glint = ((i * 0.37 + k * 1.5) % 1.0) * tau;
    final n = (rx * 7.0).ceil();
    for (var j = 0; j < n; j++) {
      final g = (j / n) * tau;
      final sg = math.sin(g);
      if ((sg >= 0.0) != near) continue;
      final x = math.cos(g) * rx;
      final yy = y + sg * ry;
      final hot = (((g - glint + math.pi * 3.0) % tau) - math.pi).abs() < 0.25;
      if (k > 0.85 && (j & 1) != 0) continue;
      p.px(
        x,
        yy,
        hot && k < 0.8 ? kWhite : (near ? col : (k < 0.4 ? c[5] : c[3])),
      );
      if (k < 0.3) p.px(x, yy + 1.0, near ? c[5] : c[3]);
    }
    if (near) p.glow(0, y + ry * 0.5, rx + 8.0, c[4], 0.22 * (1.0 - k));
  }
}

void _drawBack(Painter p, double t, Map<String, Object?> o) {
  final c = fit(o.palette, 8);
  final h = fit(o.rampOpt('metal'), 6);
  _pad(p, t, c, h);
  const w = _rx * _inner;
  for (var y = _high.toInt(); y < _py; y++) {
    final v = (y - _py) / (_high - _py);
    final fade = math.pow(1.0 - v, 1.6).toDouble();
    for (var x = (-w).floor(); x <= w.ceil(); x++) {
      final q = (x + 0.5).abs() / w;
      if (q > 1.0) continue;
      p.blend(
        x + 0.5,
        y + 0.5,
        q > 0.9 ? c[6] : c[5],
        fade *
            (0.07 +
                0.26 * math.pow(q, 4).toDouble() +
                0.12 * math.pow(1.0 - v, 4).toDouble()),
      );
    }
  }
  cycle(t, _duration, 30, o.seed + 3, (r) => r.range(0.6, 1.1),
      (age, life, r, _) {
    final k = age / life;
    final x = r.range(-0.9, 0.9) * w;
    final y = lerp(_py - 2.0, _high + 10.0, k);
    final l = 3.0 + 7.0 * k;
    p.lineShaded(
      x,
      y,
      x,
      y + l,
      color: (u) => u < 0.3 ? c[6] : c[4],
      alpha: (_) => (1.0 - k) * 1.2,
    );
  });
  _lift(p, t, c, false);
  for (var y = _py - 6.0; y > _high + 20.0; y -= 12.0) {
    p.glow(0, y, w + 8.0, c[4], 0.16 * (1.0 - (y - _py) / (_high - _py)));
  }
}

void _draw(Painter p, double t, Map<String, Object?> o) {
  final c = fit(o.palette, 8);
  final ph = t / _duration;
  _lift(p, t, c, true);
  _ghosts(o, c).at(t).draw(p);
  final k = 0.85 + 0.15 * math.sin(tau * 2.0 * ph);
  for (final x in const [-_rx * 0.6, 0.0, _rx * 0.6]) {
    p.glow(x, _py, 20, c[4], 0.25 * k);
  }
  p.glow(0, _py, 10, kWhite, 0.3 * k);
}

final PixelEffect teleporterPadEffect = PureEffect(
  meta: const EffectMeta(
    id: 'scifi/teleporter-pad',
    name: 'Teleporter pad',
    desc:
        'A steel pad glows on the floor, its rings rippling outward; a soft column of light rises off it and rings of light lift away, sparkles drifting up through them.',
    category: 'scifi',
    tags: [
      'scifi',
      'teleporter',
      'pad',
      'portal',
      'beam',
      'spawn',
      'ground',
      'loop',
    ],
    size: (96, 104),
    origin: (48, 92),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#120a26',
        '#26145a',
        '#3c2296',
        '#5a3ad2',
        '#7f66f0',
        '#b4a2ff',
        '#e6deff',
        '#ffffff',
      ],
      'metal': [
        '#0e0d14',
        '#1e1c27',
        '#312e3e',
        '#4b4759',
        '#6f6a82',
        '#9d98b0',
      ],
      'seed': 26,
    },
  ),
  onDrawBack: _drawBack,
  onDraw: _draw,
);
