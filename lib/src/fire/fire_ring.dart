// The flame-puff, smoke and spark recipe and the floor ring are adapted from Sprite Fusion's open-source explosion
// (https://www.spritefusion.com/pixel-art-vfx/explosion), and the tongue from its fire
// (https://www.spritefusion.com/pixel-art-vfx/fire), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'fire_lib.dart';

const double _sy = 0.2;
const double _charge = 0.32;
const double _spread = 0.75;
final int _soot = hex('#0d0a12');
final int _soot2 = hex('#17121d');
final int _warm = rgb(255, 176, 96);

const List<(double, double, int)> _emberLayers = [
  (1.0, 1.0, 7),
  (0.7, 0.8, 6),
  (0.4, 0.55, 5),
];

const _high = Pose(
  turn: 1.15,
  crouch: 0,
  fx: -7,
  fy: -44,
  bx: 8,
  by: -44,
  ffx: -5,
  fbx: 6,
);
const _slam = Pose(
  turn: 1.15,
  crouch: 8,
  lean: 3,
  fx: -9,
  fy: -8,
  bx: 11,
  by: -8,
  ffx: -8,
  fbx: 9,
);
const _easePose = Pose(
  turn: 1,
  crouch: 2,
  fx: -8,
  fy: -17,
  bx: 9,
  by: -17,
  ffx: -4,
  fbx: 5,
);

class _FlameSite {
  final double x, y, t0, life, h, w;
  final bool back;
  final int n;
  _FlameSite(
      this.x, this.y, this.back, this.t0, this.life, this.h, this.w, this.n);
}

class _FireRingSim extends BaseEffectSim {
  final List<int> h;
  final double reach;
  final Rng r;
  final int s;
  late final Particles ps;
  final Lights lights = Lights();
  late final int glowCol;
  final List<_FlameSite> sites = [];
  double t = 0.0;
  bool burst = false;

  _FireRingSim(Map<String, Object?> o)
      : h = hotFirst(fit(o.palette, 9)),
        reach = o.numOpt('reach', 92.0),
        r = Rng(o.seed),
        s = o.seed * 7 {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [h[1], h[2], h[4], h[5]],
    );
    glowCol = mix(mix(h[3], h[4], 0.5), kWhite, 0.25);

    double reachedAt(double d) =>
        _charge +
        _spread * (1.0 - math.pow(1.0 - math.min(1.0, d / reach), 1.0 / 3.0));

    for (var rad = 10.0; rad <= reach; rad += 9.0) {
      final per = tau * math.sqrt((rad * rad + (rad * _sy) * (rad * _sy)) / 2.0);
      final n = math.max(5, (per / 8.5 + 0.5).floor());
      for (var k = 0; k < n; k++) {
        final a = ((k + r.range(0.15, 0.85)) / n) * tau;
        final rr = rad + r.range(-3.0, 3.0);
        final q = math.min(1.0, rr / reach);
        sites.add(
          _FlameSite(
            math.cos(a) * rr,
            math.sin(a) * rr * _sy,
            math.sin(a) < 0.0,
            reachedAt(rr) + r.range(0.0, 0.04),
            (0.3 + 1.0 * q * q) * r.range(0.85, 1.2),
            r.range(9.0, 15.0) * (0.6 + 0.55 * q),
            r.range(1.8, 2.7) * (0.75 + 0.3 * q),
            r.intRange(0, 100000),
          ),
        );
      }
    }
    sites.sort((a, b) => a.y.compareTo(b.y));
  }

  double _front(double tt) =>
      reach * Ease.outCubic(clamp((tt - _charge) / _spread));

  double _reachedAt(double d) =>
      _charge +
      _spread * (1.0 - math.pow(1.0 - math.min(1.0, d / reach), 1.0 / 3.0));

  void _flames(Painter p, bool back) {
    double nz(double rate, [int seed = 0, double off = 0.0]) =>
        noise(t * rate + off, seed);
    for (final site in sites) {
      if (site.back != back) continue;
      final age = t - site.t0;
      if (age < 0.0 || age > site.life) continue;
      final u = age / site.life;
      final rise = Ease.outBack(clamp(age / 0.08), 2.0);
      final fade =
          1.0 - math.pow(math.max(0.0, (u - 0.1) / 0.9), 1.3).toDouble();
      final fh = site.h *
          rise *
          fade *
          (0.85 + 0.15 * noise(t * 3.3, site.n)) *
          (1.0 + 0.5 * math.max(0.0, noise(t * 2.6, site.n + 70) - 0.55));
      if (fh < 1.0) continue;
      final l = u < 0.3
          ? (back ? fireBackLayers : fireLayers)
          : (u < 0.65 ? fireBackLayers : _emberLayers);
      flameTongue(
        p,
        site.x,
        site.y,
        fh,
        site.w * (0.6 + 0.4 * fade),
        nz(2.2, site.n + 40) * 1.5 - site.x * 0.02,
        nz,
        site.n,
        h,
        layers: l,
      );
    }
  }

  void _scorch(Painter p) {
    final fr = _front(t);
    final end = 1.0 - smooth(3.9 - 1.2, 3.9 - 0.15, t);
    if (fr < 1.0 || end <= 0.0) return;
    final y0 = (-fr * _sy).floor();
    final y1 = (fr * _sy).ceil();
    final x0 = (-fr).floor();
    final x1 = fr.ceil();
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final d = hypot(x + 0.5, (y + 0.5) / _sy);
        if (d > fr) continue;
        final since = t - _reachedAt(d);
        final hv = rand(x, y, s);
        final hot = 1.0 - since / (1.2 + hv * 0.9);
        if (hot > 0.0 && hv < 0.03 + 0.06 * hot) {
          p.px(
            x,
            y,
            hot > 0.7
                ? h[3]
                : hot > 0.45
                    ? h[4]
                    : hot > 0.2
                        ? h[5]
                        : h[6],
          );
          p.light(x, y, h[4], 0.3 * hot);
          continue;
        }
        p.blend(
          x,
          y,
          hv < 0.5 ? _soot : _soot2,
          math.min(1.0, since * 3.0) * (0.55 - (d / reach) * 0.25) * end,
        );
      }
    }
  }

  void _ring(Painter p, bool back) {
    final k = (t - _charge) / (_spread + 0.1);
    if (k < 0.0 || k >= 1.0) return;
    band(
      p,
      0,
      0,
      _front(t) + 1.5,
      _sy,
      math.max(1.5, 6.0 * (1.0 - k)),
      k < 0.75 ? 1.0 : (1.0 - k) / 0.25,
      [h[6], h[4], h[2], h[1]],
      keep: (double g) => (math.sin(g) < 0.0) == back,
      hot: k < 0.12,
    );
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t < _charge - 0.05 && r.chance(0.9 * dt * 60.0)) {
      final a = r.range(0.0, tau);
      final d = r.range(26.0, 54.0);
      final dur = r.range(0.18, 0.26);
      final v = (d * 3.0) / (math.exp(3.0 * dur) - 1.0);
      final x = math.cos(a) * d;
      final y = math.min(-2.0, -6.0 + math.sin(a) * d * 0.45);
      final rawL = hypot(x, y + 4.0);
      final l = rawL == 0.0 ? 1.0 : rawL;
      ps.spawn(
        P.streak,
        x,
        y,
        (-x / l) * v,
        ((-4.0 - y) / l) * v,
        dur,
        r.chance(0.5) ? h[2] : h[3],
      );
    }
    if (t < _charge && r.chance(0.5 * dt * 60.0 * (t / _charge))) {
      ps.spawn(
        P.fire,
        r.range(-4.0, 4.0),
        -1.0,
        r.range(-8.0, 8.0),
        -r.range(20.0, 40.0),
        r.range(0.12, 0.24),
        0,
        r.range(1.0, 2.2),
      );
    }
    if (!burst && t >= _charge) {
      burst = true;
      lights.add(0, -18, 64, _warm, 0.85, 0.5);
      lights.add(0, -6, 30, kWhite, 0.8, 0.08);
      for (var i = 0; i < 40; i++) {
        final a = r.range(0.0, tau);
        final sp = r.range(80.0, 220.0);
        ps.spawn(
          P.spark,
          math.cos(a) * 3.0,
          -2.0,
          math.cos(a) * sp,
          math.sin(a) * sp * 0.4 - r.range(40.0, 120.0),
          r.range(0.2, 0.5),
        );
      }
    }
    if (t > _charge && t < _charge + _spread + 1.2) {
      for (var i = 0; i < 3; i++) {
        if (!r.chance(0.75 * dt * 60.0)) continue;
        final site = r.pick(sites);
        final age = t - site.t0;
        if (age < 0.0 || age > site.life * 0.7) continue;
        final backFlag = site.back ? PF.back : 0;
        ps.spawn(
          P.fire,
          site.x + r.range(-1.0, 1.0),
          site.y - site.h * 0.6,
          r.range(-5.0, 5.0),
          -r.range(20.0, 40.0),
          r.range(0.2, 0.4),
          0,
          r.range(1.2, 2.4),
          0.0,
          r.chance(0.5) ? (PF.smokes | backFlag) : backFlag,
        );
        if (r.chance(0.12)) {
          ps.spawn(
            P.ember,
            site.x,
            site.y - site.h * 0.5,
            r.range(-15.0, 15.0),
            -r.range(30.0, 70.0),
            r.range(0.6, 1.3),
            h[3],
            1.0,
            0.0,
            backFlag,
          );
        }
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    _scorch(p);
    _ring(p, true);
    _flames(p, true);
    simDraw(p, ps, h, 'back');
    final fr = _front(t);
    final k = t < _charge
        ? 0.0
        : 1.0 - smooth(_charge + _spread, _charge + _spread + 1.4, t);
    if (k > 0.0) {
      for (var i = 0; i < 16; i++) {
        p.glow(
          math.cos((i / 16.0) * tau) * fr,
          math.sin((i / 16.0) * tau) * fr * _sy - 3.0,
          16,
          glowCol,
          0.2 * k,
        );
      }
    }
  }

  @override
  void draw(Painter p) {
    _ring(p, false);
    _flames(p, false);
    simDraw(p, ps, h, 'front');
    if (t < _charge) {
      p.glow(0, -3, 8 + 22 * (t / _charge), glowCol, 0.6 * (t / _charge));
    }
    if (t >= _charge && t < _charge + 0.1) {
      final k = 1.0 - (t - _charge) / 0.1;
      p.ellipse(0, -1, 14 * (0.6 + 0.4 * k), 4, h[2]);
      p.ellipse(0, -1, 9 * (0.6 + 0.4 * k), 2.6, k > 0.5 ? kWhite : h[1]);
    }
    final k = smooth(_charge - 0.05, _charge, t) *
        (1.0 - smooth(_charge + _spread * 0.5, _charge + _spread + 1.2, t));
    if (k > 0.0) p.glow(0, -6, 92, glowCol, 0.3 * k);
    lights.draw(p);
  }
}

final SimulatedEffect fireRingEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'fire/fire-ring',
    name: 'Fire ring',
    desc:
        'A white flash at the feet, then flames race outward along the floor in a ring, flaring as the front passes and burning down behind it over a smouldering scorch.',
    category: 'fire',
    tags: ['fire', 'ring', 'nova', 'aoe', 'spell', 'ground', 'one-shot'],
    size: (224, 128),
    origin: (112, 92),
    duration: 3.9,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#4a1712', '#8a1f17', '#c9281f', '#f2561d',
        '#ff8a2a', '#ffc23d', '#ffe26b', '#fff3a6', '#ffffff',
      ],
      'reach': 92,
      'seed': 6,
    },
  ),
  act: ActSpec(
    target: const TargetSpec(x: 70),
    poses: [
      const PoseKey(-0.32, kReady),
      const PoseKey(0.02, _high),
      PoseKey(0.27, _high.copyWith(y: -1)),
      const PoseKey(0.32, _slam, PoseEase.snap),
      PoseKey(0.85, _slam.copyWith(crouch: 7)),
      const PoseKey(1.5, _easePose),
      const PoseKey(2.4, kReady),
      const PoseKey(3.9, kReady),
    ],
    hits: const [
      HitSpec(t: 0.32, stop: 0.1, shake: 0.28, amp: 3, target: false),
      HitSpec(t: 0.6, push: 1.2, straw: 10, y: -8, skin: 'char'),
      HitSpec(t: 3.5, push: 0, straw: 0, flash: 0, clearSkin: true),
    ],
    dust: const [
      DustSpec(t: 0.32, x: 10, n: 6, dir: 1),
      DustSpec(t: 0.32, x: -10, n: 6, dir: -1),
    ],
  ),
  onCreate: (o) => _FireRingSim(o),
);
