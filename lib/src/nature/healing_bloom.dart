// The healing light (a soft column of glow, a lit ring on the floor, motes and bevelled crosses drifting up and
// glinting) is adapted from Sprite Fusion's open-source heal (https://www.spritefusion.com/pixel-art-vfx/heal),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'nature_lib.dart';

const double _stem = 0.42;
const double _bud = 0.75;
const double _open = 1.05;
const double _lift = 1.7;
const double _wilt = 2.4;
const double _h = 36.0;
const int _npet = 6;
const double _dur = 3.3;

void _cross(
  Painter p,
  double x,
  double y,
  int l,
  List<int> c,
  double a,
  bool glint,
) {
  final cx = (x + 0.5).floor();
  final cy = (y + 0.5).floor();
  bool ins(int dx, int dy) =>
      (dx == 0 && dy.abs() <= l) || (dy == 0 && dx.abs() <= l);
  for (var dy = -l - 1; dy <= l + 1; dy++) {
    for (var dx = -l - 1; dx <= l + 1; dx++) {
      if (ins(dx, dy)) {
        p.dot(
          cx + dx,
          cy + dy,
          glint && dx == 0 && dy == 0
              ? kWhite
              : (dy < 0 || dx < 0 ? c[6] : c[5]),
          a,
        );
      } else if (l > 1 &&
          (ins(dx - 1, dy) ||
              ins(dx + 1, dy) ||
              ins(dx, dy - 1) ||
              ins(dx, dy + 1))) {
        p.dot(cx + dx, cy + dy, c[2], a * 0.8);
      }
    }
  }
  p.glow(x, y, 5 + l * 2, c[6], 0.35 * a);
}

class _Petal {
  final double az;
  final double off;
  bool gone = false;
  final double at;

  _Petal(this.az, this.off, this.at);
}

class _FlyingPetal {
  double x;
  double y;
  double vx;
  double vy;
  double a;
  final double va;
  double fl;
  final double vf;
  double life;
  final double max;

  _FlyingPetal({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.a,
    required this.va,
    required this.fl,
    required this.vf,
    required this.life,
  }) : max = life;
}

class _Glyph {
  final double x;
  final double y;
  final double t0;
  final double life;
  final int l;
  final double seed;

  _Glyph(this.x, this.y, this.t0, this.life, this.l, this.seed);
}

class _HealingBloomSim extends BaseEffectSim {
  final List<int> c;
  final List<int> pt;
  final List<int> ht;
  final Rng r;
  final Particles ps;
  final Lights lights;
  final List<_FlyingPetal> flying = [];
  final List<_Glyph> glyphs = [];
  final List<_Petal> petals;

  double t = 0.0;
  bool popped = false;
  bool sprouted = false;

  _HealingBloomSim._({
    required this.c,
    required this.pt,
    required this.ht,
    required this.r,
    required this.ps,
    required this.lights,
    required this.petals,
  });

  factory _HealingBloomSim(Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final pt = fit(o.rampOpt('petal'), 4);
    final ht = fit(o.rampOpt('heart'), 4);
    final r = Rng(o.seed);
    double floorFn(double _) => 0.0;
    final ps = Particles(
      rng: r,
      ground: floorFn,
      sparks: [ht[3], ht[2], ht[1], ht[0]],
    );
    final lights = Lights();
    final petals = List.generate(
      _npet,
      (i) => _Petal(
        (i / _npet) * tau + 0.3,
        (i * 0.7) % 1.0,
        _lift + ((i * 0.37) % 1.0) * 0.55,
      ),
    );
    return _HealingBloomSim._(
      c: c,
      pt: pt,
      ht: ht,
      r: r,
      ps: ps,
      lights: lights,
      petals: petals,
    );
  }

  double _grow() =>
      Ease.outCubic(clamp(t / _stem)) *
      (1 - Ease.inCubic(clamp((t - _wilt) / 0.6)));

  double _sway() => math.sin(t * 2.6) * 1.4 * smooth(0.2, 0.6, t);

  List<Point2> _stemPts() {
    final g = _grow();
    final sw = _sway();
    return List.generate(13, (i) {
      final s = i / 12;
      return (
        math.sin(s * 3.2) * 2.2 * s + sw * s * s,
        (1 - g) * _h * 1.1 - s * _h,
      );
    }, growable: false);
  }

  double _openAmt() => Ease.outBack(clamp((t - _bud) / (_open - _bud)), 1.4);

  void _drawPetal(Painter p, _Petal q, Point2 top) {
    final op = _openAmt();
    final e = lerp(0.15, math.pi / 2 - 0.2, op);
    final dx = math.sin(e) * math.cos(q.az);
    final dz = math.sin(e) * math.sin(q.az);
    final dy = -math.cos(e);
    final l = lerp(8, 12, op);
    final len = l * hypot(dx, dy);
    final ang = math.atan2(dy, dx);
    final back = dz < 0;
    final cy = top.$2 - 3;
    if (len < 1.5) return;
    drawLeaf(
      p,
      top.$1 + dx * l * 0.5,
      cy + dy * l * 0.5,
      len + 1,
      3 + (1 - dz.abs()) * 0.8,
      ang,
      back ? 0.9 : 0.2,
      back ? [pt[0], pt[0], pt[1], pt[2]] : [pt[0], pt[1], pt[2], pt[3]],
    );
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final f = math.min(1.0, dt * 120);
    final top = _stemPts()[12];
    if (!sprouted) {
      sprouted = true;
      for (var i = 0; i < 8; i++) {
        ps.spawn(
          P.grit,
          r.range(-3, 3),
          -1,
          r.range(-40, 40),
          -r.range(40, 100),
          r.range(0.5, 0.8),
          r.pick([c[2], c[3]]),
          1,
        );
      }
      for (var i = 0; i < 3; i++) {
        ps.spawn(
          P.dust,
          r.range(-3, 3),
          -1,
          r.sign() * r.range(10, 30),
          -r.range(4, 10),
          r.range(0.4, 0.6),
          c[3],
          r.range(1.5, 2.5),
        );
      }
    }
    if (t > _stem && t < _bud && r.chance(0.3 * f)) {
      final a = r.range(0, tau);
      final d = r.range(14, 26);
      final x = top.$1 + math.cos(a) * d;
      final y = top.$2 - 3 + math.sin(a) * d * 0.8;
      ps.spawn(
        P.streak,
        x,
        y,
        (top.$1 - x) * 3.4,
        (top.$2 - 3 - y) * 3.4,
        r.range(0.18, 0.26),
        r.chance(0.5) ? ht[2] : c[6],
      );
    }
    if (!popped && t >= _open - 0.12) {
      popped = true;
      lights.add(top.$1, top.$2 - 3, 22, kWhite, 0.45, 0.08);
      lights.add(top.$1, top.$2 - 3, 70, ht[2], 0.5, 0.8);
      for (var i = 0; i < 16; i++) {
        final a = r.range(0, tau);
        final sp = r.range(40, 120);
        ps.spawn(
          P.mote,
          top.$1,
          top.$2 - 3,
          math.cos(a) * sp,
          math.sin(a) * sp - 20,
          r.range(0.4, 0.8),
          r.chance(0.5) ? ht[3] : c[7],
          0.7,
        );
      }
      for (var i = 0; i < 5; i++) {
        ps.spawn(
          P.star,
          top.$1 + r.range(-10, 10),
          top.$2 - r.range(0, 14),
          0,
          -6,
          r.range(0.3, 0.6),
          ht[3],
          r.range(1, 2.4),
          r.range(0, 0.3),
        );
      }
    }
    if (t > _open && t < _wilt && r.chance(0.13 * f)) {
      glyphs.add(_Glyph(
        r.range(-22, 22),
        -r.range(2, 36),
        t,
        math.min(r.range(0.7, 1.1), _dur - 0.05 - t),
        r.chance(0.35) ? 3 : 2,
        r.next() * 9,
      ));
    }
    if (t > _open - 0.1 && t < _wilt && r.chance(0.35 * f)) {
      ps.spawn(
        P.ember,
        r.range(-20, 20),
        -r.range(0, 8),
        r.range(-6, 6),
        -r.range(25, 55),
        math.min(r.range(0.6, 1.1), _dur - 0.05 - t),
        r.chance(0.6) ? c[6] : ht[2],
        r.chance(0.3) ? 2 : 1,
      );
    }
    for (var i = glyphs.length - 1; i >= 0; i--) {
      if (t - glyphs[i].t0 > glyphs[i].life) glyphs.removeAt(i);
    }
    for (final q in petals) {
      if (!q.gone && t >= q.at) {
        q.gone = true;
        final e = math.pi / 2 - 0.15;
        final dx = math.sin(e) * math.cos(q.az);
        const l = 10.0;
        flying.add(_FlyingPetal(
          x: top.$1 + dx * l * 0.6,
          y: top.$2 - 3 - math.cos(e) * l * 0.6,
          vx: dx * 30 + r.range(-10, 10),
          vy: -r.range(25, 45),
          a: math.atan2(-math.cos(e), dx),
          va: r.range(-5, 5),
          fl: 0,
          vf: r.range(5, 9),
          life: math.min(r.range(0.75, 1.0), _dur - 0.45 - t),
        ));
      }
    }
    for (var i = flying.length - 1; i >= 0; i--) {
      final q = flying[i];
      if ((q.life -= dt) <= 0) {
        ps.spawn(
          P.star,
          q.x,
          q.y,
          0,
          -8,
          math.min(0.35, _dur - 0.05 - t),
          pt[3],
          1.8,
        );
        flying.removeAt(i);
        continue;
      }
      q.vx -= q.vx * 1.5 * dt;
      q.vy -= q.vy * 0.8 * dt + 10 * dt;
      q.x += q.vx * dt + math.sin(q.fl) * 12 * dt;
      q.y += q.vy * dt;
      q.a += q.va * dt;
      q.fl += q.vf * dt;
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final bloom = smooth(_open - 0.15, _open + 0.2, t) *
        (1 - smooth(_wilt - 0.2, _wilt + 0.5, t));
    final top = _stemPts()[12];
    for (var h = 0; h < 70; h += 7) {
      p.glow(0, -h, 22, c[5], 0.12 * bloom * (1 - h / 80));
    }
    final k = clamp((t - _open + 0.12) / 0.6);
    if (k > 0 && k < 1) {
      band(
        p,
        0,
        0.5,
        6 + 30 * Ease.outCubic(k),
        0.18,
        math.max(1.0, 3 * (1 - k)),
        1.1 - k,
        [c[3], c[5], ht[2], ht[3]],
        keep: (g) => math.sin(g) < 0,
      );
    }
    final fw = 6 + 16 * smooth(0, 0.8, t);
    for (var x = (-fw).floor(); x <= fw; x++) {
      final u = x.abs() / fw;
      final a = math.sqrt(1 - u) *
          smooth(0, 0.4, t) *
          (1 - smooth(_wilt, _wilt + 0.6, t));
      p.dot(x, 0, u < 0.3 ? c[6] : (u < 0.65 ? c[5] : c[4]), a);
      if (x % 5 == 0) p.glow(x, 0, 8, c[5], 0.2 * a * (1 - u));
    }
    if (t > _bud - 0.05) {
      for (final q in petals) {
        if (math.sin(q.az) < 0 && !q.gone) _drawPetal(p, q, top);
      }
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final pts = _stemPts();
    final top = pts[12];
    final g = _grow();
    if (g > 0.02) {
      for (var i = 1; i < pts.length; i++) {
        final (x0, y0) = pts[i - 1];
        final (x1, y1) = pts[i];
        if (y1 > 0) continue;
        p.line(x0, y0, x1, y1, c[5]);
        p.line(x0 + 1, y0, x1 + 1, y1, c[3]);
      }
      for (final (i, sd, d) in const [(4, -1, 0.1), (7, 1, 0.22)]) {
        final lk = Ease.outBack(clamp((t - d - 0.12) / 0.3), 1.6) *
            (1 - smooth(_wilt, _wilt + 0.5, t) * 0.4);
        final (x, y) = pts[i];
        if (lk <= 0 || y > -1) continue;
        final la = sd < 0 ? -2.6 + 0.4 * (1 - lk) : -0.55 - 0.4 * (1 - lk);
        drawLeaf(
          p,
          x + math.cos(la) * 6 * lk,
          y + math.sin(la) * 6 * lk,
          12 * lk,
          3.4,
          la,
          0.25,
          [c[1], c[3], c[5], c[6]],
        );
      }
      if (t > _stem - 0.1 && t < _open - 0.1) {
        final b = clamp((t - _stem + 0.1) / (_bud - _stem));
        final w = 2 + 2.5 * b;
        final h = 3.5 + 5 * b;
        p.ellipseShaded(
          top.$1,
          top.$2 - h * 0.6,
          w,
          h,
          color: (d, a) => math.cos(a) < -0.2
              ? pt[2]
              : d > 0.7
                  ? pt[0]
                  : pt[1],
        );
        p.glow(top.$1, top.$2 - h * 0.6, 8 + 8 * b, ht[2], 0.25 * b);
      }
    }
    for (final q in petals) {
      if (math.sin(q.az) >= 0 && !q.gone && t > _bud - 0.05) {
        _drawPetal(p, q, top);
      }
    }
    if (t > _open - 0.12 && t < _wilt + 0.3) {
      final pulse = 0.85 + 0.15 * math.sin(t * 9);
      final k = 1 - smooth(_wilt - 0.3, _wilt + 0.3, t);
      final cy = top.$2 - 4;
      p.circle(top.$1, cy, 3.3 * k, ht[1]);
      p.circle(top.$1 - 0.5, cy - 0.5, 2.2 * k, ht[2]);
      p.px(top.$1 - 1, cy - 1, ht[3]);
      p.glow(top.$1, cy, 16 * pulse, ht[2], 0.5 * k);
      p.glow(top.$1, cy, 34, c[5], 0.2 * k);
    }
    final e = t - _open + 0.12;
    if (e > 0 && e < 0.16) {
      sparkle(p, top.$1, top.$2 - 3, 10 * (1 - e / 0.16), ht[3], ht[2], 0.6);
    }
    for (final q in flying) {
      drawLeaf(
        p,
        q.x,
        q.y,
        6,
        2.2,
        q.a,
        q.fl,
        [pt[0], pt[1], pt[2], pt[3]],
        math.min(1.0, q.life / 0.3),
      );
    }
    for (final q in glyphs) {
      final k = (t - q.t0) / q.life;
      _cross(
        p,
        q.x + math.sin(k * 5 + q.seed) * 2,
        q.y - k * 24,
        q.l,
        c,
        math.sin(math.pi * k),
        math.sin(k * 14 + q.seed) > 0.8,
      );
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final PixelEffect healingBloom = SimulatedEffect(
  meta: const EffectMeta(
    id: 'nature/healing-bloom',
    name: 'Healing bloom',
    desc:
        'A sprout pushes up and unfurls, a bud swells and opens round a glowing golden heart in a flare of healing light; its petals lift away one by one as motes.',
    category: 'nature',
    tags: [
      'nature',
      'heal',
      'flower',
      'plant',
      'buff',
      'ground',
      'one-shot',
    ],
    size: (124, 120),
    origin: (62, 108),
    duration: 3.3,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#0c1a10',
        '#173a1a',
        '#24582a',
        '#357a34',
        '#52a03e',
        '#86c84e',
        '#c4ec7a',
        '#f4ffd0',
      ],
      'petal': ['#4a1a3a', '#a8406e', '#ec8ab0', '#ffd8e8'],
      'heart': ['#a8641a', '#f0b42e', '#ffe680', '#fffbe0'],
      'seed': 4,
    },
  ),
  onCreate: _HealingBloomSim.new,
);
