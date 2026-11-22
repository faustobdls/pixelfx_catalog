import 'dart:math' as math;
import 'package:pixelfx_core/pixelfx_core.dart';
import 'shadow_lib.dart';

const double _cy = -50;
const double _ro = 28;
const double _ri = 22;
const double _rc = 6;
const double _glyph = 1.62;
const double _flare = 2.6;
const double _break = 2.74;

class _StrokePt {
  const _StrokePt(this.x, this.y, this.t);
  final double x;
  final double y;
  final double t;
}

({List<_StrokePt> pts, double end}) _strokes() {
  final paths = <List<(double, double)>>[];
  List<(double, double)> circle(double r, double a0, [int n = 0]) {
    final count = n != 0 ? n : (r * tau).ceil();
    return List.generate(count + 1, (i) {
      final a = a0 + (i / count) * tau;
      return (math.cos(a) * r, _cy + math.sin(a) * r);
    });
  }

  paths.add(circle(_ro, -math.pi / 2));
  final star = <(double, double)>[];
  for (int i = 0; i <= 7; i++) {
    final a = -math.pi / 2 + ((i * 3) % 7) * (tau / 7);
    star.add((math.cos(a) * _ri, _cy + math.sin(a) * _ri));
  }
  paths.add(star);
  paths.add(circle(_ri, -math.pi / 2));
  paths.add(circle(_rc, math.pi / 2));
  paths.add([
    (0, _cy - 3.5),
    (2, _cy),
    (0, _cy + 3.5),
    (-2, _cy),
    (0, _cy - 3.5),
  ]);

  final pts = <_StrokePt>[];
  const speeds = [420.0, 700.0, 550.0, 380.0, 300.0];
  double t = 0.12;
  for (int k = 0; k < paths.length; k++) {
    final path = paths[k];
    for (int i = 1; i < path.length; i++) {
      final (x0, y0) = path[i - 1];
      final (x1, y1) = path[i];
      final L = hypot(x1 - x0, y1 - y0);
      for (double d = 0; d < L; d += 0.5) {
        pts.add(_StrokePt(
          x0 + ((x1 - x0) * d) / L,
          y0 + ((y1 - y0) * d) / L,
          t + d / speeds[k],
        ));
      }
      t += L / speeds[k];
    }
    t += 0.04;
  }
  return (pts: pts, end: t);
}

class _Glyph {
  _Glyph(this.x, this.y, this.segs, this.t);
  final double x;
  final double y;
  final List<((int, int), (int, int))> segs;
  final double t;
  bool popped = false;
}

List<_Glyph> _glyphs(int seed) {
  return List.generate(7, (i) {
    final r = rng(seed, i, 31);
    final segs = <((int, int), (int, int))>[((1, 0), (1, 2))];
    final extra = 2 + (r.next() < 0.5 ? 1 : 0);
    for (int k = 0; k < extra; k++) {
      final ax = r.intRange(0, 2);
      final ay = r.intRange(0, 2);
      final bx = math.max(0, math.min(2, ax + r.intRange(-1, 1)));
      final by = math.max(0, math.min(2, ay + r.intRange(-1, 1)));
      if (ax != bx || ay != by) segs.add(((ax, ay), (bx, by)));
    }
    final ang = -math.pi / 2 + (i * tau) / 7 + math.pi / 7;
    const rr = (_ro + _ri) / 2;
    return _Glyph(
      math.cos(ang) * rr,
      _cy + math.sin(ang) * rr,
      segs,
      _glyph + i * 0.07,
    );
  });
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

class _HexSigilSim extends BaseEffectSim {
  _HexSigilSim(Map<String, Object?> o)
      : C = fit(o.palette, 8),
        R = Rng(o.seed),
        S = _strokes(),
        G = _glyphs(o.seed) {
    ps = Particles(
      rng: R,
      ground: (_) => 0,
      sparks: [kWhite, C[7], C[6], C[5]],
    );
    embers = Particles(
      rng: R,
      ground: (_) => 0,
      sparks: [C[7], C[6], C[5], C[4]],
    );
    puffs = Puffs(
      rng: R,
      flame: [kWhite, C[7], C[6], C[5], C[4], C[3], C[2], C[1], C[0]],
      soot: [mix(C[3], C[2], 0.5), mix(C[2], C[1], 0.5)],
      cap: mix(C[4], C[2], 0.5),
      rim: [C[6], C[5], C[4]],
      floor: (_) => 0,
    );
  }

  final List<int> C;
  final Rng R;
  final ({List<_StrokePt> pts, double end}) S;
  final List<_Glyph> G;
  late final Particles ps;
  late final Particles embers;
  late final Puffs puffs;
  final Bits bits = Bits(ground: (_) => 0);
  final List<_Light> lights = [];

  double t = 0;
  int pi = 0;
  bool flared = false;
  bool broke = false;

  _StrokePt _pen() => S.pts[math.min(S.pts.length - 1, pi)];

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    while (pi < S.pts.length - 1 && S.pts[pi + 1].t <= t) {
      pi++;
    }
    if (t > 0.12 && t < S.end) {
      final q = _pen();
      if (R.chance(dt * 70)) {
        ps.spawn(
          ParticleKind.spark,
          q.x,
          q.y,
          R.range(-70, 70),
          R.range(-100, 20),
          R.range(0.12, 0.35),
        );
      }
      if (R.chance(dt * 10)) {
        embers.spawn(
          ParticleKind.ember,
          q.x,
          q.y,
          R.range(-12, 12),
          R.range(5, 25),
          R.range(0.5, 0.9),
        );
      }
    }
    if (t > 0.2 && t < _flare - 0.05 && R.chance(dt * (8 + 14 * smooth(0.2, _flare, t)))) {
      final a = R.range(0, tau);
      final d0 = R.range(40, 60);
      final T = R.range(0.22, 0.32);
      final v = (d0 * 3) / (math.exp(3 * T) - 1);
      ps.spawn(
        ParticleKind.streak,
        math.cos(a) * d0,
        _cy + math.sin(a) * d0,
        -math.cos(a) * v,
        -math.sin(a) * v,
        T,
        R.chance(0.5) ? C[7] : C[6],
      );
    }
    for (final g in G) {
      if (!g.popped && t >= g.t) {
        g.popped = true;
        lights.add(_Light(g.x, g.y, 14, 0.7, 0.2));
        for (int i = 0; i < 4; i++) {
          ps.spawn(
            ParticleKind.spark,
            g.x,
            g.y,
            R.range(-60, 60),
            R.range(-70, 20),
            R.range(0.1, 0.25),
          );
        }
      }
    }
    if (t >= _flare && !flared) {
      flared = true;
      lights.add(_Light(0, _cy, 96, 1.4, 0.45));
      lights.add(_Light(0, _cy, 44, 1.0, 0.14));
      for (int i = 0; i < 24; i++) {
        final a = R.range(0, tau);
        final sp = R.range(60, 130);
        ps.spawn(
          ParticleKind.spark,
          math.cos(a) * 13,
          _cy + math.sin(a) * 13,
          math.cos(a) * sp,
          math.sin(a) * sp - 30,
          R.range(0.2, 0.45),
        );
      }
    }
    if (t >= _break && !broke) {
      broke = true;
      for (int i = 0; i < S.pts.length - 1; i += 7) {
        final q = S.pts[i];
        final n = S.pts[i + 1];
        final a = math.atan2(n.y - q.y, n.x - q.x);
        bits.add(DebrisBit(
          kind: DebrisKind.shard,
          x: q.x,
          y: q.y,
          vx: R.range(-8, 8),
          vy: R.range(-12, 6),
          g: R.range(0.22, 0.45),
          drag: 0.6,
          bounce: 0.25,
          life: R.range(0.8, 1.2),
          a: a,
          va: R.range(-3, 3),
          s: R.range(2.5, 3.5),
          c: R.pick([C[7], C[6], C[6], C[5]]),
        ));
        if (i % 27 == 0) {
          embers.spawn(
            ParticleKind.ember,
            q.x,
            q.y,
            R.range(-10, 10),
            -R.range(10, 40),
            R.range(0.6, 1.1),
          );
        }
      }
      for (final g in G) {
        puffs.spawn(
          PuffKind.soot,
          g.x,
          g.y,
          R.range(-6, 6),
          -R.range(8, 18),
          R.range(0.7, 1.1),
          R.range(3, 5),
        );
      }
      for (int i = 0; i < 8; i++) {
        puffs.spawn(
          PuffKind.soot,
          R.range(-20, 20),
          _cy + R.range(-20, 20),
          R.range(-8, 8),
          -R.range(6, 16),
          R.range(0.8, 1.2),
          R.range(3, 6),
          R.range(0, 0.15),
        );
      }
    }
    for (int i = lights.length - 1; i >= 0; i--) {
      if ((lights[i].life -= dt) <= 0) lights.removeAt(i);
    }
    bits.update(dt);
    ps.update(dt);
    embers.update(dt);
    puffs.update(dt);
  }

  @override
  void drawBack(Painter p) {
    puffs.draw(p, PuffKind.soot, PuffLight(x: 0, y: _cy, k: broke ? 0.3 : 0.0, reach: 50));
    final k = t < _break ? smooth(0.1, 0.6, t) : 1 - smooth(_break, _break + 0.6, t);
    if (k > 0) p.glow(0, _cy, 52, C[4], 0.3 * k);
  }

  @override
  void draw(Painter p) {
    if (!broke) {
      final hold = t > S.end ? 0.5 + 0.5 * math.sin((t - S.end) * 9) : 0.0;
      final white = t >= _flare;
      for (final q in S.pts) {
        if (q.t > t) break;
        final age = t - q.t;
        p.px(
          q.x,
          q.y,
          white
              ? kWhite
              : age < 0.05
                  ? kWhite
                  : age < 0.15
                      ? C[7]
                      : age < 0.35
                          ? C[6]
                          : hold > 0.75
                              ? C[6]
                              : C[5],
        );
      }
      if (white) {
        for (final q in S.pts) {
          if ((q.x * 2).toInt() % 3 == 0) p.light(q.x, q.y, C[6], 0.5);
        }
      }
      for (final g in G) {
        if (t < g.t) continue;
        final age = t - g.t;
        final col = white || age < 0.06
            ? kWhite
            : age < 0.2
                ? C[7]
                : hold > 0.75
                    ? C[7]
                    : C[6];
        for (final (a, b) in g.segs) {
          p.line(
            g.x - 2 + a.$1 * 2,
            g.y - 2 + a.$2 * 2,
            g.x - 2 + b.$1 * 2,
            g.y - 2 + b.$2 * 2,
            col,
          );
        }
        if (age < 0.18) {
          ringFast(
            p,
            g.x,
            g.y,
            2 + 4 * (age / 0.18),
            1,
            age < 0.09 ? C[7] : C[5],
          );
        }
        p.glow(g.x, g.y, 6, C[5], 0.25);
      }
      if (t > 0.12 && t < S.end + 0.05) {
        final q = _pen();
        sparkle(p, q.x, q.y, 3 + math.sin(t * 60), C[7], C[6], 0.6);
        p.glow(q.x, q.y, 16, C[6], 0.55);
      }
    }
    final fu = (t - _flare) / 0.35;
    final bu = (t - _flare) / 0.22;
    if (bu > 0 && bu < 1) {
      sparkle(p, 0, _cy, 18 * (1 - bu), C[7], C[5], 0.9 * (1 - bu));
    }
    if (fu > 0 && fu < 1) {
      ringFast(
        p,
        0,
        _cy,
        _ro + 3 + 12 * Ease.outCubic(fu),
        math.max(1.0, 3 * (1 - fu)),
        fu < 0.4 ? kWhite : fu < 0.7 ? C[6] : C[4],
      );
    }
    bits.draw(p);
    puffs.draw(p, PuffKind.flame);
    ps.draw(p);
    embers.draw(p);
    for (final l in lights) {
      final q = l.life / l.max;
      p.glow(
        l.x,
        l.y,
        l.r * (0.6 + 0.4 * q),
        l.k > 1 ? C[5] : C[6],
        l.k * q * q,
      );
    }
  }
}

final PixelEffect hexSigilEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'shadow/hex-sigil',
    name: 'Hex sigil',
    desc:
        'A burning pen traces a cursed sigil in the air, its glyphs pop in one by one, then it flares white and crumbles into falling embers.',
    category: 'shadow',
    kind: AssetKind.effect,
    tags: [
      'shadow',
      'hex',
      'sigil',
      'rune',
      'curse',
      'magic',
      'circle',
      'one-shot',
    ],
    size: (168, 128),
    origin: (84, 112),
    duration: 4.2,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {'palette': kVoidPalette, 'seed': 7},
  ),
  onCreate: (o) => _HexSigilSim(o),
);
