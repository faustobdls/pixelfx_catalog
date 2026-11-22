// The lit floor line is adapted from Sprite Fusion's open-source heal (https://www.spritefusion.com/pixel-art-vfx/heal),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'holy_lib.dart';

const Pose _down = Pose(
  turn: 0.9,
  crouch: 8,
  lean: 6,
  hy: 2,
  fx: -4,
  fy: -10,
  bx: 9,
  by: -10,
  ffx: 8,
  fbx: -7,
);

const Pose _risen = Pose(
  turn: 1.15,
  crouch: -1,
  fx: -15,
  fy: -33,
  bx: 16,
  by: -33,
  hy: -1,
  ffx: -3,
  ffy: -5,
  fbx: 4,
  fby: -5,
);

const double _top = -140.0;
const double _pour = 0.34;
const double _cl0 = 0.5;
const double _cl1 = 1.15;
const double _w0 = 1.1;
const double _h0 = 1.24;
const double _h1 = 1.5;
const double _b0 = 1.95;
const double _b1 = 2.25;
const double _b2 = 2.37;
const double _b3 = 2.8;
const double _sc = 2.95;

const double _hx = 0.0;
const double _hy = -47.0;
const double _hrx = 9.5;
const double _hry = 2.6;

const (double, double) _shoulder = (4.0, -20.0);
const List<(double, double)> _armOpen = [
  (0.0, 0.0),
  (7.0, -9.0),
  (15.0, -19.0),
  (20.0, -27.0),
];
const List<(double, double)> _armFold = [
  (0.0, 0.0),
  (2.0, -2.0),
  (3.0, -3.0),
  (4.0, -3.0),
];

const List<(double s, double ang, double len, double wid, int kind)> _quillSpecs = [
  (0.14, 1.35, 11.0, 2.6, 1),
  (0.26, 1.12, 14.0, 2.8, 1),
  (0.38, 0.88, 17.0, 3.0, 1),
  (0.5, 0.62, 19.0, 3.1, 1),
  (0.62, 0.35, 21.0, 3.2, 1),
  (0.72, 0.08, 23.0, 3.3, 1),
  (0.8, -0.2, 26.0, 3.4, 0),
  (0.85, -0.45, 29.0, 3.5, 0),
  (0.9, -0.72, 31.0, 3.6, 0),
  (0.95, -1.0, 30.0, 3.6, 0),
  (1.0, -1.3, 26.0, 3.4, 0),
  (0.22, 1.2, 7.0, 2.2, 2),
  (0.34, 0.98, 8.0, 2.3, 2),
  (0.46, 0.75, 9.0, 2.4, 2),
  (0.58, 0.5, 10.0, 2.5, 2),
  (0.7, 0.22, 10.0, 2.5, 2),
  (0.81, -0.1, 11.0, 2.6, 2),
  (0.92, -0.5, 11.0, 2.6, 2),
];

const List<double> _flex = [1.0, 0.5, 0.3];

(double, double) _along(List<(double, double)> pts, double s) {
  var total = 0.0;
  final segLen = List<double>.filled(pts.length - 1, 0.0);
  for (var i = 1; i < pts.length; i++) {
    final len = hypot(pts[i].$1 - pts[i - 1].$1, pts[i].$2 - pts[i - 1].$2);
    segLen[i - 1] = len;
    total += len;
  }
  var d = s * total;
  for (var i = 0; i < segLen.length; i++) {
    if (d <= segLen[i] || i == segLen.length - 1) {
      final f = segLen[i] != 0.0 ? clamp(d / segLen[i]) : 0.0;
      return (
        lerp(pts[i].$1, pts[i + 1].$1, f),
        lerp(pts[i].$2, pts[i + 1].$2, f),
      );
    }
    d -= segLen[i];
  }
  return pts.last;
}

double _beat(double t) {
  if (t < _b0) return 0.0;
  if (t < _b1) return -0.34 * Ease.inOutSine(seg(t, _b0, _b1));
  if (t < _b2) return lerp(-0.34, 0.66, Ease.inQuad(seg(t, _b1, _b2)));
  return 0.66 * (1.0 - Ease.outBack(seg(t, _b2, _b3), 1.3));
}

class _ShaftRay {
  final double o;
  final double w;
  final double b;
  final double f;
  final double ph;

  const _ShaftRay(this.o, this.w, this.b, this.f, this.ph);
}

class _ShaftMote {
  final double q;
  final double y;
  final double v;
  final double amp;
  final double ph;
  final double f;

  const _ShaftMote(this.q, this.y, this.v, this.amp, this.ph, this.f);
}

class _QuillState {
  final double s;
  final double ang;
  final double len;
  final double wid;
  final int kind;
  final double fold;
  final double open;
  final List<double> off;
  final List<bool> gone = [false, false];

  _QuillState({
    required this.s,
    required this.ang,
    required this.len,
    required this.wid,
    required this.kind,
    required this.fold,
    required this.open,
    required this.off,
  });
}

class _WingFeather {
  final int i;
  final _QuillState q;
  final double x;
  final double y;
  final double ang;
  final double len;
  final double wid;
  final double a;
  final double hot;

  const _WingFeather({
    required this.i,
    required this.q,
    required this.x,
    required this.y,
    required this.ang,
    required this.len,
    required this.wid,
    required this.a,
    required this.hot,
  });
}

class _ResurrectionSim extends BaseEffectSim {
  final List<int> c;
  final List<int> ash;
  final ActorDefinition actor;
  final HolyShape s;
  final Rng r;
  late final List<int> wingPal;
  late final Particles ps;
  final Lights lights = Lights();
  late final Feathers loose;
  final Map<int, List<int>> rows = {};
  late final List<_ShaftRay> rays;
  late final List<_ShaftRay> cores;
  late final List<_ShaftMote> motes;
  late final List<_QuillState> quills;
  final Float32List profile = Float32List(121);
  double t = 0.0;
  bool poured = false;
  bool flashed = false;
  bool formed = false;
  bool beaten = false;

  _ResurrectionSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        ash = fit(o.rampOpt('ash'), 6),
        actor = o.actor,
        s = shapeOf(o.actor),
        r = Rng(o.seed) {
    wingPal = [c[2], c[3], c[4], c[5], c[6], kWhite];
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [kWhite, c[6], c[5], c[3]],
      haze: c[4],
    );
    loose = Feathers(r, 0.0);
    for (final (x, y) in s.edge) {
      rows.putIfAbsent(y, () => []).add(x);
    }

    rays = List.generate(6, (i) {
      final oVal = -0.75 + i * 0.3 + r.range(-0.08, 0.08);
      final w = r.range(0.1, 0.2);
      final b = r.range(0.55, 1.0);
      final f = r.range(1.5, 3.5);
      final ph = r.range(0.0, tau);
      return _ShaftRay(oVal, w, b, f, ph);
    }, growable: false);
    cores = ([...rays]..sort((a, b) => b.b.compareTo(a.b))).sublist(0, 2);

    motes = List.generate(34, (_) {
      final q = r.range(-1.0, 1.0);
      final y = r.range(0.0, 1.0);
      final v = r.range(4.0, 11.0);
      final amp = r.range(0.6, 2.4);
      final ph = r.range(0.0, tau);
      final f = r.range(0.6, 1.4);
      return _ShaftMote(q, y, v, amp, ph, f);
    }, growable: false);

    final reach = _quillSpecs.map((spec) {
      final (bx, by) = _along(_armOpen, spec.$1);
      return hypot(
        bx + math.cos(spec.$2) * spec.$3,
        by + math.sin(spec.$2) * spec.$3,
      );
    }).toList(growable: false);
    final far = reach.reduce(math.max);

    quills = List.generate(_quillSpecs.length, (i) {
      final (sVal, ang, len, wid, kind) = _quillSpecs[i];
      double off() => _sc + (1.0 - reach[i] / far) * 0.2 + r.range(0.0, 0.04);
      return _QuillState(
        s: sVal,
        ang: ang,
        len: len,
        wid: wid,
        kind: kind,
        fold: 1.45 + (i % 6) * 0.04,
        open: kind == 0
            ? 0.06 + (sVal - 0.8) * 0.45
            : (kind == 1 ? sVal * 0.06 : 0.03 + sVal * 0.05),
        off: [off(), off()],
      );
    }, growable: false);
  }

  double _climbY(double tt) =>
      lerp(1.0, s.top - 2.0, Ease.inOutSine(seg(tt, _cl0, _cl1)));

  double _shaftK(double tt) =>
      smooth(0.0, 0.12, tt) * (1.0 - smooth(3.0, 3.75, tt));

  double _shaftW(double tt) =>
      lerp(0.4, 1.0, Ease.outCubic(seg(tt, 0.0, 0.6))) *
      lerp(1.0, 0.12, Ease.inCubic(seg(tt, 2.9, 3.6)));

  double _halfW(double y, double tt) =>
      lerp(8.0, 25.0, (y - _top) / -_top) * _shaftW(tt);

  ({List<_WingFeather> out, List<(double, double)> arm}) _wing(
    double tt,
    int side,
  ) {
    final oa = Ease.outBack(seg(tt, _w0, _w0 + 0.4), 1.6);
    final rot = _beat(tt);
    final om = (_beat(tt) - _beat(tt - 0.03)) / 0.03;
    final arm = List<(double, double)>.generate(_armFold.length, (i) {
      return (
        lerp(_armFold[i].$1, _armOpen[i].$1, oa),
        lerp(_armFold[i].$2, _armOpen[i].$2, oa),
      );
    }, growable: false);
    final cr = math.cos(rot);
    final sr = math.sin(rot);
    (double, double) place((double, double) pt) => (
          side * (_shoulder.$1 + pt.$1 * cr - pt.$2 * sr),
          _shoulder.$2 + pt.$1 * sr + pt.$2 * cr,
        );
    final a0 = smooth(_w0, _w0 + 0.1, tt);
    final out = <_WingFeather>[];
    final sideIdx = side > 0 ? 0 : 1;
    for (var i = 0; i < quills.length; i++) {
      final q = quills[i];
      if (tt >= q.off[sideIdx] + 0.05) continue;
      final of = Ease.outBack(seg(tt, _w0 + q.open, _w0 + q.open + 0.42), 2.0);
      final (bx, by) = place(_along(arm, q.s));
      final ang = lerp(q.fold, q.ang, of) +
          rot -
          clamp(om * 0.045 * _flex[q.kind], -0.5, 0.5);
      out.add(_WingFeather(
        i: i,
        q: q,
        x: bx,
        y: by,
        ang: side > 0 ? ang : math.pi - ang,
        len: q.len * lerp(0.3, 1.0, of),
        wid: q.wid,
        a: a0,
        hot: tt < _w0 + q.open + 0.07 || tt >= q.off[sideIdx] ? 1.0 : 0.0,
      ));
    }
    return (out: out, arm: arm.map(place).toList(growable: false));
  }

  void _drawWing(Painter p, int side) {
    final (:out, :arm) = _wing(t, side);
    if (out.isEmpty) return;
    final order = [...out]..sort((a, b) => b.q.ang.compareTo(a.q.ang));
    for (final f in order) {
      if (f.q.kind != 2) {
        feather(p, f.x, f.y, f.ang, f.len, f.wid, wingPal, f.a, side, f.hot);
      }
    }
    for (final f in order) {
      if (f.q.kind == 2) {
        feather(p, f.x, f.y, f.ang, f.len, f.wid, wingPal, f.a, side, f.hot);
      }
    }
    final k = out.length / quills.length;
    if (k > 0.5) {
      p.polyline(
        [for (final (x, y) in arm) (x, y + 1.0)],
        c[5],
        out[0].a,
      );
      p.polyline(arm, kWhite, out[0].a);
    }
    p.glow(side * 28.0, -36, 38, c[4], 0.26 * out[0].a * k);
    final g = ((t - _w0 - 0.45) * 1.3) % 1.0;
    if (k > 0.9 && t > _w0 + 0.45 && g < 0.8) {
      final (gx, gy) = _along(arm, g / 0.8);
      sparkle(
        p,
        gx,
        gy,
        2.0 + math.sin((g / 0.8) * math.pi) * 2.0,
        kWhite,
        c[6],
        0.4,
      );
    }
    p.glowLine(
      arm[0].$1,
      arm[0].$2,
      arm[3].$1,
      arm[3].$2,
      7,
      c[5],
      0.25 * out[0].a * k,
    );

    if (t > _b1 + 0.03 && t < _b2 + 0.14) {
      for (final idx in const [6, 8, 10]) {
        final pts = <(double, double)>[];
        for (var j = 0; j < 10; j++) {
          final tt = math.max(_b1 + 0.01, t - j * 0.012);
          final wOut = _wing(tt, side).out;
          _WingFeather? w;
          for (final f in wOut) {
            if (f.i == idx) {
              w = f;
              break;
            }
          }
          if (w != null) {
            pts.add((
              w.x + math.cos(w.ang) * (w.len - 1.0),
              w.y + math.sin(w.ang) * (w.len - 1.0),
            ));
          }
        }
        final fade = 1.0 - smooth(_b2, _b2 + 0.14, t);
        for (var j = 1; j < pts.length; j++) {
          p.line(
            pts[j - 1].$1,
            pts[j - 1].$2,
            pts[j].$1,
            pts[j].$2,
            j < 3 ? kWhite : (j < 6 ? c[6] : c[4]),
            fade * (1.1 - j / 10.0),
          );
        }
      }
    }
  }

  void _shaft(Painter p) {
    final k = _shaftK(t);
    if (k <= 0.0) return;
    for (var i = 0; i < profile.length; i++) {
      final q = (i - 60) / 40.0;
      var intensity = 0.0;
      for (final ray in rays) {
        final d = (q - ray.o) / ray.w;
        intensity += ray.b *
            math.exp(-(d * d)) *
            (0.72 + 0.28 * math.sin(t * ray.f + ray.ph));
      }
      profile[i] = (intensity * 0.6 + 0.35 * math.max(0.0, 1.0 - q * q)) *
          smooth(1.25, 0.7, q.abs());
    }
    final front = lerp(_top, 1.0, Ease.inQuad(seg(t, 0.0, _pour)));
    final w0 = _halfW(0.0, t) * 1.3;
    p.each(-w0 - 1.0, _top, w0 + 1.0, math.min(front, 0.5), (x, y, sx, sy) {
      final w = _halfW(y, t);
      final q = x / w;
      if (q < -1.5 || q > 1.5) return;
      final intensity = profile[holyRound(q * 40.0) + 60] *
          k *
          (0.75 + 0.25 * smooth(_top, 0.0, y)) *
          smooth(front, front - 10.0, y);
      if (intensity <= 0.01) return;
      p.blendPx(sx, sy, c[6], intensity * 0.24);
      p.add(sx, sy, c[4], intensity * 0.3);
    });

    for (final ray in cores) {
      final sh = 0.75 + 0.25 * math.sin(t * ray.f + ray.ph);
      final yEnd = math.min(front, 0.0);
      for (var y = _top; y < yEnd; y += 1.0) {
        final pulse = 0.5 + 0.5 * math.sin(y * 0.13 - t * 11.0 + ray.ph);
        p.dot(
          ray.o * _halfW(y, t),
          y,
          pulse > 0.8 ? kWhite : c[6],
          k * sh * (0.15 + 0.55 * pulse) * smooth(front, front - 10.0, y),
        );
      }
    }

    if (t < _pour + 0.05 && front > _top + 14.0) {
      final fy = math.min(front, 0.0);
      p.glow(0, fy, 14, c[5], 0.7 * k);
      for (var dy = -6; dy <= 0; dy++) {
        p.dot(0, fy + dy, dy > -3 ? kWhite : c[6], 1.0 + dy / 7.0);
      }
    }

    for (final m in motes) {
      final y = _top + wrap(m.y * -_top + t * m.v, -_top);
      if (y > front) continue;
      final w = _halfW(y, t);
      final x = m.q * w + math.sin(t * m.f + m.ph) * m.amp;
      final pIdx = holyRound((x / w) * 40.0) + 60;
      if (pIdx < 0 || pIdx >= profile.length) continue;
      final intensity = profile[pIdx] * k;
      if (intensity < 0.25) continue;
      p.dot(
        x,
        y,
        intensity > 0.75 ? kWhite : (intensity > 0.5 ? c[6] : c[5]),
        math.min(1.0, intensity * 1.4),
      );
      p.light(x, y, c[5], intensity * 0.5);
    }
  }

  void _pool(Painter p, bool back) {
    final k = _shaftK(t) * smooth(_pour - 0.05, _pour + 0.1, t);
    final w = _halfW(0.0, t) * 1.25;
    if (k <= 0.0) return;
    if (back) {
      p.glow(0, -2, w * 1.6, c[4], 0.3 * k);
      return;
    }
    final x0 = (-w).floor();
    for (var y = 0; y <= 3; y++) {
      for (var x = x0; x <= w; x++) {
        final u = hypot(x / w, y / 4.0);
        if (u >= 1.0) continue;
        final a = k * (y == 0 ? math.sqrt(1.0 - u) * 1.2 : (1.0 - u) * 0.9);
        p.dot(
          x,
          y,
          u < 0.3
              ? (y != 0 ? c[5] : kWhite)
              : (u < 0.6 ? c[5] : (u < 0.85 ? c[4] : c[3])),
          a,
        );
      }
    }
  }

  void _drawHalo(Painter p) {
    final form = Ease.outCubic(seg(t, _h0, _h1));
    final k = 1.0 - smooth(3.35, 3.9, t);
    if (form <= 0.0 || k <= 0.0) return;
    final white = t >= _h1 && t < _h1 + 0.06;
    final gl = (t - _h1) * 4.2 + math.pi / 2.0;
    const n = 96;
    for (var j = 0; j < n; j++) {
      final g = (j / n) * tau;
      final fromFront =
          (wrap(g - math.pi / 2.0 + math.pi, tau) - math.pi).abs();
      if (fromFront > form * math.pi + 0.02) continue;
      final x = _hx + math.cos(g) * _hrx * (0.9 + 0.1 * form);
      final y = _hy + math.sin(g) * _hry;
      final near = math.sin(g) >= 0.0;
      final dg = (wrap(g - gl + math.pi, tau) - math.pi).abs();
      final hot = white || dg < 0.22 || fromFront > form * math.pi - 0.3;
      if (near) {
        p.dot(x, y, hot ? kWhite : c[6], k);
        p.dot(x, y + 1.0, hot ? c[6] : c[4], k);
      } else {
        p.dot(x, y, hot ? c[6] : c[5], k * 0.9);
      }
    }
    p.glow(_hx, _hy, 20, c[4], 0.4 * k * form);
    p.glow(_hx, _hy + 1.0, 9, kWhite, 0.2 * k * form);
    final gx = _hx + math.cos(gl) * _hrx;
    final gy = _hy + math.sin(gl) * _hry;
    if (t > _h1 && math.sin(gl) > 0.2) {
      sparkle(
        p,
        gx,
        gy + 0.5,
        2.0 + 2.0 * math.sin(gl),
        c[6],
        c[4],
        0.35 * k,
      );
    }
    if (t >= _h1 && t < _h1 + 0.3) {
      sparkle(
        p,
        _hx,
        _hy + _hry + 0.5,
        7.0 * (1.0 - (t - _h1) / 0.3),
        kWhite,
        c[5],
        0.6,
      );
    }
  }

  void _body(Painter p) {
    if (t >= _cl1 + 0.6) return;
    final ly = _climbY(t);
    if (t < _cl1) {
      recolor(p, actor, (col, _, y) {
        final d = y - ly;
        if (d < -0.5) return toneOf(ash, col);
        if (d < 0.5) return kWhite;
        if (d < 1.5) return c[6];
        final k = math.exp(-(d - 1.5) / 4.0) * 0.7;
        return k > 0.08 ? mix(col, c[5], k) : 0;
      });
      for (final (x, y) in s.out) {
        final d = y - ly;
        if (d < -0.5 || d > 12.0) continue;
        p.dot(
          x,
          y,
          d < 1.0 ? kWhite : (d < 5.0 ? c[5] : c[4]),
          d < 1.0 ? 1.0 : 1.1 - d / 12.0,
        );
      }
      if (t > _cl0) {
        p.glow(0, ly, 26, c[4], 0.5);
        p.glow(0, ly, 8, kWhite, 0.3);
        p.glow(0, -18, 36, c[5], 0.16 * seg(t, _cl0, _cl1));
      }
      return;
    }
    final u = t - _cl1;
    recolor(p, actor, (col, _, _) {
      if (u < 0.06) return kWhite;
      if (u < 0.45) {
        return mix(col, c[5], 0.55 * math.pow(1.0 - u / 0.45, 2).toDouble());
      }
      return 0;
    });
    if (u < 0.25) {
      for (final (x, y) in s.out) {
        p.dot(x, y, u < 0.08 ? kWhite : c[5], 1.0 - u / 0.25);
      }
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    // Light streaks pour down the shaft, faster as they fall.
    if (t > 0.05 && t < 2.9 && r.chance(0.16)) {
      final q = r.range(-0.9, 0.9);
      final y = _top + r.range(8.0, 24.0);
      final v0 = r.range(50.0, 90.0);
      final life = math.log(1.0 + (3.0 * (-y - 2.0)) / v0) / 3.0;
      final col = r.chance(0.5) ? c[6] : c[5];
      ps.spawn(P.streak, q * _halfW(y, t), y, q * 2.0, v0, life, col);
    }
    if (t > 0.3 && t < 2.8 && r.chance(0.05)) {
      final x = r.range(-1.0, 1.0) * _halfW(-30.0, t);
      final y = -r.range(4.0, 90.0);
      final vx = r.range(-3.0, 3.0);
      final vy = r.range(-4.0, 6.0);
      final life = r.range(0.4, 0.8);
      final col = r.chance(0.5) ? c[6] : kWhite;
      final size = r.range(0.6, 1.8);
      ps.spawn(P.star, x, y, vx, vy, life, col, size);
    }
    if (!poured && t >= _pour) {
      poured = true;
      lights.add(0, -12, 42, c[5], 0.9, 0.4);
      lights.add(0, -6, 16, kWhite, 0.6, 0.1);
      for (var i = 0; i < 14; i++) {
        final sx = r.range(-18.0, 18.0);
        final sy = -r.range(0.0, 6.0);
        final vx = r.range(-20.0, 20.0);
        final vy = -r.range(10.0, 50.0);
        final life = r.range(0.5, 1.1);
        final col = r.chance(0.5) ? kWhite : c[6];
        final size = r.range(0.6, 2.2);
        ps.spawn(P.star, sx, sy, vx, vy, life, col, size);
      }
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2.0 + r.range(-1.2, 1.2);
        final sp = r.range(60.0, 150.0);
        final sx = r.range(-3.0, 3.0);
        final life = r.range(0.25, 0.5);
        ps.spawn(P.spark, sx, -1.0, math.cos(a) * sp, math.sin(a) * sp, life);
      }
    }
    // Life climbs the body: bits of light peel off the rim at the front.
    if (t > _cl0 && t < _cl1) {
      final ly = holyRound(_climbY(t));
      for (final y in [ly, ly + 1]) {
        final xs = rows[y];
        if (xs == null || !r.chance(0.35)) continue;
        final x = r.pick(xs);
        final sign = (x + 0.5).sign;
        final kind = r.chance(0.6) ? P.mote : P.star;
        final vx = sign * r.range(8.0, 30.0);
        final vy = -r.range(15.0, 45.0);
        final life = r.range(0.35, 0.7);
        final col = r.chance(0.5) ? c[6] : c[5];
        final size = r.range(0.5, 1.1);
        ps.spawn(kind, x + sign, y.toDouble(), vx, vy, life, col, size);
      }
    }
    if (!flashed && t >= _cl1) {
      flashed = true;
      lights.add(0, -24, 64, c[5], 0.7, 0.5);
      lights.add(0, -30, 28, kWhite, 0.7, 0.1);
      for (var i = 0; i < 18; i++) {
        final a = r.range(0.0, tau);
        final sp = r.range(30.0, 110.0);
        final life = r.range(0.4, 0.9);
        final col = r.chance(0.5) ? kWhite : c[6];
        final size = r.range(0.6, 2.0);
        ps.spawn(
          P.star,
          math.cos(a) * 6.0,
          -24.0 + math.sin(a) * 12.0,
          math.cos(a) * sp,
          math.sin(a) * sp * 0.7 - 20.0,
          life,
          col,
          size,
        );
      }
    }
    // Motes spiral in to make the halo.
    if (t > _h0 - 0.2 && t < _h0 + 0.1 && r.chance(0.6)) {
      final g = r.range(0.0, tau);
      final d = r.range(14.0, 24.0);
      final x = _hx + math.cos(g) * d;
      final y = _hy + math.sin(g) * d * 0.5;
      final tx = _hx + math.cos(g + 0.6) * _hrx;
      final ty = _hy + math.sin(g + 0.6) * _hry;
      final dur = r.range(0.16, 0.24);
      final lRaw = hypot(tx - x, ty - y);
      final l = lRaw == 0.0 ? 1.0 : lRaw;
      final v = (l * 3.0) / (math.exp(3.0 * dur) - 1.0);
      final col = r.chance(0.5) ? c[6] : c[5];
      ps.spawn(
        P.streak,
        x,
        y,
        ((tx - x) / l) * v,
        ((ty - y) / l) * v,
        dur,
        col,
      );
    }
    if (!formed && t >= _h1) {
      formed = true;
      lights.add(_hx, _hy, 30, c[6], 0.8, 0.3);
    }
    // The wings burst open with a scatter of light.
    if (t > _w0 && t < _w0 + 0.35 && r.chance(0.5)) {
      for (final side in const [-1, 1]) {
        final list = _wing(t, side).out;
        if (list.isEmpty) {
          r.next();
          continue;
        }
        final f = r.pick(list);
        final vx = side * r.range(5.0, 25.0);
        final vy = -r.range(5.0, 25.0);
        final life = r.range(0.3, 0.6);
        final col = r.chance(0.5) ? kWhite : c[6];
        final size = r.range(0.6, 1.6);
        ps.spawn(
          P.star,
          f.x + math.cos(f.ang) * f.len,
          f.y + math.sin(f.ang) * f.len,
          vx,
          vy,
          life,
          col,
          size,
        );
      }
    }
    // While the wings hold, light twinkles on the tips and motes lift off them.
    if (t > _w0 + 0.45 && t < _sc) {
      for (final side in const [-1, 1]) {
        if (r.chance(0.045)) {
          final list = _wing(t, side)
              .out
              .where((w) => w.q.kind == 0)
              .toList(growable: false);
          if (list.isEmpty) {
            r.next();
          } else {
            final f = r.pick(list);
            final vy = -r.range(2.0, 8.0);
            final life = r.range(0.3, 0.6);
            final col = r.chance(0.5) ? kWhite : c[6];
            final size = r.range(1.0, 2.4);
            ps.spawn(
              P.star,
              f.x + math.cos(f.ang) * (f.len - 2.0),
              f.y + math.sin(f.ang) * (f.len - 2.0),
              0.0,
              vy,
              life,
              col,
              size,
            );
          }
        }
        if (r.chance(0.03)) {
          final list = _wing(t, side).out;
          if (list.isEmpty) {
            r.next();
          } else {
            final f = r.pick(list);
            final vx = r.range(-8.0, 8.0);
            final vy = -r.range(8.0, 25.0);
            final life = r.range(0.6, 1.1);
            ps.spawn(
              P.ember,
              f.x + math.cos(f.ang) * f.len * 0.7,
              f.y + math.sin(f.ang) * f.len * 0.7,
              vx,
              vy,
              life,
              c[5],
            );
          }
        }
      }
    }
    // The downstroke: a gust along the floor, light flung off the tips, a few feathers shaken loose.
    if (!beaten && t >= _b2 - 0.03) {
      beaten = true;
      for (final side in const [-1, 1]) {
        lights.add(side * 30.0, -34, 46, c[5], 0.6, 0.4);
        for (var i = 0; i < 7; i++) {
          final px = side * r.range(8.0, 22.0);
          final py = -r.range(1.0, 4.0);
          final vx = side * r.range(90.0, 160.0);
          final vy = -r.range(0.0, 8.0);
          final life = r.range(0.25, 0.45);
          final col = r.chance(0.5) ? c[6] : c[5];
          final size = r.range(0.6, 1.0);
          ps.spawn(P.mote, px, py, vx, vy, life, col, size);
        }
        final wingOut = _wing(t, side).out;
        for (final f in wingOut) {
          if (f.q.kind == 0) {
            final tx = f.x + math.cos(f.ang) * f.len;
            final ty = f.y + math.sin(f.ang) * f.len;
            final vx = side * r.range(30.0, 90.0);
            final vy = r.range(60.0, 160.0);
            final life = r.range(0.3, 0.6);
            ps.spawn(P.spark, tx, ty, vx, vy, life);
          }
        }
        final sec =
            wingOut.where((w) => w.q.kind == 1).toList(growable: false);
        for (var i = 0; i < 3; i++) {
          if (sec.isEmpty) {
            r.next();
            continue;
          }
          final f = r.pick(sec);
          final vx = side * r.range(20.0, 70.0);
          final vy = r.range(10.0, 50.0);
          final len = r.range(9.0, 12.0);
          final wid = r.range(2.2, 2.8);
          final life = r.range(1.2, 1.6);
          loose.add(
            x: f.x + math.cos(f.ang) * f.len * 0.6,
            y: f.y + math.sin(f.ang) * f.len * 0.6,
            vx: vx,
            vy: vy,
            a: f.ang,
            len: len,
            wid: wid,
            life: life,
            side: side,
          );
        }
      }
    }
    // The wings come apart, tips first: each feather flashes and breaks into small ones and motes.
    for (final side in const [-1, 1]) {
      final si = side > 0 ? 0 : 1;
      for (final q in quills) {
        if (q.gone[si] || t < q.off[si]) continue;
        q.gone[si] = true;
        final wOut = _wing(q.off[si] - 0.001, side).out;
        _WingFeather? f;
        for (final wf in wOut) {
          if (wf.q == q) {
            f = wf;
            break;
          }
        }
        if (f == null) continue;
        final ca = math.cos(f.ang);
        final sa = math.sin(f.ang);
        final n = q.kind == 2 ? 0 : 1;
        for (var j = 0; j < n; j++) {
          const u = 0.55;
          final x = f.x + ca * f.len * u;
          final y = f.y + sa * f.len * u;
          final ox = x - side * 4.0;
          final oy = y + 20.0;
          final lRaw = hypot(ox, oy);
          final l = lRaw == 0.0 ? 1.0 : lRaw;
          final sp = r.range(60.0, 150.0);
          final vx = (ox / l) * sp + r.range(-15.0, 15.0);
          final vy = (oy / l) * sp * 0.5 - r.range(20.0, 50.0);
          final fa = f.ang + r.range(-0.4, 0.4);
          final len = r.range(9.0, 12.0);
          final wid = r.range(2.2, 2.8);
          final life = r.range(1.0, 1.45);
          final back = r.chance(0.35);
          loose.add(
            x: x,
            y: y,
            vx: vx,
            vy: vy,
            a: fa,
            len: len,
            wid: wid,
            life: life,
            side: side,
            back: back,
          );
        }
        for (var j = 0; j < 2; j++) {
          final sx = f.x + ca * f.len * r.range(0.3, 1.0);
          final sy = f.y + sa * f.len * r.range(0.3, 1.0);
          final vx = r.range(-15.0, 15.0);
          final vy = -r.range(10.0, 40.0);
          final life = r.range(0.6, 1.1);
          ps.spawn(P.ember, sx, sy, vx, vy, life, c[5]);
        }
        if (r.chance(0.6)) {
          final vy = -r.range(5.0, 15.0);
          final life = r.range(0.3, 0.6);
          final size = r.range(1.0, 2.0);
          ps.spawn(
            P.star,
            f.x + ca * f.len,
            f.y + sa * f.len,
            0.0,
            vy,
            life,
            kWhite,
            size,
          );
        }
      }
    }
    // The halo melts into rising motes.
    if (t > 3.35 && t < 3.75 && r.chance(0.4)) {
      final g = r.range(0.0, tau);
      final vx = r.range(-6.0, 6.0);
      final vy = -r.range(10.0, 25.0);
      final life = r.range(0.5, 0.9);
      ps.spawn(
        P.ember,
        _hx + math.cos(g) * _hrx,
        _hy + math.sin(g) * _hry,
        vx,
        vy,
        life,
        c[5],
      );
    }
    ps.update(dt);
    lights.update(dt);
    loose.update(dt);
  }

  @override
  void drawBack(Painter p) {
    _shaft(p);
    _pool(p, true);
    if (t > _pour && t < _pour + 0.4) {
      final u = seg(t, _pour, _pour + 0.4);
      band(
        p,
        0,
        0,
        4.0 + 32.0 * Ease.outCubic(u),
        0.18,
        2.5 * (1.0 - u) + 0.5,
        1.1 - u,
        c.sublist(3),
        keep: farHalf,
        hot: t < _pour + 0.06,
      );
    }
    for (final side in const [-1, 1]) {
      _drawWing(p, side);
    }
    loose.draw(p, wingPal, 'back');
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    _pool(p, false);
    if (t > _pour && t < _pour + 0.4) {
      final u = seg(t, _pour, _pour + 0.4);
      band(
        p,
        0,
        0,
        4.0 + 32.0 * Ease.outCubic(u),
        0.18,
        2.5 * (1.0 - u) + 0.5,
        1.1 - u,
        c.sublist(3),
        keep: nearHalf,
        hot: t < _pour + 0.06,
      );
    }
    _body(p);
    // The downstroke sends a ripple of light out along the floor.
    if (t > _b2 - 0.03 && t < _b2 + 0.45) {
      final u = seg(t, _b2 - 0.03, _b2 + 0.45);
      final fx = 10.0 + 70.0 * Ease.outCubic(u);
      for (final side in const [-1, 1]) {
        for (var d = 0; d < 12; d++) {
          p.dot(
            side * (fx - d),
            0,
            d < 2 ? kWhite : (d < 5 ? c[6] : c[4]),
            (1.0 - u) * (1.0 - d / 12.0) * 1.3,
          );
        }
      }
    }
    // The wings light the character from behind.
    final wk = smooth(_w0, _w0 + 0.2, t) * (1.0 - smooth(_sc, _sc + 0.3, t));
    if (wk > 0.0) {
      for (final (x, y) in s.out) {
        if (y < -8) p.light(x, y, c[5], 0.55 * wk);
      }
      p.glow(0, -34, 76, c[4], 0.14 * wk);
    }
    _drawHalo(p);
    if (t >= _cl1 && t < _cl1 + 0.22) {
      final u = (t - _cl1) / 0.22;
      flare(p, 0, s.top - 1.0, 22.0 * (1.0 - u), 1.0 - u, c.sublist(3));
    }
    loose.draw(p, wingPal, 'front');
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect resurrectionEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'holy/resurrection',
    name: 'Resurrection',
    desc:
        'Light pours down on the fallen and life climbs back up the body; wings of light unfold, a halo forms, one great wingbeat, then the wings scatter into feathers.',
    category: 'holy',
    tags: [
      'holy',
      'revive',
      'resurrect',
      'wings',
      'halo',
      'light',
      'character',
      'one-shot',
    ],
    size: (192, 160),
    origin: (96, 140),
    duration: 4.8,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'palette': kHolyGold, 'ash': kHolyAsh, 'seed': 5},
  ),
  act: ActSpec(
    onBody: true,
    follow: 0.6,
    poses: [
      const PoseKey(0.0, _down),
      const PoseKey(0.5, _down),
      PoseKey(0.85, _down.copyWith(crouch: 6, lean: 4, hy: 1)),
      const PoseKey(
          1.15, Pose(turn: 1, crouch: 2, fx: -8, fy: -17, bx: 9, by: -17)),
      PoseKey(1.5, _risen.copyWith(y: -2)),
      PoseKey(1.95, _risen.copyWith(y: -3)),
      PoseKey(2.1, _risen.copyWith(y: -2, crouch: 1, fy: -37, by: -37)),
      PoseKey(
          2.3, _risen.copyWith(y: -9, fx: -15, fy: -38, bx: 16, by: -38)),
      PoseKey(2.95, _risen.copyWith(y: -6)),
      const PoseKey(
          3.8, Pose(turn: 1, y: 0, crouch: 2, fx: -8, fy: -17, bx: 9, by: -17)),
      const PoseKey(4.3, kReady),
      const PoseKey(4.8, kReady),
    ],
    dust: const [DustSpec(t: 3.8, x: 0, n: 5)],
  ),
  onCreate: (o) => _ResurrectionSim(o),
);
