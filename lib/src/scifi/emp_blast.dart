import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'scifi_lib.dart';

const double _pop = 0.42;
const double _grow = 0.32;
const double _strobe = 1.25;
const double _break = 1.58;
const double _duration = 3.2;

class _EmpArc {
  final double t;
  final List<Point2> pts;
  final double life;

  const _EmpArc({required this.t, required this.pts, required this.life});
}

class _DeadPx {
  double x;
  double y;
  final double vx;
  double vy;
  double life;
  final double max;
  final int s;
  final int c;
  final double ph;

  _DeadPx({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.max,
    required this.s,
    required this.c,
    required this.ph,
  });
}

class _EmpBlastSim extends BaseEffectSim {
  final List<int> c;
  final int f;
  final double rm;
  final int seed;
  final Rng r;
  final Particles ps;
  final Lights lights = Lights();
  final List<_EmpArc> arcs = [];
  final List<_DeadPx> dead = [];

  double t = 0.0;
  bool popped = false;
  bool broke = false;
  double nextArc = 0.0;
  List<List<Point2>> star = [];
  int starAt = -1;

  // Note: share the same Rng instance as Particles so RNG draw order matches JS 1:1.
  factory _EmpBlastSim.create(Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final r = Rng(o.seed);
    final ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [kWhite, c[6], c[5], c[4]],
      haze: c[5],
    );
    return _EmpBlastSim._init(
      c: c,
      f: hex(o['fringe'] ?? '#ff5ad8'),
      rm: o.numOpt('radius', 56.0),
      seed: o.seed,
      r: r,
      ps: ps,
    );
  }

  _EmpBlastSim._init({
    required this.c,
    required this.f,
    required this.rm,
    required this.seed,
    required this.r,
    required this.ps,
  });

  double _radius() => t < _pop
      ? 0.0
      : rm *
          (0.12 + 0.88 * Ease.outExpo(clamp((t - _pop) / _grow))) *
          (1.0 + 0.04 * clamp((t - _pop - _grow) / 0.8));

  bool _off() =>
      t > _strobe &&
      t < _break &&
      rand(seed, (t * 30.0).floor()) <
          0.2 + 0.5 * ((t - _strobe) / (_break - _strobe));

  void _charge(Painter p) {
    if (t >= _pop) return;
    final k = t / _pop;
    final rad = 1.0 + 3.2 * k * k;
    final tick = math.sin(tau * (2.0 * t + 10.0 * t * t)) > 0.0;
    p.circle(0, -7, rad + 1.0, c[4]);
    p.circle(0, -7, rad, tick ? kWhite : c[6]);
    final frame = (t * 30.0).floor();
    final rr = Rng(seed * 97 + frame);
    for (var i = 0; i < 1 + (k * 3.0).floor(); i++) {
      final a = rr.range(0.0, tau);
      final l = rad + 2.0 + rr.range(2.0, 6.0) * k;
      strokeArc(
        p,
        bolt(
          rr,
          math.cos(a) * rad,
          -7.0 + math.sin(a) * rad,
          math.cos(a) * l,
          -7.0 + math.sin(a) * l,
          jag: 0.4,
          depth: 2,
        ),
        [c[2], c[5], c[4]],
        0.7,
        0.5,
      );
    }
    p.glow(0, -7, 8.0 + 16.0 * k, c[4], 0.4 + 0.5 * k * (tick ? 1.0 : 0.6));
  }

  void _bubble(Painter p, bool near) {
    final rad = _radius();
    if (rad <= 1.0 || t >= _break || _off()) return;
    final age = t - _pop;
    final slot = (t * 30.0).floor();
    final roll = age * 40.0;
    final ry = rad * 0.16;
    final tears = <int, int>{};
    for (var i = 0; i < 2 + (t > _strobe ? 4 : 0); i++) {
      tears[(-rand(seed, slot, i) * rad).floor()] =
          (rand(seed, slot, i, 1) < 0.5 ? -1 : 1) *
              (2 + (rand(seed, slot, i, 2) * 4.0).floor());
    }
    final y0 = (-rad).floor();
    final y1 = ry.ceil();
    final x0 = (-rad).floor();
    final x1 = rad.ceil();
    for (var y = y0; y <= y1; y++) {
      final shift = tears[y] ?? 0;
      for (var x = x0; x <= x1; x++) {
        final sx = x - shift;
        final d = math.sqrt((sx + 0.5) * (sx + 0.5) +
                (y < 0 ? (y + 0.5) * (y + 0.5) : 0.0)) /
            rad;
        if (d > 1.0) {
          if (near && y < 0 && d < 1.0 + 1.4 / rad && (x + y).isEven) {
            p.px(x, y, f);
          }
          continue;
        }
        if (y >= 0) {
          final e = math.sqrt(
            ((sx + 0.5) / rad) * ((sx + 0.5) / rad) +
                ((y + 0.5) / ry) * ((y + 0.5) / ry),
          );
          if (e > 1.0 || e < 0.92 || (y > 0) != near) continue;
          p.px(x, y, e > 0.97 ? c[6] : c[4]);
          continue;
        }
        if (!near) continue;
        final rim = math.pow(d, 6).toDouble();
        final line = ((((y - roll) % 4.0) + 4.0) % 4.0) < 1.0;
        final bandOn = ((((y - roll * 0.5) % 22.0) + 22.0) % 22.0) < 4.0;
        if (d > 0.965) {
          p.px(x, y, shift != 0 ? kWhite : (-y > rad * 0.55 && sx < 0 ? kWhite : c[6]));
        } else if (d > 0.93) {
          p.px(x, y, c[4]);
        } else if (shift != 0) {
          p.px(x, y, sx.abs() > rad * 0.8 ? f : ((x & 1) != 0 ? c[6] : c[5]));
        } else {
          p.blend(
            x + 0.5,
            y + 0.5,
            line && bandOn
                ? c[6]
                : (line ? c[5] : (bandOn ? c[4] : c[3])),
            0.06 +
                0.42 * rim +
                (line ? 0.14 + 0.24 * rim : 0.0) +
                (bandOn ? 0.16 : 0.0),
          );
        }
      }
      if (shift != 0 && near) {
        p.glowLine(-rad, y, rad, y, 4, c[5], 0.3);
      }
    }
    if (near) {
      for (var a = 0.15; a < math.pi - 0.1; a += 0.35) {
        p.glow(math.cos(a) * rad, -math.sin(a) * rad, 8, c[4], 0.12);
      }
      for (var i = 0; i < 3; i++) {
        final k = rand(seed, slot, i, 7);
        if (k > 0.5) continue;
        final a = rand(seed, slot, i, 8) * math.pi;
        final d = rand(seed, slot, i, 9) * rad * 0.85;
        final bx = (math.cos(a) * d + 0.5).floor();
        final by = (-math.sin(a) * d + 0.5).floor();
        p.rect(
          bx,
          by,
          2 + (k * 8.0).floor(),
          1 + (k * 4.0).floor(),
          k < 0.2 ? kWhite : c[5],
        );
      }
    }
  }

  @override
  void update(double dt, Map<String, Object?> options) {
    t += dt;
    if (t < _pop - 0.05 && r.chance(0.6)) {
      final a = r.range(-math.pi, 0.0);
      final d = r.range(16.0, 40.0);
      final dur = r.range(0.14, 0.22);
      final v = (d * 3.0) / (math.exp(3.0 * dur) - 1.0);
      ps.spawn(
        P.streak,
        math.cos(a) * d,
        -5.0 + math.sin(a) * d * 0.7,
        -math.cos(a) * v,
        -math.sin(a) * v * 0.7,
        dur,
        r.chance(0.5) ? c[6] : c[5],
      );
    }
    final sa = t - _pop;
    final sf = (t * 30.0).floor();
    if (sa >= 0.0 && sa < 0.26 && sf != starAt) {
      starAt = sf;
      final len =
          sa < 0.05 ? Ease.outBack(sa / 0.05, 2.0) : 1.0 - (sa - 0.05) / 0.26;
      star = [];
      for (var i = 0; i < 7; i++) {
        final a = -math.pi +
            (i / 6.0) * math.pi +
            rand(seed, i, 3) * 0.3 -
            0.15 +
            r.range(-0.1, 0.1);
        final l = (20.0 + 16.0 * rand(seed, i, 5)) * math.max(0.15, len);
        star.add(bolt(
          r,
          0.0,
          -7.0,
          math.cos(a) * l,
          math.min(-1.0, -7.0 + math.sin(a) * l),
          jag: 0.28,
          depth: 4,
        ));
      }
    }
    if (sa >= 0.26) star = [];
    if (t >= _pop && !popped) {
      popped = true;
      for (var i = 0; i < 16; i++) {
        final a = r.range(-math.pi, 0.0);
        final sp = r.range(50.0, 150.0);
        ps.spawn(
          P.mote,
          0.0,
          -7.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.3, 0.6),
          r.pick([kWhite, c[6], c[5]]),
          0.8,
        );
      }
      lights.add(0.0, -20.0, 72.0, c[4], 0.9, 0.5);
      lights.add(0.0, -7.0, 30.0, kWhite, 0.9, 0.12);
      for (var i = 0; i < 60; i++) {
        final a = r.range(-math.pi, 0.0);
        final sp = r.range(90.0, 220.0);
        ps.spawn(
          P.spark,
          0.0,
          -7.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.2, 0.6),
        );
      }
      for (var i = 0; i < 6; i++) {
        ps.spawn(
          P.smoke,
          r.range(-3.0, 3.0),
          -4.0,
          r.range(-12.0, 12.0),
          -r.range(10.0, 24.0),
          r.range(1.0, 1.6),
          hex('#3c3a52'),
          r.range(2.5, 4.0),
          r.range(0.05, 0.3),
        );
      }
    }
    if (popped && !broke && t >= nextArc) {
      nextArc = t +
          (t > _strobe ? r.range(0.02, 0.05) : r.range(0.05, 0.11));
      final rad = _radius();
      final a0 = r.range(0.1, math.pi - 0.1);
      final a1 = a0 + r.sign() * r.range(0.25, 0.6);
      final rr = rad * r.range(0.92, 1.0);
      arcs.add(_EmpArc(
        t: t,
        pts: bolt(
          r,
          math.cos(a0) * rr,
          -math.sin(a0) * rr,
          math.cos(a1) * rr,
          -math.max(0.05, math.sin(a1)) * rr,
          jag: 0.3,
          depth: 4,
        ),
        life: r.range(0.05, 0.1),
      ));
      if (r.chance(0.35)) {
        ps.spawn(
          P.spark,
          math.cos(a1) * rr,
          -math.max(0.05, math.sin(a1)) * rr,
          r.range(-80.0, 80.0),
          r.range(-90.0, 10.0),
          r.range(0.15, 0.3),
        );
      }
    }
    if (t >= _break && !broke) {
      broke = true;
      final rad = _radius();
      lights.add(0.0, -rad * 0.4, rad * 1.3, c[5], 0.8, 0.3);
      for (var i = 0; i < 70; i++) {
        final a = r.range(0.05, math.pi - 0.05);
        final d = rad * r.range(0.6, 1.0);
        dead.add(_DeadPx(
          x: math.cos(a) * d,
          y: -math.sin(a) * d,
          vx: math.cos(a) * r.range(5.0, 25.0),
          vy: -r.range(0.0, 20.0),
          life: r.range(0.4, 1.0),
          max: 1.0,
          s: r.chance(0.3) ? 2 : 1,
          c: r.pick([kWhite, c[6], c[5], c[4]]),
          ph: r.range(0.0, 9.0),
        ));
      }
      for (var i = 0; i < 6; i++) {
        final a0 = r.range(0.1, math.pi - 0.1);
        final a1 = a0 + r.range(-0.5, 0.5);
        arcs.add(_EmpArc(
          t: t,
          pts: bolt(
            r,
            math.cos(a0) * rad,
            -math.sin(a0) * rad,
            math.cos(a1) * rad * 0.6,
            -math.max(0.05, math.sin(a1)) * rad * 0.6,
            jag: 0.35,
            depth: 4,
          ),
          life: 0.1,
        ));
      }
      for (var i = 0; i < 8; i++) {
        ps.spawn(
          P.smoke,
          r.range(-3.0, 3.0),
          -4.0,
          r.range(-6.0, 6.0),
          -r.range(8.0, 18.0),
          r.range(0.8, 1.2),
          hex('#2f2c3c'),
          r.range(2.0, 3.4),
          r.range(0.0, 0.35),
        );
      }
    }
    if (broke && t < _duration - 0.8 && r.chance(0.05)) {
      ps.spawn(
        P.spark,
        r.range(-3.0, 3.0),
        -3.0,
        r.range(-60.0, 60.0),
        -r.range(40.0, 120.0),
        r.range(0.15, 0.3),
      );
    }
    for (var i = arcs.length - 1; i >= 0; i--) {
      if (t - arcs[i].t > arcs[i].life) arcs.removeAt(i);
    }
    for (var i = dead.length - 1; i >= 0; i--) {
      final d = dead[i];
      if ((d.life -= dt) <= 0.0) dead.removeAt(i);
      d.vy += 60.0 * dt;
      d.x += d.vx * dt;
      d.y = math.min(-1.0, d.y + d.vy * dt);
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    _bubble(p, false);
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    _charge(p);
    _bubble(p, true);
    final a = t - _pop;
    if (a >= 0.0 && a < 0.06) {
      p.circle(0, -7, 12.0 * (1.0 - a / 0.06) + 3.0, c[6]);
      p.circle(0, -7, 9.0 * (1.0 - a / 0.06) + 1.0, kWhite);
    }
    if (a >= 0.0 && a < 0.4) {
      final k = a / 0.4;
      final rr = 6.0 + (rm + 14.0) * Ease.outCubic(k);
      band(
        p,
        0.0,
        0.0,
        rr,
        0.16,
        math.max(1.0, 3.0 * (1.0 - k)),
        1.2 - k,
        [c[3], c[5], c[6], kWhite],
        hot: k < 0.3,
      );
    }
    if (a >= 0.0 && a < 0.16) {
      sparkle(p, 0, -7, 10.0 * (1.0 - a / 0.16), c[6], c[5], 0.6);
    }
    for (final b in star) {
      strokeArc(p, b, [c[3], c[6], c[5]], 1.0 - (t - _pop) / 0.3, 1.3);
    }
    for (final arc in arcs) {
      strokeArc(
        p,
        arc.pts,
        [c[2], c[5], c[4]],
        1.0 - (t - arc.t) / (arc.life + 0.03),
        0.8,
      );
    }
    for (final d in dead) {
      if (math.sin(t * 40.0 + d.ph) < -0.3 && d.life < 0.6) continue;
      p.rect(d.x, d.y, d.s, d.s, d.life > 0.5 ? d.c : c[3]);
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final PixelEffect empBlastEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'scifi/emp-blast',
    name: 'EMP blast',
    desc:
        'A disc charge ticks, pops white, and a bubble of rolling scanlines swells out with arcs crawling its skin; it strobes, tears and shorts out into falling dead pixels.',
    category: 'scifi',
    tags: [
      'scifi',
      'emp',
      'pulse',
      'shockwave',
      'electric',
      'grenade',
      'glitch',
      'one-shot',
    ],
    size: (152, 116),
    origin: (76, 84),
    duration: _duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#0d0820',
        '#1c1658',
        '#2d2aa0',
        '#3f55e8',
        '#5a8eff',
        '#9cc4ff',
        '#dceaff',
        '#ffffff',
      ],
      'fringe': '#ff5ad8',
      'radius': 56,
      'seed': 33,
    },
  ),
  onCreate: _EmpBlastSim.create,
);
