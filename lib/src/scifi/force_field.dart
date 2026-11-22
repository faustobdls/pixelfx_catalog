import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'scifi_lib.dart';

const double _duration = 2.4;
const int _width = 184;
const int _originX = 76;

const Pose _hold = Pose(
  turn: 1.0,
  crouch: 3.0,
  lean: 1.0,
  fx: -9.0,
  fy: -38.0,
  bx: 10.0,
  by: -38.0,
  ffx: -5.0,
  fbx: 6.0,
);
final Pose _hit = _hold.copyWith(x: -2.0, crouch: 5.0, lean: -3.0);

final ActSpec _act = ActSpec(
  poses: [
    const PoseKey(0.0, _hold),
    const PoseKey(0.42, _hold),
    PoseKey(0.42, _hit, PoseEase.snap),
    PoseKey(0.7, _hold.copyWith(x: -1.0)),
    const PoseKey(1.1, _hold),
    const PoseKey(1.5, _hold),
    PoseKey(1.5, _hit.copyWith(crouch: 4.0, lean: -2.0), PoseEase.snap),
    const PoseKey(1.75, _hold),
    const PoseKey(2.4, _hold),
  ],
  hits: const [
    HitSpec(t: 0.42, stop: 0.07, shake: 0.16, amp: 2.0),
    HitSpec(t: 1.5, stop: 0.03, shake: 0.08, amp: 1.0),
  ],
);

final double _s3 = math.sqrt(3.0);
const double _sa = 0.13;
final double _ca = math.sqrt(1.0 - _sa * _sa);
const double _g = 6.3;
const double _ky = 1.12;

class _Shot {
  final double t;
  final double lon;
  final double lat;
  final bool big;
  final double nx;
  final double ny;
  final double nz;

  _Shot(this.t, this.lon, this.lat, this.big)
      : nx = math.cos(lat) * math.sin(lon),
        ny = math.sin(lat),
        nz = math.cos(lat) * math.cos(lon);
}

final List<_Shot> _shots = [
  _Shot(0.42, 0.66, 0.62, true),
  _Shot(1.5, 0.95, 0.26, false),
];

({int q, int r, double hx, double hy, double e, double corner}) _cell(
  double gx,
  double gy,
) {
  final fq = (_s3 / 3.0) * gx - gy / 3.0;
  final fr = (2.0 / 3.0) * gy;
  final fs = -fq - fr;
  var q = (fq + 0.5).floor();
  var r = (fr + 0.5).floor();
  final s = (fs + 0.5).floor();
  final dq = (q - fq).abs();
  final dr = (r - fr).abs();
  final ds = (s - fs).abs();
  if (dq > dr && dq > ds) {
    q = -r - s;
  } else if (dr > ds) {
    r = -q - s;
  }
  final hx = _s3 * (q + r / 2.0);
  final hy = 1.5 * r;
  final dx = gx - hx;
  final dy = gy - hy;
  final ax = dx.abs();
  final e = math.max(
        ax,
        math.max(
          (ax / 2.0 + (dy * _s3) / 2.0).abs(),
          (ax / 2.0 - (dy * _s3) / 2.0).abs(),
        ),
      ) /
      (_s3 / 2.0);
  final k =
      (((math.atan2(dy, dx) - math.pi / 6.0) / (math.pi / 3.0)) + 0.5).floor();
  final ca = math.pi / 6.0 + (k * math.pi) / 3.0;
  return (
    q: q,
    r: r,
    hx: hx,
    hy: hy,
    e: e,
    corner: hypot(dx - math.cos(ca), dy - math.sin(ca)),
  );
}

(double, double, double) _project(double rad, double lon, double lat) {
  final x = math.cos(lat) * math.sin(lon);
  final y = math.sin(lat);
  final z = math.cos(lat) * math.cos(lon);
  return (rad * x, -rad * (y * _ca - z * _sa), y * _sa + z * _ca);
}

class _ShellPx {
  final int x;
  final int y;
  final double cx;
  final double cy;
  final double cz;
  final double lon;
  final double lat;
  final int q;
  final int r;
  final int id;
  final double e;
  final double corner;
  final double rim;
  final double sil;
  bool seam = false;
  bool bevel = false;

  _ShellPx({
    required this.x,
    required this.y,
    required this.cx,
    required this.cy,
    required this.cz,
    required this.lon,
    required this.lat,
    required this.q,
    required this.r,
    required this.id,
    required this.e,
    required this.corner,
    required this.rim,
    required this.sil,
  });
}

class _Shell {
  final List<_ShellPx> near;
  final List<_ShellPx> far;

  const _Shell(this.near, this.far);
}

final Map<double, _Shell> _shells = {};

_Shell _shell(double rad) {
  final hit = _shells[rad];
  if (hit != null) return hit;

  final near = <_ShellPx>[];
  final far = <_ShellPx>[];
  final n = rad.ceil() + 1;
  final w = 2 * n + 1;
  final ids = [<int, int>{}, <int, int>{}];
  final yMax = (rad * _sa).ceil() + 1;
  for (var y = -n; y <= yMax; y++) {
    for (var x = -n; x <= n; x++) {
      final u = (x + 0.5) / rad;
      final vy = -(y + 0.5) / rad;
      final q2 = u * u + vy * vy;
      if (q2 > 1.0) continue;
      final vz = math.sqrt(1.0 - q2);
      for (final s in const [1, -1]) {
        final cy = vy * _ca + s * vz * _sa;
        final cz = -vy * _sa + s * vz * _ca;
        if (cy < 0.0) continue;
        final lon = math.atan2(u, cz);
        final lat = math.asin(math.min(1.0, cy));
        final c = _cell(lon * _g, lat * _g * _ky);
        final id = c.q * 1000 + c.r;
        final px = _ShellPx(
          x: x,
          y: y,
          cx: u,
          cy: cy,
          cz: cz,
          lon: lon,
          lat: lat,
          q: c.q,
          r: c.r,
          id: id,
          e: c.e,
          corner: c.corner,
          rim: 1.0 - vz,
          sil: (1.0 - math.sqrt(q2)) * rad,
        );
        if (s > 0) {
          near.add(px);
          ids[0][(y + n) * w + x + n] = id;
        } else {
          far.add(px);
          ids[1][(y + n) * w + x + n] = id;
        }
      }
    }
  }
  final lists = [near, far];
  for (var i = 0; i < 2; i++) {
    int? at(int x, int y) => ids[i][(y + n) * w + x + n];
    for (final q in lists[i]) {
      final right = at(q.x + 1, q.y);
      final down = at(q.x, q.y + 1);
      final left = at(q.x - 1, q.y);
      final up = at(q.x, q.y - 1);
      q.seam = (right != null && right != q.id) || (down != null && down != q.id);
      q.bevel = !q.seam &&
          ((left != null && left != q.id) || (up != null && up != q.id));
    }
  }
  final g = _Shell(near, far);
  _shells[rad] = g;
  return g;
}

typedef _CrackPt = (double x, double y, double f, double u);

final Map<String, List<List<_CrackPt>>> _crackCache = {};

List<List<_CrackPt>> _cracks(double rad, int seed, _Shot s) {
  final key = '$rad:$seed';
  final hit = _crackCache[key];
  if (hit != null) return hit;

  final rn = Rng(seed * 13 + 5);
  final out = <List<_CrackPt>>[];
  List<_CrackPt> toScreen(List<Point2> path, double u0, double u1) {
    final pts = <_CrackPt>[];
    for (var i = 0; i < path.length; i++) {
      final (lon, lat) = path[i];
      if (lat < 0.03 || lat > 1.52 || lon.abs() > 1.5) break;
      final (sx, sy, sf) = _project(rad, lon, lat);
      pts.add((sx, sy, sf, u0 + ((u1 - u0) * i) / (path.length - 1)));
    }
    return pts;
  }

  for (var i = 0; i < 5; i++) {
    final a = (i / 5.0) * tau + rn.range(-0.35, 0.35);
    final l = rn.range(0.42, 0.8);
    final path = bolt(
      rn,
      s.lon,
      s.lat,
      s.lon + (math.cos(a) * l) / math.cos(s.lat),
      s.lat + math.sin(a) * l,
      jag: 0.2,
      depth: 4,
    );
    out.add(toScreen(path, 0.0, 1.0));
    for (final f in forks(
      rn,
      path,
      count: rn.intRange(0, 2),
      len: l * 0.5,
      jag: 0.25,
      spread: 0.9,
    )) {
      final j = path.indexWhere((q) => q.$1 == f[0].$1 && q.$2 == f[0].$2);
      final u0 = math.max(0, j) / (path.length - 1);
      out.add(toScreen(f, u0, u0 + 0.5));
    }
  }
  _crackCache[key] = out;
  return out;
}

bool _glints(int s, int q, int r) => rand(s, q, r, 3) < 0.2;

double _glintAt(int s, int q, int r) {
  final g = rand(s, q, r) * 1.7;
  return g < 1.4 ? 1.0 + g : g - 1.4;
}

final Map<String, Ghosts> _ghostCache = {};

Ghosts _ghosts(Map<String, Object?> o, List<int> c, double rad) {
  final sparks = o.rampOpt('sparks');
  final pal = o.palette;
  final key = '$rad:${o.seed}:${sparks.join(',')}:${pal.join(',')}';
  final hit = _ghostCache[key];
  if (hit != null) return hit;

  const w = _width - _originX;
  final rn = Rng(o.seed);
  final g = Ghosts(
    _duration,
    ground: (_) => 0.0,
    sparks: sparks,
    box: (-70.0, -80.0, w - 6.0, 14.0),
  );
  for (final s in _shots) {
    final (hx, hy, _) = _project(rad, s.lon, s.lat);
    final n = s.big ? 1.0 : 0.55;
    for (var i = 0; i < 24 * n; i++) {
      final a = (s.big ? -0.9 : -0.55) + rn.range(-0.7, 0.65);
      final sp = rn.range(100.0, 280.0) * (0.7 + 0.3 * n);
      g.add(
        s.t + rn.range(0.0, 0.02),
        P.spark,
        hx,
        hy,
        math.cos(a) * sp,
        math.sin(a) * sp - 30.0,
        rn.range(0.25, 0.75),
      );
    }
    for (var i = 0; i < 7 * n; i++) {
      final a = -0.9 + rn.range(-1.2, 1.2);
      final sp = rn.range(30.0, 90.0);
      g.add(
        s.t + rn.range(0.0, 0.05),
        P.mote,
        hx,
        hy,
        math.cos(a) * sp,
        math.sin(a) * sp - 15.0,
        rn.range(0.3, 0.6),
        rn.pick([c[5], c[6], c[4]]),
        0.7,
      );
    }
    for (var i = 0; i < 3 * n; i++) {
      g.add(
        s.t + 0.04 + i * 0.07,
        P.star,
        hx + rn.range(-6.0, 6.0),
        hy + rn.range(-5.0, 5.0),
        0.0,
        -4.0,
        rn.range(0.3, 0.5),
        c[6],
        rn.range(1.0, 2.0),
      );
    }
    for (var i = 0; i < 3 * n; i++) {
      g.add(
        s.t + 0.03 + i * 0.04,
        P.smoke,
        hx + 2.0 + rn.range(-2.0, 2.0),
        hy - 1.0,
        rn.range(8.0, 22.0),
        rn.range(-14.0, -4.0),
        rn.range(0.9, 1.3),
        hex('#5b5f78'),
        rn.range(2.2, 3.4),
      );
    }
  }
  for (var r = 0; r < 12; r++) {
    for (var q = -14; q <= 14; q++) {
      if (!_glints(o.seed, q, r)) continue;
      final lon = (_s3 * (q + r / 2.0)) / _g;
      final lat = (1.5 * r) / (_g * _ky);
      final (x, y, f) = _project(rad, lon, lat);
      if (f < 0.25 || lat < 0.15 || lat > 1.45 || lon.abs() > 1.3) continue;
      g.add(
        _glintAt(o.seed, q, r) + 0.03,
        P.star,
        x,
        y,
        0.0,
        -3.0,
        0.4,
        c[6],
        1.4 + rand(q, r, 9),
      );
    }
  }
  _ghostCache[key] = g;
  return g;
}

void _drawShell(
  Painter p,
  double t,
  Map<String, Object?> o,
  List<int> c,
  bool near,
) {
  final rad = o.numOpt('radius', 44.0);
  final s = o.seed;
  final ph = t / _duration;
  final sh = _shell(rad);
  final ages = [for (final shot in _shots) since(t, shot.t, _duration)];
  final sk = clamp((ph - 0.72) / 0.26);
  final scanLat = -0.2 + sk * 2.0;
  final scanK = math.sin(math.pi * sk);

  for (final q in near ? sh.near : sh.far) {
    final ff = q.rim * q.rim;
    var rp = 0.0;
    var hot = 0.0;
    for (var i = 0; i < _shots.length; i++) {
      final shot = _shots[i];
      final age = ages[i];
      if (age >= 1.0) continue;
      final d = math.acos(
        clamp(q.cx * shot.nx + q.cy * shot.ny + q.cz * shot.nz, -1.0, 1.0),
      );
      final f = 0.06 + 3.1 * age;
      final k = (1.0 - age) * (shot.big ? 1.0 : 0.7);
      final wave = math.exp(-((d - f) / 0.15) * ((d - f) / 0.15)) * k;
      final trail = d < f ? 0.22 * k * k * (1.0 - d / f) : 0.0;
      rp = math.max(rp, math.max(wave, trail));
      final hr = shot.big ? 0.3 : 0.17;
      if (age < 0.55 && d < hr) {
        hot = math.max(
          hot,
          age < 0.07 && d < hr * 0.75
              ? 2.0
              : math.pow(1.0 - age / 0.55, 1.5).toDouble() *
                  (1.1 - (0.6 * d) / hr),
        );
      }
    }
    var gl = 0.0;
    if (_glints(s, q.q, q.r)) {
      final a = since(t, _glintAt(s, q.q, q.r), _duration);
      if (a < 0.45) gl = 1.0 - a / 0.45;
    }
    final sc = scanK *
        math.exp(-((q.lat - scanLat) / 0.09) * ((q.lat - scanLat) / 0.09));
    if (!near) {
      if (q.seam) {
        p.blend(
          q.x + 0.5,
          q.y + 0.5,
          rp > 0.3 ? c[5] : c[3],
          clamp(0.18 + 0.25 * ff + 0.6 * rp + 0.3 * sc),
        );
      } else {
        p.blend(q.x + 0.5, q.y + 0.5, c[2], 0.04 + 0.06 * ff + 0.15 * rp);
      }
      continue;
    }
    if (q.sil < 1.15) {
      final lit = -q.cx * 0.55 + q.cy * 0.85;
      p.px(
        q.x,
        q.y,
        rp > 0.4 || lit > 0.8 ? kWhite : (lit > 0.3 ? c[6] : c[5]),
      );
      p.light(q.x, q.y, c[4], 0.3);
      continue;
    }
    if (hot >= 2.0) {
      p.px(q.x, q.y, q.seam ? c[6] : kWhite);
      continue;
    }
    if (q.seam) {
      final intensity = 0.12 +
          0.5 * ff +
          0.08 * math.sin(q.lon * 2.3 + q.lat * 3.0 - ph * tau) +
          (q.corner < 0.32 ? 0.18 : 0.0) +
          0.9 * gl +
          0.7 * sc +
          1.3 * rp +
          hot;
      final col = gl > 0.6 || rp > 0.55 || hot > 0.5
          ? kWhite
          : (intensity > 0.8 ? c[6] : (intensity > 0.55 ? c[5] : c[4]));
      if (intensity > 0.36) {
        p.px(q.x, q.y, col);
      } else {
        p.blend(q.x + 0.5, q.y + 0.5, col, 0.3 + intensity);
      }
      p.light(q.x, q.y, c[4], 0.04 + 0.08 * intensity);
    } else {
      final a = 0.05 +
          0.34 * ff * q.rim +
          0.1 * math.pow(q.e, 4).toDouble() +
          (q.bevel ? 0.12 + 0.2 * ff : 0.0) +
          0.35 * gl +
          0.1 * sc +
          0.3 * rp +
          0.6 * hot;
      final col = hot > 0.6
          ? kWhite
          : (hot > 0.3 || gl > 0.5
              ? c[6]
              : (rp > 0.4 || q.bevel
                  ? c[5]
                  : (ff > 0.5 ? c[4] : c[3])));
      p.blend(q.x + 0.5, q.y + 0.5, col, clamp(a));
      if (rp > 0.1 || hot > 0.0 || gl > 0.0) {
        p.light(q.x, q.y, c[4], 0.06 * (rp + hot + gl));
      }
    }
  }
}

void _drawFoot(
  Painter p,
  double t,
  List<int> c,
  double rad,
  bool near,
) {
  bool keep(double g) => (math.sin(g) >= 0.0) == near;
  band(
    p,
    0.0,
    0.0,
    rad + 1.0,
    _sa,
    2.0,
    1.0,
    [c[1], c[3], c[5], c[6]],
    keep: keep,
  );
  for (var i = 0; i < 10; i++) {
    final g = (i / 10.0) * tau + 0.31;
    if (!keep(g)) continue;
    final x = math.cos(g) * (rad - 0.5);
    final y = math.sin(g) * rad * _sa;
    final k = 0.5 + 0.5 * math.cos(tau * (2.0 * (t / _duration) - i / 10.0));
    p.px(x - 1.0, y, c[2]);
    p.px(x + 1.0, y, c[2]);
    p.px(x, y, k > 0.6 ? kWhite : c[5]);
    p.glow(x, y, 6.0 + 4.0 * k, c[4], (near ? 0.25 : 0.15) * (0.4 + k));
  }
}

void _drawBack(Painter p, double t, Map<String, Object?> o) {
  final c = fit(o.palette, 8);
  final rad = o.numOpt('radius', 44.0);
  for (var x = -rad; x <= rad; x += rad / 3.0) {
    p.glow(x, -1, 22, c[3], 0.1);
  }
  _drawFoot(p, t, c, rad, false);
  _drawShell(p, t, o, c, false);
}

void _draw(Painter p, double t, Map<String, Object?> o) {
  final c = fit(o.palette, 8);
  final sp = fit(o.rampOpt('sparks'), 4);
  final rad = o.numOpt('radius', 44.0);
  const w = _width - _originX;
  _drawShell(p, t, o, c, true);
  _drawFoot(p, t, c, rad, true);
  for (final s in _shots) {
    final age = since(t, s.t, _duration);
    final (hx, hy, _) = _project(rad, s.lon, s.lat);
    final n = s.big ? 1.0 : 0.6;
    if (s.big && age < 0.9) {
      final fade = 1.0 - smooth(0.35, 0.9, age);
      final reach = clamp(age / 0.09);
      for (var pass = 0; pass < 2; pass++) {
        for (final cr in _cracks(rad, o.seed, s)) {
          for (var i = 1; i < cr.length; i++) {
            final (x0, y0, f0, _) = cr[i - 1];
            final (x1, y1, f1, u) = cr[i];
            if (u > reach || f0 < 0.05 || f1 < 0.05) continue;
            final k = fade * (1.2 - u * 0.4);
            if (pass == 0) {
              if (age < 0.32) {
                for (final (ox, oy) in const [
                  (1, 0),
                  (-1, 0),
                  (0, 1),
                  (0, -1),
                ]) {
                  p.line(
                    x0 + ox,
                    y0 + oy,
                    x1 + ox,
                    y1 + oy,
                    age < 0.12 ? c[6] : c[5],
                    k * (1.0 - age / 0.32),
                  );
                }
              }
              continue;
            }
            p.line(
              x0,
              y0,
              x1,
              y1,
              age < 0.12 + u * 0.08
                  ? kWhite
                  : (age < 0.3 + u * 0.1 ? c[6] : c[5]),
              k,
            );
            if (i % 3 == 0) {
              p.glow(x1, y1, 6, c[4], 0.35 * fade * (1.0 - u * 0.5));
            }
          }
        }
      }
    }
    final tk = (t - (s.t - 0.1)) / 0.1;
    if (tk >= 0.0 && tk < 1.0) {
      const sx = w - 3.0;
      final sy = hy - 12.0;
      final l = hypot(sx - hx, sy - hy);
      (double, double) atPt(double d) {
        final md = math.max(0.0, d);
        return (sx + ((hx - sx) * md) / l, sy + ((hy - sy) * md) / l);
      }

      final h = l * tk;
      final (x, y) = atPt(h);
      final (x2, y2) = atPt(h - 2.0);
      final (x7, y7) = atPt(h - 7.0);
      final (x16, y16) = atPt(h - 16.0);
      p.line(x16, y16, x7, y7, sp[3]);
      p.line(x7, y7, x2, y2, sp[1]);
      p.line(x2, y2, x, y, sp[0]);
      p.px(x, y, kWhite);
      p.glow(x, y, 9, sp[1], 0.55);
    }
    if (age < 0.14) {
      sparkle(p, hx, hy, (7.0 * (1.0 - age / 0.14) + 1.0) * n, c[6], c[5], 0.4);
    }
    flash(p, t, s.t, hx, hy, 56.0 * n, c[4], 0.45, 0.45);
    flash(p, t, s.t, hx, hy, 12.0, kWhite, 0.5 * n, 0.08);
    flash(p, t, s.t, hx + 3.0, hy, 22.0, sp[1], 0.4 * n, 0.15);
  }
  final a0 = since(t, _shots[0].t, _duration);
  p.glow(0, -rad * 0.45, rad * 1.3, c[3], 0.11 + 0.1 * math.max(0.0, 1.0 - a0 * 2.0));
  _ghosts(o, c, rad).at(t).draw(p);
}

final PixelEffect forceFieldEffect = PureEffect(
  meta: const EffectMeta(
    id: 'scifi/force-field',
    name: 'Force field',
    desc:
        'A glassy dome of hex plates over the hero: plates glint, tracers from the right slam into it, a ripple and cracks of light race across, sparks glance off.',
    category: 'scifi',
    tags: [
      'scifi',
      'shield',
      'barrier',
      'dome',
      'hex',
      'hit',
      'defense',
      'loop',
    ],
    size: (_width, 104),
    origin: (_originX, 84),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#0b1030',
        '#152a63',
        '#1d4f9e',
        '#2582d2',
        '#36b9ee',
        '#8ae8ff',
        '#d4fbff',
        '#ffffff',
      ],
      'sparks': ['#fff3a6', '#ffe26b', '#ff8a2a', '#f2561d'],
      'radius': 44,
      'seed': 5,
    },
  ),
  act: _act,
  onDrawBack: _drawBack,
  onDraw: _draw,
);
