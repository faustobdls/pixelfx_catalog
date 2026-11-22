// The pool's caustic light (two warped sine nets, light where they cross zero) is adapted from Sprite Fusion's
// open-source bubbles (https://www.spritefusion.com/pixel-art-vfx/bubbles), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'water_lib.dart';

const double _d = 2.0;
const double _sy = 0.2;
const double _g = 760.0;
const int _poolRx = 56;
const int _poolRy = 11;

double _halfW(int w, double d, int h) =>
    w + 3.2 * math.pow(clamp(d / h), 1.6);

void _sheet(Painter p, List<int> c, double ph, int h, int w, int s) {
  for (var y = -h + 2; y <= -1; y++) {
    final d = y + 0.5 + h;
    final v = d / h;
    final ss = math.sqrt(d + 3.0);
    final hw0 = _halfW(w, d, h);
    final split = smooth(0.56, 0.95, v);
    final glass = 1.0 - smooth(4.0, 24.0, d);
    final wl = tileNoise(2.0, ss * 1.4 - ph * 12.0, 0, 12, s + 2) *
        (0.4 + 1.8 * v);
    final wr = tileNoise(11.0, ss * 1.4 - ph * 12.0, 0, 12, s + 2) *
        (0.4 + 1.8 * v);
    final fan = split > 0.0
        ? tileNoise(3.0, ss * 0.8 - ph * 4.0, 0, 4, s + 61) * 1.6
        : 0.0;
    final sd = ss * 1.5 - ph * 20.0;
    final sb = ss * 0.45 - ph * 6.0;
    for (var xi = -w - 8; xi <= w + 8; xi++) {
      final x = xi + 0.5;
      final hw = hw0 + (x < 0.0 ? wl : wr);
      final ax = x.abs();
      if (ax > hw) continue;
      final e = ax / hw;
      var edge = false;
      if (split > 0.0) {
        final f = ((((x / (1.0 + 0.22 * split) + fan + 64.0) / 5.4) % 1.0) +
                1.0) %
            1.0;
        if (f > 1.0 - 0.46 * split) continue;
        edge = f < 0.2;
      }
      final dash = tileNoise(xi * 1.618 + 0.31, sd, 0, 20, s);
      if (rand(xi, s + 60) < 0.48 && e < 0.86 && !edge) {
        p.blend(
          x,
          y + 0.5,
          dash > 0.45 ? c[4] : (glass > 0.5 ? c[3] : c[2]),
          dash > 0.45 ? 0.7 : 0.42 + 0.15 * v,
        );
        continue;
      }
      final broad =
          tileNoise(((x + 40.0) / 3.0).floor() * 2.7, sb, 0, 6, s + 1);
      var b = -0.34 +
          0.46 * v +
          0.3 * broad -
          glass * 0.5 +
          0.35 * smooth(0.7, 1.0, e) * (x < 0.0 ? 1.0 : 0.3) -
          (x > 0.0 ? 0.12 * e : 0.0) +
          (edge ? 0.3 : 0.0);
      if (dash > 0.2 - 0.22 * v) b += 0.36 + 0.7 * (dash - 0.2);
      if (b > -0.2) {
        p.px(
          xi,
          y,
          b > 0.62
              ? kWhite
              : (b > 0.34 ? c[6] : (b > 0.08 ? c[5] : c[4])),
        );
      } else {
        p.blend(x, y + 0.5, c[3], 0.8);
      }
    }
  }
  cycleFixed(ph * _d, _d, 16, s + 30, 0.4, (age, life, r, _) {
    final side = r.sign();
    final d0 = r.range(14.0, h * 0.7);
    final d = d0 + 50.0 * age + 260.0 * age * age;
    final k = age / life;
    if (d > h - 6.0) return;
    final x = side * (_halfW(w, d, h) + 1.5 + age * r.range(6.0, 16.0));
    final y = -h + d;
    final len = 2.0 + 6.0 * k;
    p.lineShaded(
      x,
      y - len,
      x,
      y,
      color: (u) => u > 0.7 ? c[6] : c[4],
      alpha: (_) => 1.0 - k * 0.5,
    );
  });
}

class _RockMap {
  final Int8List id;
  final Float32List lit;

  _RockMap(this.id, this.lit);
}

final Map<String, _RockMap> _rocksCache = {};

_RockMap _rockMap(
  List<(double, double, double, double)> lumps,
  int x0,
  int y0,
  int w,
  int hgt,
  double lx,
  double ly,
  double lz,
  int s,
) {
  final id = Int8List(w * hgt)..fillRange(0, w * hgt, -1);
  final lit = Float32List(w * hgt);
  for (var j = 0; j < hgt; j++) {
    for (var i = 0; i < w; i++) {
      final x = x0 + i + 0.5;
      final y = y0 + j + 0.5;
      var best = -1;
      var z = -1e9;
      var l = 0.0;
      for (var k = 0; k < lumps.length; k++) {
        final (cx, cy, rx, ry) = lumps[k];
        final nx = (x - cx) / rx;
        final ny = (y - cy) / ry;
        final r2 = nx * nx + ny * ny;
        if (r2 >= 1.0) continue;
        final nz = math.sqrt(1.0 - r2);
        final depth = nz * ry + (k == 5 ? -6 : (k == 2 ? -3 : (k > 2 ? -1 : 0)));
        if (depth > z) {
          z = depth;
          best = k;
          l = nx * lx + ny * ly + nz * lz;
        }
      }
      id[j * w + i] = best;
      lit[j * w + i] = l + 0.2 * tileNoise(x * 0.32, y * 0.32, 0, 0, s + 70);
    }
  }
  return _RockMap(id, lit);
}

void _outcrop(Painter p, List<int> c, double ph, int h, int w, int s) {
  final st = rockColors();
  const lx = -0.55;
  const ly = -0.72;
  const lz = 0.42;
  final lumps = [
    (-w - 11.0, -h - 4.0, 13.0, 10.0),
    (w + 8.0, -h - 2.0, 9.0, 7.5),
    (0.0, -h + 3.5, w + 3.0, 4.2),
    (-w - 21.0, -h + 4.0, 7.0, 5.5),
    (w + 15.0, -h + 4.5, 5.0, 4.0),
    (-2.0, -h - 5.0, w + 7.0, 6.5),
  ];
  final x0 = -w - 29;
  final x1 = w + 21;
  final y0 = -h - 15;
  final y1 = -h + 10;
  final rw = x1 - x0 + 1;
  final rh = y1 - y0 + 1;
  final key = '$w|$h|$s';
  final map = _rocksCache[key] ??= _rockMap(lumps, x0, y0, rw, rh, lx, ly, lz, s);
  final id = map.id;
  final lit = map.lit;

  p.each(-w - 26.0, -h.toDouble(), w + 18.0, -h + 20.0, (x, y, sx, sy) {
    final k = 1.0 - hypot((x + 4.0) / (w + 22.0), (y + h) / 20.0);
    if (k > 0.0) p.blendPx(sx, sy, st[0], 0.4 * math.min(1.0, k * 3.0));
  });

  int at(int i, int j) =>
      (i < 0 || j < 0 || i >= rw || j >= rh) ? -1 : id[j * rw + i];

  for (var j = 0; j < rh; j++) {
    for (var i = 0; i < rw; i++) {
      final k = id[j * rw + i];
      final x = x0 + i;
      final y = y0 + j;
      if ((k == 2 || k == 5 || k < 0) &&
          y >= -h - 5 &&
          y < -h + 1 &&
          (x + 0.5).abs() < w + 1.5) {
        continue;
      }
      if (k < 0) {
        if (at(i - 1, j) >= 0 ||
            at(i + 1, j) >= 0 ||
            at(i, j - 1) >= 0 ||
            at(i, j + 1) >= 0) {
          p.px(x, y, st[0]);
        }
        continue;
      }
      final r = at(i + 1, j);
      final b = at(i, j + 1);
      if ((r >= 0 && r != k && r < k) || (b >= 0 && b != k)) {
        p.px(x, y, st[1]);
        continue;
      }
      final l = lit[j * rw + i];
      final wet = (x + 0.5).abs() < w + 6 && y > -h - 9;
      var col = l > 0.9
          ? st[5]
          : (l > 0.64
              ? st[4]
              : (l > 0.3 ? st[3] : (l > -0.05 ? st[2] : st[1])));
      if (k == 5) col = l > 0.7 ? st[3] : (l > 0.2 ? st[2] : st[1]);
      if (at(i, j - 1) < 0 && l > 0.25) col = st[5];
      if (wet) {
        col = l > 0.9
            ? st[4]
            : (l > 0.64 ? st[3] : (l > 0.3 ? st[2] : st[1]));
        if (l > 0.3 &&
            tileNoise(x * 0.9, y * 0.6 - ph * 8.0, 0, 8, s + 71) > 0.42) {
          col = l > 0.6 ? c[6] : c[4];
        }
      }
      p.px(x, y, col);
    }
  }

  for (var q = 0; q < 3; q++) {
    final lump = lumps[q % 2];
    final cx = (lump.$1 + (q == 2 ? -0.5 : 0.15) * lump.$3).floor();
    final cy = (lump.$2 + lump.$4 * (q == 2 ? 0.1 : -0.25)).floor();
    final len = 3 + (rand(q, s + 74) * 4.0).floor();
    final dx = rand(q, s + 75) < 0.5 ? 1 : -1;
    for (var n = 0; n <= len; n++) {
      final x = cx + (n * 0.6).round() * dx;
      final y = cy + n;
      final i = x - x0;
      final j = y - y0;
      if (at(i, j) < 0 || at(i, j) > 1 || at(i, j + 1) < 0) break;
      p.px(x, y, n == len ? st[1] : st[0]);
      if (n == 0) p.px(x - dx, y - 1, st[4]);
    }
  }

  for (final sx in [-w - 3, w + 3]) {
    for (var y = -h - 2; y < -h + 7; y++) {
      final g = ((y * 0.35 - ph * 6.0) % 1.0 + 1.0) % 1.0;
      final i = sx - x0;
      final j = y - y0;
      if (at(i, j) >= 0) p.px(sx, y, g < 0.3 ? c[6] : c[3]);
    }
  }
}

void _river(Painter p, List<int> c, double ph, int h, int w, int s) {
  final top = -h - 6.0;
  p.shade(-w - 3.0, top, w + 3.0, -h.toDouble(), (x, y, _) {
    final back = top + 1.5 + tileNoise(x * 0.3, 4.0, 0, 0, s + 62) * 1.5;
    final v = (y - back) / (-h - back);
    final hw = w + 2.0 - (1.0 - v) * 3.0;
    if (y < back || x.abs() > hw) return null;
    final n = tileNoise(x * 0.32, (y - top) * 0.7 - ph * 8.0, 0, 8, s + 3);
    return n > 0.66 ? c[6] : (n > 0.4 ? c[5] : (v < 0.5 ? c[3] : c[4]));
  });
}

void _curl(Painter p, List<int> c, double ph, int h, int w, int s) {
  for (var x = -w; x <= w; x++) {
    final g = tileNoise(x * 0.45, ph * 4.0, 0, 4, s + 4);
    p.px(x, -h - 1, c[4]);
    p.px(x, -h, kWhite);
    p.px(x, -h + 1, g > 0.2 ? c[6] : c[5]);
  }
  p.glowLine(-w, -h, w, -h, 6, c[6], 0.18);
  p.glow(0, -h, 34, c[5], 0.2);
  cycleFixed(ph * _d, _d, 4, s + 5, 0.36, (age, life, r, _) {
    final k = math.sin((math.pi * age) / life);
    final x = r.range(-w.toDouble(), w.toDouble());
    if (k > 0.5) {
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        p.px(x + dx, -h + dy, c[6]);
      }
    }
    p.glow(x, -h, 6, c[5], 0.4 * k);
  });
}

void _pool(Painter p, List<int> c, double ph, int w, int s) {
  const cy = 2.0;
  final tt = ph * tau;
  final cols = <(double, double)>[];
  for (var xi = -_poolRx; xi < _poolRx; xi++) {
    final x = xi + 0.5;
    cols.add((
      math.sin(x * 0.11 - tt * 2.0),
      math.sin(tt + x * 0.05) * 1.4 + x * 0.13,
    ));
  }
  for (var yi = (cy - _poolRy).floor(); yi < cy + _poolRy; yi++) {
    final y = yi + 0.5;
    final dy = (y - cy) / _poolRy;
    final sy = math.sin(y * 0.5 + tt);
    for (var xi = -_poolRx; xi < _poolRx; xi++) {
      final x = xi + 0.5;
      final dx = x / _poolRx;
      final d = dx * dx + dy * dy;
      if (d > 1.0) continue;
      p.blend(x, y, d < 0.12 ? c[2] : c[1], 0.62 * math.min(1.0, (1.0 - d) * 4.0));
      final (cx1, cx2) = cols[xi + _poolRx];
      final u = x * 0.2 + 1.8 * sy;
      final ww = y * 0.55 + 1.8 * cx1;
      final f = (math.max(0.0, 1.0 - (math.sin(u) + math.sin(ww)).abs() * 2.6) +
              0.6 * math.max(0.0, 1.0 - math.sin(cx2 + y * 0.3).abs() * 3.0)) *
          (1.0 - d);
      if (f > 0.5) p.light(x, y, c[5], 0.18 * f);
    }
  }
  for (var i = 0; i < 7; i++) {
    final a = math.pi * (1.12 + 0.76 * ((i + 0.5) / 7.0));
    final x = math.cos(a) * _poolRx * 0.96;
    final y = cy + math.sin(a) * _poolRy * 0.96;
    final g = math.sin(ph * tau * 2.0 + i * 2.4);
    if (g > 0.2) p.px(x, y, g > 0.8 ? c[6] : c[4]);
  }
  p.shade(-w - 3.0, 3.0, w + 3.0, 10.0, (x, y, _) {
    final n = tileNoise(x * 0.9, (y - 3.0) * 0.35 + ph * 6.0, 0, 6, s + 6);
    final k = 1.0 - (y - 3.0) / 7.0;
    if (x.abs() > w + 2.0 - (y - 3.0) * 0.4 || n < 0.25 + (1.0 - k) * 0.4) {
      return null;
    }
    return (n > 0.6 && k > 0.6) ? c[6] : c[5];
  });
}

void _foam(Painter p, List<int> c, double t, double ph, int w, int s) {
  final rSpan = w + 10.0;
  p.shade(-rSpan, -13.0, rSpan, 3.0, (x, y, _) {
    final ax = x.abs();
    final lump = tileNoise(x * 0.22, ph * 6.0, 0, 6, s + 7) * 3.0 +
        tileNoise(x * 0.55 + 9.0, ph * 12.0, 0, 12, s + 8) * 1.5;
    final top = -8.0 + lump + math.pow(ax / rSpan, 2.0) * 7.0;
    if (ax > rSpan - math.max(0.0, -y - 1.0) * 0.6 || y < top) return null;
    final n = tileNoise(x * 0.5, (y - top) * 0.5 - ph * 10.0, 0, 10, s + 9);
    final boil = tileNoise(x * 0.42 + 3.0, y * 0.42 - ph * 8.0, 0, 8, s + 12);
    final u = y - top;
    if (y > 1.0) return n > 0.0 ? c[5] : c[4];
    if (u < 1.2) return kWhite;
    if (boil < -0.3) return u > 4.0 ? c[4] : c[5];
    if (boil < -0.05) return c[6];
    return n > -0.2 ? kWhite : c[6];
  });
  cycleFixed(t, _d, 30, s + 10, 0.7, (age, life, r, _) {
    final k = age / life;
    final side = r.sign();
    final x0 = r.range(-w.toDouble(), w.toDouble()) * 0.9;
    final sp = r.range(2.0, 8.0);
    final up = r.range(2.0, 8.0);
    final x = x0 + side * Ease.outCubic(k) * sp;
    final y = -r.range(2.0, 5.0) - Ease.outCubic(k) * up;
    final rad = r.range(1.4, 3.0) * math.pow(math.sin(math.pi * k), 0.7);
    if (rad > 0.6) billow(p, x, y, rad, c);
  });
  cycleFixed(t, _d, 18, s + 11, 1.0, (age, life, r, _) {
    final side = r.sign();
    final x0 = side * r.range(2.0, w + 4.0);
    final vx = side * r.range(12.0, 60.0);
    final vy = -r.range(70.0, 150.0);
    final z = r.range(-3.0, 9.0);
    final size = r.next() < 0.3 ? 2 : 1;
    final land = z * _sy;
    final tl = (-vy + math.sqrt(vy * vy + 2.0 * _g * (land + 5.0))) / _g;
    if (age < tl) {
      bead(
        p,
        x0 + vx * age,
        -5.0 + vy * age + 0.5 * _g * age * age,
        vx,
        vy + _g * age,
        size,
        c,
      );
    } else if (age < tl + 0.35) {
      ring(
        p,
        x0 + vx * tl,
        land,
        1.0 + (age - tl) * 12.0,
        _sy,
        1.0 - (age - tl) / 0.35,
        c,
        n: 1,
      );
    }
  });
}

void _mist(Painter p, List<int> c, double t, int s, int n, int seed) {
  cycle(t, _d, n, s + seed, (g) => g.range(1.8, 2.8), (age, life, r, _) {
    final k = age / life;
    final side = r.sign();
    final drift = Ease.outCubic(k);
    final x = side * (r.range(3.0, 12.0) + drift * r.range(24.0, 48.0));
    final y = -r.range(2.0, 7.0) - k * r.range(3.0, 12.0);
    final rad = r.range(4.0, 6.0) + k * r.range(5.0, 9.0);
    final a = r.range(0.2, 0.3) *
        math.min(1.0, k / 0.12) *
        math.pow(1.0 - k, 1.7);
    p.discShaded(
      x,
      y,
      rad,
      color: (_, _) => c[6],
      alpha: (d, _) => a * (1.0 - d * d),
    );
    if (a > 0.05) p.glow(x, y, rad * 1.2, c[4], 0.35 * a);
  });
}

final PureEffect waterfallEffect = PureEffect(
  meta: const EffectMeta(
    id: 'water/waterfall',
    name: 'Waterfall',
    desc:
        'A river pours from a notch in a rock outcrop: a white curl, a deep sheet that splits into strands, churning foam, spray, drifting mist and rings on a dark pool.',
    category: 'water',
    tags: ['water', 'waterfall', 'cascade', 'foam', 'mist', 'ambient', 'loop'],
    size: (144, 136),
    origin: (72, 118),
    duration: 2.0,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': kWaterPalette,
      'height': 92,
      'width': 13,
      'ledge': true,
      'seed': 5,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _d;
    final w = o.intOpt('width', 13);
    final s = o.seed;
    _pool(p, c, ph, w, s);
    for (var i = 0; i < 3; i++) {
      final f = (ph + i / 3.0) % 1.0;
      ring(
        p,
        0.0,
        1.0,
        w + 6.0 + f * 38.0,
        _sy,
        0.95 * math.pow(1.0 - f, 1.5),
        c,
        n: 1,
        half: -1,
        seed: i + 1,
      );
    }
    _mist(p, c, t, s, 7, 20);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _d;
    final h = o.intOpt('height', 92);
    final w = o.intOpt('width', 13);
    final ledge = o.boolOpt('ledge', true);
    final s = o.seed;
    final tt = ph * tau;
    for (var i = 0; i < 3; i++) {
      final f = (ph + i / 3.0) % 1.0;
      ring(
        p,
        0.0,
        1.0,
        w + 6.0 + f * 38.0,
        _sy,
        0.95 * math.pow(1.0 - f, 1.5),
        c,
        n: 1,
        half: 1,
        seed: i + 1,
        glint: f < 0.4 ? 1.0 - f * 2.5 : 0.0,
      );
    }
    _river(p, c, ph, h, w, s);
    if (ledge) _outcrop(p, c, ph, h, w, s);
    _sheet(p, c, ph, h, w, s);
    _curl(p, c, ph, h, w, s);
    _foam(p, c, t, ph, w, s);
    _mist(p, c, t, s, 5, 21);

    cycle(t, _d, 12, s + 50, (g) => g.range(0.2, 0.4), (age, life, r, _) {
      final k = math.sin((math.pi * age) / life);
      final low = r.next() < 0.45;
      final d = low ? h - r.range(4.0, 16.0) : r.range(12.0, h - 16.0);
      final x = low
          ? r.range(-w - 10.0, w + 10.0)
          : r.range(-0.8, 0.8) * _halfW(w, d, h);
      final y = -h + d - (age / life) * (low ? 6.0 : -10.0);
      p.px(x, y, kWhite);
      if (k > 0.55) {
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          p.px(x + dx, y + dy, c[6]);
        }
      }
      if (k > 0.85 && r.next() < 0.5) {
        for (final (dx, dy) in const [(2, 0), (-2, 0), (0, 2), (0, -2)]) {
          p.px(x + dx, y + dy, c[5]);
        }
      }
      p.glow(x, y, 5, c[5], 0.35 * k);
    });

    cycle(t, _d, 34, s + 51, (g) => g.range(0.9, 1.6), (age, life, r, _) {
      final k = age / life;
      final side = r.sign();
      final x = side * (r.range(0.0, w + 6.0) + k * r.range(6.0, 22.0)) +
          math.sin(age * 5.0 + r.range(0.0, tau)) * 1.2;
      final y = -r.range(3.0, 10.0) - k * r.range(10.0, 34.0);
      if (k > 0.7 && r.next() < (k - 0.7) * 3.3) return;
      p.px(x, y, k < 0.4 && r.next() < 0.5 ? kWhite : c[6]);
    });

    p.glowLine(0, -h + 6, 0, -8, 26, c[4], 0.12);
    p.glow(0, -5, 40, c[5], 0.32 + 0.05 * math.sin(tt * 2.0));
    p.glow(0, 4, 50, c[3], 0.14);
  },
);
