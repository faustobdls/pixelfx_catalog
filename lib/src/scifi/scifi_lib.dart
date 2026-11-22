import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const double _step = 1.0 / 240.0;

const Set<ParticleKind> _softKinds = {
  P.vapour,
  P.dust,
  P.smoke,
};

class GhostSpec {
  final double born;
  final ParticleKind k;
  final double x;
  final double y;
  final double vx;
  final double vy;
  final double life;
  final int col;
  final double size;
  final int flag;
  final double seed;

  const GhostSpec({
    required this.born,
    required this.k,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.col,
    required this.size,
    required this.flag,
    required this.seed,
  });
}

class _GhostQ {
  ParticleKind k;
  double x;
  double y;
  double vx;
  double vy;
  double life;
  double max;
  int col;
  double size;
  final double seed;
  int flag;
  int hops = 0;

  _GhostQ({
    required this.k,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.max,
    required this.col,
    required this.size,
    required this.seed,
    required this.flag,
  });
}

void _move(
  _GhostQ q,
  double dt,
  double age,
  double Function(double x) ground,
) {
  switch (q.k) {
    case P.fire:
      q.vy -= 95.0 * dt;
      q.vx += math.sin(age * 17.0 + q.seed) * 30.0 * dt;
      q.vx -= q.vx * 5.0 * dt;
      q.vy -= q.vy * 3.2 * dt;
    case P.grit:
      q.vy += kGravity * dt;
      q.vx -= q.vx * 0.8 * dt;
      final g = ground(q.x);
      final ny = q.y + q.vy * dt;
      q.x += q.vx * dt;
      if (q.vy > 0.0 && q.y <= g && ny >= g) {
        q.y = g - 0.25;
        if (q.vy > 130.0 && rand((q.seed * 1000.0).toInt(), q.hops++) < 0.4) {
          q.vy = -q.vy * 0.25;
          q.vx = q.vx * 0.5;
        } else {
          q.vx = 0.0;
          q.vy = 0.0;
          q.life = math.min(q.life, 0.5);
        }
      } else {
        q.y = ny;
      }
      return;
    case P.spark:
      q.vy += kGravity * 0.45 * dt;
      q.vx -= q.vx * 2.2 * dt;
      q.vy -= q.vy * 2.2 * dt;
      final g = ground(q.x);
      final ny = q.y + q.vy * dt;
      q.x += q.vx * dt;
      if (q.vy > 0.0 && q.y <= g && ny >= g) {
        q.vy = -q.vy * 0.45;
        q.vx *= 0.7;
        q.y = g - 0.25;
      } else {
        q.y = ny;
      }
      return;
    case P.streak:
      q.vx += q.vx * 3.0 * dt;
      q.vy += q.vy * 3.0 * dt;
    case P.flake:
      q.vx -= q.vx * 2.2 * dt;
      q.vy -= q.vy * 2.2 * dt - 35.0 * dt;
      q.x += math.sin(age * 2.5 + q.seed) * 7.0 * dt;
    case P.ember:
      q.vy += (-30.0 + math.sin(age * 3.0 + q.seed) * 20.0) * dt;
      q.vx += math.cos(age * 2.3 + q.seed) * 45.0 * dt;
      q.vx -= q.vx * 1.6 * dt;
      q.vy -= q.vy * 1.6 * dt;
    case P.smoke:
      final big = (q.flag & PF.big) != 0;
      q.vy -= (big ? 23.0 : 16.0) * dt;
      q.vx += math.sin(age * 1.3 + q.seed) * 8.0 * dt;
      q.vx -= q.vx * 1.6 * dt;
      q.vy -= q.vy * 1.2 * dt;
    case P.mote:
      q.vx -= q.vx * 0.6 * dt;
      q.vy -= q.vy * 0.6 * dt;
    default:
      final drag = _softKinds.contains(q.k) ? 4.0 : 1.6;
      q.vx -= q.vx * drag * dt;
      q.vy -= q.vy * drag * dt + 5.0 * dt;
  }
  q.x += q.vx * dt;
  q.y += q.vy * dt;
}

/// Simulated particles for seamless loops: each particle is stepped forward
/// from its birth time so `at(t)` is a pure function of `t`.
class Ghosts {
  final double period;
  final double Function(double x) ground;
  final (double, double, double, double)? box;
  final Particles ps;
  final List<GhostSpec> specs = [];

  Ghosts(
    this.period, {
    double Function(double x)? ground,
    List<Object>? sparks,
    Object? haze,
    this.box,
  })  : ground = ground ?? ((_) => double.infinity),
        ps = Particles(
          ground: ground ?? ((_) => double.infinity),
          sparks: sparks,
          haze: haze,
        );

  void add(
    double born,
    ParticleKind k,
    double x,
    double y,
    double vx,
    double vy,
    double life, [
    Object? col = 0xffffffff,
    double size = 1.0,
    int flag = 0,
  ]) {
    final n = specs.length;
    var seed = rand(n, 41) * 100.0;
    if (k == P.star) {
      final m = ((8.0 * period) / tau).ceil();
      final f = (tau * m) / period - 8.0;
      if (f < 5.0) {
        seed = f + 5.0 * (rand(n, 43) * 19.0).floorToDouble();
      }
    }
    final resolvedCol =
        (col == null || (col is int && col == 0)) ? 0 : hex(col);
    specs.add(GhostSpec(
      born: ((born % period) + period) % period,
      k: k,
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      life: life,
      col: resolvedCol,
      size: size,
      flag: flag,
      seed: seed,
    ));
  }

  int get count => specs.length;

  SimParticle? state(GhostSpec s, double age) {
    final q = _GhostQ(
      k: s.k,
      x: s.x,
      y: s.y,
      vx: s.vx,
      vy: s.vy,
      life: s.life,
      max: s.life,
      col: s.col,
      size: s.size,
      seed: s.seed,
      flag: s.flag,
    );
    var a = 0.0;
    while (a < age - 1e-9) {
      final dt = math.min(_step, age - a);
      _move(q, dt, a, ground);
      a += dt;
      q.life -= dt;
      if (q.life <= 0.0) {
        if (q.k != P.fire || (q.flag & PF.smokes) == 0) return null;
        final big = (q.flag & PF.big) != 0;
        final l = big
            ? 1.3 + rand((s.seed * 7.0).toInt(), 1)
            : 0.8 + rand((s.seed * 7.0).toInt(), 1) * 0.6;
        q.k = P.smoke;
        q.vx = q.vx * 0.6;
        q.vy = q.vy * 0.6 - 6.0;
        q.life = l;
        q.max = l;
        q.col = 0;
        q.size = q.size * (big ? 0.85 : 0.7);
        q.flag = big ? PF.big : 0;
      }
    }
    final b = box;
    if (b != null) {
      final (x0, y0, x1, y1) = b;
      if (q.x < x0 || q.x > x1 || q.y < y0 || q.y > y1) return null;
    }
    return SimParticle(
      k: q.k,
      x: q.x,
      y: q.y,
      vx: q.vx,
      vy: q.vy,
      life: q.life,
      max: q.max,
      col: q.col,
      size: q.size,
      seed: q.seed,
      delay: 0.0,
      flag: q.flag,
    );
  }

  Particles at(double t) {
    ps.list.clear();
    for (final s in specs) {
      final span =
          s.k == P.fire && (s.flag & PF.smokes) != 0 ? s.life + 2.4 : s.life;
      for (var age = (((t - s.born) % period) + period) % period;
          age < span;
          age += period) {
        final q = state(s, age);
        if (q != null) ps.list.add(q);
      }
    }
    ps.t = t;
    return ps;
  }
}

/// A light that flares at [t0] and dies over [life].
void flash(
  Painter p,
  double t,
  double t0,
  double x,
  double y,
  double r,
  int c,
  double k,
  double life,
) {
  final a = t - t0;
  if (a < 0.0 || a >= life) return;
  final q = 1.0 - a / life;
  p.glow(x, y, r * (0.55 + 0.45 * q), c, k * q * q);
}

/// Smallest positive age of an event at [t0] in a loop of period [period], seen at [t].
double since(double t, double t0, double period) =>
    (((t - t0) % period) + period) % period;

/// Strokes an electric arc along [pts] with halo, body, white-hot core, and glow.
void strokeArc(
  Painter p,
  List<Point2> pts,
  List<int> c, [
  double k = 1.0,
  double w = 1.0,
]) {
  final halo = c[0];
  final body = c[1];
  final glow = c[2];
  for (var pass = 0; pass < 3; pass++) {
    for (var i = 1; i < pts.length; i++) {
      final (ax, ay) = pts[i - 1];
      final (bx, by) = pts[i];
      final len = math.max(1.0, hypot(bx - ax, by - ay));
      for (var d = 0.0; d <= len; d += 0.5) {
        final x = ax + ((bx - ax) * d) / len;
        final y = ay + ((by - ay) * d) / len;
        if (pass == 0) {
          p.circle(x, y, (k > 0.6 ? 1.6 : 1.1) * w, halo);
        } else if (pass == 1) {
          p.circle(x, y, (k > 0.6 ? 0.9 : 0.6) * w, body);
        } else if (k > 0.3) {
          p.px(x, y, kWhite);
        }
      }
      if (pass == 0 && i % 3 == 0) {
        p.glow(ax, ay, 9.0 * w, glow, 0.45 * k);
      }
    }
  }
}
