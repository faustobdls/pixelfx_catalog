import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'scifi_lib.dart';

const double _duration = 3.0;
const double _lens = -84.0;
const double _topW = 5.5;
const double _botW = 32.0;

const double _pop = 0.1;
const double _hover = 0.32;
const double _rise = 1.4;
const double _life = _pop + _hover + _rise;

double _half(double y) => lerp(_botW, _topW, clamp(y / _lens));

(double, double, double) _haul(
  double r0,
  double th0,
  int dir,
  double turns,
  double k,
) {
  final s = math.pow(clamp(k), 1.8).toDouble();
  final y = lerp(-2.0, _lens + 5.0, s);
  final th = th0 + dir * tau * turns * s;
  final rr = r0 * (_half(y) / _botW) * (1.0 - 0.5 * s);
  return (math.cos(th) * rr, y, math.sin(th));
}

class _RockSpec {
  final int id;
  final double born;
  final double r0;
  final double th0;
  final int dir;
  final double s;
  final double a0;
  final double va;

  const _RockSpec({
    required this.id,
    required this.born,
    required this.r0,
    required this.th0,
    required this.dir,
    required this.s,
    required this.a0,
    required this.va,
  });
}

class _RockState {
  final double x;
  final double y;
  final double z;
  final double px;
  final double py;
  final double size;
  final double a;
  final double lift;

  const _RockState({
    required this.x,
    required this.y,
    required this.z,
    required this.px,
    required this.py,
    required this.size,
    required this.a,
    required this.lift,
  });
}

_RockState _rockAt(_RockSpec r, double age) {
  final lift = clamp((age - _pop - _hover) / _rise);
  if (lift > 0.0) {
    final (x, y, z) = _haul(r.r0, r.th0, r.dir, 1.3, lift);
    final (x1, y1, _) = _haul(r.r0, r.th0, r.dir, 1.3, lift - 0.07);
    return _RockState(
      x: x,
      y: y,
      z: z,
      px: x1,
      py: y1,
      size: r.s * (1.0 - 0.6 * math.pow(lift, 2.5).toDouble()),
      a: r.a0 + r.va * age * (0.3 + lift * 2.0),
      lift: lift,
    );
  }
  final y = age < _pop
      ? lerp(3.0, -2.0, age / _pop)
      : -2.0 - 2.0 * smooth(0.0, _hover, age - _pop);
  final wob =
      age > _pop ? math.sin(age * 55.0 + r.th0 * 9.0) * 0.7 : 0.0;
  return _RockState(
    x: math.cos(r.th0) * r.r0 + wob,
    y: y,
    z: 1.0,
    px: 0.0,
    py: 0.0,
    size: r.s,
    a: r.a0 + r.va * age * 0.3,
    lift: 0.0,
  );
}

void _rock(
  Painter p,
  _RockState q,
  _RockSpec r,
  List<int> s,
  List<int> c,
  bool back,
) {
  const n = 6;
  final rad = math.max(0.9, q.size);
  final ca = math.cos(q.a);
  final sa = math.sin(q.a);
  final lit = mix(s[4], c[6], 0.3 + 0.6 * q.lift);

  double radiusAt(double ang) {
    final f = ((((ang / tau) * n) % n) + n) % n;
    final i = f.floor();
    final k = f - i;
    return rad * (0.75 + 0.35 * lerp(rand(r.id, i), rand(r.id, (i + 1) % n), k));
  }

  if (q.lift > 0.15 && !back) {
    p.lineShaded(
      q.px,
      q.py,
      q.x,
      q.y,
      color: (u) => u > 0.6 ? c[5] : c[3],
      alpha: (u) => 0.7 * u,
    );
    for (var i = 1; i <= 3; i++) {
      p.disc(
        lerp(q.x, q.px, i / 3.0),
        lerp(q.y, q.py, i / 3.0) + 1.0,
        rad * (0.5 + 0.25 * i),
        mix(s[3], c[5], 0.4),
        0.22 * (1.0 - i / 4.0) * q.lift,
      );
    }
  }
  p.shade(q.x - rad - 2, q.y - rad - 2, q.x + rad + 2, q.y + rad + 2,
      (x, y, out) {
    final dx = x - q.x;
    final dy = y - q.y;
    final u = dx * ca + dy * sa;
    final v = -dx * sa + dy * ca;
    final d = hypot(u, v);
    final e = radiusAt(math.atan2(v, u));
    if (d > e + 0.8) return null;
    out.c = d > e
        ? s[0]
        : (back
            ? (dy < -0.3 * rad ? s[3] : s[1])
            : (dy < -0.45 * rad
                ? (q.lift > 0.35 && d > e - 1.0 ? c[6] : lit)
                : (dy < -0.1 * rad
                    ? (dx < 0.0 ? s[4] : s[3])
                    : (dy > 0.35 * rad ? s[1] : s[2]))));
    return null;
  });
  if (!back && q.lift > 0.0) {
    p.glow(q.x, q.y - rad, 5.0 + rad, c[5], 0.25 * q.lift);
  }
}

void _pod(Painter p, double t, List<int> c, List<int> h, double y0) {
  final y = (y0 + 0.5).floor();
  p.shade(-21, y - 12, 21, y + 6, (x, yy, out) {
    final dy = yy - y;
    final cx = x / 8.5;
    final cy = (dy + 5.0) / 6.0;
    if (cy < 0.0 && cx * cx + cy * cy <= 1.0) {
      final d = cx * cx + cy * cy;
      final l = -cx * 0.6 - cy * 0.8;
      out.c = d > 0.8
          ? h[0]
          : (l > 0.85
              ? kWhite
              : (l > 0.6 ? c[6] : (l > 0.2 ? c[4] : c[3])));
      return null;
    }
    final hx = x / 20.0;
    final hy = (dy + 0.5) / 4.5;
    if (dy <= 0.0 && hx * hx + hy * hy <= 1.0) {
      final d = hx * hx + hy * hy;
      final l = -hx * 0.55 - hy * 0.7;
      out.c = d > 0.88
          ? h[0]
          : (dy == -2.0
              ? h[1]
              : (l > 0.55
                  ? h[5]
                  : (l > 0.25 ? h[4] : (l > -0.1 ? h[3] : h[2]))));
      return null;
    }
    final w = 19.5 - dy * 2.4;
    if (dy > 0.0 && dy <= 5.0 && x.abs() <= w) {
      out.c = x.abs() > w - 1.0
          ? h[0]
          : (dy == 1.0 ? h[2] : (dy >= 4.0 && x.abs() < 9.0 ? c[3] : h[1]));
    }
    return null;
  });
  for (var i = 0; i < 6; i++) {
    final lx = -15 + i * 6;
    final k = 0.5 + 0.5 * math.cos(tau * (4.0 * (t / _duration) - i / 6.0));
    p.px(lx, y + 1, k > 0.7 ? kWhite : (k > 0.35 ? c[5] : c[2]));
    if (k > 0.5) p.glow(lx, y + 1, 5, c[5], 0.35 * k);
  }
  p.ellipseShaded(
    0,
    y + 5.5,
    7.5,
    2.2,
    color: (d, _) =>
        d < 0.45 ? kWhite : (d < 0.75 ? c[6] : (d < 0.9 ? c[5] : c[3])),
  );
}

void _hoop(Painter p, double y, double rx, int c, bool back) {
  final ry = rx * 0.17;
  final n = (rx * 7.0).ceil();
  for (var i = 0; i < n; i++) {
    final g = (i / n) * tau;
    final s = math.sin(g);
    if ((s >= 0.0) == back) continue;
    p.px(math.cos(g) * rx, y + s * ry, c);
  }
}

class _TractorSetup {
  final List<int> c;
  final List<int> s;
  final List<_RockSpec> rocks;
  final Ghosts g;

  const _TractorSetup(this.c, this.s, this.rocks, this.g);
}

final Map<String, _TractorSetup> _cache = {};

_TractorSetup _setup(Map<String, Object?> o) {
  final pal = o.palette;
  final st = o.rampOpt('stone');
  final key = '${o.seed}:${pal.join(',')}:${st.join(',')}';
  final hit = _cache[key];
  if (hit != null) return hit;

  final c = fit(pal, 8);
  final s = fit(st, 5);
  final rn = Rng(o.seed);
  final rocks = List<_RockSpec>.generate(7, (i) {
    return _RockSpec(
      id: i + o.seed * 31,
      born: (i / 7.0) * _duration + rn.range(-0.06, 0.06),
      r0: rn.range(8.0, 25.0),
      th0: (i.isOdd ? 0.0 : math.pi) + rn.range(-0.45, 0.45),
      dir: rn.sign(),
      s: rn.range(2.4, 4.4),
      a0: rn.range(0.0, tau),
      va: rn.range(-7.0, 7.0),
    );
  });
  final g = Ghosts(_duration, ground: (_) => 0.0, box: (-58.0, -112.0, 58.0, 14.0));
  for (final r in rocks) {
    final x = math.cos(r.th0) * r.r0;
    for (var i = 0; i < 5; i++) {
      g.add(
        r.born + 0.02,
        P.dust,
        x + rn.range(-3.0, 3.0),
        -1.0,
        rn.range(-34.0, 34.0),
        -rn.range(8.0, 26.0),
        rn.range(0.5, 0.9),
        mix(s[3], c[4], 0.3),
        rn.range(2.2, 3.6),
      );
    }
    for (var i = 0; i < 6; i++) {
      g.add(
        r.born + 0.02,
        P.grit,
        x + rn.range(-2.0, 2.0),
        -2.0,
        rn.range(-45.0, 45.0),
        -rn.range(60.0, 150.0),
        rn.range(0.5, 0.9),
        rn.pick([s[2], s[3], s[4]]),
        rn.chance(0.3) ? 2.0 : 1.0,
      );
    }
  }
  for (var i = 0; i < 16; i++) {
    final side = rn.sign();
    g.add(
      rn.range(0.0, _duration),
      P.dust,
      side * rn.range(14.0, 34.0),
      -rn.range(0.0, 3.0),
      -side * rn.range(6.0, 22.0),
      -rn.range(4.0, 14.0),
      rn.range(0.9, 1.5),
      mix(s[3], c[5], 0.3),
      rn.range(2.6, 4.4),
    );
  }
  final v = _TractorSetup(c, s, rocks, g);
  _cache[key] = v;
  return v;
}

void _drawBack(Painter p, double t, Map<String, Object?> o) {
  final st = _setup(o);
  final c = st.c;
  final s = st.s;
  final rocks = st.rocks;
  final g = st.g;

  for (var y = -6; y <= 6; y++) {
    for (var x = -_botW.toInt(); x <= _botW.toInt(); x++) {
      final d = hypot((x + 0.5) / _botW, (y + 0.5) / 5.5);
      if (d <= 1.0) {
        p.blend(
          x + 0.5,
          y + 0.5,
          d < 0.35 ? c[6] : c[5],
          0.2 + 0.55 * math.pow(1.0 - d, 1.5).toDouble(),
        );
      }
    }
  }
  _hoop(p, 0.0, _botW + 1.0, c[5], true);
  g.at(t).draw(p, 'back');
  for (final r in rocks) {
    final age = since(t, r.born, _duration);
    if (age >= _life) continue;
    final q = _rockAt(r, age);
    if (q.z < 0.0 && q.lift > 0.0) _rock(p, q, r, s, c, true);
  }
}

void _draw(Painter p, double t, Map<String, Object?> o) {
  final st = _setup(o);
  final c = st.c;
  final s = st.s;
  final rocks = st.rocks;
  final g = st.g;
  final h = fit(o.rampOpt('hull'), 6);
  final ph = t / _duration;
  final podY = _lens - 5.0 + 1.5 * math.sin(tau * 2.0 * ph);

  for (var y = (_lens + 3.0).ceil(); y < 0; y++) {
    final w = _half(y.toDouble());
    final v = (y - _lens) / -_lens;
    final pulse = ((((v * 3.2 + ph * 6.0) % 1.0) + 1.0) % 1.0) < 0.08 ? 1 : 0;
    for (var x = (-w).floor() - 1; x <= w.ceil(); x++) {
      final q = (x + 0.5).abs() / w;
      if (q > 1.0 + 1.2 / w) continue;
      if (q > 1.0) {
        p.dot(x, y, c[4], 0.6 - 0.3 * v);
      } else if (q > 1.0 - 1.0 / w) {
        p.px(x, y, v < 0.2 ? kWhite : (v < 0.45 ? c[6] : c[5]));
      } else {
        var curtain = 0;
        for (var sc = 0; sc < 4; sc++) {
          if (((x + 0.5) / w -
                      (rand(o.seed, sc, 7) - 0.5) * 1.4 -
                      0.12 * math.sin(tau * ph + sc * 1.7))
                  .abs() <
              0.045) {
            curtain = 1;
          }
        }
        final core =
            (1.0 - q) * (1.0 - q) * math.pow(1.0 - v, 1.6).toDouble();
        final a = 0.08 +
            0.22 * q * q * q * q +
            0.6 * core +
            0.12 * pulse +
            0.18 * curtain;
        p.blend(
          x + 0.5,
          y + 0.5,
          core > 0.45
              ? kWhite
              : (curtain != 0 || pulse != 0 || v < 0.35 ? c[5] : c[4]),
          clamp(a),
        );
      }
    }
    if ((y & 3) == 0) {
      for (final side in const [-1, 1]) {
        p.glow(side * w, y, 8, c[4], 0.18);
      }
    }
  }

  for (var i = 0; i < 5; i++) {
    final k = since(t, (i / 5.0) * _duration, _duration) / 1.1;
    if (k >= 1.0) continue;
    final y = lerp(0.0, _lens + 5.0, Ease.inQuad(k));
    final w = _half(y) + 1.0;
    _hoop(p, y, w, c[3], true);
    _hoop(p, y, w, k < 0.12 ? kWhite : c[6], false);
    p.glow(0, y + w * 0.17, w + 4.0, c[5], 0.12);
  }

  cycle(t, _duration, 22, o.seed + 1, (r) => r.range(0.6, 1.0),
      (age, life, r, _) {
    final k = age / life;
    final y = lerp(-2.0, _lens + 5.0, k * k);
    final w = _half(y);
    final x = r.range(-0.85, 0.85) * w;
    final l = 2.0 + 6.0 * k;
    p.lineShaded(
      x,
      y,
      x,
      y + l,
      color: (u) => u < 0.3 ? kWhite : c[5],
      alpha: (_) => math.min(1.0, (1.0 - k) * 3.0),
    );
  });

  cycle(t, _duration, 9, o.seed + 3, (r) => r.range(1.4, 2.0),
      (age, life, r, _) {
    final k = age / life;
    final (x, y, _) =
        _haul(r.range(8.0, 26.0), r.range(0.0, tau), r.sign(), 0.8, k);
    p.disc(
      x,
      y,
      lerp(4.0, 1.5, k),
      mix(s[3], c[5], 0.25 + 0.5 * k),
      0.4 * math.min(1.0, k * 6.0) * (1.0 - k),
    );
  });

  cycle(t, _duration, 46, o.seed + 2, (r) => r.range(0.8, 1.3),
      (age, life, r, _) {
    final k = age / life;
    final r0 = r.range(6.0, 30.0);
    final th0 = r.range(0.0, tau);
    final dir = r.sign();
    final turns = r.range(1.0, 1.8);
    final mote = r.chance(0.45);
    final (x, y, z) = _haul(r0, th0, dir, turns, k);
    final (x1, y1, _) = _haul(r0, th0, dir, turns, k - (mote ? 0.13 : 0.06));
    final col = mote
        ? (r.chance(0.5) ? kWhite : c[6])
        : r.pick([s[3], s[4], s[4]]);
    p.lineShaded(
      x1,
      y1,
      x,
      y,
      color: (u) => u > 0.5
          ? (z > 0.0 ? col : scaleColor(col, 0.7))
          : (mote ? c[4] : s[2]),
    );
    if (mote) {
      p.px(x, y, kWhite);
      p.glow(x, y, 4, c[5], 0.45);
    }
  });

  cycleFixed(t, _duration, 8, o.seed + 4, 0.5, (age, life, r, _) {
    final k = age / life;
    final (x, y, _) = _haul(
      r.range(4.0, 24.0),
      r.range(0.0, tau),
      r.sign(),
      0.6,
      r.range(0.1, 0.7) + k * 0.15,
    );
    final arm = (2.0 * math.sin(math.pi * k) + 0.5).floor();
    if (arm > 0) sparkle(p, x, y, arm.toDouble(), c[6], c[5], 0.4);
  });

  for (final r in rocks) {
    final age = since(t, r.born, _duration);
    if (age >= _life) continue;
    final q = _rockAt(r, age);
    if (q.z >= 0.0 || q.lift <= 0.0) _rock(p, q, r, s, c, false);
    if (age > _life - 0.1) sparkle(p, q.x, _lens + 3.0, 5, c[6], c[5], 0.5);
  }
  for (final r in rocks) {
    flash(p, t, r.born + _life - 0.08, 0.0, _lens + 3.0, 30.0, c[5], 0.7, 0.28);
  }
  g.at(t).draw(p, 'front');
  _hoop(p, 0.0, _botW + 1.0, kWhite, false);
  _hoop(p, 1.0, _botW, c[5], false);
  _pod(p, t, c, h, podY);
  final fl = 0.85 + 0.15 * math.sin(tau * 6.0 * ph);
  p.glow(0, _lens + 6.0, 36, c[5], 0.7 * fl);
  p.glow(0, _lens + 6.0, 12, kWhite, 0.7 * fl);
  for (var y = _lens + 16.0; y < -8.0; y += 14.0) {
    p.glow(0, y, _half(y) + 10.0, c[4], 0.16);
  }
  for (final x in const [-20, 0, 20]) {
    p.glow(x, -2, 22, c[4], 0.26);
  }
}

final PixelEffect tractorBeamEffect = PureEffect(
  meta: const EffectMeta(
    id: 'scifi/tractor-beam',
    name: 'Tractor beam',
    desc:
        'A hovering pod projects a cone of light to the floor; rocks tear loose in puffs of dust and spiral up spinning into the lens while rings of light climb the beam.',
    category: 'scifi',
    tags: [
      'scifi',
      'beam',
      'tractor',
      'lift',
      'abduct',
      'debris',
      'ground',
      'loop',
    ],
    size: (120, 132),
    origin: (60, 114),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#06161a',
        '#0b2e33',
        '#11505a',
        '#1a7f84',
        '#2bb5a8',
        '#7ef0c8',
        '#d6fff0',
        '#ffffff',
      ],
      'hull': [
        '#0d0f17',
        '#1c2030',
        '#2e3448',
        '#4a5470',
        '#7a86a8',
        '#b8c4e0',
      ],
      'stone': ['#1a1622', '#2e2838', '#4a4258', '#6d6480', '#9a90aa'],
      'seed': 9,
    },
  ),
  onDrawBack: _drawBack,
  onDraw: _draw,
);
