import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'holy_lib.dart';

const Pose _hurt = Pose(
  turn: 0.8,
  crouch: 5,
  lean: 3,
  hy: 1,
  fx: 1,
  fy: -21,
  bx: 7,
  by: -15,
  ffx: 4,
  fbx: -3,
);

const Pose _up = Pose(
  turn: 1.15,
  crouch: -1,
  fx: -13,
  fy: -36,
  bx: 14,
  by: -36,
  hy: -1,
  ffx: -3,
  ffy: -5,
  fbx: 4,
  fby: -5,
);

const double _sy = 0.3;
const int _np = 8;
const double _pr = 16.0;
const double _lift0 = 0.16;
const double _lift1 = 0.74;
const double _topy = -43.0;

const List<String> _heart = [
  '.#.#.',
  '#####',
  '.###.',
  '..#..',
];

// A tiny heart of light: cream body, a white glint, a warm rim.
void _drawHeart(Painter p, double x, double y, List<int> c, double a) {
  final xi = holyRound(x) - 2;
  final yi = holyRound(y) - 2;
  bool at(int i, int j) =>
      j >= 0 && j < 4 && i >= 0 && i < 5 && _heart[j][i] == '#';
  for (var j = -1; j <= 4; j++) {
    for (var i = -1; i <= 5; i++) {
      if (at(i, j)) {
        p.dot(
          xi + i,
          yi + j,
          i == 1 && j == 1 ? kWhite : (j >= 2 ? c[5] : c[6]),
          a,
        );
      } else if (at(i - 1, j) || at(i + 1, j) || at(i, j - 1) || at(i, j + 1)) {
        p.dot(xi + i, yi + j, c[3], a * 0.9);
      }
    }
  }
  p.glow(x, y, 6, c[5], 0.4 * a);
}

class _Petal {
  final double a;
  final double t0;
  final double w;

  const _Petal(this.a, this.t0, this.w);
}

class _SpiralMote {
  final double t0;
  final double th0;
  final double r0;
  final double y0;
  final double w;
  final double v;
  final double life;
  final int kind;

  const _SpiralMote({
    required this.t0,
    required this.th0,
    required this.r0,
    required this.y0,
    required this.w,
    required this.v,
    required this.life,
    required this.kind,
  });
}

class _HealSim extends BaseEffectSim {
  final List<int> c;
  final ActorDefinition actor;
  final HolyShape s;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  final Map<int, List<int>> rows = {};
  late final List<_Petal> petals;
  late final List<_SpiralMote> motes;
  double t = 0.0;
  bool burst = false;
  int lastRow = 1;

  _HealSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        actor = o.actor,
        s = shapeOf(o.actor),
        r = Rng(o.seed) {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [kWhite, c[6], c[5], c[4]],
    );
    for (final (x, y) in s.edge) {
      rows.putIfAbsent(y, () => []).add(x);
    }
    // Petals, each blooming on its own beat round the ring.
    petals = List.generate(_np, (k) {
      return _Petal(
        (k / _np) * tau + 0.2,
        0.02 + ((k * 3) % _np) * 0.035,
        r.range(4.2, 5.2),
      );
    }, growable: false);
    // Motes riding a spiral up round the body: from the petal tips as they open, and from the hoop when it bursts.
    motes = [];
    for (var k = 0; k < _np; k++) {
      motes.add(_SpiralMote(
        t0: 0.2 + k * 0.05,
        th0: petals[k].a,
        r0: _pr * 0.9,
        y0: -1.0,
        w: 4.2 * (k.isOdd ? 1.0 : -1.0),
        v: r.range(46.0, 58.0),
        life: r.range(0.75, 0.95),
        kind: k % 2,
      ));
    }
    for (var k = 0; k < 8; k++) {
      final t0 = _lift1 + r.range(0.0, 0.06);
      final r0 = r.range(12.0, 18.0);
      final y0 = _topy + r.range(-2.0, 4.0);
      final v = r.range(14.0, 34.0);
      final life = r.range(0.35, 0.6);
      motes.add(_SpiralMote(
        t0: t0,
        th0: (k / 8.0) * tau,
        r0: r0,
        y0: y0,
        w: 3.6 * (k.isOdd ? 1.0 : -1.0),
        v: v,
        life: life,
        kind: (k + 1) % 2,
      ));
    }
  }

  double _hoopY(double tt) =>
      lerp(0.0, _topy, Ease.inOutSine(seg(tt, _lift0, _lift1)));

  double _hoopR(double tt) => lerp(_pr, 12.0, seg(tt, _lift0, _lift1));

  double _bloom(int k, double tt) {
    final pe = petals[k];
    return Ease.outBack(seg(tt, pe.t0, pe.t0 + 0.3), 1.8) *
        (1.0 - Ease.inBack(seg(tt, 1.25 + k * 0.02, 1.6 + k * 0.02), 1.4));
  }

  // A petal of a lotus of light round the feet.
  void _petal(Painter p, int k, bool back) {
    final pe = petals[k];
    final g = pe.a + t * 0.4;
    final near = math.sin(g) >= 0.0;
    final b = _bloom(k, t);
    if (near == back || b <= 0.02) return;
    final ca = math.cos(g);
    final sa = math.sin(g);
    const rb = 6.0;
    final rt = rb + 9.0 * math.min(1.2, b);
    final h = (k.isOdd ? 7.0 : 9.0) * b;
    final bx = ca * rb;
    final by = sa * rb * _sy;
    final tx = ca * rt;
    final ty = sa * rt * _sy - h;
    final l = hypot(tx - bx, ty - by);
    if (l < 1.5) return;
    final ux = (tx - bx) / l;
    final uy = (ty - by) / l;
    final w = pe.w * math.min(1.0, b) * (0.35 + 0.65 * sa.abs());
    final pad = w + 1.0;
    p.each(
      math.min(bx, tx) - pad,
      math.min(by, ty) - pad,
      math.max(bx, tx) + pad,
      math.max(by, ty) + pad,
      (x, y, sx, sy) {
        final dx = x - bx;
        final dy = y - by;
        final u = (dx * ux + dy * uy) / l;
        if (u < 0.0 || u > 1.0) return;
        final hw = w *
                math.pow(
                  math.sin(math.pi * math.pow(u, 0.6).toDouble()),
                  0.7,
                ) +
            0.2;
        final v = (-dx * uy + dy * ux).abs() / hw;
        if (v > 1.0) return;
        if (u > 0.9) {
          p.put(sx, sy, kWhite, 1.0);
          return;
        }
        if (v > 0.7) {
          p.put(sx, sy, u < 0.3 ? c[3] : (u < 0.7 ? c[5] : c[6]), 1.0);
          return;
        }
        if (v < 0.2 && u > 0.15 && u < 0.85) {
          p.put(sx, sy, u < 0.55 ? c[5] : c[6], back ? 0.75 : 0.85);
          return;
        }
        p.blendPx(sx, sy, u < 0.45 ? c[3] : c[4], back ? 0.6 : 0.45);
      },
    );
    p.glow(tx, ty, 5, c[5], 0.35 * math.min(1.0, b));
  }

  // The hoop of light rising up the body: far half behind, near half in front.
  void _hoop(Painter p, bool back) {
    if (t < _lift0 || t > _lift1 + 0.12) return;
    final y = _hoopY(t);
    final rad = _hoopR(t) * (t > _lift1 ? 1.0 - (t - _lift1) / 0.12 : 1.0);
    final keep = back ? farHalf : nearHalf;
    ovalShaded(
      p,
      0,
      y,
      rad,
      rad * _sy,
      color: (g) => math.sin(g) > 0.5 ? kWhite : c[6],
      alpha: (_) => back ? 0.8 : 1.0,
      keep: keep,
    );
    if (!back) {
      oval(p, 0, y + 1.0, rad - 0.5, rad * _sy, c[4], 1.0, keep);
      for (var i = -2; i <= 2; i++) {
        p.glow(i * rad * 0.45, y, 8, c[5], 0.32);
      }
    }
  }

  // The spiralling motes, each popping into a heart or a sparkle at the end of its ride.
  void _riders(Painter p, bool back) {
    for (final m in motes) {
      final a = t - m.t0;
      if (a < 0.0) continue;
      (double, double, double) at(double aa) {
        final th = m.th0 + m.w * aa;
        final rad = m.r0 * (1.0 - 0.45 * (aa / m.life));
        return (math.cos(th) * rad, m.y0 - m.v * aa, math.sin(th));
      }

      if (a < m.life) {
        final (x, y, z) = at(a);
        if ((z < 0.0) != back) continue;
        for (var j = 0; j < 7; j++) {
          final aj = a - j * 0.03;
          if (aj < 0.0) break;
          final (tx, ty, tz) = at(aj);
          if ((tz < 0.0) != back) continue;
          p.dot(
            tx,
            ty,
            j == 0 ? kWhite : (j < 3 ? c[6] : c[5]),
            (1.0 - j / 7.0) * (back ? 0.6 : 1.0),
          );
        }
        p.glow(x, y, 4, c[5], back ? 0.2 : 0.4);
        continue;
      }
      // The pop: a quick sparkle, then a heart (or a star) that floats up and fades.
      final u = (a - m.life) / 0.36;
      if (u >= 1.0 || back) continue;
      final (x, y, _) = at(m.life);
      final k = 1.0 - smooth(0.5, 1.0, u);
      if (u < 0.12) {
        sparkle(p, x, y, 3, kWhite, c[6], 0.5);
      } else if (m.kind != 0) {
        _drawHeart(p, x, y - u * 6.0, c, k);
      } else {
        sparkle(
          p,
          x,
          y - u * 5.0,
          1.0 + 2.0 * k * (0.7 + 0.3 * math.sin(a * 30.0)),
          kWhite,
          c[5],
          0.45 * k,
        );
      }
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    // The hoop leaves sparkles on the body as it passes each row.
    if (t > _lift0 && t < _lift1) {
      final yVal = holyRound(_hoopY(t));
      for (var y = lastRow; y > yVal; y--) {
        final xs = rows[y];
        if (xs == null || !r.chance(0.45)) continue;
        final px = r.pick(xs) + r.range(-1.0, 1.0) * 2.0;
        final vx = r.range(-4.0, 4.0);
        final vy = -r.range(4.0, 12.0);
        final life = r.range(0.3, 0.55);
        final col = r.chance(0.5) ? kWhite : c[6];
        final size = r.range(0.6, 1.6);
        ps.spawn(P.star, px, y.toDouble(), vx, vy, life, col, size);
      }
      lastRow = math.min(lastRow, yVal);
    }
    if (!burst && t >= _lift1) {
      burst = true;
      lights.add(0, _topy, 26, c[5], 0.55, 0.3);
      lights.add(0, _topy, 10, kWhite, 0.45, 0.08);
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    // A warm pool under the flower.
    final pool = smooth(0.0, 0.2, t) * (1.0 - smooth(1.3, 1.75, t));
    if (pool > 0.0) p.glow(0, -2, 30, c[4], 0.3 * pool);
    for (var k = 0; k < _np; k++) {
      _petal(p, k, true);
    }
    _hoop(p, true);
    ps.draw(p, 'back');
    _riders(p, true);
  }

  @override
  void draw(Painter p) {
    // Drained of colour above the hoop, restored below it with a warm glow at the line.
    final drain = smooth(0.0, 0.08, t);
    if (t < _lift1 + 0.35) {
      final yVal = t < _lift0 ? 1.0 : _hoopY(t);
      final done = t >= _lift1;
      recolor(p, actor, (col, _, y) {
        final d = y - yVal;
        if (!done && d < -0.5) {
          final l = luma(col) * 0.88;
          return mix(col, rgb(l * 236.0, l * 226.0, l * 222.0), 0.68 * drain);
        }
        if (!done && d < 1.0) return kWhite;
        if (!done && d < 2.5) return c[6];
        final k = done
            ? 0.45 * (1.0 - seg(t, _lift1, _lift1 + 0.35))
            : 0.5 * math.exp(-(d - 2.5) / 5.0);
        return k > 0.05 ? mix(col, c[5], k) : 0;
      });
      if (t > _lift0 && !done) p.glow(0, yVal, 18, c[5], 0.35);
    }
    for (var k = 0; k < _np; k++) {
      _petal(p, k, false);
    }
    _hoop(p, false);
    if (t >= _lift1 && t < _lift1 + 0.25) {
      sparkle(
        p,
        0,
        _topy,
        8.0 * (1.0 - (t - _lift1) / 0.25),
        kWhite,
        c[5],
        0.6,
      );
    }
    _riders(p, false);
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect healEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'holy/heal',
    name: 'Heal',
    desc:
        'Petals of light bloom under the feet, a hoop of light rises up the body restoring its colour and leaving sparkles, and motes spiral up and pop into tiny hearts.',
    category: 'holy',
    tags: [
      'holy',
      'heal',
      'restore',
      'buff',
      'petals',
      'hearts',
      'character',
      'one-shot',
    ],
    size: (80, 104),
    origin: (40, 92),
    duration: 1.9,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#3d2027',
        '#7d3f35',
        '#c97a4a',
        '#f2b46a',
        '#ffd994',
        '#fff0cf',
        '#fffaf2',
        '#ffffff',
      ],
      'seed': 2,
    },
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      const PoseKey(-0.3, _hurt),
      PoseKey(0.16, _hurt.copyWith(crouch: 6)),
      PoseKey(0.5, _hurt.copyWith(crouch: 3, lean: 1, hy: 0)),
      const PoseKey(0.78, _up),
      PoseKey(1.2, _up.copyWith(crouch: 0, fy: -30, by: -30, hy: 0)),
      const PoseKey(1.9, kReady),
    ],
  ),
  onCreate: (o) => _HealSim(o),
);
