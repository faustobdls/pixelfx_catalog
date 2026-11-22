import 'dart:math' as math;
import 'package:pixelfx_core/pixelfx_core.dart';
import 'shadow_lib.dart';

const double _tx = 104;
const double _ty = -24;
const double _hx = 1;
const double _hy = -20;
const int _n = 7;

class _Orb {
  _Orb({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.home,
    required this.size,
  });

  double x;
  double y;
  double vx;
  double vy;
  final double home;
  final List<(double, double)> trail = [];
  bool done = false;
  double at = 0;
  final double size;
}

class _Stain {
  _Stain(this.x, this.t0);
  final double x;
  final double t0;
}

class _Light {
  _Light(this.x, this.y, this.r, this.c, this.k, this.life) : max = life;
  final double x;
  final double y;
  final double r;
  final int c;
  final double k;
  double life;
  final double max;
}

class _LifeStealSim extends BaseEffectSim {
  _LifeStealSim(Map<String, Object?> o)
      : C = fit(o.palette, 8),
        R = Rng(o.seed),
        A = o.actor {
    ps = Particles(
      rng: R,
      ground: (_) => 0,
      sparks: [kWhite, C[7], C[6], C[5]],
    );
    drops = Drops(onLand: (x, y, v, s) => stains.add(_Stain(x, t)));
    orbs = List.generate(_n, (i) {
      final a = -math.pi / 2 + (i - (_n - 1) / 2) * 0.4 + R.range(-0.12, 0.12);
      final sp = R.range(100, 170);
      return _Orb(
        x: _tx,
        y: _ty,
        vx: math.cos(a) * sp + 10,
        vy: math.sin(a) * sp,
        home: 0.36 + i * 0.05 + R.range(0, 0.04),
        size: R.range(1.6, 2.4),
      );
    });
  }

  final List<int> C;
  final Rng R;
  final ActorDefinition? A;
  late final Particles ps;
  late final Drops drops;
  final List<_Stain> stains = [];
  final List<_Light> lights = [];
  late final List<_Orb> orbs;

  double t = 0;
  bool hit = false;
  double flush = 0;

  void _light(double x, double y, double r, int c, double k, double life) =>
      lights.add(_Light(x, y, r, c, k, life));

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (!hit) {
      hit = true;
      _light(_tx, _ty, 54, C[5], 1, 0.35);
      _light(_tx, _ty, 18, kWhite, 1, 0.08);
      for (int i = 0; i < 14; i++) {
        drops.add(
          _tx + R.range(-3, 3),
          _ty + R.range(-3, 3),
          R.range(-40, 90),
          R.range(-140, -20),
          R.chance(0.4) ? 2 : 1,
        );
      }
      for (int i = 0; i < 12; i++) {
        final a = R.range(0, tau);
        final sp = R.range(80, 170);
        ps.spawn(
          ParticleKind.spark,
          _tx,
          _ty,
          math.cos(a) * sp,
          math.sin(a) * sp,
          R.range(0.15, 0.35),
        );
      }
    }
    for (final b in orbs) {
      if (b.done) continue;
      if (t < b.home) {
        b.vx -= b.vx * 5 * dt;
        b.vy -= b.vy * 5 * dt;
      } else {
        final dx = _hx - b.x;
        final dy = _hy - b.y;
        final dRaw = hypot(dx, dy);
        final d = dRaw > 0 ? dRaw : 1.0;
        final pull = 2600 * math.min(1.0, (t - b.home) * 3);
        b.vx += (dx / d) * pull * dt;
        b.vy += (dy / d) * pull * dt;
        b.vx -= b.vx * 2.2 * dt;
        b.vy -= b.vy * 2.2 * dt;
        if (d < 6) {
          b.done = true;
          b.at = t;
          flush = math.min(1.5, flush + 0.45);
          _light(_hx, _hy, 30, C[5], 0.8, 0.25);
          for (int i = 0; i < 6; i++) {
            final a = R.range(0, tau);
            final sp = R.range(40, 100);
            ps.spawn(
              ParticleKind.spark,
              _hx,
              _hy,
              math.cos(a) * sp,
              math.sin(a) * sp - 20,
              R.range(0.12, 0.3),
            );
          }
          for (int i = 0; i < 3; i++) {
            ps.spawn(
              ParticleKind.ember,
              _hx + R.range(-8, 8),
              _hy + R.range(-6, 14),
              R.range(-10, 10),
              -R.range(15, 35),
              R.range(0.6, 1.1),
              C[6],
            );
          }
        }
      }
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.trail.insert(0, (b.x, b.y));
      if (b.trail.length > 26) b.trail.removeLast();
    }
    flush -= flush * 2.6 * dt;
    for (int i = lights.length - 1; i >= 0; i--) {
      if ((lights[i].life -= dt) <= 0) lights.removeAt(i);
    }
    for (int i = stains.length - 1; i >= 0; i--) {
      if (t - stains[i].t0 > 0.8) stains.removeAt(i);
    }
    drops.update(dt);
    ps.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final k = 1 - smooth(0.1, 0.9, t);
    if (k > 0) {
      p.disc(_tx, _ty, 6 + t * 10, C[2], 0.5 * k);
      p.glow(_tx, _ty, 30, C[4], 0.35 * k);
    }
    for (final s in stains) {
      p.dot(s.x, -0.5, C[3], 1 - (t - s.t0) / 0.8);
    }
  }

  @override
  void draw(Painter p) {
    final fk = math.min(1.0, flush) * (1 - smooth(1.5, 2.05, t));
    final actor = A;
    if (actor != null && fk > 0.03) {
      for (int my = 0; my < actor.h; my++) {
        for (int mx = 0; mx < actor.w; mx++) {
          final c0 = actor.pixels[my * actor.w + mx];
          if (c0 == 0) continue;
          final l = luma(c0);
          p.blend(
            actor.x + mx,
            actor.y + my,
            l > 0.6
                ? C[6]
                : l > 0.4
                    ? C[5]
                    : l > 0.2
                        ? C[4]
                        : C[3],
            0.45 * fk,
          );
        }
      }
      if (fk > 0.12) {
        p.outline(
          actor.mask,
          actor.x,
          actor.y,
          fk > 0.6 ? C[6] : fk > 0.3 ? C[5] : C[3],
        );
      }
      p.glow(_hx, _hy, 28, C[5], 0.45 * fk);
    }
    if (t < 0.12) sparkle(p, _tx, _ty, 10 * (1 - t / 0.12), C[7], C[5], 0.6);
    final ru = t / 0.28;
    if (ru < 1) {
      ringFast(
        p,
        _tx,
        _ty,
        4 + 16 * Ease.outCubic(ru),
        math.max(1.0, 2 * (1 - ru)),
        ru < 0.4 ? C[7] : C[5],
      );
    }
    drops.draw(p, C[3], C[6]);
    for (final b in orbs) {
      if (b.done && t - b.at > 0.2) continue;
      final n = b.done
          ? (b.trail.length * (1 - (t - b.at) / 0.2)).floor()
          : b.trail.length;
      for (int i = n - 1; i >= 1; i--) {
        final u = i / 25;
        final (x0, y0) = b.trail[i - 1];
        final (x1, y1) = b.trail[i];
        p.line(
          x1,
          y1,
          x0,
          y0,
          u < 0.15
              ? C[7]
              : u < 0.35
                  ? C[6]
                  : u < 0.6
                      ? C[5]
                      : u < 0.8
                          ? C[4]
                          : C[2],
        );
        if (i < 7) {
          p.disc(
            x1,
            y1,
            (b.size + 0.4) * (1 - i / 7),
            u < 0.12 ? C[6] : C[5],
            0.8,
          );
        }
        if (i % 6 == 3) p.glow(x1, y1, 6, C[5], 0.2 * (1 - u));
      }
      if (b.done) continue;
      final pulse = t < b.home ? 0.8 + 0.2 * math.sin(t * 30 + b.size * 9) : 1.0;
      p.circle(b.x, b.y, b.size + 0.9, C[4]);
      p.circle(b.x, b.y, b.size * pulse, C[6]);
      p.px(b.x - 0.5, b.y - 0.5, kWhite);
      p.glow(b.x, b.y, 9, C[5], 0.5);
    }
    ps.draw(p);
    for (final l in lights) {
      final q = l.life / l.max;
      p.glow(l.x, l.y, l.r * (0.6 + 0.4 * q), l.c, l.k * q * q);
    }
  }
}

final Pose _grasp = kReady.copyWith(
  crouch: 3,
  lean: 3,
  fx: 17,
  fy: -28,
  bx: -6,
  by: -21,
  ffx: 10,
  fbx: -9,
);

const Pose _fed = Pose(
  turn: 1.15,
  crouch: 0,
  lean: -3,
  hy: -1,
  fx: -13,
  fy: -37,
  bx: 14,
  by: -37,
  ffx: -3,
  fbx: 4,
);

final PixelEffect lifeStealEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'shadow/life-steal',
    name: 'Life steal',
    desc:
        'A target on the right is struck and bleeds red orbs; they hang a moment, then whip home as comet streaks and flood the caster crimson.',
    category: 'shadow',
    kind: AssetKind.effect,
    tags: [
      'shadow',
      'life-steal',
      'drain',
      'blood',
      'heal',
      'directional',
      'magic',
      'one-shot',
    ],
    size: (184, 100),
    origin: (36, 92),
    duration: 2.2,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#14040a',
        '#3a0a14',
        '#6a101c',
        '#a01824',
        '#d42a30',
        '#ff5a50',
        '#ff9a8a',
        '#ffe6de',
      ],
      'dark': '#2a1040',
      'seed': 11,
    },
  ),
  act: ActSpec(
    onBody: true,
    follow: 0,
    target: const TargetSpec(x: 104),
    poses: [
      const PoseKey(-0.46, kReady),
      PoseKey(-0.2, kReady.copyWith(crouch: 4, lean: -2, fx: 3, fy: -27, bx: 8, by: -20)),
      PoseKey(0, _grasp, PoseEase.snap),
      PoseKey(0.4, _grasp),
      PoseKey(0.7, _grasp.copyWith(fx: 13, fy: -26, lean: 1)),
      PoseKey(0.8, _fed.copyWith(crouch: 2), PoseEase.snap),
      const PoseKey(1.22, _fed),
      const PoseKey(
        1.7,
        Pose(
          turn: 1,
          crouch: 2,
          fx: -11,
          fy: -26,
          bx: 12,
          by: -26,
          ffx: -3,
          fbx: 4,
        ),
      ),
      const PoseKey(2.2, kReady),
    ],
    hits: const [
      HitSpec(
        t: 0.01,
        stop: 0.07,
        shake: 0.12,
        amp: 1,
        push: 1.6,
        straw: 12,
        skin: 'red',
        y: -24,
      ),
      HitSpec(t: 1.6, push: 0, straw: 0, flash: 0, clearSkin: true),
    ],
  ),
  onCreate: (o) => _LifeStealSim(o),
);
