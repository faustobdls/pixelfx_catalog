import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const int _originY = 128;
const double _flash = 0.42;
const double _break0 = 0.5;
const double _break1 = 1.1;
const double _lift = 1.3;
const double _gone = 1.62;
const double _top = -_originY * 1.0;

const Pose _set = Pose(
  turn: 1.0,
  crouch: 3.0,
  fx: -9.0,
  fy: -15.0,
  bx: 10.0,
  by: -15.0,
  ffx: -3.0,
  fbx: 4.0,
);
final Pose _raised = _set.copyWith(
  crouch: 0.0,
  fx: -11.0,
  fy: -29.0,
  bx: 12.0,
  by: -29.0,
);

final ActSpec _act = ActSpec(
  onBody: true,
  follow: 0.0,
  poses: [
    const PoseKey(-0.3, kReady),
    const PoseKey(0.1, _set),
    PoseKey(0.42, _raised, PoseEase.snap),
    PoseKey(2.6, _raised),
  ],
);

class _WarpBit {
  double x;
  double y;
  final double x0;
  final double y0;
  double vx = 0.0;
  double vy = 0.0;
  final double tr;
  final int c;
  bool free = false;
  final double j;
  final bool rim;

  _WarpBit({
    required this.x,
    required this.y,
    required this.x0,
    required this.y0,
    required this.tr,
    required this.c,
    required this.j,
    required this.rim,
  });
}

class _WarpOutSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final Particles ps;
  final Lights lights = Lights();
  final List<_WarpBit> bits;
  final List<(int, int)> edge;

  double t = 0.0;
  bool flashed = false;
  bool lifted = false;

  factory _WarpOutSim.create(Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final r = Rng(o.seed);
    final a = o.actor;
    final ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [kWhite, c[6], c[5], c[4]],
    );
    bool on(int x, int y) =>
        x >= 0 && y >= 0 && x < a.w && y < a.h && a.mask.data[y * a.w + x] != 0;

    final bits = <_WarpBit>[];
    final edge = <(int, int)>[];
    for (var my = -1; my <= a.h; my++) {
      for (var mx = -1; mx <= a.w; mx++) {
        if (on(mx, my)) {
          final x = a.x + mx;
          final y = a.y + my;
          final tr = _break0 +
              (my / a.h) * (_break1 - _break0 - 0.12) +
              r.range(0.0, 0.12);
          final rim = !on(mx - 1, my) ||
              !on(mx + 1, my) ||
              !on(mx, my - 1) ||
              !on(mx, my + 1);
          final pxCol = a.pixels[my * a.w + mx];
          bits.add(_WarpBit(
            x: x.toDouble(),
            y: y.toDouble(),
            x0: x.toDouble(),
            y0: y.toDouble(),
            tr: tr,
            c: pxCol != 0 ? pxCol : c[3],
            j: r.next(),
            rim: rim,
          ));
        } else if (on(mx - 1, my) ||
            on(mx + 1, my) ||
            on(mx, my - 1) ||
            on(mx, my + 1)) {
          edge.add((a.x + mx, a.y + my));
        }
      }
    }
    return _WarpOutSim._(c: c, r: r, ps: ps, bits: bits, edge: edge);
  }

  _WarpOutSim._({
    required this.c,
    required this.r,
    required this.ps,
    required this.bits,
    required this.edge,
  });

  double _width() => t < _break0
      ? 0.0
      : (t < _lift
          ? 2.0 + 7.0 * Ease.outCubic(clamp((t - _break0) / 0.35))
          : lerp(
              9.0,
              0.6,
              Ease.inCubic(clamp((t - _lift) / (_gone - _lift))),
            ));

  double _foot() => t < _lift
      ? 0.0
      : lerp(0.0, _top, Ease.inQuad(clamp((t - _lift) / (_gone - _lift))));

  @override
  void update(double dt, Map<String, Object?> options) {
    t += dt;
    if (t < _flash - 0.05 && r.chance(0.7)) {
      final ang = r.range(0.0, tau);
      final d = r.range(26.0, 48.0);
      final dur = r.range(0.16, 0.26);
      final v = (d * 3.0) / (math.exp(3.0 * dur) - 1.0);
      const cy = -19.0;
      ps.spawn(
        P.streak,
        math.cos(ang) * d,
        cy + math.sin(ang) * d * 0.8,
        -math.cos(ang) * v,
        -math.sin(ang) * v * 0.8,
        dur,
        r.chance(0.5) ? c[6] : c[5],
      );
    }
    if (t >= _flash && !flashed) {
      flashed = true;
      lights.add(0.0, -20.0, 80.0, c[4], 0.9, 0.5);
      lights.add(0.0, -20.0, 30.0, kWhite, 0.8, 0.12);
      for (var i = 0; i < 14; i++) {
        ps.spawn(
          P.star,
          r.range(-14.0, 14.0),
          -r.range(2.0, 40.0),
          r.range(-20.0, 20.0),
          -r.range(10.0, 40.0),
          r.range(0.3, 0.6),
          r.chance(0.5) ? kWhite : c[6],
          r.range(0.8, 1.8),
        );
      }
    }
    for (var i = bits.length - 1; i >= 0; i--) {
      final b = bits[i];
      if (t < b.tr) continue;
      if (!b.free) {
        b.free = true;
        final ox = b.x + 0.5;
        final oy = b.y + 19.0;
        b.vx = ox * r.range(1.5, 4.0) + r.range(-10.0, 10.0);
        b.vy = oy * r.range(0.5, 1.5) - r.range(10.0, 40.0);
      }
      b.vy -= 560.0 * dt;
      b.vx += (-(b.x + 0.5) * 14.0 - b.vx * 3.0) * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      if (b.y < _top + 2.0) bits.removeAt(i);
    }
    if (t >= _lift && !lifted) {
      lifted = true;
      lights.add(0.0, -2.0, 40.0, c[4], 0.7, 0.3);
      for (var i = 0; i < 22; i++) {
        final ang = -math.pi / 2.0 + r.range(-1.4, 1.4);
        final sp = r.range(80.0, 220.0);
        ps.spawn(
          P.spark,
          r.range(-3.0, 3.0),
          -1.0,
          math.cos(ang) * sp,
          math.sin(ang) * sp,
          r.range(0.2, 0.55),
        );
      }
      for (var i = 0; i < 16; i++) {
        ps.spawn(
          P.star,
          r.range(-10.0, 10.0),
          -r.range(4.0, 70.0),
          r.range(-6.0, 6.0),
          -r.range(10.0, 30.0),
          r.range(0.5, 0.95),
          r.chance(0.4) ? kWhite : c[6],
          r.range(0.6, 1.6),
          r.range(0.0, 0.3),
        );
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final k = clamp(t / _flash);
    final fade = 1.0 - smooth(_lift, _lift + 0.6, t);
    if (fade > 0.0) {
      band(
        p,
        0.0,
        0.0,
        lerp(30.0, 14.0, Ease.outCubic(k)),
        0.16,
        1.5,
        (0.4 + 0.6 * k) * fade,
        [c[3], c[4], c[5], c[6]],
        keep: (g) => math.sin(g) < 0.0,
      );
    }
    final w = _width();
    final f = _foot();
    if (w > 0.3 && t < _gone) {
      for (var y = _top.floor(); y < f; y++) {
        if (y >= f && t >= _lift) break;
        for (var x = (-w).floor() - 1; x <= w.ceil(); x++) {
          final q = (x + 0.5).abs() / w;
          if (q > 1.0 + 1.0 / w) continue;
          if (w < 2.2) {
            p.px(x, y, q < 0.7 ? kWhite : c[6]);
          } else if (q > 1.0) {
            p.dot(x, y, c[4], 0.5);
          } else if (q > 1.0 - 1.2 / w) {
            p.px(x, y, c[6]);
          } else {
            p.blend(x + 0.5, y + 0.5, c[5], 0.12 + 0.25 * q * q);
          }
        }
        if ((y & 7) == 0) {
          p.glow(0, y, math.min(w * 2.5 + 6.0, y - _top + 2.0), c[4], 0.28);
        }
      }
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final k = clamp(t / _flash);
    final fade = 1.0 - smooth(_lift, _lift + 0.6, t);
    if (fade > 0.0) {
      band(
        p,
        0.0,
        0.0,
        lerp(30.0, 14.0, Ease.outCubic(k)),
        0.16,
        1.5,
        (0.4 + 0.6 * k) * fade,
        [c[3], c[5], c[6], kWhite],
        keep: (g) => math.sin(g) >= 0.0,
      );
    }
    if (t < _flash) {
      final fr = (t * 24.0).floor();
      for (final (x, y) in edge) {
        if (rand(x, y, fr) < 0.25 + 0.7 * k) {
          p.px(
            x,
            y,
            k > 0.7 && rand(x, y, fr, 1) < 0.5 ? kWhite : c[5],
          );
        }
      }
      p.glow(0, -20, 26, c[4], 0.4 * k);
    }
    for (final b in bits) {
      if (b.free || t < _flash) continue;
      final a = t - _flash;
      final scan = (((b.y + (t * 40.0).floor()) % 4.0 + 4.0) % 4.0) == 0.0;
      final col = a < 0.07
          ? kWhite
          : (a < 0.16
              ? c[6]
              : (b.rim
                  ? c[6]
                  : mix(b.c, scan ? c[6] : c[5], scan ? 0.6 : 0.45)));
      p.px(b.x, b.y, b.tr - t < 0.06 ? kWhite : col);
    }
    for (final b in bits) {
      if (!b.free) continue;
      final sp = b.vy.abs();
      final l = math.min(8.0, sp * 0.02);
      final u = clamp((b.y - _top) / (b.y0 - _top));
      final head = u > 0.75 ? kWhite : (u > 0.4 ? c[6] : c[5]);
      if (l >= 1.0 && b.j < 0.33) {
        p.lineShaded(
          b.x,
          b.y,
          b.x - b.vx * 0.01,
          b.y + l,
          color: (s) => s < 0.25 ? head : (s < 0.6 ? c[5] : c[3]),
        );
      } else if (b.j < 0.75 || u > 0.6) {
        p.px(b.x, b.y, b.j > 0.9 ? kWhite : head);
      }
    }
    if (t >= _flash && t < _flash + 0.12) {
      sparkle(p, 0, -20, 10.0 * (1.0 - (t - _flash) / 0.12), c[6], c[5], 0.6);
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final PixelEffect warpOutEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'scifi/warp-out',
    name: 'Warp out',
    desc:
        "The hero's outline flickers on, they flash white and break into light from the head down, streaming up a beam that lifts off the floor and pinches shut.",
    category: 'scifi',
    tags: [
      'scifi',
      'teleport',
      'warp',
      'beam',
      'despawn',
      'leave',
      'one-shot',
    ],
    size: (128, 168),
    origin: (64, _originY),
    duration: 2.6,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#0b1030',
        '#152a63',
        '#1d4f9e',
        '#2582d2',
        '#36b9ee',
        '#8ae8ff',
        '#d4fbff',
        '#ffffff',
      ],
      'seed': 4,
    },
  ),
  act: _act,
  onActorAlpha: (t, _) => t < _flash ? 1.0 : 0.0,
  onCreate: _WarpOutSim.create,
);
