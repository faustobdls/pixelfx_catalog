import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'impacts_lib.dart';

const Pose _fall = Pose(
  turn: 0.8,
  y: -46.0,
  crouch: -1.0,
  lean: -1.0,
  fx: -9.0,
  fy: -42.0,
  bx: 10.0,
  by: -42.0,
  ffx: 6.0,
  ffy: -8.0,
  fbx: -3.0,
  fby: -3.0,
  toeB: true,
  ghost: 1,
);

const Pose _hero = Pose(
  y: 0.0,
  crouch: 8.0,
  lean: 5.0,
  fx: 13.0,
  fy: -8.0,
  bx: -6.0,
  by: -23.0,
  ffx: 11.0,
  fbx: -10.0,
);

final SimulatedEffect heavyLandingEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'impacts/heavy-landing',
    name: 'Heavy landing',
    desc:
        'A character lands hard: the floor dents and cracks under their feet, two rings of dust roll out along the floor one after the other, and pebbles hop away.',
    category: 'impacts',
    tags: [
      'impact',
      'landing',
      'ground',
      'stomp',
      'dust',
      'rocks',
      'actor',
      'one-shot',
    ],
    size: (176, 80),
    origin: (88, 60),
    duration: 1.6,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#1c1a24',
        '#2f2a3a',
        '#4a4258',
        '#6b6280',
        '#9088a4',
        '#bdb6cc',
        '#e6e1ee',
      ],
      'stone': '#4a3f69',
      'seed': 14,
    },
  ),
  act: ActSpec(
    poses: [
      const PoseKey(-0.26, _fall),
      PoseKey(-0.01, _fall.copyWith(y: -6.0), PoseEase.inEase),
      const PoseKey(0.0, _hero, PoseEase.snap),
      PoseKey(0.55, _hero.copyWith(crouch: 7.0)),
      PoseKey(
        0.95,
        _hero.copyWith(
          crouch: 5.0,
          lean: 3.0,
          fx: 13.0,
          fy: -15.0,
          bx: -5.0,
          by: -20.0,
        ),
      ),
      const PoseKey(1.3, kReady),
      const PoseKey(1.6, kReady),
    ],
    hits: const [HitSpec(t: 0.005, stop: 0.13, shake: 0.32, amp: 3.0)],
  ),
  onCreate: (o) => _HeavyLandingSim(o),
);

void _dent(Painter p, StonePalette st, double k) {
  for (var x = -10; x <= 9; x++) {
    final q = (x + 0.5).abs() / 10.0;
    final dep = (1.8 * (1.0 - q * q) + 0.5).floor();
    if (q < 0.82) {
      for (var y = 0; y < dep; y++) {
        p.dot(x, y, kSoot, k);
      }
      p.dot(x, dep, st.lip, k);
    } else {
      p.dot(x, -1, q > 0.92 ? st.light : st.lip, k);
    }
  }
}

class _HeavyLandingSim extends BaseEffectSim {
  static double _floor(double _) => 0.0;

  final List<int> c;
  final StonePalette st;
  final Rng r;
  final double duration = 1.6;
  late final Particles back;
  late final Particles front;
  final Bits bits = Bits(ground: _floor);
  late final List<CrackLine> cracks;
  late final int dust;
  late final int lit;
  late final double ph;
  final Map<DebrisBit, List<double>> rockPts = {};
  final Map<DebrisBit, double> pvy = {};
  double t = 0.0;

  _HeavyLandingSim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        st = stone(o['stone'] ?? '#4a3f69'),
        r = Rng(o.seed) {
    back = Particles(rng: r, ground: _floor);
    front = Particles(rng: r, ground: _floor);
    cracks = makeCracks(
      r,
      6,
      len: (8.0, 20.0),
      dive: 0.7,
      maxY: 12.0,
      forks: 0.4,
      x0: (2.0, 6.0),
    );
    dust = mix(st.dust, c[5], 0.4);
    lit = mix(dust, kWhite, 0.3);
    ph = r.range(0.0, tau);

    void ring(
      int n,
      double v0,
      double v1,
      (double, double) size,
      double delay,
    ) {
      for (var i = 0; i < n; i++) {
        final g = (i / n) * tau + r.range(-0.1, 0.1);
        final v = r.range(v0, v1);
        final far = math.sin(g) < 0.0;
        (far ? back : front).spawn(
          P.dust,
          math.cos(g) * 4.0,
          math.sin(g) * 0.7 - 1.0,
          math.cos(g) * v,
          math.sin(g) * v * 0.16 - r.range(2.0, 10.0),
          r.range(0.45, 0.8),
          r.chance(0.45) ? lit : dust,
          r.range(size.$1, size.$2),
          delay + r.range(0.0, 0.03),
        );
      }
    }

    ring(20, 140.0, 190.0, (2.2, 3.4), 0.01);
    ring(18, 70.0, 110.0, (3.4, 5.4), 0.12);

    for (var i = 0; i < 12; i++) {
      final s = r.sign();
      final up = i < 6;
      (i.isOdd ? front : back).spawn(
        P.dust,
        s * r.range(2.0, 10.0),
        -r.range(1.0, 4.0),
        s * r.range(10.0, 35.0) * (up ? 0.6 : 1.0),
        -(up ? r.range(25.0, 60.0) : r.range(4.0, 12.0)),
        r.range(0.55, 0.9),
        r.chance(0.5) ? lit : dust,
        r.range(3.0, 5.0),
        r.range(0.02, 0.1),
      );
    }

    for (var i = 0; i < 12; i++) {
      final s = r.sign();
      final v = r.range(50.0, 130.0);
      final bit = DebrisBit(
        kind: B.chunk,
        x: s * r.range(3.0, 8.0),
        y: -1.0,
        vx: s * v,
        vy: -r.range(140.0, 230.0),
        g: 1.0,
        drag: 0.5,
        bounce: 0.55,
        life: r.range(1.0, 1.45),
        a: r.range(0.0, tau),
        va: s * r.range(8.0, 16.0),
        s: r.chance(0.3) ? 2.0 : 1.0,
      );
      bits.add(bit);
      rockPts[bit] = rockShape(r);
      pvy[bit] = 0.0;
    }

    for (var i = 0; i < 24; i++) {
      final s = r.sign();
      final a = -math.pi / 2.0 + s * r.range(0.3, 1.2);
      final v = r.range(60.0, 170.0);
      front.spawn(
        P.grit,
        s * r.range(2.0, 7.0),
        -1.0,
        math.cos(a) * v,
        math.sin(a) * v,
        r.range(0.6, 1.1),
        r.pick([st.light, st.body, st.lip]),
        r.chance(0.3) ? 2.0 : 1.0,
      );
    }
  }

  void _rings(Painter p, bool far) {
    const specs = [
      (0.01, 0.45, 58.0, 4.5, 0.75, true),
      (0.12, 0.85, 42.0, 6.0, 0.8, false),
    ];
    for (final (t0, dur, r1, w, k0, edge) in specs) {
      final g = (t - t0) / dur;
      if (g <= 0.0 || g >= 1.0) continue;
      final rad = 6.0 + r1 * Ease.outCubic(g);
      dustRing(
        p,
        0.0,
        0.0,
        rad,
        w * (1.0 + g),
        k0 * math.pow(1.0 - g, 1.2).toDouble() * math.min(1.0, g / 0.06),
        dust,
        sy: 0.2,
        ph: ph + t0 * 10.0,
        brk: g * 0.8,
        half: far ? -1 : 1,
      );
      if (edge && g < 0.75) {
        band(
          p,
          0.0,
          0.5,
          rad + 2.0,
          0.2,
          math.max(1.0, 2.5 * (1.0 - g)),
          1.1 - g / 0.75,
          [st.body, st.light, lit, kWhite],
          keep: (a) => (math.sin(a) < 0.0) == far,
        );
      }
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    for (final b in bits.list) {
      pvy[b] = b.vy;
    }
    bits.update(dt);
    for (final b in bits.list) {
      if ((pvy[b] ?? 0.0) > 80.0 && b.vy <= 0.0) {
        front.spawn(
          P.dust,
          b.x,
          -0.5,
          r.sign() * r.range(6.0, 20.0),
          -r.range(2.0, 10.0),
          r.range(0.25, 0.45),
          dust,
          r.range(1.0, 1.8),
        );
        pvy[b] = 0.0;
      }
    }
    back.update(dt);
    front.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final fade = 1.0 - smooth(duration - 0.5, duration - 0.1, t);
    _dent(p, st, fade);
    drawCracks(
      p,
      cracks,
      (cr) => cr.len * Ease.outCubic(clamp((t - cr.t0) / 0.08)),
      (_) => 0.0,
      [kWhite, kWhite, kWhite, kWhite],
      kSoot,
      st.light,
      fade,
    );
    _rings(p, true);
    back.draw(p);
  }

  @override
  void draw(Painter p) {
    _rings(p, false);
    front.draw(p);
    for (final b in bits.list) {
      rock(p, b, rockPts[b]!, st);
    }
    if (t < 0.035) {
      p.ellipseShaded(
        0.0,
        0.0,
        15.0,
        2.5,
        color: (d, _) => d < 0.55 ? kWhite : c[6],
      );
    } else if (t < 0.07) {
      for (var x = -22; x <= 22; x++) {
        p.dot(x, 0, x.abs() < 10 ? kWhite : c[5], 1.0 - x.abs() / 24.0);
      }
    }
    if (t < 0.12) {
      p.glowLine(-20.0, 0.0, 20.0, 0.0, 8.0, c[6], 0.45 * (1.0 - t / 0.12));
    }
  }
}
