import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const double _open = 0.3;
const List<double> _belch = [0.52, 0.76];
const double _burst = 1.0;
const double _shut = 1.9;
const double _pop = 2.22;
const double _sy = 0.34;
final int _voidCol = hex('#06030b');
final int _fumeCol = hex('#3a3046');
final List<int> _stoneCols = [
  '#1a1424',
  '#2b2639',
  '#4a4263',
  '#6c6488',
  '#9a91b4',
].map(hex).toList();
final int _dustCol = hex('#5a5070');

final PixelEffect spawnPortalEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'spawn/spawn-portal',
    name: 'Spawn portal',
    desc:
        'A rift tears open on the floor and swirls, belches violet smoke and sparks, spits a fountain of wisps up out of itself, then twists shut with a pop.',
    category: 'spawn',
    tags: [
      'spawn',
      'portal',
      'summon',
      'rift',
      'arcane',
      'smoke',
      'ground',
      'one-shot',
    ],
    size: (208, 150),
    origin: (104, 122),
    duration: 3.8,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#12081f',
        '#2a0f4d',
        '#481b8c',
        '#7330d0',
        '#a35cff',
        '#cf9bff',
        '#f1dcff',
        '#ffffff',
      ],
      'width': 28,
      'seed': 6,
    },
  ),
  onCreate: (o) => _SpawnPortalSim(o),
);

double _portalRadius(double t, double rx) {
  if (t < _open) return rx * Ease.outBack(clamp(t / _open), 2.2);
  if (t < _shut) {
    final dt = t - _burst - 0.05;
    return rx * (1 + 0.035 * math.sin(t * 9) + 0.1 * math.exp(-(dt * dt) / 0.006));
  }
  final k = clamp((t - _shut) / (_pop - _shut));
  return rx *
      (k < 0.35
          ? 1 + 0.1 * math.sin((k / 0.35) * math.pi * 0.5)
          : 1.1 * (1 - math.pow((k - 0.35) / 0.65, 1.6)));
}

double _spinAt(double t) =>
    t * 2.4 +
    1.5 * smooth(_burst - 0.1, _burst + 0.3, t) +
    10 * math.pow(clamp((t - _shut) / (_pop - _shut)), 2.2);

double _lipAt(double th, double spin) =>
    1 +
    0.05 * noise(th * 3 + spin * 0.6, 5) +
    0.035 * noise(th * 8 - spin * 1.3, 9);

void _drawHole(
  Painter p,
  List<int> cRamp,
  double rx,
  double spin,
  double heat, [
  double wind = 2.3,
]) {
  if (rx < 1) return;
  final ry = rx * _sy;
  p.shade(
    (-rx - 2).floor(),
    (-ry - 2).floor(),
    (rx + 2).ceil(),
    (ry + 2).ceil(),
    (x, y, out) {
      final u = x / rx;
      final v = y / ry;
      final q = hypot(u, v);
      final th = math.atan2(v, u);
      final lip = _lipAt(th, spin);
      if (q > lip) return null;
      final w = q / lip;
      out.c = v < 0 && w > 0.72
          ? (w > 0.86 ? cRamp[2] : cRamp[1])
          : (w > 0.55 ? cRamp[0] : _voidCol);
      return null;
    },
  );
  final n = math.max(40, (rx * 5 + 0.5).floor());
  for (var i = 0; i < 3; i++) {
    for (var j = 0; j <= n; j++) {
      final q = 0.14 + 0.82 * (j / n);
      final th = spin + (i * tau) / 3 - wind * math.log(q);
      final lip = _lipAt(th, spin);
      final x = math.cos(th) * q * lip * rx;
      final y = math.sin(th) * q * lip * ry;
      final c = q > 0.8
          ? (heat > 1.1 ? kWhite : cRamp[6])
          : q > 0.55
              ? cRamp[5]
              : q > 0.32
                  ? cRamp[4]
                  : cRamp[3];
      p.dot(x, y, c, q > 0.3 ? 1 : q / 0.3);
      if (q > 0.4 && j % 2 == 0) {
        final t2 = th - 0.32;
        final x2 = math.cos(t2) * q * 0.94 * lip * rx;
        final y2 = math.sin(t2) * q * 0.94 * lip * ry;
        p.dot(x2, y2, q > 0.7 ? cRamp[4] : cRamp[3], 0.85);
      }
    }
  }
  p.glow(0, 0, rx * 0.45, cRamp[3], 0.35 * heat);
}

void _drawLip(
  Painter p,
  List<int> cRamp,
  double rx,
  double spin,
  double heat,
  bool near,
) {
  if (rx < 1) return;
  final ry = rx * _sy;
  final n = (rx * 7).ceil();
  for (var j = 0; j < n; j++) {
    final th = (j / n) * tau;
    final s = math.sin(th);
    if ((s >= 0) != near) continue;
    final l = _lipAt(th, spin);
    final x = math.cos(th) * rx * l;
    final y = s * ry * l;
    final f = noise(th * 9 + spin * 3, 13);
    p.dot(math.cos(th) * (rx * l + 1.2), s * (ry * l + 1), cRamp[1]);
    p.dot(
      x,
      y,
      near
          ? (f > -0.3 || heat > 1.1 ? kWhite : cRamp[6])
          : (f > 0.2 ? cRamp[6] : cRamp[5]),
    );
    if (j % 6 == 0) {
      p.glow(x, y, 7, cRamp[5], (near ? 0.3 : 0.2) * math.min(1.4, heat));
    }
  }
}

class _SwirlMote {
  _SwirlMote({
    required this.a,
    required this.r,
    required this.w,
    required this.inRate,
    required this.c,
  });

  double a;
  double r;
  final double w;
  final double inRate;
  final int c;
}

class _Wisp {
  _Wisp({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.ph,
  });

  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double max = 1;
  final List<(double, double)> tr = [];
  double acc = 0;
  final double ph;
}

class _ShockRing {
  const _ShockRing({
    required this.t0,
    required this.life,
    required this.r0,
    required this.r1,
    required this.th,
    required this.hot,
  });

  final double t0;
  final double life;
  final double r0;
  final double r1;
  final double th;
  final bool hot;
}

void _drawRing(
  Painter p,
  List<int> cRamp,
  _ShockRing r,
  double t,
  bool near,
) {
  final k = (t - r.t0) / r.life;
  if (k < 0 || k >= 1) return;
  band(
    p,
    0,
    0,
    r.r0 + (r.r1 - r.r0) * Ease.outCubic(k),
    _sy * 0.62,
    math.max(1.0, r.th * (1 - k)),
    1.15 - k,
    cRamp,
    keep: (double g) => (math.sin(g) >= 0) == near,
    hot: r.hot && k < 0.15,
  );
}

class _SpawnPortalSim extends BaseEffectSim {
  _SpawnPortalSim(Map<String, Object?> o) {
    cRamp = fit(o.palette, 8);
    rx = o.numOpt('width', 28);
    rng = Rng(o.seed);
    sm = [
      mix(cRamp[4], _fumeCol, 0.4),
      mix(cRamp[3], _fumeCol, 0.3),
      mix(cRamp[5], _fumeCol, 0.55),
    ];
    ps = Particles(
      rng: rng,
      ground: (_) => 0,
      sparks: [cRamp[7], cRamp[6], cRamp[5], cRamp[3]],
    );
    rocks = Bits(ground: (_) => 0);
    lights = Lights();
  }

  late final List<int> cRamp;
  late final double rx;
  late final Rng rng;
  late final List<int> sm;
  late final Particles ps;
  late final Bits rocks;
  late final Lights lights;
  final List<_SwirlMote> swirl = [];
  final List<_Wisp> wisps = [];
  final List<_ShockRing> rings = [];
  final Set<String> done = {};
  final Set<DebrisBit> dusted = {};
  double t = 0;

  void _addSwirl(double r0) {
    swirl.add(
      _SwirlMote(
        a: rng.range(0, tau),
        r: r0,
        w: rng.range(2.2, 4),
        inRate: rng.range(0.3, 0.7),
        c: rng.pick([kWhite, cRamp[6], cRamp[6], cRamp[5]]),
      ),
    );
  }

  void _pull() {
    final a = rng.range(math.pi * 1.03, math.pi * 1.97);
    final d = rng.range(40, 86);
    final dur = rng.range(0.24, 0.42);
    final x = math.cos(a) * d * 1.08;
    final y = math.sin(a) * d * 0.85;
    final l = hypot(x, y);
    final v = (0.6 * l) / (1 - math.exp(-0.6 * dur));
    ps.spawn(
      P.mote,
      x,
      y,
      (-x / l) * v,
      (-y / l) * v,
      dur,
      rng.pick([kWhite, cRamp[6], cRamp[5], cRamp[5], cRamp[4]]),
      rng.range(1, 1.7),
    );
  }

  void _puff(int n, bool big, double sp) {
    for (var i = 0; i < n; i++) {
      final a = rng.range(0, tau);
      final d = rng.range(0, 0.55) * rx;
      ps.spawn(
        P.smoke,
        math.cos(a) * d,
        math.sin(a) * d * _sy - 2,
        rng.range(-1, 1) * sp * 0.6,
        -rng.range(0.4, 1) * sp,
        rng.range(1.2, 2.2) * (big ? 1.15 : 0.8),
        rng.pick(sm),
        rng.range(2.8, 4.6) * (big ? 1.15 : 0.9),
        big ? rng.range(0, 0.3) : rng.range(0, 0.1),
        big ? PF.big : 0,
      );
    }
  }

  void _sparks(int n, double up, double spread) {
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + rng.range(-spread, spread);
      final sp = rng.range(0.5, 1) * up;
      ps.spawn(
        P.spark,
        rng.range(-0.5, 0.5) * rx,
        -1,
        math.cos(a) * sp,
        math.sin(a) * sp,
        rng.range(0.35, 0.8),
      );
    }
  }

  bool _once(String k, double at) =>
      !done.contains(k) && t >= at && done.add(k);

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final shutting = t > _shut && t < _pop;
    if ((t < _open + 0.15 || shutting) && rng.chance(0.55)) {
      final s = rng.sign();
      final d = rng.range(rx * 1.3, rx * 2.4);
      final dur = rng.range(0.18, 0.3);
      final v = (d * 3) / (math.exp(3 * dur) - 1);
      ps.spawn(
        P.streak,
        s * d,
        -rng.range(0, 3),
        -s * v,
        rng.range(-2, 2),
        dur,
        rng.chance(0.5) ? cRamp[6] : cRamp[5],
      );
    }
    if (t > 0.1 &&
        t < _pop - 0.1 &&
        rng.chance(shutting ? 0.85 : (t < _burst ? 0.55 : 0.1))) {
      _pull();
    }
    if (t < _pop && t > 0.12 && rng.chance(shutting ? 0.5 : 0.25)) {
      _addSwirl(rng.range(1.1, 1.5));
    }
    if (_once('open', _open * 0.7)) {
      lights.add(0, -8, 50, cRamp[4], 0.75, 0.45);
      rings.add(
        _ShockRing(
          t0: t,
          life: 0.42,
          r0: rx * 0.8,
          r1: rx * 1.9,
          th: 2.5,
          hot: true,
        ),
      );
      for (var i = 0; i < 8; i++) {
        ps.spawn(
          P.dust,
          rng.sign() * rng.range(0.7, 1.1) * rx,
          -1,
          rng.sign() * rng.range(10, 45),
          -rng.range(4, 14),
          rng.range(0.4, 0.7),
          _dustCol,
          rng.range(1.5, 3),
        );
      }
    }
    if (_once('b0', _belch[0])) {
      _puff(6, false, 34);
      _sparks(8, 210, 0.55);
      lights.add(0, -6, 44, cRamp[4], 0.6, 0.3);
    }
    if (_once('b1', _belch[1])) {
      _puff(8, false, 40);
      _sparks(12, 240, 0.6);
      lights.add(0, -6, 48, cRamp[4], 0.65, 0.3);
    }
    if (_once('burst', _burst)) {
      lights.add(0, -26, 74, cRamp[4], 1, 0.75);
      lights.add(0, -10, 40, kWhite, 0.85, 0.14);
      rings.addAll([
        _ShockRing(
          t0: t,
          life: 0.55,
          r0: rx * 1.0,
          r1: rx * 2.5,
          th: 3.5,
          hot: true,
        ),
        _ShockRing(
          t0: t + 0.06,
          life: 0.45,
          r0: rx * 0.8,
          r1: rx * 1.8,
          th: 2,
          hot: false,
        ),
      ]);
      _puff(18, true, 70);
      _sparks(34, 400, 0.8);
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + (i - 2) * 0.27 + rng.range(-0.08, 0.08);
        final sp = rng.range(185, 235);
        wisps.add(
          _Wisp(
            x: rng.range(-4, 4),
            y: -2,
            vx: math.cos(a) * sp,
            vy: math.sin(a) * sp,
            life: rng.range(0.75, 1.0),
            ph: rng.range(0, tau),
          ),
        );
      }
      for (var i = 0; i < 12; i++) {
        rocks.add(
          DebrisBit(
            kind: B.chunk,
            x: rng.sign() * rng.range(0.75, 1.05) * rx,
            y: -1,
            vx: rng.range(-100, 100),
            vy: -rng.range(150, 280),
            g: 1,
            drag: 0.4,
            bounce: 0.3,
            life: rng.range(1.3, 1.9),
            a: rng.range(0, tau),
            va: rng.range(-14, 14),
            s: rng.range(1, 2.4),
            rampColors: _stoneCols,
          ),
        );
      }
      for (var i = 0; i < 14; i++) {
        ps.spawn(
          P.star,
          rng.range(-0.8, 0.8) * rx,
          -rng.range(4, 34),
          rng.range(-30, 30),
          -rng.range(10, 60),
          rng.range(0.5, 1.1),
          rng.pick([kWhite, cRamp[6], cRamp[5]]),
          rng.range(0.8, 2),
        );
      }
    }
    if (t > _open && t < _shut && rng.chance(0.16)) _puff(1, false, 22);
    if (t > _open && t < _shut + 0.1 && rng.chance(0.06)) _sparks(1, 160, 0.4);
    if (_once('pop', _pop)) {
      lights.add(0, -4, 50, cRamp[4], 0.95, 0.5);
      lights.add(0, -2, 28, kWhite, 0.9, 0.12);
      rings.add(
        _ShockRing(t0: t, life: 0.35, r0: 2, r1: rx * 1.9, th: 2.5, hot: true),
      );
      for (var i = 0; i < 18; i++) {
        final a = rng.range(-math.pi, 0);
        final sp = rng.range(90, 270);
        ps.spawn(
          P.spark,
          0,
          -1,
          math.cos(a) * sp,
          math.sin(a) * sp * 0.8,
          rng.range(0.25, 0.6),
        );
      }
      for (var i = 0; i < 9; i++) {
        final a = rng.range(0, tau);
        final sp = rng.range(30, 95);
        ps.spawn(
          P.star,
          0,
          -2,
          math.cos(a) * sp,
          math.sin(a) * sp * 0.5 - 20,
          rng.range(0.4, 0.9),
          rng.pick([kWhite, cRamp[6]]),
          rng.range(0.8, 1.8),
        );
      }
      for (var i = 0; i < 6; i++) {
        ps.spawn(
          P.smoke,
          rng.range(-6, 6),
          -rng.range(1, 4),
          rng.range(-34, 34),
          -rng.range(10, 30),
          rng.range(0.8, 1.3),
          sm[2],
          rng.range(2.5, 4.5),
        );
      }
      for (var i = 0; i < 14; i++) {
        ps.spawn(
          P.star,
          rng.range(-1, 1) * rx * 0.9,
          -rng.range(0.5, 2),
          rng.range(-4, 4),
          -rng.range(0, 4),
          rng.range(0.6, 1.4),
          rng.pick([cRamp[6], cRamp[5], cRamp[5]]),
          rng.range(0.4, 0.9),
          rng.range(0, 0.25),
        );
      }
    }

    for (var i = swirl.length - 1; i >= 0; i--) {
      final s = swirl[i];
      final k = shutting ? 2.4 : 1.0;
      s.a += s.w * k * dt * (1.4 / math.max(0.3, s.r));
      s.r -= s.inRate * k * dt;
      if (s.r < 0.25 || t > _pop) swirl.removeAt(i);
    }

    for (var i = wisps.length - 1; i >= 0; i--) {
      final w = wisps[i];
      w.tr.insert(0, (w.x, w.y));
      if (w.tr.length > 12) w.tr.removeLast();
      w.life -= dt;
      if (w.life <= 0 || (w.vy > 0 && w.y > -2)) {
        for (var j = 0; j < 8; j++) {
          final a = rng.range(0, tau);
          final sp = rng.range(30, 120);
          ps.spawn(
            P.spark,
            w.x,
            w.y,
            math.cos(a) * sp + w.vx * 0.2,
            math.sin(a) * sp + w.vy * 0.2,
            rng.range(0.2, 0.5),
          );
        }
        ps.spawn(P.star, w.x, w.y, 0, -6, 0.45, kWhite, 2.4);
        lights.add(w.x, w.y, 24, cRamp[5], 0.65, 0.25);
        wisps.removeAt(i);
        continue;
      }
      w.vy += 360 * dt;
      w.vx += math.sin((w.max - w.life) * 16 + w.ph) * 160 * dt;
      w.vx -= w.vx * 1.1 * dt;
      w.vy -= w.vy * 1.1 * dt;
      w.x += w.vx * dt;
      w.y += w.vy * dt;
      for (w.acc += dt; w.acc > 0.03; w.acc -= 0.03) {
        ps.spawn(
          P.smoke,
          w.x,
          w.y,
          w.vx * 0.05,
          w.vy * 0.05 - 4,
          rng.range(0.6, 1),
          sm[0],
          rng.range(1.5, 2.4),
        );
      }
      if (rng.chance(0.3)) {
        ps.spawn(
          P.mote,
          w.x,
          w.y,
          -w.vx * 0.2 + rng.range(-15, 15),
          -w.vy * 0.2 + rng.range(-15, 15),
          rng.range(0.2, 0.4),
          cRamp[6],
          0.6,
        );
      }
    }

    for (var i = rings.length - 1; i >= 0; i--) {
      if (t - rings[i].t0 > rings[i].life) rings.removeAt(i);
    }
    rocks.update(dt);
    for (final b in rocks.list) {
      if (b.rest && dusted.add(b)) {
        for (var i = 0; i < 2; i++) {
          ps.spawn(
            P.dust,
            b.x + rng.range(-1.5, 1.5),
            -0.5,
            rng.sign() * rng.range(6, 30),
            -rng.range(2, 12),
            rng.range(0.3, 0.6),
            _dustCol,
            rng.range(1.2, 2.4),
          );
        }
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  void _drawSwirl(Painter p, bool near) {
    final curRx = _portalRadius(t, rx);
    for (final s in swirl) {
      for (var j = 0; j < 3; j++) {
        final a = s.a - j * 0.08 * (1.4 / math.max(0.3, s.r));
        final x = math.cos(a) * s.r * curRx;
        final y = math.sin(a) * s.r * curRx * _sy;
        if ((math.sin(a) >= 0) != near) continue;
        p.dot(x, y - 0.5, j != 0 ? cRamp[5] : s.c, j != 0 ? 0.9 - j * 0.3 : 1);
        if (j == 0) p.glow(x, y, 3, cRamp[5], 0.35);
      }
    }
  }

  @override
  void drawBack(Painter p) {
    final curRx = _portalRadius(t, rx);
    final spin = _spinAt(t);
    final dt = t - _burst;
    final heat =
        0.85 + 0.15 * math.sin(t * 7) + 0.6 * math.exp(-(dt * dt) / 0.01);
    if (t < _pop) {
      p.glow(0, -4, curRx * 1.8 + 10, cRamp[4], 0.32 * clamp(curRx / rx));
      p.glowLine(0, -2, 0, -44, curRx * 0.7 + 6, cRamp[4], 0.16 * clamp(curRx / rx));
    }
    if (t < _open * 0.6) {
      final k = t / (_open * 0.6);
      final l = rx * 1.1 * Ease.outCubic(k);
      p.lineShaded(
        -l,
        0,
        l,
        0,
        color: (double u) => (u - 0.5).abs() < 0.3 ? kWhite : cRamp[6],
      );
      p.glowLine(-l, 0, l, 0, 7, cRamp[5], 0.6);
    }
    if (t > _open * 0.35 && t < _pop) {
      _drawHole(
        p,
        cRamp,
        curRx,
        spin,
        heat + 0.4 * smooth(_shut, _pop, t),
        2.3 + 2.6 * smooth(_shut, _pop - 0.05, t),
      );
      _drawLip(p, cRamp, curRx, spin, heat, false);
    }
    for (final r in rings) {
      _drawRing(p, cRamp, r, t, false);
    }
    _drawSwirl(p, false);
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final curRx = _portalRadius(t, rx);
    final spin = _spinAt(t);
    final dt = t - _burst;
    final heat =
        0.85 + 0.15 * math.sin(t * 7) + 0.6 * math.exp(-(dt * dt) / 0.01);
    if (t > _open * 0.35 && t < _pop) _drawLip(p, cRamp, curRx, spin, heat, true);
    for (final r in rings) {
      _drawRing(p, cRamp, r, t, true);
    }
    _drawSwirl(p, true);
    final b = t - _burst;
    if (b > 0 && b < 0.45) {
      final k = b / 0.45;
      final top = -84 * Ease.outExpo(clamp(b / 0.14));
      final bot = -1 - 60 * Ease.inQuad(k);
      final w0 = rx * 0.55 * (1 - k * 0.8);
      p.shade(
        (-w0 - 1).floor(),
        top.floor(),
        (w0 + 1).ceil(),
        bot.ceil(),
        (x, y, out) {
          final u = (y - bot) / (top - bot);
          final half =
              w0 *
              math.pow(1 - u, 0.8) *
              (0.85 + 0.15 * math.sin(y * 0.7 + t * 40));
          final d = x.abs() / math.max(0.5, half);
          if (d > 1) return null;
          out.c = d < 0.35 ? kWhite : (d < 0.7 ? cRamp[6] : cRamp[5]);
          return null;
        },
      );
      p.glowLine(0, bot, 0, top, w0 + 12, cRamp[5], 0.55 * (1 - k));
      if (b < 0.14) flare(p, 0, -4, 36 * (1 - b / 0.14), 1 - b / 0.14, cRamp);
    }
    final q = t - _pop;
    if (q > -0.08 && q < 0.25) {
      sparkle(
        p,
        0.0,
        -1.0,
        ((q < 0 ? 4 : 12) * (1 - clamp(q / 0.25)) + 0.5).floorToDouble(),
        kWhite,
        cRamp[5],
        0.7 * (1 - clamp(q / 0.25)),
      );
    }
    rocks.draw(p);
    for (final w in wisps) {
      final k = w.life / w.max;
      for (var i = 1; i < w.tr.length; i++) {
        final (x0, y0) = w.tr[i - 1];
        final (x1, y1) = w.tr[i];
        final u = i / w.tr.length;
        p.line(
          x0,
          y0,
          x1,
          y1,
          u < 0.25 ? kWhite : (u < 0.55 ? cRamp[6] : cRamp[4]),
          1.15 - u,
        );
        if (u < 0.35) p.line(x0 + 1, y0, x1 + 1, y1, cRamp[5], 1);
      }
      p.circle(w.x, w.y, 2, cRamp[5]);
      p.circle(w.x, w.y, 1.2, cRamp[6]);
      p.px(w.x, w.y, kWhite);
      p.glow(w.x, w.y, 12, cRamp[5], 0.5 * k + 0.2);
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}
