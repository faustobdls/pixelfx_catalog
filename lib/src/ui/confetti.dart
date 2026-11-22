// The flutter (a swing that slows at its ends, a tilt that follows it, a paper flip that shows the back) adapts
// Sprite Fusion's open-source falling leaves (https://www.spritefusion.com/pixel-art-vfx/falling-leaves),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

class _Popper {
  final double x;
  final double y;
  final double a;
  final double t;

  const _Popper({
    required this.x,
    required this.y,
    required this.a,
    required this.t,
  });
}

const List<_Popper> _poppers = [
  _Popper(x: -74.0, y: -1.0, a: -math.pi / 2.0 + 0.62, t: 0.1),
  _Popper(x: 74.0, y: -1.0, a: -math.pi / 2.0 - 0.62, t: 0.26),
];

final int _ink = hex('#141019');
final int _offWhite = hex('#c8c0d8');
final int _smokeCol = hex('#5d5660');

void _drawPopper(
  Painter p,
  double x,
  double y,
  double a,
  double k,
  List<int> c,
  double alpha,
) {
  final ca = math.cos(a);
  final sa = math.sin(a);
  final bx = x - ca * k;
  final by = y - sa * k;
  p.shade(bx - 12.0, by - 12.0, bx + 12.0, by + 12.0, (px, py, out) {
    final dx = px - bx;
    final dy = py - by;
    final u = dx * ca + dy * sa;
    final v = -dx * sa + dy * ca;
    if (u < 0.0 || u > 11.0) return null;
    final hw = 0.8 + u * 0.32;
    if (v.abs() > hw + 0.6) return null;
    out.a = alpha;
    if (v.abs() > hw - 0.4 || u > 10.2 || u < 0.8) return _ink;
    final stripe = ((u + v * 0.6) / 2.2).floor() % 2 == 0;
    return stripe
        ? (v < 0.0 ? c[2] : scaleColor(c[2], 0.75))
        : (v < 0.0 ? kWhite : _offWhite);
  });
}

class _Bit {
  double x;
  double y;
  double vx;
  double vy;
  final int c;
  final double w;
  final double h;
  double ang;
  final double spin;
  double flip;
  final double fs;
  double ph;
  final double amp;
  final double fw;
  double x0 = 0.0;
  int mode = 0;
  double rest = 0.0;
  final double fall;

  _Bit({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.c,
    required this.w,
    required this.h,
    required this.ang,
    required this.spin,
    required this.flip,
    required this.fs,
    required this.ph,
    required this.amp,
    required this.fw,
    required this.fall,
  });
}

class _Pt {
  double x;
  double y;
  _Pt(this.x, this.y);
}

class _Ribbon {
  final List<_Pt> pts;
  double vx;
  double vy;
  final int c;
  double ph;
  final double amp;
  final double fw;
  int mode = 0;
  double x0 = 0.0;
  final double curl;
  final double fall;

  _Ribbon({
    required this.pts,
    required this.vx,
    required this.vy,
    required this.c,
    required this.ph,
    required this.amp,
    required this.fw,
    required this.curl,
    required this.fall,
  });
}

class _ConfettiSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  final List<_Bit> bits = [];
  final List<_Ribbon> ribbons = [];
  final List<bool> fired = [false, false];
  static const double _end = 3.4 - 0.05;

  double t = 0.0;

  _ConfettiSim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        r = Rng(o.seed) {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [
        hex('#ffffff'),
        hex('#fff3a6'),
        hex('#ffc23d'),
        hex('#ff8a2a'),
      ],
    );
  }

  double _kick(double time, _Popper pp) =>
      time < pp.t ? 0.0 : 3.0 * math.exp(-(time - pp.t) * 14.0);

  void _fire(_Popper pp) {
    final mx = pp.x + math.cos(pp.a) * 11.0;
    final my = pp.y + math.sin(pp.a) * 11.0;
    lights.add(mx, my, 34, kWhite, 0.6, 0.12);
    lights.add(mx, my, 50, c[2], 0.4, 0.4);
    for (var i = 0; i < 6; i++) {
      ps.spawn(
        P.smoke,
        mx,
        my,
        math.cos(pp.a) * r.range(20.0, 60.0) + r.range(-10.0, 10.0),
        math.sin(pp.a) * r.range(20.0, 60.0),
        r.range(0.6, 1.0),
        _smokeCol,
        r.range(2.5, 4.0),
      );
    }
    for (var i = 0; i < 12; i++) {
      final an = pp.a + r.range(-0.5, 0.5);
      final sp = r.range(120.0, 260.0);
      ps.spawn(
        P.spark,
        mx,
        my,
        math.cos(an) * sp,
        math.sin(an) * sp,
        r.range(0.1, 0.25),
      );
    }
    for (var i = 0; i < 46; i++) {
      final an = pp.a + r.range(-0.38, 0.38);
      final sp = r.range(200.0, 380.0);
      bits.add(_Bit(
        x: mx,
        y: my,
        vx: math.cos(an) * sp,
        vy: math.sin(an) * sp,
        c: r.pick(c),
        w: r.range(2.0, 3.0),
        h: r.range(3.0, 4.6),
        ang: r.range(0.0, tau),
        spin: r.range(-14.0, 14.0),
        flip: r.range(0.0, tau),
        fs: r.range(5.0, 13.0),
        ph: r.range(0.0, tau),
        amp: r.range(5.0, 12.0),
        fw: r.range(2.0, 3.4),
        fall: r.range(26.0, 40.0),
      ));
    }
    for (var i = 0; i < 4; i++) {
      final an = pp.a + r.range(-0.25, 0.25);
      final sp = r.range(220.0, 330.0);
      ribbons.add(_Ribbon(
        pts: List<_Pt>.generate(11, (_) => _Pt(mx, my)),
        vx: math.cos(an) * sp,
        vy: math.sin(an) * sp,
        c: r.pick(c),
        ph: r.range(0.0, tau),
        amp: r.range(6.0, 12.0),
        fw: r.range(1.5, 2.4),
        curl: r.range(0.7, 1.1),
        fall: r.range(22.0, 32.0),
      ));
    }
  }

  @override
  void update(double dt, Map<String, Object?> options) {
    t += dt;
    for (var i = 0; i < _poppers.length; i++) {
      final pp = _poppers[i];
      if (!fired[i] && t >= pp.t) {
        fired[i] = true;
        _fire(pp);
      }
    }

    for (final b in bits) {
      if (b.mode == 2) {
        b.rest += dt;
        continue;
      }
      b.flip += b.fs * dt;
      if (b.mode == 0) {
        b.vx -= b.vx * 3.4 * dt;
        b.vy -= b.vy * 3.4 * dt - 140.0 * dt;
        b.x += b.vx * dt;
        b.y += b.vy * dt;
        b.ang += b.spin * dt;
        if (hypot(b.vx, b.vy) < 40.0) {
          b.mode = 1;
          b.x0 = b.x - math.sin(b.ph) * b.amp;
        }
      } else {
        b.ph += b.fw * dt;
        b.x0 += b.vx * dt;
        b.vx -= b.vx * 2.0 * dt;
        b.x = b.x0 + math.sin(b.ph) * b.amp;
        b.y += b.fall * (0.4 + 0.9 * math.cos(b.ph).abs()) * dt;
        b.ang = math.cos(b.ph) * 0.9;
        if (b.y >= -1.0) {
          b.y = -0.5;
          b.mode = 2;
          b.ang = r.range(-0.3, 0.3);
          b.flip = 0.0;
        }
      }
    }

    for (final rib in ribbons) {
      final h = rib.pts[0];
      if (rib.mode == 0) {
        rib.vx -= rib.vx * 3.0 * dt;
        rib.vy -= rib.vy * 3.0 * dt - 120.0 * dt;
        h.x += rib.vx * dt;
        h.y += rib.vy * dt;
        if (hypot(rib.vx, rib.vy) < 35.0) {
          rib.mode = 1;
          rib.x0 = h.x - math.sin(rib.ph) * rib.amp;
        }
      } else if (h.y < -1.0) {
        rib.ph += rib.fw * dt;
        rib.x0 += rib.vx * dt;
        rib.vx -= rib.vx * 2.0 * dt;
        h.x = rib.x0 + math.sin(rib.ph) * rib.amp;
        h.y += rib.fall * (0.5 + 0.7 * math.cos(rib.ph).abs()) * dt;
      }
      for (var i = 1; i < rib.pts.length; i++) {
        final a = rib.pts[i - 1];
        final b = rib.pts[i];
        b.y = math.min(-0.5, b.y + 20.0 * dt);
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final dRaw = hypot(dx, dy);
        final d = dRaw == 0.0 ? 1.0 : dRaw;
        if (d > 2.6) {
          b.x = a.x + (dx / d) * 2.6;
          b.y = a.y + (dy / d) * 2.6;
        }
      }
    }

    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final fade = 1.0 - seg(t, _end - 0.45, _end - 0.05);
    for (final pp in _poppers) {
      final k = _kick(t, pp);
      _drawPopper(p, pp.x, pp.y, pp.a, k, c, 1.0 - seg(t, 2.5, 2.9));
      final ft = t - pp.t;
      if (ft > 0.0 && ft < 0.12) {
        sparkle(
          p,
          pp.x + math.cos(pp.a) * 13.0,
          pp.y + math.sin(pp.a) * 13.0,
          7.0 * (1.0 - ft / 0.12),
          kWhite,
          c[2],
          0.7,
        );
      }
    }

    for (final rib in ribbons) {
      final pts = [
        for (var i = 0; i < rib.pts.length; i++)
          (
            rib.pts[i].x +
                math.sin(i * rib.curl + t * 9.0 + rib.ph) *
                    (i != 0 ? 1.6 : 0.0),
            rib.pts[i].y,
          ),
      ];
      for (var i = 1; i < pts.length; i++) {
        final (x0, y0) = pts[i - 1];
        final (x1, y1) = pts[i];
        final front = math.sin(i * rib.curl + t * 9.0 + rib.ph) > 0.0;
        p.line(x0, y0, x1, y1, front ? rib.c : scaleColor(rib.c, 0.6), fade);
        p.line(
          x0 + 1.0,
          y0,
          x1 + 1.0,
          y1,
          front ? mix(rib.c, kWhite, 0.35) : scaleColor(rib.c, 0.45),
          fade,
        );
      }
    }

    for (final b in bits) {
      if (b.y > 1.0) continue;
      final fw = b.mode == 2 ? 1.0 : math.cos(b.flip);
      final w = math.max(0.5, fw.abs() * b.w);
      final ca = math.cos(b.ang);
      final sa = math.sin(b.ang);
      final col = fw >= 0.0 ? b.c : scaleColor(b.c, 0.62);
      if (b.mode == 2) {
        p.dot(b.x, b.y, scaleColor(b.c, 0.8), fade);
        p.dot(b.x + 1.0, b.y, scaleColor(b.c, 0.6), fade);
        continue;
      }
      p.shade(b.x - 4.0, b.y - 4.0, b.x + 4.0, b.y + 4.0, (x, y, out) {
        final dx = x - b.x;
        final dy = y - b.y;
        final u = dx * ca + dy * sa;
        final v = -dx * sa + dy * ca;
        if (u.abs() > w / 2.0 + 0.2 || v.abs() > b.h / 2.0) return null;
        out.a = fade;
        return fw.abs() > 0.92 && v < -b.h / 2.0 + 1.0 ? kWhite : col;
      });
      if (fw.abs() > 0.97) {
        p.glow(b.x, b.y, 5, mix(b.c, kWhite, 0.5), 0.35 * fade);
      }
    }

    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect confettiEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ui/confetti',
    name: 'Confetti',
    desc:
        'Two party poppers bang one after the other: paper bits and curly streamers burst out, stall, then tumble and flutter down, flipping, and settle on the floor.',
    category: 'ui',
    tags: ['ui', 'celebration', 'confetti', 'party', 'reward', 'one-shot'],
    size: (200, 140),
    origin: (100, 126),
    duration: 3.4,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#ff4a5a',
        '#ff9a2a',
        '#ffe03c',
        '#5ad84a',
        '#3cc8ff',
        '#7a6cff',
        '#f53cd1',
      ],
      'seed': 11,
    },
  ),
  onCreate: _ConfettiSim.new,
);
