// The layered flame tongues and the licks, embers and smoke shed off a burning edge follow Sprite Fusion's
// open-source fire (https://www.spritefusion.com/pixel-art-vfx/fire), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'transitions_lib.dart';

const double _duration = 3.0;
const double _close = 1.18;
const double _cover = 1.35;
const double _smoulder = 1.5;
const double _pop = 1.8;
const double _open = 2.62;
const double _sc = 90.0;
const double _halo = 24.0;
const double _pool = 48.0;

const List<String> _ashHex = ['#a39cab', '#7b7484', '#5c5664', '#433e4b'];
const List<(double, double, int)> _layers = [
  (1.0, 1.0, 2),
  (0.76, 0.86, 4),
  (0.54, 0.68, 6),
  (0.3, 0.42, 8),
];

const List<double> _rateIn = [0.006, 0.0014, 0.0006, 0.0024, 0.0012, 0.0004];
const List<double> _rateOut = [0.006, 0.0005, 0.0004, 0.0012, 0.0004, 0.0004];

ScalarField _inField(int seed) {
  return screenField((x, y) {
    final ux = (x - kScreenW / 2.0) / (kScreenW / 2.0);
    final uy = (y - kScreenH / 2.0) / (kScreenH / 2.0);
    final ux2 = ux * ux;
    final uy2 = uy * uy;
    final m = math.pow(ux2 * ux2 + uy2 * uy2, 0.25);
    return (1.0 - m) * _sc +
        14.0 * fbm(x / 44.0, y / 44.0, seed, 3) +
        2.4 * fbm(x / 7.0, y / 7.0, seed + 9, 2) +
        7.0 * (0.5 - y / kScreenH);
  });
}

({ScalarField field, double ox, double oy}) _outField(int seed) {
  final r = Rng(seed * 31 + 5);
  final ox = kScreenW / 2.0 + r.range(-26.0, 26.0);
  final oy = kScreenH / 2.0 + r.range(-14.0, 6.0);
  final sats = [-1, 1]
      .map(
        (s) => (
          x: ox + s * r.range(70.0, 110.0),
          y: oy + r.range(-40.0, 40.0),
          d: r.range(30.0, 44.0),
        ),
      )
      .toList();
  final f = screenField((x, y) {
    var v = hypot((x - ox) / (kScreenW / 2.0), (y - oy) / (kScreenH / 2.0)) * _sc;
    for (final s in sats) {
      final sv = s.d +
          hypot((x - s.x) / (kScreenW / 2.0), (y - s.y) / (kScreenH / 2.0)) *
              _sc *
              1.15;
      if (sv < v) v = sv;
    }
    return v +
        13.0 * fbm(x / 40.0, y / 40.0, seed + 21, 3) +
        2.4 * fbm(x / 7.0, y / 7.0, seed + 33, 2);
  });
  return (field: f, ox: ox, oy: oy);
}

void _tongue(
  Painter p,
  List<int> f,
  double x,
  double y,
  double h,
  double w,
  double sway,
  double t,
  int n,
) {
  for (final (lw, lh, ri) in _layers) {
    final ht = h * lh;
    final col = f[ri];
    for (var row = 0; row <= ht; row++) {
      final u = row / math.max(1.0, ht);
      final half = w *
              lw *
              math.pow(1.0 - u, 0.85) *
              math.min(1.0, (row + 1.5) / 3.5) +
          noise(t * 9.0 + row * 0.45, n) * 0.5;
      if (half < 0.3) continue;
      final cx =
          x + sway * u * u * lh + noise(t * 4.0 + row * 0.2, n + 7) * u * 1.1;
      final px0 = ((cx - half) + 0.5).floor();
      final px1 = ((cx + half) + 0.5).floor();
      final py = ((y - row) + 0.5).floor();
      for (var px = px0; px <= px1; px++) {
        p.px(px.toDouble(), py.toDouble(), col);
      }
    }
  }
}

class _BurnAwaySim extends BaseEffectSim {
  final List<int> f;
  final int ink;
  final Rng r;
  final int seed;
  final int charCol;
  final int scorchCol;
  final int warmCol;
  final int smokeCol;
  final int litSmokeCol;
  final int dimSmokeCol;
  final int smokeMidCol;
  final ScalarField fieldA;
  final ScalarField fieldB;
  final double boxOx;
  final double boxOy;
  final Float32List heat;
  final Uint8List ph;
  final Float32List fleck;
  final Float32List jit;
  final Float32List vein;
  final Float32List fl = Float32List(64);
  final Float32List hvArr = Float32List(64);
  final Uint8List tw = Uint8List(64);
  final Particles ps;
  final Particles ash;
  final Lights lights = Lights();
  final List<int> line = [];
  double t = 0.0;
  int pin = 0;
  int pout = 0;
  bool closed = false;
  bool popped = false;

  factory _BurnAwaySim.create(Map<String, Object?> o) {
    final f = fit(o.palette, 9);
    final ink = hex(o['color'] ?? '#0b0a10');
    final r = Rng(o.seed);
    final seed = o.seed * 13;
    final charCol = mix(ink, f[0], 0.45);
    final scorchCol = mix(ink, hex('#3a2216'), 0.6);
    final warmCol = mix(f[4], f[5], 0.4);
    final smokeCol = mix(hex('#8a7276'), f[2], 0.2);
    final litSmokeCol = mix(hex('#8a7276'), f[3], 0.25);
    final dimSmokeCol = kSmokeRamp[3];
    final smokeMidCol = kSmokeRamp[2];
    final fieldA = _inField(seed);
    final out = _outField(seed + 1);
    const total = kScreenW * kScreenH;
    final heat = Float32List(total);
    final ph = Uint8List(total);
    final fleck = Float32List(total);
    final jit = Float32List(total);
    final vein = Float32List(total);
    for (var i = 0; i < total; i++) {
      final x = i % kScreenW;
      final y = i ~/ kScreenW;
      heat[i] = 0.5 + 0.5 * noise2(x / 13.0, y / 13.0, seed + 41);
      ph[i] = math.min(
        63,
        ((0.5 + 0.5 * noise2(x / 23.0, y / 23.0, seed + 43)) * 64.0).floor(),
      );
      fleck[i] =
          rand(x, y, seed + 45) < 0.04 ? 9.0 + 22.0 * rand(x, y, seed + 47) : 0.0;
      jit[i] = (rand(x, y, seed + 49) - 0.5) * 1.5;
      final rx = x * 0.8 + y * 0.6;
      final ry = y * 0.8 - x * 0.6;
      vein[i] = math.min(
        noise2(rx / 11.0, ry / 9.0, seed + 61).abs(),
        noise2(ry / 5.5, rx / 5.0, seed + 63).abs() * 1.5,
      );
    }
    final ps = Particles(rng: r, sparks: [f[7], f[6], f[4], f[2]]);
    final ash = Particles(rng: r, sparks: [for (final s in _ashHex) hex(s)]);
    return _BurnAwaySim._(
      f: f,
      ink: ink,
      r: r,
      seed: seed,
      charCol: charCol,
      scorchCol: scorchCol,
      warmCol: warmCol,
      smokeCol: smokeCol,
      litSmokeCol: litSmokeCol,
      dimSmokeCol: dimSmokeCol,
      smokeMidCol: smokeMidCol,
      fieldA: fieldA,
      fieldB: out.field,
      boxOx: out.ox,
      boxOy: out.oy,
      heat: heat,
      ph: ph,
      fleck: fleck,
      jit: jit,
      vein: vein,
      ps: ps,
      ash: ash,
    );
  }

  _BurnAwaySim._({
    required this.f,
    required this.ink,
    required this.r,
    required this.seed,
    required this.charCol,
    required this.scorchCol,
    required this.warmCol,
    required this.smokeCol,
    required this.litSmokeCol,
    required this.dimSmokeCol,
    required this.smokeMidCol,
    required this.fieldA,
    required this.fieldB,
    required this.boxOx,
    required this.boxOy,
    required this.heat,
    required this.ph,
    required this.fleck,
    required this.jit,
    required this.vein,
    required this.ps,
    required this.ash,
  });

  double _kIn(double t) =>
      fieldA.lo -
      8.0 +
      (fieldA.hi - fieldA.lo + 8.0) * math.pow(math.max(0.0, t) / _close, 1.25);

  double _kOut(double t) => t < _pop
      ? fieldB.lo -
          24.0 +
          24.0 * Ease.inQuad(clamp((t - _smoulder) / (_pop - _smoulder)))
      : fieldB.lo +
          (fieldB.hi - fieldB.lo + 16.0) *
              Ease.outQuad(clamp((t - _pop) / (_open - _pop)));

  void _shed(int i, bool inA) {
    final rates = inA ? _rateIn : _rateOut;
    final flRate = rates[0];
    final emRate = rates[1];
    final smRate = rates[2];
    final shRate = rates[3];
    final asRate = rates[4];
    final liRate = rates[5];
    final x = (i % kScreenW) + 0.5;
    final y = (i ~/ kScreenW) + 0.5;
    final end = inA ? _pop + 0.1 : _duration - 0.05;
    var rv = r.next();
    if ((rv -= flRate) < 0.0) {
      final life = lifeLeft(r.range(0.18, 0.4), t, end);
      if (life > 0.08) {
        ps.spawn(
          P.fire,
          x,
          y - 3.0,
          r.range(-8.0, 8.0),
          -r.range(25.0, 50.0),
          life,
          0,
          r.range(0.8, 1.7),
        );
      }
    } else if ((rv -= emRate) < 0.0) {
      final life = lifeLeft(
        inA ? r.range(0.6, 1.3) : r.range(0.5, 1.0),
        t,
        end,
      );
      if (life > 0.2) {
        ps.spawn(
          P.ember,
          x,
          y - 2.0,
          r.range(-30.0, 30.0),
          -r.range(40.0, 100.0),
          life,
          0,
          r.chance(0.25) ? 2.0 : 1.0,
        );
      }
    } else if ((rv -= smRate + shRate * heat[i] * heat[i]) < 0.0) {
      final n = r.intRange(4, 6);
      final vx = r.range(-6.0, 6.0);
      final up = (inA ? fieldA : fieldB).ny[i] < -0.25;
      for (var j = 0; j < n; j++) {
        final life = lifeLeft(
          up ? r.range(0.8, 1.3) : r.range(0.35, 0.65),
          t + j * 0.05,
          end,
        );
        if (life > 0.4) {
          ps.spawn(
            P.smoke,
            x + r.range(-3.5, 3.5),
            y - 4.0 - j * 1.2,
            vx + r.range(-3.0, 3.0),
            -r.range(18.0, 34.0),
            life,
            smokeCol,
            r.range(2.8, 4.8),
            j * 0.05,
          );
        }
      }
    } else if ((rv -= asRate) < 0.0) {
      final life = lifeLeft(r.range(0.9, 1.6), t, end);
      if (life > 0.3) {
        ash.spawn(
          P.ember,
          x,
          y - 2.0,
          r.range(-18.0, 18.0),
          -r.range(25.0, 60.0),
          life,
        );
      }
    } else if ((rv -= liRate) < 0.0) {
      lights.add(
        x,
        y - 4.0,
        r.range(20.0, 32.0),
        warmCol,
        r.range(0.14, 0.26),
        r.range(0.18, 0.4),
      );
    }
  }

  void _drawSmoke(Painter p, Painter p0) {
    final inPhase = t < _cover;
    final open = t >= _smoulder && t < _open + 0.25;
    final k = inPhase ? _kIn(t) : _kOut(t);
    final fv = inPhase ? fieldA.f : fieldB.f;
    for (final q in ps.list) {
      if (q.k != P.smoke || q.delay > 0.0) continue;
      final kk = q.life / q.max;
      final age = 1.0 - kk;
      final rad =
          q.size * (0.65 + math.min(1.0, age * 2.5) * 0.45 + age * 0.4);
      final idx = clampInt(q.y.floor(), 0, kScreenH - 1) * kScreenW +
          clampInt(q.x.floor(), 0, kScreenW - 1);
      final e =
          inPhase || open ? (inPhase ? k - fv[idx] : fv[idx] - k) : 99.0;
      final lit = clamp(1.0 - e.abs() / 30.0);
      final a = math.min(1.0, age * 12.0) *
          math.min(1.0, kk * 2.4) *
          0.58 *
          (e > 0.0 ? 0.05 + 0.95 * lit : (inPhase ? 1.0 : 0.2 + 0.8 * lit));
      if (a < 0.04) continue;
      final col = mix(mix(dimSmokeCol, litSmokeCol, lit), smokeMidCol, age * 0.5);
      final d = q.x - rad > 0.0 &&
              q.y - rad > 0.0 &&
              q.x + rad < kScreenW - 1 &&
              q.y + rad < kScreenH - 1
          ? p0
          : p;
      d.disc(q.x, q.y, rad, col, a * 0.45);
      d.disc(q.x + rad * 0.05, q.y + rad * 0.06, rad * 0.74, col, a * 0.62);
      if (age < 0.5) {
        d.disc(
          q.x - rad * 0.22,
          q.y - rad * 0.3,
          rad * 0.5,
          mix(col, kWhite, 0.15),
          a * 0.4 * (1.0 - age * 2.0),
        );
      }
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t < _cover) {
      final k = _kIn(t);
      while (pin < fieldA.order.length && fieldA.f[fieldA.order[pin]] <= k) {
        _shed(fieldA.order[pin++], true);
      }
      if (!closed && t >= _close) {
        closed = true;
        final i = fieldA.order[fieldA.order.length - 1];
        final x = (i % kScreenW).toDouble();
        final y = (i ~/ kScreenW).toDouble();
        lights.add(x, y, 64.0, warmCol, 0.5, 0.4);
        for (var j = 0; j < 12; j++) {
          ps.spawn(
            P.ember,
            x + r.range(-6.0, 6.0),
            y + r.range(-3.0, 3.0),
            r.range(-50.0, 50.0),
            -r.range(40.0, 120.0),
            r.range(0.5, 0.75),
            0,
            r.chance(0.3) ? 2.0 : 1.0,
          );
        }
        for (var j = 0; j < 5; j++) {
          ps.spawn(
            P.smoke,
            x + r.range(-8.0, 8.0),
            y + r.range(-4.0, 2.0),
            r.range(-10.0, 10.0),
            -r.range(12.0, 28.0),
            r.range(1.1, 1.6),
            smokeCol,
            r.range(3.5, 5.5),
            r.range(0.0, 0.15),
          );
        }
      }
    }

    if (t >= _smoulder && t < _pop && r.chance(0.1)) {
      final i = fieldB.order[r.intRange(0, 400)];
      final x = (i % kScreenW) + 0.5;
      final y = (i ~/ kScreenW) + 0.5;
      if (r.chance(0.6)) {
        ps.spawn(
          P.smoke,
          x,
          y,
          r.range(-4.0, 4.0),
          -r.range(8.0, 16.0),
          lifeLeft(r.range(0.9, 1.4), t, _duration - 0.05),
          smokeCol,
          r.range(2.0, 3.5),
        );
      } else {
        ps.spawn(
          P.ember,
          x,
          y,
          r.range(-12.0, 12.0),
          -r.range(15.0, 40.0),
          r.range(0.4, 0.8),
        );
      }
    }

    if (!popped && t >= _pop) {
      popped = true;
      lights.add(boxOx, boxOy, 90.0, warmCol, 0.6, 0.45);
      lights.add(boxOx, boxOy, 34.0, f[7], 0.7, 0.12);
      for (var j = 0; j < 12; j++) {
        final a = r.range(0.0, tau);
        final sp = r.range(50.0, 150.0);
        ps.spawn(
          P.ember,
          boxOx + math.cos(a) * 3.0,
          boxOy + math.sin(a) * 2.0,
          math.cos(a) * sp,
          math.sin(a) * sp * 0.7 - 40.0,
          r.range(0.4, 0.9),
          0,
          r.chance(0.3) ? 2.0 : 1.0,
        );
      }
      for (var j = 0; j < 10; j++) {
        final a = r.range(0.0, tau);
        final sp = r.range(120.0, 260.0);
        ps.spawn(
          P.spark,
          boxOx,
          boxOy,
          math.cos(a) * sp,
          math.sin(a) * sp - 50.0,
          r.range(0.15, 0.35),
        );
      }
    }

    if (t >= _pop && t < _open + 0.2) {
      final k = _kOut(t);
      while (pout < fieldB.order.length && fieldB.f[fieldB.order[pout]] <= k) {
        _shed(fieldB.order[pout++], false);
      }
    }

    ps.update(dt);
    ash.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p0) {
    final p = clipTo(p0);
    line.clear();
    if (t >= _cover && t < _smoulder) {
      fastRect(p0, 0.0, 0.0, kScreenW.toDouble(), kScreenH.toDouble(), ink);
    } else if (t < _open + 0.25) {
      final inPhase = t < _cover;
      final k = inPhase ? _kIn(t) : _kOut(t);
      final fd = inPhase ? fieldA : fieldB;
      final fv = fd.f;
      final gv = fd.g;
      final fade = inPhase ? 1.0 - smooth(_cover - 0.15, _cover, t) : 1.0;
      for (var j = 0; j < 64; j++) {
        final q = j / 63.0;
        fl[j] = 0.75 + 0.25 * math.sin(t * 7.0 + q * 9.0);
        hvArr[j] = 0.3 * math.sin(t * 5.5 + q * 11.0);
        tw[j] = math.sin(t * 13.0 + q * 40.0) > -0.5 ? 1 : 0;
      }
      final px = screenPixels(p0);
      final ord = fd.order;
      final totalN = ord.length;
      final su = clamp((t - _smoulder) / (_pop - _smoulder));
      final sr = 5.0 + 17.0 * su;
      final sk = inPhase || t < _smoulder
          ? 0.0
          : (t < _pop ? 0.3 + 0.7 * su : 1.0 - (t - _pop) / 0.3);

      void shadeAt(int i) {
        final e = inPhase ? k - fv[i] : fv[i] - k;
        final s = e * gv[i];
        px.at(i);
        if (e < 0.0) {
          if (inPhase && s > -2.5) px.blend(scorchCol, 0.5 * (1.0 + s / 2.5));
          final u = math.max(0.0, 1.0 + e / _halo);
          final v = 1.0 + e / _pool;
          px.add(warmCol, (0.3 * u * u + 0.12 * v * v) * fl[ph[i]]);
          return;
        }
        final hv = clamp(heat[i] + hvArr[ph[i]]);
        final th = 0.6 + 0.6 * hv;
        final u = s / th;
        if (u < 6.4) {
          if (u < 0.9) line.add(i);
          px.put(
            u < 0.9
                ? (hv > 0.6 ? f[8] : f[7])
                : (u < 1.7
                    ? f[6]
                    : (u < 2.4
                        ? f[5]
                        : (u < 3.1
                            ? f[4]
                            : (u < 3.8
                                ? f[3]
                                : (u < 4.6
                                    ? f[2]
                                    : (u < 5.5 ? f[1] : f[0])))))),
          );
          if (u < 4.6) {
            px.add(warmCol, 0.45 * (1.0 - u / 4.6) * (0.7 + 0.3 * hv));
          }
          return;
        }
        if (sk > 0.0 && fv[i] < fieldB.lo + sr) {
          final hm =
              (1.0 - (fv[i] - fieldB.lo) / sr) * sk * (0.7 + 0.6 * hv);
          if (vein[i] < 0.04 + 0.08 * hm) {
            px.put(
              hm > 0.95
                  ? f[6]
                  : (hm > 0.75
                      ? f[5]
                      : (hm > 0.55
                          ? f[4]
                          : (hm > 0.38 ? f[3] : (hm > 0.22 ? f[2] : f[1])))),
            );
            px.add(warmCol, 0.4 * hm);
            return;
          }
          px.add(warmCol, 0.2 * hm * hm);
        }
        final len = fleck[i] * (0.8 + 0.4 * hv);
        if (len > 0.0 && s < len) {
          final v = (s - 6.4 * th) / math.max(1.0, len - 6.4 * th);
          if (v < 1.0 &&
              tw[(ph[i] * 5) & 63] != 0 &&
              !(fade < 1.0 && fade <= jit[i] / 1.5 + 0.5)) {
            px.put(v < 0.3 ? f[4] : (v < 0.55 ? f[3] : (v < 0.8 ? f[2] : f[1])));
            px.add(warmCol, 0.3 * (1.0 - v));
            return;
          }
        }
        if (e < 22.0) {
          final ee = 1.0 - e / 22.0;
          px.add(warmCol, 0.2 * ee * ee);
        }
        px.put(u - 6.4 < 1.6 * th + jit[i] ? charCol : ink);
      }

      final lo = fd.below(k - (inPhase ? 33.0 : _pool));
      final hi = fd.below(
        math.max(k + (inPhase ? _pool : 33.0), sk > 0.0 ? fieldB.lo + sr : -1e9),
      );
      final c0 = inPhase ? 0 : hi;
      final c1 = inPhase ? lo : totalN;
      final a0 = lo;
      final a1 = hi;
      for (var j = c0; j < c1; j++) {
        final i = ord[j];
        if (fleck[i] != 0.0) {
          shadeAt(i);
        } else {
          px.at(i);
          px.put(ink);
        }
      }
      for (var j = a0; j < a1; j++) {
        shadeAt(ord[j]);
      }

      for (final i in line) {
        final x = i % kScreenW;
        final y = i ~/ kScreenW;
        final dn = inPhase ? -fd.ny[i] : fd.ny[i];
        final h0 = rand(x, y >> 3, seed + 51);
        if (h0 > 0.12 + 0.6 * math.max(0.0, dn)) continue;
        final n = (x * 7 + (y >> 4) * 131) % 977;
        final hv = heat[i];
        final leap =
            1.0 + math.max(0.0, noise(t * 2.6 + n * 3.1, n + 70) - 0.5) * 1.8;
        final h = (5.0 + 7.0 * rand(x, 1, seed + 53)) *
            (0.6 + 0.4 * noise(t * 3.3 + n * 1.7, n)) *
            (0.6 + 0.6 * hv) *
            leap *
            fade *
            (dn > 0.0 ? 0.65 + 0.5 * dn : 0.5);
        if (h >= 1.5) {
          _tongue(
            p,
            f,
            x + 0.5,
            y + 1.0,
            h,
            (1.1 + 0.7 * hv) * (0.8 + h / 16.0),
            noise(t * 2.2 + n, n + 40) * 1.5,
            t,
            n,
          );
        }
      }
    }
    _drawSmoke(p, p0);
    ash.draw(p, 'front');
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect burnAwayEffect = SimulatedEffect(
  meta: screenMeta(
    id: 'transitions/burn-away',
    name: 'Burn away',
    desc:
        'The screen burns in from its edges behind a ragged ember line of licking flames, embers and smoke; then the black smoulders and burns open from the middle.',
    tags: const ['burn', 'fire', 'embers', 'smoke', 'wipe'],
    duration: _duration,
    options: const {
      'palette': [
        '#4a1712',
        '#8a1f17',
        '#c9281f',
        '#f2561d',
        '#ff8a2a',
        '#ffc23d',
        '#ffe26b',
        '#fff3a6',
        '#ffffff',
      ],
      'seed': 3,
    },
  ),
  onCreate: _BurnAwaySim.create,
);
