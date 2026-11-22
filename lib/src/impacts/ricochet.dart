import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart' hide star;

import 'impacts_lib.dart';

final SimulatedEffect ricochetEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'impacts/ricochet',
    name: 'Ricochet',
    desc:
        'A tracer streaks down onto the floor, glances off with a white-hot star and skips away at an angle, leaving a glowing skid while sparks skitter along the ground.',
    category: 'impacts',
    tags: [
      'impact',
      'ricochet',
      'bullet',
      'tracer',
      'sparks',
      'ground',
      'directional',
      'one-shot',
    ],
    size: (232, 84),
    origin: (64, 60),
    duration: 1.1,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#4a1712',
        '#c9281f',
        '#f2561d',
        '#ff8a2a',
        '#ffe26b',
        '#fff3a6',
        '#ffffff',
      ],
      'stone': '#5b5079',
      'seed': 8,
    },
  ),
  onCreate: (o) => _RicochetSim(o),
);

const double _hitTime = 0.05;
const double _speed = 760.0;
const double _inAngle = 0.32;
const double _outAngle = -0.21;

void _tracer(
  Painter p,
  double hx,
  double hy,
  double a,
  double l,
  List<int> c, [
  double k = 1.0,
]) {
  final cs = math.cos(a);
  final sn = math.sin(a);
  for (var d = 0.0; d <= l; d += 0.5) {
    final u = d / l;
    p.dot(
      hx - cs * d,
      hy - sn * d,
      u < 0.12
          ? kWhite
          : (u < 0.45 ? c[5] : (u < 0.75 ? c[4] : c[2])),
      u < 0.45 ? 1.0 : k * (1.25 - u),
    );
  }
  p.glow(hx, hy, 9.0, c[4], 0.6 * k);
}

class _RicochetSim extends BaseEffectSim {
  static double _floor(double _) => 0.0;

  final List<int> c;
  final StonePalette st;
  final Rng r;
  final double duration = 1.1;
  late final Particles ps;
  final Lights lights = Lights();
  late final List<ImpactSpike> sp;
  double t = 0.0;
  bool hit = false;

  _RicochetSim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        st = stone(o['stone'] ?? '#5b5079'),
        r = Rng(o.seed) {
    ps = Particles(rng: r, ground: _floor, sparks: [c[6], c[5], c[4], c[2]]);
    sp = spikes(
      r,
      9,
      _outAngle,
      len: (6.0, 9.0),
      w: (1.4, 1.9),
      fwd: 2.6,
      back: 0.6,
    );
    for (final s in sp) {
      if (math.sin(s.a) > 0.2) s.len *= 0.3;
      if (math.sin(s.a - _outAngle).abs() > 0.6) s.len *= 0.65;
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (!hit && t >= _hitTime) {
      hit = true;
      lights.add(0.0, -2.0, 44.0, c[4], 0.65, 0.25);
      lights.add(0.0, -1.0, 14.0, kWhite, 0.6, 0.06);
      for (var i = 0; i < 18; i++) {
        final low = i < 12;
        final a = _outAngle +
            (low ? r.range(-0.22, 0.12) : r.range(-0.7, 0.25));
        final v = r.range(260.0, 520.0) * (low ? 1.0 : 0.7);
        ps.spawn(
          P.spark,
          r.range(-1.0, 2.0),
          -1.0,
          math.cos(a) * v,
          math.sin(a) * v,
          r.range(0.15, 0.42) * (low ? 1.3 : 1.0),
          kWhite,
          1.0,
          low ? r.range(0.0, 0.05) : 0.0,
        );
      }
      for (var i = 0; i < 7; i++) {
        final a = -math.pi / 2.0 + r.range(-0.2, 0.9);
        final v = r.range(60.0, 170.0);
        ps.spawn(
          P.grit,
          r.range(0.0, 4.0),
          -1.0,
          math.cos(a) * v,
          math.sin(a) * v,
          r.range(0.6, 0.95),
          r.pick([st.light, st.body, st.lip]),
          i < 2 ? 2.0 : 1.0,
        );
      }
      for (var i = 0; i < 4; i++) {
        ps.spawn(
          P.dust,
          r.range(0.0, 8.0),
          -1.0,
          r.range(20.0, 70.0),
          -r.range(4.0, 16.0),
          r.range(0.25, 0.45),
          mix(st.dust, kWhite, r.range(0.1, 0.3)),
          r.range(1.2, 2.0),
        );
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final u = t - _hitTime;
    if (u >= 0.0) {
      final heat = math.pow(clamp(1.0 - u / 0.85), 1.2).toDouble();
      final fade = 1.0 - smooth(duration - 0.4, duration - 0.05, t);
      final l = 12.0 * math.min(1.0, u / 0.03);
      for (var x = -3; x <= l; x++) {
        final q = (x + 3) / 15.0;
        final h = heat * (1.15 - q * 0.6);
        p.dot(
          x,
          0,
          h > 0.8
              ? kWhite
              : (h > 0.55
                  ? c[5]
                  : (h > 0.35
                      ? c[4]
                      : (h > 0.18
                          ? c[3]
                          : (h > 0.08 ? c[2] : kSoot)))),
          fade,
        );
        if (x > -2 && x < l - 2 && (x & 1) == 0) {
          p.dot(x, 1, h > 0.4 ? c[3] : kSoot, fade * 0.7);
        }
      }
      if (heat > 0.0) {
        p.glowLine(-3.0, 0.0, l, 0.0, 5.0, c[3], 0.45 * heat);
      }
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    ps.draw(p, 'front');
    if (t < _hitTime) {
      final d = (_hitTime - t) * _speed;
      _tracer(p, -math.cos(_inAngle) * d, -math.sin(_inAngle) * d, _inAngle, 22.0, c);
    } else {
      final u = t - _hitTime;
      if (u < 0.03) {
        star(p, 0.0, -1.0, sp, 1.0, 1.0, [c[2], c[5], c[4], kWhite], 1.0, 2.0);
      } else if (u < 0.06) {
        star(p, 0.0, -1.0, sp, 1.25, 0.55, [c[1], c[4], c[3], c[5]], 1.0, 2.0);
      }
      if (u < 0.2) {
        final head = 4.0 + u * _speed;
        final k = 1.0 - u / 0.2;
        _tracer(
          p,
          math.cos(_outAngle) * head,
          -1.0 + math.sin(_outAngle) * head,
          _outAngle,
          math.min(head - 2.0, 18.0 + u * 200.0),
          c,
          k,
        );
      }
      final g = (u - 0.02) / 0.2;
      if (g >= 0.0 && g < 1.0) {
        final rad = 5.0 + 12.0 * (1.0 - math.pow(1.0 - g, 3).toDouble());
        final col = g < 0.3 ? c[5] : (g < 0.6 ? c[4] : c[3]);
        final n = (rad * math.pi * 1.3).ceil();
        for (var j = 0; j <= n; j++) {
          final a = -math.pi + (j / n) * math.pi;
          p.dot(math.cos(a) * rad, -1.0 + math.sin(a) * rad, col, 1.15 - g);
        }
      }
      final pop = math.exp(-u / 0.045);
      if (pop > 0.02) {
        p.glow(0.0, -2.0, 22.0, c[3], 0.75 * pop);
        p.glow(0.0, -1.0, 8.0, kWhite, 0.5 * pop);
      }
    }
    lights.draw(p);
  }
}
