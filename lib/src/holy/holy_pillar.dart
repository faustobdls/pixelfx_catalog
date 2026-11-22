import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'holy_lib.dart';

const double _top = -204.0;
const double _py = -1.0;
const double _sun = _top + 38.0;
const double _sy = 0.24;
const double _rx = 26.0;
const double _dmax = _py - _top;

// The sun opens, the fan unfolds and pours down, it holds and pulses, folds shut, the light lifts away.
const double _open = 0.3;
const double _hit = 0.66;
const double _fold = 2.05;
const double _shut = 2.45;
const double _lift = 2.75;

class _Shaft {
  final double th;
  final double spread;
  final double b;
  final double ph;
  final double far;

  const _Shaft(this.th, this.spread, this.b, this.ph, this.far);
}

class _PillarMote {
  final double x;
  final double y;
  final double v;
  final double amp;
  final double f;
  final double ph;

  const _PillarMote(this.x, this.y, this.v, this.amp, this.f, this.ph);
}

class _HolyPillarSim extends BaseEffectSim {
  final List<int> c;
  final int nShafts;
  final Rng r;
  late final List<int> wing;
  late final Particles ps;
  final Lights lights = Lights();
  late final Feathers feathers;
  late final List<_Shaft> shafts;
  late final List<_PillarMote> motes;
  final Float32List row = Float32List(192);
  final Uint8List core = Uint8List(192);
  double t = 0.0;
  bool hit = false;
  bool shut = false;
  bool glinted = false;

  _HolyPillarSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        nShafts = math.max(3, o.intOpt('shafts', 7)),
        r = Rng(o.seed) {
    wing = [c[2], c[3], c[4], c[5], c[6], kWhite];
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [kWhite, c[6], c[5], c[3]],
    );
    feathers = Feathers(r, 0.0);
    final mid = (nShafts - 1) / 2.0;

    shafts = List.generate(nShafts, (i) {
      final off = i - mid;
      final far = off.abs() / mid;
      final th = off * (0.4 / mid) + r.range(-0.02, 0.02);
      final spread = r.range(0.05, 0.085) * (1.0 - far * 0.25);
      final b = (1.0 - far * 0.35) * r.range(0.8, 1.0);
      final ph = r.range(0.0, 1.0);
      return _Shaft(th, spread, b, ph, far);
    }, growable: false);

    motes = List.generate(72, (_) {
      final x = r.range(-80.0, 80.0);
      final y = r.range(0.0, 1.0);
      final v = r.range(7.0, 18.0);
      final amp = r.range(0.5, 2.5);
      final f = r.range(0.6, 1.5);
      final ph = r.range(0.0, tau);
      return _PillarMote(x, y, v, amp, f, ph);
    }, growable: false);

    for (var i = 0; i < 6; i++) {
      final x = r.range(-46.0, 46.0);
      final y = r.range(-150.0, -100.0);
      final vx = r.range(-8.0, 8.0);
      final vy = r.range(0.0, 8.0);
      final a = r.range(-0.4, 0.4);
      final len = r.range(7.0, 9.0);
      final wid = r.range(1.9, 2.3);
      final life = r.range(1.4, 1.7);
      final sink = r.range(26.0, 36.0);
      final delay = _hit + 0.1 + i * 0.16 + r.range(0.0, 0.08);
      feathers.add(
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        a: a,
        len: len,
        wid: wid,
        life: life,
        sink: sink,
        back: i % 3 == 0,
        delay: delay,
      );
    }
  }

  double _angle(_Shaft s, double tt) {
    final st = s.far * 0.1;
    final open = Ease.outBack(seg(tt, _open + st, _open + st + 0.42), 1.5);
    final fold = Ease.inOutCubic(seg(tt, _fold - s.far * 0.1, _shut));
    return s.th * open * (1.0 - fold);
  }

  double _frontD(_Shaft s, double tt) =>
      _dmax * (1.0 - Ease.inQuad(seg(tt, _open + s.far * 0.06, _hit + s.far * 0.06)));

  double _liftD(double tt) => _dmax * Ease.inQuad(seg(tt, _shut + 0.05, _lift));

  double _fade(double tt) =>
      smooth(_open, _open + 0.1, tt) * (1.0 - smooth(_lift - 0.05, _lift + 0.05, tt));

  double _width(_Shaft s, double d, double tt) =>
      (1.4 + d * s.spread) * lerp(1.0, 0.25, smooth(_shut, _lift, tt));

  double _pulse(_Shaft s, double d, double tt) {
    if (tt < _hit || tt > _shut) return 1.0;
    final capD = _dmax * (1.0 - fract((tt - _hit) / 0.6 + s.ph));
    final dist = (d - capD) / 12.0;
    return 1.0 + 0.9 * math.exp(-(dist * dist));
  }

  double _lightAt(double x, double y) {
    final dy = _py - y;
    if (dy <= 0.0) return 0.0;
    var intensity = 0.0;
    final lift = _liftD(t);
    for (final s in shafts) {
      final a = _angle(s, t);
      final ca = math.cos(a);
      final d = dy / ca;
      final xc = math.tan(a) * dy;
      final hw = _width(s, d, t) / 2.0 / ca;
      if (d < lift || d < _frontD(s, t)) continue;
      final v = (x - xc) / hw;
      if (v.abs() < 1.0) intensity += (1.0 - v * v) * s.b;
    }
    return intensity * _fade(t);
  }

  void _fan(Painter p) {
    final k = _fade(t);
    if (k <= 0.0) return;
    final lift = _liftD(t);
    final yStart = _top.ceil();
    final yEnd = _py.toInt();
    for (var y = yStart; y < yEnd; y++) {
      final dy = _py - (y + 0.5);
      row.fillRange(0, row.length, 0.0);
      core.fillRange(0, core.length, 0);
      var any = false;
      for (final s in shafts) {
        final a = _angle(s, t);
        final ca = math.cos(a);
        final d = dy / ca;
        final fd = _frontD(s, t);
        if (d < lift || d < fd - 6.0) continue;
        final xc = math.tan(a) * dy;
        final hw = _width(s, d, t) / 2.0 / ca;
        final soft = smooth(fd - 6.0, fd + 4.0, d) * smooth(lift, lift + 6.0, d);
        final i0 = s.b * _pulse(s, d, t) * soft * k;
        final xMin = (xc - hw).floor();
        final xMax = (xc + hw).ceil();
        for (var x = xMin; x <= xMax; x++) {
          final v = (x + 0.5 - xc) / hw;
          final i = x + 96;
          if (i < 0 || i >= 192 || v.abs() >= 1.0) continue;
          row[i] += i0 * math.pow(1.0 - v * v, 1.3).toDouble();
          any = true;
        }
        final ci = holyRound(xc - 0.5) + 96;
        if (ci >= 0 && ci < 192) {
          core[ci] = math.max(core[ci], math.min(255, (i0 * 200.0).toInt()));
        }
      }
      if (!any) continue;
      for (var i = 0; i < 192; i++) {
        final intensity = row[i];
        if (intensity < 0.02) continue;
        final x = i - 96;
        p.blend(x, y, c[6], math.min(0.6, intensity * 0.38));
        p.light(x, y, c[4], math.min(0.9, intensity * 0.32));
        // A fine bright line runs down the middle of each shaft.
        if (core[i] != 0) {
          p.dot(
            x,
            y,
            core[i] > 150 ? kWhite : c[6],
            math.min(1.0, core[i] / 180.0),
          );
        }
      }
    }
    // Where the shafts converge, the light gathers to a point.
    if (t > _hit - 0.05) p.glow(0, _py - 3.0, 20, c[5], 0.5 * k);
  }

  // The sun: a halo that opens at the top like an iris, rays ticking round it, then closes with a glint.
  void _drawSun(Painter p) {
    final rVal = 15.0 *
        Ease.outBack(seg(t, 0.02, 0.45), 1.8) *
        (1.0 - Ease.inBack(seg(t, _shut, _lift + 0.1), 1.5));
    if (rVal > 0.5) {
      final spin = t * 0.6;
      p.glow(0, _sun, math.min(32.0, rVal * 3.0), c[4], 0.5);
      p.glow(0, _sun, rVal * 1.4, kWhite, 0.35);
      p.circle(0, _sun, rVal * 0.45, kWhite);
      oval(p, 0, _sun, rVal * 0.62, rVal * 0.62, c[6], 1.0);
      ovalShaded(
        p,
        0,
        _sun,
        rVal,
        rVal,
        color: (g) => math.sin(g * 6.0 + spin * 4.0) > 0.5 ? kWhite : c[5],
      );
      for (var j = 0; j < 16; j++) {
        final g = spin + (j * tau) / 16.0;
        final l = j.isOdd ? 3.0 : 6.0;
        p.lineShaded(
          math.cos(g) * (rVal + 2.0),
          _sun + math.sin(g) * (rVal + 2.0),
          math.cos(g) * (rVal + 2.0 + l),
          _sun + math.sin(g) * (rVal + 2.0 + l),
          color: (u) => u < 0.4 ? c[6] : c[4],
          alpha: (u) => 1.1 - u,
        );
      }
    }
    if (t > _lift && t < _lift + 0.3) {
      sparkle(
        p,
        0,
        _sun,
        10.0 * (1.0 - (t - _lift) / 0.3),
        kWhite,
        c[5],
        0.6,
      );
    }
  }

  // The sigil burning on the floor: two rings and a turning band of marks; white-hot, then gold, then cooling.
  void _sigil(Painter p, bool back) {
    if (t < _hit) return;
    final u = seg(t, _hit, _hit + 0.2);
    final heat = 1.0 - smooth(_shut, _shut + 0.8, t);
    final out = 1.0 - smooth(_shut + 0.4, _shut + 1.0, t);
    if (out <= 0.0) return;
    final keep = back ? farHalf : nearHalf;
    bool burnt(double g) =>
        (wrap(g - math.pi / 2.0 + math.pi, tau) - math.pi).abs() <=
        u * math.pi + 0.01;
    final tTick = (t * 20.0).floor();
    int col(double g, bool hot) {
      if (!burnt(g)) return 0;
      final flick = rand(holyRound(g * 40.0), tTick) < 0.18;
      if (t < _hit + 0.08 || (flick && heat > 0.4)) return kWhite;
      if (heat > 0.6) return hot ? c[6] : c[5];
      if (heat > 0.3) return c[4];
      if (heat > 0.1) return c[3];
      return c[2];
    }

    ovalShaded(
      p,
      0,
      0,
      _rx,
      _rx * _sy,
      color: (g) => col(g, true),
      alpha: (_) => out,
      keep: (g) => keep(g) && burnt(g),
    );
    ovalShaded(
      p,
      0,
      0,
      _rx * 0.72,
      _rx * 0.72 * _sy,
      color: (g) => col(g, false),
      alpha: (_) => out,
      keep: (g) => keep(g) && burnt(g),
    );
    // Marks between the rings, turning slowly.
    for (var j = 0; j < 12; j++) {
      final g = t * 0.35 + (j * tau) / 12.0;
      if (!keep(g) || !burnt(g)) continue;
      final colVal = col(g, j.isEven);
      const r0 = _rx * 0.78;
      final r1 = _rx * (j % 3 == 0 ? 0.95 : 0.88);
      if (colVal != 0) {
        p.line(
          math.cos(g) * r0,
          math.sin(g) * r0 * _sy,
          math.cos(g) * r1,
          math.sin(g) * r1 * _sy,
          colVal,
          out,
        );
      }
    }
    if (!back) {
      for (var i = -2; i <= 2; i++) {
        p.glow(
          i * _rx * 0.45,
          -2,
          16,
          c[4],
          (0.34 - i.abs() * 0.05) * out * (0.5 + 0.5 * heat),
        );
      }
      p.glow(0, -1, 10, kWhite, 0.3 * heat * out);
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    // Light gathers to the sun as it opens.
    if (t < _open + 0.1 && r.chance(0.5)) {
      final a = r.range(0.0, tau);
      final d = r.range(22.0, 34.0);
      final x = math.cos(a) * d;
      final y = _sun + math.sin(a) * d;
      final dur = r.range(0.18, 0.28);
      final v = ((d - 10.0) * 3.0) / (math.exp(3.0 * dur) - 1.0);
      final col = r.chance(0.5) ? c[6] : c[5];
      ps.spawn(P.streak, x, y, (-x / d) * v, ((_sun - y) / d) * v, dur, col);
    }
    if (!hit && t >= _hit) {
      hit = true;
      lights.add(0, -30, 64, c[5], 0.85, 0.5);
      lights.add(0, -6, 30, kWhite, 0.8, 0.12);
      for (var i = 0; i < 26; i++) {
        final a = -math.pi / 2.0 + r.range(-1.2, 1.2);
        final sp = r.range(70.0, 190.0);
        final sx = r.range(-3.0, 3.0);
        final life = r.range(0.25, 0.6);
        ps.spawn(
          P.spark,
          sx,
          -2.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          life,
        );
      }
    }
    // While it holds: embers off the burning sigil, a few feathers drifting down through the shafts.
    if (t > _hit && t < _shut + 0.1 && r.chance(0.35)) {
      final g = r.range(0.0, tau);
      final rad = _rx * (r.chance(0.5) ? 1.0 : 0.72);
      final vx = r.range(-6.0, 6.0);
      final vy = -r.range(12.0, 30.0);
      final life = r.range(0.5, 0.8);
      ps.spawn(
        P.ember,
        math.cos(g) * rad,
        math.sin(g) * rad * _sy - 1.0,
        vx,
        vy,
        life,
        c[5],
        1.0,
        0.0,
        math.sin(g) < 0.0 ? PF.back : 0,
      );
    }
    if (t > _hit && t < _fold && r.chance(0.05)) {
      final sx = r.range(-1.0, 1.0) * 40.0;
      final sy = -r.range(20.0, 160.0);
      final vy = r.range(2.0, 8.0);
      final life = r.range(0.3, 0.6);
      final col = r.chance(0.5) ? kWhite : c[6];
      final size = r.range(0.8, 1.8);
      ps.spawn(P.star, sx, sy, 0.0, vy, life, col, size);
    }
    // The fan snaps shut on the mark: a flash where the shafts become one.
    if (!shut && t >= _shut) {
      shut = true;
      lights.add(0, -60, 70, c[5], 0.7, 0.35);
      for (var i = 0; i < 12; i++) {
        final sx = r.range(-4.0, 4.0);
        final sy = -r.range(10.0, 170.0);
        final vx = r.range(-25.0, 25.0);
        final vy = r.range(-10.0, 10.0);
        final life = r.range(0.4, 0.8);
        final col = r.chance(0.5) ? kWhite : c[6];
        final size = r.range(0.8, 2.0);
        ps.spawn(P.star, sx, sy, vx, vy, life, col, size);
      }
    }
    if (!glinted && t >= _lift) {
      glinted = true;
      lights.add(0, _sun, 40, kWhite, 0.6, 0.2);
    }
    ps.update(dt);
    feathers.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    _fan(p);
    _sigil(p, true);
    feathers.draw(p, wing, 'back');
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    _sigil(p, false);
    // Dust motes drifting down, lit only where a shaft catches them.
    for (final m in motes) {
      final y = _top + wrap(m.y * _dmax + t * m.v, _dmax);
      final x = m.x + math.sin(t * m.f + m.ph) * m.amp;
      final intensity = _lightAt(x, y);
      if (intensity < 0.2) continue;
      p.dot(
        x,
        y,
        intensity > 0.7 ? kWhite : c[6],
        math.min(1.0, intensity * 1.3),
      );
      p.light(x, y, c[5], 0.4 * math.min(1.0, intensity));
    }
    _drawSun(p);
    if (t > _hit - 0.02 && t < _hit + 0.25) {
      sparkle(
        p,
        0,
        _py - 2.0,
        12.0 * (1.0 - (t - _hit) / 0.25),
        kWhite,
        c[5],
        0.7,
      );
    }
    if (t > _shut && t < _shut + 0.2) {
      sparkle(
        p,
        0,
        _py - 2.0,
        8.0 * (1.0 - (t - _shut) / 0.2),
        kWhite,
        c[5],
        0.5,
      );
    }
    feathers.draw(p, wing, 'front');
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect holyPillarEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'holy/holy-pillar',
    name: 'Holy pillar',
    desc:
        'Light breaks through from above: a sun opens at the top and a fan of shafts converges on the mark, pulsing, while a sigil burns on the floor; then the fan folds shut.',
    category: 'holy',
    tags: ['holy', 'pillar', 'light', 'rays', 'aoe', 'sigil', 'ground', 'one-shot'],
    size: (192, 232),
    origin: (96, 204),
    duration: 3.5,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {'palette': kHolyGold, 'shafts': 7, 'seed': 3},
  ),
  onCreate: (o) => _HolyPillarSim(o),
);
