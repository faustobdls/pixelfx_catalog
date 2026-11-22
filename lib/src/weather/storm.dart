// The bolt (a branching path, a stepped leader, strokes that flicker frame by frame, light along the channel) and
// the rain (streaks with lit heads, splashes that throw droplets) are adapted from Sprite Fusion's open-source
// lightning (https://www.spritefusion.com/pixel-art-vfx/lightning), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'weather_lib.dart';

const double _d = 10.0;
const double _slant = 0.42;
const double _tLead = 2.62;
const double _t1 = 3.0;
const double _t2 = 3.3;
const double _tSheet = 6.4;
const double _tFar = 8.6;
const double _bx0 = 62.0;
const double _by0 = -136.0;
const double _bx1 = 52.0;
const double _by1 = 3.0;

const List<double> _f1 = [1.0, 0.62, 0.95, 0.4, 0.7, 0.22];
const List<double> _f2 = [0.92, 0.5, 0.8, 0.3, 0.12];

double _env(double t, double t0, List<double> e) {
  final i = ((t - t0) * 30.0 + 1e-3).floor();
  return i >= 0 && i < e.length ? e[i] : 0.0;
}

double _flashAt(double t) => math.max(_env(t, _t1, _f1), _env(t, _t2, _f2));

double _sheetAt(double t) {
  final a = t - _tSheet;
  if (a < 0.0 || a > 0.9) return 0.0;
  final p1 = math.exp(-math.pow((a - 0.08) / 0.05, 2));
  final p2 = math.exp(-math.pow((a - 0.3) / 0.09, 2));
  final tail = a > 0.3 ? math.exp(-(a - 0.3) * 6.0) * 0.5 : 0.0;
  return math.min(1.0, 0.7 * p1 + p2 + tail) *
      ((a * 30.0).floor() % 3 == 1 ? 0.75 : 1.0);
}

double _blink(double a, double k) {
  if (a < 0.0 || a > 0.3) return 0.0;
  return k *
      (math.exp(-math.pow((a - 0.06) / 0.04, 2)) +
          0.65 * math.exp(-math.pow((a - 0.18) / 0.05, 2)));
}

double _farAt(double t) => _blink(t - _tFar, 0.45);
double _far2At(double t) => _blink(t - 0.9, 0.3);
double _snap(double t) => (t * 3e4).round() / 3e4;

void _sky(Painter p, double f, List<int> v) {
  final k = f * 0.36;
  if (k <= 0.01) return;
  final c = mix(v[2], v[3], 0.6);
  pass(p, _stormMeta, -170.0, 9.0, (x, y, out) {
    final d = (x - (_bx0 + _bx1) / 2.0).abs() / 230.0;
    out.l = c;
    out.k = k * (0.2 + 0.8 * math.pow(math.max(0.0, 1.0 - d), 2.2));
  });
}

class _CloudRow {
  final double base;
  final double wob;
  final int n;
  final (double, double) rx;
  final double ry;
  final double drift;
  final (double, double) life;
  final List<int> tone;
  final bool tex;
  final bool haze;

  const _CloudRow({
    required this.base,
    required this.wob,
    required this.n,
    required this.rx,
    required this.ry,
    required this.drift,
    required this.life,
    required this.tone,
    required this.tex,
    this.haze = false,
  });
}

const List<_CloudRow> _rows = [
  _CloudRow(
    base: -161,
    wob: 3,
    n: 18,
    rx: (16, 30),
    ry: 0.8,
    drift: 15,
    life: (4, 7),
    tone: [1, 2, 3, 4],
    tex: true,
  ),
  _CloudRow(
    base: -150,
    wob: 3,
    n: 22,
    rx: (10, 20),
    ry: 0.85,
    drift: 10,
    life: (3.5, 6.5),
    tone: [1, 2, 3, 5],
    tex: true,
  ),
  _CloudRow(
    base: -140,
    wob: 3,
    n: 26,
    rx: (7, 14),
    ry: 0.9,
    drift: 6,
    life: (3, 6),
    tone: [2, 2, 3, 5],
    tex: false,
    haze: true,
  ),
];

double _sag(double x) =>
    9.0 * math.exp(-math.pow((x - 40.0) / 95.0, 2)) - 3.0;

class _Roll {
  final double x;
  final double h;
  final double rx;

  const _Roll(this.x, this.h, this.rx);
}

List<List<_Roll>> _makeRolls(int s, double t) {
  return List<List<_Roll>>.generate(_rows.length, (j) {
    final rw = _rows[j];
    final out = <_Roll>[];
    for (var i = 0; i < rw.n; i++) {
      final l = rw.life.$1 + rand(s, j, i, 1) * (rw.life.$2 - rw.life.$1);
      final age = wrap(t - rand(s, j, i, 2) * _d, _d);
      if (age >= l) continue;
      final u = age / l;
      final g = math.pow(math.sin(math.pi * u), 0.6);
      final rx = rw.rx.$1 + rand(s, j, i, 3) * (rw.rx.$2 - rw.rx.$1);
      final ry = rx * rw.ry;
      final x = -200.0 + rand(s, j, i, 4) * 400.0 + rw.drift * (age - l / 2.0);
      out.add(
        _Roll(
          x,
          ry * g * (0.6 + 0.4 * rand(s, j, i, 5)),
          rx * (0.8 + 0.2 * g),
        ),
      );
    }
    return out;
  });
}

void _veil(
  Painter p,
  double t,
  int s,
  List<int> c,
  List<int> v,
  double f,
) {
  final fld = noiseField(s + 11, 256, 128, const [4, 8, 16]);
  final shift = (256.0 * 2.0 * t) / _d;
  final glow = mix(c[3], v[3], 0.5);
  pass(p, _stormMeta, -170.0, -0.5, (x, y, out) {
    final n = sampleField(fld, (x - y * _slant) * 1.9 - shift, y * 0.16 + 7.0);
    final dens = clamp(0.45 + (n - 0.5) * 2.6);
    out.c = f > 0.05
        ? mix(
            c[1],
            glow,
            math.min(
              1.0,
              f * dens * 0.7 * math.max(0.25, 1.0 - (x - _bx1).abs() / 220.0),
            ),
          )
        : c[1];
    out.a = 0.4 + 0.38 * dens;
    out.b = true;
  });
}

void _deck(
  ClippedWeatherPainter q,
  CanvasBox b,
  double t,
  int s,
  List<int> c,
  List<int> v,
  double Function(double x, double y) litAt,
  bool lit,
) {
  final r = _makeRolls(s, t);
  final fld = noiseField(s * 3 + 1, 256, 128);
  final drift = (256.0 * t) / _d;
  final n = _rows.length;
  final mo = math.pow(math.cos((math.pi * t) / _d), 2).toDouble();
  final rampCols = [c[0], c[1], c[2], c[3], c[4], c[5], c[6], v[4], kWhite];
  final top = Float32List(n);
  final bot = Float32List(n);
  final bulge = Float32List(n);

  for (var x = b.x0; x < b.x1; x++) {
    final cx = x + 0.5;
    var low = -170.0;
    for (var j = 0; j < n; j++) {
      final rw = _rows[j];
      final und = (sampleField(fld, cx * 0.55 + j * 91.0, 3.0) * mo +
              sampleField(fld, cx * 0.55 + j * 91.0, 60.0) * (1.0 - mo) -
              0.5) *
          2.0;
      final baseC = rw.base +
          _sag(cx) * (0.4 + j * 0.3) +
          7.0 * und +
          rw.wob *
              2.0 *
              (sampleField(
                    fld,
                    cx * 1.8 + j * 61.0 - drift * (0.5 - j * 0.1),
                    20.0 + j * 17.0,
                  ) -
                  0.5);
      var bump = 0.0;
      for (final rl in r[j]) {
        final dx = (cx - rl.x) / rl.rx;
        if (dx * dx < 1.0) {
          bump = math.max(bump, rl.h * math.sqrt(1.0 - dx * dx));
        }
      }
      final y1 = baseC + bump;
      top[j] = -999.0;
      bot[j] = y1;
      bulge[j] = bump;
      low = math.max(low, y1);
    }
    var prev = -1;
    var prevBot = -999.0;
    for (var y = b.y0; y < low; y++) {
      final cy = y + 0.5;
      var j = 0;
      while (j < n && !(cy >= top[j] && cy < bot[j])) {
        j++;
      }
      if (j >= n) {
        prev = -1;
        continue;
      }
      if (j != prev) {
        if (prev >= 0 && prev < j) prevBot = cy;
        prev = j;
      }
      final rw = _rows[j];
      final d = bot[j] - cy;
      final tone = rw.tone;
      final th = bayer(x.toDouble(), y.toDouble());
      int idx;
      if (d < 1.0) {
        idx = bulge[j] > 3.0 ? tone[3] : tone[3] - 1;
      } else if (cy - prevBot < 1.5 && j > 0) {
        idx = math.max(0, tone[0] - 1);
      } else if (d < 2.0 + bulge[j] * 0.25 + th * 2.0) {
        idx = tone[2];
      } else if (d < 6.0 + bulge[j] * 0.4 + th * 3.0) {
        idx = tone[1];
      } else {
        final nn = sampleField(
          fld,
          cx * 0.9 + j * 77.0 - drift * (0.6 - j * 0.12),
          cy * 1.7 + j * 31.0,
        );
        idx = tone[0] + (rw.tex && nn > 0.6 ? 1 : 0);
      }
      var lk = 0.0;
      if (lit) {
        final lv = litAt(cx, cy);
        if (lv > 0.02) {
          idx = math.min(
            8,
            idx + (lv * (d < 1.0 ? 4.4 : (d < 4.0 ? 3.8 : 3.1)) + 0.5).floor(),
          );
          lk = lv;
        }
      }
      if (rw.haze && lk == 0.0 && d >= 1.0) {
        q.blend(x, y, rampCols[idx], 0.75);
      } else {
        q.px(x, y, rampCols[math.max(0, idx)]);
      }
      if (lk > 0.03) q.light(x, y, v[3], lk * (d < 3.0 ? 0.4 : 0.22));
    }
  }
}

void _rain(
  ClippedWeatherPainter q,
  double t,
  int s,
  List<int> c,
  List<int> v,
  double f,
  bool near,
) {
  int litAt(double x) {
    final l = f * (0.3 + 0.7 * math.max(0.0, 1.0 - (x - _bx1).abs() / 170.0));
    return l > 0.45 ? 2 : (l > 0.15 ? 1 : 0);
  }

  final hyp = math.sqrt(_slant * _slant + 1.0);
  final ux = _slant / hyp;
  final uy = 1.0 / hyp;

  if (!near) {
    final bodyCols = [c[4], c[4], c[5]];
    final headCols = [c[5], c[6], c[6]];
    trips(t, _d, 300, s * 7 + 1, 22, 28, (u, k, m, i) {
      final j = wrapInt(k, m);
      final stop = -14.0 - rand(s, i, j, 1) * 90.0;
      final y = -176.0 + (stop + 176.0) * u;
      final x = -170.0 + rand(s, i, j, 2) * 360.0 - (stop - y) * _slant;
      final len = 3.0 + rand(s, i, j, 3) * 2.0;
      final lit = litAt(x);
      q.line(
        x - ux * len,
        y - uy * len,
        x - ux * len * 0.4,
        y - uy * len * 0.4,
        bodyCols[lit],
      );
      q.line(x - ux * len * 0.4, y - uy * len * 0.4, x, y, headCols[lit]);
    });
    return;
  }

  final bodyCols = [c[6], c[6], v[4]];
  final headCols = [c[7], kWhite, kWhite];
  final tailCols = [c[4], c[5], v[3]];
  trips(t, _d, 84, s * 7 + 2, 30, 38, (u, k, m, i) {
    final j = wrapInt(k, m);
    final z = 1.0 + rand(s, i, j, 1) * 4.0;
    final y = -180.0 + (z + 180.0) * u;
    final x = -175.0 + rand(s, i, j, 2) * 370.0 - (z - y) * _slant;
    final len = 9.0 + rand(s, i, j, 3) * 5.0;
    final lit = litAt(x);
    q.line(
      x - ux * len,
      y - uy * len,
      x - ux * len * 0.55,
      y - uy * len * 0.55,
      tailCols[lit],
    );
    q.line(
      x - ux * len * 0.55,
      y - uy * len * 0.55,
      x - ux,
      y - uy,
      bodyCols[lit],
    );
    q.px(x, y, headCols[lit]);
    final dur = _d / m;
    final age = u * dur;
    if (age < 0.4) {
      final jp = wrapInt(k - 1, m);
      final zp = 1.0 + rand(s, i, jp, 1) * 4.0;
      final xp = -175.0 + rand(s, i, jp, 2) * 370.0;
      final litP = litAt(xp);
      splash(
        q,
        xp,
        zp,
        age,
        0.25 + (zp - 1.0) / 5.3,
        (
          hot: litP != 0 ? kWhite : c[7],
          cool: [c[5], c[6], v[4]][litP],
        ),
        rand(s, i, jp, 4),
      );
    }
  });
}

List<BoltBranch> _channel(int s) {
  final r = Rng(s * 31 + 1);
  final p = tree(r, _bx0, _by0, _bx1, _by1, 0.26, 0.18);
  final pts = p[0].pts;
  final side = r.sign();
  const stops = [0.2, 0.38, 0.55];
  for (var i = 0; i < stops.length; i++) {
    final u = stops[i];
    final k = (u * (pts.length - 1)).floor();
    final (ax, ay) = pts[k];
    final (bx, by) = pts[math.min(pts.length - 1, k + 3)];
    final a = math.atan2(by - ay, bx - ax) +
        (i % 2 != 0 ? -side : side) * r.range(0.6, 1.0);
    final l = r.range(36, 56) * (1.0 - u * 0.45);
    p.addAll(
      tree(
        r,
        ax,
        ay,
        ax + math.cos(a) * l,
        ay + math.sin(a) * l,
        0.3,
        0.5,
        0.6,
        1,
      ),
    );
  }
  return p;
}

void _stroke(
  ClippedWeatherPainter q,
  List<BoltBranch> paths,
  double k,
  List<int> v,
) {
  for (var passIdx = 0; passIdx < 3; passIdx++) {
    for (final p in paths) {
      final trunk = p.w >= 1.0;
      if (!trunk && (k < 0.4 || (passIdx == 0 && p.w < 0.5))) continue;
      for (var i = 0; i < p.pts.length - 1; i++) {
        final (ax, ay) = p.pts[i];
        final (bx, by) = p.pts[i + 1];
        final l = math.max(
          1.0,
          math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay)),
        );
        for (var d = 0.0; d <= l; d += 0.5) {
          final x = ax + ((bx - ax) * d) / l;
          final y = ay + ((by - ay) * d) / l;
          if (passIdx == 0) {
            q.circle(
              x,
              y,
              trunk ? (k > 0.6 ? 2.3 : 1.7) : 1.2,
              k > 0.6 ? v[2] : v[1],
            );
          } else if (passIdx == 1) {
            q.circle(
              x,
              y,
              trunk ? (k > 0.6 ? 1.4 : 0.9) : 0.6,
              trunk ? v[4] : v[3],
            );
          } else if (trunk) {
            q.px(x, y, k > 0.3 ? kWhite : v[4]);
            if (k > 0.85) q.px(x + 1.0, y, kWhite);
          } else if (p.w > 0.4 && k > 0.6) {
            q.px(x, y, v[4]);
          }
        }
        if (passIdx == 0 && i % 3 == 0) {
          q.glow(ax, ay, trunk ? 18 : 8, v[3], (trunk ? 0.5 : 0.3) * k * p.w);
        }
      }
    }
  }
}

void _bolt(ClippedWeatherPainter q, double t, int s, List<int> v) {
  final p1 = _channel(s);
  if (t < _t1) {
    final step = ((t - _tLead) / (_t1 - _tLead) * 9.0).floor() / 9.0;
    final reach = _by0 + (_by1 - _by0) * math.pow(step, 1.25);
    for (final p in p1) {
      for (var i = 0; i < p.pts.length - 1; i++) {
        final (ax, ay) = p.pts[i];
        final (bx, by) = p.pts[i + 1];
        if (by > reach) break;
        q.line(ax, ay, bx, by, p.w >= 1.0 ? v[2] : v[1]);
        if (i % 4 == 0) q.glow(ax, ay, 6, v[3], 0.22 * p.w);
      }
    }
    return;
  }
  final p2Extra =
      tree(Rng(s * 31 + 2), _bx0, _by0, _bx1, _by1, 0.3, 0.3).skip(1).take(2);
  final p2 = [p1[0], ...p2Extra];
  final st = t >= _t2 ? 2 : 1;
  final a = t - (st == 2 ? _t2 : _t1);
  final k = _env(t, st == 2 ? _t2 : _t1, st == 2 ? _f2 : _f1);
  final paths = st == 2 ? p2 : p1;
  if (k > 0.0) {
    _stroke(q, paths, k, v);
  } else if (a < 0.5) {
    final g = 1.0 - a / 0.5;
    for (final p in paths) {
      if (p.w >= 1.0) {
        for (final (x, y) in p.pts) {
          q.dot(x, y, v[1], g * 0.9);
        }
      }
    }
  }
}

void _crawler(ClippedWeatherPainter q, double t, int s, List<int> v) {
  final a = t - _tSheet - 0.22;
  if (a < 0.0 || a > 0.17) return;
  final p = tree(Rng(s * 7 + 3), -150.0, -138.0, -26.0, -134.0, 0.2, 0.7);
  final reach = -150.0 + 130.0 * math.min(1.0, ((a * 30.0).floor() + 1) / 3.0);
  final k = a < 0.1 ? 1.0 : 0.5;
  for (final br in p) {
    for (var i = 0; i < br.pts.length - 1; i++) {
      final (ax, ay) = br.pts[i];
      final (bx, by) = br.pts[i + 1];
      if (ax > reach) break;
      q.line(ax, ay, bx, by, br.w >= 1.0 && k > 0.6 ? v[4] : v[3]);
      if (br.w >= 1.0) q.dot(ax, ay + 1.0, v[2], k);
      if (i % 3 == 0) q.glow(ax, ay, 10, v[3], 0.35 * k * br.w);
    }
  }
}

void _strike(
  ClippedWeatherPainter q,
  double t,
  int s,
  List<int> c,
  List<int> v,
) {
  final a = t - _t1;
  if (a < 0.0 || a > 1.8) return;
  final k = _flashAt(t);
  if (k > 0.0) {
    final fr = (t * 30.0 + 1e-3).floor();
    final rc = Rng(s * 977 + fr);
    for (var i = 0; i < 4; i++) {
      final side = i % 2 != 0 ? 1.0 : -1.0;
      final l = rc.range(10, 30) * (0.6 + 0.4 * k);
      for (final br in tree(
        rc,
        _bx1 + side,
        _by1 - 1.0,
        _bx1 + side * l,
        _by1 + rc.range(-2, 3),
        0.35,
        0.5,
        0.6,
        1,
      )) {
        q.polyline(br.pts, k > 0.6 && br.w > 0.5 ? v[4] : v[3]);
        final mid = br.pts[br.pts.length >> 1];
        q.glow(mid.$1, mid.$2, 8, v[3], 0.3 * k);
      }
    }
    q.circle(_bx1, _by1 - 1.0, 2.0 + 3.0 * k, v[4]);
    q.circle(_bx1, _by1 - 1.0, 1.0 + 2.0 * k, kWhite);
    q.glow(_bx1, _by1 - 12.0, 95, v[2], 0.55 * k);
    q.glow(_bx1, _by1 - 4.0, 40, v[3], 0.5 * k);
    q.glow(_bx1, _by1 - 2.0, 14, kWhite, 0.6 * k);
  }
  final ps = Particles(
    rng: Rng(s * 13 + 5),
    ground: (_) => 4.0,
    sparks: [kWhite, v[4], v[3], v[2]],
    haze: v[2],
  );
  final r = ps.r;
  final steam = mix(c[4], v[3], 0.3);
  void burst(int n, double pow) {
    for (var i = 0; i < n; i++) {
      final an = -math.pi / 2.0 + r.range(-1.35, 1.35);
      final sp = r.range(110, 420) * pow;
      ps.spawn(
        P.spark,
        _bx1,
        _by1 - 1.0,
        math.cos(an) * sp,
        math.sin(an) * sp,
        r.range(0.18, 0.6),
      );
    }
    for (var i = 0; i < 6 * pow; i++) {
      final sd = r.sign();
      ps.spawn(
        P.vapour,
        _bx1 + sd * r.range(2, 8),
        _by1 - r.range(1, 3),
        sd * r.range(30, 90),
        -r.range(4, 16),
        r.range(0.6, 1.2),
        steam,
        r.range(2.5, 4.5),
        r.range(0, 0.08),
      );
    }
  }

  burst(48, 1.0);
  var tt = 0.0;
  var second = false;
  const dt = 1.0 / 120.0;
  for (; tt + dt <= a; tt += dt) {
    if (!second && tt >= _t2 - _t1) {
      second = true;
      burst(16, 0.7);
    }
    ps.update(dt);
  }
  ps.draw(q);
  if (a < 1.6) {
    q.glow(_bx1, _by1, 16, v[2], 0.4 * math.pow(1.0 - a / 1.6, 2));
  }
}

void _floor(
  ClippedWeatherPainter q,
  double t,
  int s,
  List<int> c,
  List<int> v,
  double f,
) {
  final fld = noiseField(s + 3, 256, 128);
  final mFld = noiseField(s + 4, 256, 128, const [4, 8, 16]);
  final wind = (256.0 * 3.0 * t) / _d;
  pass(q, _stormMeta, -14.0, -0.5, (x, y, out) {
    final m = sampleField(mFld, x * 1.1 - wind, y * 4.0 + 9.0) - 0.4;
    if (m <= 0.0) return;
    out.c = f > 0.1 ? mix(c[4], v[3], f) : c[4];
    out.a = math.min(0.3, m * 0.9) * (1.0 + y / 14.0);
    out.b = true;
  });
  pass(q, _stormMeta, 0.0, 9.0, (x, y, out) {
    bool pool(double yy) =>
        sampleField(fld, x * 1.3 + 31.0, yy * 9.0) > 0.6 - yy * 0.006;
    final wet = pool(y);
    final lip = wet && !pool(y - 1.0);
    out.b = true;
    out.c = c[1];
    out.a = 0.5;
    if (y < 1.0) {
      out.c = sampleField(fld, x * 2.0, 50.0) > 0.5 ? c[4] : c[3];
      out.a = 1.0;
      out.b = false;
    } else if (wet) {
      final d = (x - _bx1).abs() / 150.0;
      if (f > 0.06) {
        out.c = (d < 0.25 && f > 0.5) || lip ? v[4] : v[3];
        out.a = clamp(f * (1.35 - d) * (lip ? 1.4 : 1.0));
        out.b = false;
      } else {
        out.c = lip ? c[5] : c[3];
        out.a = lip ? 1.0 : 0.7;
      }
      out.l = v[3];
      out.k = f * 0.25 * math.max(0.0, 1.0 - d);
    }
  });
  if (f > 0.2) {
    final fr = (t * 30.0).floor();
    for (var y = 1; y < 10; y++) {
      if (rand(y, fr, 3) < 0.8) {
        q.dot(
          _bx1 + math.sin(y * 1.7 + t * 40.0) * 1.2,
          y,
          y < 4 ? kWhite : v[4],
          f * (1.1 - y / 12.0),
        );
      }
    }
  }
}

const List<String> _defaultBolt = [
  '#2a1a6e',
  '#4835c2',
  '#6a6cff',
  '#78b8ff',
  '#c6ebff',
  '#ffffff',
];

const EffectMeta _stormMeta = EffectMeta(
  id: 'weather/storm',
  name: 'Storm',
  desc:
      'Driving rain at two depths under a churning cloud deck; a forked bolt strikes in a double flash that lights the sky and the rain, then sheet lightning glows in the clouds.',
  category: 'weather',
  tags: [
    'weather',
    'storm',
    'rain',
    'lightning',
    'thunder',
    'ambient',
    'loop',
  ],
  size: (320, 180),
  origin: (160, 170),
  duration: _d,
  loop: true,
  fps: 30,
  bg: BackdropKind.sky,
  defaultOptions: {
    'palette': [
      '#09080f',
      '#121120',
      '#1b1a30',
      '#262541',
      '#363a5c',
      '#4f5d8c',
      '#7790c6',
      '#c2d6ff',
    ],
    'bolt': _defaultBolt,
    'seed': 5,
  },
);

final PureEffect stormEffect = PureEffect(
  meta: _stormMeta,
  onDrawBack: (p, tRaw, o) {
    final t = _snap(tRaw);
    final q = clip(p, _stormMeta);
    final b = boxOf(_stormMeta);
    final s = o.seed;
    final c = fit(o.palette, 8);
    final v = fit((o['bolt'] as List<Object>?) ?? _defaultBolt, 6);
    final f = _flashAt(t);
    final sh = _sheetAt(t);
    final far = _farAt(t);
    final far2 = _far2At(t);
    final lead = t > _tLead && t < _t1 ? 0.25 + 0.2 * math.sin(t * 70.0) : 0.0;
    final pre = t > _tLead - 0.5 && t < _tLead
        ? 0.12 * math.max(0.0, math.sin((t - _tLead) * 41.0))
        : 0.0;
    final srcs = <(double, double, double, double)>[];
    if (f + lead + pre > 0.0) {
      srcs.add((_bx0, _by0 - 6.0, 150.0, f + lead * 0.5 + pre));
    }
    if (sh > 0.0) srcs.add((-96.0, -146.0, 120.0, sh));
    if (far > 0.0) srcs.add((128.0, -156.0, 80.0, far));
    if (far2 > 0.0) srcs.add((-40.0, -160.0, 70.0, far2));
    double litAt(double x, double y) {
      var l = 0.0;
      for (final (sx, sy, r, k) in srcs) {
        final d = math.sqrt((x - sx) * (x - sx) + (y - sy) * 1.5 * (y - sy) * 1.5) / r;
        if (d < 1.0) l += k * (1.0 - d) * (1.0 - d);
      }
      return math.min(1.0, l);
    }

    _sky(p, f, v);
    if (sh > 0.05) {
      pass(p, _stormMeta, -170.0, 0.0, (x, y, out) {
        final d =
            math.sqrt((x + 96.0) * (x + 96.0) + (y + 150.0) * 1.3 * (y + 150.0) * 1.3) /
                170.0;
        if (d < 1.0) {
          out.l = v[2];
          out.k = sh * 0.3 * (1.0 - d) * (1.0 - d);
        }
      });
    }
    _veil(p, t, s, c, v, f);
    _rain(q, t, s, c, v, f, false);
    if (t > _tLead && t < _t2 + 0.7) _bolt(q, t, s, v);
    _deck(q, b, t, s, c, v, litAt, srcs.isNotEmpty);
    _crawler(q, t, s, v);
    _floor(q, t, s, c, v, f);
    _strike(q, t, s, c, v);
  },
  onDraw: (p, tRaw, o) {
    final t = _snap(tRaw);
    final q = clip(p, _stormMeta);
    final s = o.seed;
    final c = fit(o.palette, 8);
    final v = fit((o['bolt'] as List<Object>?) ?? _defaultBolt, 6);
    _rain(q, t, s, c, v, _flashAt(t), true);
  },
);
