import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'ice_lib.dart';

const double _duration = 3.2;
const double _pop = 0.16;
const double _cy = -48.0;
const List<int> _sizes = [2, 0, 1, 0, 2, 0, 1, 0, 1];

class _Flake {
  double x;
  double y;
  double vx;
  double vy;
  final double r;
  double rot;
  final double w0;
  final double w1;
  final FlakeDesign d;
  double life;
  double age = 0.0;
  final double ph;
  final double tw;
  final double tw0;
  bool rest = false;
  bool popped = false;

  _Flake({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.r,
    required this.rot,
    required this.w0,
    required this.w1,
    required this.d,
    required this.life,
    required this.ph,
    required this.tw,
    required this.tw0,
  });
}

class _SnowflakeBurstSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  final List<_Flake> flakes = [];

  double t = 0.0;
  bool popped = false;

  _SnowflakeBurstSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed) {
    final count = o.intOpt('count', 9);
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [c[7], c[6], c[5], c[4]],
      haze: c[5],
    );
    for (var i = 0; i < count; i++) {
      final z = _sizes[i % _sizes.length];
      final rad = z == 2
          ? r.range(9.5, 11.5)
          : (z == 1 ? r.range(6, 7.5) : r.range(3, 4.5));
      final a = (i / count) * tau + r.range(-0.3, 0.3) + 0.4;
      final sp = r.range(80, 120) * (1.4 - rad / 14.0);
      flakes.add(_Flake(
        x: 0.0,
        y: _cy,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp * 0.85 - 20.0,
        r: rad,
        rot: r.range(0, tau),
        w0: r.sign() * r.range(7, 12),
        w1: r.sign() * r.range(0.4, 1),
        d: flakeDesign(r),
        life: r.range(2.1, 2.8),
        ph: r.range(0, tau),
        tw: r.range(0.5, 0.85),
        tw0: r.range(0.15, 0.6),
      ));
    }
  }

  double _sz(_Flake f) =>
      f.r *
      math.min(1.0, Ease.outBack(clamp(f.age / 0.18), 2.0)) *
      math.min(1.0, (f.life - f.age) / 0.35);

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (t < _pop - 0.03 && r.chance(0.8)) {
      final a = r.range(0, tau);
      final d = r.range(22, 44);
      final dur = r.range(0.12, 0.16);
      final v = (d * 3.0) / (math.exp(3.0 * dur) - 1.0);
      ps.spawn(
        P.streak,
        math.cos(a) * d,
        _cy + math.sin(a) * d,
        -math.cos(a) * v,
        -math.sin(a) * v,
        dur,
        r.chance(0.5) ? c[6] : c[5],
      );
    }
    if (!popped && t >= _pop) {
      popped = true;
      lights.add(0, _cy, 44, kWhite, 0.8, 0.1);
      lights.add(0, _cy, 72, c[4], 0.5, 0.6);
      for (var i = 0; i < 22; i++) {
        final a = r.range(0, tau);
        final sp = r.range(80, 150);
        ps.spawn(P.mote, 0, _cy, math.cos(a) * sp, math.sin(a) * sp,
            r.range(0.25, 0.5), r.chance(0.5) ? c[6] : c[5], r.range(0.6, 1));
      }
      for (var i = 0; i < 18; i++) {
        final a = r.range(-math.pi, 0.2);
        final sp = r.range(30, 110);
        ps.spawn(
          P.flake,
          0,
          _cy,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(1, 1.6),
          r.chance(0.6) ? kWhite : c[6],
          r.range(0.5, 1.5),
        );
      }
      for (var i = 0; i < 12; i++) {
        final a = r.range(0, tau);
        final d = r.range(10, 44);
        ps.spawn(
          P.star,
          math.cos(a) * d,
          _cy + math.sin(a) * d * 0.85,
          0,
          r.range(2, 6),
          r.range(0.3, 0.6),
          r.chance(0.5) ? kWhite : c[6],
          r.range(0.8, 2.2),
          r.range(0.08, 1.6),
        );
      }
    }
    if (popped) {
      for (final f in flakes) {
        f.age += dt;
        if (f.age >= f.life) continue;
        if (!f.rest) {
          f.vx -= f.vx * 2.8 * dt;
          f.vy -= f.vy * 2.8 * dt - 26.0 * dt;
          f.x += f.vx * dt + math.sin(t * 1.8 + f.ph) * 5.0 * dt;
          f.y += f.vy * dt;
          f.rot += (f.w1 + (f.w0 - f.w1) * math.exp(-f.age * 2.5)) * dt;
          if (f.y > -_sz(f) * 0.3) {
            f.rest = true;
            f.y = -1.0;
            f.life = math.min(f.life, f.age + 0.6);
          }
        }
        if (!f.popped && f.life - f.age < 0.1) {
          f.popped = true;
          for (var i = 0; i < 2; i++) {
            ps.spawn(
              P.star,
              f.x + r.range(-2, 2),
              f.y + r.range(-2, 2),
              r.range(-6, 6),
              -r.range(2, 8),
              r.range(0.2, 0.4),
              r.chance(0.5) ? kWhite : c[6],
              r.range(0.8, 1.6),
            );
          }
        }
      }
    }
    ps.update(dt);
    lights.update(dt);
    endBy(t, _duration, ps: ps);
  }

  @override
  void draw(Painter p) {
    if (t < _pop) {
      final k = t / _pop;
      snowflake(p, 0, _cy, 1.0 + 3.2 * k * k, t * 20.0, flakes[0].d, c, hot: k);
      p.glow(0, _cy, 8.0 + 14.0 * k, c[5], 0.3 + 0.4 * k);
    }
    final q = t - _pop;
    if (q >= 0.0 && q < 0.4) {
      if (q < 0.07) p.circle(0, _cy, 6.0 * (1.0 - q / 0.07) + 1.0, kWhite);
      flare(
        p,
        0,
        _cy,
        28.0 * math.pow(math.max(0.0, 1.0 - q / 0.26), 1.5),
        1.0 - q / 0.26,
        c,
      );
      final e = Ease.outCubic(q / 0.4);
      final rad = 5.0 + 34.0 * e;
      p.ring(
        0,
        _cy,
        rad,
        math.max(1.0, 2.4 * (1.0 - e)),
        q < 0.08 ? kWhite : (q < 0.2 ? c[6] : c[5]),
        1.15 - e,
      );
      p.glowRing(0, _cy, rad, 5, c[5], 0.4 * (1.0 - e));
    }
    if (popped) {
      p.glow(0, _cy, 46, c[4], 0.3 * (1.0 - smooth(_pop, _pop + 1.6, t)));
    }
    for (final f in flakes) {
      if (!popped || f.age >= f.life) continue;
      final rad = _sz(f);
      final tw = math.pow(
            math.max(0.0, math.sin(((f.age - f.tw0) / f.tw) * tau)),
            8,
          ).toDouble() *
          (f.age > f.tw0 ? 1.0 : 0.0);
      if (f.rest) {
        final l = math.max(
          1,
          (rad * 1.2 * ((f.life - f.age) / 0.6) + 0.5).floor(),
        );
        for (var i = -l; i <= l; i++) {
          p.px(
            f.x + i,
            -1,
            i.abs() == l ? c[5] : (i == 0 ? kWhite : c[6]),
          );
        }
        p.glow(f.x, -1, 3 + l, c[4], 0.3);
        continue;
      }
      snowflake(
        p,
        f.x,
        f.y,
        rad,
        f.rot,
        f.d,
        c,
        hot: math.max(tw, 1.0 - clamp(f.age / 0.12)),
      );
      p.glow(f.x, f.y, 6.0 + rad * 1.4, c[4], 0.12);
      if (tw > 0.5) flare(p, f.x, f.y, (3.0 + rad * 0.7) * tw, tw, c);
    }
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect snowflakeBurstEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ice/snowflake-burst',
    name: 'Snowflake burst',
    desc:
        'A cold pop: frost gathers and flashes white in a ring, then crisp six-armed snowflakes spin out, slow, twinkle and drift down to settle and melt.',
    category: 'ice',
    tags: ['ice', 'snow', 'snowflake', 'burst', 'magic', 'one-shot'],
    size: (140, 120),
    origin: (70, 106),
    duration: _duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#151a3d', '#212f6b', '#2c58aa', '#3a8bd8',
        '#62c8f4', '#a6ecff', '#dcfbff', '#ffffff',
      ],
      'count': 9,
      'seed': 8,
    },
  ),
  onCreate: (o) => _SnowflakeBurstSim(o),
);
