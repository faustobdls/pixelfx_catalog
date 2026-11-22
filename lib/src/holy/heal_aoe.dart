import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'holy_lib.dart';

const double _sy = 0.2;
const double _seedTime = 0.3;
const double _roll = 1.0;

class _PlusSite {
  final double x;
  final double z;
  final double t0;
  final double rise;
  final double life;
  final double sway;
  final int l;
  final int thick;
  bool popped = false;

  _PlusSite({
    required this.x,
    required this.z,
    required this.t0,
    required this.rise,
    required this.life,
    required this.sway,
    required this.l,
    required this.thick,
  });
}

class _RingRider {
  final double a;
  final double w;

  const _RingRider(this.a, this.w);
}

class _HealAoeSim extends BaseEffectSim {
  final List<int> c;
  final double reach;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  late final List<_PlusSite> sites;
  late final List<_RingRider> riders;
  double t = 0.0;
  bool released = false;

  _HealAoeSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        reach = o.numOpt('reach', 104.0),
        r = Rng(o.seed) {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [kWhite, c[6], c[5], c[4]],
    );
    sites = List.generate(26, (i) {
      final a = r.range(0.0, tau);
      final d = reach * math.sqrt(r.range(0.04, 0.92));
      final big = i % 5 < 2;
      final t0 = _passed(d) + r.range(0.0, 0.06);
      final rise = r.range(18.0, 34.0);
      final life = r.range(0.9, 1.3);
      final sway = r.range(0.0, tau);
      return _PlusSite(
        x: math.cos(a) * d,
        z: math.sin(a) * d,
        t0: t0,
        rise: rise,
        life: life,
        sway: sway,
        l: big ? 3 + (i % 5 == 0 ? 1 : 0) : (i % 5 == 2 ? 1 : 2),
        thick: big ? 3 : 1,
      );
    }, growable: false);

    riders = List.generate(14, (i) {
      final a = (i / 14.0) * tau + r.range(-0.2, 0.2);
      final w = r.range(0.6, 1.1) * (i.isOdd ? 1 : -1);
      return _RingRider(a, w);
    }, growable: false);
  }

  double _front(double tt) =>
      tt < _seedTime ? 0.0 : reach * Ease.outCubic(seg(tt, _seedTime, _seedTime + _roll));

  double _passed(double d) {
    final rem = 1.0 - math.min(0.999, d / reach);
    return _seedTime + _roll * (1.0 - math.pow(rem, 1.0 / 3.0).toDouble());
  }

  void _wash(Painter p) {
    // The floor glows behind the front and fades after it.
    final fr = _front(t);
    if (fr < 2.0 || t > 2.6) return;
    p.shade(-fr - 1.0, -fr * _sy - 1.0, fr + 1.0, fr * _sy + 1.0, (x, y, out) {
      final d = hypot(x, y / _sy);
      if (d > fr) return null;
      final age = t - _passed(d);
      final k = math.exp(-age / 0.35) *
          smooth(fr, fr - 6.0, d) *
          (1.0 - smooth(1.4, 1.9, t));
      if (k < 0.04) return null;
      out.l = c[4];
      out.k = 0.32 * k;
      return null;
    });
  }

  void _ring(Painter p, bool back) {
    if (t < _seedTime) return;
    final u = seg(t, _seedTime, _seedTime + _roll + 0.25);
    final fr = _front(t);
    final k = u < 0.7 ? 1.0 : (1.0 - u) / 0.3;
    if (k <= 0.0) return;
    final keep = back ? farHalf : nearHalf;
    band(
      p,
      0.0,
      0.0,
      fr,
      _sy,
      math.max(2.0, 7.0 * (1.0 - u * 0.7)),
      k,
      c.sublist(2),
      keep: keep,
      hot: t < _seedTime + 0.08,
    );
    ovalShaded(
      p,
      0.0,
      0.0,
      fr + 1.0,
      (fr + 1.0) * _sy,
      color: (g) => math.sin(g) > 0.3 ? kWhite : c[6],
      alpha: (_) => k * (back ? 0.7 : 1.0),
      keep: keep,
    );

    // A crest of light blades flickers up along the front as it rolls.
    final n = (fr * 0.9).ceil();
    final tTick = (t * 20.0).floor();
    for (var j = 0; j < n; j++) {
      final g = (j / n) * tau;
      final near = math.sin(g) >= 0.0;
      if (near == back || rand(j, tTick) > 0.45) continue;
      final x = math.cos(g) * fr;
      final y = math.sin(g) * fr * _sy;
      final h = (1.0 + rand(j, 7) * 4.0) * k * (near ? 1.0 : 0.6);
      for (var i = 1; i <= h; i++) {
        p.dot(
          x,
          y - i,
          i > h - 1.0 ? kWhite : c[6],
          k * (1.2 - i / (h + 1.0)),
        );
      }
    }

    // Lights riding round the ring as it rolls.
    for (final rr in riders) {
      final g = rr.a + rr.w * (t - _seedTime) * 2.2;
      final near = math.sin(g) >= 0.0;
      if (near == back) continue;
      final x = math.cos(g) * fr;
      final y = math.sin(g) * fr * _sy;
      if (near) {
        sparkle(
          p,
          x,
          y - 1.0,
          2.0 + (math.sin(t * 9.0 + rr.a * 5.0) > 0.3 ? 1.0 : 0.0),
          kWhite,
          c[6],
          0.35 * k,
        );
      } else {
        p.dot(x, y, c[6], k);
      }
    }
    if (!back) {
      for (var i = 0; i < 8; i++) {
        final g = (i / 8.0) * tau;
        p.glow(math.cos(g) * fr, math.sin(g) * fr * _sy - 2.0, 16, c[4], 0.22 * k);
      }
    }
  }

  void _sprouts(Painter p, bool back) {
    for (final s in sites) {
      final a = t - s.t0;
      if (a < 0.0 || a > s.life || (s.z < 0.0) != back) continue;
      final u = a / s.life;
      final h = s.rise * Ease.outCubic(u);
      final x = s.x + math.sin(a * 4.0 + s.sway) * 1.5 * u;
      final y = s.z * _sy - 2.0 - h;
      final pop = Ease.outBack(clamp(a / 0.12), 2.6);
      final end = s.life - 0.15;
      final lVal = math.max(1, holyRound(s.l * pop - (back ? 1.0 : 0.0)));
      if (a < 0.04) {
        sparkle(p, x, y, 3, kWhite, c[6], 0.5);
      } else if (a < end) {
        plus(
          p,
          x,
          y,
          lVal,
          back && lVal < 3 ? 1 : s.thick,
          back ? c.sublist(0, 7) : c,
          back ? 0.8 : 1.0,
          !back && math.sin(a * 12.0 + s.sway * 3.0) > 0.8,
        );
      } else {
        final v = (a - end) / 0.15;
        for (final (dx, dy) in const [(1, 1), (1, -1), (-1, 1), (-1, -1)]) {
          p.dot(
            x + dx * (2.0 + v * 5.0),
            y + dy * (2.0 + v * 5.0) - v * 2.0,
            v < 0.4 ? kWhite : c[6],
            1.0 - v,
          );
        }
      }
      // A thread of light still ties it to the floor while it rises.
      if (u < 0.5) {
        for (var j = 1.0; j < h * (1.0 - u * 2.0); j += 1.5) {
          p.dot(
            s.x,
            s.z * _sy - 2.0 - h + j + 3.0,
            c[5],
            (1.0 - j / h) * (1.0 - u * 2.0) * (back ? 0.5 : 0.8),
          );
        }
      }
      p.glow(
        x,
        y,
        7.0 + lVal * 2.0,
        c[5],
        (back ? 0.2 : 0.34) * (a < end ? 1.0 : 1.0 - (a - end) / 0.15),
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    // The seed gathers: motes slide in over the floor to a point that brightens.
    if (t < _seedTime - 0.04 && r.chance(0.7)) {
      final a = r.range(0.0, tau);
      final d = r.range(24.0, 48.0);
      final x = math.cos(a) * d;
      final y = math.sin(a) * d * _sy - r.range(1.0, 8.0);
      final dur = r.range(0.16, 0.24);
      final lRaw = hypot(x, y + 3.0);
      final l = lRaw == 0.0 ? 1.0 : lRaw;
      final v = (l * 3.0) / (math.exp(3.0 * dur) - 1.0);
      final col = r.chance(0.5) ? c[6] : c[5];
      ps.spawn(P.streak, x, y, (-x / l) * v, ((-3.0 - y) / l) * v, dur, col);
    }
    if (!released && t >= _seedTime) {
      released = true;
      lights.add(0, -16, 76, c[5], 0.85, 0.55);
      lights.add(0, -6, 28, kWhite, 0.8, 0.12);
      for (var i = 0; i < 10; i++) {
        final px = r.range(-2.0, 2.0);
        final py = -r.range(2.0, 10.0);
        final vx = r.range(-25.0, 25.0);
        final vy = -r.range(80.0, 170.0);
        final life = r.range(0.3, 0.6);
        final col = r.chance(0.5) ? kWhite : c[6];
        final size = r.range(0.6, 1.0);
        ps.spawn(P.mote, px, py, vx, vy, life, col, size);
      }
      for (var i = 0; i < 16; i++) {
        final a = r.range(math.pi * 1.05, math.pi * 1.95);
        final sp = r.range(40.0, 120.0);
        final life = r.range(0.4, 0.8);
        final col = r.chance(0.5) ? kWhite : c[6];
        final size = r.range(0.6, 2.0);
        ps.spawn(P.star, 0.0, -3.0, math.cos(a) * sp, math.sin(a) * sp, life, col, size);
      }
    }
    for (final s in sites) {
      if (!s.popped && t >= s.t0) {
        s.popped = true;
        // A splash of dew where each one breaks the floor.
        for (var i = 0; i < 3; i++) {
          final sx = s.x + r.range(-3.0, 3.0);
          final vx = r.range(-10.0, 10.0);
          final vy = -r.range(15.0, 40.0);
          final life = r.range(0.3, 0.6);
          final col = r.chance(0.5) ? kWhite : c[6];
          final size = r.range(0.5, 1.2);
          ps.spawn(
            P.star,
            sx,
            s.z * _sy - 1.0,
            vx,
            vy,
            life,
            col,
            size,
            0.0,
            s.z < 0.0 ? PF.back : 0,
          );
        }
      }
    }
    // Dew rising off the glowing floor behind the ring.
    if (t > _seedTime + 0.1 && t < 1.9 && r.chance(0.35)) {
      final fr = _front(t);
      final a = r.range(0.0, tau);
      final d = fr * math.sqrt(r.next());
      final vx = r.range(-5.0, 5.0);
      final vy = -r.range(10.0, 30.0);
      final life = r.range(0.5, 1.0);
      ps.spawn(
        P.ember,
        math.cos(a) * d,
        math.sin(a) * d * _sy - 1.0,
        vx,
        vy,
        life,
        c[5],
        1.0,
        0.0,
        math.sin(a) < 0.0 ? PF.back : 0,
      );
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    _wash(p);
    _ring(p, true);
    _sprouts(p, true);
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    _ring(p, false);
    // The seed: a point of light pulsing on the floor, then a flare as it lets go.
    if (t < _seedTime) {
      final k = t / _seedTime;
      sparkle(p, 0, -3, 2.0 + 4.0 * k * k, kWhite, c[6], 0.3 + 0.4 * k);
      p.glow(0, -3, 10.0 + 16.0 * k, c[4], 0.5 * k);
    } else if (t < _seedTime + 0.2) {
      final u = (t - _seedTime) / 0.2;
      flare(p, 0, -3, 22.0 * math.pow(1.0 - u, 1.5).toDouble(), 1.0 - u, c.sublist(3));
    }
    // As it lets go, a jet of light leaps out of the floor, lets go of it and dissolves upward.
    final g = seg(t, _seedTime, _seedTime + 0.5);
    if (g > 0.0 && g < 1.0) {
      final top = -4.0 - 46.0 * Ease.outCubic(math.min(1.0, g * 2.2)) - 10.0 * g;
      final bot = -2.0 - 50.0 * Ease.inQuad(seg(g, 0.35, 1.0));
      final w = 1.0 + 2.4 * (1.0 - g);
      if (bot - top > 2.0) {
        p.beamShaded(
          0,
          bot,
          0,
          top,
          w * 2.0,
          color: (u, v) => v < 0.45 ? kWhite : (u > 0.8 ? c[5] : c[6]),
        );
        p.glowLine(0, bot, 0, top, 12, c[5], 0.55 * (1.0 - g));
        sparkle(p, 0, top, 4.0 * (1.0 - g) + 1.0, kWhite, c[6], 0.5 * (1.0 - g));
      }
    }
    _sprouts(p, false);
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect healAoeEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'holy/heal-aoe',
    name: 'Healing ring',
    desc:
        'A seed of green light sinks into the floor and a soft ring rolls out from it; the floor glows where it passes and plus signs sprout and float up.',
    category: 'holy',
    tags: ['holy', 'heal', 'aoe', 'ring', 'plus', 'ground', 'one-shot'],
    size: (256, 136),
    origin: (128, 104),
    duration: 2.9,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {'palette': kHolyGreen, 'reach': 104, 'seed': 6},
  ),
  onCreate: (o) => _HealAoeSim(o),
);
