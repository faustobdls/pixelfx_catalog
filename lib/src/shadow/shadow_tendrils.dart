import 'dart:math' as math;
import 'package:pixelfx_core/pixelfx_core.dart';
import 'shadow_lib.dart';

const double _rx = 40;
const double _open = 0.34;
const double _shut = 2.5;
const double _sink = 0.5;
const double _lx = -0.6;
const double _ly = -0.8;

class _SpinePt {
  const _SpinePt(this.x, this.y, this.th, this.w, this.u, this.s);
  final double x;
  final double y;
  final double th;
  final double w;
  final double u;
  final double s;
}

class _TentSpec {
  _TentSpec({
    required this.x,
    required this.y,
    required this.back,
    required this.L,
    required this.W,
    required this.lean,
    required this.curl,
    required this.lam,
    required this.om,
    required this.ph,
    required this.A,
    required this.H,
    required this.t0,
    required this.t1,
    required this.whip,
  });

  final double x;
  final double y;
  final bool back;
  final double L;
  final double W;
  final double lean;
  final int curl;
  final double lam;
  final double om;
  final double ph;
  final double A;
  final double H;
  final double t0;
  final double t1;
  final ({double t, double a})? whip;
  bool up = false;
  bool down = false;
}

List<_SpinePt>? _spine(_TentSpec T, double t) {
  final e = clamp((t - T.t0) / 0.2);
  final s1 = clamp((t - T.t1) / _sink);
  if (e <= 0 || s1 >= 1) return null;
  final lift = 0.07 * math.sin(math.pi * clamp(s1 / 0.3));
  final down = Ease.inOutCubic(clamp((s1 - 0.12) / 0.88));
  final rise = Ease.outBack(e, 1.8) * (1 + lift) * (1 - down);
  final hidden = (1 - rise) * T.L;
  final writhe = T.A * (0.25 + 0.75 * smooth(T.t0 + 0.08, T.t0 + 0.5, t));
  final hook =
      (0.04 + T.H * Ease.outBack(clamp((t - T.t0 - 0.1) / 0.32), 2.5)) *
      (1 + 0.5 * s1) *
      (1 + 0.18 * math.sin(t * 2.3 + T.ph));
  double lean = T.lean + 0.12 * math.sin(t * 1.6 + T.ph);
  final whip = T.whip;
  if (whip != null) {
    final dw = (t - whip.t) / 0.14;
    lean += whip.a * math.exp(-(dw * dw));
  }
  double th = -math.pi / 2 + lean;
  double x = T.x - math.cos(th) * hidden;
  double y = T.y - math.sin(th) * hidden;
  final pts = <_SpinePt>[];
  final n = (T.L / 0.5).ceil();
  for (int i = 0; i <= n; i++) {
    final s = i * 0.5;
    final u = s / T.L;
    pts.add(_SpinePt(x, y, th, T.W * math.pow(1 - u, 0.75) + 0.45, u, s));
    th += 0.5 *
        (writhe * math.sin((s / T.lam) * tau - T.om * t + T.ph) +
            T.curl * hook * smooth(0.58, 1, u));
    x += math.cos(th) * 0.5;
    y += math.sin(th) * 0.5;
  }
  return pts;
}

void _tentacle(
  Painter p,
  _TentSpec T,
  List<_SpinePt> pts,
  List<int> C,
  double t,
) {
  final surf = T.y;
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
  final pulse = (t - T.t0) * 150;
  final slow = (((t - T.t0) * 55) % (T.L * 1.8)) - 4;
  for (final q in pts) {
    if (q.y > surf) continue;
    final nx = -math.sin(q.th);
    final ny = math.cos(q.th);
    final f = nx * _lx + ny * _ly;
    final ks = f >= 0 ? 1 : -1;
    final lit = ks * q.w;
    final x0 = q.x + nx * lit;
    final y0 = q.y + ny * lit;
    final x1 = q.x - nx * lit;
    final y1 = q.y - ny * lit;
    if (y1 <= surf) p.px(x1, y1, C[3]);
    if (y0 <= surf) {
      p.px(
        x0,
        y0,
        f.abs() > 0.8 && q.u > 0.15
            ? C[7]
            : q.u > 0.85
                ? C[6]
                : f.abs() > 0.3
                    ? C[6]
                    : C[5],
      );
    }
    if (q.u > 0.62 && q.u < 0.93 && q.s % 3 < 0.5) {
      p.px(
        q.x + nx * T.curl * q.w * 0.45,
        q.y + ny * T.curl * q.w * 0.45,
        C[4],
      );
    }
    final dp = math.min((q.s - pulse).abs(), (q.s - slow).abs() * 1.6);
    if (dp < 2.5) p.px(q.x, q.y, dp < 1 ? C[7] : C[5]);
  }
  final tip = pts.last;
  if (tip.y <= surf) {
    p.px(tip.x, tip.y, kWhite);
    p.glow(tip.x, tip.y, 6, C[6], 0.25);
  }
  for (int i = 0; i < pts.length; i += 8) {
    if (pts[i].y < surf) p.glow(pts[i].x, pts[i].y, 9, C[4], 0.1);
  }
  final idx = math.min(pts.length - 1, math.max(0, (pulse * 2 + 0.5).floor()));
  final pq = pts[idx];
  if (pulse < T.L && pq.y < surf) p.glow(pq.x, pq.y, 10, C[6], 0.45);
  _SpinePt? base;
  for (final q in pts) {
    if (q.y <= surf) {
      base = q;
      break;
    }
  }
  if (base != null) {
    final w = base.w + 1.5;
    p.line(base.x - w, surf, base.x + w, surf, C[5]);
    p.px(base.x - w - 1, surf + 0.5, C[3]);
    p.px(base.x + w + 1, surf + 0.5, C[3]);
  }
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

class _ShadowTendrilsSim extends BaseEffectSim {
  _ShadowTendrilsSim(Map<String, Object?> o)
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
        if (_inPool(x, t)) {
          ripples.add(PoolRipple(x: x, t0: t, life: 0.5, w: 0.6));
        } else {
          splats.add(_Splat(x, t, s));
        }
      },
    );
    const rows = [
      (-22.0, -2.5),
      (-8.0, -3.0),
      (7.0, -3.0),
      (21.0, -2.5),
      (-28.0, 2.5),
      (-1.0, 3.0),
      (27.0, 2.5),
    ];
    const order = [3, 0, 5, 2, 4, 1, 6];
    const last = [1, 5, 0, 6, 3, 2, 4];
    tents = List.generate(rows.length, (i) {
      final (x, y) = rows[i];
      final back = y < 0;
      final sx = x == 0 ? 1 : (x > 0 ? 1 : -1);
      return _TentSpec(
        x: x + R.range(-3, 3),
        y: y,
        back: back,
        L: back ? R.range(46, 62) : R.range(32, 46),
        W: back ? R.range(3.2, 4) : R.range(3.8, 4.6),
        lean: sx * (0.06 + x.abs() / 120) + R.range(-0.06, 0.06),
        curl: R.chance(0.75) ? -sx : sx,
        lam: R.range(36, 50),
        om: R.range(4.5, 7) * R.sign(),
        ph: R.range(0, tau),
        A: R.range(0.06, 0.085),
        H: R.range(0.15, 0.32),
        t0: 0.3 + order[i] * 0.045 + R.range(0, 0.03),
        t1: 1.5 + last[i] * 0.1 + R.range(0, 0.05),
        whip: R.chance(0.45)
            ? (t: R.range(0.9, 1.5), a: R.range(0.28, 0.45) * R.sign())
            : null,
      );
    });
  }

  final List<int> C;
  late final List<int> dim;
  final Rng R;
  late final Particles ps;
  late final Puffs puffs;
  late final Drops drops;
  late final List<_TentSpec> tents;
  final List<PoolRipple> ripples = [];
  final List<_Splat> splats = [];
  final List<_Light> lights = [];

  double t = 0;
  double acc = 0;

  double _rxAt(double tt) =>
      _rx *
      Ease.outCubic(clamp(tt / _open)) *
      (1 - Ease.inCubic(clamp((tt - _shut) / 0.45)));

  bool _inPool(double x, double tt) => x.abs() < _rxAt(tt) * 0.95;

  void _splash(double x, double y, int n, double power) {
    for (int i = 0; i < n; i++) {
      drops.add(
        x + R.range(-2, 2),
        y - 1,
        R.range(-70, 70) * power,
        -R.range(90, 230) * power,
        R.chance(0.4) ? 2 : 1,
      );
    }
    ripples.add(PoolRipple(x: x, t0: t, life: 0.7, w: 1));
    lights.add(_Light(x, y - 7, 30, 0.6 * power, 0.25));
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    for (final T in tents) {
      if (!T.up && t >= T.t0) {
        T.up = true;
        _splash(T.x, T.y, 12, 1);
        for (int i = 0; i < 4; i++) {
          ps.spawn(
            ParticleKind.spark,
            T.x,
            T.y - 2,
            R.range(-80, 80),
            -R.range(120, 260),
            R.range(0.2, 0.45),
          );
        }
      }
      if (!T.down && t >= T.t1 + _sink * 0.8) {
        T.down = true;
        _splash(T.x, T.y, 6, 0.6);
      }
      if (t > T.t0 + 0.2 && t < T.t1 && R.chance(dt * 1.6)) {
        final pts = _spine(T, t);
        if (pts != null) {
          final q = pts[(R.range(0.3, 0.95) * pts.length).floor()];
          if (q.y < T.y) {
            ps.spawn(
              ParticleKind.star,
              q.x - math.sin(q.th) * q.w,
              q.y + math.cos(q.th) * q.w,
              0,
              -4,
              R.range(0.25, 0.5),
              C[6],
              R.range(1, 2.2),
            );
          }
        }
      }
    }
    final r = _rxAt(t);
    if (r > 8 && t < _shut - 0.4) {
      for (acc += dt * 9; acc > 1; acc--) {
        puffs.spawn(
          PuffKind.soot,
          R.range(-0.8, 0.8) * r,
          -R.range(1, 4),
          R.range(-8, 8),
          -R.range(14, 30),
          R.range(0.6, 0.85),
          R.range(3, 6),
        );
      }
      if (R.chance(dt * 16)) {
        ps.spawn(
          ParticleKind.mote,
          R.range(-0.8, 0.8) * r,
          -2,
          R.range(-8, 8),
          -R.range(30, 80),
          R.range(0.5, 1),
          R.pick([C[7], C[6], C[6], C[5]]),
          R.range(0.6, 1.1),
        );
      }
      if (R.chance(dt * 5)) {
        ps.spawn(
          ParticleKind.ember,
          R.range(-0.8, 0.8) * r,
          -3,
          R.range(-10, 10),
          -R.range(20, 45),
          R.range(0.6, 1),
          C[6],
        );
      }
      if (R.chance(dt * 3)) {
        ripples.add(
          PoolRipple(x: R.range(-0.7, 0.7) * r, t0: t, life: 0.6, w: 0.5),
        );
      }
      if (R.chance(dt * 7)) {
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
      p.glow(0, -16, 86, C[4], 0.22 * k);
      p.glow(0, -8, r * 1.7 + 12, C[4], 0.32 * k * (0.9 + 0.1 * math.sin(t * 5)));
      p.glow(0, 0, r * 1.15, C[5], 0.18 * k);
    }
    puffs.draw(p, PuffKind.soot, PuffLight(x: 0, y: 6, k: k, reach: 70));
    ps.draw(p, 'back');
    for (final T in tents) {
      if (T.back) {
        final pts = _spine(T, t);
        if (pts != null) _tentacle(p, T, pts, dim, t);
      }
    }
  }

  @override
  void draw(Painter p) {
    for (final T in tents) {
      if (!T.back) {
        final pts = _spine(T, t);
        if (pts != null) _tentacle(p, T, pts, C, t);
      }
    }
    drops.draw(p, C[1], C[5]);
    for (final s in splats) {
      final a = 1 - (t - s.t0) / 0.6;
      p.dot(s.x, -0.5, C[1], a * 1.5);
      p.dot(s.x + 1, -0.5, C[2], a);
      if (s.s > 1) p.dot(s.x - 1, -0.5, C[2], a);
      p.dot(s.x, -1.5, C[5], a);
    }
    ps.draw(p, 'front');
    for (final l in lights) {
      final q = l.life / l.max;
      p.glow(l.x, l.y, l.r * (0.6 + 0.4 * q), C[5], l.k * q * q);
    }
  }
}

final PixelEffect shadowTendrilsEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'shadow/shadow-tendrils',
    name: 'Shadow tendrils',
    desc:
        'A dark pool opens on the floor; tentacles with lit rims and hooked tips lash up out of it with a splash, writhe, and sink back as it closes.',
    category: 'shadow',
    kind: AssetKind.effect,
    tags: [
      'shadow',
      'tentacle',
      'tendril',
      'ground',
      'dark',
      'magic',
      'one-shot',
    ],
    size: (208, 130),
    origin: (104, 106),
    duration: 3.2,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {'palette': kVoidPalette, 'seed': 3},
  ),
  onCreate: (o) => _ShadowTendrilsSim(o),
);
