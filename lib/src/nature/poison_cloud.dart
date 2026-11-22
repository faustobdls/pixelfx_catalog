import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const double _dur = 4.0;

class _Sheet {
  final double h;
  final double e;
  final double a;
  final int dim;
  final int flow;
  final int n;
  final bool back;

  const _Sheet({
    required this.h,
    required this.e,
    required this.a,
    required this.dim,
    required this.flow,
    required this.n,
    required this.back,
  });
}

const List<_Sheet> _sheets = [
  _Sheet(h: 36, e: 0.84, a: 0.46, dim: 2, flow: 4, n: 2, back: true),
  _Sheet(h: 26, e: 0.96, a: 0.5, dim: 1, flow: 8, n: 2, back: true),
  _Sheet(h: 16, e: 1.04, a: 0.56, dim: 0, flow: 8, n: 3, back: false),
];

class _Tongue {
  final int s;
  final double q;
  final double x;
  final double h;

  const _Tongue({
    required this.s,
    required this.q,
    required this.x,
    required this.h,
  });
}

List<_Tongue> _tongues(_Sheet sh, int si, double e, double ph) {
  final out = <_Tongue>[];
  for (final s in const [-1, 1]) {
    for (var i = 0; i < sh.n; i++) {
      final q = (ph + i / sh.n + si * 0.17 + (s > 0 ? 0.5 / sh.n : 0)) % 1.0;
      out.add(_Tongue(
        s: s,
        q: q,
        x: s * e * (0.3 + 0.82 * q),
        h: sh.h * (0.75 - 0.45 * q),
      ));
    }
  }
  return out;
}

double _height(
  _Sheet sh,
  int si,
  double e,
  double x,
  double ph,
  List<_Tongue> tonguesList,
  int seed,
) {
  final ax = x.abs();
  final env = 1 - smooth(0.5, 1, ax / (e * sh.e));
  final r = tileNoise(
    ax * 0.07 - ph * sh.flow,
    si * 3.7,
    sh.flow,
    0,
    seed + si,
  );
  var h = sh.h * env * (0.55 + 0.45 * r);
  for (final g in tonguesList) {
    final behind = g.s * (g.x - x);
    if (behind < -1.5 || behind > 30) continue;
    h = math.max(
      h,
      g.h *
          math.sqrt(math.max(0.0, 1 - behind / 30)) *
          smooth(-1.5, 1.5, behind) *
          (1 - smooth(0.75, 1, g.q)),
    );
  }
  return h;
}

void _sheet(
  Painter p,
  List<int> c,
  _Sheet sh,
  int si,
  double e,
  double t,
  int seed,
) {
  final ph = t / _dur;
  final tonguesList = _tongues(sh, si, e, ph);
  final d = sh.dim;
  final xMax = (e * 1.25).ceil();
  for (var x = -xMax; x <= xMax; x++) {
    final h = _height(sh, si, e, x + 0.5, ph, tonguesList, seed);
    if (h < 0.6) continue;
    final top = -(h + 0.5).floor();
    final xSign = x == 0 ? 1 : x.sign;
    for (var y = top; y <= 1; y++) {
      final v = clamp(-y / h);
      final streak = 0.7 +
          0.3 *
              tileNoise(
                x * 0.05 - ph * sh.flow * xSign,
                y * 0.55,
                sh.flow,
                0,
                seed + 9 + si,
              );
      final lv = v - (streak - 0.7) * 0.6;
      final col = y == top
          ? c[math.max(1, 4 - d)]
          : lv < 0.16
              ? c[6 - d]
              : lv < 0.42
                  ? c[5 - d]
                  : lv < 0.68
                      ? c[4 - d]
                      : c[math.max(1, 3 - d)];
      p.blend(
        x,
        y,
        col,
        sh.a * (y == top ? 0.65 : (0.6 + 0.4 * (1 - v)) * streak),
      );
    }
  }
  for (final g in tonguesList) {
    final k = math.sin(math.pi * g.q);
    if (k < 0.15 || g.h < 4) continue;
    final rad = 1.8 + g.h * 0.22;
    final cx = g.x - g.s * rad * 0.6;
    final cy = -g.h * 0.72;
    final spin = -g.s * g.q * tau * 2.2;
    for (var a = 0.0; a < 4.6; a += 0.1) {
      final rr = rad * (1 - a * 0.12);
      final px = cx + g.s * math.cos(spin + a) * rr;
      final py = cy + math.sin(spin + a) * rr;
      final w = 1.6 * (1 - a / 6);
      for (var o = -w; o <= w; o += 0.8) {
        final qx = px + g.s * math.cos(spin + a) * o;
        final qy = py + math.sin(spin + a) * o;
        p.blend(
          qx,
          qy,
          o > w * 0.4 ? c[5 - d] : c[4 - d],
          sh.a * 0.75 * k * (1 - a / 5.5),
        );
      }
    }
  }
}

void _plumes(Painter p, List<int> c, double e, double t, int seed) {
  cycle(t, _dur, 5, seed, (g) => g.range(2.4, 3.2), (age, l, r, _) {
    final u = age / l;
    final x0 = r.range(-0.55, 0.55) * e;
    final rise = r.range(13, 19);
    final len = r.range(34, 48);
    final ph = r.range(0, tau);
    final amp = r.range(3, 5);
    final head = 14 + rise * age;
    final tail = math.max(10.0, head - len);
    final fade = smooth(0, 0.15, u) * (1 - smooth(0.5, 1, u));
    for (var h = tail; h <= head; h += 0.7) {
      final s = (h - tail) / math.max(1.0, head - tail);
      final tw = math.cos(h * 0.22 + age * 2.4 + ph);
      final w = 0.6 + 2.2 * tw.abs() * (1 - s * 0.5);
      final x = x0 + amp * math.sin(h * 0.12 + age + ph) * (0.4 + s);
      final a = fade * math.sin(math.pi * math.min(1.0, s * 1.2)) * 0.32;
      for (var o = -w; o <= w; o += 1) {
        p.blend(
          x + o,
          -h,
          tw > 0
              ? (o.abs() < w * 0.5 ? c[6] : c[5])
              : (o.abs() < w * 0.5 ? c[3] : c[2]),
          a,
        );
      }
    }
  });
}

void _specks(Painter p, List<int> c, double e, double t, int seed) {
  cycle(t, _dur, 30, seed, (g) => g.range(1.5, 2.6), (age, l, r, _) {
    final u = age / l;
    final s = r.sign();
    final x = s * (r.range(0.05, 0.7) * e + age * r.range(6, 14));
    final y = -r.range(2, 20) -
        math.sin(age * r.range(1.5, 3) + r.next() * tau) * 2;
    final a = math.min(1.0, u * 5) *
        math.min(1.0, (1 - u) * 3) *
        (0.6 + 0.4 * math.sin(age * r.range(6, 10) + r.next() * tau));
    if (a < 0.1) return;
    p.dot(x, y, a > 0.7 ? c[7] : c[6], a * 1.3);
    p.glow(x, y, 4, c[6], 0.3 * a);
  });
}

final PixelEffect poisonCloud = PureEffect(
  meta: const EffectMeta(
    id: 'nature/poison-cloud',
    name: 'Poison cloud',
    desc:
        'A miasma hugging the floor: ragged sheets of gas lit yellow-green from within, fading to violet, creep out in tongues that curl over at their tips; plumes twist up as ribbons.',
    category: 'nature',
    tags: [
      'nature',
      'poison',
      'gas',
      'cloud',
      'miasma',
      'toxic',
      'area',
      'ground',
      'loop',
    ],
    size: (256, 100),
    origin: (128, 86),
    duration: 4.0,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#0e0816',
        '#24123a',
        '#3e2056',
        '#5a3a62',
        '#6a6a3a',
        '#96aa30',
        '#cce040',
        '#f4ffa0',
      ],
      'spread': 1,
      'seed': 3,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final e = 96.0 * o.numOpt('spread', 1.0);
    final pulse = 0.85 + 0.15 * math.sin((tau * t * 2) / _dur);
    for (var x = -e; x <= e; x += 22) {
      p.glow(x, -3, 30, c[5], 0.14 * pulse * (1 - x.abs() / (e * 1.3)));
    }
    for (var i = 0; i < 6; i++) {
      final r = rng(o.seed, i, 7);
      final x = math.sin((tau * t) / _dur + r.range(0, tau)) *
              e *
              r.range(0.2, 0.7) +
          r.range(-0.3, 0.3) * e;
      final k = 0.6 + 0.4 * math.sin((tau * t * 3) / _dur + i);
      p.glow(x, -r.range(4, 10), r.range(14, 22), c[6], 0.2 * k);
    }
    for (var i = 0; i < _sheets.length; i++) {
      if (_sheets[i].back) _sheet(p, c, _sheets[i], i, e, t, o.seed);
    }
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final e = 96.0 * o.numOpt('spread', 1.0);
    _plumes(p, c, e, t, o.seed * 7 + 2);
    for (var i = 0; i < _sheets.length; i++) {
      if (!_sheets[i].back) _sheet(p, c, _sheets[i], i, e, t, o.seed);
    }
    _specks(p, c, e, t, o.seed * 11 + 5);
    p.glow(0, -6, e * 0.9, c[5], 0.1);
  },
);
