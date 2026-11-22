// The fire puffs, sparks and embers are adapted from Sprite Fusion's open-source explosion
// (https://www.spritefusion.com/pixel-art-vfx/explosion), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'explosions_lib.dart';

const double _flash = 0.05;
const double _lift = 0.07;
const (double, double) _skirtWindow = (0.55, 1.75);

final List<int> _cap =
    ['#a0918c', '#7c6f6e', '#5f5458', '#40373f', '#271f27'].map(hex).toList();

class _VeilPuff {
  final double a, s, w, e, dx, dy;
  const _VeilPuff(this.a, this.s, this.w, this.e, this.dx, this.dy);
}

class _SkirtPuff {
  final double ph, v, s, w, e, dx, dy;
  const _SkirtPuff(this.ph, this.v, this.s, this.w, this.e, this.dx, this.dy);
}

class _NukeSim extends BaseEffectSim {
  final EffectMeta meta;
  final List<int> f, fr, dustRamp;
  final int dustCol;
  final Rng r;
  final int w, h, ox, oy;
  final double x0, x1, y0, y1;
  late final Particles ps;
  final Lights lights = Lights();
  late final Plume plume;
  late final PlumeColumn column;
  late final List<_VeilPuff> veil;
  late final List<_SkirtPuff> skirt;
  double t = 0.0;
  bool boomed = false;

  _NukeSim(this.meta, Map<String, Object?> o)
      : f = fit(o.palette, 8),
        fr = fireRamp(fit(o.palette, 8)),
        dustCol = hex(o['dust'] ?? '#8a7466'),
        dustRamp = [
          mix(hex(o['dust'] ?? '#8a7466'), kWhite, 0.22),
          hex(o['dust'] ?? '#8a7466'),
          mix(hex(o['dust'] ?? '#8a7466'), hex('#3a3040'), 0.35),
          mix(hex(o['dust'] ?? '#8a7466'), hex('#2a2330'), 0.6),
          mix(hex(o['dust'] ?? '#8a7466'), hex('#1c1720'), 0.8),
        ],
        r = Rng(o.seed),
        w = meta.size.$1,
        h = meta.size.$2,
        ox = meta.origin.$1,
        oy = meta.origin.$2,
        x0 = -meta.origin.$1 + 3.0,
        x1 = meta.size.$1 - meta.origin.$1 - 3.0,
        y0 = -meta.origin.$2 + 3.0,
        y1 = meta.size.$2 - meta.origin.$2 - 3.0 {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [f[6], f[5], f[3], f[2]],
    );
    plume = Plume(
      r,
      x: 0.0,
      y: -26.0,
      rise: 152.0,
      tauVal: 1.7,
      drift: 3.0,
      tube: (14.0, 26.0),
      ring: (4.0, 46.0),
      grow: 1.6,
      n: 50,
      size: (9.5, 14.5),
      swell: 0.45,
      spin: 2.4,
      spinTau: 2.4,
      heat: 1.25,
      cool: 0.42,
      under: 0.6,
      tilt: 0.16,
      squash: 0.48,
      fade: (6.0, 8.3),
      spread: 26.0,
      style: 1,
      inner: true,
      hollow: true,
      fray: (4.0, 1.6, 6.4),
    );
    plume.onFray = (x, y, rad, ux, uy) => ps.spawn(
          P.smoke,
          x,
          y,
          ux * r.range(10, 26),
          uy * r.range(4, 12) - r.range(2, 8),
          r.range(1, 1.7),
          _cap[r.intRange(0, 1)],
          rad * r.range(0.3, 0.45),
        );
    column = PlumeColumn(
      r,
      w: 3.5,
      foot: 22.0,
      speed: 125.0,
      size: (5.5, 7.0),
      n: 84,
      sway: 1.4,
      style: 1,
    );
    veil = List.generate(
      72,
      (i) => _VeilPuff(
        -math.pi * ((i + r.range(0.2, 0.8)) / 72.0),
        r.range(6, 10),
        r.range(0.97, 1.06),
        r.range(0.6, 1.3),
        r.range(-1, 1),
        r.range(-1, 0.2),
      ),
      growable: false,
    );
    skirt = List.generate(
      110,
      (_) => _SkirtPuff(
        r.range(0, tau),
        r.range(0, 1),
        r.range(5, 9),
        r.range(0.9, 1.06),
        r.range(0.6, 1.3),
        r.range(-1, 1),
        r.range(-1, 0.4),
      ),
      growable: false,
    );
  }

  double _top() {
    final s = plume.shape();
    return s.y + s.tube * 0.3;
  }

  void _boom() {
    lights.add(0, -60, 150, f[4], 0.7, 1.6);
    for (var i = 0; i < 26; i++) {
      final a = r.range(-math.pi, 0);
      final d = r.range(4, 22);
      final sp = r.range(40, 160);
      ps.spawn(
        P.fire,
        math.cos(a) * d,
        -26.0 + math.sin(a) * d,
        math.cos(a) * sp,
        math.sin(a) * sp * 0.7 - 30.0,
        r.range(0.6, 1.1),
        0,
        r.range(7, 12),
        0,
        r.chance(0.5) ? (PF.smokes | PF.big) : 0,
      );
    }
    for (var i = 0; i < 90; i++) {
      final a = r.range(-math.pi - 0.3, 0.3);
      final sp = r.range(200, 420);
      ps.spawn(
        P.spark,
        math.cos(a) * 18.0,
        -26.0 + math.sin(a) * 18.0,
        math.cos(a) * sp,
        math.sin(a) * sp - 60.0,
        r.range(0.3, 0.8),
      );
    }
    for (var i = 0; i < 50; i++) {
      final a = r.range(-math.pi, 0);
      final sp = r.range(30, 140);
      ps.spawn(
        P.ember,
        math.cos(a) * 20.0,
        -26.0 + math.sin(a) * 20.0,
        math.cos(a) * sp,
        math.sin(a) * sp - 60.0,
        r.range(1.6, 3.4),
        f[3],
      );
    }
    for (var i = 0; i < 120; i++) {
      final slow = i >= 92;
      final a = r.range(0, tau);
      final c = math.cos(a);
      final s = math.sin(a);
      final sp = slow ? r.range(110, 200) : r.range(240, 440);
      ps.spawn(
        P.smoke,
        c * 14.0,
        s * 14.0 * 0.16 - r.range(1, 3),
        c * sp,
        s * sp * (s > 0.0 ? 0.06 : 0.14) - r.range(0, slow ? 6 : 3),
        r.range(1.8, 3),
        dustCol,
        slow ? r.range(8, 11) : r.range(5, 9),
        r.range(0.05, 0.2),
      );
    }
    for (var i = 0; i < 40; i++) {
      final u = r.range(-1, 1);
      final a = -math.pi / 2 + u * 0.7;
      final sp = r.range(150, 380) * (1.0 - 0.4 * u.abs());
      ps.spawn(
        P.grit,
        u * 12.0,
        -1.0,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(1.2, 2),
        r.pick(dustRamp.sublist(0, 3)),
        r.chance(0.4) ? 2.0 : 1.0,
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (!boomed && t >= _lift) {
      boomed = true;
      _boom();
    }
    if (t >= _lift) plume.update(dt);
    final s = plume.shape();
    final hot = plume.hot();
    column.update(dt, _top(), t > 0.35 && t < 4.9 ? 1.0 : 0.0);
    if (t > 0.9 && t < 4.6 && r.chance(9.0 * dt)) {
      final sg = r.sign();
      ps.spawn(
        P.vapour,
        sg * r.range(50, 160),
        -r.range(2, 6),
        -sg * r.range(20, 45),
        -r.range(0, 6),
        r.range(1.2, 1.8),
        dustRamp[1],
        r.range(5, 8),
      );
    }
    if (t > 0.3 && t < 3.4 && r.chance(14.0 * hot * dt)) {
      final a = r.range(0, tau);
      ps.spawn(
        P.ember,
        s.x + math.cos(a) * (s.ring + s.tube),
        s.y + math.sin(a) * s.tube * 0.5,
        math.cos(a) * r.range(30, 80),
        -r.range(10, 50),
        r.range(1.4, 2.6),
        f[3],
      );
    }
    updraft(
      ps,
      dt,
      x: 0.0,
      top: s.y + s.tube * 0.3,
      w: 9.0,
      up: 160.0,
      pull: 120.0,
      low: 14.0,
      reach: 170.0,
      k: 1.0 - smooth(4.4, 5.4, t),
    );
    ps.update(dt);
    cullParticles(ps, x0, y0, x1, y1);
    fadeEdges(ps, x0, x1, 34.0, y1);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    if (t < _flash) return;
    final s = plume.shape();
    final k = (t - _lift) / 0.8;
    if (k > 0.0 && k < 1.0) {
      band(
        p,
        0,
        0.5,
        196.0 * Ease.outCubic(k),
        0.16,
        math.max(1.0, 5.0 * (1.0 - k)),
        1.15 - k,
        [dustRamp[2], dustRamp[0], f[5], f[7]],
        keep: (g) => math.sin(g) < 0.0,
      );
    }
    drawPs(p, ps, 'back', fr);
    _skirtDraw(p, t, s, veil, skirt, true);
    plume.draw(p, fr, _cap);
    final eVal = plume.ember();
    final gone = smooth(plume.fade.$1, plume.fade.$2 - 0.6, t - _lift);
    if (gone < 1.0) {
      final hy = s.y + s.tube * 0.42;
      final rx = s.ring * 0.7 + 5.0;
      final ry = s.tube * 0.28 + 2.0;
      haze(
        p,
        0,
        hy,
        rx,
        ry,
        (d) => d < 0.55 * eVal
            ? mix(_cap[4], fr[d < 0.3 * eVal ? 5 : 6], 0.75 * eVal)
            : _cap[4],
        (d) => (d < 0.6 ? 0.8 : (d < 0.85 ? 0.5 : 0.22)) * (1.0 - gone),
      );
    }
    column.draw(p, _top(), fr, dustRamp, clamp(1.0 - t / 1.8), eVal * 0.8);
    _skirtDraw(p, t, s, veil, skirt, false);
    lightPool(p, 0, 1, 140, 16, f[3], 0.3 * plume.hot());
  }

  @override
  void draw(Painter p) {
    if (t < _flash) {
      _wash(p, ox, oy, w, h, 0, -40, kWhite, 1.6);
      p.circle(0, -40, 64, kWhite);
      return;
    }
    final k = (t - _lift) / 0.8;
    if (k > 0.0 && k < 1.0) {
      band(
        p,
        0,
        0.5,
        196.0 * Ease.outCubic(k),
        0.16,
        math.max(1.0, 5.0 * (1.0 - k)),
        1.15 - k,
        [dustRamp[2], dustRamp[0], f[5], f[7]],
        keep: (g) => math.sin(g) >= 0.0,
      );
    }
    final fl = (t - _flash) / 0.13;
    if (fl < 1.0) {
      final r = 22.0 + 8.0 * fl;
      p.circle(0, -26, r + 1.5, f[2]);
      p.circle(0, -26, r, fl < 0.5 ? f[6] : f[5]);
      p.circle(0, -26, r * 0.62, fl < 0.5 ? kWhite : f[6]);
    }
    drawPs(p, ps, 'front', fr);
    final u = (t - _flash) / 0.7;
    if (u < 1.0) {
      final r = 30.0 + 250.0 * Ease.outCubic(u);
      const cy = -26.0;
      bool outOfBounds(double a) =>
          cy + math.sin(a) * r > 0.0 ||
          (math.cos(a) * r).abs() > ox - 3.0 ||
          cy + math.sin(a) * r < 3.0 - oy;
      p.ringShaded(
        0,
        cy,
        r,
        math.max(1.0, 2.5 * (1.0 - u)),
        color: (_, _) => u < 0.3 ? kWhite : f[6],
        alpha: (_, a) => outOfBounds(a) ? 0.0 : 1.1 - u,
      );
      glowDome(
        p,
        0,
        cy,
        r,
        7,
        f[5],
        0.3 * (1.0 - u),
        (3.0 - ox, 3.0 - oy, w - ox - 4.0, 0.0),
      );
    }
    final wVal = math.exp(-(t - _flash) / 0.13);
    if (wVal > 0.02) _wash(p, ox, oy, w, h, 0, -40, kWhite, 0.9 * wVal);
    lights.draw(p);
  }
}

void _wash(Painter p, int ox, int oy, int w, int h, double cx, double cy, int c,
    double k) {
  final rx = math.min(ox + cx, w - ox - cx) - 4.0;
  final up = oy + cy - 4.0;
  final down = h - oy - cy - 4.0;
  p.shade(-ox, -oy, w - ox - 1, h - oy - 1, (x, y, out) {
    final d = hypot((x - cx) / rx, (y - cy) / (y < cy ? up : down));
    out.l = c;
    out.k = k * (1.0 - smooth(0, 1, d));
    return null;
  });
}

void _skirtDraw(
  Painter p,
  double t,
  ({double x, double y, double tube, double ring, double g}) s,
  List<_VeilPuff> veil,
  List<_SkirtPuff> skirt,
  bool back,
) {
  final u = (t - _skirtWindow.$1) / (_skirtWindow.$2 - _skirtWindow.$1);
  if (u <= 0.0 || u >= 1.0) return;
  final a = math.min(1.0, u / 0.06) *
      math.pow(1.0 - u, 1.5).toDouble() *
      0.6;
  final capR = (s.ring + s.tube) * 1.1;
  final y0 = s.y + s.tube * 0.3;
  final y1 = s.y * 0.55;
  if (!back) {
    for (final q in veil) {
      final ev = u * u * q.e;
      final r = capR * q.w * (1.0 + ev * 0.2);
      p.disc(
        math.cos(q.a) * r + q.dx * ev * 10.0,
        s.y + math.sin(q.a) * (s.tube * 1.15 + 6.0) * q.w + q.dy * ev * 8.0,
        q.s * (1.0 - 0.5 * u),
        kWhite,
        a * 0.38,
      );
    }
  }
  for (final q in skirt) {
    final z = math.sin(q.ph);
    if ((z < 0.0) != back) continue;
    final r = lerp(capR * 0.82, 13.0, math.pow(q.v, 0.6).toDouble()) * q.w;
    final ev = u * u * q.e;
    final x = math.cos(q.ph) * r * (1.0 + ev * 0.25) + q.dx * ev * 10.0;
    final y = lerp(y0, y1, q.v) + z * r * 0.18 + q.dy * ev * 8.0;
    p.disc(
      x,
      y,
      q.s * (1.0 - 0.55 * u),
      kWhite,
      a * (back ? 0.3 : 0.55) * (1.0 - q.v * 0.3),
    );
  }
  if (u < 0.7) {
    const r = 13.0 * 1.25;
    final k = 1.0 - u / 0.7;
    for (var i = 0; i < 64; i++) {
      final g = (i / 64.0) * tau;
      final z = math.sin(g);
      if ((z < 0.0) != back) continue;
      p.dot(
        math.cos(g) * r * (1.0 + u * 0.6),
        y1 + 2.0 + z * r * 0.22,
        kWhite,
        k * (back ? 0.6 : 1.0),
      );
    }
  }
}

const EffectMeta _nukeMeta = EffectMeta(
  id: 'explosions/nuke',
  name: 'Nuke',
  desc:
      'A blinding white frame, then a fireball lifts on a thin stem into a wide rolling cap that glows from inside; a white skirt flashes and a dust surge sweeps the floor.',
  category: 'explosions',
  tags: ['explosion', 'nuke', 'mushroom', 'cloud', 'big', 'ground', 'one-shot'],
  size: (400, 320),
  origin: (200, 284),
  duration: 9,
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
    'dust': '#8a7466',
    'seed': 5,
  },
);

final SimulatedEffect nukeEffect = SimulatedEffect(
  meta: _nukeMeta,
  onCreate: (o) => _NukeSim(_nukeMeta, o),
);
