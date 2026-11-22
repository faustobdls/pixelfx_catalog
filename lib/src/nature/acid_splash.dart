// The drops that splat where they land are adapted from Sprite Fusion's open-source blood
// (https://www.spritefusion.com/pixel-art-vfx/blood), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'nature_lib.dart';

const double _hit = 0.3;
const double _y0 = -62.0;
const double _v0 = 60.0;
const double _spread = 0.4;
const double _dry = 0.7;
const double _gone = 2.2;
const double _w = 30.0;
const double _pit = 5.0;
const double _dur = 2.8;

class _Spike {
  final double a;
  final double h;
  final double r;
  bool shed = false;

  _Spike(this.a, this.h, this.r);
}

class _Stain {
  final double x;
  final double t0;
  final double w;

  _Stain(this.x, this.t0, this.w);
}

class _Wisp {
  final double x;
  final double y;
  final double t0;
  final double life;
  final double rise;
  final double len;
  final double amp;
  final double k;
  final double ph;
  final double drift;

  _Wisp({
    required this.x,
    required this.y,
    required this.t0,
    required this.life,
    required this.rise,
    required this.len,
    required this.amp,
    required this.k,
    required this.ph,
    required this.drift,
  });
}

class _Pop {
  final double x;
  final double y;
  final double t0;

  _Pop(this.x, this.y, this.t0);
}

void _drawWisp(Painter p, _Wisp q, double t, int col) {
  final age = t - q.t0;
  final u = age / q.life;
  if (u < 0 || u >= 1) return;
  final head = q.rise * age;
  final tail = math.max(0.0, head - q.len);
  final fade = smooth(0, 0.15, u) * (1 - smooth(0.4, 1, u));
  for (var h = tail; h <= head; h += 0.5) {
    final s = (h - tail) / math.max(1.0, head - tail);
    final x = q.x + q.amp * math.sin(h * q.k + q.ph) * (0.2 + s) + q.drift * age;
    p.blend(x, q.y - h, col, fade * math.sin(math.pi * s) * 0.42);
  }
}

class _AcidSplashSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final int scorch;
  final int burnt;
  final int steamCol;
  final Particles ps;
  final Drops drops;
  final Lights lights;
  final List<_Stain> stains = [];
  final List<_Wisp> wisps = [];
  final List<_Pop> pops = [];
  final List<_Spike> spikes;
  final List<double> rag;

  double t = 0.0;
  bool hit = false;

  _AcidSplashSim._({
    required this.c,
    required this.r,
    required this.scorch,
    required this.burnt,
    required this.steamCol,
    required this.ps,
    required this.drops,
    required this.lights,
    required this.spikes,
    required this.rag,
  });

  factory _AcidSplashSim(Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final r = Rng(o.seed);
    double floorFn(double _) => 0.0;
    final scorch = mix(c[0], hex('#140f0c'), 0.6);
    final burnt = mix(c[1], hex('#2a1a10'), 0.6);
    final steamCol = mix(c[7], hex('#e8ece6'), 0.75);
    final ps = Particles(
      rng: r,
      ground: floorFn,
      sparks: [c[7], c[6], c[5], c[4]],
    );
    final drops = Drops(floorFn);
    final lights = Lights();
    final spikes = List.generate(
      13,
      (i) => _Spike(
        (i / 13) * tau + r.range(-0.18, 0.18),
        r.range(4, 10),
        r.range(0.85, 1.12),
      ),
    );
    final rag = List.generate(80, (i) => rand(i, o.seed, 5) - 0.5);
    return _AcidSplashSim._(
      c: c,
      r: r,
      scorch: scorch,
      burnt: burnt,
      steamCol: steamCol,
      ps: ps,
      drops: drops,
      lights: lights,
      spikes: spikes,
      rag: rag,
    );
  }

  double _pw() => _w * Ease.outCubic(clamp((t - _hit) / _spread)) * 1.02;
  double _pitD() => _pit * Ease.outCubic(clamp((t - _hit) / 1.1));

  double _depth(double x) {
    final w = _pw();
    final d = x.abs() / math.max(1.0, w);
    if (d >= 1) return -1;
    return _pitD() * math.sqrt(1 - d * d) +
        rag[((x + 0.5).floor() + 200) % 80] * 0.9;
  }

  double _level() =>
      t < _hit ? 0.0 : -1.6 + (_pit + 1.6) * Ease.inQuad(smooth(_dry, _gone, t));

  double _width() {
    final l = _level();
    final w = _pw();
    if (l <= 0) return w;
    final ratio = l / math.max(0.1, _pitD());
    return w * math.sqrt(math.max(0.0, 1 - ratio * ratio));
  }

  double _heat() =>
      smooth(_hit, _hit + 0.3, t) * (1 - smooth(_gone - 0.3, _gone + 0.25, t));

  double _gobY() => _y0 + _v0 * t + 0.5 * 950 * t * t;
  double _crownR() => 4 + 11 * Ease.outCubic(clamp((t - _hit) / 0.16));
  double _crownH() => 5 * math.sin(math.pi * clamp((t - _hit) / 0.26));

  double _spikeK() {
    final u = clamp((t - _hit - 0.015) / 0.26);
    return math.sin(math.pi * math.pow(u, 0.6));
  }

  (double, double, double, double) _tipOf(_Spike s) {
    final rad = _crownR() * s.r;
    final h = _crownH();
    final sn = math.sin(s.a);
    final sh = s.h * _spikeK();
    final bx = math.cos(s.a) * rad;
    final by = sn * rad * 0.3 - h * (0.75 + 0.25 * sn.abs());
    return (bx, by, bx + math.cos(s.a) * sh * 0.55, by - sh);
  }

  void _steam(double x, double y, bool big) {
    wisps.add(_Wisp(
      x: x,
      y: y,
      t0: t,
      life: math.min(r.range(0.5, 0.9) * (big ? 1.3 : 1), _dur - 0.05 - t),
      rise: r.range(22, 32),
      len: r.range(5, 10) * (big ? 1.4 : 1),
      amp: r.range(1, 2.5),
      k: r.range(0.35, 0.6),
      ph: r.range(0, tau),
      drift: r.range(-4, 4),
    ));
  }

  void _crown(Painter p, bool back) {
    if (t < _hit || t > _hit + 0.27) return;
    final rad = _crownR();
    final h = _crownH();
    final ry = rad * 0.3;
    for (var x = (-rad).floor(); x <= rad.ceil(); x++) {
      final cx = (x + 0.5) / rad;
      if (cx.abs() > 1) continue;
      final e = math.sqrt(1 - cx * cx);
      final yb = (back ? -ry : ry) * e;
      final hh = h * (0.75 + 0.25 * e);
      final yStart = (yb - hh).floor();
      final yEnd = (yb + 0.5).floor();
      for (var y = yStart; y <= yEnd; y++) {
        final rim = y == yStart;
        if (rim) {
          p.px(x, y, back ? c[5] : (cx < 0.1 ? c[7] : c[6]));
        } else {
          final idx = (cx < -0.25 ? 5 : cx > 0.45 ? 3 : 4) - (back ? 1 : 0);
          p.blend(x, y, c[idx], back ? 0.55 : 0.7);
        }
      }
    }
    for (final s in spikes) {
      if ((math.sin(s.a) < 0) != back) continue;
      final (bx, by, tx, ty) = _tipOf(s);
      p.line(bx, by, tx, ty, back ? c[4] : c[6]);
      p.line(
        bx + 1,
        by,
        (bx + tx) / 2 + 0.5,
        (by + ty) / 2,
        back ? c[3] : c[5],
      );
      if (!s.shed) {
        p.px(tx, ty - 1, back ? c[5] : c[7]);
        p.px(tx + 1, ty - 1, c[5]);
      }
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final f = math.min(1.0, dt * 120);
    _width();
    if (!hit && t >= _hit) {
      hit = true;
      lights.add(0, -4, 28, kWhite, 0.6, 0.08);
      lights.add(0, -10, 56, c[5], 0.5, 0.6);
      for (var i = 0; i < 26; i++) {
        final a = -math.pi / 2 + r.range(-1.35, 1.35);
        final sp = r.range(60, 250);
        drops.add(
          r.range(-3, 3),
          -2,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.chance(0.3) ? 2 : 1,
        );
      }
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2 + r.range(-1.2, 1.2);
        final sp = r.range(120, 260);
        ps.spawn(
          P.spark,
          0,
          -2,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.12, 0.3),
        );
      }
      for (var i = 0; i < 5; i++) {
        _steam(r.range(-10, 10), -r.range(2, 6), true);
      }
    }
    if (hit) {
      for (final s in spikes) {
        if (!s.shed && t > _hit + 0.09) {
          s.shed = true;
          final (_, _, tx, ty) = _tipOf(s);
          drops.add(
            tx,
            ty - 1,
            math.cos(s.a) * r.range(30, 80),
            -r.range(50, 130),
            r.chance(0.4) ? 2 : 1,
          );
        }
      }
    }
    drops.update(dt, (d, _) {
      if (d.x.abs() > _pw()) {
        stains.add(_Stain(d.x, t, d.s * 0.8 + r.range(0.3, 1.2)));
      }
      if (t < _gone) _steam(d.x, -1, false);
    });
    final lv = _level();
    final w2 = _width();
    if (t > _hit + 0.15 && t < _gone && w2 > 2) {
      if (r.chance(0.3 * f)) {
        final x = r.range(-0.85, 0.85) * w2;
        final y = math.min(lv, _depth(x)) - 1;
        pops.add(_Pop(x, y, t));
        for (var j = 0; j < r.intRange(1, 3); j++) {
          drops.add(
            x,
            math.min(y - 1, -1.0),
            r.range(-40, 40),
            -r.range(50, 110),
            1,
          );
        }
      }
      if (r.chance(0.14 * f)) {
        _steam(r.range(-0.9, 0.9) * w2, math.min(lv, 0.0) - 1, r.chance(0.25));
      }
    }
    if (t > _gone - 0.2 && t < _dur - 0.5 && r.chance(0.08 * f)) {
      _steam(r.range(-0.7, 0.7) * _pw(), 0, false);
    }
    for (var i = pops.length - 1; i >= 0; i--) {
      if (t - pops[i].t0 > 0.1) pops.removeAt(i);
    }
    for (var i = wisps.length - 1; i >= 0; i--) {
      if (t - wisps[i].t0 > wisps[i].life) wisps.removeAt(i);
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final fade = 1 - smooth(_dur - 0.6, _dur - 0.08, t);
    final hk = _heat();
    final w = _pw();
    final lv = _level();
    for (final s in stains) {
      final age = t - s.t0;
      final k = 1 - smooth(1, 1.8, age);
      final col = age < 0.15
          ? c[7]
          : age < 0.5
              ? c[6]
              : age < 0.9
                  ? c[4]
                  : burnt;
      for (var x = (s.x - s.w).floor(); x <= (s.x + s.w).ceil(); x++) {
        p.dot(x, 0, (x - s.x).abs() < s.w * 0.5 ? scorch : col, k * fade);
      }
      if (age < 0.5) p.glow(s.x, -1, 5, c[5], 0.3 * (1 - age / 0.5));
    }
    _crown(p, true);
    if (t > _hit && w > 1) {
      for (var x = (-w).floor() - 1; x <= w.ceil() + 1; x++) {
        final dp = _depth(x + 0.5);
        if (dp < 0) continue;
        final bottom = math.max(0, (dp + 0.5).floor());
        final edge = (x + 0.5).abs() / w > 0.88;
        for (var y = 0; y <= bottom; y++) {
          p.dot(
            x,
            y,
            y == bottom
                ? (hk > 0.5 ? c[6] : (hk > 0.15 ? c[4] : burnt))
                : scorch,
            fade,
          );
        }
        p.dot(
          x,
          bottom + 1,
          hk > 0.5 ? c[5] : (hk > 0.15 ? c[3] : scorch),
          fade * 0.8,
        );
        if (edge) {
          p.dot(x, -1, hk > 0.4 ? c[7] : (hk > 0.1 ? c[5] : burnt), fade);
        }
      }
      for (final sd in const [-1, 1]) {
        p.glow(sd * w, -1, 8, c[6], 0.45 * hk);
      }
      if (t < _gone) {
        for (var x = (-w).floor(); x <= w.ceil(); x++) {
          final dp = _depth(x + 0.5);
          if (dp < 0) continue;
          final d = (x + 0.5).abs() / w;
          final dome = lv < 0
              ? (lv * math.sqrt(math.max(0.0, 1 - d * d)) + 0.5).floor()
              : (lv + 0.5).floor();
          final bottom = (dp + 0.5).floor();
          if (dome > bottom) continue;
          final n = noise(x * 0.25 - t * 2.4, 3) +
              noise(x * 0.1 + t * 1.4, 5) * 0.6;
          for (var y = dome; y <= bottom; y++) {
            p.px(
              x,
              y,
              y == dome
                  ? (n > 0.7 ? c[7] : c[6])
                  : y == dome + 1
                      ? (n > 0.2 ? c[5] : c[4])
                      : y >= bottom
                          ? c[3]
                          : c[4],
            );
          }
        }
      }
      p.glow(0, -6, w * 1.4 + 10, c[4],
          0.3 * hk * (0.85 + 0.15 * math.sin(t * 9)));
      p.glow(0, 1, w * 0.9, c[6], 0.2 * hk);
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    if (t < _hit) {
      final y = _gobY();
      final v = _v0 + 950 * t;
      final st = 1 + v * 0.0022;
      final rx = 2.6 / math.sqrt(st);
      final ry = 2.8 * st;
      p.shade(-rx - 1, y - ry - 4, rx + 1, y + ry + 1, (x, yy, out) {
        final dx = x / rx;
        final dy = (yy - y) / ry;
        final tail =
            dy < 0 && x.abs() < rx * (1 + dy * 0.9) + 0.4 && dy > -1.7;
        final d = dx * dx + dy * dy;
        if (d > 1.25 && !tail) return null;
        out.c = d > 1 && !tail
            ? c[2]
            : dx < -0.2 && dy < -0.1
                ? c[7]
                : dy > 0.45
                    ? c[4]
                    : c[5];
        return null;
      });
      p.px(-1, y - ry * 0.3, kWhite);
      for (var i = 1; i <= 3; i++) {
        p.dot(0, y - ry - 2 - i * 4, c[5], 1 - i * 0.25);
      }
      p.glow(0, y, 10, c[5], 0.45);
    }
    _crown(p, false);
    final e = t - _hit;
    if (e >= 0 && e < 0.07) {
      final k = 1 - e / 0.07;
      p.ellipse(0, -2, 6 + 6 * (1 - k), 2.5, k > 0.5 ? kWhite : c[7]);
      sparkle(p, 0, -4, 8 * k, c[7], c[6], 0.6);
    }
    for (final q in pops) {
      final k = (t - q.t0) / 0.1;
      p.px(q.x, q.y, kWhite);
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, -1)]) {
        p.dot(q.x + dx * (1 + k * 2), q.y + dy * (1 + k * 2), c[7], 1 - k);
      }
      p.glow(q.x, q.y, 4, c[6], 0.4 * (1 - k));
    }
    for (final q in wisps) {
      _drawWisp(p, q, t, steamCol);
    }
    drops.draw(p, c);
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final PixelEffect acidSplash = SimulatedEffect(
  meta: const EffectMeta(
    id: 'nature/acid-splash',
    name: 'Acid splash',
    desc:
        'A gob of acid bursts into a crown and spatters; it eats a glowing, smoking pit into the floor and boils down into it, spitting bright beads, pale steam curling off.',
    category: 'nature',
    tags: [
      'nature',
      'acid',
      'poison',
      'splash',
      'liquid',
      'ground',
      'one-shot',
    ],
    size: (184, 116),
    origin: (92, 100),
    duration: 2.8,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#0e140a',
        '#1c3010',
        '#2c5214',
        '#457e18',
        '#6aae1c',
        '#a0dc2a',
        '#dcff6a',
        '#f8ffd0',
      ],
      'seed': 6,
    },
  ),
  onCreate: _AcidSplashSim.new,
);
