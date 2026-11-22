import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'spawn_lib.dart';

const Pose _agony = Pose(
  turn: 1.15,
  crouch: 0,
  hy: -1,
  fx: -14,
  fy: -36,
  bx: 15,
  by: -36,
  ffx: -3,
  fbx: 4,
);

const double _flash = 0.42;
const double _whiteT = 0.07;
const double _p0 = _flash + _whiteT;
const double _peel = 1.2;
const double _coreY = -20;

final PixelEffect disintegrateEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'spawn/disintegrate',
    name: 'Disintegrate',
    desc:
        'The character crackles with light, flashes white, then peels away from the head down: each pixel flares white-hot and streams off on the wind as a cooling mote of light.',
    category: 'spawn',
    tags: [
      'spawn',
      'death',
      'disintegrate',
      'dissolve',
      'pixels',
      'energy',
      'light',
      'one-shot',
    ],
    size: (176, 100),
    origin: (48, 86),
    duration: 3.4,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#120a26',
        '#2a1658',
        '#3d2f9c',
        '#3f68d4',
        '#3fa8ec',
        '#86e0ff',
        '#d6f8ff',
        '#ffffff',
      ],
      'accent': ['#7a3ae4', '#b682ff', '#ecd2ff'],
      'wind': 1,
      'seed': 5,
    },
  ),
  act: const ActSpec(
    onBody: true,
    poses: [
      PoseKey(-0.2, kReady),
      PoseKey(
        0.05,
        Pose(turn: 1, crouch: 3, fx: -9, fy: -16, bx: 10, by: -16, ffx: -3, fbx: 4),
      ),
      PoseKey(0.3, _agony),
      PoseKey(3.4, _agony),
    ],
  ),
  onActorAlpha: (t, _) => t < _flash - 0.1 ? 1.0 : 0.0,
  onCreate: (o) => _DisintegrateSim(o),
);

class _Mote {
  _Mote({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.max,
    required this.c,
    required this.kind,
    required this.lift,
    required this.cool,
    required this.own,
    required this.seed,
  });

  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double max;
  final int c;
  final int kind;
  final double lift;
  final List<int> cool;
  final bool own;
  bool rest = false;
  final double seed;
}

class _DisintegrateSim extends BaseEffectSim {
  _DisintegrateSim(Map<String, Object?> o) {
    cRamp = fit(o.palette, 8);
    aRamp = fit(o.rampOpt('accent'), 3);
    rng = Rng(o.seed);
    w = o.numOpt('wind', 1);
    coolList = [
      [cRamp[6], cRamp[5], cRamp[5], cRamp[4]],
      [aRamp[2], aRamp[1], aRamp[1], aRamp[0]],
      [kWhite, cRamp[6], cRamp[5], cRamp[5]],
    ];
    body = bodyOf(o.actor, cRamp);
    rim = rimOf(body);
    top = body.y;
    h = body.h;
    ps = Particles(
      rng: rng,
      ground: (_) => 0,
      sparks: [cRamp[7], cRamp[6], cRamp[5], cRamp[3]],
    );
    lights = Lights();

    for (final b in body.list) {
      final u = (b.y - top) / h;
      b.key =
          u +
          0.14 * (rand(b.mx, b.my, 3) - 0.5) +
          0.05 * noise(b.mx * 0.45, 7) -
          (b.edge ? 0.03 : 0);
      b.gone = false;
    }
  }

  late final List<int> cRamp;
  late final List<int> aRamp;
  late final Rng rng;
  late final double w;
  late final List<List<int>> coolList;
  late final BodyData body;
  late final List<RimCell> rim;
  late final int top;
  late final int h;
  late final Particles ps;
  late final Lights lights;
  final List<_Mote> motes = [];
  double t = 0;
  bool flashed = false;

  double _front(double t) => -0.06 + 1.14 * Ease.inOutSine(clamp((t - _p0) / _peel));

  double _gust(double t) => 0.7 + 0.5 * (noise(t * 1.6, 11) * 0.5 + 0.5);

  void _letGo(BodyPixel b) {
    b.gone = true;
    final lo = b.y > -9 && rng.chance(0.22);
    final kind = lo
        ? 2
        : rng.chance(0.42)
            ? 1
            : rng.chance(0.07)
                ? 3
                : 0;
    if (kind == 3) {
      ps.spawn(
        P.star,
        b.x.toDouble(),
        b.y.toDouble(),
        rng.range(-6, 14) * w,
        rng.range(-26, -8),
        rng.range(0.6, 1.1),
        rng.chance(0.5) ? cRamp[6] : kWhite,
        rng.range(1, 2.2),
      );
      return;
    }
    final life = kind == 2
        ? rng.range(0.7, 1.2)
        : kind == 1
            ? rng.range(0.25, 0.5)
            : rng.range(0.9, 1.7);
    final out = (b.x + 0.5) * rng.range(2, 6);
    motes.add(
      _Mote(
        x: b.x + 0.5,
        y: b.y + 0.5,
        vx: (out + rng.range(-6, 16)) * (kind == 2 ? 0.4 : 1),
        vy: kind == 2 ? rng.range(-30, -8) : rng.range(-46, -8),
        life: life,
        max: life,
        c: b.c,
        kind: kind,
        lift: rng.range(0.4, 1.4),
        cool: coolList[rng.chance(0.3) ? 1 : (rng.chance(0.3) ? 2 : 0)],
        own: rng.chance(0.2),
        seed: rng.range(0, 100),
      ),
    );
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t < _flash - 0.05 && rng.chance(0.55)) {
      final a = rng.range(0, tau);
      final d = rng.range(22, 44);
      final dur = rng.range(0.16, 0.26);
      final v = (d * 3) / (math.exp(3 * dur) - 1);
      final x = math.cos(a) * d;
      final y = math.min(_coreY + math.sin(a) * d * 0.9, -3.0);
      final len = hypot(x, y - _coreY);
      final l = len == 0 ? 1.0 : len;
      ps.spawn(
        P.streak,
        x,
        y,
        (-x / l) * v,
        ((_coreY - y) / l) * v,
        dur,
        rng.chance(0.5) ? cRamp[6] : cRamp[5],
      );
    }
    if (!flashed && t >= _flash) {
      flashed = true;
      lights.add(0, _coreY, 64, cRamp[4], 0.85, 0.6);
      lights.add(0, _coreY, 30, kWhite, 0.8, 0.14);
      for (var i = 0; i < 14; i++) {
        final a = rng.range(0, tau);
        final sp = rng.range(50, 150);
        ps.spawn(
          P.star,
          rng.range(-6, 6),
          _coreY + rng.range(-10, 10),
          math.cos(a) * sp,
          math.sin(a) * sp * 0.7 - 25,
          rng.range(0.35, 0.8),
          rng.pick([kWhite, cRamp[6], cRamp[5]]),
          rng.range(0.6, 1.8),
        );
      }
    }
    if (t >= _p0) {
      final f = _front(t);
      for (final b in body.list) {
        if (!b.gone && b.key < f) _letGo(b);
      }
    }
    final g = _gust(t) * (1 - 0.55 * smooth(_p0 + _peel, _p0 + _peel + 1.2, t));
    for (var i = motes.length - 1; i >= 0; i--) {
      final m = motes[i];
      m.life -= dt;
      if (m.life <= 0) {
        motes.removeAt(i);
        continue;
      }
      if (m.kind == 2) {
        if (m.rest) continue;
        m.vx += (w * 30 * g - m.vx * 1.2) * dt;
        m.vy += 260 * dt - m.vy * 1.2 * dt;
        m.x += m.vx * dt;
        final ny = m.y + m.vy * dt;
        if (m.vy > 0 && ny >= -0.5) {
          if (m.vy > 50) {
            m.vy *= -0.35;
            m.vx *= 0.6;
            m.y = -0.6;
          } else {
            m.rest = true;
            m.y = -0.5;
          }
        } else {
          m.y = ny;
        }
        continue;
      }
      final age = m.max - m.life;
      final k = math.min(1.0, age / 0.15);
      final fx = w * (100 * g + 30 * noise2(m.x * 0.07, m.y * 0.07 - t * 0.8, 3)) * k;
      final fy = (-30 * m.lift + 42 * noise2(m.x * 0.06 + 40, m.y * 0.06 - t * 1.1, 5)) * k;
      final drag = m.kind == 1 ? 3.0 : 1.5;
      m.vx += (fx - m.vx * drag) * dt;
      m.vy += (fy - m.vy * drag) * dt;
      m.x += m.vx * dt;
      m.y += m.vy * dt;
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final k = (t - _flash) / 0.5;
    if (k > 0 && k < 1) {
      band(
        p,
        0,
        0,
        6 + 30 * Ease.outCubic(k),
        0.18,
        math.max(1.0, 3.5 * (1 - k)),
        1.15 - k,
        cRamp,
        keep: (double g) => math.sin(g) < 0,
        hot: k < 0.12,
      );
    }
    final pool =
        smooth(0.1, _flash, t) * (1 - smooth(_p0 + _peel * 0.8, _p0 + _peel + 0.6, t));
    if (pool > 0) p.glow(0, -1, 30, cRamp[4], 0.22 * pool);
  }

  @override
  void draw(Painter p) {
    final f = _front(t);
    if (t < _flash) {
      final k = t / _flash;
      final fr = (t * 30).floor();
      for (final c in rim) {
        final hVal = rand(c.mx * 61 + c.my, fr, 7);
        if (hVal < 0.12 + 0.62 * k * k) {
          p.px(
            c.x,
            c.y,
            k > 0.72 && rand(c.mx, c.my, fr) < 0.5
                ? kWhite
                : (hVal < 0.2 ? cRamp[6] : cRamp[5]),
          );
        }
      }
      p.glow(0, _coreY, 26, cRamp[4], 0.42 * k);
      p.glow(0, _coreY, 12, cRamp[6], 0.25 * k * k);
    }
    if (t >= _flash - 0.1) {
      final shake = t < _flash ? ((t * 60).floor() % 2 != 0 ? 1.0 : -1.0) * 0.6 : 0.0;
      final white = t >= _flash && t < _p0;
      for (final b in body.list) {
        if (b.gone) continue;
        final int c;
        if (white) {
          c = b.edge ? cRamp[6] : kWhite;
        } else if (t < _flash) {
          c = b.edge ? mix(b.c, cRamp[6], 0.7) : mix(b.c, cRamp[5], 0.25);
        } else {
          final d = b.key - f;
          final aboveCell = body.cell(b.mx, b.my - 1);
          final above = !body.on(b.mx, b.my - 1) || (aboveCell != null && aboveCell.gone);
          c = above && d < 0.06
              ? kWhite
              : d < 0.03
                  ? mix(b.c, cRamp[6], 0.7)
                  : d < 0.1
                      ? mix(b.c, cRamp[5], 0.4)
                      : b.edge
                          ? mix(b.c, cRamp[5], 0.5)
                          : mix(b.c, cRamp[4], 0.16);
        }
        p.px(b.x + shake, b.y, c);
      }
      if (white) {
        p.glow(0, _coreY, 34, cRamp[5], 0.7);
        sparkle(p, 0.0, _coreY - 3, 9.0, cRamp[6], cRamp[4], 0.5);
      }
    }
    if (t >= _p0 && f < 1.05) {
      final fy = top + clamp(f) * h;
      final k = 1 - smooth(0.85, 1.05, f);
      p.glowLine(-10, fy, 10, fy, 8, cRamp[5], 0.32 * k);
      p.glow(0, fy, 22, cRamp[4], 0.2 * k);
    }
    final k = (t - _flash) / 0.5;
    if (k > 0 && k < 1) {
      band(
        p,
        0,
        0,
        6 + 30 * Ease.outCubic(k),
        0.18,
        math.max(1.0, 3.5 * (1 - k)),
        1.15 - k,
        cRamp,
        keep: (double g) => math.sin(g) >= 0,
        hot: k < 0.12,
      );
    }
    for (final m in motes) {
      final age = m.max - m.life;
      final k2 = m.life / m.max;
      final a = k2 < 0.35 ? k2 / 0.35 : 1.0;
      int c;
      if (age < 0.034) {
        c = mix(m.c, kWhite, 0.55);
      } else if (age < 0.06) {
        c = kWhite;
      } else if (age < 0.15) {
        c = m.cool[0];
      } else {
        final u = (age - 0.15) / math.max(0.05, m.max - 0.15);
        final cc = m.cool[1 + math.min(2, (u * 3).floor())];
        c = m.own && u < 0.5 ? mix(m.c, cc, 0.55) : cc;
        if (m.kind == 0 && math.sin(t * 21 + m.seed) > 0.8) c = m.cool[0];
      }
      if (m.kind == 2) {
        p.dot(m.x, m.y, c, a);
        p.glow(m.x, m.y, 3, cRamp[5], 0.3 * k2);
        continue;
      }
      final sp = hypot(m.vx, m.vy);
      final denom = sp == 0 ? 1.0 : sp;
      final ux = m.vx / denom;
      final uy = m.vy / denom;
      if (sp > 30 && m.kind == 0) {
        p.dot(m.x - ux * 1.2, m.y - uy * 1.2, scaleColor(c, 0.6), a * 0.85);
      }
      if (sp > 85 && m.kind == 0) {
        p.dot(m.x - ux * 2.4, m.y - uy * 2.4, scaleColor(c, 0.4), a * 0.6);
      }
      p.dot(m.x, m.y, c, a);
      if (k2 > 0.15) {
        p.glow(m.x, m.y, 2.5, c, (m.kind == 1 ? 0.16 : 0.11) * k2);
      }
    }
    ps.draw(p);
    lights.draw(p);
  }
}
