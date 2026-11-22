import 'dart:math' as math;
import 'package:pixelfx_core/pixelfx_core.dart';
import 'shadow_lib.dart';

const double _y = -54;
const double _rs = 16;
const double _rel = 0.52;
const double _burn = 1.62;
const double _pop = 1.84;
final int _smoke = hex('#5d5468');

void _sphere(Painter p, List<int> C, double r, double t, double heat) {
  if (r < 0.6) return;
  final E = r + 12 * heat + 2;
  p.shade(-E, _y - E, E, _y + E, (x, y, out) {
    final dx = x;
    final dy = y - _y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d > E) return null;
    if (d < r - 0.5) {
      final e = r - d;
      final ang = math.atan2(dy, dx);
      if (e < 1.4 && math.cos(ang - 0.8) > 0.55) return C[2];
      final gx = dx + r * 0.45;
      final gy = dy + r * 0.45;
      if (r > 8 && gx * gx + gy * gy < 1.6) return C[3];
      return C[0];
    }
    final e = d - (r - 0.5);
    if (e < 1) {
      out.c = math.sin(math.atan2(dy, dx) * 7 + t * 9) > -0.6 ? kWhite : C[7];
      out.k = 0.4;
      return null;
    }
    final ang = math.atan2(dy + e * 0.6, dx);
    final top = math.max(0.0, -math.sin(ang));
    final a1 = ang - t * 0.9;
    final a2 = ang + t * 1.7;
    final i1 = ((a1 * 9) / tau + 0.5).floor();
    final i2 = ((a2 * 15) / tau + 0.5).floor();
    final t1 =
        math.pow(0.5 + 0.5 * math.cos(a1 * 9), 3) *
        (0.55 + 0.45 * noise(t * 7 + i1 * 3.7, 1));
    final t2 =
        math.pow(0.5 + 0.5 * math.cos(a2 * 15), 4) *
        (0.5 + 0.5 * noise(t * 11 + i2 * 5.1, 2));
    final h =
        heat *
        (0.3 + 0.95 * top) *
        (1.5 + 12 * math.max(0.0, t1) + 6 * math.max(0.0, t2));
    if (e > h + 1) return null;
    final u = (e - 1) / h;
    out.c = u < 0.18
        ? kWhite
        : u < 0.4
            ? C[7]
            : u < 0.62
                ? C[6]
                : u < 0.84
                    ? C[5]
                    : C[4];
    out.a = u < 0.8 ? 1.0 : (1 - u) * 5;
    if (u < 0.6 && ((x.floor() + y.floor()) & 1) == 0) {
      out.k = 0.25 * (1 - u);
    }
    return null;
  });
}

class _Light {
  _Light(this.x, this.y, this.r, this.c, this.k, this.life) : max = life;
  final double x;
  final double y;
  final double r;
  final int c;
  final double k;
  double life;
  final double max;
}

class _Ring {
  _Ring(this.r0, this.r1, this.life, this.th, this.hot, this.delay) : max = life;
  final double r0;
  final double r1;
  double life;
  final double max;
  final double th;
  final bool hot;
  double delay;
}

void _floorRing(Painter p, List<int> C, _Ring r, bool back) {
  if (r.delay > 0 || !r.hot || r.th < 3) return;
  final q = r.life / r.max;
  final rr = r.r0 + (r.r1 - r.r0) * (1 - q * q * q);
  if (rr <= -_y) return;
  final rf = math.sqrt(rr * rr - _y * _y);
  band(
    p,
    0,
    0.5,
    rf,
    0.16,
    math.max(1.0, 3 * q),
    math.min(1.0, q * 1.5),
    [C[3], C[4], C[5], C[6]],
    keep: (g) => (math.sin(g) < 0) == back,
  );
  if (!back) {
    for (final s in const [-1, 1]) {
      p.glow(s * rf, -2, 16, C[5], 0.4 * q);
    }
  }
}

class _DarkExplosionSim extends BaseEffectSim {
  _DarkExplosionSim(Map<String, Object?> o)
      : C = fit(o.palette, 8),
        R = Rng(o.seed) {
    ps = Particles(
      rng: R,
      ground: (_) => 0,
      sparks: [kWhite, C[7], C[6], C[5]],
    );
    embers = Particles(
      rng: R,
      ground: (_) => 0,
      sparks: [C[7], C[6], C[5], C[4]],
    );
    puffs = Puffs(
      rng: R,
      flame: [kWhite, C[7], C[6], C[5], C[5], C[4], C[4], C[3], C[2]],
      soot: [mix(mix(C[3], C[1], 0.3), _smoke, 0.45), mix(C[1], _smoke, 0.3)],
      cap: mix(mix(C[4], C[2], 0.5), _smoke, 0.4),
      rim: [C[6], C[5], C[4]],
      floor: (_) => 0,
    );
  }

  final List<int> C;
  final Rng R;
  late final Particles ps;
  late final Particles embers;
  late final Puffs puffs;
  final Bits bits = Bits(ground: (_) => 0);
  final List<_Light> lights = [];
  final List<_Ring> rings = [];
  final Set<DebrisBit> _flatBits = {};
  final Set<DebrisBit> _wispBits = {};

  double t = 0;
  bool released = false;
  bool collapsing = false;
  bool popped = false;
  double acc = 0;
  double dustAcc = 0;
  double flick = 1;

  double _coreR(double tt) =>
      tt < _rel - 0.07 ? 1.5 + 5 * Ease.inQuad(tt / _rel) : 1;

  double _sphereR(double tt) {
    if (tt < _rel) return 0;
    if (tt < _burn) {
      return _rs *
          Ease.outBack(clamp((tt - _rel) / 0.14), 2.4) *
          (1 + 0.06 * smooth(_rel + 0.3, _burn, tt) + 0.02 * math.sin(tt * 11));
    }
    if (tt < _pop) {
      return _rs * 1.08 * (1 - Ease.inQuad((tt - _burn) / (_pop - _burn)));
    }
    return 0;
  }

  double _starL(double tt) => (tt < _rel || tt > _rel + 0.26)
      ? 0
      : 60 * (1 - Ease.inQuad(clamp((tt - _rel - 0.05) / 0.21)));

  double _starRot(double tt) => 0.32 + (tt - _rel) * 2.2;

  double _burning(double tt) => tt < _rel
      ? clamp(tt / _rel) * 0.7
      : tt < _burn
          ? 1.0
          : tt < _pop
              ? 1.2
              : math.max(0.0, 1 - (tt - _pop) / 0.35);

  void _light(double x, double y, double r, int c, double k, double life) =>
      lights.add(_Light(x, y, r, c, k, life));

  (double, double) _rim(double a, double r) =>
      (math.cos(a) * r, _y + math.sin(a) * r);

  void _release() {
    _light(0, _y, 100, C[4], 1.25, 0.85);
    _light(0, _y, 86, mix(C[6], kWhite, 0.5), 1.3, 0.22);
    rings.add(_Ring(_rs, 104, 0.46, 3.6, true, 0));
    rings.add(_Ring(_rs * 0.8, 62, 0.3, 1.6, true, 0.02));
    rings.add(_Ring(_rs, 124, 0.62, 1.2, false, 0.07));
    for (int i = 0; i < 34; i++) {
      final big = i < 20;
      final a = R.range(0, tau);
      final (x, y) = _rim(a, _rs * 0.7);
      final sp = big ? R.range(80, 170) : R.range(130, 220);
      bits.add(DebrisBit(
        kind: DebrisKind.shard,
        x: x,
        y: y,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp - R.range(40, 110),
        g: 0.75,
        drag: big ? 1.3 : 1.7,
        bounce: 0.35,
        life: R.range(1.6, 2.6),
        a: R.range(0, tau),
        va: R.range(-16, 16),
        s: big ? R.range(6, 11) : R.range(3, 4.5),
      ));
    }
    for (int i = 0; i < 84; i++) {
      final a = R.range(0, tau);
      final (x, y) = _rim(a, _rs * 0.8);
      final sp = R.range(120, 235);
      ps.spawn(
        ParticleKind.spark,
        x,
        y,
        math.cos(a) * sp,
        math.sin(a) * sp - 50,
        R.range(0.2, 0.7),
      );
    }
    for (int i = 0; i < 28; i++) {
      final a = R.range(0, tau);
      final (x, y) = _rim(a, _rs * 0.9);
      final sp = R.range(30, 130);
      embers.spawn(
        ParticleKind.ember,
        x,
        y,
        math.cos(a) * sp,
        math.sin(a) * sp - 40,
        R.range(1.3, 2.5),
      );
    }
    for (int i = 0; i < 24; i++) {
      final a = R.range(0, tau);
      final (x, y) = _rim(a, _rs * 0.9);
      final sp = R.range(15, 70);
      puffs.spawn(
        PuffKind.soot,
        x,
        y,
        math.cos(a) * sp,
        math.sin(a) * sp * 0.8 - 14,
        R.range(2, 2.8),
        R.range(7, 12),
        R.range(0.02, 0.3),
      );
    }
    for (int i = 0; i < 12; i++) {
      final s = i % 2 != 0 ? 1.0 : -1.0;
      puffs.spawn(
        PuffKind.soot,
        s * R.range(10, 40),
        -R.range(2, 5),
        s * R.range(50, 120),
        -R.range(0, 10),
        R.range(1.6, 2.4),
        R.range(5, 9),
        R.range(0.08, 0.2),
      );
    }
    for (int i = 0; i < 10; i++) {
      final a = -math.pi / 2 + R.range(-1.6, 1.6);
      final (x, y) = _rim(a, _rs);
      final sp = R.range(30, 80);
      puffs.spawn(
        PuffKind.flame,
        x,
        y,
        math.cos(a) * sp,
        math.sin(a) * sp - 30,
        R.range(0.3, 0.6),
        R.range(2, 3.6),
        0,
        R.chance(0.5),
      );
    }
    ps.list.clear();
    puffs.list.removeWhere((q) => q.delay <= 0);
  }

  void _popBlast() {
    _light(0, _y, 56, kWhite, 0.9, 0.18);
    _light(0, _y, 120, C[5], 0.8, 0.5);
    rings.add(_Ring(2, 40, 0.28, 2, true, 0));
    for (int i = 0; i < 26; i++) {
      final a = R.range(0, tau);
      final sp = R.range(120, 250);
      ps.spawn(
        ParticleKind.spark,
        0,
        _y,
        math.cos(a) * sp,
        math.sin(a) * sp - 40,
        R.range(0.2, 0.6),
      );
    }
    for (int i = 0; i < 14; i++) {
      final a = R.range(0, tau);
      final sp = R.range(20, 90);
      embers.spawn(
        ParticleKind.ember,
        0,
        _y,
        math.cos(a) * sp,
        math.sin(a) * sp - 30,
        R.range(0.9, 1.6),
      );
    }
    for (int i = 0; i < 10; i++) {
      final a = R.range(0, tau);
      final sp = R.range(20, 70);
      puffs.spawn(
        PuffKind.soot,
        math.cos(a) * 3,
        _y + math.sin(a) * 3,
        math.cos(a) * sp,
        math.sin(a) * sp - 15,
        R.range(1.1, 1.7),
        R.range(3, 6),
        R.range(0, 0.08),
      );
    }
    for (final q in embers.list) {
      final dx = q.x;
      final dy = q.y - _y;
      final dRaw = hypot(dx, dy);
      final d = dRaw > 0 ? dRaw : 1.0;
      final f = 90 * math.max(0.0, 1 - d / 70);
      q.vx += (dx / d) * f;
      q.vy += (dy / d) * f - f * 0.3;
    }
    for (final q in puffs.list) {
      final dx = q.x;
      final dy = q.y - _y;
      final dRaw = hypot(dx, dy);
      final d = dRaw > 0 ? dRaw : 1.0;
      final f = 90 * math.max(0.0, 1 - d / 70);
      q.vx += (dx / d) * f;
      q.vy += (dy / d) * f - f * 0.3;
    }
    for (int i = 0; i < 12; i++) {
      puffs.spawn(
        PuffKind.soot,
        R.range(-6, 6),
        _y + R.range(-4, 6),
        R.range(-10, 10),
        -R.range(20, 55),
        R.range(1.3, 1.8),
        R.range(7, 12),
        R.range(0.02, 0.2),
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    flick = 0.88 + 0.12 * math.sin(t * 37) * math.sin(t * 23);
    if (t < _rel - 0.06) {
      final k = t / _rel;
      for (acc += dt * (90 + 150 * k); acc > 1; acc--) {
        final a = R.range(0, tau);
        final D = R.range(36, 84);
        final x = math.cos(a) * D;
        final y = math.min(-3.0, _y + math.sin(a) * D);
        final vt = R.range(50, 110);
        final vi = R.range(10, 40);
        ps.spawn(
          ParticleKind.mote,
          x,
          y,
          -math.sin(a) * vt - math.cos(a) * vi,
          math.cos(a) * vt - math.sin(a) * vi,
          0.9,
          R.pick([kWhite, C[6], C[6], C[5]]),
          R.range(0.7, 1.2),
        );
      }
      if (R.chance(0.75)) {
        final a = R.range(0, tau);
        final D = R.range(28, 70);
        final T = R.range(0.18, 0.28);
        final v = (D * 3) / (math.exp(3 * T) - 1);
        ps.spawn(
          ParticleKind.streak,
          math.cos(a) * D,
          _y + math.sin(a) * D,
          -math.cos(a) * v,
          -math.sin(a) * v,
          T,
          R.chance(0.5) ? C[7] : C[6],
        );
      }
      if (t < _rel - 0.2 && R.chance(0.16)) {
        final a = R.range(0, tau);
        final D = R.range(34, 60);
        puffs.spawn(
          PuffKind.soot,
          math.cos(a) * D,
          _y + math.sin(a) * D,
          -math.sin(a) * 40,
          math.cos(a) * 40,
          R.range(0.6, 0.9),
          R.range(3, 6),
        );
      }
      attractParticles(
        ps.list,
        0,
        _y,
        2.2e6 * (0.3 + k),
        110,
        0.55,
        2.5,
        dt,
        (q) => q.k == ParticleKind.mote ? 1.0 : 0.0,
        420,
      );
      attractPuffs(
        puffs.list,
        0,
        _y,
        1.2e6 * (0.3 + k),
        90,
        0.7,
        4,
        dt,
        (_) => 1.0,
        160,
      );
    }
    if (t >= _rel && !released) {
      released = true;
      _release();
    }
    if (released && t < _burn) {
      final sr = _sphereR(t);
      for (acc += dt * 34; acc > 1; acc--) {
        final a = -math.pi / 2 + R.gauss() * 1.1;
        final (x, y) = _rim(a, sr + 1);
        final sp = R.range(10, 35);
        puffs.spawn(
          PuffKind.flame,
          x,
          y,
          math.cos(a) * sp,
          math.sin(a) * sp - R.range(10, 30),
          R.range(0.25, 0.45),
          R.range(1.2, 2.2),
          0,
          R.chance(0.2),
        );
      }
      if (R.chance(dt * 10)) {
        final a = -math.pi / 2 + R.range(-1.4, 1.4);
        final (x, y) = _rim(a, sr * 0.9);
        puffs.spawn(
          PuffKind.soot,
          x,
          y,
          math.cos(a) * 20,
          -R.range(15, 35),
          R.range(1.2, 1.7),
          R.range(5, 9),
        );
      }
      if (R.chance(dt * 8)) {
        final a = R.range(0, tau);
        final (x, y) = _rim(a, sr);
        final sp = R.range(110, 200);
        ps.spawn(
          ParticleKind.spark,
          x,
          y,
          math.cos(a) * sp,
          math.sin(a) * sp - 40,
          R.range(0.2, 0.5),
        );
      }
      if (R.chance(dt * 7)) {
        final a = -math.pi / 2 + R.range(-1.2, 1.2);
        final (x, y) = _rim(a, sr);
        embers.spawn(
          ParticleKind.ember,
          x,
          y,
          math.cos(a) * 30,
          -R.range(20, 50),
          R.range(0.9, 1.6),
        );
      }
    }
    if (t >= _burn && !collapsing) {
      collapsing = true;
      for (int i = 0; i < 14; i++) {
        final a = R.range(0, tau);
        final D = R.range(26, 48);
        final T = R.range(0.14, 0.2);
        final v = (D * 3) / (math.exp(3 * T) - 1);
        ps.spawn(
          ParticleKind.streak,
          math.cos(a) * D,
          _y + math.sin(a) * D,
          -math.cos(a) * v,
          -math.sin(a) * v,
          T,
          R.chance(0.5) ? kWhite : C[6],
        );
      }
    }
    if (collapsing && !popped) {
      attractPuffs(
        puffs.list,
        0,
        _y,
        1.4e6,
        64,
        0.6,
        3,
        dt,
        (q) => q.k == PuffKind.flame ? 1.0 : 0.35,
        200,
      );
    }
    if (t >= _pop && !popped) {
      popped = true;
      _popBlast();
    }
    for (final r in rings) {
      if (r.delay > 0 || !r.hot || r.th < 3) continue;
      final rr = r.r0 + (r.r1 - r.r0) * (1 - math.pow(r.life / r.max, 3));
      final rf = rr > -_y ? math.sqrt(rr * rr - _y * _y) : 0.0;
      if (rf > 0) {
        for (dustAcc += dt * 60; dustAcc > 1; dustAcc--) {
          final s = R.sign();
          ps.spawn(
            ParticleKind.dust,
            s * rf + R.range(-2, 2),
            -R.range(1, 3),
            s * R.range(20, 50),
            -R.range(4, 14),
            R.range(0.4, 0.8),
            mix(C[2], C[3], R.next()),
            R.range(1.5, 3),
          );
        }
      }
    }
    for (int i = lights.length - 1; i >= 0; i--) {
      if ((lights[i].life -= dt) <= 0) lights.removeAt(i);
    }
    for (int i = rings.length - 1; i >= 0; i--) {
      final q = rings[i];
      if (q.delay > 0) {
        q.delay -= dt;
      } else if ((q.life -= dt) <= 0) {
        rings.removeAt(i);
      }
    }
    bits.update(dt);
    for (final b in bits.list) {
      if (b.rest && !_flatBits.contains(b)) {
        _flatBits.add(b);
        b.a = ((b.a / math.pi) + 0.5).floor() * math.pi + R.range(-0.2, 0.2);
        b.y = -1;
      }
      if (b.life < 0.45 && !_wispBits.contains(b)) {
        _wispBits.add(b);
        puffs.spawn(
          PuffKind.soot,
          b.x,
          b.y - 1,
          R.range(-4, 4),
          -R.range(8, 16),
          R.range(0.6, 0.9),
          R.range(1.4, 2.4),
        );
      }
    }
    puffs.update(dt);
    ps.update(dt);
    embers.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final k = _burning(t);
    for (final r in rings) {
      _floorRing(p, C, r, true);
    }
    puffs.draw(p, PuffKind.soot, PuffLight(x: 0, y: _y, k: k * flick, reach: 84));
    ps.draw(p, 'back');
    if (k > 0) p.glow(0, -3, 74, C[4], 0.24 * math.min(1.0, k) * flick);
  }

  @override
  void draw(Painter p) {
    final sr = _sphereR(t);
    final k = _burning(t);
    final L = _starL(t);
    for (final r in rings) {
      _floorRing(p, C, r, false);
    }
    double cr = 0;
    if (t < _rel) {
      final q = t / _rel;
      final ring = 3 + 74 * (1 - Ease.inQuad(q));
      final d1 = t - _rel * 0.5;
      final d2 = t - _rel * 0.8;
      final beat =
          1 + 0.3 * math.exp(-(d1 * d1) / 0.0015) + 0.4 * math.exp(-(d2 * d2) / 0.0015);
      cr = _coreR(t) * beat;
      ringFast(p, 0, _y, ring, 1, q > 0.7 ? C[6] : C[5], 0.2 + 0.7 * q);
      if (t > _rel - 0.07) {
        p.circle(0, _y, 1.6, kWhite);
      } else {
        _sphere(p, C, cr, t, 0.3 + 0.3 * q);
      }
      halo(p, 0, _y, cr, cr + 14 + 30 * q, C[5], (0.45 + 0.7 * q) * beat);
      p.glow(0, _y, 60 + 30 * q, C[4], 0.12 + 0.3 * q);
    }
    final fu = (t - _rel) / 0.12;
    if (fu >= 0 && fu < 1) {
      final r = 36 * (1 - 0.3 * fu);
      p.circle(0, _y, r + 1.5, C[5], 1.2 - fu);
      p.circle(0, _y, r, fu < 0.35 ? kWhite : C[6], 1.1 - fu);
      if (fu < 0.6) p.circle(0, _y, r * 0.62, kWhite);
    }
    for (final r in rings) {
      if (r.delay > 0) continue;
      final q = r.life / r.max;
      final rr = r.r0 + (r.r1 - r.r0) * (1 - q * q * q);
      final th = math.max(1.0, r.th * q + 0.4);
      ringFastFn(
        p,
        0,
        _y,
        rr,
        th,
        (v, _) => r.hot
            ? (v > 0.6 ? kWhite : v > 0.3 ? C[6] : C[5])
            : (v > 0.5 ? C[5] : C[4]),
        1.0,
        (v, g) => _y + math.sin(g) * rr > 0.5 ? 0.0 : math.min(1.0, q * 1.6),
      );
      if (r.hot) ringLight(p, 0, _y, rr, 4, C[5], 0.4 * q, (x, y) => y < 0.5);
    }
    _sphere(
      p,
      C,
      sr,
      t,
      t < _burn ? 1.0 : 1 + 0.5 * clamp((t - _burn) / (_pop - _burn)),
    );
    final star = L > 0 ? BlackStar(_y, L, _starRot(t), 0.5, 0.4) : null;
    if (star != null) {
      final age = t - _rel;
      final fr = age < 0.12 ? 36 * (1 - 0.3 * (age / 0.12)) + 1.5 : 0.0;
      final cut = math.max(fr, sr);
      star.draw(
        p,
        C[0],
        age < 0.1 ? C[5] : C[4],
        (x, y) => x * x + (y - _y) * (y - _y) < cut * cut,
      );
    }
    puffs.draw(p, PuffKind.flame);
    for (final b in bits.list) {
      shard(p, b, C, 0, _y, math.min(1.0, k) * 0.9);
    }
    ps.draw(p, 'front');
    embers.draw(p, 'front');
    final pu = (t - _pop) / 0.2;
    if (pu >= 0 && pu < 1) {
      sparkle(p, 0, _y, 12 * (1 - pu), C[6], C[5], 0.7 * (1 - pu));
    }
    for (final l in lights) {
      final q = l.life / l.max;
      p.glow(l.x, l.y, l.r * (0.55 + 0.45 * q), l.c, l.k * q * q);
    }
    if (sr > 1) {
      halo(p, 0, _y, sr - 0.5, sr + 16, C[6], 0.5 * flick * math.min(1.0, k));
      p.glow(0, _y, sr + 54, C[4], 0.5 * flick * math.min(1.0, k));
    }
    final b0 = math.max(sr, cr) + 1;
    if (b0 > 2) {
      final lim = math.max(sr, cr) - 0.5;
      unlight(
        p,
        -b0,
        _y - b0,
        b0,
        _y + b0,
        (x, y) => x * x + (y - _y) * (y - _y) < lim * lim,
      );
    }
    if (star != null) star.unlight(p);
  }
}

final PixelEffect darkExplosionEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'shadow/dark-explosion',
    name: 'Dark explosion',
    desc:
        'Motes swirl into a pulsing core, a black star cuts across a violet-white flash, and a black sphere burns at the rim, throws lit shards and smoke, then collapses.',
    category: 'shadow',
    kind: AssetKind.effect,
    tags: [
      'shadow',
      'explosion',
      'void',
      'dark',
      'magic',
      'impact',
      'one-shot',
    ],
    size: (280, 248),
    origin: (140, 206),
    duration: 3.8,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {'palette': kVoidPalette, 'seed': 6},
  ),
  onCreate: (o) => _DarkExplosionSim(o),
);
