import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'ice_lib.dart';

const double _duration = 3.0;
const double _start = 0.04;
const double _run = 0.44;
const double _shimmer = 0.74;
const double _tremble = 1.2;
const double _flash = 1.36;
const double _shatter = 1.42;
const double _melt = 1.75;

class _BladeSpec {
  final double dx;
  final double h;
  final double w;
  final double lean;
  final bool back;
  final double delay;
  final double jag;
  final bool main;

  const _BladeSpec({
    required this.dx,
    required this.h,
    required this.w,
    required this.lean,
    required this.back,
    required this.delay,
    required this.jag,
    this.main = false,
  });
}

class _SpikeCluster {
  final double x;
  final double q;
  final double h;
  final double w;
  final List<_BladeSpec> blades;
  final _BladeSpec main;
  final double t0;
  bool up = false;

  _SpikeCluster({
    required this.x,
    required this.q,
    required this.h,
    required this.w,
    required this.blades,
    required this.main,
    required this.t0,
  });
}

class _IceSpikesSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final double reach;
  final double heightOpt;
  late final Particles ps;
  final Bits bits = Bits(ground: (_) => 0.0);
  final Lights lights = Lights();
  late final Panes panes;
  final List<_SpikeCluster> clusters = [];
  late final _SpikeCluster crest;

  double t = 0.0;
  bool broke = false;
  bool trembled = false;

  _IceSpikesSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed),
        reach = o.numOpt('reach', 172.0),
        heightOpt = o.numOpt('height', 56.0) {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [c[7], c[6], c[5], c[4]],
      haze: c[5],
    );
    panes = Panes(
      ground: (_) => 0.0,
      onCrumble: (q) {
        _splinter(q.x, 0, 0, 3);
        ps.spawn(P.vapour, q.x, -1, r.range(-12, 12), -r.range(2, 8),
            r.range(0.4, 0.7), c[6], r.range(1.4, 2.2));
      },
      onLand: (q, x, y, v) {
        if (v < 110.0) return;
        ps.spawn(P.vapour, x, y - 1, r.range(-20, 20), -r.range(2, 8),
            r.range(0.4, 0.7), c[6], r.range(1.4, 2.4));
        _splinter(x, y, q.vx, 3);
        if (r.chance(0.3)) {
          ps.spawn(P.star, x, y - 2, 0, -5, r.range(0.2, 0.4), kWhite,
              r.range(0.8, 1.6));
        }
      },
    );

    double env(double q) =>
        0.28 + 0.72 * math.exp(-math.pow((q - 0.64) / 0.3, 2));
    for (var x = 10.0; x < reach - 2.0; x += r.range(20, 26)) {
      final q = x / reach;
      final h = heightOpt * env(q) * r.range(0.88, 1.06);
      final w = clamp(h * 0.36, 5.0, 14.0);
      final lean = h * r.range(0.2, 0.34);
      final backBlade = _BladeSpec(
        dx: w * r.range(0.35, 0.6),
        h: h * r.range(0.5, 0.7),
        w: w * 0.7,
        lean: h * r.range(0.4, 0.6),
        back: true,
        delay: r.range(0.02, 0.05),
        jag: r.chance(0.5) ? r.range(0.35, 0.6) : -1.0,
      );
      final mainBlade = _BladeSpec(
        dx: 0.0,
        h: h,
        w: w,
        lean: lean,
        back: false,
        delay: 0.0,
        jag: r.chance(0.7) ? r.range(0.32, 0.58) : -1.0,
        main: true,
      );
      final list = <_BladeSpec>[backBlade, mainBlade];
      if (h > 14.0) {
        list.add(_BladeSpec(
          dx: -w * r.range(0.35, 0.55),
          h: h * r.range(0.24, 0.4),
          w: w * 0.55,
          lean: -h * r.range(0, 0.12),
          back: false,
          delay: r.range(0.03, 0.07),
          jag: -1.0,
        ));
      }
      clusters.add(_SpikeCluster(
        x: x,
        q: q,
        h: h,
        w: w,
        blades: list,
        main: mainBlade,
        t0: _reachedAt(x) + 0.012,
      ));
    }
    var best = clusters[0];
    for (final cl in clusters) {
      if (cl.h > best.h) best = cl;
    }
    crest = best;
  }

  void _splinter(double x, double y, double vx, int n) {
    for (var i = 0; i < n; i++) {
      bits.add(DebrisBit(
        kind: B.shard,
        x: x + r.range(-2, 2),
        y: y - 1,
        vx: vx * 0.5 + r.range(-45, 45),
        vy: -r.range(30, 100),
        g: 0.8,
        drag: 0.6,
        bounce: 0.35,
        life: r.range(0.4, 0.75),
        a: r.range(0, tau),
        va: r.range(-18, 18),
        s: r.range(1.2, 2.4),
        c: c[r.intRange(4, 7)],
      ));
    }
  }

  double _front(double tt) =>
      reach * (1.0 - math.pow(1.0 - seg(tt, _start, _start + _run), 1.7));

  double _reachedAt(double x) =>
      _start + _run * (1.0 - math.pow(1.0 - clamp(x / reach), 1.0 / 1.7));

  ({double g, double x, double tx, double ty, bool white}) _pose(
    _SpikeCluster cl,
    _BladeSpec b,
  ) {
    final g = Ease.outBack(clamp((t - cl.t0 - b.delay) / 0.09), 2.2);
    final x = cl.x + b.dx;
    return (
      g: g,
      x: x,
      tx: x + b.lean * g,
      ty: -b.h * g,
      white: t - cl.t0 - b.delay < 0.03 || (t >= _flash && t < _shatter),
    );
  }

  void _drawClusters(Painter p) {
    if (t >= _shatter) return;
    for (final pass in const [0, 1, 2]) {
      for (final cl in clusters) {
        if (t < cl.t0) continue;
        final jx = t >= _tremble && t < _flash
            ? (((t * 40.0).floor() + (cl.x + 0.5).floor()).isOdd ? 1.0 : 0.0)
            : 0.0;
        for (final b in cl.blades) {
          if ((pass == 0) != b.back || (pass == 1) != b.main) continue;
          final s = _pose(cl, b);
          if (s.g <= 0.0) continue;
          final gl = (t - _shimmer - cl.q * 0.34) / 0.2;
          blade(
            p,
            s.x + jx,
            0,
            s.tx + jx,
            s.ty,
            b.w,
            c,
            white: s.white,
            jag: b.jag,
            dim: b.back ? 1 : 0,
            glint: gl >= 0.0 && gl <= 1.0 ? gl : -1.0,
          );
        }
        if (pass == 2) {
          final pop = clamp(1.0 - (t - cl.t0) / 0.15);
          final wh = t >= _flash;
          p.glow(
            cl.x + cl.main.lean * 0.4,
            -cl.h * 0.45,
            cl.h * 0.9 + 10.0,
            c[4],
            (0.16 + 0.42 * pop + (wh ? 0.4 : 0.0)) *
                (0.85 + 0.15 * math.sin(t * 3.0 + cl.x)),
          );
          if (pop > 0.0) p.glow(cl.x, -2, 14, kWhite, 0.55 * pop);
        }
      }
    }
  }

  void _drawFrost(Painter p) {
    final fr = _front(t);
    final xMax = math.min(fr, reach + 6.0);
    for (var x = -3; x <= xMax; x++) {
      final q = clamp(x / reach);
      final age = t - _reachedAt(math.max(0.0, x.toDouble()));
      final a = 1.0 - smooth(_melt + q * 0.35, _melt + q * 0.35 + 0.6, t);
      if (a <= 0.0 || age < 0.0) continue;
      final h = rand(x, 17);
      final grow = smooth(0.0, 0.3, age);
      final head = fr - x < 3.0 && fr < reach;
      p.dot(x, 0, head || age < 0.06 || h < 0.3 ? kWhite : c[6], a);
      final len =
          h < 0.45 ? (grow * (1.0 + rand(x, 5) * 2.6) + 0.5).floor() : 0;
      for (var j = 1; j <= len; j++) {
        p.dot(x, -j, j == len ? kWhite : c[5], a);
      }
      if (len > 1 && rand(x, 9) < 0.5) p.dot(x + 1, -len + 1, c[6], a);
      final depth = grow * (2.0 + rand(x, 11) * 4.0) * (1.0 - q * 0.3);
      for (var j = 1; j <= depth; j++) {
        final col = rand(x * 31 + j, 7) < 0.06
            ? kWhite
            : (j < 2 ? c[5] : (j < 4 ? c[4] : c[3]));
        p.dot(x, j, col, a * (1.1 - j / (depth + 1.0)));
      }
      if (head) p.dot(x, -1, kWhite);
    }
    if (fr < reach && t > _start) {
      p.glow(fr, -2, 16, c[6], 0.6);
      p.glow(fr, -1, 7, kWhite, 0.6);
    }
  }

  void _breakBlade(_SpikeCluster cl, _BladeSpec b) {
    final s = _pose(cl, b);
    final ax = s.tx - s.x;
    final ay = s.ty;
    final rawL = hypot(ax, ay);
    final len = rawL == 0.0 ? 1.0 : rawL;
    final nx = -ay / len;
    final ny = ax / len;
    final hw = b.w / 2.0;
    final tri = <(double, double)>[
      (s.x - nx * hw, -ny * hw),
      (s.tx, s.ty),
      (s.x + nx * hw, ny * hw),
    ];
    final ang = math.atan2(ay, ax) + math.pi / 2.0;
    var parts = <List<(double, double)>>[tri];
    if (b.h > 9.0) {
      parts = [
        for (final poly in parts)
          ...splitPoly(poly, s.x + ax * 0.4, ay * 0.4, ang),
      ];
    }
    if (b.h > 22.0) {
      parts = [
        for (final poly in parts)
          if (poly.any((pt) => pt.$2 < ay * 0.5))
            ...splitPoly(poly, s.x + ax * 0.72, ay * 0.72, ang)
          else
            poly,
      ];
    }
    for (final part in parts) {
      var mx = 0.0;
      var my = 0.0;
      for (final (px, py) in part) {
        mx += px;
        my += py;
      }
      mx /= part.length;
      my /= part.length;
      final up = clamp(-my / 40.0);
      panes.add(IcePane(
        pts: [for (final (px, py) in part) (px - mx, py - my)],
        x: mx,
        y: my,
        vx: r.range(-25, 60),
        vy: -r.range(40, 130) * (0.5 + up),
        a: 0,
        va: r.range(-8, 8),
        f: r.range(-0.7, 0.7),
        vf: r.range(-6, 6),
        lit: b.back ? 0.45 : 0.75,
        g: 0.9,
        drag: 0.6,
        bounce: 0.3,
        solid: true,
        ridge: math.atan2(ay, ax),
        brittle: b.h > 30.0 ? 2 : 1,
        crumble: r.range(0.12, 0.4),
        life: r.range(1, 1.4),
      ));
    }
    for (var i = 0; i < 2.0 + b.h / 7.0; i++) {
      final u = r.next();
      bits.add(DebrisBit(
        kind: r.chance(0.15) ? B.chunk : B.shard,
        x: s.x + ax * u + r.range(-1.5, 1.5),
        y: ay * u,
        vx: r.range(-60, 90),
        vy: -r.range(60, 230),
        g: 0.9,
        drag: 0.6,
        bounce: 0.3,
        life: r.range(0.7, 1.3),
        a: r.range(0, tau),
        va: r.range(-20, 20),
        s: r.range(1.2, 3.2),
        c: c[r.intRange(4, 7)],
        rampColors: [c[1], c[3], c[4], c[6], c[7]],
      ));
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (t - dt <= _start && t > _start) {
      for (var i = 0; i < 4; i++) {
        ps.spawn(P.vapour, r.range(0, 6), -r.range(0, 3), r.range(10, 60),
            -r.range(2, 12), r.range(0.4, 0.7), c[6], r.range(2, 3.2));
      }
      lights.add(4, -4, 26, c[5], 0.6, 0.25);
    }
    final fr = _front(t);
    if (t > _start && fr < reach - 1.0) {
      if (r.chance(0.5)) {
        ps.spawn(
          P.streak,
          fr - r.range(4, 12),
          -r.range(1, 3),
          r.range(40, 80),
          -r.range(0, 6),
          r.range(0.08, 0.14),
          r.chance(0.5) ? c[6] : kWhite,
        );
      }
      if (r.chance(0.3)) {
        ps.spawn(
          P.flake,
          fr,
          -1,
          r.range(10, 50),
          -r.range(20, 70),
          r.range(0.5, 0.9),
          r.chance(0.5) ? kWhite : c[6],
          r.range(0.5, 1.2),
        );
      }
      if (r.chance(0.12)) {
        ps.spawn(P.vapour, fr, -r.range(0, 3), r.range(20, 60), -r.range(2, 10),
            r.range(0.4, 0.7), c[6], r.range(1.6, 2.8));
      }
    }
    for (final cl in clusters) {
      if (cl.up || t < cl.t0) continue;
      cl.up = true;
      final big = cl == crest;
      final n = 3 + (cl.h / 8.0 + 0.5).floor();
      for (var i = 0; i < n; i++) {
        final a = -math.pi / 2.0 + r.range(-1.1, 1.0);
        final sp = r.range(60, 190) * (0.45 + cl.h / 44.0);
        bits.add(DebrisBit(
          kind: B.shard,
          x: cl.x + r.range(-3, 3),
          y: -1,
          vx: math.cos(a) * sp + 25.0,
          vy: math.sin(a) * sp,
          g: 0.8,
          drag: 0.6,
          bounce: 0.3,
          life: r.range(0.6, 1.1),
          a: r.range(0, tau),
          va: r.range(-18, 18),
          s: r.range(1.2, 3),
          c: c[r.intRange(5, 7)],
        ));
      }
      ps.spawn(
        P.vapour,
        cl.x,
        -1,
        r.range(-10, 40),
        -r.range(2, 10),
        r.range(0.5, 0.9),
        c[6],
        r.range(2.2, 3.4) * (0.6 + cl.h / 60.0),
      );
      for (var i = 0; i < 2; i++) {
        ps.spawn(
          P.flake,
          cl.x + r.range(-4, 4),
          -r.range(2, cl.h * 0.5),
          r.range(-20, 40),
          -r.range(20, 60),
          r.range(0.6, 1.1),
          r.chance(0.5) ? kWhite : c[6],
          r.range(0.5, 1.3),
        );
      }
      if (cl.h > 16.0) {
        ps.spawn(P.star, cl.x + cl.main.lean, -cl.h * 0.96, 0, -4,
            r.range(0.3, 0.5), kWhite, r.range(1.4, 2.6), 0.08);
      }
      lights.add(cl.x, -cl.h * 0.4, 16.0 + cl.h * 0.6, c[5], 0.5, 0.18);
      if (big) {
        lights.add(cl.x, -cl.h * 0.5, 54, kWhite, 0.5, 0.14);
        for (var i = 0; i < 4; i++) {
          ps.spawn(P.vapour, cl.x + r.range(-6, 6), -r.range(0, 4),
              r.range(-40, 60), -r.range(4, 16), r.range(0.6, 1), c[6],
              r.range(3, 4.5));
        }
      }
    }
    if (t > _start + _run && t < _tremble && r.chance(0.09)) {
      final cl = r.pick(clusters);
      final b = r.pick(cl.blades);
      final s = _pose(cl, b);
      final u = r.range(0.3, 0.95);
      ps.spawn(
        P.star,
        s.x + (s.tx - s.x) * u,
        s.ty * u,
        0,
        -3,
        r.range(0.25, 0.5),
        r.chance(0.6) ? c[6] : kWhite,
        r.range(0.6, 2),
      );
    }
    if (!trembled && t >= _tremble) {
      trembled = true;
      for (final cl in clusters) {
        for (var i = 0; i < 2; i++) {
          bits.add(DebrisBit(
            kind: B.shard,
            x: cl.x + r.range(-4, 4),
            y: -r.range(4, cl.h * 0.8),
            vx: r.range(-20, 20),
            vy: -r.range(0, 30),
            g: 0.8,
            drag: 0.5,
            bounce: 0.3,
            life: r.range(0.3, 0.6),
            a: r.range(0, tau),
            va: r.range(-18, 18),
            s: r.range(1, 1.8),
            c: c[r.intRange(5, 7)],
          ));
        }
      }
    }
    if (!broke && t >= _shatter) {
      broke = true;
      for (final cl in clusters) {
        for (final b in cl.blades) {
          _breakBlade(cl, b);
        }
        for (var i = 0; i < 2; i++) {
          ps.spawn(
            P.vapour,
            cl.x + r.range(-6, 6),
            -r.range(1, 8),
            r.range(-30, 50),
            -r.range(4, 18),
            r.range(0.6, 1.1),
            c[6],
            r.range(2.4, 4) * (0.7 + cl.h / 60.0),
          );
        }
        if (r.chance(0.7)) {
          ps.spawn(
            P.star,
            cl.x + r.range(-6, 6),
            -r.range(4, cl.h),
            r.range(-10, 10),
            -r.range(6, 20),
            r.range(0.4, 0.8),
            r.chance(0.5) ? kWhite : c[6],
            r.range(1, 2.2),
          );
        }
        for (var i = 0; i < 2; i++) {
          ps.spawn(
            P.flake,
            cl.x + r.range(-6, 6),
            -r.range(4, cl.h),
            r.range(-30, 60),
            -r.range(30, 90),
            r.range(0.9, 1.5),
            r.chance(0.6) ? kWhite : c[6],
            r.range(0.5, 1.5),
          );
        }
        lights.add(cl.x, -cl.h * 0.5, 22.0 + cl.h, kWhite, 0.45, 0.12);
      }
      for (var i = 0; i < 5; i++) {
        lights.add((reach * (i + 0.5)) / 5.0, -18, 40, c[4], 0.4, 0.5);
      }
    }
    if (broke && t < _shatter + 0.8 && r.chance(0.1) && bits.list.isNotEmpty) {
      final b = r.pick(bits.list);
      ps.spawn(P.star, b.x, b.y - 1.0, 0, -3, r.range(0.2, 0.4),
          r.chance(0.5) ? kWhite : c[6], r.range(0.6, 1.5));
    }
    ps.update(dt);
    bits.update(dt);
    panes.update(dt);
    lights.update(dt);
    endBy(t, _duration, ps: ps, bits: bits, panes: panes);
  }

  @override
  void drawBack(Painter p) {
    _drawFrost(p);
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    _drawClusters(p);
    final k =
        (1.0 - smooth(_melt, _melt + 0.9, t)) * smooth(_start, _start + 0.3, t);
    final fr = _front(t);
    for (var i = 0; i < 6; i++) {
      p.glow((fr * (i + 0.5)) / 6.0, -3, 26, c[4], 0.15 * k);
    }
    if (t >= _flash && t < _shatter + 0.1) {
      for (final cl in clusters) {
        sparkle(
          p,
          cl.x + cl.main.lean,
          -cl.h,
          6.0 * (1.0 - clamp((t - _flash) / 0.16)),
          c[6],
          c[4],
          0.4,
        );
      }
    }
    panes.draw(p, c);
    bits.draw(p);
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect iceSpikesEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ice/ice-spikes',
    name: 'Ice spikes',
    desc:
        'A frost line races along the floor and clusters of jagged ice blades burst up behind it in a rising wave, glint, flash white together and shatter into toppling shards.',
    category: 'ice',
    tags: ['ice', 'spikes', 'ground', 'wave', 'directional', 'magic', 'one-shot'],
    size: (264, 112),
    origin: (24, 96),
    duration: _duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#151a3d', '#212f6b', '#2c58aa', '#3a8bd8',
        '#62c8f4', '#a6ecff', '#dcfbff', '#ffffff',
      ],
      'reach': 172,
      'height': 56,
      'seed': 3,
    },
  ),
  onCreate: (o) => _IceSpikesSim(o),
);
