import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'projectiles_lib.dart';

const _rocketMeta = EffectMeta(
  id: 'projectiles/rocket',
  name: 'Rocket',
  desc:
      'A steel rocket roars along: a flickering jet with shock diamonds and a white-hot nozzle, a thick billowing smoke trail lit by the flame, sparks shed behind.',
  category: 'projectiles',
  tags: ['projectile', 'rocket', 'missile', 'smoke', 'fire', 'directional', 'loop'],
  size: (288, 76),
  origin: (252, 42),
  duration: 1.2,
  loop: true,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': [
      '#4a1712',
      '#8a1f17',
      '#c9281f',
      '#f2561d',
      '#ff8a2a',
      '#ffc23d',
      '#ffe26b',
      '#fff3a6',
      '#ffffff',
    ],
    'metal': [
      '#0f0d16',
      '#25243a',
      '#3e4058',
      '#61667f',
      '#8e97b0',
      '#c4cce0',
      '#f2f6ff',
    ],
    'paint': ['#3a0d14', '#7c1a22', '#bd2f2c', '#ec5a45', '#ff9b7e'],
    'smoke': [
      '#26222e',
      '#3d3846',
      '#5a5463',
      '#7e7887',
      '#a7a1ad',
      '#d0cad2',
      '#f1ecee',
    ],
    'speed': 120,
    'seed': 5,
  },
);

final _outline = hex('#100d17');
const _nozzle = -14.0;
const _j0 = 22.0;

final _ship = pixelShape(-15, -9, 30, 19, (set) {
  const body = {-3: '4', -2: '6', -1: '5', 0: '4', 1: '3', 2: '2', 3: '1'};
  const seam = {-3: '3', -2: '4', -1: '4', 0: '3', 1: '2', 2: '1', 3: '1'};
  const paint = {-3: 'd', -2: 'e', -1: 'e', 0: 'd', 1: 'c', 2: 'b', 3: 'a'};
  for (var y = -3; y <= 3; y++) {
    for (var x = -11; x <= 5; x++) {
      set(x, y, body[y]!);
    }
  }
  for (var y = -3; y <= 3; y++) {
    set(-3, y, seam[y]!);
    set(-9, y, paint[y]!);
    set(-8, y, paint[y]!);
  }
  const nose = {6: 3, 7: 3, 8: 2, 9: 2, 10: 1, 11: 1, 12: 0, 13: 0};
  for (final entry in nose.entries) {
    for (var y = -entry.value; y <= entry.value; y++) {
      set(entry.key, y, paint[y]!);
    }
  }
  set(7, -2, 'w');
  set(8, -2, 'w');
  set(9, -1, 'e');
  set(13, 0, 'e');
  const finSpans = [(-13, -8), (-13, -9), (-13, -10), (-13, -11)];
  for (var i = 0; i < finSpans.length; i++) {
    final (a, b) = finSpans[i];
    for (var x = a; x <= b; x++) {
      set(
        x,
        -4 - i,
        x == b
            ? '5'
            : i > 1
                ? '4'
                : '3',
      );
      set(
        x,
        4 + i,
        x == b
            ? '3'
            : i > 1
                ? '1'
                : '2',
      );
    }
  }
  for (var y = -2; y <= 2; y++) {
    set(-12, y, y < 0 ? '3' : '2');
  }
  for (var y = -3; y <= 3; y++) {
    set(-13, y, y < -1 ? '2' : '1');
  }
  set(-14, -3, 'h');
  set(-14, 3, 'h');
  for (var y = -2; y <= 2; y++) {
    set(-14, y, y.abs() < 2 ? 'x' : 'h');
  }
});

void _jet(
  Painter p,
  List<int> f,
  double x0,
  double y0,
  double jLen,
  double wob,
  int fr,
) {
  final dia = [
    for (var i = 0; i < 4; i++)
      3.6 + i * 4.3 + (rand(fr, i, 41) - 0.5) * 0.7,
  ];
  p.shade(x0 - jLen - 2, y0 - 6, x0, y0 + 6, (x, y, _) {
    final u = x0 - x;
    if (u < 0) return null;
    final q = u / jLen;
    if (q > 1.05) return null;
    final ady = (y - y0).abs();
    final qq = math.min(q, 1.0);
    final w = (2.6 + 2.4 * math.pow(qq, 0.7)) * (1 - qq * qq) * wob;
    final m = w -
        ady +
        (rand(x.floor() * 7 + y.floor() * 131, fr) - 0.5) *
            0.9 *
            math.min(1.0, 0.25 + q * 2);
    if (m < -0.5) return null;
    if (m < 0.5) return f[q < 0.45 ? 3 : 2];
    for (var i = 0; i < dia.length; i++) {
      if (dia[i] > jLen * 0.72) break;
      final d = (u - dia[i]).abs() / (1.9 - i * 0.15) + ady / (1.7 - i * 0.25);
      if (d < 1) return d < 0.55 && i < 3 ? f[8] : f[7];
    }
    if (u < 1.6 && ady < 1.6) return f[8];
    final lvl = (1 - ady / math.max(0.6, w)) * (1 - math.pow(qq, 1.5));
    return lvl > 0.62
        ? (u < 3 ? f[7] : f[5])
        : lvl > 0.38
            ? f[5]
            : lvl > 0.16
                ? f[4]
                : f[3];
  });
}

final PixelEffect rocketEffect = PureEffect(
  meta: _rocketMeta,
  onDraw: (p, t, o) {
    final f = fit(o.palette, 9);
    final m = fit(o.rampOpt('metal'), 7);
    final a = fit(o.rampOpt('paint'), 5);
    final sm = fit(o.rampOpt('smoke'), 7);
    final s = o.seed;
    const dDur = 1.2;
    final v = o.numOpt('speed', 120);
    final fr = (t * 30 + 1e-6).floor();
    int bob(double tt) => (math.sin((tt / dDur) * tau) * 0.62 + 0.5).floor();
    final by = bob(t);
    final jLen = _j0 * (0.84 + 0.32 * rand(fr, s, 1));
    final wob = 0.92 + 0.16 * rand(fr, s, 2);
    final fl = jLen / _j0;
    final left = -_rocketMeta.origin.$1 + 2.0;
    final sp = [f[7], f[6], f[4], f[3]];

    final list = <CloudPuff>[];
    beat(t, dDur, 66, s + 1, (r) => r.range(1.1, 1.45), (age, life, r, _) {
      final (x, y, _, _) = wake(
        _nozzle - _j0 * r.range(0.62, 0.8),
        bob(t - age) + r.range(-1, 1),
        -r.range(75, 105),
        r.range(-20, 20),
        age,
        v,
        3,
        0,
      );
      final k = age / life;
      final rise = 0.5 * r.range(6, 16) * age * age;
      final sway = math.sin(age * 2.3 + r.range(0, tau)) * age * 2;
      final rad = r.range(2.2, 3) +
          ((r.chance(0.25) ? r.range(14, 19) : r.range(8, 13)) - 2.6) *
              (1 - math.exp(-2.2 * age));
      if (x - rad < left + 1) return;
      final alpha = math.min(1.0, age * 16) *
          math.pow(1 - k, 1.25) *
          0.68 *
          smooth(left, left + 40, x - rad);
      list.add(CloudPuff(
        x: x,
        y: y - rise + sway,
        r: rad,
        a: alpha,
        b: clamp(0.95 - k * 0.75 + r.range(-0.08, 0.08)),
        w: math.exp(-age * r.range(3.5, 6)),
      ));
    });
    cloud(
      p,
      list,
      sm,
      [
        mix(f[0], sm[0], 0.5),
        mix(f[1], sm[1], 0.45),
        mix(f[2], sm[2], 0.35),
        f[3],
        f[4],
        f[6],
        f[7],
      ],
      dens: 1.3,
      lit: 1.5,
    );
    p.glow(_nozzle - _j0 - 6, by.toDouble(), 26, f[4], 0.24 * fl);

    beat(t, dDur, 9, s + 4, (r) => r.range(0.6, 1.1), (age, life, r, _) {
      final k = 1 - age / life;
      final (x, y, _, _) = wake(
        _nozzle - _j0 * 0.6,
        bob(t - age).toDouble(),
        -r.range(40, 120),
        r.range(-40, 30),
        age,
        v,
        2.5,
        -8,
      );
      if (x < left + 2 || (k < 0.3 && rand(fr, r.intRange(0, 999)) < 0.5)) {
        return;
      }
      final col = k > 0.6
          ? f[6]
          : k > 0.3
              ? f[4]
              : f[2];
      p.px(x, y, col);
      p.glow(x, y, 3, col, 0.35 * k);
    });

    beat(t, dDur, 30, s + 3, (r) => r.range(0.08, 0.16), (age, life, r, _) {
      final k = age / life;
      final (x, y, _, _) = wake(
        _nozzle - _j0 * r.range(0.6, 0.9),
        bob(t - age) + r.range(-1.5, 1.5),
        -r.range(10, 50),
        r.range(-12, 12),
        age,
        v,
        4,
        -30,
      );
      final idx = 7 - (math.pow(k, 0.7) * 4).floor();
      final rad = r.range(1.2, 2.2) * (1 - k * 0.6);
      p.circle(x, y, rad, f[idx - 2]);
      p.circle(x + rad * 0.25, y - rad * 0.1, rad * 0.65, f[idx]);
      p.glow(x, y, rad * 2.4 + 2, f[idx], 0.2 * (1 - k));
    });

    beat(t, dDur, 30, s + 2, (r) => r.range(0.18, 0.45), (age, life, r, _) {
      final (x, y, vx, vy) = wake(
        _nozzle - r.range(2, _j0 * 0.7),
        bob(t - age) + r.range(-1.5, 1.5),
        -r.range(20, 190),
        r.range(-80, 50),
        age,
        v,
        2.6,
        160,
      );
      if (x > left + 10) spark(p, x, y, vx, vy, 1 - age / life, sp);
    });
    beat(t, dDur, 8, s + 6, (r) => r.range(0.5, 0.8), (age, life, r, _) {
      final (x, y, vx, vy) = wake(
        _nozzle - r.range(4, _j0 * 0.8),
        bob(t - age) + r.range(-1, 1),
        -r.range(10, 80),
        r.range(-60, 10),
        age,
        v,
        1.8,
        170,
      );
      if (x > left + 10) spark(p, x, y, vx, vy, 1 - age / life, sp, 0.5);
    });

    _jet(p, f, _nozzle, by + 0.5, jLen, wob, fr + s * 31);
    p.sprite(
      _ship.rows,
      {
        'o': _outline,
        '1': m[1],
        '2': m[2],
        '3': m[3],
        '4': m[4],
        '5': m[5],
        '6': m[6],
        'a': a[0],
        'b': a[1],
        'c': a[2],
        'd': a[3],
        'e': a[4],
        'w': kWhite,
        'h': f[5],
        'x': f[8],
      },
      _ship.x0,
      _ship.y0 + by,
    );

    p.glow(_nozzle - 10, by.toDouble(), 60, f[4], 0.28 * fl);
    p.glowLine(_nozzle - 3, by + 0.5, _nozzle - jLen * 0.9, by + 0.5, 11, f[4], 0.2);
    p.glow(_nozzle - 1, by + 0.5, 8, f[7], 0.45);
    p.glow(_nozzle + 3, by + 5.0, 12, f[4], 0.22 * fl);
  },
);
