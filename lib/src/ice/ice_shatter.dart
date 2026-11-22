import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'ice_lib.dart';

const double _duration = 2.8;
const double _hit = 0.26;
const double _crack2 = 0.4;
const double _shiver = 0.54;
const double _flash = 0.62;
const double _burst = 0.68;

const List<(double, double)> _front = [
  (-16, 0),
  (-16, -28),
  (12, -28),
  (12, 0),
];
const List<(double, double)> _top = [
  (-16, -28),
  (-8, -34),
  (20, -34),
  (12, -28),
];
const List<(double, double)> _side = [
  (12, 0),
  (12, -28),
  (20, -34),
  (20, -6),
];
const List<(double, double)> _sil = [
  (-16, 0),
  (-16, -28),
  (-8, -34),
  (20, -34),
  (20, -6),
  (12, 0),
];
const (double, double) _hitAt = (-16.0, -15.0);
const List<(double, double)> _plane = [
  (-16, -21),
  (-5, -28),
  (3, -13),
  (-16, -9),
];
const List<(double, double)> _shade = [(5, -28), (12, -28), (12, -10)];

class _Scuff {
  final int x;
  double t = 0.0;

  _Scuff(this.x);
}

class _IceShatterSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  late final Particles ps;
  final Bits bits = Bits(ground: (_) => 0.0);
  final Lights lights = Lights();
  final List<_Scuff> scuffs = [];
  late final Panes panes;

  final List<(int, int)> veins = [];
  final List<(int, int, bool)> bubbles = [];
  late final List<List<(double, double, double)>> cracks;
  late final List<List<(double, double, double)>> cracks2;

  double t = 0.0;
  bool struck = false;
  bool burst = false;
  bool wave2 = false;
  bool white = false;

  _IceShatterSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed) {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [c[7], c[6], c[5], c[4]],
      haze: c[5],
    );
    panes = Panes(
      ground: (_) => 0.0,
      onLand: (q, x, y, v) {
        if (v < 100.0) return;
        ps.spawn(P.vapour, x, y - 1, q.vx * 0.3 + r.range(-15, 15),
            -r.range(2, 10), r.range(0.4, 0.7), c[6], r.range(1.6, 2.8));
        _splinter(x, y, q.vx, 2);
        if (r.chance(0.3)) {
          ps.spawn(P.star, x, y - 3, 0, -5, r.range(0.2, 0.4), kWhite,
              r.range(0.8, 1.6));
        }
      },
      onSkid: (_, x, _) {
        if (r.chance(0.5)) scuffs.add(_Scuff((x + r.range(-1, 1) + 0.5).floor()));
      },
      onCrumble: (q) {
        _splinter(q.x, 0, q.vx, 3);
        ps.spawn(P.vapour, q.x, -1, r.range(-10, 14), -r.range(2, 6),
            r.range(0.4, 0.7), c[6], r.range(1.2, 2));
      },
    );

    for (var k = 0; k < 3; k++) {
      var x = r.range(-12, 8);
      var y = r.range(-24, -6);
      var a = r.range(0, tau);
      for (var i = 0; i < 9; i++) {
        a += r.range(-0.6, 0.6);
        x += math.cos(a) * 1.5;
        y += math.sin(a) * 1.2;
        if (x < -14.0 || x > 10.0 || y < -26.0 || y > -2.0) break;
        veins.add((x.floor(), y.floor()));
      }
    }
    for (var k = 0; k < 5; k++) {
      bubbles.add((r.intRange(-12, 8), r.intRange(-23, -4), r.chance(0.4)));
    }
    cracks = fractures(r, _inside, _hitAt.$1 + 1.0, _hitAt.$2, 4,
        len: 8, a0: -0.9, spread: 1.9);
    cracks2 = fractures(r, _inside, _hitAt.$1 + 1.0, _hitAt.$2, 6,
        len: 18, a0: -1.3, spread: 2.7, fork: 0.16);
  }

  static bool _inside(double x, double y) => inPoly(_sil, x, y);

  void _splinter(double x, double y, double vx, int n) {
    for (var i = 0; i < n; i++) {
      bits.add(DebrisBit(
        kind: B.shard,
        x: x + r.range(-2, 2),
        y: y - 1,
        vx: vx * 0.6 + r.range(-35, 45),
        vy: -r.range(30, 100),
        g: 0.8,
        drag: 0.6,
        bounce: 0.35,
        life: r.range(0.4, 0.8),
        a: r.range(0, tau),
        va: r.range(-18, 18),
        s: r.range(1.2, 2.4),
        c: c[r.intRange(4, 7)],
      ));
    }
  }

  int _jolt() {
    if (t >= _hit && t < _hit + 0.05) return 2;
    if (t >= _hit + 0.05 && t < _hit + 0.12) return 1;
    if (t >= _shiver && t < _flash) return (t * 40.0).floor().isOdd ? 1 : 0;
    return 0;
  }

  void _drawBlock(Painter p) {
    if (t >= _burst) return;
    final jx = _jolt().toDouble();
    final wh = t >= _flash;
    final sweep = -40.0 + 70.0 * seg(t, 0.04, 0.3);
    List<(double, double)> sh(List<(double, double)> pts) =>
        [for (final (x, y) in pts) (x + jx, y)];

    p.poly(
      sh(const [
        (-17, 1),
        (-17, -28.5),
        (-8.3, -35.2),
        (21, -35.2),
        (21, -5.6),
        (12.5, 1),
      ]),
      c[0],
    );
    if (wh) {
      p.poly(sh(_sil), kWhite);
      return;
    }
    p.polyShaded(
      sh(_front),
      color: (x, y) {
        final lx = x - jx;
        final d = lx + y * 0.8;
        if ((d - sweep).abs() < 1.3 && y < -6.0) return kWhite;
        if (y < -9.0 && ((d + 21.0).abs() < 1.1 || (d + 16.5).abs() < 0.6)) {
          return c[6];
        }
        if ((((lx + 7.5).abs() < 0.5 && y < -6.0) ||
                ((y + 5.5).abs() < 0.5 && lx > -8.0)) &&
            (lx.floor() + y.floor()).isEven) {
          return c[5];
        }
        if (inPoly(_plane, lx, y)) return y < -25.5 ? c[6] : c[5];
        if (inPoly(_shade, lx, y)) return c[3];
        return y < -25.5
            ? c[5]
            : (y < -8.0 ? c[4] : (y < -2.5 ? c[3] : c[2]));
      },
    );
    p.polyShaded(
      sh(_top),
      color: (x, y) => y > -29.5
          ? c[7]
          : (y < -32.5
              ? c[5]
              : (rand(x.floor(), y.floor(), 3) < 0.08 ? c[7] : c[6])),
    );
    p.polyShaded(
      sh(_side),
      color: (x, y) {
        final lx = x - jx;
        return lx < 13.5
            ? c[3]
            : ((lx - 16.5).abs() < 0.6 && y < -8.0
                ? c[3]
                : (y > (lx - 12.0) * -0.75 - 3.0 ? c[1] : c[2]));
      },
    );
    for (final (x, y) in veins) {
      p.px(x + jx, y, c[5]);
    }
    for (final (x, y, big) in bubbles) {
      p.px(x + jx, y, c[6]);
      if (big) {
        p.px(x + jx + 1, y, c[5]);
        p.px(x + jx, y + 1, c[5]);
      }
    }
    void edge((double, double) a, (double, double) b, int col) =>
        p.line(a.$1 + jx, a.$2, b.$1 + jx, b.$2, col);
    edge((-16, -28), (12, -28), kWhite);
    edge((-16, -28), (-8, -34), c[6]);
    edge((-8, -34), (20, -34), c[5]);
    edge((12, -28), (20, -34), c[7]);
    edge((-16, -1), (-16, -28), c[5]);
    edge((12, -1), (12, -28), c[6]);
    edge((20, -6), (20, -34), c[3]);
    edge((13, -1), (20, -6), c[1]);
    if (t >= _hit) drawFractures(p, cracks, (t - _hit) * 170.0, c, ox: jx);
    if (t >= _crack2) drawFractures(p, cracks2, (t - _crack2) * 200.0, c, ox: jx);
  }

  void _drawFloor(Painter p) {
    final out = 1.0 - smooth(_burst + 0.6, _burst + 1.5, t);
    if (out > 0.0) {
      for (var x = -22; x <= 26; x++) {
        final d = (x - 2).abs() / 24.0;
        final h = rand(x, 41);
        final a = out * clamp((1.1 - d) / 0.25);
        if (a <= 0.0) continue;
        p.dot(x, 0, h < 0.35 ? kWhite : c[6], a);
        if (h < 0.4 && (x < -16 || x > 20)) p.dot(x, -1, c[5], a);
        final depth = 1 + (rand(x, 7) * 3.0 * (1.0 - d) + 0.5).floor();
        for (var j = 1; j <= depth; j++) {
          p.dot(x, j, j < 2 ? c[5] : c[4], a * (1.0 - j / 5.0));
        }
      }
    }
    for (final s in scuffs) {
      final a = 1.0 - s.t / 0.9;
      if (a > 0.0) {
        p.dot(s.x, 0, s.t < 0.15 ? kWhite : c[6], a);
        p.dot(s.x, 1, c[4], a * 0.6);
      }
    }
  }

  void _explode() {
    List<List<(double, double)>> chop(
      List<(double, double)> pts,
      double maxArea,
      int depth,
    ) {
      final cc = centroid(pts);
      return cc.area < maxArea || depth > 4
          ? [pts]
          : splitPoly(
              pts,
              cc.x + r.range(-1, 1),
              cc.y + r.range(-1, 1),
              r.range(0, math.pi),
            ).expand((q) => chop(q, maxArea, depth + 1)).toList();
    }

    for (final (face, tone, maxArea) in const [
      (_front, 0.6, 46.0),
      (_top, 1.0, 40.0),
      (_side, 0.3, 46.0),
    ]) {
      for (final part in chop(face, maxArea, 0)) {
        final m = centroid(part);
        final dx = m.x - _hitAt.$1;
        final dy = m.y - _hitAt.$2;
        final rawD = hypot(dx, dy);
        final d = rawD == 0.0 ? 1.0 : rawD;
        final sp = r.range(50, 150) * (0.7 + 0.3 * (1.0 - d / 40.0));
        panes.add(IcePane(
          pts: [for (final (px, py) in part) (px - m.x, py - m.y)],
          x: m.x,
          y: m.y,
          vx: (dx / d) * sp * 0.9 + r.range(40, 110),
          vy: (dy / d) * sp * 0.4 - r.range(60, 200),
          a: 0,
          va: r.range(-10, 10),
          f: r.range(-0.9, 0.9),
          vf: r.range(-7, 7),
          tone: tone,
          lit: tone,
          g: 0.9,
          drag: 0.5,
          bounce: 0.38,
          solid: true,
          brittle: 3,
          crumble: r.range(0.25, 0.6),
          life: r.range(1.5, 1.9),
        ));
      }
    }
    for (var i = 0; i < 46; i++) {
      final x = r.range(-15, 19);
      final y = -r.range(1, 33);
      final dx = x - _hitAt.$1;
      final dy = y - _hitAt.$2;
      final rawD = hypot(dx, dy);
      final d = rawD == 0.0 ? 1.0 : rawD;
      final sp = r.range(60, 200);
      if (!_inside(x, y)) continue;
      bits.add(DebrisBit(
        kind: r.chance(0.15) ? B.chunk : B.shard,
        x: x,
        y: y,
        vx: (dx / d) * sp * 0.8 + r.range(20, 90),
        vy: (dy / d) * sp * 0.4 - r.range(60, 240),
        g: 0.85,
        drag: 0.6,
        bounce: 0.32,
        life: r.range(0.8, 1.4),
        a: r.range(0, tau),
        va: r.range(-22, 22),
        s: r.range(1.2, 3.4),
        c: c[r.intRange(4, 7)],
        rampColors: [c[1], c[3], c[4], c[6], c[7]],
      ));
    }
    for (var i = 0; i < 9; i++) {
      ps.spawn(P.vapour, r.range(-6, 18), -r.range(1, 6), r.range(10, 130),
          -r.range(2, 12), r.range(0.6, 1.1), c[6], r.range(2.2, 3.8));
    }
    for (var i = 0; i < 5; i++) {
      ps.spawn(P.dust, r.range(-6, 16), -r.range(1, 4), r.range(30, 110),
          -r.range(2, 8), r.range(0.5, 0.9), c[5], r.range(1.6, 2.8));
    }
    for (var i = 0; i < 4; i++) {
      ps.spawn(P.vapour, r.range(-8, 18), -r.range(8, 28), r.range(-10, 50),
          -r.range(8, 24), r.range(0.6, 1), c[6], r.range(2.6, 4));
    }
    for (var i = 0; i < 16; i++) {
      final a = r.range(-math.pi * 0.9, -0.1);
      final sp = r.range(40, 140);
      ps.spawn(
        P.flake,
        r.range(-8, 16),
        -r.range(6, 28),
        math.cos(a) * sp + 20.0,
        math.sin(a) * sp,
        r.range(1, 1.6),
        r.chance(0.6) ? kWhite : c[6],
        r.range(0.5, 1.6),
      );
    }
    for (var i = 0; i < 7; i++) {
      ps.spawn(
        P.star,
        r.range(-14, 40),
        -r.range(4, 40),
        r.range(-8, 16),
        -r.range(4, 16),
        r.range(0.4, 0.8),
        r.chance(0.5) ? kWhite : c[6],
        r.range(1, 2.4),
      );
    }
    lights.add(2, -17, 64, kWhite, 0.85, 0.14);
    lights.add(16, -18, 86, c[4], 0.5, 0.55);
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (!struck && t >= _hit) {
      struck = true;
      lights.add(_hitAt.$1, _hitAt.$2, 24, kWhite, 0.6, 0.08);
      lights.add(_hitAt.$1 + 6, _hitAt.$2, 40, c[5], 0.4, 0.3);
      for (var i = 0; i < 12; i++) {
        final a = math.pi + r.range(-0.9, 0.9);
        final sp = r.range(50, 120);
        ps.spawn(P.spark, _hitAt.$1 - 1, _hitAt.$2, math.cos(a) * sp,
            math.sin(a) * sp - 40.0, r.range(0.15, 0.4));
      }
      for (var i = 0; i < 6; i++) {
        final a = math.pi + r.range(-1, 0.8);
        final sp = r.range(40, 100);
        bits.add(DebrisBit(
          kind: B.shard,
          x: _hitAt.$1 - 1,
          y: _hitAt.$2 + r.range(-2, 2),
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp - 60.0,
          g: 0.85,
          drag: 0.6,
          bounce: 0.3,
          life: r.range(0.5, 0.9),
          a: r.range(0, tau),
          va: r.range(-20, 20),
          s: r.range(1.2, 2.4),
          c: c[r.intRange(5, 7)],
        ));
      }
    }
    if (!wave2 && t >= _crack2) {
      wave2 = true;
      lights.add(0, -16, 36, c[6], 0.35, 0.15);
      for (var i = 0; i < 3; i++) {
        bits.add(DebrisBit(
          kind: B.shard,
          x: r.range(-14, 18),
          y: -r.range(4, 30),
          vx: r.range(-30, 30),
          vy: -r.range(10, 50),
          g: 0.85,
          drag: 0.6,
          bounce: 0.3,
          life: r.range(0.4, 0.7),
          a: r.range(0, tau),
          va: r.range(-20, 20),
          s: r.range(1, 2),
          c: c[r.intRange(5, 7)],
        ));
      }
    }
    if (!white && t >= _flash) {
      white = true;
      lights.add(2, -17, 44, kWhite, 0.7, 0.08);
    }
    if (!burst && t >= _burst) {
      burst = true;
      _explode();
    }
    if (burst && t < _burst + 1.0 && r.chance(0.08) && bits.list.isNotEmpty) {
      final b = r.pick(bits.list);
      ps.spawn(P.star, b.x, b.y - 1.0, 0, -3, r.range(0.2, 0.4),
          r.chance(0.5) ? kWhite : c[6], r.range(0.6, 1.5));
    }
    for (var i = scuffs.length - 1; i >= 0; i--) {
      if ((scuffs[i].t += dt) > 0.9) scuffs.removeAt(i);
    }
    ps.update(dt);
    bits.update(dt);
    panes.update(dt);
    lights.update(dt);
    endBy(t, _duration, ps: ps, bits: bits, panes: panes);
  }

  @override
  void drawBack(Painter p) {
    _drawFloor(p);
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    _drawBlock(p);
    final h = t - _hit;
    if (h >= 0.0 && h < 0.2) {
      sparkle(
        p,
        _hitAt.$1 - 1,
        _hitAt.$2,
        9.0 * Ease.outBack(math.min(1.0, h / 0.04)) * (1.0 - h / 0.2),
        c[6],
        c[4],
        0.7,
      );
      if (h < 0.08) {
        flare(p, _hitAt.$1 - 1, _hitAt.$2, 14.0 * (1.0 - h / 0.08),
            1.0 - h / 0.08, c);
      }
    }
    final k = 1.0 - smooth(_burst, _burst + 0.4, t);
    final crk = smooth(_hit, _flash, t);
    if (k > 0.0) {
      p.glow(2, -17, 34, c[4], (0.16 + 0.22 * crk) * k);
      p.glow(2, -2, 30, c[4], 0.14 * k);
    }
    if (t >= _flash && t < _burst + 0.12) {
      final f = 1.0 - clamp((t - _flash) / 0.18);
      flare(p, 2, -17, 26.0 * f, f, c);
    }
    panes.draw(p, c);
    bits.draw(p);
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect iceShatterEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ice/ice-shatter',
    name: 'Ice shatter',
    desc:
        'A block of ice takes a hit from the left: it jolts, cracks race over its faces, it flashes white and bursts into chunks that tumble, bounce and skid off in a roll of ice dust.',
    category: 'ice',
    tags: ['ice', 'shatter', 'break', 'destroy', 'impact', 'directional', 'one-shot'],
    size: (224, 112),
    origin: (68, 90),
    duration: _duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#151a3d', '#212f6b', '#2c58aa', '#3a8bd8',
        '#62c8f4', '#a6ecff', '#dcfbff', '#ffffff',
      ],
      'seed': 6,
    },
  ),
  onCreate: (o) => _IceShatterSim(o),
);
