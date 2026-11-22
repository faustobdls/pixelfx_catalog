import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const Pose _high = Pose(
    turn: 1.15, crouch: 0, fx: -7, fy: -44, bx: 8, by: -44, ffx: -5, fbx: 6);
const Pose _slam = Pose(
    turn: 1.15, crouch: 8, lean: 3, fx: -9, fy: -8, bx: 11, by: -8, ffx: -8, fbx: 9);
const Pose _ease = Pose(
    turn: 1.0, crouch: 2, fx: -8, fy: -17, bx: 9, by: -17, ffx: -4, fbx: 5);

const double _charge = 0.42;
const double _spread = 0.62;
const double _hold = 1.95;
const double _melt = 0.7;
const double _coreY = -24.0;

class _RingSpec {
  final (double, double) q;
  final (double, double) h;
  final (double, double) w;
  final int n;
  final int kids;
  const _RingSpec(this.q, this.h, this.w, this.n, this.kids);
}

const List<_RingSpec> _rings = [
  _RingSpec((0.15, 0.24), (24, 32), (10, 13), 2, 2),
  _RingSpec((0.36, 0.52), (13, 19), (7, 9), 3, 1),
  _RingSpec((0.62, 0.9), (5, 10), (4, 6), 4, 0),
];

void _frost(
  Painter p,
  List<int> c,
  double x0,
  double x1,
  double reach,
  double a,
  double edge,
) {
  final ix0 = x0.floor();
  final ix1 = x1.ceil();
  for (var x = ix0; x <= ix1; x++) {
    final d = (x + 0.5).abs();
    final q = d / reach;
    final k = clamp((a * 1.15 - q) / 0.15);
    if (k <= 0.0) continue;
    final h = rand(x, 17);
    final fresh = edge > 0.0 && d > edge - 3.0;
    final tuft =
        h < 0.45 ? ((1.0 + rand(x, 5) * 3.0) * (1.0 - q * 0.6)).round() : 0;
    final depth = (4.0 + rand(x, 11) * 4.0) * (1.0 - q * 0.5);
    p.dot(x, 0, fresh || h < 0.25 ? kWhite : c[6], k);
    for (var j = 1; j <= tuft; j++) {
      p.dot(x, -j, j == tuft ? kWhite : c[5], k);
    }
    if (tuft > 1 && rand(x, 9) < 0.5) {
      p.dot(x + (rand(x, 3) < 0.5 ? -1 : 1), -tuft + 1, c[6], k);
    }
    for (var j = 1; j <= depth; j++) {
      final v = j / depth;
      final col = rand(x * 31 + j, 7) < 0.06
          ? kWhite
          : (v < 0.25 ? c[6] : (v < 0.55 ? c[5] : c[4]));
      p.dot(x, j, col, k * (1.1 - v) * (fresh ? 1.3 : 1.0));
    }
  }
}

void _snowflake(
  Painter p,
  List<int> c,
  double x,
  double y,
  double l,
  double spin,
  double k,
) {
  if (l < 0.8) return;
  for (var i = 0; i < 6; i++) {
    final a = spin + (i * tau) / 6.0;
    final ca = math.cos(a);
    final sa = math.sin(a);
    for (var d = 0.0; d <= l; d += 0.5) {
      p.dot(x + ca * d, y + sa * d, d < l * 0.4 ? kWhite : c[6], k + 0.2);
    }
    if (l > 3.0) {
      for (final s in const [-1, 1]) {
        final bx = x + ca * l * 0.6;
        final by = y + sa * l * 0.6;
        final ba = a + s * 0.9;
        for (var d = 0.0; d <= l * 0.35; d += 0.5) {
          p.dot(bx + math.cos(ba) * d, by + math.sin(ba) * d, c[5], k);
        }
      }
    }
  }
  p.px(x, y, kWhite);
  p.glow(x, y, 10.0 + l * 3.0, c[5], 0.35 + 0.5 * k);
}

class _CrystalPart {
  final double dx, h, w, lean;
  const _CrystalPart(this.dx, this.h, this.w, this.lean);
}

class _CrystalSite {
  final double x, d, h, t0, phase;
  final bool back;
  bool up = false;
  final List<_CrystalPart> parts;
  _CrystalSite(this.x, this.d, this.h, this.back, this.t0, this.parts, this.phase);
}

class _FrostNovaSim extends BaseEffectSim {
  final List<int> c;
  late final List<int> dim;
  final double reach;
  final Rng r;
  late final Particles ps;
  final Bits bits = Bits(ground: (_) => 0.0);
  final Lights lights = Lights();
  final List<_CrystalSite> sites = [];
  double t = 0.0;
  bool released = false;

  _FrostNovaSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        reach = o.numOpt('reach', 104.0),
        r = Rng(o.seed) {
    dim = [c[0], c[0], c[1], c[2], c[3], c[4], c[5], c[6]];
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [c[7], c[6], c[5], c[4]],
      haze: c[5],
    );
    double reachedAt(double d) =>
        _charge +
        _spread * (1.0 - math.pow(1.0 - math.min(1.0, d / reach), 1.0 / 3.0));

    for (final side in const [-1, 1]) {
      for (var ri = 0; ri < _rings.length; ri++) {
        final ring = _rings[ri];
        for (var i = 0; i < ring.n; i++) {
          final q = ring.q.$1 +
              ((ring.q.$2 - ring.q.$1) * (i + r.range(0.2, 0.8))) / ring.n;
          final h = r.range(ring.h.$1, ring.h.$2);
          final w = r.range(ring.w.$1, ring.w.$2);
          final parts = <_CrystalPart>[
            _CrystalPart(0, h, w, side * h * r.range(0.1, 0.28)),
          ];
          for (var k = 0; k < ring.kids; k++) {
            final s = k.isOdd ? -side : side;
            final kh = h * r.range(0.4, 0.62);
            parts.insert(
              0,
              _CrystalPart(
                s * r.range(0.3, 0.5) * w,
                kh,
                w * 0.62,
                s * kh * r.range(0.35, 0.6),
              ),
            );
          }
          sites.add(_CrystalSite(
            side * q * reach,
            q * reach,
            h,
            (i + ri + (side > 0 ? 1 : 0)) % 2 == 1,
            reachedAt(q * reach) + r.range(0.0, 0.03),
            parts,
            r.next(),
          ));
        }
      }
    }
  }

  double _front(double tt) => tt < _charge
      ? 0.0
      : reach *
          (1.0 - math.pow(1.0 - clamp((tt - _charge) / _spread), 3.0));

  double _sink(double tt) => smooth(_hold, _hold + _melt, tt);

  void _drawCrystals(Painter p, bool back) {
    final m = _sink(t);
    for (final s in sites) {
      if (!s.up || s.back != back || m >= 1.0) continue;
      final g = Ease.outBack(clamp((t - s.t0) / 0.1), 2.6);
      final white = t < s.t0 + 0.03;
      final sw = (((t - s.t0) * 0.7 + s.phase * 3.0) % 1.6) / 0.5;
      for (final q in s.parts) {
        crystal(
          p,
          s.x + q.dx,
          back ? -1.0 : 0.0,
          q.h * g * (1.0 - m),
          q.w * (1.0 - m * 0.3),
          q.lean * g * (1.0 - m),
          back ? dim : c,
          white: white,
          glint: sw <= 1.0 ? sw : -1.0,
        );
      }
    }
  }

  void _drawRing(Painter p, bool back) {
    if (t < _charge) return;
    final u = clamp((t - _charge) / (_spread + 0.15));
    if (u >= 1.0) return;
    final fr = _front(t);
    band(
      p,
      0,
      0,
      fr + 2.0,
      0.16,
      math.max(2.0, 10.0 * math.pow(1.0 - u, 0.7)),
      u < 0.75 ? 1.0 : (1.0 - u) / 0.25,
      c,
      keep: (g) => (math.sin(g) < 0.0) == back,
      hot: t - _charge < 0.1,
    );
    if (!back) {
      for (final s in const [-1, 1]) {
        p.glow(s * (fr + 2.0), -2, 22, c[5], 0.55 * (1.0 - u));
      }
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (t < _charge - 0.06) {
      if (r.chance(0.9)) {
        final a = r.range(0, tau);
        final d = r.range(26, 58);
        final dur = r.range(0.2, 0.3);
        final v = (d * 3.0) / (math.exp(3.0 * dur) - 1.0);
        final x = math.cos(a) * d;
        final y = math.min(_coreY + math.sin(a) * d * 0.8, -2.0);
        final rawL = hypot(x, y - _coreY);
        final l = rawL == 0.0 ? 1.0 : rawL;
        ps.spawn(P.streak, x, y, (-x / l) * v, ((_coreY - y) / l) * v, dur,
            r.chance(0.5) ? c[6] : c[5]);
      }
      if (r.chance(0.14)) {
        final s = r.sign();
        ps.spawn(P.vapour, s * r.range(28, 60), -r.range(0, 2),
            -s * r.range(35, 70), -r.range(0, 3), r.range(0.35, 0.5),
            c[6], r.range(2, 3));
      }
    }
    if (t >= _charge && !released) {
      released = true;
      lights.add(0, _coreY, 84, c[4], 0.8, 0.55);
      lights.add(0, _coreY, 45, kWhite, 0.7, 0.12);
      for (var i = 0; i < 22; i++) {
        final a = r.range(-math.pi, 0.25);
        final sp = r.range(110, 280);
        bits.add(DebrisBit(
          kind: DebrisKind.shard,
          x: r.range(-3, 3),
          y: _coreY,
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp,
          g: 0.7,
          drag: 0.6,
          bounce: 0.3,
          life: r.range(0.9, 1.5),
          a: r.range(0, tau),
          va: r.range(-20, 20),
          s: r.range(1.5, 3.5),
          c: r.pick([c[7], c[6], c[5]]),
        ));
      }
      for (var i = 0; i < 14; i++) {
        final a = r.range(-math.pi, 0);
        final sp = r.range(40, 160);
        ps.spawn(P.flake, 0, _coreY, math.cos(a) * sp, math.sin(a) * sp,
            r.range(1.2, 1.8), r.chance(0.6) ? kWhite : c[6], r.range(0.5, 1.6));
      }
    }
    final fr = _front(t);
    if (t > _charge && t < _charge + _spread) {
      for (final s in const [-1, 1]) {
        ps.spawn(
          P.vapour,
          s * fr + r.range(-2, 2),
          -r.range(0, 5),
          s * r.range(15, 75),
          -r.range(2, 15),
          r.range(0.6, 1.0),
          r.chance(0.7) ? c[6] : c[5],
          r.range(3, 5.5) * (1.0 - 0.4 * (fr / reach)),
        );
        if (r.chance(0.45)) {
          ps.spawn(P.flake, s * fr, -2, s * r.range(10, 45), -r.range(30, 85),
              r.range(1.1, 1.9), r.chance(0.5) ? kWhite : c[6], r.range(0.5, 1.2));
        }
      }
    }
    for (final s in sites) {
      if (!s.up && t >= s.t0) {
        s.up = true;
        final n = 2 + (s.h / 8.0).round();
        for (var i = 0; i < n; i++) {
          final a = -math.pi / 2 + r.range(-1.3, 1.3);
          final sp = r.range(60, 200) * (0.5 + s.h / 40.0);
          bits.add(DebrisBit(
            kind: DebrisKind.shard,
            x: s.x + r.range(-3, 3),
            y: 0,
            vx: math.cos(a) * sp,
            vy: math.sin(a) * sp,
            g: 0.8,
            drag: 0.6,
            bounce: 0.3,
            life: r.range(0.9, 1.6),
            a: r.range(0, tau),
            va: r.range(-18, 18),
            s: r.range(1.5, 3),
            c: r.pick([c[7], c[6], c[5]]),
          ));
        }
        ps.spawn(P.vapour, s.x, -1, r.range(-30, 30), -r.range(2, 8),
            r.range(0.5, 0.9), c[6], r.range(2.5, 4));
        if (s.h > 10.0) {
          ps.spawn(P.star, s.x + r.range(-3, 3), -r.range(4, s.h * 0.8), 0, -3,
              r.range(0.3, 0.6), c[6], r.range(1, 2.4));
        }
      }
    }
    if (t > _charge + 0.2 && t < _hold + 0.2) {
      if (r.chance(0.5)) {
        final s = r.pick(sites);
        if (s.up) {
          ps.spawn(
            P.star,
            s.x + r.range(-3, 3),
            -r.range(2, s.h * 0.9),
            0,
            -3,
            r.range(0.3, 0.6),
            r.chance(0.6) ? c[6] : kWhite,
            r.range(0.6, 2.2),
          );
        }
      }
      if (t < _hold - 0.3 && r.chance(0.16)) {
        ps.spawn(
          P.flake,
          r.range(-1, 1) * fr,
          -r.range(40, 90),
          r.range(-5, 5),
          r.range(3, 10),
          r.range(1.1, 1.5),
          r.chance(0.5) ? kWhite : c[6],
          r.range(0.5, 1.4),
        );
      }
    }
    if (t > _hold && t < _hold + _melt) {
      if (r.chance(0.5)) {
        final s = r.pick(sites);
        bits.add(DebrisBit(
          kind: DebrisKind.drip,
          x: s.x + r.range(-3, 3),
          y: -r.range(3, s.h * 0.6 * (1.0 - _sink(t))),
          vy: 10,
          g: 0.6,
          life: 1,
          c: c[5],
        ));
      }
      if (r.chance(0.25)) {
        ps.spawn(
          P.vapour,
          r.range(-1, 1) * reach * 0.8,
          -r.range(0, 3),
          r.range(-10, 10),
          -r.range(6, 16),
          r.range(0.6, 1),
          c[5],
          r.range(3, 5),
        );
      }
    }
    ps.update(dt);
    bits.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final out = 1.0 - smooth(_hold + 0.2, _hold + _melt + 0.6, t);
    final fr = _front(t);
    if (out > 0.0 && t > _charge) {
      _frost(p, c, -math.max(12.0, fr + 1.0), math.max(12.0, fr + 1.0),
          reach, out, fr);
    }
    _drawRing(p, true);
    _drawCrystals(p, true);
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    _drawRing(p, false);
    _drawCrystals(p, false);
    if (t < _charge) {
      final k = t / _charge;
      final beat = 1.0 +
          0.25 * math.exp(-math.pow(t - _charge * 0.55, 2) / 0.002) +
          0.3 * math.exp(-math.pow(t - _charge * 0.85, 2) / 0.002);
      _snowflake(p, c, 0, _coreY, (2.0 + 5.5 * k * k) * beat, t * 4.0, k);
    } else if (t < _charge + 0.22) {
      final a = (t - _charge) / 0.22;
      flare(p, 0, _coreY, 36.0 * math.pow(1.0 - a, 1.5), 1.0 - a, c);
      p.glow(0, _coreY, 46, kWhite, 0.6 * (1.0 - a));
    }
    if (t > _charge) {
      final k = (1.0 - smooth(_hold, _hold + _melt + 0.3, t)) *
          (0.85 + 0.15 * math.sin(t * 2.4));
      final fr = _front(t);
      for (var i = -3; i <= 3; i++) {
        p.glow((i / 3.5) * fr, -4, 26, c[4], 0.16 * k);
      }
    }
    bits.draw(p);
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect frostNovaEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ice/frost-nova',
    name: 'Frost nova',
    desc:
        'Frost spirals into a spinning snowflake, then a wave blooms three rings of ice crystals round the caster; snow drifts, frost creeps, and the ice melts back into the floor.',
    category: 'ice',
    tags: ['ice', 'nova', 'aoe', 'frost', 'magic', 'one-shot'],
    size: (288, 192),
    origin: (144, 150),
    duration: 3.4,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#151a3d', '#212f6b', '#2c58aa', '#3a8bd8',
        '#62c8f4', '#a6ecff', '#dcfbff', '#ffffff',
      ],
      'reach': 104,
      'seed': 4,
    },
  ),
  act: ActSpec(
    target: const TargetSpec(x: 76),
    poses: [
      const PoseKey(-0.34, kReady),
      PoseKey(-0.04, _high.copyWith(crouch: 2, fy: -36, by: -36)),
      const PoseKey(0.36, _high),
      const PoseKey(0.42, _slam, PoseEase.snap),
      PoseKey(0.9, _slam.copyWith(crouch: 7)),
      PoseKey(1.9, _slam.copyWith(crouch: 6)),
      const PoseKey(2.6, _ease),
      const PoseKey(3.4, kReady),
    ],
    hits: const [
      HitSpec(t: 0.42, stop: 0.1, shake: 0.26, amp: 2, target: false),
      HitSpec(t: 0.66, push: 0.9, straw: 6, y: -10, skin: 'ice', shiver: 1.7),
      HitSpec(t: 2.9, push: 0.2, straw: 0, flash: 0, clearSkin: true),
    ],
    dust: const [
      DustSpec(t: 0.42, x: 10, n: 5, dir: 1, color: '#d8f2ff'),
      DustSpec(t: 0.42, x: -10, n: 5, dir: -1, color: '#d8f2ff'),
    ],
  ),
  onCreate: (o) => _FrostNovaSim(o),
);
