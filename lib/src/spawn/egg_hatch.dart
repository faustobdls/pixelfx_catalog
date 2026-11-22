import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const List<(double, double)> _wobbles = [(0.3, 0.11), (0.85, 0.19), (1.4, 0.28)];
const double _pop = 1.98;
const int _ew = 16;
const int _eh = 20;
const int _zy = 11;
const List<double> _light = [-0.72, 0.5, 0.48];
const double _crumble = 3.1 - 0.55;

class _EggCell {
  const _EggCell({
    required this.x,
    required this.y,
    required this.u,
    required this.v,
    required this.half,
  });

  final int x;
  final int y;
  final double u;
  final double v;
  final double half;
}

final List<_EggCell> _eggCells = () {
  final list = <_EggCell>[];
  for (var y = 0; y < _eh; y++) {
    for (var x = -_ew ~/ 2; x < _ew ~/ 2; x++) {
      final v = (y + 0.5) / _eh;
      final u = (x + 0.5) / (_ew / 2);
      final k = 2 * v - 1;
      final half = math.sqrt(math.max(0.0, 1 - k * k)) * (1.08 - 0.22 * v);
      if (u.abs() <= half) {
        list.add(_EggCell(x: x, y: y, u: u, v: v, half: half));
      }
    }
  }
  return list;
}();

final PixelEffect eggHatchEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'spawn/egg-hatch',
    name: 'Egg hatch',
    desc:
        'A speckled egg rocks three times, each rock cracking it further with warm light leaking out, then pops: light pours out of the opening and lit shell halves tumble away.',
    category: 'spawn',
    tags: [
      'spawn',
      'egg',
      'hatch',
      'birth',
      'crack',
      'shell',
      'light',
      'ground',
      'one-shot',
    ],
    size: (120, 96),
    origin: (60, 84),
    duration: 3.1,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#1e1826',
        '#4a3e52',
        '#857684',
        '#c4b4ac',
        '#ece0d2',
        '#fffaf0',
      ],
      'glow': ['#ff8a2a', '#ffd25a', '#fff3c0'],
      'speckle': '#9a6a52',
      'seed': 31,
    },
  ),
  onCreate: (o) => _EggHatchSim(o),
);

class _ShadedEggCell {
  _ShadedEggCell({
    required this.x,
    required this.y,
    required this.c,
    required this.lit,
  });

  final int x;
  final int y;
  final int c;
  final double lit;
}

class _Piece {
  _Piece({
    required this.id,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.va,
    required this.r,
    required this.map,
    required this.life,
    required this.born,
  });

  final int id;
  double x;
  double y;
  double vx;
  double vy;
  double a = 0;
  double va;
  final double r;
  final Map<(int, int), (int, bool)> map;
  double life;
  bool rest = false;
  final double born;
}

class _EggHatchSim extends BaseEffectSim {
  _EggHatchSim(Map<String, Object?> o) {
    cRamp = fit(o.palette, 6);
    gRamp = fit(o.rampOpt('glow'), 3);
    spk = hex(o.strOpt('speckle', '#9a6a52'));
    rng = Rng(o.seed);

    for (final e in _eggCells) {
      final nx = clamp(e.u / math.max(0.05, e.half), -1.0, 1.0);
      final ny = (2 * e.v - 1) * 0.9;
      final nz = math.sqrt(math.max(0.0, 1 - nx * nx - ny * ny));
      final d = nx * _light[0] + ny * _light[1] + nz * _light[2];
      at[(e.x, e.y)] = _ShadedEggCell(x: e.x, y: e.y, c: cRamp[0], lit: d);
    }
    for (final e in _eggCells) {
      final nx = clamp(e.u / math.max(0.05, e.half), -1.0, 1.0);
      final ny = (2 * e.v - 1) * 0.9;
      final nz = math.sqrt(math.max(0.0, 1 - nx * nx - ny * ny));
      final d = nx * _light[0] + ny * _light[1] + nz * _light[2];
      final edge =
          !_has(e.x - 1, e.y) ||
          !_has(e.x + 1, e.y) ||
          !_has(e.x, e.y - 1) ||
          !_has(e.x, e.y + 1);
      var c = d > 0.9
          ? kWhite
          : d > 0.62
              ? cRamp[5]
              : d > 0.32
                  ? cRamp[4]
                  : d > 0.02
                      ? cRamp[3]
                      : d > -0.3
                          ? cRamp[2]
                          : cRamp[1];
      if (edge && nx > 0.25 && ny < 0.55) {
        c = cRamp[3];
      } else if (rand(e.x, e.y, 3) < 0.08 && e.v > 0.12 && !edge) {
        c = d > 0.2 ? spk : mix(spk, cRamp[1], 0.5);
      }
      final cell = _ShadedEggCell(x: e.x, y: e.y, c: c, lit: d);
      at[(e.x, e.y)] = cell;
      shadedList.add(cell);
    }

    void walk(double x, double y, double a, int len, int s) {
      var px = (x + 0.5).floor();
      var py = (y + 0.5).floor();
      for (var i = 0; i < len; i++) {
        final side = (i % 2 != 0 ? 1 : -1) * rng.range(0.6, 1.3);
        a += rng.range(-0.25, 0.25);
        x += math.cos(a) * 1.8 - math.sin(a) * side * 0.6;
        y += math.sin(a) * 1.8 + math.cos(a) * side * 0.6;
        final nx = (x + 0.5).floor();
        final ny = (y + 0.5).floor();
        final n = math.max((nx - px).abs(), (ny - py).abs());
        for (var j = 1; j <= n; j++) {
          final kx = (px + ((nx - px) * j) / n + 0.5).floor();
          final ky = (py + ((ny - py) * j) / n + 0.5).floor();
          final k = (kx, ky);
          if (!at.containsKey(k)) return;
          crack.putIfAbsent(k, () => s);
        }
        px = nx;
        py = ny;
      }
    }

    walk(2, 15, -2.2, 3, 0);
    walk(2, 15, 0.3, 2, 0);
    walk(-2, 13, -0.6, 3, 1);
    walk(-2, 13, 2.7, 3, 1);
    walk(3, 11, 1.9, 2, 1);
    walk(2, 15, 1.5, 2, 1);

    for (var x = -_ew ~/ 2; x < _ew ~/ 2; x++) {
      final y = _zy + ((x + 8) % 3 == 0 ? 1 : ((x + 8) % 3 == 1 ? 0 : -1));
      zig.add(y);
      if (_has(x, y)) crack[(x, y)] = 2;
    }

    near = List.generate(3, (s) {
      final pts = <(int, int)>[];
      crack.forEach((k, cs) {
        if (cs <= s) pts.add(k);
      });
      final m = <(int, int), double>{};
      for (final e in shadedList) {
        var best = 9.0;
        for (final (cx, cy) in pts) {
          final d = hypot((cx - e.x).toDouble(), (cy - e.y).toDouble());
          if (d < best) best = d;
        }
        m[(e.x, e.y)] = best;
      }
      return m;
    });

    ps = Particles(
      rng: rng,
      ground: (_) => 0,
      sparks: [kWhite, gRamp[2], gRamp[1], gRamp[0]],
    );
    lights = Lights();
    bits = Bits(ground: (_) => 0);
  }

  late final List<int> cRamp;
  late final List<int> gRamp;
  late final int spk;
  late final Rng rng;
  final Map<(int, int), _ShadedEggCell> at = {};
  final List<_ShadedEggCell> shadedList = [];
  final Map<(int, int), int> crack = {};
  final List<int> zig = [];
  late final List<Map<(int, int), double>> near;
  late final Particles ps;
  late final Lights lights;
  late final Bits bits;
  final List<_Piece> pieces = [];
  double t = 0;
  bool popped = false;
  bool crumbled = false;
  double cupA = 0;
  double cupV = 0;
  final List<bool> done = [false, false, false];

  bool _has(int x, int y) => at.containsKey((x, y));

  int _zigAt(int x) => zig[clampInt(x + _ew ~/ 2, 0, zig.length - 1)];

  int _stage(double t) => t > _wobbles[2].$1 + 0.05
      ? 3
      : t > _wobbles[1].$1 + 0.05
          ? 2
          : t > _wobbles[0].$1 + 0.05
              ? 1
              : 0;

  double _angle(double t) {
    var a = 0.0;
    for (final (t0, amp) in _wobbles) {
      final u = t - t0;
      if (u > 0 && u < 0.55) {
        a += amp * math.sin(u * 22) * math.exp(-u * 5);
      }
    }
    if (t > _pop - 0.14 && t < _pop) {
      a += 0.05 * math.sin(t * 120);
    }
    return a;
  }

  double _inner(double t) => t < _pop
      ? _stage(t) / 3 +
          0.25 * math.max(0.0, math.sin(t * 9)) * (_stage(t) / 3)
      : 1.6 * math.exp(-(t - _pop) * 2.6);

  void _breakUp(
    bool Function(int x, int y) keep,
    int n,
    (double, double) Function(double cx, double cy) vel,
    double Function() life,
  ) {
    final seeds = List.generate(
      n,
      (_) => (rng.range(-_ew / 2 + 1, _ew / 2 - 1), rng.range(0, _eh.toDouble())),
    );
    final cells = <int, List<_ShadedEggCell>>{};
    for (final e in shadedList) {
      if (!keep(e.x, e.y)) continue;
      var best = 0;
      var bd = 1e9;
      for (var i = 0; i < seeds.length; i++) {
        final (sx, sy) = seeds[i];
        final d = hypot(e.x - sx, e.y - sy);
        if (d < bd) {
          bd = d;
          best = i;
        }
      }
      cells.putIfAbsent(best, () => []).add(e);
    }
    for (final px in cells.values) {
      var cx = 0.0;
      var cy = 0.0;
      for (final e in px) {
        cx += e.x + 0.5;
        cy += e.y + 0.5;
      }
      cx /= px.length;
      cy /= px.length;
      final map = <(int, int), (int, bool)>{};
      final mine = <(int, int)>{for (final e in px) (e.x, e.y)};
      for (final e in px) {
        var edge = false;
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          if (!mine.contains((e.x + dx, e.y + dy)) && _has(e.x + dx, e.y + dy)) {
            edge = true;
            break;
          }
        }
        final c = e.c == cRamp[1] || e.c == cRamp[2] ? cRamp[3] : e.c;
        map[((e.x + 0.5 - cx + 0.5).floor(), (-(e.y + 0.5 - cy) + 0.5).floor())] =
            (c, edge);
      }
      var r = 0.0;
      for (final e in px) {
        final d = hypot(e.x + 0.5 - cx, e.y + 0.5 - cy);
        if (d > r) r = d;
      }
      r += 1;
      final (vx, vy) = vel(cx, cy);
      final l = life();
      pieces.add(
        _Piece(
          id: pieces.length + 1,
          x: cx,
          y: -cy,
          vx: vx,
          vy: vy,
          va: rng.range(-10, 10),
          r: r,
          map: map,
          life: l,
          born: t,
        ),
      );
    }
  }

  void _doPop() {
    popped = true;
    _breakUp(
      (x, y) => y >= _zigAt(x),
      6,
      (cx, _) => (cx * rng.range(8, 13) + rng.range(-14, 14), -rng.range(140, 210)),
      () => rng.range(0.95, 1.15),
    );
    for (var i = 0; i < 14; i++) {
      final a = -math.pi / 2 + rng.range(-1.2, 1.2);
      final sp = rng.range(70, 170);
      bits.add(
        DebrisBit(
          kind: B.shard,
          x: rng.range(-5, 5),
          y: -_zy - rng.range(0, 4),
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp,
          g: 0.9,
          drag: 0.6,
          bounce: 0.3,
          life: rng.range(0.55, 0.85),
          a: rng.range(0, tau),
          va: rng.range(-20, 20),
          s: rng.range(1.2, 2.4),
          c: rng.pick([cRamp[5], cRamp[5], cRamp[4], gRamp[2]]),
        ),
      );
    }
    for (var i = 0; i < 12; i++) {
      final a = -math.pi / 2 + rng.range(-1.1, 1.1);
      final sp = rng.range(50, 110);
      ps.spawn(
        P.star,
        rng.range(-3, 3),
        -_zy - 2,
        math.cos(a) * sp,
        math.sin(a) * sp,
        rng.range(0.4, 0.9),
        rng.pick([kWhite, gRamp[2], gRamp[1]]),
        rng.range(1, 2.2),
      );
    }
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + rng.range(-1, 1);
      final sp = rng.range(100, 200);
      ps.spawn(
        P.spark,
        rng.range(-3, 3),
        -_zy - 1,
        math.cos(a) * sp,
        math.sin(a) * sp,
        rng.range(0.2, 0.45),
      );
    }
    for (var i = 0; i < 4; i++) {
      final s = rng.sign();
      ps.spawn(
        P.dust,
        s * rng.range(5, 8),
        -1,
        s * rng.range(25, 50),
        -rng.range(2, 6),
        rng.range(0.15, 0.25),
        cRamp[5],
        rng.range(1, 1.8),
      );
    }
    lights.add(0, -_zy - 10, 40, gRamp[1], 0.9, 0.55);
    lights.add(0, -_zy - 2, 18, kWhite, 0.9, 0.12);
    cupV = rng.sign() * 3.0;
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    for (var i = 0; i < _wobbles.length; i++) {
      final t0 = _wobbles[i].$1;
      if (!done[i] && t >= t0 + 0.05) {
        done[i] = true;
        lights.add(
          i == 1 ? -3 : 2,
          (-14 + i).toDouble(),
          (8 + i * 2).toDouble(),
          gRamp[1],
          0.25 + i * 0.08,
          0.18,
        );
        for (var j = 0; j < 2 + i * 2; j++) {
          ps.spawn(
            P.star,
            rng.range(-5, 5),
            -rng.range(8, 17),
            rng.range(-20, 20),
            -rng.range(10, 30),
            rng.range(0.25, 0.5),
            rng.pick([kWhite, gRamp[2]]),
            rng.range(0.6, 1.4),
          );
        }
        for (var j = 0; j < i + 1; j++) {
          bits.add(
            DebrisBit(
              kind: B.shard,
              x: rng.range(-4, 4),
              y: -rng.range(10, 16),
              vx: rng.range(-50, 50),
              vy: -rng.range(40, 90),
              g: 0.9,
              drag: 0.5,
              bounce: 0.3,
              life: rng.range(0.5, 0.8),
              a: rng.range(0, tau),
              va: rng.range(-20, 20),
              s: rng.range(1, 1.6),
              c: cRamp[4],
            ),
          );
        }
        ps.spawn(
          P.dust,
          rng.sign() * rng.range(5, 7),
          -0.5,
          rng.sign() * rng.range(8, 18),
          -rng.range(1, 3),
          rng.range(0.15, 0.25),
          cRamp[5],
          rng.range(0.8, 1.4),
        );
      }
    }
    if (!popped && t >= _pop) _doPop();
    if (popped && t < _pop + 0.6 && rng.chance(0.35)) {
      ps.spawn(
        P.mote,
        rng.range(-4, 4),
        -_zy - 1,
        rng.range(-8, 8),
        -rng.range(40, 80),
        math.min(rng.range(0.4, 0.8), 3.1 - 0.1 - t),
        rng.pick([gRamp[2], gRamp[1], kWhite]),
        0.7,
      );
    }
    if (popped && !crumbled && t >= _crumble) {
      crumbled = true;
      _breakUp(
        (x, y) => y < _zigAt(x),
        4,
        (cx, _) => (cx * rng.range(4, 8), -rng.range(40, 80)),
        () => rng.range(0.38, 0.48),
      );
      for (var i = 0; i < 3; i++) {
        ps.spawn(
          P.dust,
          rng.range(-6, 6),
          -1,
          rng.sign() * rng.range(10, 25),
          -rng.range(2, 6),
          rng.range(0.15, 0.25),
          cRamp[5],
          rng.range(1, 1.6),
        );
      }
    }
    if (popped) {
      cupV += (-cupA * 90 - cupV * 4) * dt;
      cupA += cupV * dt;
    }
    for (var i = pieces.length - 1; i >= 0; i--) {
      final q = pieces[i];
      q.life -= dt;
      if (q.life <= 0) {
        pieces.removeAt(i);
        continue;
      }
      if (q.rest) continue;
      q.vy += 900 * dt;
      q.vx -= q.vx * 0.6 * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      q.a += q.va * dt;
      final g = -q.r * 0.45;
      if (q.y > g && q.vy > 0) {
        q.y = g;
        if (q.vy > 80) {
          q.vy *= -0.35;
          q.vx *= 0.6;
          q.va *= 0.5;
        } else {
          q.rest = true;
          q.vx = 0;
          q.vy = 0;
        }
      }
    }
    bits.update(dt);
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    if (!crumbled) {
      final sx = popped ? 0.0 : -_angle(t) * 8;
      final k = popped ? 1 - smooth(_pop, _crumble, t) * 0.4 : 1.0;
      for (var y = -1; y <= 1; y++) {
        for (var x = -10; x <= 10; x++) {
          final dx = (x + 0.5 - sx) / 9.5;
          final dy = (y + 0.5) / 1.8;
          final d = dx * dx + dy * dy;
          if (d < 1) p.blend(x, y, cRamp[0], 0.5 * k * (1 - d));
        }
      }
    }
    final g = _inner(t);
    if (g > 0.05) p.glow(0, -3, 22, gRamp[0], 0.18 * math.min(1.2, g));
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final st = _stage(t);
    final a = popped ? cupA * 0.03 : _angle(t);
    final ca = math.cos(a);
    final sa = math.sin(a);
    final g = _inner(t);

    if (!crumbled) {
      p.shade(-12, -_eh - 4, 12, 1, (x, y, out) {
        final ux = (x * ca + y * sa).floor();
        final uy = (-(-x * sa + y * ca)).floor();
        final e = at[(ux, uy)];
        final inside = e != null && !(popped && uy >= _zigAt(ux));
        if (!inside) {
          var n = false;
          for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            final f = at[(ux + dx, uy + dy)];
            if (f != null && !(popped && uy + dy >= _zigAt(ux + dx))) {
              n = true;
              break;
            }
          }
          if (n && !(popped && uy >= _zigAt(ux) && uy <= _zigAt(ux) + 1)) {
            out.c = cRamp[0];
          }
          return null;
        }
        final cs = crack[(ux, uy)];
        if (popped) {
          out.c = uy >= _zigAt(ux) - 1
              ? (g > 0.9
                  ? kWhite
                  : g > 0.4
                      ? gRamp[2]
                      : g > 0.12
                          ? gRamp[1]
                          : cRamp[4])
              : e.c;
          if (uy >= _zigAt(ux) - 1) {
            out.k = 0.25 * g;
            out.l = gRamp[1];
          }
          return null;
        }
        if (cs != null && cs < st) {
          final fresh = t - _wobbles[cs].$1 < 0.17;
          out.c = fresh
              ? kWhite
              : rand(ux, uy, (t * 20).toInt()) < 0.25 + 0.1 * st
                  ? gRamp[1]
                  : gRamp[0];
          out.k = 0.14 + 0.06 * st;
          out.l = gRamp[1];
          return null;
        }
        final cDown = crack[(ux, uy + 1)];
        final cRight = crack[(ux + 1, uy)];
        if ((cDown != null && cDown < st) || (cRight != null && cRight < st)) {
          out.c = e.lit > 0.3 ? cRamp[2] : cRamp[1];
          return null;
        }
        final dn = st > 0 ? (near[st - 1][(ux, uy)] ?? 9.0) : 9.0;
        final k = math.min(1.0, g * 1.5);
        final base = st > 0 && e.c != spk ? mix(e.c, gRamp[0], 0.05 * st * k) : e.c;
        out.c = dn < 1.6
            ? mix(base, gRamp[1], (st >= 2 ? 0.32 : 0.2) * k)
            : dn < 2.7 && st >= 2
                ? mix(base, gRamp[1], 0.14 * k)
                : base;
        return null;
      });
    }

    final q = t - _pop;
    if (popped && q < 1.2 && !crumbled && g > 0.22) {
      const oy = -_zy + 0.5;
      const rx = 7;
      for (var y = -2; y <= 2; y++) {
        for (var x = -rx; x <= rx; x++) {
          final d = hypot((x + 0.5) / rx, (y + 0.5) / 2.2);
          if (d > 1) continue;
          if (g < 0.6 && d > 0.75) continue;
          p.px(
            x,
            oy + y,
            g > 1
                ? (d < 0.7 ? kWhite : gRamp[2])
                : g > 0.6
                    ? (d < 0.5 ? gRamp[2] : gRamp[1])
                    : (d < 0.45 ? gRamp[1] : gRamp[0]),
          );
        }
      }
      p.glow(0, oy, 16, gRamp[1], 0.6 * g);
      if (q < 0.65) {
        final rk = q / 0.65;
        final lenMax = 36 * Ease.outCubic(clamp(q / 0.1)) * (1 - rk * 0.6);
        for (var i = 0; i < 7; i++) {
          final an = -math.pi / 2 + (i - 3) * 0.24 + 0.05 * math.sin(t * 6 + i);
          final len = lenMax * (i % 2 != 0 ? 0.65 : 1.0);
          final w = i % 2 != 0 ? 1 : 2;
          final x1 = math.cos(an) * len;
          final y1 = oy + math.sin(an) * len;
          for (var j = 0; j < w; j++) {
            p.lineShaded(
              j * 0.8 - 0.4,
              oy - 1,
              x1 + j * 0.8 - 0.4,
              y1,
              color: (double u) =>
                  u < 0.3 ? kWhite : (u < 0.65 ? gRamp[2] : gRamp[1]),
              alpha: (double u) => (1 - u * u) * (1.1 - rk),
            );
          }
          p.glowLine(0, oy, x1, y1, 5, gRamp[1], 0.35 * (1 - rk));
        }
      }
      if (q < 0.1) p.glow(0, oy - 4, 30, kWhite, 0.6 * (1 - q / 0.1));
      p.glowLine(0, oy, 0, oy - 26, 8, gRamp[1], 0.25 * g);
    }

    if (!popped && g > 0) p.glow(0, -_eh * 0.55, 7 + 2.0 * st, gRamp[1], 0.05 * g);

    for (final s in pieces) {
      final c2 = math.cos(s.a);
      final s2 = math.sin(s.a);
      final f = math.min(1.0, s.life / 0.4);
      final r = s.r.ceil();
      final hot = t - s.born < 0.35;
      for (var py = -r; py <= r; py++) {
        for (var px = -r; px <= r; px++) {
          final ux = (px * c2 + py * s2 + 0.5).floor();
          final uy = (-px * s2 + py * c2 + 0.5).floor();
          final m = s.map[(ux, uy)];
          if (m != null && rand(ux, uy, s.id) < f) {
            p.px(
              s.x.floor() + px,
              s.y.floor() + py,
              m.$2 ? (hot ? gRamp[2] : cRamp[4]) : m.$1,
            );
          }
        }
      }
      if (hot) p.glow(s.x, s.y, 6, gRamp[1], 0.3);
    }

    bits.draw(p);
    if (popped && q < 0.9) {
      sparkle(
        p,
        -3.0,
        (-_zy - 6).toDouble(),
        (4 * (1 - q / 0.9) + 0.5).floorToDouble(),
        kWhite,
        gRamp[1],
        0.4,
      );
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}
