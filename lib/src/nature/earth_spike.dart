// The eruption (a spike punching up with overshoot and a white frame, a burst of debris, mist and glints, then
// breaking into tumbling pieces) is adapted from Sprite Fusion's open-source ice spikes, and the grit and
// rolling dust from his explosion (https://www.spritefusion.com/pixel-art-vfx/ice), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'nature_lib.dart';

const double _up = 0.34;
const double _rise = 0.09;
const double _crack = 1.18;
const double _split = 1.5;
const double _part = 0.1;
const double _fall = 0.42;
const double _sink = 0.55;
const double _dur = 3.4;

class _SpikeInfo {
  final double x;
  final double h;
  final double w;
  final double lean;
  final double at;
  final double split;
  final bool back;
  final bool main;
  final SpikeLook look;
  final List<List<Point2>> cracks;
  final double cut;
  bool up = false;
  bool split0 = false;
  double top = 1.0;

  _SpikeInfo({
    required this.x,
    required this.h,
    required this.w,
    required this.lean,
    required this.at,
    required this.split,
    required this.back,
    this.main = false,
    required this.look,
    required this.cracks,
    required this.cut,
  });
}

class _Slab {
  final int sd;
  final double x;
  final List<Point2> pts;
  final double s;
  final double a;

  _Slab({
    required this.sd,
    required this.x,
    required this.pts,
    required this.s,
    required this.a,
  });
}

class _EarthSpikeSim extends BaseEffectSim {
  final List<int> s;
  final List<int> g;
  final Rng r;
  final double height;
  final int dust;
  final int dust2;
  final Particles ps;
  final Bits bits;
  final Lights lights;
  final List<_SpikeInfo> spikes;
  final List<List<Point2>> cracks;
  final List<_Slab> slabs;

  double t = 0.0;

  _EarthSpikeSim._({
    required this.s,
    required this.g,
    required this.r,
    required this.height,
    required this.dust,
    required this.dust2,
    required this.ps,
    required this.bits,
    required this.lights,
    required this.spikes,
    required this.cracks,
    required this.slabs,
  });

  factory _EarthSpikeSim(Map<String, Object?> o) {
    final s = fit(o.palette, 8);
    final g = fit(o.rampOpt('glow'), 5);
    final r = Rng(o.seed);
    double floorFn(double _) => 0.0;
    final height = o.numOpt('height', 62.0);
    final dust = mix(s[6], hex('#8c8494'), 0.45);
    final dust2 = mix(s[5], hex('#6c6474'), 0.4);
    final ps = Particles(
      rng: r,
      ground: floorFn,
      sparks: [g[4], g[3], g[2], g[1]],
    );
    final bits = Bits(ground: floorFn);
    final lights = Lights();

    final specs = <({
      double x,
      double h,
      double w,
      double lean,
      double at,
      double split,
      bool back,
      bool main,
    })>[
      (
        x: -height * 0.17,
        h: height * 0.52,
        w: height * 0.22,
        lean: -height * r.range(0.13, 0.18),
        at: _up + 0.045,
        split: _split - 0.1,
        back: true,
        main: false,
      ),
      (
        x: height * 0.18,
        h: height * 0.4,
        w: height * 0.2,
        lean: height * r.range(0.11, 0.15),
        at: _up + 0.085,
        split: _split + 0.08,
        back: false,
        main: false,
      ),
      (
        x: 0,
        h: height,
        w: height * 0.36,
        lean: r.range(-2, 2),
        at: _up,
        split: _split,
        back: false,
        main: true,
      ),
    ];

    final spikes = [
      for (final sp in specs)
        _SpikeInfo(
          x: sp.x,
          h: sp.h,
          w: sp.w,
          lean: sp.lean,
          at: sp.at,
          split: sp.split,
          back: sp.back,
          main: sp.main,
          look: spikeLook(r),
          cracks: [
            spikeCrack(r, r.range(0.04, 0.16), r.range(-0.6, -0.1), 1),
            spikeCrack(r, r.range(0.22, 0.4), r.range(0.1, 0.6), -1),
            spikeCrack(r, r.range(0.42, 0.58), r.range(-0.4, 0.4), r.sign()),
          ],
          cut: r.range(0.24, 0.32),
        ),
    ];

    final cracks = [
      floorCrack(r, -1, r.range(34, 44)),
      floorCrack(r, 1, r.range(34, 44)),
      floorCrack(r, -1, r.range(14, 20)),
      floorCrack(r, 1, r.range(14, 20)),
    ];

    final slabs = [
      for (final sd in const [-1, 1])
        _Slab(
          sd: sd,
          x: sd * r.range(13, 16),
          pts: const [(-1.2, -0.32), (1.1, -0.42), (1.2, 0.36), (-1.1, 0.4)],
          s: r.range(5.5, 7),
          a: sd * r.range(0.45, 0.65),
        ),
    ];

    return _EarthSpikeSim._(
      s: s,
      g: g,
      r: r,
      height: height,
      dust: dust,
      dust2: dust2,
      ps: ps,
      bits: bits,
      lights: lights,
      spikes: spikes,
      cracks: cracks,
      slabs: slabs,
    );
  }

  void _rock({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required double drag,
    required double bounce,
    required double life,
    required double a,
    required double va,
    required double s,
  }) {
    bits.add(RockBit(
      kind: B.chunk,
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      g: 1,
      drag: drag,
      bounce: bounce,
      life: life,
      a: a,
      va: va,
      s: s,
      pts: stoneShape(r),
    ));
  }

  double _grown(_SpikeInfo sp) =>
      t < sp.at ? 0.0 : Ease.outBack(clamp((t - sp.at) / _rise), 2.2);

  double _open() => Ease.outCubic(clamp((t - 0.02) / 0.24));

  double _heat() =>
      t < _up ? smooth(0, _up, t) : 1 - smooth(_up, _up + 0.9, t);

  double _gap(_SpikeInfo sp) =>
      smooth(sp.split, sp.split + _part, t) * (sp.main ? 3 : 2);

  double _tip(_SpikeInfo sp) =>
      smooth(sp.split, sp.split + _part + _fall, t) * 0.12 * sp.h;

  double _topAt(_SpikeInfo sp) =>
      lerp(1, sp.cut, Ease.inQuad(clamp((t - sp.split - 0.04) / _fall)));

  void _erupt(_SpikeInfo sp) {
    final k = sp.h / height;
    lights.add(sp.x, -sp.h * 0.4, 30 * k + 14, kWhite, 0.5 * k + 0.1, 0.1);
    lights.add(sp.x, -10, 60 * k + 20, g[2], 0.34 * k, 0.5);
    final chunkCount = (16 * k + 0.5).floor() + 3;
    for (var i = 0; i < chunkCount; i++) {
      final a = -math.pi / 2 + r.range(-1.1, 1.1);
      final spd = r.range(140, 360) * (0.6 + 0.4 * k);
      _rock(
        x: sp.x + r.range(-sp.w / 3, sp.w / 3),
        y: -r.range(1, 6),
        vx: math.cos(a) * spd,
        vy: math.sin(a) * spd,
        drag: 0.35,
        bounce: 0.32,
        life: r.range(1.4, 2.4),
        a: r.range(0, tau),
        va: r.range(-14, 14),
        s: r.range(1.6, 3.8) * (0.6 + 0.4 * k),
      );
    }
    final gritCount = (55 * k + 0.5).floor() + 10;
    for (var i = 0; i < gritCount; i++) {
      final u = r.range(-1, 1);
      final a = -math.pi / 2 + u * 0.9;
      final spd = r.range(90, 330) * (1 - 0.35 * u.abs());
      ps.spawn(
        P.grit,
        sp.x + u * sp.w * 0.4,
        -1,
        math.cos(a) * spd,
        math.sin(a) * spd,
        r.range(1, 2),
        r.pick([s[6], s[5], s[4], s[4], s[3]]),
        r.chance(0.4) ? 2 : 1,
      );
    }
    final sparkCount = (9 * k + 0.5).floor() + 2;
    for (var i = 0; i < sparkCount; i++) {
      final a = -math.pi / 2 + r.range(-1.2, 1.2);
      final spd = r.range(160, 380);
      ps.spawn(
        P.spark,
        sp.x,
        -r.range(2, 10),
        math.cos(a) * spd,
        math.sin(a) * spd,
        r.range(0.15, 0.4),
      );
    }
    final smokeCount = (10 * k + 0.5).floor() + 3;
    for (var i = 0; i < smokeCount; i++) {
      final sd = r.sign();
      ps.spawn(
        P.smoke,
        sp.x + sd * r.range(2, 10),
        -r.range(1, 4),
        sd * r.range(50, 170) * (0.5 + 0.5 * k),
        -r.range(3, 16),
        r.range(0.9, 1.6),
        r.chance(0.5) ? dust : dust2,
        r.range(3, 5.5) * (0.6 + 0.4 * k),
        r.range(0, 0.05),
        PF.big,
      );
    }
    final dustCount = (14 * k + 0.5).floor() + 4;
    for (var i = 0; i < dustCount; i++) {
      final sd = r.sign();
      ps.spawn(
        P.dust,
        sp.x + sd * r.range(0, 8),
        -r.range(0, 3),
        sd * r.range(40, 160),
        -r.range(2, 20),
        r.range(0.5, 1),
        r.chance(0.5) ? dust : dust2,
        r.range(1.5, 3.2),
      );
    }
    final smoke2Count = (3 * k + 0.5).floor() + 1;
    for (var i = 0; i < smoke2Count; i++) {
      ps.spawn(
        P.smoke,
        sp.x + r.range(-6, 6),
        -r.range(2, 12),
        r.range(-20, 20),
        -r.range(15, 45),
        r.range(1, 1.6),
        dust,
        r.range(4, 6) * k + 2,
        r.range(0.02, 0.12),
        PF.big,
      );
    }
    if (sp.main) {
      for (var i = 0; i < 3; i++) {
        ps.spawn(
          P.star,
          sp.x + r.range(-5, 5),
          -r.range(10, sp.h * 0.9),
          0,
          -3,
          r.range(0.25, 0.5),
          s[7],
          r.range(1, 2.2),
          r.range(0.1, 0.4),
        );
      }
      for (var i = 0; i < 14; i++) {
        ps.spawn(
          P.grit,
          r.range(-60, 60),
          -r.range(110, 125),
          r.range(-15, 15),
          r.range(10, 60),
          r.range(1.2, 1.8),
          r.pick([s[5], s[4], s[3]]),
          r.chance(0.35) ? 2 : 1,
          r.range(0.25, 0.9),
        );
      }
    }
  }

  void _crumble(_SpikeInfo sp, double u0, double u1) {
    final gp = _gap(sp);
    final lean = sp.lean;
    final tp = _tip(sp);
    for (final half in const [-1, 1]) {
      final u = (u0 + u1) / 2;
      final hw = (sp.w / 2) * math.pow(1 - u, 0.85);
      final x = sp.x + lean * u + half * (gp / 2 + hw * 0.45 + tp * u);
      final y = -u * sp.h;
      if (hw < 0.8 && half > 0) continue;
      _rock(
        x: x,
        y: y,
        vx: half * r.range(8, 40) + lean * 0.6,
        vy: -r.range(0, 50),
        drag: 0.3,
        bounce: 0.3,
        life: math.min(r.range(1.1, 1.6), _dur - 0.15 - t),
        a: r.range(0, tau),
        va: r.range(-8, 8),
        s: clamp(hw * 0.62, 1.6, 4.8),
      );
      for (var i = 0; i < 3; i++) {
        ps.spawn(
          P.grit,
          x + r.range(-2, 2),
          y + r.range(-2, 2),
          half * r.range(5, 45),
          -r.range(10, 70),
          r.range(0.9, 1.6),
          r.pick([s[6], s[5], s[4], s[3]]),
          r.chance(0.35) ? 2 : 1,
        );
      }
    }
    if (r.chance(0.5)) {
      ps.spawn(
        P.dust,
        sp.x + lean * u1 + r.range(-4, 4),
        -u1 * sp.h,
        r.sign() * r.range(15, 45),
        r.range(20, 60),
        r.range(0.35, 0.6),
        dust,
        r.range(2, 3.5),
      );
    }
  }

  void _drawShard(Painter p, _SpikeInfo sp) {
    final gr = _grown(sp);
    if (gr <= 0) return;
    if (t < sp.split) {
      final white = t - sp.at < 0.04 || t > sp.split - 0.045;
      final crack = smooth(_crack + (sp.main ? 0 : 0.05), sp.split - 0.03, t);
      final sw = (t - sp.at) * 0.9 - 0.15;
      final glint = sw > 0 && sw.remainder(1.2) < 0.55
          ? sw.remainder(1.2) / 0.55
          : -1.0;
      drawSpike(
        p,
        sp.x,
        0,
        sp.h * gr,
        sp.w,
        sp.lean * math.min(1.0, gr),
        sp.look,
        s,
        SpikeDrawOpts(
          white: white,
          glint: glint,
          cracks: sp.cracks,
          crack: crack,
          heat: smooth(_crack, sp.split, t),
          glowRamp: g,
        ),
      );
      return;
    }
    final top = _topAt(sp);
    final gp = _gap(sp);
    final tp = _tip(sp);
    final sink =
        smooth(sp.split + _fall, sp.split + _fall + _sink, t) * sp.h * (sp.cut + 0.06);
    if (sink >= sp.h * (sp.cut + 0.05)) return;
    for (final half in const [-1, 1]) {
      drawSpike(
        p,
        sp.x + (half * gp) / 2,
        sink,
        sp.h,
        sp.w,
        sp.lean + half * tp,
        sp.look,
        s,
        SpikeDrawOpts(
          half: half,
          clip: top,
          floor: 0,
          cracks: sp.cracks,
          crack: 1,
          heat: 1 - smooth(sp.split, sp.split + 0.45, t),
          glowRamp: g,
        ),
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final f = math.min(1.0, dt * 120);
    if (t < _up) {
      final l = _open();
      for (final c in cracks) {
        if (r.chance(0.35 * f)) {
          final q = c[math.min(c.length - 1, (r.range(0, l) * c.length).floor())];
          ps.spawn(
            P.grit,
            q.$1,
            -1,
            r.range(-20, 20),
            -r.range(30, 110),
            r.range(0.5, 1),
            r.pick([s[5], s[4]]),
            1,
          );
          if (r.chance(0.25)) {
            ps.spawn(
              P.dust,
              q.$1,
              -1,
              r.range(-15, 15),
              -r.range(4, 14),
              r.range(0.3, 0.6),
              dust2,
              r.range(1.5, 3),
            );
          }
        }
      }
      if (t > 0.12 && r.chance(0.2 * f)) {
        ps.spawn(
          P.dust,
          r.sign() * r.range(10, 16),
          -r.range(1, 4),
          r.sign() * r.range(10, 30),
          -r.range(4, 12),
          r.range(0.4, 0.7),
          dust2,
          r.range(2, 3.5),
        );
      }
    }
    for (final sp in spikes) {
      if (!sp.up && t >= sp.at) {
        sp.up = true;
        _erupt(sp);
      }
      if (!sp.split0 && t >= sp.split) {
        sp.split0 = true;
        lights.add(sp.x, -sp.h * 0.5, 30, kWhite, 0.3, 0.08);
        ps.spawn(P.star, sp.x + sp.lean * 0.5, -sp.h * 0.55, 0, -2, 0.3, s[7], 2.5);
      }
      if (t >= sp.split) {
        final top = _topAt(sp);
        while (sp.top - top > 0.045 ||
            (top <= sp.cut + 1e-6 && sp.top > sp.cut + 1e-6)) {
          final u1 = sp.top;
          final u0 = math.max(top, sp.top - 0.11);
          _crumble(sp, u0, u1);
          sp.top = u0;
          if (u0 <= sp.cut + 1e-6) break;
        }
      }
      if (t < sp.split && t > _crack && r.chance(0.12 * f)) {
        final u = r.range(0.1, 0.7);
        ps.spawn(
          P.grit,
          sp.x + sp.lean * u + r.range(-2, 2),
          -u * sp.h,
          r.range(-15, 15),
          -r.range(0, 20),
          r.range(0.6, 1.1),
          r.pick([s[5], s[4]]),
          1,
        );
        if (r.chance(0.3)) {
          ps.spawn(
            P.dust,
            sp.x + sp.lean * u,
            -u * sp.h,
            r.range(-10, 10),
            -r.range(2, 8),
            r.range(0.4, 0.7),
            dust,
            r.range(1.5, 2.5),
          );
        }
      }
      if (sp.up && t < sp.split && t > sp.at + 0.2 && r.chance(0.05 * f)) {
        final u = r.range(0.2, 0.8);
        final sd = r.sign();
        ps.spawn(
          P.grit,
          sp.x + sp.lean * u + sd * (sp.w / 2) * (1 - u),
          -u * sp.h,
          sd * r.range(10, 30),
          -r.range(0, 15),
          r.range(0.7, 1.2),
          r.pick([s[6], s[5]]),
          1,
        );
      }
      if (sp.main && sp.up && t < sp.split && t > sp.at + 0.25 && r.chance(0.03 * f)) {
        ps.spawn(
          P.star,
          sp.x + r.range(-4, 2),
          -r.range(8, sp.h * 0.85),
          0,
          -2,
          r.range(0.25, 0.45),
          r.chance(0.5) ? s[7] : g[3],
          r.range(0.8, 2),
        );
      }
      if (t > sp.split + _fall &&
          t < sp.split + _fall + _sink * 0.8 &&
          r.chance(0.15 * f)) {
        ps.spawn(
          P.dust,
          sp.x + r.range(-sp.w / 2, sp.w / 2),
          -r.range(0, 2),
          r.sign() * r.range(20, 60),
          -r.range(0, 5),
          r.range(0.4, 0.7),
          dust2,
          r.range(1.5, 3),
        );
      }
    }
    bits.update(dt);
    for (final b in bits.list) {
      if (b is RockBit && b.rest && !b.dusted) {
        b.dusted = true;
        for (var i = 0; i < 2; i++) {
          ps.spawn(
            P.dust,
            b.x + r.range(-1.5, 1.5),
            -0.5,
            r.sign() * r.range(8, 35),
            -r.range(2, 14),
            r.range(0.3, 0.6),
            dust2,
            r.range(1.3, 2.6),
          );
        }
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final l = _open();
    final hk = _heat();
    final fade = 1 - smooth(_dur - 1.1, _dur - 0.3, t);
    for (final c in cracks) {
      final m = math.max(2, (c.length * l).ceil());
      for (var k = 1; k < m; k++) {
        final (x0, y0) = c[k - 1];
        final (x1, y1) = c[k];
        p.line(x0, y0 + 1, x1, y1 + 1, s[0], fade);
        p.line(
          x0,
          y0,
          x1,
          y1,
          hk > 0.65
              ? g[4]
              : hk > 0.35
                  ? g[3]
                  : hk > 0.12
                      ? g[2]
                      : hk > 0.03
                          ? g[1]
                          : s[1],
          fade,
        );
        if (k % 2 == 0) p.glow(x1, y1, 6, g[2], 0.3 * hk);
      }
    }
    if (hk > 0) p.glow(0, -3, 26, g[2], 0.35 * hk);
    ps.draw(p, 'back');
    for (final sp in spikes) {
      if (sp.back) _drawShard(p, sp);
    }
  }

  @override
  void draw(Painter p) {
    if (t < _up + 0.02) {
      final k = smooth(0.06, _up, t);
      final hm = 8 * k;
      final jx = math.sin(t * 95) * 0.8 * k;
      if (hm > 0.6) {
        p.shade(-16, -hm - 1, 16, 1, (x, y, out) {
          final dx = (x - jx) / 15;
          final dy = y / hm;
          final d = dx * dx + dy * dy;
          if (y > 0.5 || d > 1.18) return null;
          out.c = d > 1
              ? s[0]
              : dy < -0.72
                  ? s[6]
                  : dx < -0.3
                      ? s[5]
                      : dx > 0.35
                          ? s[3]
                          : s[4];
          return null;
        });
      }
    }
    if (t >= _up) {
      final sink = smooth(_split + _fall, _split + _fall + _sink, t) * 7;
      final a = 1 - smooth(_split + _fall, _split + _fall + _sink, t);
      for (final sl in slabs) {
        final gr = Ease.outBack(clamp((t - _up) / 0.1), 2);
        if (a > 0) {
          drawRock(
            p,
            sl.x,
            -1.5 + sink,
            sl.s * math.min(1.0, gr),
            sl.a * gr,
            sl.pts,
            s,
            a,
            t - _up < 0.04,
          );
        }
      }
    }
    for (final sp in spikes) {
      if (!sp.back) _drawShard(p, sp);
    }
    final m0 = spikes[2];
    final leak =
        smooth(_crack, _split, t) * (1 - smooth(_split, _split + 0.5, t));
    if (leak > 0) {
      p.glowLine(
        m0.x,
        -4,
        m0.x + m0.lean * 0.6,
        -m0.h * 0.6,
        20,
        g[2],
        0.22 * leak,
      );
    }
    for (final b in bits.list) {
      if (b is RockBit) {
        drawRock(p, b.x, b.y, b.s, b.a, b.pts, s, math.min(1.0, b.life / 0.4));
      }
    }
    ps.draw(p, 'front');
    final m = spikes[2];
    final e = t - m.at;
    if (e > 0 && e < 0.2) {
      final gr = Ease.outBack(clamp(e / _rise), 2.2);
      sparkle(
        p,
        m.x + m.lean,
        -m.h * gr,
        10 * (1 - e / 0.2),
        s[7],
        g[3],
        0.5,
      );
      p.glowLine(
        m.x,
        0,
        m.x + m.lean,
        -m.h * gr,
        10,
        g[3],
        0.3 * (1 - e / 0.2),
      );
    }
    lights.draw(p);
  }
}

final PixelEffect earthSpike = SimulatedEffect(
  meta: const EffectMeta(
    id: 'nature/earth-spike',
    name: 'Earth spike',
    desc:
        'The floor cracks with light and heaves, a faceted stone spike rams up with two side shards in a burst of chips, grit and dust; rubble rains, then it splits and crumbles.',
    category: 'nature',
    tags: [
      'nature',
      'earth',
      'stone',
      'spike',
      'ground',
      'attack',
      'one-shot',
    ],
    size: (272, 150),
    origin: (136, 132),
    duration: 3.4,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#120c0c',
        '#251917',
        '#3b2a24',
        '#553d31',
        '#715440',
        '#8f6e52',
        '#b8966e',
        '#e6d0a8',
      ],
      'glow': ['#4a1a0c', '#a8401a', '#ff8a2a', '#ffd27a', '#fff4d0'],
      'height': 62,
      'seed': 5,
    },
  ),
  onCreate: _EarthSpikeSim.new,
);
