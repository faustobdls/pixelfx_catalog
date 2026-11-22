// The floor glow and the specks rising off it follow Sprite Fusion's open-source mana heal
// (https://www.spritefusion.com/pixel-art-vfx/heal), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'arcane_lib.dart';

const double _d = 4.0;
const double _r = 46.0;
const double _rr = 39.0;
const double _ri = 23.0;
const double _rc = 7.0;
const double _sy = 0.3;
const int _nr = 12;

Point2 _at(double g, double r) => (math.cos(g) * r, math.sin(g) * r * _sy);

double _gap(double a, double b) =>
    math.atan2(math.sin(a - b), math.cos(a - b)).abs();

void _circle(Painter p, List<int> c, double t, bool far) {
  final ph = t / _d;
  final spin = (ph * tau) / 4.0;
  final keep = far
      ? (double g) => math.sin(g) < 0.0
      : (double g) => math.sin(g) >= 0.0;
  final chase = ph * tau * 2.0;
  bool lit(double g, double w) =>
      _gap(g, chase) < w || _gap(g, chase + math.pi) < w;
  int toneCol(double g, int hi, int lo) => math.sin(g) < 0.0 ? lo : hi;

  floorRing(
    p,
    0,
    0,
    _r,
    _sy,
    (g) => lit(g, 0.22)
        ? kWhite
        : lit(g, 0.5)
            ? c[6]
            : toneCol(g, c[6], c[5]),
    (_) => 1.0,
    keep,
  );
  floorRing(p, 0, 0, _ri, _sy, (g) => toneCol(g, c[5], c[4]), (_) => 1.0, keep);
  floorRing(p, 0, 0, _rc, _sy, (g) => toneCol(g, c[6], c[5]), (_) => 1.0, keep);

  for (var j = 0; j < 16; j++) {
    final g = spin + ((j + 0.5) * tau) / 16.0;
    if ((math.sin(g) < 0.0) != far) continue;
    final (x, y) = _at(g, _r + 3.5);
    final hot = lit(g, 0.3);
    p.px(
      x,
      y,
      hot ? kWhite : toneCol(g, j.isOdd ? c[5] : c[6], c[4]),
    );
    if (j.isEven) {
      for (final dx in const [1.0, -1.0]) {
        p.px(x + dx, y, hot ? c[6] : toneCol(g, c[4], c[3]));
      }
    }
  }

  final pts = List.generate(
    4,
    (k) => _at(-spin + (k * tau) / 4.0 + math.pi / 4.0, _ri),
    growable: false,
  );
  for (var k = 0; k < 4; k++) {
    var (ax, ay) = pts[k];
    var (bx, by) = pts[(k + 1) % 4];
    if ((ay < 0.0) != (by < 0.0)) {
      final u = ay / (ay - by);
      final mx = ax + (bx - ax) * u;
      if ((ay < 0.0) == far) {
        bx = mx;
        by = 0.0;
      } else {
        ax = mx;
        ay = 0.0;
      }
    } else if ((ay < 0.0) != far) {
      continue;
    }
    p.line(ax, ay, bx, by, far ? c[4] : c[5]);
  }

  final gs = <(int k, double g)>[];
  for (var k = 0; k < _nr; k++) {
    final g = spin + ((k + 0.5) * tau) / _nr;
    if ((math.sin(g) < 0.0) == far) {
      gs.add((k, g));
    }
  }
  gs.sort((a, b) => math.sin(a.$2).compareTo(math.sin(b.$2)));
  const runeIds = [0, 3, 5];
  for (final (k, g) in gs) {
    final (x, y) = _at(g, _rr);
    final hot = lit(g, 0.2);
    final bob = math.sin(ph * tau * 4.0 + 4.0 * g) * 0.5;
    arcaneGlyph(
      p,
      runeIds[k % 3],
      x,
      y - 1.0 + bob,
      hot ? kWhite : (far ? c[5] : c[6]),
      1.0,
      hot ? c[5] : (far ? c[2] : c[3]),
    );
    p.glow(x, y - 3.0, hot ? 10 : 6, c[5], hot ? 0.5 : (far ? 0.12 : 0.22));
    p.glow(x, y, 5, c[4], 0.15);
  }
}

void _motes(Painter p, List<int> c, double t, int seed, bool far) {
  cycle(t, _d, 76, seed * 5 + 1, (g) => g.range(1.1, 1.9), (age, life, r, _) {
    final g0 = r.range(0.0, tau);
    final r0 = r.pick([_r, _r, _rr, _rr, _ri]);
    final q = age / life;
    final g = g0 + q * r.range(0.6, 1.4);
    if ((math.sin(g) < 0.0) != far) return;
    final rr = r0 * (1.0 - 0.35 * q);
    final h = 2.0 + Ease.outQuad(q) * r.range(26.0, 52.0);
    final x = math.cos(g) * rr;
    final y = math.sin(g) * rr * _sy - h;
    final a = math.min(1.0, q * 5.0) * (1.0 - smooth(0.65, 1.0, q));
    final big = r.chance(0.2);
    final col = r.chance(0.3)
        ? kWhite
        : r.chance(0.6)
            ? c[6]
            : c[5];
    final size = big ? 1.1 : r.range(0.55, 0.9);
    mote(
      p,
      x,
      y,
      -math.sin(g) * rr * 0.8,
      -36.0 * (1.0 - q) - 10.0,
      col,
      size,
      a,
      big ? 0.5 : 0.3,
    );
  });

  cycleFixed(t, _d, 14, seed * 5 + 2, 0.45, (age, life, r, _) {
    final g = r.range(0.0, tau);
    if ((math.sin(g) < 0.0) != far) return;
    final rr = r.range(8.0, _r);
    final x = math.cos(g) * rr;
    final y = math.sin(g) * rr * _sy - r.range(6.0, 34.0);
    final k = math.sin((age / life) * math.pi);
    sparkle(p, x, y, 1.0 + 2.4 * k, c[6], c[5], 0.35 * k);
  });
}

final PureEffect runeCircleEffect = PureEffect(
  meta: const EffectMeta(
    id: 'arcane/rune-circle',
    name: 'Rune circle',
    desc:
        'A rune circle turns on the floor in perspective: a carousel of runes lit by chasing light, a turning square, ticks, motes rising off it.',
    category: 'arcane',
    tags: ['arcane', 'rune', 'circle', 'magic', 'aura', 'ground', 'loop'],
    size: (136, 100),
    origin: (68, 80),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {'palette': Pal.arcane, 'seed': 8},
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final pulse = 0.85 + 0.15 * math.sin((t / _d) * tau * 4.0);
    p.glow(0, 0, _r * 1.4, c[4], 0.24 * pulse);
    for (final s in const [-1.0, 1.0]) {
      p.glow(s * _r * 0.55, 1, _r * 0.7, c[5], 0.12 * pulse);
    }
    for (var h = 0; h < 66; h += 6) {
      p.glow(0, -h, 26, c[4], 0.11 * pulse * (1.0 - h / 80.0));
    }
    _circle(p, c, t, true);
    _motes(p, c, t, o.seed, true);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final chase = (t / _d) * tau * 2.0;
    _circle(p, c, t, false);
    _motes(p, c, t, o.seed, false);
    for (final g in [chase, chase + math.pi]) {
      final (x, y) = _at(g, _r);
      sparkle(p, x, y, 2.5 + math.sin(t * 30.0) * 0.8, c[6], c[5], 0.5);
      p.glow(x, y, 14, c[5], 0.4);
    }
  },
);
