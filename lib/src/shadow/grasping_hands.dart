import 'dart:math' as math;
import 'package:pixelfx_core/pixelfx_core.dart';
import 'shadow_lib.dart';

const double _rx = 42;
const double _open = 0.32;
const double _shut = 2.35;
const double _lx = -0.6;
const double _ly = -0.8;

class _ArmPt {
  const _ArmPt(this.x, this.y, this.th, this.w, this.u);
  final double x;
  final double y;
  final double th;
  final double w;
  final double u;
}

class _ArmSpec {
  _ArmSpec({
    required this.x,
    required this.y,
    required this.back,
    required this.L,
    required this.W,
    required this.lean,
    required this.bend,
    required this.curve,
    required this.curl,
    required this.t0,
    required this.td,
    required this.ph,
  });

  final double x;
  final double y;
  final bool back;
  final double L;
  final double W;
  final double lean;
  final double bend;
  final double curve;
  final int curl;
  final double t0;
  final double td;
  final double ph;
  bool up = false;
  bool shut = false;
  bool down = false;
  ({double x, double y, double t0})? snap;
}

double _gripOf(_ArmSpec A, double t) {
  final shut = Ease.outBack(clamp((t - A.t0 - 0.3) / 0.12), 2.2);
  final splay = smooth(A.td, A.td + 0.12, t);
  return shut * (1 - splay) - 0.35 * splay;
}

List<_ArmPt>? _armPts(_ArmSpec A, double t) {
  final e = clamp((t - A.t0) / 0.22);
  final d = clamp((t - A.td) / 0.34);
  if (e <= 0 || d >= 1) return null;
  final rise = Ease.outBack(e, 1.6) * (1 - Ease.inQuad(d));
  final hidden = (1 - rise) * A.L;
  final grip = _gripOf(A, t);
  final strain =
      t > A.t0 + 0.5 && t < A.td ? math.sin(t * 47 + A.ph) * 0.03 : 0.0;
  final elbow = A.bend * (0.3 + 0.7 * grip) * (1 - d) + strain;
  final lean =
      A.lean + 0.06 * math.sin(t * 2.2 + A.ph) + d * A.lean * 0.6;
  double th = -math.pi / 2 + lean;
  double x = A.x - math.cos(th) * hidden;
  double y = A.y - math.sin(th) * hidden;
  final pts = <_ArmPt>[];
  final n = (A.L / 0.5).ceil();
  for (int i = 0; i <= n; i++) {
    final s = i * 0.5;
    final u = s / A.L;
    pts.add(_ArmPt(x, y, th, A.W * (1 - 0.5 * u) + 0.4, u));
    final g = (u - 0.52) / 0.07;
    th += 0.5 *
        (elbow * math.exp(-(g * g)) / (0.07 * math.sqrt(math.pi) * A.L) +
            A.curve / A.L);
    x += math.cos(th) * 0.5;
    y += math.sin(th) * 0.5;
  }
  return pts;
}

void _drawArm(Painter p, _ArmSpec A, List<_ArmPt> pts, List<int> C) {
  final surf = A.y;
  for (final q in pts) {
    if (q.y > surf) continue;
    final nx = -math.sin(q.th);
    final ny = math.cos(q.th);
    final ks = nx * _lx + ny * _ly >= 0 ? 1 : -1;
    for (double v = -q.w; v <= q.w; v += 0.5) {
      final x = q.x + nx * v;
      final y = q.y + ny * v;
      final u = (v / q.w) * ks;
      if (y <= surf) p.px(x, y, u > 0.55 ? C[2] : u > -0.45 ? C[1] : C[0]);
    }
  }
  for (final q in pts) {
    if (q.y > surf) continue;
    final nx = -math.sin(q.th);
    final ny = math.cos(q.th);
    final f = nx * _lx + ny * _ly;
    final ks = f >= 0 ? 1 : -1;
    final l = ks * q.w;
    if (q.y - ny * l <= surf) p.px(q.x - nx * l, q.y - ny * l, C[3]);
    if (q.y + ny * l <= surf) {
      p.px(q.x + nx * l, q.y + ny * l, f.abs() > 0.8 ? C[7] : C[6]);
    }
  }
  _ArmPt? base;
  for (final q in pts) {
    if (q.y <= surf) {
      base = q;
      break;
    }
  }
  if (base != null) {
    p.line(base.x - base.w - 1.5, surf, base.x + base.w + 1.5, surf, C[5]);
  }
}

void _drawHand(
  Painter p,
  _ArmSpec A,
  List<_ArmPt> pts,
  List<int> C,
  double t,
) {
  final tip = pts.last;
  if (tip.y > A.y - 2) return;
  final th = tip.th;
  final dx = math.cos(th);
  final dy = math.sin(th);
  final nx = -dy;
  final ny = dx;
  final g = _gripOf(A, t);
  final side = A.curl;
  final cx = tip.x + dx * 2.6;
  final cy = tip.y + dy * 2.6;
  p.shade(cx - 5, cy - 5, cx + 5, cy + 5, (x, y, _) {
    final a = (x - cx) * dx + (y - cy) * dy;
    final b = (x - cx) * nx + (y - cy) * ny;
    final d = (a / 3) * (a / 3) + (b / 2.7) * (b / 2.7);
    if (d > 1.25) return null;
    if (d > 1) return b * side < 0 ? C[6] : C[3];
    return b * side < -1 ? C[2] : C[1];
  });
  (double, double) bone(
    double x0,
    double y0,
    double ang,
    double len,
    bool last,
  ) {
    final x1 = x0 + math.cos(ang) * len;
    final y1 = y0 + math.sin(ang) * len;
    final ox = (-math.sin(ang) * side * -1 + 0.5).floor().toDouble();
    final oy = (math.cos(ang) * side * -1 + 0.5).floor().toDouble();
    p.line(x0, y0, x1, y1, C[1]);
    p.line(x0 + ox, y0 + oy, x1 + ox, y1 + oy, C[5]);
    if (last) {
      p.px(x1, y1, kWhite);
      p.px(x1 + math.cos(ang), y1 + math.sin(ang), C[7]);
    }
    return (x1, y1);
  }

  final spread = 1 - 0.65 * math.max(0.0, g);
  final curl = g * 1.2;
  const fingerOffsets = [-2.2, -0.75, 0.75, 2.2];
  for (int i = 0; i < fingerOffsets.length; i++) {
    final o = fingerOffsets[i];
    final bx = cx + dx * 2.6 + nx * o * 0.9;
    final by = cy + dy * 2.6 + ny * o * 0.9;
    final len = i == 0 || i == 3 ? 2.6 : 3.2;
    final a0 = th + o * 0.2 * spread;
    final (jx, jy) = bone(bx, by, a0 + curl * side * 0.6, len, false);
    bone(jx, jy, a0 + curl * side * 1.5, len * 0.85, true);
  }
  final (jx, jy) = bone(
    cx - nx * side * 2.4,
    cy - ny * side * 2.4,
    th - side * (1 - 0.6 * g),
    2.4,
    false,
  );
  bone(jx, jy, th - side * (0.6 - 1.4 * g), 2, true);
  p.glow(cx, cy, 8, C[5], 0.18 + 0.3 * math.max(0.0, g));
}

class _Splat {
  _Splat(this.x, this.t0, this.s);
  final double x;
  final double t0;
  final double s;
}

class _Light {
  _Light(this.x, this.y, this.r, this.k, this.life) : max = life;
  final double x;
  final double y;
  final double r;
  final double k;
  double life;
  final double max;
}

class _GraspingHandsSim extends BaseEffectSim {
  _GraspingHandsSim(Map<String, Object?> o)
      : C = fit(o.palette, 8),
        R = Rng(o.seed) {
    dim = [C[0], C[0], C[1], C[1], C[3], C[4], C[5], C[6]];
    ps = Particles(
      rng: R,
      ground: (_) => 0,
      sparks: [C[7], C[6], C[5], C[4]],
      haze: C[4],
    );
    puffs = Puffs(
      rng: R,
      flame: [C[7], C[6], C[5], C[4], C[3], C[2], C[1], C[1], C[0]],
      soot: [mix(C[3], C[2], 0.55), mix(C[2], C[1], 0.5)],
      cap: mix(C[4], C[2], 0.5),
      rim: [C[6], C[5], C[4]],
      floor: (_) => 0,
    );
    drops = Drops(
      onLand: (x, y, v, s) {
        if (x.abs() < _rxAt(t) * 0.95) {
          ripples.add(PoolRipple(x: x, t0: t, life: 0.5, w: 0.6));
        } else {
          splats.add(_Splat(x, t, s));
        }
      },
    );
    const lay = [(-20.0, -2.5, 1), (17.0, -2.5, -1), (-30.0, 2.5, 1), (28.0, 2.5, -1)];
    const t0Order = [1, 3, 0, 2];
    const tdOrder = [2, 0, 3, 1];
    arms = List.generate(lay.length, (i) {
      final (x, y, toward) = lay[i];
      final back = y < 0;
      return _ArmSpec(
        x: x + R.range(-3, 3),
        y: y,
        back: back,
        L: back ? R.range(44, 52) : R.range(36, 44),
        W: back ? R.range(3.2, 3.8) : R.range(3.6, 4.2),
        lean: -toward * R.range(0.16, 0.3),
        bend: toward * R.range(0.35, 0.6),
        curve: toward * R.range(0.05, 0.15),
        curl: toward,
        t0: 0.3 + t0Order[i] * 0.06 + R.range(0, 0.03),
        td: 1.45 + tdOrder[i] * 0.09 + R.range(0, 0.05),
        ph: R.range(0, tau),
      );
    });
  }

  final List<int> C;
  late final List<int> dim;
  final Rng R;
  late final Particles ps;
  late final Puffs puffs;
  late final Drops drops;
  late final List<_ArmSpec> arms;
  final List<PoolRipple> ripples = [];
  final List<_Splat> splats = [];
  final List<_Light> lights = [];

  double t = 0;
  double acc = 0;

  double _rxAt(double tt) =>
      _rx *
      Ease.outCubic(clamp(tt / _open)) *
      (1 - Ease.inCubic(clamp((tt - _shut) / 0.45)));

  void _splash(double x, double y, int n, double k) {
    for (int i = 0; i < n; i++) {
      drops.add(
        x + R.range(-2, 2),
        y - 1,
        R.range(-70, 70) * k,
        -R.range(90, 220) * k,
        R.chance(0.4) ? 2 : 1,
      );
    }
    ripples.add(PoolRipple(x: x, t0: t, life: 0.7, w: 1));
    lights.add(_Light(x, y - 7, 30, 0.55 * k, 0.25));
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    for (final A in arms) {
      if (!A.up && t >= A.t0) {
        A.up = true;
        _splash(A.x, A.y, 12, 1);
      }
      if (!A.shut && t >= A.t0 + 0.36) {
        A.shut = true;
        final pts = _armPts(A, t);
        if (pts != null) {
          final q = pts.last;
          lights.add(_Light(q.x, q.y, 22, 0.7, 0.2));
          final sx = q.x + math.cos(q.th) * 4;
          final sy = q.y + math.sin(q.th) * 4;
          A.snap = (x: sx, y: sy, t0: t);
          for (int i = 0; i < 6; i++) {
            final a = R.range(0, tau);
            final sp = R.range(60, 130);
            ps.spawn(
              ParticleKind.spark,
              sx,
              sy,
              math.cos(a) * sp,
              math.sin(a) * sp - 20,
              R.range(0.12, 0.3),
            );
          }
          puffs.spawn(PuffKind.soot, sx, sy, 0, -12, 0.6, 3.5);
        }
      }
      if (!A.down && t >= A.td + 0.28) {
        A.down = true;
        _splash(A.x, A.y, 8, 0.7);
      }
    }
    final r = _rxAt(t);
    if (r > 8 && t < _shut - 0.4) {
      for (acc += dt * 8; acc > 1; acc--) {
        puffs.spawn(
          PuffKind.soot,
          R.range(-0.8, 0.8) * r,
          -R.range(1, 4),
          R.range(-8, 8),
          -R.range(14, 28),
          R.range(0.6, 0.85),
          R.range(3, 6),
        );
      }
      if (R.chance(dt * 12)) {
        ps.spawn(
          ParticleKind.mote,
          R.range(-0.8, 0.8) * r,
          -2,
          R.range(-8, 8),
          -R.range(30, 70),
          R.range(0.5, 0.9),
          R.pick([C[7], C[6], C[5]]),
          R.range(0.6, 1),
        );
      }
      if (R.chance(dt * 6)) {
        ps.spawn(
          ParticleKind.vapour,
          R.range(-0.7, 0.7) * r,
          -R.range(2, 8),
          R.range(-6, 6),
          -R.range(10, 22),
          R.range(0.6, 0.9),
          R.chance(0.5) ? C[3] : C[4],
          R.range(3, 6),
        );
      }
      if (R.chance(dt * 3)) {
        ripples.add(
          PoolRipple(x: R.range(-0.7, 0.7) * r, t0: t, life: 0.6, w: 0.5),
        );
      }
    }
    for (int i = ripples.length - 1; i >= 0; i--) {
      if (t - ripples[i].t0 > ripples[i].life) ripples.removeAt(i);
    }
    for (int i = splats.length - 1; i >= 0; i--) {
      if (t - splats[i].t0 > 0.6) splats.removeAt(i);
    }
    for (int i = lights.length - 1; i >= 0; i--) {
      if ((lights[i].life -= dt) <= 0) lights.removeAt(i);
    }
    drops.update(dt);
    puffs.update(dt);
    ps.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final r = _rxAt(t);
    final k = r / _rx;
    floorPool(p, C, r, t, ripples);
    if (k > 0) {
      p.glow(0, -16, 80, C[4], 0.2 * k);
      p.glow(0, -8, r * 1.7 + 12, C[4], 0.3 * k);
      p.glow(0, 0, r * 1.15, C[5], 0.16 * k);
    }
    puffs.draw(p, PuffKind.soot, PuffLight(x: 0, y: 6, k: k, reach: 70));
    ps.draw(p, 'back');
    for (final A in arms) {
      if (A.back) {
        final pts = _armPts(A, t);
        if (pts != null) {
          _drawArm(p, A, pts, dim);
          _drawHand(p, A, pts, dim, t);
        }
      }
    }
  }

  @override
  void draw(Painter p) {
    for (final A in arms) {
      if (!A.back) {
        final pts = _armPts(A, t);
        if (pts != null) {
          _drawArm(p, A, pts, C);
          _drawHand(p, A, pts, C, t);
        }
      }
    }
    for (final A in arms) {
      final snap = A.snap;
      if (snap != null && t - snap.t0 < 0.22) {
        final u = (t - snap.t0) / 0.22;
        ringFast(
          p,
          snap.x,
          snap.y,
          2 + 5 * Ease.outCubic(u),
          1,
          u < 0.4 ? C[6] : u < 0.7 ? C[5] : C[3],
        );
      }
    }
    drops.draw(p, C[1], C[5]);
    for (final s in splats) {
      final a = 1 - (t - s.t0) / 0.6;
      p.dot(s.x, -0.5, C[1], a * 1.5);
      p.dot(s.x + 1, -0.5, C[2], a);
      p.dot(s.x, -1.5, C[5], a);
    }
    ps.draw(p, 'front');
    for (final l in lights) {
      final q = l.life / l.max;
      p.glow(l.x, l.y, l.r * (0.6 + 0.4 * q), C[5], l.k * q * q);
    }
  }
}

final PixelEffect graspingHandsEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'shadow/grasping-hands',
    name: 'Grasping hands',
    desc:
        'Shadow arms burst up out of a dark pool with a splash, clench their hands into claws, strain, and are dragged back under, fingers clawing at the air.',
    category: 'shadow',
    kind: AssetKind.effect,
    tags: [
      'shadow',
      'hands',
      'arms',
      'grab',
      'ground',
      'dark',
      'magic',
      'one-shot',
    ],
    size: (200, 116),
    origin: (100, 100),
    duration: 3.1,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {'palette': kVoidPalette, 'seed': 5},
  ),
  onCreate: (o) => _GraspingHandsSim(o),
);
