// The blast recipe (fire puffs that cool into smoke, sparks, embers, burning brands, grit, rocks, scorch, rings) is
// adapted from Sprite Fusion's open-source explosion (https://www.spritefusion.com/pixel-art-vfx/explosion),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'explosions_lib.dart';

const double _rad = 30.0;
const double _power = 1.45;
const double _earth = 1.6;

final List<int> _sm =
    ['#83777f', '#6e6470', '#575060', '#3f3947', '#29242f'].map(hex).toList();

class _BlastSpec {
  final double t, x, y, rad, power;
  final bool main;
  const _BlastSpec(this.t, this.x, this.y, this.rad, this.power,
      {this.main = false});
}

const List<_BlastSpec> _blasts = [
  _BlastSpec(0.0, 0.0, -9.0, _rad, _power, main: true),
  _BlastSpec(0.13, -17.0, -30.0, 17.0, 0.9),
  _BlastSpec(0.25, 15.0, -46.0, 15.0, 0.8),
];

class _Flash {
  final double x, y, r, max;
  double life;
  _Flash(this.x, this.y, this.r, this.life) : max = life;
}

class _ShockRing {
  final double x, y, r0, r1, thick, max;
  final int c;
  double life;
  _ShockRing(this.x, this.y, this.r0, this.r1, this.life, this.thick, this.c)
      : max = life;
}

class _BigExplosionSim extends BaseEffectSim {
  final EffectMeta meta;
  final List<int> f, fr, hr;
  final StoneColors st;
  final Rng r;
  final int warm;
  final double x0, x1, y0, y1;
  late final Particles ps;
  late final Blazes blazes;
  final Bits rocks = Bits(ground: (_) => 0.0);
  final Lights lights = Lights();
  final List<_Flash> flashes = [];
  final List<_ShockRing> rings = [];
  late final Plume plume;
  late final PlumeColumn column;
  double t = 0.0;
  int next = 0;

  _BigExplosionSim(this.meta, Map<String, Object?> o)
      : f = fit(o.palette, 8),
        fr = fireRamp(fit(o.palette, 8)),
        hr = heatRamp(fireRamp(fit(o.palette, 8))),
        st = stoneColors(o['stone'] ?? '#4a3f69'),
        r = Rng(o.seed),
        warm = mix(fit(o.palette, 8)[3], fit(o.palette, 8)[6], 0.45),
        x0 = -meta.origin.$1 + 3.0,
        x1 = meta.size.$1 - meta.origin.$1 - 3.0,
        y0 = -meta.origin.$2 + 3.0,
        y1 = meta.size.$2 - meta.origin.$2 - 3.0 {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [f[6], f[5], f[3], f[2]],
      onLand: (x, y) =>
          blazes.add(x, y - 0.25, r.range(3, 4.4), r.range(0.7, 1.25)),
    );
    blazes = Blazes(ps);
    plume = Plume(
      r,
      x: 0.0,
      y: -34.0,
      rise: 118.0,
      tauVal: 1.25,
      drift: 4.0,
      tube: (9.0, 21.0),
      ring: (2.0, 19.0),
      grow: 1.0,
      n: 42,
      size: (6.0, 11.0),
      swell: 0.9,
      spin: 2.6,
      spinTau: 1.7,
      heat: 1.2,
      cool: 0.42,
      under: 0.5,
      tilt: 0.22,
      squash: 0.72,
      fade: (4.4, 6.4),
      spread: 22.0,
    );
    column = PlumeColumn(
      r,
      w: 5.0,
      foot: 18.0,
      speed: 85.0,
      size: (7.0, 11.0),
      n: 28,
      sway: 2.5,
    );
  }

  double _top() {
    final s = plume.shape();
    return s.y + s.tube * 0.45;
  }

  void _blast(_BlastSpec b) {
    final x = b.x;
    final y = b.y;
    final rad = b.rad;
    final power = b.power;
    final main = b.main;
    if (!main) flashes.add(_Flash(x, y, rad * 1.05, 0.06));
    if (!main) {
      rings.add(_ShockRing(x, y, rad * 0.45, rad * 2.7, 0.36, 3.0, f[5]));
      rings.add(_ShockRing(x, y, rad * 0.3, rad * 1.6, 0.24, 1.8, f[3]));
    }
    lights.add(x, main ? y - 24.0 : y, main ? 72.0 : rad * 3.4, warm,
        0.6 * power, 0.8);
    lights.add(
        x, main ? y - 12.0 : y, main ? 44.0 : rad * 1.6, kWhite, 0.6, 0.1);
    final down = main ? 0.25 : math.pi;
    for (var i = 0; i < 5; i++) {
      ps.spawn(
        P.fire,
        x + r.range(-2.5, 2.5),
        y + r.range(-2.5, 2.5),
        r.range(-20, 20),
        r.range(-40, -10),
        r.range(0.18, 0.3),
        0,
        r.range(rad * 0.4, rad * 0.55),
      );
    }
    for (var i = 0; i < (26 * power + 0.5).floor(); i++) {
      final a = main ? r.range(-math.pi - down, down) : r.range(0, tau);
      final d = r.range(0, rad * 0.55);
      final sp = r.range(40, 200) * power;
      ps.spawn(
        P.fire,
        x + math.cos(a) * d,
        y + math.sin(a) * d,
        math.cos(a) * sp,
        math.sin(a) * sp * 0.8 - 40.0,
        r.range(0.55, 1.15),
        0,
        r.range(rad * 0.22, rad * 0.46),
        0,
        r.chance(0.45) ? (PF.smokes | PF.big) : 0,
      );
    }
    for (var i = 0; i < 5; i++) {
      final a = r.range(-math.pi, 0);
      final d = r.range(rad * 0.1, rad * 0.5);
      ps.spawn(
        P.smoke,
        x + math.cos(a) * d,
        y + math.sin(a) * d,
        math.cos(a) * 30.0,
        math.sin(a) * 20.0 - 30.0,
        r.range(0.9, 1.5),
        hex('#221d26'),
        r.range(rad * 0.15, rad * 0.26),
        r.range(0.06, 0.2),
        PF.big,
      );
    }
    for (var i = 0; i < (8 * power + 0.5).floor(); i++) {
      final a = r.range(-math.pi, 0);
      final d = r.range(0, rad * 0.7);
      final sp = r.range(15, 90);
      ps.spawn(
        P.smoke,
        x + math.cos(a) * d,
        y + math.sin(a) * d,
        math.cos(a) * sp,
        math.sin(a) * sp * 0.6 - 35.0,
        r.range(1.8, 2.8),
        0,
        r.range(rad * 0.26, rad * 0.4),
        r.range(0.12, 0.45),
        PF.big,
      );
    }
    for (var i = 0; i < (80 * power + 0.5).floor(); i++) {
      final a = r.range(0, tau);
      final sp = r.range(170, main ? 470 : 380);
      ps.spawn(
        P.spark,
        x,
        y,
        math.cos(a) * sp,
        math.sin(a) * sp - 70.0,
        r.range(0.2, 0.65),
      );
    }
    for (var i = 0; i < (30 * power + 0.5).floor(); i++) {
      final a = r.range(0, tau);
      final sp = r.range(30, 150);
      ps.spawn(
        P.ember,
        x + math.cos(a) * rad * 0.4,
        y + math.sin(a) * rad * 0.4,
        math.cos(a) * sp,
        math.sin(a) * sp - 75.0,
        r.range(1.4, 3),
        f[3],
      );
    }
    if (!main) return;
    for (var i = 0; i < 14; i++) {
      final a = -math.pi / 2 + r.range(-1.3, 1.3);
      final sp = r.range(160, 340);
      ps.spawn(
        P.brand,
        x,
        y,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(0.8, 1.5),
      );
    }
    for (var i = 0; i < 18; i++) {
      final s = r.sign();
      ps.spawn(
        P.smoke,
        s * r.range(0, _rad * 0.6),
        -r.range(1, 6),
        s * r.range(3, 9) * _rad,
        -r.range(2, 15),
        r.range(1.3, 2.2),
        st.dust,
        r.range(8, 12),
        r.range(0, 0.06),
        PF.big,
      );
    }
    for (var i = 0; i < (_earth * 12 + 0.5).floor(); i++) {
      ps.spawn(
        P.smoke,
        r.range(-0.3, 0.3) * _rad,
        -r.range(2, _rad * 0.6),
        r.range(-15, 15),
        -r.range(60, 190) * _earth * 0.6,
        r.range(1.6, 2.6),
        st.dust,
        r.range(8, 12),
        r.range(0, 0.15),
        PF.big,
      );
    }
    for (var i = 0; i < (_earth * _rad * 4 + 0.5).floor(); i++) {
      final u = r.range(-1, 1);
      final a = -math.pi / 2 + u * 0.55;
      final sp = r.range(5, 15) * _rad * (1.0 - 0.45 * u.abs());
      ps.spawn(
        P.grit,
        u * 0.25 * _rad,
        -1.0,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(1.4, 2.4),
        r.pick([st.light, st.body, st.body, st.shade]),
        r.chance(0.45) ? 2.0 : 1.0,
      );
    }
    for (var i = 0; i < 26; i++) {
      final big = i < 10;
      final hot = r.chance(0.45);
      final sx = r.sign();
      rocks.add(ExplosionBit(
        kind: B.chunk,
        x: r.range(-0.4, 0.4) * _rad,
        y: -4.0,
        vx: sx * r.range(30, big ? 120 : 150),
        vy: -r.range(big ? 280 : 320, big ? 480 : 560),
        g: 1.0,
        drag: 0.3,
        bounce: 0.3,
        life: r.range(3.6, 5),
        a: r.range(0, tau),
        va: r.range(-14, 14),
        s: big ? r.range(2.6, 3.8) : r.range(1.2, 2.4),
        heat: hot ? r.range(0.6, 1) : 0.0,
      ));
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    while (next < _blasts.length && t >= _blasts[next].t) {
      _blast(_blasts[next++]);
    }
    if (t > 0.08) plume.update(dt);
    final s = plume.shape();
    final k = 1.0 - smooth(2.2, 3.1, t);
    if (t > 0.2 && t < 3.1) {
      if (r.chance(8.0 * k * dt)) {
        ps.spawn(
          P.smoke,
          r.range(-10, 10),
          -r.range(1, 6),
          r.range(-8, 8),
          -r.range(40, 80),
          r.range(1.5, 2.3),
          st.dust,
          r.range(5, 8),
          0,
          PF.big,
        );
      }
      if (t < 1.5 && r.chance(16.0 * dt)) {
        ps.spawn(
          P.fire,
          r.range(-6, 6),
          -r.range(4, 14),
          r.range(-10, 10),
          -r.range(90, 150),
          r.range(0.5, 0.8),
          0,
          r.range(4, 7.5),
          0,
          r.chance(0.5) ? (PF.smokes | PF.big) : 0,
        );
      }
      if (t > 0.45 && r.chance(12.0 * k * dt)) {
        final sg = r.sign();
        ps.spawn(
          P.smoke,
          sg * r.range(40, 120),
          -r.range(1, 4),
          -sg * r.range(10, 30),
          -r.range(0, 5),
          r.range(1.3, 1.9),
          st.dust,
          r.range(3.5, 5.5),
          0,
          PF.big,
        );
      }
    }
    if (t > 0.3 && t < 3.0 && r.chance(10.0 * plume.hot() * dt)) {
      final a = r.range(0, tau);
      ps.spawn(
        P.ember,
        s.x + math.cos(a) * (s.ring + s.tube),
        s.y + math.sin(a) * s.tube * 0.5,
        math.cos(a) * r.range(40, 90),
        -r.range(10, 60),
        r.range(1.2, 2.4),
        f[3],
      );
    }
    if (t > 1.4 && t < 4.6 && r.chance(7.0 * dt)) {
      ps.spawn(
        P.flake,
        s.x + r.range(-1, 1) * (s.ring + s.tube),
        s.y + s.tube * 0.6,
        r.range(-6, 6),
        r.range(0, 10),
        r.range(2, 3),
        r.pick([_sm[1], _sm[2], f[2]]),
        r.range(0.6, 1.2),
      );
    }
    column.update(dt, _top(), t > 0.22 && t < 2.5 ? 1.0 : 0.0);
    updraft(
      ps,
      dt,
      x: 0.0,
      top: s.y + s.tube * 0.4,
      w: 9.0 + 7.0 * math.min(1.0, t),
      up: 170.0,
      pull: 130.0,
      low: 12.0,
      reach: 130.0,
      k: 1.0 - smooth(2.5, 3.8, t),
    );
    for (var i = flashes.length - 1; i >= 0; i--) {
      if ((flashes[i].life -= dt) <= 0.0) flashes.removeAt(i);
    }
    for (var i = rings.length - 1; i >= 0; i--) {
      if ((rings[i].life -= dt) <= 0.0) rings.removeAt(i);
    }
    for (final b in rocks.list) {
      (b as ExplosionBit).pvy = b.vy;
    }
    rocks.update(dt);
    for (var i = rocks.list.length - 1; i >= 0; i--) {
      final b = rocks.list[i] as ExplosionBit;
      if (b.x < x0 + 4.0 || b.x > x1 - 4.0) {
        rocks.list.removeAt(i);
        continue;
      }
      if (b.heat > 0.0) {
        b.heat = math.max(0.0, b.heat - dt * 0.3);
        if (!b.rest && b.heat > 0.25) {
          (b.pts ??= []).add((x: b.x, y: b.y, t: t));
          if (r.chance(14.0 * dt)) {
            ps.spawn(P.fire, b.x, b.y, b.vx * 0.1, b.vy * 0.1 - 8.0,
                r.range(0.16, 0.3), 0, r.range(1.2, 2.2));
          }
        } else if (b.rest && r.chance(3.0 * b.heat * dt)) {
          ps.spawn(P.smoke, b.x, b.y - 1.0, r.range(-3, 3), -r.range(5, 12),
              r.range(0.8, 1.4), 0, r.range(1.6, 2.6));
        }
      }
      final landed = (b.pvy > 0.0 && b.vy <= 0.0) || (b.rest && !b.dusted);
      if (landed && b.pvy > 60.0) {
        for (var j = 0; j < 2 + (b.size + 0.5).floor(); j++) {
          ps.spawn(
            P.dust,
            b.x + r.range(-1.5, 1.5),
            -0.5,
            r.sign() * r.range(10, 50),
            -r.range(2, 20),
            r.range(0.3, 0.7),
            st.dust,
            r.range(1.3, 1.0 + b.size),
          );
        }
        if (b.heat > 0.5 && !b.dusted) {
          blazes.add(b.x, -0.25, r.range(1.2, 2.2), 0.45);
        }
      }
      if (b.rest) b.dusted = true;
      final pts = b.pts;
      if (pts != null) {
        while (pts.isNotEmpty && t - pts[0].t > 0.45) {
          pts.removeAt(0);
        }
      }
    }
    blazes.update(dt);
    ps.update(dt);
    cullParticles(ps, x0, y0, x1, y1);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    scorch(p, hr, t, 52, 3.4,
        1.0 - smooth(meta.duration - 1.6, meta.duration - 0.3, t), 3);
    final k = t / 0.6;
    if (k < 1.0) {
      band(
        p,
        0,
        0.5,
        132.0 * Ease.outCubic(k),
        0.16,
        math.max(1.0, 6.0 * (1.0 - k)),
        1.15 - k,
        [st.body, st.light, f[3], f[6]],
        keep: (g) => math.sin(g) < 0.0,
      );
    }
    drawPs(p, ps, 'back', fr);
    column.draw(p, _top(), fr, _sm, 1.0 - t / 1.4, plume.hot());
    plume.draw(p, fr, _sm);
    blazes.drawBack(p);
  }

  @override
  void draw(Painter p) {
    final k = t / 0.6;
    if (k < 1.0) {
      band(
        p,
        0,
        0.5,
        132.0 * Ease.outCubic(k),
        0.16,
        math.max(1.0, 6.0 * (1.0 - k)),
        1.15 - k,
        [st.body, st.light, f[3], f[6]],
        keep: (g) => math.sin(g) >= 0.0,
      );
    }
    if (t < 0.04) {
      dome(p, f, 0, 44, 1);
      p.glow(0, -30, 68, kWhite, 0.6);
    } else if (t < 0.11) {
      dome(p, f, 0, 38.0 - (t - 0.04) * 120.0, 1.0 - (t - 0.04) / 0.07);
    }
    for (final b in rocks.list) {
      final rb = b as ExplosionBit;
      final pts = rb.pts;
      if (pts != null) {
        burnTrail(p, pts, t, fr, _sm, 0.45, 0.6 + rb.size * 0.3, rb.heat);
      }
      drawRock(p, rb, st, fr);
    }
    drawPs(p, ps, 'front', fr);
    if (t < 0.24) {
      flare(p, 0, -14, 70.0 * math.pow(1.0 - t / 0.24, 1.4).toDouble(),
          1.0 - t / 0.24, f);
    }
    if (t < 0.5) {
      final u = t / 0.5;
      final r = 34.0 + 80.0 * Ease.outCubic(u);
      p.ringShaded(
        0,
        0,
        r,
        math.max(1.0, 3.0 * (1.0 - u) + 0.5),
        color: (_, _) => u < 0.3 ? f[6] : (u < 0.6 ? f[5] : f[3]),
        alpha: (_, a) =>
            math.sin(a) > 0.0 ? 0.0 : math.min(1.0, (1.0 - u) * 1.6),
      );
      glowDome(p, 0, 0, r, 6, f[4], 0.35 * (1.0 - u));
    }
    for (final fl in flashes) {
      final k2 = fl.life / fl.max;
      final r = fl.r * (0.8 + 0.2 * k2);
      p.circle(fl.x, fl.y, r + 1.2, f[2]);
      p.circle(fl.x, fl.y, r, k2 > 0.45 ? f[6] : f[5]);
      p.circle(fl.x, fl.y, r * 0.6, k2 > 0.45 ? kWhite : f[6]);
    }
    for (final rg in rings) {
      final k2 = rg.life / rg.max;
      final e = 1.0 - math.pow(k2, 3).toDouble();
      p.ring(rg.x, rg.y, rg.r0 + (rg.r1 - rg.r0) * e,
          math.max(1.0, rg.thick * k2 + 0.4), rg.c, math.min(1.0, k2 * 1.6));
    }
    final hot = plume.hot();
    final flash = math.max(0.0, 1.0 - t / 0.9);
    lightPool(p, 0, 1, 150, 22, f[3], 0.24 * hot + 0.5 * flash * flash);
    lights.draw(p);
  }
}

const EffectMeta _bigExplosionMeta = EffectMeta(
  id: 'explosions/big-explosion',
  name: 'Big explosion',
  desc:
      'A huge ground blast in three beats: a white dome, a rolling fireball that climbs into a mushrooming smoke column, heavy rocks, and fires left burning.',
  category: 'explosions',
  tags: [
    'explosion',
    'fire',
    'smoke',
    'debris',
    'mushroom',
    'big',
    'ground',
    'one-shot',
  ],
  size: (360, 300),
  origin: (180, 262),
  duration: 7.2,
  loop: false,
  fps: 30,
  bg: BackdropKind.ground,
  defaultOptions: {
    'palette': [
      '#4a1712',
      '#c9281f',
      '#f2561d',
      '#ff8a2a',
      '#ffc23d',
      '#ffe26b',
      '#fff3a6',
      '#ffffff',
    ],
    'stone': '#4a3f69',
    'seed': 11,
  },
);

final SimulatedEffect bigExplosionEffect = SimulatedEffect(
  meta: _bigExplosionMeta,
  onCreate: (o) => _BigExplosionSim(_bigExplosionMeta, o),
);
