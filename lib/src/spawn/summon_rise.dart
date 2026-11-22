import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

final int _soot = hex('#2a1e2a');
const double _ign = 0.5;
const double _runesAt = 0.78;
const double _breakAt = 1.05;
const double _eyesAt = 2.3;
const double _fadeAt = 3.4;
const double _duration = 4.6;
const double _sy = 0.3;
const double _r0 = 36;
const double _r1 = 27;

class _BeastData {
  const _BeastData({
    required this.w,
    required this.h,
    required this.part,
    required this.amb,
    required this.down,
    required this.rim,
    required this.crease,
    required this.outline,
    required this.eyes,
    required this.tusks,
    required this.glints,
  });

  final int w;
  final int h;
  final Uint8List part;
  final Float32List amb;
  final Float32List down;
  final Float32List rim;
  final Uint8List crease;
  final List<(int, int)> outline;
  final List<(int, int)> eyes;
  final List<(int, int)> tusks;
  final List<(double, double)> glints;
}

_BeastData _buildBeast() {
  const w = 46;
  const h = 46;
  const n = w * h;
  const c = 22.5;
  final parts = List.generate(8, (_) => Uint8List(n));
  late Uint8List cur;

  void put(double x, double y) {
    final ix = (x + 0.5).floor();
    final iy = (y + 0.5).floor();
    if (ix >= 0 && iy >= 0 && ix < w && iy < h) cur[iy * w + ix] = 1;
  }

  void ell(double cx, double cy, double rx, double ry) {
    for (var y = (cy - ry).floor(); y <= (cy + ry).ceil(); y++) {
      for (var x = (cx - rx).floor(); x <= (cx + rx).ceil(); x++) {
        final dx = (x + 0.5 - cx) / rx;
        final dy = (y + 0.5 - cy) / ry;
        if (dx * dx + dy * dy <= 1) put(x.toDouble(), y.toDouble());
      }
    }
  }

  void stroke(List<(double, double)> pts, double r0, double r1) {
    final lenList = List<double>.filled(pts.length - 1, 0);
    var total = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final segLen = hypot(
        pts[i].$1 - pts[i - 1].$1,
        pts[i].$2 - pts[i - 1].$2,
      );
      lenList[i - 1] = segLen;
      total += segLen;
    }
    var acc = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final segLen = lenList[i - 1];
      final steps = (segLen * 3).ceil() + 1;
      for (var j = 0; j <= steps; j++) {
        final u = j / steps;
        final r = r0 + (r1 - r0) * ((acc + segLen * u) / total);
        ell(
          pts[i - 1].$1 + (pts[i].$1 - pts[i - 1].$1) * u,
          pts[i - 1].$2 + (pts[i].$2 - pts[i - 1].$2) * u,
          r,
          r,
        );
      }
      acc += segLen;
    }
  }

  final head = parts[0];
  final horns = parts[1];
  final arms = parts[2];
  final shoulders = parts[3];
  final chest = parts[4];
  final waist = parts[5];
  final legs = parts[6];
  final tail = parts[7];

  for (final s in const [-1, 1]) {
    double xAt(double d) => c + s * d;
    cur = horns;
    stroke(
      [
        (xAt(4), 11),
        (xAt(8), 8),
        (xAt(12), 6.5),
        (xAt(15), 4),
        (xAt(16), 1.5),
        (xAt(15.2), 0),
      ],
      2.3,
      0.45,
    );
    cur = shoulders;
    ell(xAt(10), 16, 7, 5);
    ell(xAt(8.5), 19.5, 5.5, 4.2);
    cur = arms;
    stroke([(xAt(14.5), 16.5), (xAt(17.5), 22), (xAt(18.5), 28)], 4, 3.2);
    stroke([(xAt(18.5), 28), (xAt(19), 33), (xAt(19.2), 36.5)], 3.4, 2.8);
    ell(xAt(19.2), 37.8, 3, 2.3);
    stroke([(xAt(17.2), 39), (xAt(16.6), 41.8)], 0.9, 0.4);
    stroke([(xAt(19.2), 39.5), (xAt(19.3), 42.6)], 0.9, 0.4);
    stroke([(xAt(21.2), 38.8), (xAt(22), 41.4)], 0.9, 0.4);
    cur = legs;
    stroke([(xAt(5.5), 31), (xAt(8), 37), (xAt(7.5), 42)], 4, 3);
    ell(xAt(8.5), 44.3, 4.2, 1.7);
  }
  cur = tail;
  stroke(
    [
      (c, 30),
      (c + 0.5, 36),
      (c + 2.5, 41.5),
      (c + 7, 44.6),
      (c + 12.5, 44.2),
      (c + 14.5, 42.5),
    ],
    2.3,
    0.6,
  );
  cur = chest;
  ell(c, 22.5, 8.2, 7.5);
  cur = waist;
  ell(c, 29.5, 6.2, 4.5);
  cur = head;
  ell(c, 12.5, 5.2, 4.6);
  ell(c, 16, 4.2, 2.8);

  final part = Uint8List(n);
  for (var i = 0; i < n; i++) {
    for (var k = 0; k < parts.length; k++) {
      if (parts[k][i] != 0) {
        part[i] = k + 1;
        break;
      }
    }
  }
  bool on(int x, int y) =>
      x >= 0 && y >= 0 && x < w && y < h && part[y * w + x] > 0;

  Float32List blur(Uint8List src) {
    final a = Float32List(n);
    for (var i = 0; i < n; i++) {
      a[i] = src[i].toDouble();
    }
    final b = Float32List(n);
    for (var pass = 0; pass < 2; pass++) {
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          var s = 0.0;
          for (var d = -2; d <= 2; d++) {
            s += x + d >= 0 && x + d < w ? a[y * w + x + d] : 0;
          }
          b[y * w + x] = s / 5;
        }
      }
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          var s = 0.0;
          for (var d = -2; d <= 2; d++) {
            s += y + d >= 0 && y + d < h ? b[(y + d) * w + x] : 0;
          }
          a[y * w + x] = s / 5;
        }
      }
    }
    return a;
  }

  final amb = Float32List(n);
  final down = Float32List(n);
  final rim = Float32List(n);
  final crease = Uint8List(n);

  for (var k = 0; k < parts.length; k++) {
    final bBuf = blur(parts[k]);
    double at(int x, int y) =>
        x >= 0 && y >= 0 && x < w && y < h ? bBuf[y * w + x] : 0.0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        if (part[i] != k + 1) continue;
        final gx = at(x + 1, y) - at(x - 1, y);
        final gy = at(x, y + 1) - at(x, y - 1);
        final mag = hypot(gx, gy);
        final g = mag == 0 ? 1e-6 : mag;
        final ox = -gx / g;
        final oy = -gy / g;
        final e = clamp(g / 0.28);
        amb[i] =
            0.42 +
            e *
                (0.4 * math.max(0.0, -oy) +
                    0.14 * math.max(0.0, -ox) -
                    0.3 * math.max(0.0, oy) -
                    0.08 * math.max(0.0, ox));
        down[i] =
            e *
            math.max(0.0, oy) *
            ((x + 0.5 - c).abs() < 7 && y > 27 ? 0.3 : 1.0);
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          if (on(x + dx, y + dy) && part[(y + dy) * w + x + dx] > k + 1) {
            crease[i] = 1;
          }
        }
      }
    }
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (!on(x, y)) continue;
      final k = !on(x, y + 1) ? 1.0 : (!on(x, y + 2) ? 0.5 : 0.0);
      rim[y * w + x] = (x + 0.5 - c).abs() < 7 && y > 27 ? k * 0.3 : k;
    }
  }

  final outline = <(int, int)>[];
  for (var y = -1; y <= h; y++) {
    for (var x = -1; x <= w; x++) {
      if (!on(x, y) &&
          (on(x - 1, y) || on(x + 1, y) || on(x, y - 1) || on(x, y + 1))) {
        outline.add((x, y));
      }
    }
  }

  final eyes = <(int, int)>[];
  final tusks = <(int, int)>[];
  for (final s in const [-1, 1]) {
    eyes.add(((c + s * 2.2 - 0.5 + 0.5).floor(), 12));
    eyes.add(((c + s * 3.2 - 0.5 + 0.5).floor(), 12));
    tusks.add(((c + s * 3.4 - 0.5 + 0.5).floor(), 16));
    tusks.add(((c + s * 3.6 - 0.5 + 0.5).floor(), 15));
  }

  return _BeastData(
    w: w,
    h: h,
    part: part,
    amb: amb,
    down: down,
    rim: rim,
    crease: crease,
    outline: outline,
    eyes: eyes,
    tusks: tusks,
    glints: [
      ((c - 2.7 - 0.5 + 0.5).floor() - w / 2, (12 - h).toDouble()),
      ((c + 2.7 - 0.5 + 0.5).floor() - w / 2, (12 - h).toDouble()),
    ],
  );
}

final _BeastData _beast = _buildBeast();

const List<List<List<(double, double)>>> _glyphs = [
  [
    [(0, -2), (0, 2)],
    [(-1.5, -1), (1.5, 1)],
  ],
  [
    [(-1.5, 2), (0, -2), (1.5, 2)],
    [(-0.8, 0.4), (0.8, 0.4)],
  ],
  [
    [(-1.5, -2), (-1.5, 2), (1.5, 2)],
    [(0, -2), (1.5, -0.5)],
  ],
  [
    [(0, -2), (0, 2)],
    [(0, -2), (1.6, -0.6), (0, 0.6)],
  ],
  [
    [(-1.5, -2), (1.5, 2)],
    [(1.5, -2), (-1.5, 2)],
    [(-1.5, 0), (1.5, 0)],
  ],
  [
    [(-1.4, -2), (1.4, -2), (-1.4, 2), (1.4, 2)],
  ],
];

final PixelEffect summonRiseEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'spawn/summon-rise',
    name: 'Summon rise',
    desc:
        'A rune circle burns into the floor, the ground bursts, and a horned brute heaves up out of it through dust and rubble, lit from below, until its eyes flare.',
    category: 'spawn',
    tags: [
      'spawn',
      'summon',
      'demon',
      'rise',
      'runes',
      'dust',
      'rubble',
      'ground',
      'one-shot',
    ],
    size: (176, 116),
    origin: (88, 94),
    duration: _duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#1a0608',
        '#3d0c0c',
        '#7a1a10',
        '#c0381a',
        '#f06a1e',
        '#ffae3a',
        '#ffe08a',
        '#ffffff',
      ],
      'body': ['#060409', '#0e0913', '#170f1e', '#211628', '#2d2036'],
      'horn': ['#0c080c', '#201820', '#352a32', '#4e3f48', '#6e5c64'],
      'stone': ['#1a1424', '#2b2639', '#4a4263', '#6c6488', '#9a91b4'],
      'seed': 9,
    },
  ),
  onCreate: (o) => _SummonRiseSim(o),
);

class _Rune {
  const _Rune({required this.a, required this.g});

  final double a;
  final List<List<(double, double)>> g;
}

class _SummonRiseSim extends BaseEffectSim {
  _SummonRiseSim(Map<String, Object?> o) {
    cRamp = fit(o.palette, 8);
    sh = fit(o.rampOpt('body'), 5);
    hr = fit(o.rampOpt('horn'), 5);
    st = fit(o.rampOpt('stone'), 5);
    dustCol = mix(st[2], hex('#7a6c78'), 0.45);
    rng = Rng(o.seed);
    ps = Particles(
      rng: rng,
      ground: (_) => 0,
      sparks: [cRamp[6], cRamp[5], cRamp[4], cRamp[3]],
    );
    rub = [
      st[0],
      st[1],
      mix(st[2], cRamp[2], 0.3),
      mix(st[3], cRamp[4], 0.3),
      mix(st[4], cRamp[5], 0.35),
    ];
    rocks = Bits(ground: (_) => 0);
    lights = Lights();
    runes = List.generate(
      12,
      (i) => _Rune(
        a: (i / 12) * tau + 0.13,
        g: _glyphs[(i * 5 + 2) % _glyphs.length],
      ),
    );
    for (var i = 0; i < 7; i++) {
      var a = (i / 7) * tau + rng.range(-0.25, 0.25);
      var r = 3.0;
      final pts = <(double, double)>[(0, 0)];
      final len = rng.range(_r1 * 0.6, _r1 * 1.05);
      while (r < len) {
        r += rng.range(2, 4);
        a += rng.range(-0.3, 0.3);
        pts.add((math.cos(a) * r, math.sin(a) * r * _sy));
      }
      cracks.add(pts);
    }
  }

  late final List<int> cRamp;
  late final List<int> sh;
  late final List<int> hr;
  late final List<int> st;
  late final int dustCol;
  late final Rng rng;
  late final Particles ps;
  late final List<int> rub;
  late final Bits rocks;
  late final Lights lights;
  late final List<_Rune> runes;
  final List<List<(double, double)>> cracks = [];
  final Set<String> done = {};
  final Set<DebrisBit> dusted = {};
  double t = 0;

  double _rise(double t) {
    if (t < _breakAt) return 0;
    final a = Ease.outCubic(clamp((t - _breakAt) / 0.4)) * 0.56;
    final sag = 0.04 * math.sin(math.pi * clamp((t - _breakAt - 0.42) / 0.3));
    final b = Ease.outBack(clamp((t - _breakAt - 0.62) / 0.45), 1.4) * 0.44;
    return a - sag + b;
  }

  double _heat(double t) {
    final db = t - _breakAt;
    final de = t - _eyesAt;
    return smooth(0, _ign, t) *
        (1 - smooth(_fadeAt, _fadeAt + 0.8, t)) *
        (1 - 0.25 * smooth(_eyesAt + 0.2, _eyesAt + 0.9, t)) *
        (0.85 +
            0.15 * noise(t * 9, 3) +
            0.5 * math.exp(-(db * db) / 0.02) +
            0.3 * math.exp(-(de * de) / 0.01));
  }

  double _left(double a, double b) =>
      math.max(0.05, math.min(rng.range(a, b), _duration - 0.1 - t));

  bool _once(String k, double at) =>
      !done.contains(k) && t >= at && done.add(k);

  List<(double, double)> _topEdge() {
    final off = _beast.h * (1 - _rise(t));
    final pts = <(double, double)>[];
    for (var x = 0; x < _beast.w; x++) {
      for (var y = 0; y < _beast.h; y++) {
        if (_beast.part[y * _beast.w + x] != 0) {
          final ly = y - _beast.h + off;
          if (ly < 0) pts.add((x - _beast.w / 2, ly));
          break;
        }
      }
    }
    return pts;
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final h = _heat(t);
    if (t < _ign) {
      final ph = (t / _ign) * math.pi;
      for (final s in const [-1, 1]) {
        final a = math.pi / 2 + s * ph;
        final y = math.sin(a) * _r0 * _sy;
        if (rng.chance(0.5)) {
          if (y < -0.5) {
            ps.spawn(
              P.spark,
              math.cos(a) * _r0,
              y,
              rng.range(-40, 40),
              -rng.range(40, 130),
              rng.range(0.2, 0.45),
            );
          } else {
            ps.spawn(
              P.ember,
              math.cos(a) * _r0,
              y,
              rng.range(-20, 20),
              -rng.range(30, 70),
              rng.range(0.3, 0.6),
              cRamp[6],
              1.4,
            );
          }
        }
      }
    }
    if (t > 0.2 && t < _fadeAt + 0.6 && rng.chance(0.2 * h)) {
      final a = rng.range(0, tau);
      final r = rng.pick([_r0, _r1, _r0]);
      ps.spawn(
        P.ember,
        math.cos(a) * r,
        math.sin(a) * r * _sy,
        rng.range(-10, 10),
        -rng.range(20, 50),
        _left(0.8, 1.6),
        cRamp[5],
        rng.range(1, 1.8),
      );
    }
    if (t > 0.15 && rng.chance(0.4 * math.min(1.0, h))) {
      final a = rng.range(0, tau);
      final r = rng.chance(0.7) ? _r0 : _r1;
      final ok = t < _ign
          ? (((a - math.pi / 2 + math.pi * 3) % tau) - math.pi).abs() <
              (t / _ign) * math.pi
          : true;
      if (ok) {
        ps.spawn(
          P.fire,
          math.cos(a) * r,
          math.sin(a) * r * _sy - 0.5,
          rng.range(-4, 4),
          -rng.range(6, 16),
          rng.range(0.18, 0.4),
          0,
          rng.range(0.8, 1.6) * math.min(1.0, h),
          0,
          rng.chance(0.25) ? PF.smokes : 0,
        );
      }
    }
    if (t > 0.3 && t < _fadeAt + 0.4 && rng.chance(0.05 * h)) {
      final a = rng.range(0, tau);
      ps.spawn(
        P.smoke,
        math.cos(a) * _r0 * 0.9,
        math.sin(a) * _r0 * _sy - 1,
        rng.range(-4, 4),
        -rng.range(12, 24),
        _left(1.4, 2.2),
        0,
        rng.range(2.2, 3.4),
      );
    }
    if (_once('ign', _ign)) lights.add(0, -4, 60, cRamp[4], 0.55, 0.5);
    if (_once('runes', _runesAt)) lights.add(0, -4, 50, cRamp[5], 0.5, 0.35);
    if (t > _runesAt && t < _breakAt && rng.chance(0.35)) {
      ps.spawn(
        P.grit,
        rng.range(-_r1, _r1),
        -0.5,
        rng.range(-20, 20),
        -rng.range(40, 120),
        rng.range(0.5, 0.9),
        rng.pick([st[2], st[3], st[4]]),
        1,
      );
    }
    if (t > _runesAt && t < _breakAt && rng.chance(0.1)) {
      ps.spawn(
        P.dust,
        rng.range(-_r1, _r1),
        -1,
        rng.range(-12, 12),
        -rng.range(4, 12),
        rng.range(0.4, 0.7),
        dustCol,
        rng.range(1.5, 2.5),
      );
    }
    if (_once('break', _breakAt)) {
      lights.add(0, -18, 64, cRamp[4], 0.9, 0.6);
      lights.add(0, -8, 26, cRamp[6], 0.8, 0.14);
      for (var i = 0; i < 18; i++) {
        rocks.add(
          DebrisBit(
            kind: B.chunk,
            x: rng.range(-14, 14),
            y: -2,
            vx: rng.range(-75, 75),
            vy: -rng.range(170, 320),
            g: 1,
            drag: 0.7,
            bounce: 0.32,
            life: rng.range(1.6, 2.4),
            a: rng.range(0, tau),
            va: rng.range(-14, 14),
            s: rng.range(1.3, 3),
            rampColors: rub,
          ),
        );
      }
      for (var i = 0; i < 60; i++) {
        final u = rng.range(-1, 1);
        final a = -math.pi / 2 + u * 0.7;
        final sp = rng.range(80, 230) * (1 - 0.4 * u.abs());
        ps.spawn(
          P.grit,
          u * 10,
          -1,
          math.cos(a) * sp,
          math.sin(a) * sp,
          rng.range(1, 1.8),
          rng.pick([st[2], st[3], st[3], st[4]]),
          rng.chance(0.4) ? 2 : 1,
        );
      }
      for (var i = 0; i < 12; i++) {
        final s = rng.sign();
        ps.spawn(
          P.smoke,
          s * rng.range(2, 14),
          -rng.range(1, 5),
          s * rng.range(35, 100),
          -rng.range(4, 24),
          rng.range(1.2, 2),
          dustCol,
          rng.range(3.5, 6),
          rng.range(0, 0.1),
          PF.big,
        );
      }
      for (var i = 0; i < 4; i++) {
        final s = rng.sign();
        ps.spawn(
          P.smoke,
          s * rng.range(10, 18),
          -rng.range(2, 8),
          s * rng.range(10, 30),
          -rng.range(40, 90),
          rng.range(1.4, 2.2),
          dustCol,
          rng.range(4, 6.5),
          rng.range(0, 0.12),
          PF.big,
        );
      }
      for (var i = 0; i < 24; i++) {
        final a = -math.pi / 2 + rng.range(-1.1, 1.1);
        final sp = rng.range(150, 360);
        ps.spawn(
          P.spark,
          rng.range(-6, 6),
          -2,
          math.cos(a) * sp,
          math.sin(a) * sp,
          rng.range(0.25, 0.65),
        );
      }
    }
    final rv = _rise(t) - _rise(t - dt);
    if (t > _breakAt && t < _breakAt + 1.2 && rv > 0) {
      if (rng.chance(math.min(0.9, rv * 140))) {
        final e = _topEdge();
        if (e.isNotEmpty) {
          final (x, y) = rng.pick(e);
          ps.spawn(
            P.grit,
            x,
            y,
            rng.range(-25, 25),
            -rng.range(10, 60),
            rng.range(0.8, 1.4),
            rng.pick([st[2], st[3], st[4]]),
            rng.chance(0.3) ? 2 : 1,
          );
        }
      }
      if (rng.chance(math.min(0.8, rv * 70))) {
        final s = rng.sign();
        ps.spawn(
          P.smoke,
          s * rng.range(10, 22),
          -rng.range(1, 4),
          s * rng.range(30, 80),
          -rng.range(2, 12),
          rng.range(1, 1.8),
          dustCol,
          rng.range(3, 5.5),
          0,
          PF.big,
        );
      }
    }
    if (_once('heave2', _breakAt + 0.64)) {
      lights.add(0, -10, 56, cRamp[4], 0.6, 0.4);
      for (var i = 0; i < 8; i++) {
        rocks.add(
          DebrisBit(
            kind: B.chunk,
            x: rng.sign() * rng.range(10, 22),
            y: -2,
            vx: rng.sign() * rng.range(25, 70),
            vy: -rng.range(90, 180),
            g: 1,
            drag: 0.7,
            bounce: 0.3,
            life: rng.range(1.2, 1.8),
            a: rng.range(0, tau),
            va: rng.range(-12, 12),
            s: rng.range(1.2, 2.4),
            rampColors: rub,
          ),
        );
      }
    }
    if (_once('eyes', _eyesAt)) {
      for (final (ex, ey) in _beast.glints) {
        lights.add(ex, ey, 14, cRamp[6], 0.7, 0.3);
        for (var i = 0; i < 5; i++) {
          ps.spawn(
            P.spark,
            ex,
            ey,
            rng.range(-90, 90),
            rng.range(-90, 20),
            rng.range(0.15, 0.35),
          );
        }
      }
      for (var i = 0; i < 10; i++) {
        final s = rng.sign();
        ps.spawn(
          P.dust,
          s * rng.range(8, 20),
          -1,
          s * rng.range(30, 80),
          -rng.range(3, 10),
          rng.range(0.4, 0.8),
          dustCol,
          rng.range(1.5, 3),
        );
      }
    }
    if (t > _fadeAt + 0.05 && t < _fadeAt + 0.75 && rng.chance(0.45)) {
      final x = rng.intRange(4, _beast.w - 5);
      final y = rng.intRange(2, _beast.h - 4);
      if (_beast.part[y * _beast.w + x] != 0) {
        final lx = x - _beast.w / 2;
        final ly = (y - _beast.h).toDouble();
        ps.spawn(
          P.smoke,
          lx,
          ly,
          rng.range(-6, 6),
          -rng.range(10, 26),
          _left(0.9, 1.5),
          _soot,
          rng.range(2, 3.4),
        );
        if (rng.chance(0.3)) {
          ps.spawn(
            P.ember,
            lx,
            ly,
            rng.range(-10, 10),
            -rng.range(15, 40),
            _left(0.6, 1.2),
            cRamp[4],
            1,
          );
        }
      }
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
            dustCol,
            rng.range(1.2, 2.4),
          );
        }
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final h = _heat(t);
    if (h <= 0.01) return;
    p.glow(0, -2, 52, cRamp[4], 0.28 * h);
    p.glow(0, -22, 72, cRamp[4], 0.1 * h);
    p.glow(0, -1, 22, cRamp[5], 0.2 * h);
    final ck =
        smooth(_runesAt, _breakAt, t) * (1 - smooth(_fadeAt, _fadeAt + 0.7, t));
    if (ck > 0) {
      for (final pts in cracks) {
        for (var i = 1; i < pts.length; i++) {
          final u = i / pts.length;
          if (u > ck * 1.1) break;
          final cool = smooth(_breakAt + 0.1, _breakAt + 1.1, t);
          final ci = (6 - u * 2 - cool * 2.6 + 0.5).floor();
          p.line(
            pts[i - 1].$1,
            pts[i - 1].$2,
            pts[i].$1,
            pts[i].$2,
            cRamp[clampInt(ci, 2, 6)],
            1,
          );
        }
      }
    }
    const n = 220;
    final prog = clamp(t / _ign) * math.pi;
    for (var j = 0; j < n; j++) {
      final a = (j / n) * tau;
      final d = (((a - math.pi / 2 + math.pi * 3) % tau) - math.pi).abs();
      if (d > prog) continue;
      final fresh = prog - d < 0.25 && t < _ign + 0.1;
      final f = noise(a * 6 + t * 5, 4) * 0.5 + 0.5;
      final k = h * (0.7 + 0.5 * f);
      final ca = math.cos(a);
      final sa = math.sin(a);
      p.dot(
        ca * _r0,
        sa * _r0 * _sy,
        fresh
            ? kWhite
            : k > 0.95
                ? cRamp[6]
                : k > 0.6
                    ? cRamp[5]
                    : k > 0.35
                        ? cRamp[4]
                        : cRamp[3],
      );
      p.dot(ca * (_r0 + 2.2), sa * (_r0 + 2.2) * _sy, k > 0.8 ? cRamp[4] : cRamp[3], 0.9);
      if (t > _runesAt - 0.15) {
        p.dot(
          ca * _r1,
          sa * _r1 * _sy,
          k > 0.9 ? cRamp[5] : (k > 0.5 ? cRamp[4] : cRamp[3]),
          smooth(_runesAt - 0.15, _runesAt + 0.05, t),
        );
      }
      if (j % 11 == 0) p.glow(ca * _r0, sa * _r0 * _sy, 9, cRamp[4], 0.22 * k);
    }
    final rk = smooth(_runesAt - 0.1, _runesAt + 0.15, t);
    if (rk > 0) {
      for (final r in runes) {
        final k = h * rk * (0.75 + 0.35 * noise(t * 4 + r.a * 5, 8));
        const mid = (_r0 + _r1) / 2 + 0.5;
        final tax = -math.sin(r.a);
        final tay = math.cos(r.a);
        final nax = math.cos(r.a);
        final nay = math.sin(r.a);
        (double, double) proj((double, double) uv) => (
          nax * mid + tax * uv.$1 * 1.1 + nax * uv.$2,
          (nay * mid + tay * uv.$1 * 1.1 + nay * uv.$2) * _sy,
        );
        for (final strokePts in r.g) {
          for (var i = 1; i < strokePts.length; i++) {
            final (x0, y0) = proj(strokePts[i - 1]);
            final (x1, y1) = proj(strokePts[i]);
            p.line(
              x0,
              y0,
              x1,
              y1,
              k > 0.9 ? cRamp[6] : (k > 0.55 ? cRamp[5] : cRamp[4]),
              math.min(1.0, k * 1.5),
            );
          }
        }
      }
    }
    final hole =
        smooth(_breakAt - 0.05, _breakAt + 0.15, t) *
        (1 - smooth(_breakAt + 0.95, _breakAt + 1.5, t));
    if (hole > 0) {
      final hw = 15 * hole;
      p.shade((-hw - 1).floor(), -1, (hw + 1).ceil(), 4, (x, y, out) {
        final d = hypot(x / hw, (y - 0.5) / 3.2);
        if (d > 1) return null;
        out.c = d > 0.86 ? cRamp[4] : (d > 0.62 ? cRamp[1] : cRamp[0]);
        return null;
      });
      p.glow(0, 0, 24, cRamp[5], 0.3 * hole * h);
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final r = _rise(t);
    final off = _beast.h * (1 - r);
    final h = _heat(t);
    final fade = smooth(_fadeAt + 0.1, _fadeAt + 0.8, t);
    if (r > 0) {
      final w = _beast.w;
      final bh = _beast.h;
      final x0 = -w / 2;
      final oy = off - bh;
      final k = math.min(1.0, h);
      bool gone(int x, int y) =>
          fade > 0 &&
          fade > 0.06 + 0.86 * (0.55 * (1 - y / bh) + 0.45 * rand(x, y, 3));
      for (final (x, y) in _beast.outline) {
        if (y + oy < 0 && !gone(x, math.min(bh - 1, math.max(0, y)))) {
          p.px(x0 + x, y + oy, sh[0]);
        }
      }
      for (var y = 0; y < bh; y++) {
        final ly = y + oy;
        if (ly >= 0) break;
        final upRim = math.exp(ly / 17) * k;
        final upPlane = math.exp(ly / 19) * k;
        for (var x = 0; x < w; x++) {
          final i = y * w + x;
          final pt = _beast.part[i];
          if (pt == 0 || gone(x, y)) continue;
          final ramp = pt == 2 ? hr : sh;
          final a = _beast.amb[i];
          var si = _beast.crease[i] != 0
              ? 0
              : a > 0.74
                  ? 4
                  : a > 0.56
                      ? 3
                      : a > 0.36
                          ? 2
                          : 1;
          if (pt == 2 && si > 0) si = math.min(4, si + (y < 3 ? 2 : 1));
          final lr = _beast.rim[i] * upRim;
          final lp = _beast.down[i] * upPlane * 0.6;
          var c = ramp[si];
          if (lr > 0.7) {
            c = cRamp[5];
          } else if (lr > 0.48) {
            c = cRamp[4];
          } else if (lr > 0.3 || lp > 0.42) {
            c = cRamp[3];
          } else if (lr > 0.17 || lp > 0.26) {
            c = mix(cRamp[2], ramp[si], 0.3);
          } else if (lr > 0.08 || lp > 0.12) {
            c = mix(ramp[si], cRamp[1], 0.6);
          }
          p.px(x0 + x, ly, c);
        }
      }
      for (final (x, y) in _beast.tusks) {
        if (y + oy < 0 && !gone(x, y)) {
          p.px(x0 + x, y + oy, mix(hr[4], cRamp[4], 0.35 * k));
        }
      }
      for (final (x, y) in _beast.eyes) {
        if (y + oy < 0 && !gone(x, y)) {
          p.px(
            x0 + x,
            y + oy,
            t > _eyesAt - 0.05
                ? (t < _eyesAt + 0.1 ? kWhite : cRamp[6])
                : (t > _breakAt + 0.5 ? cRamp[2] : sh[0]),
          );
        }
      }
      if (t > _eyesAt - 0.05) {
        final ek =
            (1 - smooth(_fadeAt + 0.6, _fadeAt + 1.0, t)) *
            (0.85 + 0.15 * math.sin(t * 13));
        for (final (ex, ey0) in _beast.glints) {
          final ey = ey0 + off;
          if (ey >= 0) continue;
          p.glow(ex + 0.5, ey, 6, cRamp[5], 0.5 * ek);
          final g = (t - _eyesAt) / 0.3;
          if (g > 0 && g < 1) {
            final l = 9 * math.pow(1 - g, 1.5);
            p.lineShaded(
              ex - l,
              ey,
              ex + l,
              ey,
              color: (double u) => (u - 0.5).abs() < 0.18
                  ? kWhite
                  : ((u - 0.5).abs() < 0.35 ? cRamp[6] : cRamp[5]),
            );
            if (g < 0.4) {
              p.line(ex, ey - 2 * (1 - g), ex, ey + 2 * (1 - g), cRamp[6]);
            }
          } else if (fade > 0.6 && ek > 0.05) {
            p.px(ex, ey, cRamp[6]);
          }
        }
      }
      p.glow(0, -6, 30, cRamp[4], 0.25 * h * r);
    }
    rocks.draw(p);
    ps.draw(p, 'front');
    lights.draw(p);
  }
}
