import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'holy_lib.dart';

const Pose _brace = Pose(
  turn: 0.7,
  crouch: 3,
  lean: 1,
  fx: 5,
  fy: -33,
  bx: 10,
  by: -20,
  ffx: 4,
  fbx: -2,
);

const double _dur = 2.4;
const double _cy = -22.0;
const double _tilt = 0.34;
const int _nMeridians = 4;
const double _floorSy = 0.26;

(double x, double y, double z) _onSphere(double r, double lat, double lon) {
  final x3 = r * math.cos(lat) * math.sin(lon);
  final y3 = r * math.sin(lat);
  final z3 = r * math.cos(lat) * math.cos(lon);
  return (
    x3,
    _cy - (y3 * math.cos(_tilt) - z3 * math.sin(_tilt)),
    y3 * math.sin(_tilt) + z3 * math.cos(_tilt),
  );
}

// The sheen: a diagonal band crossing the bubble once a loop, then a rest.
double _sheen(double t, double dur) =>
    -1.7 + 3.4 * clamp(((t / dur) % 1.0) / 0.55);

void _lattice(
  Painter p,
  double t,
  Map<String, Object?> o,
  bool back,
) {
  final c = fit(o.palette, 8);
  final r = o.numOpt('radius', 29.0);
  final phi = (t / _dur) * (math.pi / _nMeridians);
  final sw = _sheen(t, _dur);
  final seen = <int, (double x, double y, double f, int hot)>{};

  void dot(double x, double y, double z) {
    if ((z < 0.0) != back) return;
    final key = x.floor() * 1000 + y.floor();
    final f = z.abs() / r;
    final q = (x - (y - _cy)) / (r * 1.414);
    final hot = (q - sw).abs() < 0.12 ? 1 : 0;
    final v = seen[key];
    if (v == null || f < v.$3) {
      seen[key] = (x, y, f, hot != 0 ? 1 : (v != null ? v.$4 : 0));
    }
  }

  // Meridians, turning.
  for (var k = 0; k < 2 * _nMeridians; k++) {
    final lon = phi + (k * math.pi) / _nMeridians;
    for (var lat = -math.pi / 2.0; lat <= math.pi / 2.0; lat += 0.7 / r) {
      final (x, y, z) = _onSphere(r, lat, lon);
      dot(x, y, z);
    }
  }
  // The equator.
  for (var lon = 0.0; lon < tau; lon += 0.7 / r) {
    final (x, y, z) = _onSphere(r, 0.0, lon);
    dot(x, y, z);
  }
  for (final (x, y, f, hot) in seen.values) {
    if (back) {
      p.blend(x, y, c[4], 0.32);
    } else if (hot != 0) {
      p.px(x, y, kWhite);
    } else if (f < 0.4) {
      p.px(x, y, c[6]);
    } else {
      p.blend(x, y, f < 0.7 ? c[6] : c[5], f < 0.7 ? 0.8 : 0.55);
    }
  }
}

void _film(Painter p, double t, Map<String, Object?> o, bool back) {
  final c = fit(o.palette, 8);
  final r = o.numOpt('radius', 29.0);
  final sw = _sheen(t, _dur);
  p.each(-r - 1.0, _cy - r - 1.0, r + 1.0, _cy + r + 1.0, (x, y, sx, sy) {
    final d = hypot(x, y - _cy) / r;
    if (d >= 1.0) return;
    final q = (x - (y - _cy)) / (r * 1.414);
    final hot = math.max(0.0, 1.0 - (q - sw).abs() / 0.22);
    final a = (back ? 0.07 : 0.03) +
        0.26 * math.pow(d, 6).toDouble() +
        0.2 * hot * (back ? 0.3 : 1.0);
    p.blendPx(sx, sy, hot > 0.5 && !back ? c[6] : c[5], a);
  });
}

final PureEffect divineShieldEffect = PureEffect(
  meta: const EffectMeta(
    id: 'holy/divine-shield',
    name: 'Divine shield',
    desc:
        'A bubble of gold light round the character: a bright rim and a thin gold film, meridians turning like a slow globe, a sheen sweeping across and sparkles winking on it.',
    category: 'holy',
    tags: ['holy', 'shield', 'bubble', 'barrier', 'buff', 'character', 'loop'],
    size: (88, 84),
    origin: (44, 68),
    duration: _dur,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'palette': kHolyGold, 'radius': 29, 'seed': 8},
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      const PoseKey(0.0, _brace),
      PoseKey(0.6, _brace.copyWith(crouch: 4)),
      PoseKey(1.2, _brace.copyWith(fy: -35, crouch: 3)),
      PoseKey(1.8, _brace.copyWith(crouch: 4)),
      const PoseKey(2.4, _brace),
    ],
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final r = o.numOpt('radius', 29.0);
    final rf = math.sqrt(r * r - _cy * _cy);
    _film(p, t, o, true);
    _lattice(p, t, o, true);
    // Where it meets the floor: the far half of a bright seal.
    oval(p, 0, 0, rf, rf * _floorSy, c[5], 0.8, farHalf);
    p.glow(0, _cy, r * 1.1, c[4], 0.14);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final r = o.numOpt('radius', 29.0);
    final rf = math.sqrt(r * r - _cy * _cy);
    final a = o['actor'] as ActorDefinition?;
    final seed = o.seed;

    // The bubble lights the character from all round.
    if (a != null) {
      for (final (x, y) in shapeOf(a).out) {
        p.light(x, y, c[5], 0.3);
      }
    }
    _film(p, t, o, false);
    _lattice(p, t, o, false);

    // The rim: bright where the light sits (top left) and where the sheen crosses it.
    final sw = _sheen(t, _dur);
    final n = (r * tau * 1.4).ceil();
    for (var j = 0; j < n; j++) {
      final g = (j / n) * tau;
      final x = math.cos(g) * r;
      final y = _cy + math.sin(g) * r;
      final q = (x - (y - _cy)) / (r * 1.414);
      final lit = math.cos(g + 2.36);
      final hot = (q - sw).abs() < 0.15;
      p.dot(
        x,
        y,
        hot || lit > 0.75 ? kWhite : (lit > -0.2 ? c[6] : c[5]),
        1.0,
      );
      p.dot(
        math.cos(g) * (r - 1.0),
        _cy + math.sin(g) * (r - 1.0),
        c[4],
        0.35 + 0.3 * lit,
      );
    }
    p.glowRing(0, _cy, r, 6, c[4], 0.32);

    // Where the meridians cross the equator, and at the pole they all turn round, the lattice catches the light.
    final phi = (t / _dur) * (math.pi / _nMeridians);
    for (var k = 0; k < 2 * _nMeridians; k++) {
      final (x, y, z) = _onSphere(r, 0.0, phi + (k * math.pi) / _nMeridians);
      if (z < r * 0.15) continue;
      p.px(x, y, kWhite);
      if (z > r * 0.45) {
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          p.blend(x + dx, y + dy, c[6], 0.7);
        }
      }
      p.glow(x, y, 4, c[5], 0.3);
    }
    final (px0, py0, _) = _onSphere(r, math.pi / 2.0, 0.0);
    sparkle(
      p,
      px0,
      py0,
      2.0 + holyRound(1.5 + 1.5 * math.sin((t / _dur) * tau * 2.0)),
      kWhite,
      c[6],
      0.45,
    );

    // Two glints chase each other round the rim.
    for (final off in const [0.0, math.pi]) {
      final g = (t / _dur) * tau + off + 0.8;
      sparkle(
        p,
        math.cos(g) * r,
        _cy + math.sin(g) * r,
        2,
        kWhite,
        c[6],
        0.4,
      );
    }

    // A bubble's shine: a bright curl up on the left, a dot under it, a faint one low on the right.
    for (var g = 3.55; g < 4.2; g += 0.04) {
      p.px(
        math.cos(g) * r * 0.74,
        _cy + math.sin(g) * r * 0.74,
        g > 3.7 && g < 4.05 ? kWhite : c[6],
      );
    }
    p.px(math.cos(3.4) * r * 0.62, _cy + math.sin(3.4) * r * 0.62, kWhite);
    for (var g = 0.45; g < 0.8; g += 0.05) {
      p.dot(
        math.cos(g) * r * 0.8,
        _cy + math.sin(g) * r * 0.8,
        c[5],
        0.6,
      );
    }

    // The near half of the floor seal and a pool of light.
    ovalShaded(
      p,
      0,
      0,
      rf,
      rf * _floorSy,
      color: (g) => math.sin(g) > 0.6 ? kWhite : c[6],
      keep: nearHalf,
    );
    for (var i = -2; i <= 2; i++) {
      p.glow(i * rf * 0.5, 0, 12, c[4], 0.18);
    }

    // Sparkles winking on its skin as it turns, motes rising inside.
    cycle(t, _dur, 9, seed, (g) => g.range(0.35, 0.6), (age, life, rr, _) {
      final lat = rr.range(-1.2, 1.3);
      final lon = rr.range(0.0, tau) + phi;
      final (x, y, z) = _onSphere(r, lat, lon);
      final k = math.sin((age / life) * math.pi);
      if (z < 0.0) return;
      sparkle(
        p,
        x,
        y,
        1.0 + 2.5 * k * rr.range(0.6, 1.0),
        kWhite,
        c[6],
        0.45 * k,
      );
    });
    cycle(t, _dur, 12, seed + 1, (g) => g.range(1.2, 2.2),
        (age, life, rr, _) {
      final x0 = rr.range(-0.7, 0.7) * r;
      final u = age / life;
      final x = x0 + math.sin(u * 6.0 + rr.range(0.0, 6.0)) * 2.0;
      final y = _cy + r * 0.75 - u * r * 1.4;
      if (hypot(x, y - _cy) > r - 2.0) return;
      p.dot(x, y, u < 0.5 ? c[6] : c[5], math.sin(u * math.pi));
      p.light(x, y, c[5], 0.4 * math.sin(u * math.pi));
    });
  },
);
