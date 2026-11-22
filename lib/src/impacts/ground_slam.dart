import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart' hide star;

import 'impacts_lib.dart';

final SimulatedEffect groundSlamEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'impacts/ground-slam',
    name: 'Ground slam',
    desc:
        'Something lands hard: the floor flashes and cracks, two crescent shock waves race out along it, a dust wave and a tall dust cloud rise, rocks erupt, bounce and settle.',
    category: 'impacts',
    tags: [
      'impact',
      'ground',
      'slam',
      'shockwave',
      'quake',
      'rocks',
      'dust',
      'one-shot',
    ],
    size: (288, 208),
    origin: (144, 164),
    duration: 3.2,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#2a1712',
        '#5e2c1c',
        '#a4502a',
        '#e8893a',
        '#ffc764',
        '#fff0b4',
        '#ffffff',
      ],
      'stone': '#4a3f69',
      'reach': 104,
      'seed': 5,
    },
  ),
  onCreate: (o) => _GroundSlamSim(o),
);

const double _wave = 0.6;

void _crater(Painter p, StonePalette st, double hot, List<int> c, double k) {
  for (var x = -12; x <= 11; x++) {
    final q = (x + 0.5).abs() / 12.0;
    final dep = (2.6 * (1.0 - q * q) + 0.5).floor();
    if (q < 0.84) {
      for (var y = 0; y < dep; y++) {
        p.dot(x, y, kSoot, k);
      }
      p.dot(x, dep, hot > 0.5 ? c[5] : (hot > 0.2 ? c[4] : st.lip), k);
    } else {
      p.dot(x, -1, q > 0.93 ? st.light : st.lip, k);
      if (q < 0.9) p.dot(x, -2, st.light, k * 0.8);
    }
  }
}

class _Ember {
  final double x;
  final double y;
  final double d;
  final double life;
  final double ph;

  const _Ember({
    required this.x,
    required this.y,
    required this.d,
    required this.life,
    required this.ph,
  });
}

class _GroundSlamSim extends BaseEffectSim {
  static double _floor(double _) => 0.0;

  final List<int> c;
  final StonePalette st;
  final double reach;
  final Rng r;
  final double duration = 3.2;
  late final Particles ps;
  final Bits bits = Bits(ground: _floor);
  final Lights lights = Lights();
  late final List<int> hot;
  late final int dustLit;
  late final List<CrackLine> cracks;
  late final List<ImpactSpike> burst;
  final List<_Ember> embers = [];
  final Map<DebrisBit, List<double>> rockPts = {};
  final Map<DebrisBit, double> pvy = {};
  final List<double> acc = [];
  double t = 0.0;

  _GroundSlamSim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        st = stone(o['stone'] ?? '#4a3f69'),
        reach = o.numOpt('reach', 104.0),
        r = Rng(o.seed) {
    ps = Particles(rng: r, ground: _floor, sparks: [c[6], c[5], c[4], c[3]]);
    hot = [kWhite, c[5], c[4], c[3]];
    dustLit = mix(st.dust, kWhite, 0.2);
    cracks = makeCracks(
      r,
      10,
      len: (22.0, 58.0),
      dive: 0.55,
      maxY: 22.0,
      forks: 0.7,
      x0: (2.0, 9.0),
    );
    burst = [
      ImpactSpike(a: -0.07, len: r.range(34.0, 40.0), w: 1.9),
      ImpactSpike(a: math.pi + 0.07, len: r.range(34.0, 40.0), w: 1.9),
      ImpactSpike(
        a: -0.42 + r.range(-0.08, 0.08),
        len: r.range(15.0, 20.0),
        w: 1.5,
      ),
      ImpactSpike(
        a: -math.pi + 0.42 + r.range(-0.08, 0.08),
        len: r.range(15.0, 20.0),
        w: 1.5,
      ),
      ImpactSpike(
        a: -math.pi / 2.0 + r.range(-0.15, 0.15),
        len: r.range(18.0, 24.0),
        w: 1.7,
      ),
      ImpactSpike(
        a: -1.05 + r.range(-0.1, 0.1),
        len: r.range(10.0, 14.0),
        w: 1.2,
      ),
      ImpactSpike(
        a: -math.pi + 1.05 + r.range(-0.1, 0.1),
        len: r.range(10.0, 14.0),
        w: 1.2,
      ),
    ];

    for (final cr in cracks) {
      for (final pt in cr.pts) {
        if (pt.d > 3.0 && pt.d < 32.0 && r.chance(0.25)) {
          embers.add(
            _Ember(
              x: pt.x,
              y: pt.y,
              d: pt.d,
              life: r.range(0.8, 2.2),
              ph: r.range(0.0, tau),
            ),
          );
        }
      }
    }

    lights.add(0.0, -12.0, 96.0, c[4], 0.6, 0.6);
    lights.add(0.0, -4.0, 50.0, kWhite, 0.9, 0.14);

    for (var i = 0; i < 56; i++) {
      final low = i < 14;
      final s = r.sign();
      final a = low
          ? (s > 0 ? -r.range(0.04, 0.6) : math.pi + r.range(0.04, 0.6))
          : -math.pi / 2.0 + r.range(-1.15, 1.15);
      final sp = low ? r.range(150.0, 380.0) : r.range(200.0, 500.0);
      ps.spawn(
        P.spark,
        r.range(-4.0, 4.0),
        -1.0,
        math.cos(a) * sp,
        math.sin(a) * sp,
        low ? r.range(0.2, 0.5) : r.range(0.25, 0.65),
        kWhite,
        1.0,
        low ? 0.0 : r.range(0.0, 0.05),
      );
    }

    for (var i = 0; i < 20; i++) {
      final s = i < 3 ? 4 : r.intRange(1, 3);
      final a = -math.pi / 2.0 + r.range(-0.5, 0.5);
      final sp = s > 3
          ? r.range(110.0, 190.0)
          : r.range(170.0, 380.0) * (s > 2 ? 0.8 : 1.0);
      final bit = DebrisBit(
        kind: B.chunk,
        x: r.range(-7.0, 7.0),
        y: -2.0,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp,
        g: 1.0,
        drag: 0.4,
        bounce: 0.38,
        life: r.range(1.9, 2.7),
        a: r.range(0.0, tau),
        va: r.range(-14.0, 14.0),
        s: s.toDouble(),
      );
      bits.add(bit);
      rockPts[bit] = rockShape(r);
      pvy[bit] = 0.0;
    }

    for (var i = 0; i < 110; i++) {
      final u = r.range(-1.0, 1.0);
      final a = -math.pi / 2.0 + u * 0.65;
      final sp = r.range(110.0, 380.0) * (1.0 - 0.35 * u.abs());
      ps.spawn(
        P.grit,
        u * 6.0,
        -1.0,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(1.0, 2.2),
        r.pick([st.light, st.body, st.body, st.shade, st.shade, st.lip]),
        r.chance(0.35) ? 2.0 : 1.0,
      );
    }

    for (var i = 0; i < 28; i++) {
      final core = i < 14;
      final s = r.sign();
      ps.spawn(
        P.smoke,
        core ? r.range(-5.0, 5.0) : s * r.range(4.0, 12.0),
        -r.range(2.0, 10.0),
        core ? r.range(-12.0, 12.0) : s * r.range(14.0, 38.0),
        -r.range(50.0, 130.0) * (core ? 1.0 : r.range(0.3, 0.6)),
        r.range(1.9, 2.7),
        r.chance(0.35) ? dustLit : st.dust,
        core ? r.range(4.5, 9.0) : r.range(4.0, 7.5),
        r.range(0.02, 0.22),
        PF.big,
      );
    }
    for (var i = 0; i < 10; i++) {
      final s = r.sign();
      ps.spawn(
        P.smoke,
        s * r.range(2.0, 14.0),
        -r.range(2.0, 6.0),
        s * r.range(20.0, 70.0),
        -r.range(4.0, 20.0),
        r.range(1.4, 2.3),
        st.dust,
        r.range(6.0, 9.0),
        r.range(0.0, 0.08),
        PF.big,
      );
    }
    for (var i = 0; i < 26; i++) {
      ps.spawn(
        P.flake,
        r.range(-22.0, 22.0),
        -r.range(14.0, 80.0),
        r.range(-12.0, 12.0),
        r.range(-10.0, 4.0),
        r.range(1.2, 2.0),
        r.chance(0.5) ? st.lip : dustLit,
        r.range(0.5, 1.2),
        r.range(0.25, 1.0),
      );
    }
    acc.add(r.next());
    acc.add(r.next());
  }

  double _front(double time) =>
      7.0 + (reach - 7.0) * Ease.outCubic(clamp((time - 0.015) / _wave));

  double _heat(double time) => math.pow(clamp(1.0 - time / 0.8), 1.4).toDouble();

  (double, double) _crest(double u) => (
        6.0 + 28.0 * math.pow(1.0 - u, 0.75),
        1.5 + 5.0 * math.pow(1.0 - u, 0.9),
      );

  void _ring(Painter p, bool back) {
    final u = clamp((t - 0.015) / (_wave + 0.1));
    if (t < 0.015 || u >= 0.9) return;
    band(
      p,
      0.0,
      0.5,
      _front(t) + 1.0,
      0.16,
      math.max(1.0, 4.0 * math.pow(1.0 - u, 0.8)),
      u < 0.55 ? 1.1 : (0.9 - u) / 0.35,
      u < 0.35
          ? [c[3], c[4], c[5], c[6]]
          : [st.body, st.light, c[4], c[5]],
      keep: (g) => (math.sin(g) < 0.0) == back,
      hot: t < 0.09,
    );
  }

  void _fronts(Painter p) {
    final u = clamp((t - 0.03) / (_wave + 0.16));
    if (t < 0.03 || u >= 1.0) return;
    final fr = _front(t);
    final (h, w) = _crest(u);
    final k = u < 0.7 ? 1.0 : (1.0 - u) / 0.3;
    final cols = u < 0.14
        ? [kWhite, c[6], c[5]]
        : (u < 0.34
            ? [c[6], c[5], c[4]]
            : (u < 0.55 ? [c[5], c[4], st.lip] : [st.lip, st.light, st.dust]));
    for (final s in [-1, 1]) {
      frontCrescent(p, s * fr, s, h, w, cols, k);
      p.glow(s * fr, -h * 0.3, 8.0 + h * 0.7, c[4], 0.5 * (1.0 - u) * k);
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final u = clamp((t - 0.015) / _wave);
    if (u > 0.0 && u < 1.0) {
      final fr = _front(t);
      final (h, _) = _crest(u);
      for (var k = 0; k < 2; k++) {
        final s = k != 0 ? 1 : -1;
        for (acc[k] += dt * 120.0 * (1.0 - u * 0.7); acc[k] > 1.0; acc[k]--) {
          ps.spawn(
            P.smoke,
            s * (fr - r.range(1.0, 7.0)),
            -r.range(0.5, 3.0),
            s * r.range(15.0, 70.0) * (1.0 - u),
            -r.range(2.0, 12.0),
            r.range(1.0, 2.1),
            r.chance(0.3) ? dustLit : st.dust,
            r.range(2.5, 6.5) * (1.0 - 0.4 * u),
            0.0,
            PF.big,
          );
          if (r.chance(0.5)) {
            ps.spawn(
              P.dust,
              s * (fr - r.range(0.0, 3.0)),
              -r.range(0.3, 0.9) * h,
              s * r.range(-15.0, 25.0),
              -r.range(8.0, 35.0),
              r.range(0.3, 0.6),
              r.chance(0.5) ? dustLit : st.dust,
              r.range(1.2, 2.4),
            );
          }
          if (r.chance(0.4)) {
            ps.spawn(
              P.grit,
              s * fr,
              -1.0,
              s * r.range(10.0, 60.0),
              -r.range(40.0, 140.0) * (1.0 - u),
              r.range(0.5, 1.0),
              r.pick([st.light, st.body, st.lip]),
              1.0,
            );
          }
          if (u < 0.45 && r.chance(0.2)) {
            ps.spawn(
              P.spark,
              s * fr,
              -1.0,
              s * r.range(60.0, 200.0),
              -r.range(30.0, 160.0),
              r.range(0.12, 0.3),
            );
          }
        }
      }
    }
    for (final b in bits.list) {
      pvy[b] = b.vy;
    }
    bits.update(dt);
    for (final b in bits.list) {
      final prev = pvy[b] ?? 0.0;
      if (prev > 70.0 && b.vy <= 0.0) {
        final n = prev > 200.0 ? 3 : 2;
        for (var i = 0; i < n; i++) {
          ps.spawn(
            P.dust,
            b.x + r.range(-1.5, 1.5),
            -0.5,
            r.sign() * r.range(8.0, 35.0),
            -r.range(2.0, 16.0),
            r.range(0.3, 0.65),
            st.dust,
            r.range(1.3, 2.4) * (0.7 + b.s * 0.25),
          );
        }
        pvy[b] = 0.0;
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final fade = 1.0 - smooth(duration - 0.9, duration - 0.15, t);
    final h = _heat(t);
    if (t > 0.02) _crater(p, st, h, c, fade);
    drawCracks(
      p,
      cracks,
      (cr) => cr.len * Ease.outCubic(clamp((t - cr.t0) / 0.1)),
      (d) => h * clamp(1.2 - d / 40.0),
      hot,
      kSoot,
      st.light,
      fade,
    );
    for (final e in embers) {
      final k = 1.0 - (t - 0.1) / e.life;
      if (t < 0.1 || k <= 0.0) continue;
      final f = 0.6 + 0.4 * math.sin(t * 23.0 + e.ph);
      p.px(e.x, e.y, k * f > 0.55 ? c[5] : (k * f > 0.25 ? c[4] : c[3]));
      p.glow(e.x, e.y, 4.0, c[4], 0.35 * k * f);
    }
    _ring(p, true);
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    _ring(p, false);
    _fronts(p);
    for (final b in bits.list) {
      rock(p, b, rockPts[b]!, st);
    }
    ps.draw(p, 'front');
    if (t < 0.035) {
      p.ellipseShaded(
        0.0,
        0.0,
        30.0,
        4.5,
        color: (d, _) => d > 0.8 ? c[4] : (d > 0.5 ? c[6] : kWhite),
      );
      star(p, 0.0, -1.0, burst, 1.0, 1.0, [c[4], c[6], kWhite, kWhite]);
    } else if (t < 0.07) {
      star(p, 0.0, -1.0, burst, 1.25, 0.5, [c[3], c[5], c[6], kWhite]);
    }
    if (t < 0.14) {
      p.glowLine(-80.0, 0.0, 80.0, 0.0, 10.0, c[5], 0.55 * (1.0 - t / 0.14));
    }
    final h = _heat(t);
    if (h > 0.0) p.glow(0.0, 1.0, 46.0, c[4], 0.35 * h);
    lights.draw(p);
  }
}
