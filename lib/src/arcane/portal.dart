// The dithered light ramp and the streaked, knotted disc texture are adapted from Sprite Fusion's open-source
// black hole (https://www.spritefusion.com/pixel-art-vfx/black-hole), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'arcane_lib.dart';

const double _d = 2.4;

double _wrapPi(double a) => a - tau * ((a + math.pi) / tau).floor();

class _PortalState {
  final List<int> c;
  final double rx;
  final double ry;
  final double ph;
  final int seed;
  final double cy;
  final List<double> spots;

  _PortalState(
    this.c,
    this.rx,
    this.ry,
    this.ph,
    this.seed,
    this.cy,
    this.spots,
  );

  double rim(double th) =>
      1.0 +
      0.05 * tileNoise((th / tau) * 10.0 + ph * 10.0, ph * 4.0, 10, 4, seed) +
      0.018 * math.sin(th * 3.0 - ph * tau * 2.0);

  Point2 at(double th, double rho) {
    final out = math.max(0.0, rho - 1.0);
    final k = math.min(1.0, rho);
    return (
      math.cos(th) * (k * rx + out * 21.0),
      math.min(-1.0, cy + math.sin(th) * (k * ry + out * 16.0)),
    );
  }

  double hot(double th) {
    final d0 = _wrapPi(th - spots[0]);
    final d1 = _wrapPi(th - spots[1]);
    return math.max(
          math.exp(-(d0 * d0) / 0.12),
          0.85 * math.exp(-(d1 * d1) / 0.08),
        ) +
        0.35 * math.max(0.0, math.cos(th + 2.3));
  }
}

_PortalState _setup(double t, Map<String, Object?> o) {
  final c = fit(o.palette, 8);
  final rx = o.numOpt('width', 17.0);
  final ry = o.numOpt('height', 29.0);
  final ph = t / _d;
  final seed = o.seed;
  final cy = -(ry + 5.0);
  final spots = [ph * tau * 2.0 - 0.6, ph * tau * 2.0 + math.pi - 0.6];
  return _PortalState(c, rx, ry, ph, seed, cy, spots);
}

void _rift(Painter p, _PortalState s) {
  final c = s.c;
  final rx = s.rx;
  final ry = s.ry;
  final ph = s.ph;
  final cy = s.cy;
  p.shade(-rx - 4.0, cy - ry - 4.0, rx + 4.0, cy + ry + 4.0, (x, y, out) {
    final u = x / rx;
    final v = (y - cy) / ry;
    final rawR = hypot(u, v);
    final r = rawR == 0.0 ? 1e-6 : rawR;
    final th = math.atan2(v, u);
    final r0 = s.rim(th);
    final g = hypot(u / rx, v / ry) / r;
    final e = (r - r0) / g;
    final h = s.hot(th);
    if (e > 2.5) return null;
    if (e > 1.5) {
      if (h > 0.6) {
        out.c = c[3];
        out.a = 0.5;
      }
      return null;
    }
    if (e > 0.5) {
      out.c = h > 0.5 ? c[4] : c[2];
      return null;
    }
    if (e > -0.5) {
      out.c = h > 0.42 ? kWhite : c[6];
      out.k = 0.25 + 0.4 * h;
      return null;
    }
    final d = r / r0;
    final z = -math.log(math.max(0.02, d));
    final phi = 3.0 * th + 6.5 * z - tau * 3.0 * ph;
    final c1 = 0.5 + 0.5 * math.cos(phi);
    final c2 = 0.5 + 0.5 * math.cos(phi + math.pi + 0.6 * z);
    final lit = math.pow(d, 1.5).toDouble();
    final sink = smooth(0.2, 0.62, d);
    final knot = math.pow(
            math.max(0.0, math.cos(4.0 * z - phi / 3.0 + tau * 5.0 * ph)), 6)
        .toDouble();
    var st = smooth(0.4, 0.7, d) + 0.6 * smooth(0.8, 0.95, d);
    final crest = math.pow(c1, 16) * (0.6 + 5.6 * lit) * (1.0 + 0.5 * knot) * sink;
    st += crest + math.pow(c1, 5) * 1.1 * lit;
    st += math.pow(c2, 18) * (0.3 + 1.8 * lit) * sink;
    st += math.pow(0.5 + 0.5 * math.cos(tau * (z * 1.5 - ph * 2.0)), 20) *
        1.3 *
        sink *
        (1.0 - 0.5 * c1);
    st += math.pow(0.5 + 0.5 * math.cos(3.0 * phi + 2.0 * z + 1.3), 10) *
        1.1 *
        lit *
        sink;
    final sRim = smooth(0.8, 1.0, d);
    st += 2.2 * sRim * sRim * (0.75 + 0.45 * h);
    out.c = tone(c, st / 7.0, x, y, 0.0, 0.65);
    if (crest > 2.2) out.k = 0.12 + 0.05 * crest;
    return null;
  });
}

void _well(Painter p, _PortalState s) {
  final c = s.c;
  final rx = s.rx;
  final ry = s.ry;
  final ph = s.ph;
  final seed = s.seed;
  final cy = s.cy;
  final t = ph * _d;
  cycle(t, _d, 18, seed * 7 + 5, (g) => g.range(1.1, 1.8), (age, life, r, _) {
    final q = age / life;
    final th = r.range(0.0, tau) + q * 2.6;
    final rho = 0.92 * (1.0 - Ease.inQuad(q) * 0.9);
    final r0 = s.rim(th);
    final x = math.cos(th) * rho * r0 * rx;
    final y = cy + math.sin(th) * rho * r0 * ry;
    final tw =
        math.sin(ph * tau * r.intRange(14, 22) + r.range(0.0, tau));
    final a = math.min(1.0, q * 6.0) * (rho > 0.25 ? 1.0 : rho / 0.25);
    if (tw > -0.3) {
      p.dot(
        x,
        y,
        rho > 0.6 && tw > 0.6
            ? kWhite
            : rho > 0.45
                ? c[6]
                : c[5],
        a,
      );
    }
  });
}

void _orbit(Painter p, _PortalState s) {
  final c = s.c;
  final rx = s.rx;
  final ry = s.ry;
  final ph = s.ph;
  final seed = s.seed;
  final cy = s.cy;
  for (var i = 0; i < 7; i++) {
    final k = (ph * 2.0 + i / 7.0) % 1.0;
    final th = ((i * 2.39 + seed) % tau) + ph * tau * 2.0 + k * 2.5;
    final rho = 1.2 + 0.35 * ((i * 0.618) % 1.0) - 0.3 * Ease.inQuad(k);
    final x = math.cos(th) * rho * rx;
    final y = cy + math.sin(th) * rho * ry;
    final a = math.min(1.0, math.sin(k * math.pi) * 2.2);
    mote(
      p,
      x,
      y,
      -math.sin(th) * rx * 10.0,
      math.cos(th) * ry * 10.0,
      i % 3 != 0 ? c[6] : kWhite,
      0.6,
      a,
      0.3,
    );
  }
}

void _infall(Painter p, _PortalState s) {
  final c = s.c;
  final ph = s.ph;
  final seed = s.seed;
  final t = ph * _d;
  cycle(t, _d, 60, seed * 7 + 1, (g) => g.range(0.3, 0.5), (age, life, r, _) {
    final a0 = r.range(0.0, tau);
    final d0 = r.range(1.8, 3.0);
    final spin = r.range(0.8, 1.8) * (r.chance(0.8) ? 1.0 : 0.35);
    final size = r.range(0.8, 1.5);
    final hue = r.next();
    Point2 pos(double q) => s.at(
          a0 + spin * q * q,
          d0 * (1.0 - math.pow(q, 1.4).toDouble()),
        );
    final q = age / life;
    final (x, y) = pos(q);
    final (x2, y2) = pos(math.min(1.0, q + 0.015));
    final vx = (x2 - x) / (0.015 * life);
    final vy = (y2 - y) / (0.015 * life);
    final rho = d0 * (1.0 - math.pow(q, 1.4).toDouble());
    final r0 = s.rim(a0 + spin * q * q);
    final fade = math.min(1.0, q * 5.0);
    if (rho > r0 + 0.06) {
      mote(
        p,
        x,
        y,
        vx,
        vy,
        hue < 0.25
            ? kWhite
            : hue < 0.55
                ? c[6]
                : hue < 0.8
                    ? c[5]
                    : c[4],
        hue < 0.8 ? size : size * 1.4,
        fade,
        hue < 0.8 ? 0.4 : 0.15,
      );
    } else if (rho > 0.3) {
      p.dot(x, y, rho > 0.65 ? c[6] : c[5], rho);
    }
  });

  cycle(t, _d, 12, seed * 7 + 2, (g) => g.range(0.36, 0.5), (age, life, r, _) {
    final a0 = r.range(0.0, tau);
    final d0 = r.range(2.3, 3.0);
    final spin = r.range(0.2, 0.5);
    final qc = math.sqrt(1.0 - 1.05 / d0);
    final q = age / life;
    Point2 pos(double u) => s.at(a0 + spin * u * u, d0 * (1.0 - u * u));
    if (q < qc) {
      final (x, y) = pos(q);
      final (x2, y2) = pos(q + 0.015);
      streak(
        p,
        x,
        y,
        (x2 - x) / (0.015 * life),
        (y2 - y) / (0.015 * life),
        c[6],
        math.min(1.0, q * 5.0),
      );
    } else {
      final k = 1.0 - (q - qc) / (1.0 - qc);
      final (x, y) = pos(qc);
      if (k > 0.55) p.px(x, y, kWhite);
      p.glow(x, y, 7, c[6], 0.6 * k * k);
    }
  });
}

void _skaters(Painter p, _PortalState s) {
  final c = s.c;
  final ph = s.ph;
  final seed = s.seed;
  final cy = s.cy;
  final ry = s.ry;
  final t = ph * _d;
  final foot = cy + ry;
  cycle(t, _d, 14, seed * 7 + 3, (g) => g.range(0.7, 1.1), (age, life, r, _) {
    final side = r.sign();
    final x0 = side * r.range(22.0, 50.0);
    final y0 = -1.0 - r.range(0.0, 1.5);
    final q = age / life;
    final e = Ease.inCubic(q);
    final x = x0 * (1.0 - e);
    final y = y0 + (foot + 2.0) * smooth(0.55, 1.0, q);
    final qPrev = math.max(0.0, q - 0.04);
    final xb = x0 * (1.0 - Ease.inCubic(qPrev));
    final yb = y0 + (foot + 2.0) * smooth(0.55, 1.0, qPrev);
    final big = r.chance(0.3);
    mote(
      p,
      x,
      y,
      (x - xb) * 25.0,
      (y - yb) * 25.0,
      big ? c[6] : c[5],
      big ? 0.9 : 0.6,
      math.min(1.0, q * 4.0) * (1.0 - smooth(0.85, 1.0, q)),
      0.3,
    );
  });
}

void _floor(Painter p, _PortalState s) {
  final c = s.c;
  final ph = s.ph;
  final pulse = 0.85 + 0.15 * math.sin(ph * tau * 2.0);
  for (var x = -36; x <= 36; x++) {
    final u = (x + 0.5).abs() / 36.0;
    final a = (u < 0.55 ? 1.0 : 1.0 - (u - 0.55) / 0.45) * (0.8 + 0.2 * pulse);
    p.dot(
      x.toDouble(),
      0,
      u < 0.2
          ? kWhite
          : u < 0.5
              ? c[6]
              : c[5],
      a,
    );
    if (u < 0.3) {
      p.dot(x.toDouble(), 1, u < 0.15 ? c[5] : c[4], u < 0.15 ? 1.0 : 0.5);
    }
  }
}

final PureEffect portalEffect = PureEffect(
  meta: const EffectMeta(
    id: 'arcane/portal',
    name: 'Portal',
    desc:
        'An upright rift: fibrous spiral arms wind down into the dark, a lit rim wobbles, motes and streaks are pulled in, the floor glows.',
    category: 'arcane',
    tags: ['arcane', 'portal', 'rift', 'teleport', 'magic', 'ground', 'loop'],
    size: (152, 116),
    origin: (76, 106),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {'palette': Pal.arcane, 'width': 17, 'height': 29, 'seed': 4},
  ),
  onDrawBack: (p, t, o) {
    _floor(p, _setup(t, o));
  },
  onDraw: (p, t, o) {
    final s = _setup(t, o);
    final c = s.c;
    final cy = s.cy;
    final rx = s.rx;
    final ry = s.ry;
    final ph = s.ph;
    final pulse = 0.85 + 0.15 * math.sin(ph * tau * 2.0);
    _rift(p, s);
    _well(p, s);
    _orbit(p, s);
    _infall(p, s);
    _skaters(p, s);
    p.glow(0, cy, ry * 5.0, c[4], 0.17 * pulse);
    p.glow(0, cy, ry * 2.6, c[4], 0.1 * pulse);
    for (var i = 0; i < 16; i++) {
      final th = (i / 16.0) * tau;
      final r0 = s.rim(th) * 1.08;
      p.glow(math.cos(th) * r0 * rx, cy + math.sin(th) * r0 * ry, 15, c[4],
          0.15 * pulse);
    }
    for (final th in s.spots) {
      final r0 = s.rim(th);
      p.glow(math.cos(th) * r0 * rx, cy + math.sin(th) * r0 * ry, 16, c[6],
          0.42);
    }
    for (var i = -3; i <= 3; i++) {
      p.glow(i * 7.0, -1, 16, c[5], 0.12 * pulse);
    }
  },
);
