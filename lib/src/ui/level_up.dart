// The pillar's strands of light and the rings climbing it adapt Sprite Fusion's open-source holy light
// (https://www.spritefusion.com/pixel-art-vfx/holy-light), and the streaks rushing in its power-up
// (https://www.spritefusion.com/pixel-art-vfx/power-up), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'ui_lib.dart';

const double _duration = 3.2;
const double _rel = 0.28;
const double _ret = 1.02;
const double _gone = 1.34;
const double _top = 100.0;
const double _ty = -68.0;
const double _drop = 0.5;
const double _stag = 0.05;
const double _landed = 1.06;
const double _shine = 1.24;
const double _exit = 2.3;

const Pose _coil = Pose(
  turn: 0.9,
  crouch: 7,
  lean: 2,
  fx: -6,
  fy: -13,
  bx: 7,
  by: -13,
  ffx: -5,
  fbx: 6,
);

const Pose _leap = Pose(
  turn: 1.1,
  y: -16,
  crouch: -1,
  fx: -6,
  fy: -45,
  bx: 7,
  by: -44,
  ffx: -2,
  ffy: -8,
  fbx: 5,
  fby: -3,
  toeB: true,
);

const Pose _pump = Pose(
  turn: 0.9,
  crouch: 0,
  fx: -6,
  fy: -45,
  bx: 9,
  by: -15,
  ffx: -3,
  fbx: 4,
);

class _Strand {
  final double x;
  final double sp;
  final double per;
  final double duty;
  final double ph;
  final int lvl;
  final double end;

  _Strand({
    required this.x,
    required this.sp,
    required this.per,
    required this.duty,
    required this.ph,
    required this.lvl,
    required this.end,
  });
}

final List<_Strand> _strands = List<_Strand>.generate(
  9,
  (i) => _Strand(
    x: (i / 8.0 - 0.5) * 1.5 + (rand(i, 1) - 0.5) * 0.16,
    sp: 170.0 + rand(i, 2) * 170.0,
    per: 10.0 + rand(i, 3) * 16.0,
    duty: 0.3 + rand(i, 4) * 0.35,
    ph: rand(i, 5),
    lvl: rand(i, 6) < 0.35 ? 1 : 2,
    end: 0.5 + rand(i, 7) * 0.42,
  ),
);

double _widthAt(double t) => t < _rel
    ? 0.0
    : 12.0 *
        (1.0 + 0.4 * math.exp(-(t - _rel) * 10.0)) *
        (1.0 - 0.82 * smooth(_ret - 0.12, _ret + 0.16, t));

void _column(Painter p, List<int> c, double t) {
  final a = t - _rel;
  if (a < 0.0 || t > _gone) return;
  final top = -_top * Ease.outExpo(clamp(a / 0.12));
  final bot = -_top * Ease.inCubic(seg(t, _ret, _gone));
  final w = _widthAt(t);
  final k = 1.0 - smooth(_ret, _gone, t);
  p.glowLine(0, top, 0, math.min(bot, -34.0), w * 1.6 + 6.0, c[5], 0.2 * k + 0.06);
  p.glowLine(0, top, 0, math.min(bot, -40.0), 5.0, kWhite, 0.18 * k);
  if (a < 0.04) {
    for (var y = top.floor(); y < bot; y++) {
      final wr = w * 0.55 * (1.0 - 0.3 * (-y / _top));
      final xEnd = wr.ceil();
      for (var x = (-wr).floor(); x <= xEnd; x++) {
        p.dot(
          x,
          y,
          (x + 0.5).abs() < wr - 1.5 ? kWhite : c[6],
          clamp((y + _top) / 20.0) * 1.5,
        );
      }
    }
    return;
  }
  final yEnd = bot.ceil();
  for (var y = top.ceil(); y < yEnd; y++) {
    final h = -y / _top;
    final fade =
        clamp((y + _top) / 16.0) * (t < _ret ? 1.0 : clamp((bot - y) / 10.0));
    final head = y - top < 3.0 && a < 0.16;
    final wr = w * (1.0 - 0.3 * h) + 0.9 * noise2(y * 0.2, t * 12.0, 3);
    for (final s in const [-1, 1]) {
      final run = fract(y * 0.06 + t * 3.4 + (s > 0 ? 0.5 : 0.0)) < 0.78;
      final xw = s * wr;
      p.dot(xw, y, head ? kWhite : (run ? c[6] : c[5]), fade * 1.4);
      p.dot(xw + s, y, c[4], fade * (run ? 0.5 : 0.25));
      if (run) p.dot(xw - s, y, c[5], fade * 1.2);
    }
    p.dot(0, y, kWhite, fade * 1.6);
    p.dot(-1, y, noise2(y * 0.3, t * 14.0, 5) > -0.2 ? kWhite : c[6], fade * 1.3);
    if (noise2(y * 0.25, t * 9.0, 8) > 0.25) p.dot(1, y, c[6], fade * 1.2);
    for (final st in _strands) {
      if (h > st.end) continue;
      final ph = fract((y + t * st.sp) / st.per + st.ph);
      if (ph > st.duty) continue;
      final u = ph / st.duty;
      p.px(
        st.x * wr,
        y,
        head || u < 0.2
            ? kWhite
            : (u < 0.65 ? c[7 - st.lvl] : c[6 - st.lvl]),
      );
    }
  }
}

void _plate(Painter p, List<int> c, double t, double k) {
  if (k <= 0.02) return;
  final rx = 9.0 + 9.0 * k + math.sin(t * 9.0);
  const ry = 2.2;
  p.shade(-rx, -ry, rx, ry, (x, y, out) {
    final dx = x / rx;
    final dy = y / ry;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d > 1.0) return null;
    final u = d / math.max(0.05, k);
    out.a = d < 0.6 * k ? 1.0 : k * (1.0 - d) * 2.2;
    return u < 0.3 ? kWhite : (u < 0.55 ? c[6] : (u < 0.8 ? c[5] : c[4]));
  });
  p.glow(0, -1, rx * 2.2, c[4], 0.35 * k);
}

void _rays(Painter p, List<int> c, double t, double k, double cx, double cy) {
  if (k <= 0.02) return;
  for (var i = 0; i < 20; i++) {
    final an = (i / 20.0) * tau + 0.08;
    final ca = math.cos(an);
    final sa = math.sin(an);
    final isLong = i % 2 == 0;
    if (sa.abs() < 0.4) continue;
    final r0 = 1.0 / math.sqrt(math.pow(ca / 52.0, 2) + math.pow(sa / 12.0, 2)) +
        2.0 * k;
    final len = (isLong ? 15.0 + 7.0 * rand(i, 9) : 7.0 + 4.0 * rand(i, 8)) * k;
    if (len < 1.0) continue;
    final sh = 0.75 + 0.25 * math.sin(t * 7.0 + i * 2.1);
    final x0 = cx + ca * r0;
    final y0 = cy + sa * r0;
    p.lineShaded(
      x0,
      y0,
      x0 + ca * len,
      y0 + sa * len,
      color: (u) => u < 0.3 ? c[7] : (u < 0.6 ? c[6] : c[5]),
      alpha: (u) => sh * (u < 0.55 ? 1.3 : (1.3 * (1.0 - u)) / 0.45),
    );
  }
}

class _DropLetter {
  final PixelGlyph g;
  final int w;
  final double cx;
  final double born;
  final double pop;
  double off = -18.0;
  double v = 60.0;
  double sq = 0.0;
  double flash = 0.0;
  bool on = false;
  bool landed = false;
  bool rest = false;
  bool burst = false;

  _DropLetter({
    required this.g,
    required this.w,
    required this.cx,
    required this.born,
    required this.pop,
  });
}

class _SatSparkle {
  final double x;
  final double y;
  final double t0;
  final double dur;
  final double l;

  _SatSparkle({
    required this.x,
    required this.y,
    required this.t0,
    required this.dur,
    required this.l,
  });
}

class _RushStreak {
  double x;
  double y;
  final double vx;
  final double vy;
  double life;
  final double len;
  final int c;
  final bool back;

  _RushStreak({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.len,
    required this.c,
    required this.back,
  });
}

class _LevelUpSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final ActorDefinition? actor;
  final int shadowCol;
  final Particles ps;
  final Lights lights = Lights();
  late final double x0;
  late final double base;
  late final double right;
  late final List<_DropLetter> lets;
  late final List<_SatSparkle> sats;
  final List<double> halos = [];
  final List<_RushStreak> rush = [];

  double t = 0.0;
  bool released = false;
  double nextHalo = _rel + 0.03;
  double gather = 0.0;

  _LevelUpSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed),
        actor = o.actor,
        shadowCol = scaleColor(fit(o.palette, 8)[0], 0.5),
        ps = Particles(
          rng: Rng(o.seed),
          ground: (_) => 0.0,
          sparks: [
            fit(o.palette, 8)[7],
            fit(o.palette, 8)[6],
            fit(o.palette, 8)[5],
            fit(o.palette, 8)[3],
          ],
        ) {
    // Advance ps's rng? Notice in JS ps gets the SAME Rng instance `R`, not a copy!
    // Replace ps so ps.r === r:
    psReplaced = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [c[7], c[6], c[5], c[3]],
    );
    final word = spell(o.strOpt('text', 'LEVEL UP!'));
    base = _ty + 14.0;
    x0 = -word.w.toDouble();
    right = x0 + word.w * 2.0;
    lets = <_DropLetter>[];
    var idx = 0;
    for (final l in word.letters) {
      if (l.g == null) continue;
      lets.add(_DropLetter(
        g: l.g!,
        w: l.w,
        cx: x0 + (l.x + l.w / 2.0) * 2.0,
        born: _drop + idx * _stag,
        pop: _exit + idx * 0.04,
      ));
      idx++;
    }
    sats = List<_SatSparkle>.generate(8, (i) {
      final s = i % 2 != 0 ? 1 : -1;
      final x = s * r.range(20.0, 60.0);
      final y = _ty +
          7.0 +
          (x.abs() < 50.0 ? r.sign() * r.range(11.0, 18.0) : r.range(-14.0, 14.0));
      return _SatSparkle(
        x: x,
        y: y,
        t0: _shine - 0.1 + i * 0.13 + r.range(0.0, 0.05),
        dur: r.range(0.32, 0.5),
        l: r.range(3.0, 6.0),
      );
    });
  }

  late final Particles psReplaced;

  void _spawn(
    ParticleKind k,
    double x,
    double y,
    double vx,
    double vy,
    double life, [
    Object? col,
    double size = 1.0,
    double delay = 0.0,
    int flag = 0,
  ]) {
    psReplaced.spawn(
      k,
      x,
      y,
      vx,
      vy,
      math.min(life, _duration - 0.05 - t),
      col,
      size,
      delay,
      flag,
    );
  }

  void _drawRush(Painter p, bool back) {
    for (final m in rush) {
      if (m.back != back) continue;
      final sp = hypot(m.vx, m.vy);
      final ux = m.vx / sp;
      final uy = m.vy / sp;
      final len = m.len;
      p.line(m.x - ux * len, m.y - uy * len, m.x - ux * len * 0.4,
          m.y - uy * len * 0.4, m.c);
      p.line(m.x - ux * len * 0.35, m.y - uy * len * 0.35, m.x, m.y, kWhite);
      p.glow(m.x, m.y, 4, c[5], 0.25);
    }
  }

  @override
  void update(double dt, Map<String, Object?> options) {
    t += dt;
    for (gather += t < _rel ? dt * 420.0 : 0.0; gather >= 1.0; gather -= 1.0) {
      final kind = r.next();
      final sp = r.range(140.0, 250.0) * (1.0 + t * 2.0);
      double x;
      double y;
      double tx;
      double ty;
      if (kind < 0.42) {
        final an = r.range(0.0, tau);
        final d = r.range(22.0, 70.0);
        x = math.cos(an) * d;
        y = -1.0 - math.sin(an).abs() * d * 0.1;
        tx = math.cos(an) * 3.0;
        ty = -1.0;
      } else if (kind < 0.84) {
        final an = r.range(0.0, tau);
        final d = r.range(34.0, 64.0);
        x = math.cos(an) * d;
        y = math.min(-3.0, -20.0 + math.sin(an) * d * 0.85);
        tx = math.cos(an) * 11.0;
        ty = -20.0 + math.sin(an) * 14.0;
      } else {
        if (t < _rel * 0.4) continue;
        x = r.range(-9.0, 9.0);
        y = -1.0;
        tx = x * 0.7;
        ty = -r.range(26.0, 44.0);
      }
      final dx = tx - x;
      final dy = ty - y;
      final lRaw = hypot(dx, dy);
      final l = lRaw == 0.0 ? 1.0 : lRaw;
      rush.add(_RushStreak(
        x: x,
        y: y,
        vx: (dx / l) * sp,
        vy: (dy / l) * sp,
        life: math.min(l / sp, _rel + 0.06 - t),
        len: r.range(5.0, 9.0),
        c: r.chance(0.45) ? c[6] : c[5],
        back: kind > 0.84 && r.chance(0.5),
      ));
    }

    for (var i = rush.length - 1; i >= 0; i--) {
      final m = rush[i];
      m.life -= dt;
      if (m.life <= 0.0) {
        rush.removeAt(i);
      } else {
        m.x += m.vx * dt;
        m.y += m.vy * dt;
      }
    }

    if (t < _rel && r.chance(0.12)) {
      _spawn(P.star, r.range(-30.0, 30.0), -r.range(0.0, 3.0), 0.0,
          -r.range(10.0, 30.0), r.range(0.3, 0.5), c[6], 0.6);
    }

    if (!released && t >= _rel) {
      released = true;
      lights.add(0, -24, 90, c[5], 0.6, 0.7);
      lights.add(0, -8, 40, kWhite, 0.6, 0.12);
      for (var i = 0; i < 22; i++) {
        final an = (i / 22.0) * tau + r.range(-0.12, 0.12);
        final sp = r.range(260.0, 460.0);
        final y0 = -18.0 + math.sin(an) * 8.0;
        final vy = math.sin(an) * sp * 0.8;
        final life = math.min(
          r.range(0.1, 0.2),
          math.min(
            vy > 0.0 ? -y0 / vy : (vy < 0.0 ? (y0 + 104.0) / -vy : 1.0),
            78.0 / (math.cos(an) * sp).abs(),
          ),
        );
        _spawn(
          P.mote,
          math.cos(an) * 6.0,
          y0,
          math.cos(an) * sp,
          vy,
          life,
          r.chance(0.4) ? c[7] : c[6],
          1.0,
          0.0,
          an > 0.3 && an < math.pi - 0.3 ? PF.back : 0,
        );
      }
      for (var i = 0; i < 26; i++) {
        final an = -math.pi / 2.0 + r.range(-1.3, 1.3);
        final sp = r.range(120.0, 290.0);
        _spawn(P.spark, r.range(-5.0, 5.0), -2.0, math.cos(an) * sp,
            math.sin(an) * sp, r.range(0.35, 0.8));
      }
      for (var i = 0; i < 16; i++) {
        _spawn(
          P.star,
          r.range(-10.0, 10.0),
          r.range(-36.0, -4.0),
          r.range(-30.0, 30.0),
          -r.range(15.0, 60.0),
          r.range(0.6, 1.3),
          r.pick([c[7], c[6], c[5]]),
          r.chance(0.35) ? r.range(1.5, 2.6) : r.range(0.4, 0.9),
          0.0,
          r.chance(0.4) ? PF.back : 0,
        );
      }
    }

    final w = _widthAt(t);
    if (t >= nextHalo && t < _ret - 0.1) {
      halos.add(t);
      nextHalo += 0.16;
    }

    if (t > _rel && t < _ret + 0.1 && r.chance(0.5)) {
      final s = r.sign();
      final y = r.range(-4.0, -60.0);
      final vy = -r.range(140.0, 260.0);
      _spawn(
        P.mote,
        s * r.range(0.75, 1.6) * w,
        y,
        0.0,
        vy,
        math.min(r.range(0.16, 0.32), (y + 96.0) / -vy),
        r.chance(0.5) ? c[7] : c[6],
        r.range(0.6, 1.0),
        0.0,
        r.chance(0.5) ? PF.back : 0,
      );
    }

    if (t > _rel && t < 2.4 && r.chance(0.14 * (1.0 - seg(t, 1.6, 2.4)))) {
      _spawn(
        P.ember,
        r.range(-20.0, 20.0),
        -r.range(1.0, 30.0),
        r.range(-15.0, 15.0),
        -r.range(20.0, 55.0),
        r.range(0.8, 1.6),
        c[5],
        r.range(1.0, 2.0),
        0.0,
        r.chance(0.4) ? PF.back : 0,
      );
    }

    if (actor != null && t > _rel + 0.1 && t < 2.2 && r.chance(0.09)) {
      final m = actor!.mask;
      for (var n = 0; n < 12; n++) {
        final i = r.intRange(0, m.w - 1);
        final j = r.intRange(0, m.h - 1);
        if (m.data[j * m.w + i] == 0) continue;
        _spawn(
          P.star,
          actor!.x + i + 0.5,
          actor!.y + j + 0.5,
          r.range(-8.0, 8.0),
          -r.range(14.0, 34.0),
          r.range(0.6, 1.1),
          r.pick([c[7], c[6], c[5]]),
          r.chance(0.2) ? 1.5 : 0.6,
          0.0,
          r.chance(0.5) ? PF.back : 0,
        );
        break;
      }
    }

    if (t > 1.0 && t < 2.5 && r.chance(0.13)) {
      final up = r.chance(0.6);
      final x = up ? r.range(-58.0, 58.0) : r.range(-20.0, 20.0);
      final y = up ? _ty + 7.0 + r.range(-16.0, 16.0) : r.range(-44.0, -6.0);
      _spawn(
        P.star,
        x,
        y,
        r.range(-6.0, 6.0),
        -r.range(4.0, 14.0),
        r.range(0.4, 0.8),
        r.pick([c[7], c[6], c[6], c[5]]),
        r.chance(0.3) ? r.range(1.5, 2.4) : 0.6,
        0.0,
        r.chance(0.3) ? PF.back : 0,
      );
    }

    for (final l in lets) {
      if (t < l.born) continue;
      l.on = true;
      if (!l.rest) {
        l.v += 1700.0 * dt;
        l.off += l.v * dt;
        if (l.off >= 0.0 && l.v > 0.0) {
          l.off = 0.0;
          if (l.v > 110.0) {
            l.sq = 1.0;
            if (!l.landed) {
              l.landed = true;
              l.flash = 1.0;
              lights.add(l.cx, base - 7.0, 18, c[5], 0.55, 0.25);
              for (final s in const [-1, 1]) {
                _spawn(
                  P.star,
                  l.cx + s * l.w,
                  base - r.range(0.0, 3.0),
                  s * r.range(15.0, 40.0),
                  -r.range(5.0, 25.0),
                  r.range(0.25, 0.45),
                  c[6],
                  r.range(0.5, 1.2),
                );
              }
            }
            l.v = -l.v * 0.3;
          } else {
            l.v = 0.0;
            l.rest = true;
          }
        }
      }
      l.sq = math.max(0.0, l.sq - dt / 0.1);
      l.flash = math.max(0.0, l.flash - dt / 0.12);
      if (!l.burst && t >= l.pop + 0.06) {
        l.burst = true;
        for (var i = 0; i < 3; i++) {
          final an = r.range(0.0, tau);
          final sp = r.range(20.0, 55.0);
          _spawn(
            P.star,
            l.cx + r.range(-3.0, 3.0),
            base - 7.0 + r.range(-4.0, 4.0),
            math.cos(an) * sp,
            math.sin(an) * sp - 15.0,
            r.range(0.3, 0.6),
            r.pick([c[7], c[6]]),
            i != 0 ? 0.6 : r.range(1.2, 2.0),
          );
        }
      }
    }

    psReplaced.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    _rays(
      p,
      c,
      t,
      Ease.outExpo(seg(t, _landed, _landed + 0.2)) *
          (1.0 - Ease.inQuad(seg(t, _exit - 0.15, _exit + 0.1))),
      0.0,
      _ty + 7.0,
    );
    if (t < _rel) {
      final k = seg(t, 0.02, _rel);
      band(
        p,
        0,
        0,
        4.0 + 52.0 * (1.0 - Ease.inQuad(k)),
        0.2,
        1.5,
        k * 1.1,
        c,
        keep: (g) => math.sin(g) < 0.0,
      );
    }
    for (final (d, r1, th) in const [(0.0, 72.0, 4.0), (0.08, 46.0, 2.5)]) {
      final k = (t - _rel - d) / 0.55;
      if (k > 0.0 && k < 1.0) {
        band(
          p,
          0,
          0,
          5.0 + r1 * Ease.outCubic(k),
          0.2,
          math.max(1.0, th * (1.0 - k)),
          1.15 - k,
          c,
          keep: (g) => math.sin(g) < 0.0,
          hot: k < 0.15,
        );
      }
    }
    for (final h0 in halos) {
      final k = (t - h0) / 0.6;
      if (k > 0.0 && k < 1.0) {
        band(
          p,
          0,
          -2.0 - 72.0 * Ease.outQuad(k),
          (_widthAt(t) * 1.45 + 4.0) * (1.0 - 0.4 * k),
          0.3,
          1.5,
          (1.0 - k) * 1.4,
          c,
          keep: (g) => math.sin(g) < 0.0,
          hot: k < 0.12,
        );
      }
    }
    _column(p, c, t);
    _plate(
      p,
      c,
      t,
      t < _rel
          ? 0.55 * seg(t, 0.05, _rel)
          : 1.0 - smooth(_ret - 0.1, _gone + 0.2, t),
    );
    psReplaced.draw(p, 'back');
    _drawRush(p, true);
  }

  @override
  void draw(Painter p) {
    if (t < _rel) {
      final k = seg(t, 0.02, _rel);
      band(
        p,
        0,
        0,
        4.0 + 52.0 * (1.0 - Ease.inQuad(k)),
        0.2,
        1.5,
        k * 1.1,
        c,
        keep: (g) => math.sin(g) >= 0.0,
      );
    }
    for (final (d, r1, th) in const [(0.0, 72.0, 4.0), (0.08, 46.0, 2.5)]) {
      final k = (t - _rel - d) / 0.55;
      if (k > 0.0 && k < 1.0) {
        band(
          p,
          0,
          0,
          5.0 + r1 * Ease.outCubic(k),
          0.2,
          math.max(1.0, th * (1.0 - k)),
          1.15 - k,
          c,
          keep: (g) => math.sin(g) >= 0.0,
          hot: k < 0.15,
        );
      }
    }
    for (final h0 in halos) {
      final k = (t - h0) / 0.6;
      if (k > 0.0 && k < 1.0) {
        band(
          p,
          0,
          -2.0 - 72.0 * Ease.outQuad(k),
          (_widthAt(t) * 1.45 + 4.0) * (1.0 - 0.4 * k),
          0.3,
          1.5,
          (1.0 - k) * 1.4,
          c,
          keep: (g) => math.sin(g) >= 0.0,
          hot: k < 0.12,
        );
      }
    }

    final lit = smooth(_rel - 0.02, _rel + 0.04, t) * (1.0 - smooth(_ret, 2.5, t));
    tintActor(
      p,
      actor,
      t < _rel
          ? 0.0
          : (t < _rel + 0.06 ? 1.0 : math.exp(-(t - _rel - 0.06) / 0.07)),
      [c[4], c[5], c[6]],
    );
    lightActor(
      p,
      actor,
      c[5],
      0.1 * seg(t, 0.05, _rel) * (1.0 - lit) + 0.06 * lit,
      0.6 * lit,
      t,
    );
    haloActor(
      p,
      actor,
      c[5],
      0.85 * lit * (1.0 - smooth(_ret, _gone + 0.3, t)) + 0.3 * lit,
      t,
    );

    if (t < _rel) {
      final k = seg(t, 0.05, _rel);
      final beat =
          1.0 + 0.4 * math.exp(-((t - _rel * 0.6) * (t - _rel * 0.6)) / 0.001);
      sparkle(p, 0, -2, (1.0 + 4.0 * k * k) * beat, c[6], c[5], 0.3 + 0.4 * k);
    } else if (t < _rel + 0.22) {
      final a = (t - _rel) / 0.22;
      flare(p, 0, -4, 28.0 * math.pow(1.0 - a, 1.5), 1.0 - a, c);
      p.glow(0, -16, 48, kWhite, 0.3 * (1.0 - a));
    }

    psReplaced.draw(p, 'front');
    _drawRush(p, false);

    final items = <WordLetter>[];
    final done = (t - _landed) / 0.12;
    for (final l in lets) {
      if (!l.on) continue;
      var sx = 2.0;
      var sy = 2.0;
      var flash = l.flash;
      if (!l.landed && l.v > 150.0) {
        sx = 1.8;
        sy = 2.3;
      }
      if (l.sq > 0.0) {
        sx = 2.0 * (1.0 + 0.22 * l.sq);
        sy = 2.0 * (1.0 - 0.22 * l.sq);
      }
      final pu = (t - l.pop) / 0.07;
      final hop = seg(t, l.pop - 0.1, l.pop);
      if (pu >= 1.0) continue;
      if (hop > 0.0 && pu <= 0.0) {
        sx = 2.0 * (1.0 - 0.1 * hop);
        sy = 2.0 * (1.0 + 0.15 * hop);
      }
      if (pu > 0.0) {
        sx = sy = 2.0 * (1.0 + 0.3 * pu);
        flash = 1.0;
      }
      flash = math.max(flash, done > 0.0 && done < 1.0 ? 1.0 - done : 0.0);
      final h = 7.0 * sy;
      final w = l.w * sx;
      items.add(WordLetter(
        g: l.g,
        x: l.cx - w / 2.0,
        y: base + l.off - h - 3.0 * Ease.outQuad(hop),
        sx: sx,
        sy: sy,
        a: clamp((t - l.born) / 0.05),
        flash: flash,
      ));
    }

    final sh = seg(t, _shine, _shine + 0.34);
    final shine = (sh > 0.0 && sh < 1.0)
        ? x0 - 14.0 + (right - x0 + 30.0) * Ease.inOutSine(sh)
        : null;
    drawWord(
      p,
      items,
      WordStyle(
        fill: [c[3], c[4], c[5], c[6]],
        edge: kWhite,
        under: c[2],
        outline: c[0],
        shadow: shadowCol,
        shine: shine,
        shineY: _ty,
        glint: c[6],
      ),
    );
    if (shine != null && shine > x0 && shine < right) {
      p.glowLine(shine, _ty, shine + 8.4, base, 9, c[6], 0.3);
    }
    final hold = smooth(0.9, 1.2, t) * (1.0 - smooth(_exit, _exit + 0.4, t));
    if (hold > 0.0) {
      p.glow(
        0,
        _ty + 7,
        50,
        c[5],
        0.22 * hold + (done > 0.0 && done < 1.0 ? 0.3 * (1.0 - done) : 0.0),
      );
    }

    for (final l in lets) {
      final u = (t - l.pop - 0.07) / 0.16;
      if (u > 0.0 && u < 1.0) {
        sparkle(p, l.cx, base - 7.0, 6.0 * (1.0 - u) * (1.0 - u), c[6], c[5], 0.5);
      }
    }

    final g = (t - _shine - 0.3) / 0.26;
    if (g > 0.0 && g < 1.0) {
      sparkle(p, right - 2.0, _ty + 1.0, 7.0 * math.sin(g * math.pi), c[6], c[5], 0.6);
    }
    for (final s in sats) {
      final u = (t - s.t0) / s.dur;
      if (u > 0.0 && u < 1.0) {
        sparkle(p, s.x, s.y, s.l * math.pow(math.sin(u * math.pi), 0.7), c[6],
            c[5], 0.5);
      }
    }
    lights.draw(p);
  }
}

final SimulatedEffect levelUpEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ui/level-up',
    name: 'Level up',
    desc:
        'Gold gathers at the feet and bursts up as a pillar of light round the hero; rings climb it, LEVEL UP! drops in letter by letter, a shine sweeps it, sparkles twinkle.',
    category: 'ui',
    tags: ['ui', 'level', 'reward', 'text', 'light', 'one-shot'],
    size: (176, 138),
    origin: (88, 114),
    duration: _duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#2a1405',
        '#5c3008',
        '#9a5a0e',
        '#d48e18',
        '#f5b92c',
        '#ffde5e',
        '#fff4bc',
        '#ffffff',
      ],
      'text': 'LEVEL UP!',
      'seed': 5,
    },
  ),
  act: ActSpec(
    onBody: true,
    follow: 0.0,
    poses: [
      const PoseKey(-0.3, kReady),
      const PoseKey(0.28, _coil),
      const PoseKey(0.3, _leap, PoseEase.snap),
      PoseKey(0.46, _leap.copyWith(y: -19)),
      PoseKey(0.72, _leap.copyWith(y: 0, ffy: -4, fby: -4), PoseEase.inEase),
      PoseKey(0.74, _coil.copyWith(crouch: 5), PoseEase.snap),
      const PoseKey(0.95, _pump, PoseEase.out),
      PoseKey(1.2, _pump.copyWith(crouch: 1, fy: -43)),
      const PoseKey(1.45, _pump),
      PoseKey(2.3, _pump.copyWith(fy: -41)),
      const PoseKey(2.8, kReady),
      const PoseKey(3.2, kReady),
    ],
    hits: const [HitSpec(t: 0.28, stop: 0.05, shake: 0.14, amp: 2.0)],
    dust: const [DustSpec(t: 0.3, x: 0.0, n: 7), DustSpec(t: 0.74, x: 0.0, n: 6)],
  ),
  onCreate: _LevelUpSim.new,
);
