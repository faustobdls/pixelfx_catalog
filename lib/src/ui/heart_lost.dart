import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'ui_lib.dart';

const double _hit = 0.14;
const double _crack = 0.24;
const double _split = 0.5;
const double _duration = 1.5;

const List<String> _mask = [
  '....xxxx...xxxx....',
  '..xxxxxxx.xxxxxxx..',
  '.xxxxxxxxxxxxxxxxx.',
  'xxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxx',
  'xxxxxxxxxxxxxxxxxxx',
  '.xxxxxxxxxxxxxxxxx.',
  '..xxxxxxxxxxxxxxx..',
  '...xxxxxxxxxxxxx...',
  '....xxxxxxxxxxx....',
  '.....xxxxxxxxx.....',
  '......xxxxxxx......',
  '.......xxxxx.......',
  '........xxx........',
  '.........x.........',
];
const int _mw = 19;
const int _mh = 16;
const double _ox = -9.5;
const double _oy = -8.0;
const List<int> _crackX = [
  9, 9, 10, 9, 8, 8, 9, 10, 10, 9, 8, 9, 9, 10, 9, 9,
];

final List<int> _socketCols = [
  hex('#0d0a14'),
  hex('#2a2338'),
  hex('#3c3350'),
];

bool _inMask(int i, int j) =>
    i >= 0 && j >= 0 && i < _mw && j < _mh && _mask[j][i] == 'x';

int _shadeAt(List<int> c, int i, int j) {
  final u = (i - 9) / 9.5;
  final v = (j - 7) / 8.0;
  if ((i == 3 || i == 4) && (j == 2 || j == 3) && !(i == 4 && j == 3)) {
    return kWhite;
  }
  if (i >= 2 && i <= 5 && j >= 2 && j <= 5 && u + v < -0.75) return c[5];
  final l = -(u * 0.55 + v * 0.65);
  return l > 0.25
      ? c[4]
      : (l > -0.3 ? c[3] : (l > -0.6 ? c[2] : c[1]));
}

void _drawPart(
  Painter p,
  List<int> c,
  int side,
  double x,
  double y,
  double a,
  bool white,
  double crackK,
  double alpha,
) {
  final ca = math.cos(a);
  final sa = math.sin(a);
  final px0 = side < 0 ? -4.5 : (side > 0 ? 4.5 : 0.0);
  const py0 = 0.0;
  bool own(int i, int j) =>
      _inMask(i, j) &&
      (side == 0 || (side < 0 ? i < _crackX[j] : i >= _crackX[j]));

  p.shade(x - 13.0, y - 13.0, x + 13.0, y + 13.0, (sx, sy, out) {
    final dx = sx - x;
    final dy = sy - y;
    final lx = dx * ca + dy * sa + px0;
    final ly = -dx * sa + dy * ca + py0;
    final i = (lx - _ox).floor();
    final j = (ly - _oy).floor();
    if (!own(i, j)) return null;
    out.a = alpha;
    final edge = !own(i - 1, j) ||
        !own(i + 1, j) ||
        !own(i, j - 1) ||
        !own(i, j + 1);
    if (white) return edge ? c[6] : kWhite;
    if (edge) return c[0];
    if (side == 0 && j / _mh < crackK) {
      if (i == _crackX[j]) return c[0];
      if (i == _crackX[j] - 1) return c[6];
    }
    return _shadeAt(c, i, j);
  });
}

class _HeartHalf {
  final int s;
  double x;
  double y = 0.0;
  double vx;
  double vy;
  double a = 0.0;
  final double va;

  _HeartHalf({
    required this.s,
    required this.x,
    required this.vx,
    required this.vy,
    required this.va,
  });
}

class _HeartLostSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final int seed;
  late final Particles ps;
  final Bits bits = Bits();
  final Lights lights = Lights();
  late final List<_HeartHalf> halves;
  static const double _end = _duration - 0.05;

  double t = 0.0;
  bool hit = false;
  bool split = false;
  bool gone = false;

  _HeartLostSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed),
        seed = o.seed {
    ps = Particles(rng: r, sparks: [c[7], c[6], c[5], c[3]]);
    halves = [
      for (final s in const [-1, 1])
        _HeartHalf(
          s: s,
          x: s * 4.5,
          vx: s * r.range(55.0, 70.0),
          vy: -r.range(60.0, 80.0),
          va: s * r.range(2.2, 3.2),
        ),
    ];
  }

  @override
  void update(double dt, Map<String, Object?> options) {
    t += dt;
    if (!hit && t >= _hit) {
      hit = true;
      lights.add(0, 0, 40, c[5], 0.6, 0.3);
      for (var i = 0; i < 8; i++) {
        final an = r.range(0.0, tau);
        final sp = r.range(80.0, 170.0);
        ps.spawn(
          P.spark,
          math.cos(an) * 9.0,
          math.sin(an) * 7.0,
          math.cos(an) * sp,
          math.sin(an) * sp - 30.0,
          r.range(0.1, 0.22),
        );
      }
    }

    if (!split && t >= _split) {
      split = true;
      lights.add(0, 0, 44, kWhite, 0.6, 0.12);
      lights.add(0, 0, 50, c[5], 0.5, 0.4);
      for (var i = 0; i < 12; i++) {
        final j = r.intRange(1, 14);
        final an = -math.pi / 2.0 + r.range(-1.4, 1.4);
        final sp = r.range(40.0, 100.0);
        bits.add(DebrisBit(
          kind: B.shard,
          x: _crackX[j] + _ox,
          y: j + _oy,
          vx: math.cos(an) * sp,
          vy: math.sin(an) * sp,
          g: 0.5,
          drag: 1.0,
          life: r.range(0.35, 0.55),
          a: r.range(0.0, tau),
          va: r.range(-20.0, 20.0),
          s: r.range(1.5, 3.0),
          c: r.pick([c[6], c[5], c[4], c[3]]),
        ));
      }
      for (var i = 0; i < 5; i++) {
        ps.spawn(
          P.dust,
          r.range(-2.0, 2.0),
          r.range(-6.0, 6.0),
          r.range(-25.0, 25.0),
          r.range(-20.0, 5.0),
          r.range(0.35, 0.6),
          c[2],
          r.range(2.0, 3.5),
        );
      }
      for (var i = 0; i < 6; i++) {
        final an = r.range(0.0, tau);
        final sp = r.range(30.0, 70.0);
        ps.spawn(
          P.star,
          math.cos(an) * 4.0,
          math.sin(an) * 4.0,
          math.cos(an) * sp,
          math.sin(an) * sp,
          r.range(0.25, 0.45),
          r.pick([c[7], c[6]]),
          i % 2 != 0 ? 0.6 : 1.4,
        );
      }
    }

    if (split && !gone && t >= 0.95) {
      gone = true;
      for (final h in halves) {
        for (var i = 0; i < 5; i++) {
          final an = r.range(0.0, tau);
          final sp = r.range(20.0, 50.0);
          ps.spawn(
            P.star,
            h.x + math.cos(an) * 4.0,
            h.y + math.sin(an) * 4.0,
            math.cos(an) * sp,
            math.sin(an) * sp - 10.0,
            math.min(r.range(0.2, 0.35), _end - t),
            r.pick([c[7], c[6], c[5]]),
            i != 0 ? 0.6 : 1.3,
          );
        }
      }
    }

    if (split) {
      for (final h in halves) {
        h.vy += 520.0 * dt;
        h.vx -= h.vx * 0.6 * dt;
        h.x += h.vx * dt;
        h.y += h.vy * dt;
        h.a += h.va * dt;
        if (t < 0.92 && r.chance(0.05)) {
          ps.spawn(
            P.ember,
            h.x,
            h.y,
            r.range(-10.0, 10.0),
            r.range(-10.0, 5.0),
            math.min(r.range(0.3, 0.5), _end - t),
            c[4],
            1.0,
          );
        }
      }
    }

    bits.update(dt);
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    final (jx, jy) = shake(t, 3.0, _hit, 0.25, seed);
    final tremble = (t > _crack && t < _split)
        ? (math.sin(t * 90.0) + 0.5).floor()
        : 0;
    final sk = seg(t, _split - 0.05, _split + 0.1) * (1.0 - seg(t, 1.15, 1.4));
    if (sk > 0.0) {
      p.shade(-12.0, -10.0, 12.0, 10.0, (sx, sy, out) {
        final i = (sx - _ox).floor();
        final j = (sy - _oy).floor();
        if (!_inMask(i, j)) return null;
        out.a = sk;
        final edge = !_inMask(i - 1, j) ||
            !_inMask(i + 1, j) ||
            !_inMask(i, j - 1) ||
            !_inMask(i, j + 1);
        return edge
            ? _socketCols[2]
            : (j < 3 ? _socketCols[1] : _socketCols[0]);
      });
    }

    if (t < _split) {
      final beat =
          t < _hit ? 1.0 + 0.08 * math.max(0.0, math.sin(t * 22.0)) : 1.0;
      final white = t >= _hit && t < _hit + 0.07;
      _drawPart(
        p,
        c,
        0,
        (jx + tremble).toDouble(),
        jy.toDouble(),
        0.0,
        white,
        seg(t, _crack, _split - 0.06),
        1.0,
      );
      p.glow(0, 0, 18.0 * beat, c[4], 0.3 + (white ? 0.5 : 0.0));
      if (t < _hit) {
        sparkle(
          p,
          -6,
          -5,
          2.5 * math.max(0.0, math.sin(t * 22.0)),
          c[7],
          c[6],
          0.3,
        );
      }
    } else {
      final fade = 1.0 - seg(t, 0.9, 1.0);
      final white = t < _split + 0.05;
      if (fade > 0.0) {
        for (final h in halves) {
          _drawPart(p, c, h.s, h.x, h.y, h.a, white, 0.0, fade);
        }
      }
      final rk = (t - _split) / 0.3;
      if (rk < 1.0) {
        p.ring(
          0,
          0,
          8.0 + 16.0 * Ease.outCubic(rk),
          math.max(1.0, 2.0 * (1.0 - rk)),
          rk < 0.3 ? kWhite : c[5],
          1.2 - rk,
        );
      }
    }

    bits.draw(p);
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect heartLostEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ui/heart-lost',
    name: 'Heart lost',
    desc:
        'A HUD heart is hit: it flashes white and jolts, a crack runs down it, it splits into two halves that tumble away, leaving an empty socket that fades.',
    category: 'ui',
    tags: ['ui', 'health', 'heart', 'hud', 'damage', 'one-shot'],
    size: (96, 88),
    origin: (48, 34),
    duration: _duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#1a0508',
        '#4a0b12',
        '#8c1420',
        '#d42a2e',
        '#ff5a4a',
        '#ff9a86',
        '#ffd8cc',
        '#ffffff',
      ],
      'seed': 5,
    },
  ),
  onCreate: _HeartLostSim.new,
);
