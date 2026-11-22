import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart' hide star;

import 'impacts_lib.dart';

final Pose _brace = kReady.merge(
  const Pose(
    crouch: 4.0,
    lean: 2.0,
    fx: 13.0,
    fy: -28.0,
    bx: 6.0,
    by: -21.0,
    ffx: 9.0,
    fbx: -9.0,
  ),
);

final SimulatedEffect shieldBlockEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'impacts/shield-block',
    name: 'Shield block',
    desc:
        'A blow is caught on a half-dome of energy in front of the character: its diamond lattice flashes, a ripple runs over it, sparks glance off, then it blinks out cell by cell.',
    category: 'impacts',
    tags: [
      'impact',
      'block',
      'shield',
      'barrier',
      'energy',
      'ripple',
      'actor',
      'one-shot',
    ],
    size: (148, 104),
    origin: (40, 88),
    duration: 1.1,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#151a3d',
        '#212f6b',
        '#2c58aa',
        '#3a8bd8',
        '#62c8f4',
        '#a6ecff',
        '#dcfbff',
        '#ffffff',
      ],
      'sparks': ['#fff3a6', '#ffe26b', '#ff8a2a', '#f2561d'],
      'seed': 12,
    },
  ),
  act: ActSpec(
    poses: [
      const PoseKey(-0.36, kReady),
      PoseKey(-0.1, _brace),
      PoseKey(
        0.0,
        _brace.copyWith(
          x: -3.0,
          crouch: 6.0,
          lean: -2.0,
          fx: 10.0,
          fy: -26.0,
        ),
        PoseEase.snap,
      ),
      PoseKey(0.18, _brace.copyWith(x: -4.0, crouch: 5.0, lean: 0.0)),
      PoseKey(0.65, _brace.copyWith(x: -3.0)),
      PoseKey(1.1, kReady.copyWith(x: 0.0)),
    ],
    hits: const [HitSpec(t: 0.005, stop: 0.09, shake: 0.2, amp: 2.0)],
    dust: const [DustSpec(t: 0.01, x: -10.0, n: 6, dir: -1)],
  ),
  onCreate: (o) => _ShieldBlockSim(o),
);

const int _cx = 3;
const int _rx = 28;
const int _ry = 44;
const double _grid = 3.4;
const double _hitLon = 1.18;
const double _hitLat = 0.5;
const double _gone = 0.5;

(double, double) _onDome(double lon, double lat) => (
      _cx + _rx * math.cos(lat) * math.sin(lon),
      -_ry * math.sin(lat),
    );

class _ShieldBlockSim extends BaseEffectSim {
  static double _floor(double _) => 0.0;

  final List<int> c;
  final List<int> s;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  late final double hx;
  late final double hy;
  late final List<ImpactSpike> sp;
  double t = 0.0;

  _ShieldBlockSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        s = fit(
          (o['sparks'] as List?)?.cast<Object>() ??
              const ['#fff3a6', '#ffe26b', '#ff8a2a', '#f2561d'],
          4,
        ),
        r = Rng(o.seed) {
    ps = Particles(rng: r, ground: _floor, sparks: s);
    final (hitX, hitY) = _onDome(_hitLon, _hitLat);
    hx = hitX;
    hy = hitY;
    sp = spikes(
      r,
      8,
      0.2,
      len: (5.0, 8.0),
      w: (1.4, 1.9),
      fwd: 1.2,
      back: 0.3,
    );

    lights.add(hx, hy, 40.0, s[1], 0.7, 0.2);
    lights.add(hx, hy, 12.0, kWhite, 0.7, 0.06);

    final nA = math.atan2(
      -math.sin(_hitLat) / _ry,
      (math.cos(_hitLat) * math.sin(_hitLon)) / _rx,
    );
    for (var i = 0; i < 14; i++) {
      final a = nA + r.range(-1.2, 0.9);
      final v = r.range(130.0, 300.0);
      ps.spawn(
        P.spark,
        hx + 1.0,
        hy,
        math.cos(a) * v,
        math.sin(a) * v - 30.0,
        r.range(0.15, 0.42),
        kWhite,
        1.0,
        i > 10 ? r.range(0.01, 0.04) : 0.0,
      );
    }
  }

  void _dome(Painter p, bool back) {
    final fade = 1.0 - smooth(_gone + 0.35, _gone + 0.55, t);
    if (fade <= 0.0) return;
    for (var y = -_ry - 1; y < 0; y++) {
      for (var x = _cx; x <= _cx + _rx + 1; x++) {
        final u = (x + 0.5 - _cx) / _rx;
        final v = -(y + 0.5) / _ry;
        final q = u * u + v * v;
        if (q > 1.0 || u < 0.0 || v < 0.0) continue;
        final z = math.sqrt(1.0 - q) * (back ? -1.0 : 1.0);
        final lon = math.atan2(u, z);
        final lat = math.asin(clamp(v));
        final a = (lon + lat) * _grid;
        final b = (lon - lat) * _grid;
        final fa = a - a.floor();
        final fb = b - b.floor();
        final cell = rand(a.floor(), b.floor(), 31);
        final line = math.min(math.min(fa, 1.0 - fa), math.min(fb, 1.0 - fb)) <
            0.13;
        final gone = _gone + cell * 0.35;
        if (t > gone) continue;
        final d = math.acos(
          clamp(
            math.cos(lat) * math.cos(_hitLat) * math.cos(lon - _hitLon) +
                math.sin(lat) * math.sin(_hitLat),
            -1.0,
            1.0,
          ),
        );
        var hit = 0.0;
        const ripples = [(0.0, 1.0), (0.12, 0.55)];
        for (final (t0, k0) in ripples) {
          final k = t - t0;
          final front = k * 3.6;
          if (k < 0.0 || k > 0.55) continue;
          if ((d - front).abs() < 0.2) {
            hit = math.max(hit, k0 * (1.0 - k / 0.55));
          } else if (d < front) {
            hit = math.max(hit, 0.3 * k0 * (1.0 - k / 0.55));
          }
        }
        final rim = 1.0 - z.abs();
        final flash = t < 0.05;
        final blink = t > gone - 0.06;
        final sheen =
            ((fract(lat * 0.8 - lon * 0.3 - t * 1.6)) - 0.5).abs() < 0.05;
        if (back) {
          if (line) p.dot(x, y, c[3], 0.5 * fade);
          continue;
        }
        if (q > 0.9) {
          p.dot(x, y, flash || hit > 0.5 ? kWhite : c[6], fade);
        } else if (line) {
          p.dot(
            x,
            y,
            flash || blink || hit > 0.5
                ? kWhite
                : (hit > 0.2 || sheen
                    ? c[6]
                    : (rim > 0.7 ? c[5] : (rim > 0.35 ? c[4] : c[3]))),
            fade,
          );
        } else {
          p.blend(
            x,
            y,
            flash || hit > 0.35 ? c[6] : c[3],
            fade *
                math.min(
                  0.85,
                  (flash ? 0.35 : 0.1 + 0.25 * rim * rim) + hit * 0.65,
                ),
          );
        }
        if (((x * 7 + y * 3) & 15) == 0) {
          p.light(x, y, c[4], 0.15 + 0.5 * hit);
        }
      }
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t > _gone && t < _gone + 0.38 && r.chance(0.5)) {
      final lon = r.range(0.0, math.pi / 2.0);
      final lat = r.range(0.05, 1.4);
      final (x, y) = _onDome(lon, lat);
      ps.spawn(
        P.star,
        x,
        y,
        r.range(-10.0, 10.0),
        -r.range(10.0, 40.0),
        r.range(0.2, 0.36),
        r.chance(0.5) ? c[6] : c[5],
        r.range(0.6, 1.4),
      );
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    _dome(p, true);
  }

  @override
  void draw(Painter p) {
    _dome(p, false);
    final fade = 1.0 - smooth(_gone + 0.3, _gone + 0.55, t);
    if (fade > 0.0) {
      for (var x = _cx; x <= _cx + _rx; x++) {
        p.dot(
          x,
          0,
          t < 0.05 ? kWhite : c[5],
          fade * (0.6 + 0.4 * ((x - _cx) / _rx)),
        );
      }
    }
    if (t < 0.03) {
      star(p, hx, hy, sp, 1.0, 1.0, [s[3], s[0], s[1], kWhite], 1.0, 2.0);
    } else if (t < 0.06) {
      star(p, hx, hy, sp, 1.25, 0.55, [s[3], s[1], s[2], s[0]], 1.0, 2.0);
    }
    ps.draw(p);
    p.glow(
      _cx + _rx * 0.5,
      -_ry * 0.45,
      _ry * 0.9,
      c[4],
      0.2 * (1.0 - smooth(_gone, _gone + 0.55, t)) +
          0.35 * math.exp(-t / 0.08),
    );
    lights.draw(p);
  }
}
