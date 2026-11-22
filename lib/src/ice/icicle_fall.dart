import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'ice_lib.dart';

const double _duration = 2.6;
const double _root = -80.0;
const double _len = 36.0;
const double _width = 12.0;
const double _drip = 0.16;
const double _tremble = 0.3;
const double _snap = 0.6;
const double _free = _snap + 0.04;
final double _fallT = math.sqrt((2.0 * (-_root - _len)) / kGravity);
final double _impact = _free + _fallT;

void _icicle(
  Painter p,
  List<int> c,
  double x,
  double top,
  double len,
  double w, {
  double tilt = 0.0,
  double cut = 0.0,
  bool white = false,
  double glint = -1.0,
}) {
  double hw(double u) =>
      (w / 2.0) *
          math.pow(1.0 - u, 0.75) *
          (1.0 + 0.14 * math.sin(u * 13.0 + 0.5)) *
          (u < 0.08 ? 1.15 : 1.0) +
      0.3;
  p.shade(
    x - w / 2.0 - 4.0,
    top - 1.0,
    x + w / 2.0 + 4.0 + tilt.abs() * len,
    top + len + 1.0,
    (px, py, o) {
      final u = (py - top) / len;
      final cx = x + tilt * len * u + 0.7 * math.sin(u * 6.0 + 1.0);
      final s = px - cx;
      if (u < cut || u > 1.0) return null;
      final h = hw(u);
      if (s.abs() > h + 1.0) return null;
      if (s.abs() > h) {
        o.c = c[1];
        return null;
      }
      if (white) return o.c = kWhite;
      final q = s / h;
      final ring = math.sin(u * 13.0 + 0.5) > 0.7;
      var col = u > 0.88
          ? kWhite
          : (q < -0.72
              ? c[6]
              : (q < -0.2
                  ? (ring ? c[7] : c[5])
                  : (q < 0.18
                      ? (u < 0.72 ? c[7] : c[6])
                      : (q > 0.8
                          ? c[2]
                          : ((q - 0.45).abs() < 0.1 && u > 0.15 && u < 0.6
                              ? c[5]
                              : (q < 0.6 ? c[4] : c[3]))))));
      if (glint >= 0.0 && q < 0.25 && (u - glint).abs() < 0.06) col = kWhite;
      o.c = col;
      return null;
    },
  );
}

class _RimeCell {
  final int x;
  final int h;
  final int stub;

  const _RimeCell(this.x, this.h, this.stub);
}

class _IcicleFallSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  late final Particles ps;
  final Bits bits = Bits(ground: (_) => 0.0);
  final Lights lights = Lights();
  late final Panes panes;
  final List<_RimeCell> rime = [];

  double t = 0.0;
  bool snapped = false;
  bool landed = false;
  bool dripped = false;

  _IcicleFallSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed) {
    final seed = o.seed;
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
        ps.spawn(P.vapour, x, y - 1, r.range(-15, 15), -r.range(2, 8),
            r.range(0.4, 0.6), c[6], r.range(1.4, 2.2));
        _splinter(x, y, q.vx, 2);
      },
      onCrumble: (q) => _splinter(q.x, 0, q.vx, 3),
    );
    for (var x = -18; x <= 18; x++) {
      final h = rand(x, seed, 2);
      final d = x.abs() / 18.0;
      rime.add(_RimeCell(
        x,
        1 + ((0.6 + h * 1.8) * (1.0 - d * 0.7) + 0.5).floor(),
        h < 0.3 && x.abs() > 7
            ? 2 + (rand(x, 5) * 5.0 * (1.0 - d * 0.5) + 0.5).floor()
            : 0,
      ));
    }
  }

  void _splinter(double x, double y, double vx, int n) {
    for (var i = 0; i < n; i++) {
      bits.add(DebrisBit(
        kind: B.shard,
        x: x + r.range(-2, 2),
        y: y - 1,
        vx: vx * 0.5 + r.range(-45, 45),
        vy: -r.range(30, 100),
        g: 0.8,
        drag: 0.6,
        bounce: 0.35,
        life: r.range(0.4, 0.75),
        a: r.range(0, tau),
        va: r.range(-18, 18),
        s: r.range(1.2, 2.4),
        c: c[r.intRange(4, 7)],
      ));
    }
  }

  double _top() =>
      _root + (t < _free ? 0.0 : 0.5 * kGravity * math.pow(t - _free, 2));

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (!dripped && t >= _drip) {
      dripped = true;
      bits.add(DebrisBit(
        kind: B.drip,
        x: 0.5,
        y: _root + _len + 1.0,
        vy: 20,
        g: 0.9,
        life: 1.2,
        c: c[6],
      ));
    }
    if (t > _tremble && t < _snap && r.chance(0.25)) {
      ps.spawn(
        P.flake,
        r.range(-6, 6),
        _root + r.range(0, 3),
        r.range(-8, 8),
        r.range(5, 20),
        r.range(0.6, 1.1),
        r.chance(0.5) ? kWhite : c[6],
        r.range(0.5, 1.1),
      );
    }
    if (!snapped && t >= _snap) {
      snapped = true;
      lights.add(0, _root + 4.0, 24, kWhite, 0.6, 0.1);
      lights.add(0, _root + 4.0, 32, c[5], 0.4, 0.3);
      for (var i = 0; i < 7; i++) {
        final a = r.range(0, tau);
        final sp = r.range(30, 110);
        bits.add(DebrisBit(
          kind: B.shard,
          x: r.range(-4, 4),
          y: _root + 2.0,
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp - 20.0,
          g: 0.8,
          drag: 0.8,
          bounce: 0.3,
          life: r.range(0.5, 0.9),
          a: r.range(0, tau),
          va: r.range(-20, 20),
          s: r.range(1, 2),
          c: c[r.intRange(5, 7)],
        ));
      }
      for (var i = 0; i < 3; i++) {
        ps.spawn(P.vapour, r.range(-5, 5), _root + 2.0, r.range(-25, 25),
            r.range(-5, 5), r.range(0.4, 0.7), c[6], r.range(1.6, 2.6));
      }
      for (var i = 0; i < 5; i++) {
        ps.spawn(
          P.flake,
          r.range(-6, 6),
          _root + 2.0,
          r.range(-30, 30),
          r.range(-20, 20),
          r.range(0.6, 1.2),
          r.chance(0.5) ? kWhite : c[6],
          r.range(0.5, 1.3),
        );
      }
    }
    if (t > _free && t < _impact && r.chance(0.5)) {
      final tp = _top();
      ps.spawn(
        P.mote,
        r.range(-3, 3),
        tp + r.range(0, _len * 0.6),
        r.range(-10, 10),
        r.range(-40, -10),
        r.range(0.2, 0.35),
        r.chance(0.5) ? c[6] : c[5],
        0.6,
      );
    }
    if (!landed && t >= _impact) {
      landed = true;
      const tp = -_len;
      lights.add(0, -16, 46, kWhite, 0.85, 0.12);
      lights.add(0, -16, 58, c[4], 0.5, 0.5);
      var parts = <List<(double, double)>>[
        const [(-_width / 2.0, tp), (_width / 2.0, tp), (0.5, 0.0)],
      ];
      for (final v in const [0.3, 0.58, 0.8]) {
        parts = [
          for (final poly in parts)
            ...splitPoly(
              poly,
              0,
              tp + _len * v + r.range(-2, 2),
              r.range(-0.4, 0.4),
            ),
        ];
      }
      parts = [
        for (final poly in parts)
          if (centroid(poly).area > 22.0)
            ...splitPoly(
              poly,
              centroid(poly).x,
              centroid(poly).y,
              math.pi / 2.0 + r.range(-0.5, 0.5),
            )
          else
            poly,
      ];
      for (final part in parts) {
        final m = centroid(part);
        final side = m.x < 0.5 ? -1.0 : 1.0;
        final low = clamp(-m.y / _len);
        panes.add(IcePane(
          pts: [for (final (px, py) in part) (px - m.x, py - m.y)],
          x: m.x,
          y: m.y,
          vx: side * r.range(30, 110) + r.range(-15, 15),
          vy: -r.range(70, 200) * (0.4 + low),
          a: 0,
          va: r.range(-12, 12),
          f: r.range(-0.7, 0.7),
          vf: r.range(-8, 8),
          lit: 0.75,
          g: 0.9,
          drag: 0.6,
          bounce: 0.35,
          solid: true,
          ridge: math.pi / 2.0,
          brittle: 2,
          crumble: r.range(0.15, 0.45),
          life: r.range(1, 1.4),
        ));
      }
      for (var i = 0; i < 52; i++) {
        final a = -math.pi / 2.0 + r.range(-1.25, 1.25);
        final sp = r.range(60, 230);
        bits.add(DebrisBit(
          kind: r.chance(0.15) ? B.chunk : B.shard,
          x: r.range(-3, 3),
          y: -r.range(1, 10),
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp,
          g: 0.85,
          drag: 0.6,
          bounce: 0.32,
          life: r.range(0.6, 1.2),
          a: r.range(0, tau),
          va: r.range(-22, 22),
          s: r.range(1.2, 3),
          c: c[r.intRange(4, 7)],
          rampColors: [c[1], c[3], c[4], c[6], c[7]],
        ));
      }
      for (var i = 0; i < 10; i++) {
        final s = r.sign();
        ps.spawn(P.vapour, s * r.range(0, 8), -r.range(1, 6),
            s * r.range(25, 90), -r.range(2, 14), r.range(0.6, 1.1), c[6],
            r.range(2.2, 3.8));
      }
      for (var i = 0; i < 12; i++) {
        ps.spawn(
          P.flake,
          r.range(-6, 6),
          -r.range(2, 16),
          r.range(-70, 70),
          -r.range(30, 110),
          r.range(1, 1.5),
          r.chance(0.6) ? kWhite : c[6],
          r.range(0.5, 1.5),
        );
      }
      for (var i = 0; i < 6; i++) {
        ps.spawn(
          P.star,
          r.range(-24, 24),
          -r.range(4, 34),
          r.range(-10, 10),
          -r.range(4, 14),
          r.range(0.4, 0.8),
          r.chance(0.5) ? kWhite : c[6],
          r.range(1, 2.2),
        );
      }
    }
    if (landed && t < _impact + 0.9 && r.chance(0.08) && bits.list.isNotEmpty) {
      final b = r.pick(bits.list);
      ps.spawn(P.star, b.x, b.y - 1.0, 0, -3, r.range(0.2, 0.4),
          r.chance(0.5) ? kWhite : c[6], r.range(0.6, 1.4));
    }
    ps.update(dt);
    bits.update(dt);
    panes.update(dt);
    lights.update(dt);
    endBy(t, _duration, ps: ps, bits: bits, panes: panes);
  }

  @override
  void drawBack(Painter p) {
    if (t > _tremble && t < _impact + 0.05) {
      final k = t < _free
          ? seg(t, _tremble, _free) * 0.35
          : 0.35 + 0.65 * seg(t, _free, _impact);
      final rx = 3.0 + 7.0 * k;
      for (var x = (-rx).floor(); x <= rx; x++) {
        final f = 1.0 - math.pow(x / rx, 2);
        p.blend(x + 0.5, 0, c[0], 0.7 * k * f);
        if (x.abs() < rx * 0.7) p.blend(x + 0.5, 1, c[0], 0.45 * k * f);
      }
    }
    if (t >= _impact) {
      final g = Ease.outCubic(seg(t, _impact, _impact + 0.25));
      final out = 1.0 - smooth(_impact + 0.8, _impact + 1.5, t);
      for (var x = -26; x <= 26; x++) {
        final d = (x + 0.5).abs() / 26.0;
        final h = rand(x, 23);
        final a = out * clamp((g * 1.15 - d) / 0.15);
        if (a <= 0.0) continue;
        p.dot(x, 0, h < 0.35 || d > g - 0.12 ? kWhite : c[6], a);
        if (h < 0.4) {
          final tuft = ((1.0 + rand(x, 3) * 2.5) * (1.0 - d) + 0.5).floor();
          for (var j = 1; j <= tuft; j++) {
            p.dot(x + x.sign * (j > 1 ? 1 : 0), -j, j > 1 ? kWhite : c[5], a);
          }
        }
        final depth = ((2.0 + rand(x, 7) * 3.0) * (1.0 - d * 0.6) + 0.5).floor();
        for (var j = 1; j <= depth; j++) {
          p.dot(x, j, j < 2 ? c[5] : c[4], a * (1.1 - j / 6.0));
        }
      }
      final k = seg(t, _impact, _impact + 0.35);
      if (k < 1.0) {
        band(
          p,
          0,
          0.5,
          6.0 + 34.0 * Ease.outCubic(k),
          0.18,
          math.max(1.0, 4.0 * (1.0 - k)),
          1.1 - k,
          [c[3], c[4], c[5], c[6]],
          keep: (a) => math.sin(a) < 0.0,
        );
      }
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final ra = 1.0 - smooth(_duration - 0.7, _duration - 0.2, t);
    for (final rc in rime) {
      for (var j = 0; j < rc.h + 1; j++) {
        final col = j == rc.h
            ? kWhite
            : (j == rc.h - 1 ? c[6] : (j == 0 ? c[3] : c[5]));
        p.dot(rc.x, _root - 1.0 - j, col, ra);
      }
      for (var j = 0; j < rc.stub; j++) {
        final col = j == rc.stub - 1 ? kWhite : (j == 0 ? c[5] : c[4]);
        p.dot(rc.x, _root + j, col, ra);
      }
      if (rc.stub > 4) p.dot(rc.x + 1, _root, c[3], ra);
    }
    if (snapped) {
      for (var x = -_width ~/ 2 + 1; x <= _width ~/ 2 - 1; x++) {
        final l = 1 + (rand(x, 77) * 2.5 + 0.5).floor();
        for (var j = 0; j < l; j++) {
          final col = j == l - 1
              ? (t < _snap + 0.15 ? kWhite : c[6])
              : (x < 0 ? c[5] : c[3]);
          p.dot(x, _root + j, col, ra);
        }
      }
    }
    p.glow(0, _root, 18, c[4], 0.3 * ra);
    if (t >= _impact) {
      final k = seg(t, _impact, _impact + 0.35);
      if (k < 1.0) {
        band(
          p,
          0,
          0.5,
          6.0 + 34.0 * Ease.outCubic(k),
          0.18,
          math.max(1.0, 4.0 * (1.0 - k)),
          1.1 - k,
          [c[3], c[4], c[5], c[6]],
          keep: (a) => math.sin(a) >= 0.0,
          hot: k < 0.15,
        );
      }
      if (t < _impact + 0.22) {
        sparkle(
          p,
          0.5,
          -3,
          10.0 *
              Ease.outBack(math.min(1.0, (t - _impact) / 0.05)) *
              (1.0 - (t - _impact) / 0.22),
          c[6],
          c[4],
          0.7,
        );
      }
    }
    if (t < _impact) {
      final tp = _top();
      final jx = t > _tremble && t < _snap
          ? ((t * 36.0).floor().isOdd ? 1 : 0) *
              (seg(t, _tremble, _snap) * 1.4 + 0.4 + 0.5).floor()
          : 0;
      final falling = t >= _free;
      final sp = falling ? kGravity * (t - _free) : 0.0;
      if (falling) {
        for (final (dx, k) in const [(-3.0, 0.7), (0.5, 1.0), (4.0, 0.6)]) {
          final l = math.min(30.0, sp * 0.07) * k;
          if (l > 2.0) {
            p.lineShaded(
              dx,
              tp - l,
              dx,
              tp + 3.0,
              color: (u) => u > 0.75 ? c[6] : (u > 0.4 ? c[4] : c[3]),
            );
          }
        }
      }
      final gl = (t - 0.04) / 0.3;
      _icicle(
        p,
        c,
        jx + 0.5,
        tp,
        _len,
        _width,
        white: t >= _impact - 0.025 || (t >= _snap && t < _snap + 0.03),
        glint: gl >= 0.0 && gl <= 1.0 ? gl : -1.0,
      );
      if (snapped && t < _snap + 0.12) {
        p.line(-_width / 2.0 - 1.0, _root + 1.0, _width / 2.0 + 1.0, _root + 1.0,
            kWhite);
      }
      p.glow(0.5, tp + _len * 0.5, 20, c[4], 0.28);
      if (t < _drip) {
        final s = seg(t, 0, _drip);
        p.dot(0.5, _root + _len + 1.0, c[6], s);
        if (s > 0.6) p.px(0.5, _root + _len + 2.0, kWhite);
      }
    }
    panes.draw(p, c);
    bits.draw(p);
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect icicleFallEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ice/icicle-fall',
    name: 'Icicle fall',
    desc:
        'An icicle drips and trembles, snaps off its frosted root, drops, stabs the floor and bursts into skidding shards, splinters and rolling frost.',
    category: 'ice',
    tags: ['ice', 'icicle', 'fall', 'trap', 'shatter', 'one-shot'],
    size: (152, 120),
    origin: (76, 100),
    duration: _duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#151a3d', '#212f6b', '#2c58aa', '#3a8bd8',
        '#62c8f4', '#a6ecff', '#dcfbff', '#ffffff',
      ],
      'seed': 4,
    },
  ),
  onCreate: (o) => _IcicleFallSim(o),
);
