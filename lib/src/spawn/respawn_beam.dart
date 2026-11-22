import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'spawn_lib.dart';

const Pose _setPose = Pose(
  turn: 1,
  crouch: 4,
  fx: -9,
  fy: -14,
  bx: 10,
  by: -14,
  ffx: -3,
  fbx: 4,
);

const double _slam = 0.32;
const double _write0 = _slam + 0.08;
const double _write = 0.95;
const double _done = _write0 + _write;
const double _lift = _done + 0.12;
const double _drop = 0.07;
const int _topY = -136;

final PixelEffect respawnBeamEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'spawn/respawn-beam',
    name: 'Respawn beam',
    desc:
        'A guide line drops, a pillar of light slams onto the spot, and a scan bar climbs from the feet writing the character back in row by row, white-hot lines cooling to its colors.',
    category: 'spawn',
    tags: [
      'spawn',
      'respawn',
      'beam',
      'teleport',
      'scanline',
      'light',
      'one-shot',
    ],
    size: (128, 150),
    origin: (64, 136),
    duration: 2.5,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#061e1b',
        '#0c3e36',
        '#136a5a',
        '#1f9c80',
        '#45d1a8',
        '#a8f5d8',
        '#ffffff',
      ],
      'width': 15,
      'seed': 12,
    },
  ),
  act: const ActSpec(
    onBody: true,
    follow: 0,
    poses: [
      PoseKey(0, _setPose),
      PoseKey(1.4, _setPose),
      PoseKey(
        1.72,
        Pose(
          turn: 1.15,
          crouch: -1,
          fx: -13,
          fy: -36,
          bx: 14,
          by: -36,
          hy: -1,
          ffx: -3,
          fbx: 4,
        ),
      ),
      PoseKey(2.1, kReady),
      PoseKey(2.5, kReady),
    ],
  ),
  onActorAlpha: (t, _) => t < _done + 0.04 ? 0.0 : 1.0,
  onCreate: (o) => _RespawnBeamSim(o),
);

class _Strand {
  const _Strand({required this.o, required this.f, required this.w});

  final double o;
  final double f;
  final double w;
}

class _RespawnBeamSim extends BaseEffectSim {
  _RespawnBeamSim(Map<String, Object?> o) {
    cRamp = fit(o.palette, 7);
    rng = Rng(o.seed);
    bw = o.numOpt('width', 15);
    body = bodyOf(o.actor, cRamp);
    rim = rimOf(body);
    top = body.y;
    h = body.h;
    ps = Particles(
      rng: rng,
      ground: (_) => 0,
      sparks: [kWhite, cRamp[5], cRamp[4], cRamp[3]],
    );
    lights = Lights();
    strands = List.generate(
      6,
      (i) => _Strand(
        o: rand(i, 1) * 1.6 - 0.8,
        f: 1 + rand(i, 2) * 3,
        w: rand(i, 3),
      ),
    );
  }

  late final List<int> cRamp;
  late final Rng rng;
  late final double bw;
  late final BodyData body;
  late final List<RimCell> rim;
  late final int top;
  late final int h;
  late final Particles ps;
  late final Lights lights;
  late final List<_Strand> strands;
  double t = 0;
  bool slammed = false;
  bool finished = false;

  double _scanY(double t) =>
      -Ease.inOutSine(clamp((t - _write0) / _write)) * (h + 2);

  double _rowT(int my) =>
      _write0 +
      (_write * math.acos(1 - 2 * clamp((h - my) / (h + 2)))) / math.pi;

  double _width(double t) {
    if (t < _slam - _drop) return 0;
    if (t < _slam) return bw * 0.6;
    if (t < _lift) {
      return bw *
          (1 + 0.4 * math.exp(-(t - _slam) * 10)) *
          (0.92 + 0.08 * math.sin(t * 40));
    }
    return bw * (1 - Ease.outCubic(clamp((t - _lift) / 0.3)));
  }

  double _bottom(double t) =>
      t < _lift ? 0.0 : -150 * Ease.inCubic(clamp((t - _lift) / 0.4));

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t < _slam && rng.chance(0.5)) {
      final s = rng.sign();
      final d = rng.range(18, 40);
      final dur = rng.range(0.15, 0.25);
      final v = (d * 3) / (math.exp(3 * dur) - 1);
      ps.spawn(
        P.streak,
        s * d,
        -rng.range(0, 3),
        -s * v,
        0,
        dur,
        rng.chance(0.5) ? cRamp[5] : cRamp[4],
      );
    }
    if (!slammed && t >= _slam) {
      slammed = true;
      lights.add(0, -28, 64, cRamp[4], 1, 0.5);
      lights.add(0, -52, 80, cRamp[5], 1.1, 0.4);
      lights.add(0, -9, 24, kWhite, 0.9, 0.12);
      for (var i = 0; i < 40; i++) {
        final s = rng.sign();
        final sp = rng.range(60, 135);
        ps.spawn(
          P.spark,
          s * rng.range(0, 6),
          -1,
          s * sp,
          -rng.range(20, 140),
          rng.range(0.25, 0.7),
        );
      }
      for (var i = 0; i < 12; i++) {
        ps.spawn(
          P.star,
          rng.range(-bw, bw),
          -rng.range(2, 40),
          rng.range(-20, 20),
          -rng.range(20, 70),
          rng.range(0.5, 1),
          rng.pick([kWhite, cRamp[5]]),
          rng.range(0.8, 1.8),
        );
      }
      for (var i = 0; i < 8; i++) {
        final s = rng.sign();
        ps.spawn(
          P.dust,
          s * rng.range(4, 10),
          -1,
          s * rng.range(30, 80),
          -rng.range(3, 10),
          rng.range(0.4, 0.7),
          cRamp[2],
          rng.range(1.5, 3),
        );
      }
    }
    if (t > _write0 && t < _done && rng.chance(0.45)) {
      final y = _scanY(t);
      final s = rng.sign();
      ps.spawn(
        P.spark,
        s * rng.range(6, 11),
        y,
        s * rng.range(40, 140),
        rng.range(-60, 10),
        rng.range(0.15, 0.35),
      );
    }
    if (t > _slam && t < _lift + 0.2 && rng.chance(0.6)) {
      ps.spawn(
        P.star,
        rng.range(-1.3, 1.3) * bw,
        -rng.range(0, 90),
        rng.range(-6, 6),
        -rng.range(30, 90),
        rng.range(0.4, 0.9),
        rng.pick([kWhite, cRamp[5], cRamp[5], cRamp[4]]),
        rng.chance(0.3) ? rng.range(1, 1.8) : 0.6,
      );
    }
    if (!finished && t >= _done) {
      finished = true;
      lights.add(0, top + h / 2, 40, cRamp[5], 0.7, 0.3);
      for (var i = 0; i < 14; i++) {
        final c = rng.pick(rim);
        ps.spawn(
          P.star,
          c.x.toDouble(),
          c.y.toDouble(),
          rng.range(-25, 25),
          -rng.range(10, 50),
          rng.range(0.4, 0.9),
          rng.pick([kWhite, cRamp[5]]),
          rng.range(0.8, 1.8),
        );
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final w = _width(t);
    final b = _bottom(t);
    if (t < _slam) {
      final k = smooth(0, _slam * 0.7, t) * (1 - smooth(_slam - _drop, _slam, t) * 0.5);
      for (var y = _topY; y < -1; y += 2) {
        p.dot(
          0,
          (y + (t * 60).toInt() % 2).toDouble(),
          cRamp[5],
          k * (0.35 + 0.65 * ((y - _topY) / -_topY)),
        );
      }
      band(p, 0, 0, 10 - 4 * k, 0.2, 1, k, cRamp, keep: (double g) => math.sin(g) < 0);
      p.glow(0, -2, 16, cRamp[4], 0.4 * k);
    }
    if (w <= 0.2) return;
    final yEnd = t < _slam
        ? _topY + (-1 - _topY) * Ease.inCubic(clamp((t - _slam + _drop) / _drop))
        : -1 + b;
    final writing =
        smooth(_write0 - 0.05, _write0 + 0.1, t) * (1 - smooth(_done, _lift, t));
    final fill = 0.2 - 0.1 * writing;
    final core = 1 - smooth(_slam + 0.06, _write0 + 0.08, t);
    final fr = (t * 30).toInt();
    for (var y = _topY; y <= yEnd; y++) {
      for (var x = (-w).floor(); x <= w.ceil(); x++) {
        final q = ((x + 0.5) / w).abs();
        if (q > 1) continue;
        if (q > 0.86) {
          p.dot(
            x.toDouble(),
            y.toDouble(),
            q > 0.94 && rand(x, y, fr) < 0.7 ? kWhite : cRamp[5],
            1,
          );
          continue;
        }
        if (q < 0.7 * core) {
          var hot = q < 0.35 * core;
          for (final s in strands) {
            if (((x + 0.5) / w -
                        s.o * 0.6 -
                        0.05 * math.sin(t * s.f * 3 + y * 0.05))
                    .abs() <
                0.04) {
              hot = false;
            }
          }
          p.px(x, y, hot ? kWhite : (q < 0.5 * core ? cRamp[6] : cRamp[5]));
          continue;
        }
        var a = fill * (1.2 - q);
        var c = cRamp[4];
        for (final s in strands) {
          if (((x + 0.5) / w - s.o - 0.06 * math.sin(t * s.f + s.o * 7)).abs() <
              0.045 + 0.03 * s.w) {
            a = 0.55 - 0.25 * writing;
            c = cRamp[5];
          }
        }
        p.blend(x, y, c, a);
      }
    }
    if (yEnd > _topY + 24) {
      for (final s in const [-1, 1]) {
        p.glowLine(s * w, _topY + 24, s * w, yEnd, 6, cRamp[4], 0.3);
      }
    }
    p.glow(0, -5, w * 1.5 + 6, cRamp[5], 0.45);
  }

  @override
  void draw(Painter p) {
    final w = _width(t);
    final sk = (t - _slam) / 0.45;
    if (sk > 0 && sk < 1) {
      final rx = 14 + 18 * Ease.outCubic(sk);
      final ry = 3 + 1.5 * sk;
      p.ellipseShaded(
        0,
        0.5,
        rx,
        ry,
        color: (double d, _) => d < 0.4 ? kWhite : (d < 0.7 ? cRamp[6] : cRamp[5]),
        alpha: (double d, _) => (1 - sk) * 1.4 * (1 - d * d),
      );
      p.glow(0, -2, rx * 1.3, cRamp[5], 0.5 * (1 - sk));
    }
    for (var i = 0; i < 2; i++) {
      final k = (t - _slam - 0.08 * i) / 0.5;
      if (k > 0 && k < 1) {
        band(
          p,
          0,
          0,
          8 + (i != 0 ? 22 : 34) * Ease.outCubic(k),
          0.2,
          math.max(1.0, 3 * (1 - k)),
          1.15 - k,
          cRamp,
          keep: (_) => true,
          hot: k < 0.15,
        );
      }
    }
    if (t >= _write0 && t < _done + 0.05) {
      final sy = _scanY(t);
      final fr = (t * 30).floor();
      for (final b in body.list) {
        final t0 = _rowT(b.my);
        final age = t - t0;
        if (age < 0) continue;
        final glitch = age < 0.12 && rand(b.my, fr, 9) < 0.3
            ? (rand(b.my, fr, 4) < 0.5 ? -2 : 2)
            : 0;
        final c = age < 0.05
            ? kWhite
            : age < 0.14
                ? cRamp[5]
                : age < 0.3
                    ? mix(b.c, cRamp[5], 0.5 * (1 - (age - 0.14) / 0.16))
                    : b.c;
        p.px(b.x + glitch, b.y, b.edge && age < 0.3 ? cRamp[6] : c);
      }
      if (t < _done) {
        p.lineShaded(
          -w - 2,
          sy,
          w + 2,
          sy,
          color: (double u) => (u - 0.5).abs() < 0.35 ? kWhite : cRamp[5],
        );
        p.line(-w, sy + 1, w, sy + 1, cRamp[4], 0.6);
        p.glowLine(-w, sy, w, sy, 6, cRamp[5], 0.6);
      }
    }
    final fk = (t - _done) / 0.25;
    if (fk > 0 && fk < 1) {
      for (final c in rim) {
        p.dot(c.x.toDouble(), c.y.toDouble(), fk < 0.4 ? kWhite : cRamp[5], 1.2 - fk);
      }
      sparkle(
        p,
        6.0,
        (top + 6).toDouble(),
        (6 * (1 - fk) + 0.5).floorToDouble(),
        kWhite,
        cRamp[5],
        0.5,
      );
    }
    if (w > 0.2) {
      if (t >= _slam && t - _slam < 0.1) {
        p.glow(0, -30, 56, kWhite, 0.6 * (1 - (t - _slam) / 0.1));
      }
    }
    ps.draw(p);
    lights.draw(p);
  }
}
