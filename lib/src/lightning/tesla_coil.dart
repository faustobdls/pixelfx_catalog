// The arcs (forking bolts re-struck every frame, inked with halo, body, core and light), their flicker and the
// zaps that strike the floor in a spray of sparks follow Sprite Fusion's open-source lightning and energy orb
// (https://www.spritefusion.com/pixel-art-vfx/lightning), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'lightning_lib.dart';

const int _fps = 30;
const int _n = 72;
const double _period = _n / _fps;
const double _ty = -57.0;
const double _rr = 12.0;
const double _tr = 3.6;
const double _sy = 0.45;
const double _cTop = -50.0;
const double _cBot = -12.0;

final List<int> _iron =
    ['#120f18', '#1e1a27', '#2c2637', '#3f374d', '#5a5068']
        .map(hex)
        .toList(growable: false);
final int _ash = hex('#5b5566');
const List<double> _fl = [1.0, 0.7, 0.95, 0.55, 0.85, 0.45, 0.7, 0.35];

class _CoilArc {
  final int f0;
  final int len;
  final int side;
  final double phi;
  final bool front;
  final double th0;
  final double th1;
  final double l;

  const _CoilArc({
    required this.f0,
    required this.len,
    required this.side,
    required this.phi,
    required this.front,
    required this.th0,
    required this.th1,
    required this.l,
  });
}

class _CoilStrike {
  final int f0;
  final int side;
  final double x;
  final double phi;

  const _CoilStrike({
    required this.f0,
    required this.side,
    required this.x,
    required this.phi,
  });
}

({List<_CoilArc> arcs, List<_CoilStrike> strikes}) _plan(int seed) {
  final r = rng(seed, 1);
  final arcs = <_CoilArc>[];
  final strikes = <_CoilStrike>[];
  for (final (v, n) in const [(2, 3), (20, 3), (30, 1), (38, 3), (56, 3), (66, 1)]) {
    for (var j = 0; j < n + r.intRange(0, 1); j++) {
      final side = r.chance(0.5) ? 1 : -1;
      final front = r.chance(0.55);
      final a = r.range(0.15, 1.1);
      final phi = side > 0
          ? (front ? a : -a)
          : (front ? math.pi - a : math.pi + a);
      final th0 = r.range(-1.15, 0.35);
      arcs.add(
        _CoilArc(
          f0: (v + j * r.intRange(2, 4)) % _n,
          len: r.intRange(3, 7),
          side: side,
          phi: phi,
          front: front,
          th0: th0,
          th1: th0 + r.range(-0.6, 0.6),
          l: r.range(24.0, 52.0),
        ),
      );
    }
  }
  for (final (f0, side) in const [(14, 1), (47, -1)]) {
    strikes.add(
      _CoilStrike(
        f0: f0,
        side: side,
        x: side * r.range(38.0, 56.0),
        phi: side > 0 ? 0.4 : math.pi - 0.4,
      ),
    );
  }
  return (arcs: arcs, strikes: strikes);
}

int _ageOf(int f, int f0) => (((f - f0) % _n) + _n) % _n;

Point2 _root(double phi, [double up = 0.0]) => (
      math.cos(phi) * (_rr + _tr * 0.6),
      _ty + math.sin(phi) * _rr * _sy - up,
    );

void _drawCoil(Painter p, List<int> cu, List<double> lit, List<int> c) {
  final n = cu.length;
  p.shade(-14, -8, 14, 0, (x, y, out) {
    if (x < -13.0 || x > 13.0 || y < -7.0) return null;
    final edge = x < -12.0 ? 2 : (x > 12.0 ? 0 : 1);
    out.c = y < -6.0
        ? _iron[4]
        : (y < -5.0
            ? _iron[3]
            : (y > -1.0
                ? _iron[0]
                : _iron[edge + 1 > 2 ? 2 : edge + (y < -3.0 ? 1 : 0)]));
    return null;
  });
  for (final rx in const [-10, 10]) {
    p.px(rx, -4, _iron[4]);
    p.px(rx, -3, _iron[0]);
  }
  void turn(double y, bool front) {
    for (var a = 0.0; a < tau; a += 0.04) {
      if ((math.sin(a) >= 0.0) != front) continue;
      final x = math.cos(a) * 10.0;
      final yy = y + math.sin(a) * 2.2;
      final l = 0.5 - 0.4 * math.cos(a) + (front ? 0.25 : -0.2);
      p.px(x, yy, cu[clampInt(jsRound(l * (n - 1)), 0, n - 1)]);
      p.px(x, yy + 1.0, cu[clampInt(jsRound(l * (n - 1)) - 2, 0, n - 1)]);
    }
  }

  turn(-10.5, false);
  turn(-13.5, false);
  p.shade(-6, _cTop, 6, _cBot, (x, y, out) {
    if (x < -5.0 || x > 5.0) return null;
    final u = (x + 5.5) / 11.0;
    final nx = u * 2.0 - 1.0;
    final wire = (y.floor() & 1) == 0;
    var l = 0.62 -
        0.55 * nx -
        0.35 * nx * nx +
        ((nx + 0.35).abs() < 0.12 ? 0.3 : 0.0);
    if (!wire) l -= 0.32;
    out.c = cu[clampInt(jsRound(l * (n - 1)), 0, n - 1)];
    if (wire &&
        ((nx < -0.75 && lit[0] > 0.25) || (nx > 0.75 && lit[1] > 0.25))) {
      out.c = nx < 0.0
          ? (lit[0] > 0.6 ? c[6] : c[4])
          : (lit[1] > 0.6 ? c[6] : c[4]);
    }
    return null;
  });
  p.line(-5, _cTop - 1, 5, _cTop - 1, _iron[3]);
  p.line(-4, _cTop - 2, 4, _cTop - 2, _iron[2]);
  turn(-10.5, true);
  turn(-13.5, true);
}

class _TorusMap {
  final int x0;
  final int y0;
  final int w;
  final int h;
  final Float32List z;
  final Float32List n;
  final double ca;
  final double sa;

  const _TorusMap({
    required this.x0,
    required this.y0,
    required this.w,
    required this.h,
    required this.z,
    required this.n,
    required this.ca,
    required this.sa,
  });
}

_TorusMap? _torus;

_TorusMap _torusMap() {
  final existing = _torus;
  if (existing != null) return existing;
  const sa = _sy;
  final ca = math.sqrt(1.0 - _sy * _sy);
  final x0 = -(_rr + _tr).ceil() - 1;
  final y0 = (_ty - _rr * _sy - _tr).floor() - 2;
  final w = 2 * -x0 + 2;
  final h = (_ty + _rr * _sy + _tr).ceil() + 3 - y0;
  final z = Float32List(w * h);
  for (var i = 0; i < z.length; i++) {
    z[i] = -1e9;
  }
  final n = Float32List(w * h * 3);
  for (var i = 0; i < 480; i++) {
    final phi = (i / 480.0) * tau;
    final cp = math.cos(phi);
    final sp = math.sin(phi);
    for (var j = 0; j < 96; j++) {
      final psi = (j / 96.0) * tau;
      final cs = math.cos(psi);
      final ss = math.sin(psi);
      final rr = _rr + _tr * cs;
      final x = rr * cp;
      final y = _tr * ss;
      final zz = rr * sp;
      final px = x.floor() - x0;
      final py = (_ty - y * ca + zz * sa).floor() - y0;
      final d = zz * ca + y * sa;
      if (px < 0 || py < 0 || px >= w || py >= h) continue;
      final k = py * w + px;
      if (d > z[k]) {
        z[k] = d;
        n[k * 3] = cs * cp;
        n[k * 3 + 1] = ss;
        n[k * 3 + 2] = cs * sp;
      }
    }
  }
  final map = _TorusMap(
    x0: x0,
    y0: y0,
    w: w,
    h: h,
    z: z,
    n: n,
    ca: ca,
    sa: sa,
  );
  _torus = map;
  return map;
}

(double, double, double) _norm(double x, double y, double z) {
  final l = math.sqrt(x * x + y * y + z * z);
  return (x / l, y / l, z / l);
}

final (double, double, double) _key = _norm(-0.55, 0.75, 0.45);

void _drawTorus(Painter p, List<int> st, List<int> c, List<double> lit) {
  final tMap = _torusMap();
  final m = st.length;
  final half = _norm(_key.$1, _key.$2 + tMap.sa, _key.$3 + tMap.ca);
  bool on(int x, int y) =>
      x >= 0 &&
      y >= 0 &&
      x < tMap.w &&
      y < tMap.h &&
      tMap.z[y * tMap.w + x] > -1e8;

  for (var y = 0; y < tMap.h; y++) {
    for (var x = 0; x < tMap.w; x++) {
      final k = y * tMap.w + x;
      if (tMap.z[k] < -1e8) continue;
      final nx = tMap.n[k * 3];
      final ny = tMap.n[k * 3 + 1];
      final nz = tMap.n[k * 3 + 2];
      final dif = math.max(0.0, nx * _key.$1 + ny * _key.$2 + nz * _key.$3);
      final spec = math
          .pow(math.max(0.0, nx * half.$1 + ny * half.$2 + nz * half.$3), 28.0)
          .toDouble();
      final inner = nx * (x + tMap.x0 + 0.5) < 0.0 &&
              (x + tMap.x0 + 0.5).abs() < _rr
          ? 0.75
          : 1.0;
      var col = spec > 0.55
          ? st[m - 1]
          : st[clampInt(
              ((0.12 + 0.8 * dif * inner + spec) * (m - 1.01)).floor(),
              0,
              m - 2,
            )];
      for (final (s, l) in [(-1, lit[0]), (1, lit[1])]) {
        final r = math.max(0.0, s * nx * 0.85 + ny * 0.25 + nz * 0.45) *
            math.min(1.0, l);
        if (r > 0.88) {
          col = c[6];
        } else if (r > 0.62) {
          col = mix(col, c[5], 0.6);
        } else if (r > 0.38) {
          col = mix(col, c[4], 0.3);
        }
      }
      if (!on(x, y + 1) && ny < 0.3) col = st[0];
      p.px(x + tMap.x0, y + tMap.y0, col);
    }
  }
}

final PureEffect teslaCoilEffect = PureEffect(
  meta: const EffectMeta(
    id: 'lightning/tesla-coil',
    name: 'Tesla coil',
    desc:
        'A copper coil under a steel torus throws branching arcs that lash out in volleys and now and then strike the floor in a spray of sparks, lighting the metal and the ground.',
    category: 'lightning',
    tags: ['lightning', 'electric', 'tesla', 'machine', 'prop', 'loop'],
    size: (224, 136),
    origin: (112, 120),
    duration: 2.4,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': voltPalette,
      'sparks': plasmaSparks,
      'copper': [
        '#2a120c',
        '#5a2814',
        '#8e4a1e',
        '#c4772f',
        '#eaa65a',
        '#ffd9a0',
      ],
      'steel': [
        '#0f121c',
        '#1f2433',
        '#353d52',
        '#556078',
        '#7f8ba3',
        '#b8c3d6',
        '#f2f6ff',
      ],
      'seed': 4,
    },
  ),
  onDraw: (Painter p, double t, Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final cu = fit((o['copper'] as List).cast<Object>(), 6);
    final stCols = fit((o['steel'] as List).cast<Object>(), 7);
    final sparks =
        (o['sparks'] as List).cast<Object>().map(hex).toList(growable: false);
    final seed = o.seed;
    final f = (t * _fps + 1e-6).floor() % _n;
    final planned = _plan(seed);
    final arcs = planned.arcs;
    final strikes = planned.strikes;
    final lit = <double>[0.0, 0.0];
    final live = [
      for (final a in arcs)
        if (_ageOf(f, a.f0) < a.len) a,
    ];
    for (final a in live) {
      lit[a.side > 0 ? 1 : 0] += _fl[_ageOf(f, a.f0)] * 0.6;
    }
    for (final s in strikes) {
      final a = _ageOf(f, s.f0);
      if (a < 6) lit[s.side > 0 ? 1 : 0] += 1.0;
    }
    final act = math.min(1.0, (lit[0] + lit[1]) * 0.5);

    p.glow(0, -10, 58, c[3], 0.14 + 0.25 * act);
    p.ellipse(0, 0.5, 15, 1.6, _iron[0]);
    for (final s in strikes) {
      final age = (((t - s.f0 / _fps) % _period) + _period) % _period;
      lightningScorch(
        p,
        s.x,
        0.0,
        7.0,
        math.pow(clamp(1.0 - age / 1.1), 1.3).toDouble(),
        1.0 - clamp((age - 1.4) / 0.6),
      );
      for (var j = 0; j < 2; j++) {
        final u = (age - 0.12 - j * 0.18) / 1.2;
        if (u > 0.0 && u < 1.0) {
          lightningPuff(
            p,
            s.x + (j != 0 ? 3.0 : -2.0) + u * 5.0 * s.side,
            -3.0 - u * 16.0 - j * 2.0,
            2.6 + j,
            u,
            mix(_ash, c[2], 0.3),
          );
        }
      }
    }

    void drawArc(_CoilArc a) {
      final age = _ageOf(f, a.f0);
      final u = age / math.max(1, a.len - 1);
      final th = a.th0 + (a.th1 - a.th0) * Ease.outQuad(u);
      final ang = a.side > 0 ? th : math.pi - th;
      final (x0, y0) = _root(a.phi);
      final l = a.l * (age == 0 ? 0.75 : 1.0);
      final r = rng(seed, 21, a.f0, f);
      boltStrokeWith(
        p,
        zigzag(r, x0, y0, x0 + math.cos(ang) * l, y0 + math.sin(ang) * l,
            0.32, 0.75),
        _fl[age],
        c,
        s: 0.6,
        light: 0.4,
      );
      p.glow(x0, y0, 10, c[5], 0.5 * _fl[age]);
    }

    for (final a in live) {
      if (!a.front) drawArc(a);
    }
    _drawCoil(p, cu, lit, c);
    _drawTorus(p, stCols, c, lit);

    final rc = rng(seed, 9, f);
    for (var i = 0; i < 6; i++) {
      final phi = rc.range(0.0, tau);
      final d = rc.range(1.0, 3.0);
      final x = math.cos(phi) * (_rr + _tr + d);
      final y = _ty + math.sin(phi) * (_rr * _sy + _tr + d * 0.7);
      p.px(x, y, rc.chance(0.3) ? c[5] : c[3]);
      if (rc.chance(0.4)) p.px(x + math.cos(phi), y + math.sin(phi) * 0.6, c[2]);
      p.glow(x, y, 4, c[3], 0.3);
    }

    for (var i = 0; i < 2; i++) {
      final phi = rc.range(0.0, tau);
      final x0 = math.cos(phi) * (_rr + _tr * 0.8);
      final y0 = _ty + math.sin(phi) * (_rr * _sy + _tr * 0.6);
      final a = math.atan2(math.sin(phi) * 0.6 - 0.5, math.cos(phi)) +
          rc.range(-0.5, 0.5);
      final l = rc.range(4.0, 10.0);
      crackle(
        p,
        zigzag(rc, x0, y0, x0 + math.cos(a) * l, y0 + math.sin(a) * l, 0.4, 0.4),
        rc.range(0.35, 0.65),
        c,
        0.3,
      );
    }
    p.glow(0, _ty, 34, c[3], 0.18 + 0.3 * act);
    for (final a in live) {
      if (a.front) drawArc(a);
    }

    for (final s in strikes) {
      final age = _ageOf(f, s.f0);
      if (age < 6) {
        final k = const [1.0, 0.75, 1.0, 0.6, 0.85, 0.4][age];
        final (x0, y0) = _root(s.phi, -2.0);
        final r = rng(seed, 41, s.f0, f);
        boltStrokeWith(
          p,
          zigzag(r, x0, y0, s.x, 0.0, 0.22, 0.55),
          k,
          c,
          s: age == 0 ? 0.95 : 0.8,
          hero: age == 0,
        );
        p.circle(s.x, -1, 3.0 * k + 1.5, c[2]);
        p.circle(s.x, -1, 3.0 * k + 0.5, c[5]);
        p.circle(s.x, -1, 2.0 * k, kWhite);
        p.glow(s.x, -10, 40, c[4], 0.55 * k);
        p.glow(s.x, -3, 12, c[6], 0.5 * k);
        if (age < 2) p.glow(0, -50, 120, c[3], 0.25 * k);
      }
      final st = (((t - s.f0 / _fps) % _period) + _period) % _period;
      for (var j = 0; j < 18; j++) {
        final r = rng(seed, 51, s.f0, j);
        final life = r.range(0.3, 0.65);
        if (st >= life) continue;
        final a = -math.pi / 2.0 + r.range(-1.3, 1.3);
        final sp = r.range(50.0, 190.0);
        final (x, y, vx, vy) = lightningFlight(
          s.x,
          -1.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          st,
          floor: 0.0,
        );
        lightningSpark(p, x, y, vx, vy, 1.0 - st / life, sparks);
      }
    }

    for (final a in arcs) {
      final age = (((t - a.f0 / _fps) % _period) + _period) % _period;
      final ang = a.side > 0 ? a.th0 : math.pi - a.th0;
      final (x0, y0) = _root(a.phi);
      for (var j = 0; j < 3; j++) {
        final r = rng(seed, 61, a.f0, j);
        final life = r.range(0.15, 0.35);
        if (age >= life) continue;
        final tx = x0 + math.cos(ang) * a.l * 0.75;
        final ty = y0 + math.sin(ang) * a.l * 0.75;
        final b = ang + r.range(-0.9, 0.9);
        final sp = r.range(50.0, 150.0);
        final (x, y, vx, vy) = lightningFlight(
          tx,
          ty,
          math.cos(b) * sp,
          math.sin(b) * sp,
          age,
          floor: 0.0,
        );
        lightningSpark(p, x, y, vx, vy, 1.0 - age / life, sparks);
      }
    }
  },
);
