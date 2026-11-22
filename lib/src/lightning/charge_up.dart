// The charge (streaks spiralling in, a core that swells with an accelerating pulse, little arcs spitting off
// it) and the release (flash, rings, a spray of motes and stars) follow Sprite Fusion's open-source energy charge
// (https://www.spritefusion.com/pixel-art-vfx/energy), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'lightning_lib.dart';

final Pose _hold = kReady.copyWith(
  crouch: 3,
  lean: -2,
  fx: 15,
  fy: -21,
  bx: 9,
  by: -17,
  ffx: 9,
  fbx: -7,
);

const Pose _burst = Pose(
  turn: 1.15,
  y: -2,
  crouch: 0,
  lean: -2,
  fx: -13,
  fy: -37,
  bx: 14,
  by: -36,
  ffx: -2,
  ffy: -6,
  fbx: 3,
  fby: -6,
);

final ActSpec _act = ActSpec(
  onBody: true,
  follow: 0.0,
  poses: [
    const PoseKey(-0.36, kReady),
    PoseKey(0.0, _hold),
    PoseKey(0.8, _hold.copyWith(crouch: 4)),
    PoseKey(1.4, _hold.copyWith(crouch: 6, lean: 0)),
    PoseKey(1.59, _hold.copyWith(crouch: 7, lean: 0)),
    const PoseKey(1.6, _burst, PoseEase.snap),
    PoseKey(
      1.95,
      _burst.copyWith(y: 0, crouch: 2, fy: -30, by: -30, ffx: -4, fby: -4),
    ),
    const PoseKey(2.7, kReady),
  ],
  hits: const [HitSpec(t: 1.6, stop: 0.14, shake: 0.3, amp: 3)],
  dust: const [
    DustSpec(t: 1.6, x: 10, n: 6, dir: 1),
    DustSpec(t: 1.6, x: -10, n: 6, dir: -1),
  ],
);

const double _cx = 15.0;
const double _cy = -21.0;
const List<double> _bk = [1.0, 0.7, 0.95, 0.5, 0.8, 0.35];
final int _ash = hex('#5b5566');

final Expando<List<Point2>> _edges = Expando<List<Point2>>();

List<Point2> _edgeOf(ActorDefinition a) {
  var e = _edges[a.mask];
  if (e != null) return e;
  final m = a.mask;
  bool on(int x, int y) =>
      x >= 0 && y >= 0 && x < m.w && y < m.h && m.data[y * m.w + x] != 0;
  e = <Point2>[];
  for (var y = 0; y < m.h; y++) {
    for (var x = 0; x < m.w; x++) {
      if (on(x, y) &&
          (!on(x - 1, y) || !on(x + 1, y) || !on(x, y - 1) || !on(x, y + 1))) {
        e.add(((a.x + x).toDouble(), (a.y + y).toDouble()));
      }
    }
  }
  _edges[a.mask] = e;
  return e;
}

class _ChargeBolt {
  final double x1;
  final double y1;
  final double t0;
  const _ChargeBolt(this.x1, this.y1, this.t0);
}

class _ChargeArc {
  final double x;
  final double y;
  final double t;
  final int seed;
  const _ChargeArc(this.x, this.y, this.t, this.seed);
}

class _ChargeUpSim extends BaseEffectSim {
  final List<int> c;
  final int seed;
  final double rel;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  late final List<_ChargeBolt> bolts;
  final List<_ChargeArc> arcs = [];
  List<double> beats = [];
  ActorDefinition actor;
  double t = 0.0;
  bool released = false;
  double phase = 0.0;

  _ChargeUpSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        seed = o.seed,
        rel = o.numOpt('charge', 1.6),
        r = Rng(o.seed),
        actor = o['actor'] as ActorDefinition {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: (o['sparks'] as List).cast<Object>(),
    );
    bolts = List.generate(8, (i) {
      final a = (i / 8.0) * tau + r.range(-0.25, 0.25);
      final l = r.range(44.0, 72.0);
      final x1 = _cx + math.cos(a) * l;
      final y1 = math.min(0.0, _cy + math.sin(a) * l);
      return _ChargeBolt(x1, y1, rel + r.range(0.0, 0.05));
    });
  }

  double _level() => clamp(t / rel);

  @override
  void update(double dt, Map<String, Object?> opts) {
    final nextActor = opts['actor'] as ActorDefinition?;
    if (nextActor != null) actor = nextActor;
    t += dt;
    final k = _level();
    final e = k * k;
    if (t < rel) {
      for (var acc = (60.0 + 360.0 * e) * dt; acc > 0.0; acc--) {
        if (acc < 1.0 && !r.chance(acc)) break;
        final a = r.range(0.0, tau);
        final d = r.range(30.0, 72.0) * (1.0 - 0.35 * k);
        final life = r.range(0.16, 0.26);
        final sp = (d / life) * 0.95;
        ps.spawn(
          P.mote,
          _cx + math.cos(a) * d,
          math.min(-2.0, _cy + math.sin(a) * d),
          -math.cos(a) * sp - math.sin(a) * sp * 0.4,
          -math.sin(a) * sp + math.cos(a) * sp * 0.4,
          life,
          r.pick([c[7], c[6], c[5]]),
          1.0,
        );
      }
      if (k > 0.2 && r.chance((2.0 + 16.0 * e) * dt)) {
        final a = r.range(0.0, tau);
        final d = r.range(20.0, 40.0);
        arcs.add(
          _ChargeArc(
            _cx + math.cos(a) * d,
            math.min(-3.0, _cy + math.sin(a) * d),
            t,
            r.intRange(0, 1000000),
          ),
        );
      }
      phase += (1.5 + 11.0 * e) * dt;
      if (phase >= 1.0) {
        phase -= 1.0;
        beats.add(t);
      }
      if (r.chance(4.0 * e * dt)) {
        ps.spawn(
          P.star,
          _cx + r.range(-14.0, 14.0),
          _cy + r.range(-14.0, 10.0),
          0.0,
          -4.0,
          r.range(0.2, 0.35),
          c[6],
          r.range(1.0, 2.0),
        );
      }
    } else if (!released) {
      released = true;
      lights.add(_cx, _cy, 110, c[4], 0.8, 0.5);
      lights.add(_cx, _cy, 28, kWhite, 0.6, 0.08);
      for (var i = 0; i < 70; i++) {
        final a = r.range(0.0, tau);
        final sp = r.range(140.0, 330.0) * (math.sin(a) > 0.4 ? 0.55 : 1.0);
        ps.spawn(
          math.sin(a) < -0.2 && r.chance(0.35) ? P.mote : P.spark,
          _cx,
          _cy,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.25, 0.55),
          r.pick([c[7], c[6], c[5]]),
          r.range(0.8, 1.4),
        );
      }
      for (var i = 0; i < 10; i++) {
        final a = r.range(0.0, tau);
        final sp = r.range(60.0, 160.0);
        ps.spawn(
          P.star,
          _cx,
          _cy,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.4, 0.8),
          r.chance(0.5) ? c[6] : c[5],
          r.range(1.2, 2.4),
        );
      }
      for (var i = 0; i < 4; i++) {
        ps.spawn(
          P.smoke,
          _cx + r.range(-5.0, 5.0),
          _cy + r.range(-4.0, 4.0),
          r.range(-12.0, 12.0),
          -r.range(8.0, 18.0),
          r.range(0.6, 0.85),
          mix(_ash, c[4], 0.3),
          r.range(3.0, 5.0),
          r.range(0.05, 0.15),
        );
      }
    }
    beats = [
      for (final b in beats)
        if (t - b < 0.22) b,
    ];
    for (var i = arcs.length - 1; i >= 0; i--) {
      if (t - arcs[i].t > 0.07) arcs.removeAt(i);
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final k = _level();
    if (t < rel) p.glow(_cx * 0.5, -3, 40, c[3], 0.3 * k * k);
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final k = _level();
    final e = k * k;
    final f = (t * 30.0 + 1e-4).floor();
    final aDef = actor;
    if (t < rel) {
      final jit = k > 0.85
          ? (f % 2 != 0 ? 1.0 : -1.0) * ((k - 0.85) / 0.15)
          : 0.0;
      final x = _cx + jit;
      const y = _cy;
      final pr = 0.5 + 0.5 * math.sin(phase * tau);
      for (final (ex, ey) in _edgeOf(aDef)) {
        final d = hypot(ex + 0.5 - x, ey + 0.5 - y);
        if (d < 6.0 + 10.0 * k && e > 0.08) {
          p.px(ex, ey, d < 4.0 + 6.0 * k && e > 0.4 ? c[6] : c[4]);
        }
      }
      for (final b in beats) {
        final q = (t - b) / 0.22;
        p.ring(
          x,
          y,
          4.0 + 20.0 * (1.0 - Ease.inQuad(q)) * (0.5 + k),
          1,
          q > 0.6 ? c[6] : c[4],
          0.4 + 0.6 * q,
        );
      }
      for (final arc in arcs) {
        crackle(
          p,
          zigzag(rng(arc.seed, f), arc.x, arc.y, x, y, 0.35, 0.4),
          0.85,
          c,
          0.4,
        );
      }
      final rad = 1.2 + 6.5 * e + pr * (0.5 + 1.2 * k);
      p.circle(x, y, rad + 1.3, c[2]);
      p.circle(x, y, rad, c[4]);
      p.circle(x - rad * 0.12, y - rad * 0.12, rad * 0.7, c[5]);
      p.circle(x, y, rad * 0.38, kWhite);
      if (rad > 3.0) {
        for (final s in const [0.0, math.pi]) {
          for (var angOff = 0.0; angOff < 1.3; angOff += 0.12) {
            final ang = t * 10.0 + s + angOff;
            final rr = rad * (0.62 + 0.1 * math.sin(angOff * 3.0));
            p.dot(
              x + math.cos(ang) * rr,
              y + math.sin(ang) * rr,
              angOff < 0.5 ? kWhite : c[6],
            );
          }
        }
      }
      if (k > 0.35) {
        final q = rng(seed, 5, f);
        final ang = q.range(0.0, tau);
        final l = q.range(3.0, 6.0) * (0.5 + k);
        crackle(
          p,
          zigzag(
            q,
            x + math.cos(ang) * rad,
            y + math.sin(ang) * rad,
            x + math.cos(ang) * (rad + l),
            y + math.sin(ang) * (rad + l),
            0.4,
            0.3,
          ),
          0.7,
          c,
          0.3,
        );
      }
      p.glow(x, y, 12.0 + 30.0 * k, c[4], 0.35 + 0.45 * k);
      p.glow(x, y, 6.0 + 6.0 * k, c[6], 0.25 + 0.3 * k);
    } else {
      final a = t - rel;
      if (a < 0.07) {
        p.mask(aDef.mask, aDef.x, aDef.y, a < 0.035 ? kWhite : c[6]);
      }
      if (a < 0.22) {
        final q = a / 0.22;
        flare(
          p,
          _cx,
          _cy,
          46.0 * math.pow(1.0 - q, 1.4).toDouble(),
          1.0 - q,
          c,
        );
        if (q < 0.3) {
          p.circle(_cx, _cy, 12.0 * (1.0 - q * 2.5) + 1.5, kWhite);
        }
      }
      for (var i = 0; i < bolts.length; i++) {
        final b = bolts[i];
        final ba = ((t - b.t0) * 30.0 + 1e-4).floor();
        if (t < b.t0 || ba >= _bk.length) continue;
        boltStrokeWith(
          p,
          zigzag(rng(seed, 3, i, ba >> 1), _cx, _cy, b.x1, b.y1, 0.25, 0.75),
          _bk[ba],
          c,
          s: ba == 0 ? 0.95 : 0.75,
          hero: ba == 0,
        );
        if (b.y1 > -1.0) p.glow(b.x1, -3, 18, c[5], 0.5 * _bk[ba]);
      }
      final q = a / 0.45;
      if (q < 1.0) {
        final rad = 8.0 + 80.0 * Ease.outCubic(q);
        p.ringShaded(
          _cx,
          _cy,
          rad,
          math.max(1.0, 3.0 * (1.0 - q)),
          color: (_, _) => q < 0.25 ? kWhite : c[5],
          alpha: (_, g) => _cy + math.sin(g) * rad > -1.0 ? 0.0 : 1.1 - q,
        );
        final r2 = 6.0 + 56.0 * Ease.outCubic(math.min(1.0, q * 1.3));
        p.ringShaded(
          _cx,
          _cy,
          r2,
          1.0,
          color: (_, _) => c[4],
          alpha: (_, g) => _cy + math.sin(g) * r2 > -1.0 ? 0.0 : 0.8 - q,
        );
        p.glow(
          _cx,
          _cy - 6,
          math.min(rad * 0.9, 46.0),
          c[3],
          0.42 * (1.0 - q) * (1.0 - q),
        );
      }
      if (a > 0.15 && a < 0.5) {
        final qq = rng(seed, 8, f);
        final ang = qq.range(0.0, tau);
        final l = qq.range(5.0, 10.0);
        crackle(
          p,
          zigzag(
            qq,
            _cx,
            _cy,
            _cx + math.cos(ang) * l,
            _cy + math.sin(ang) * l,
            0.45,
            0.3,
          ),
          0.8 * (1.0 - (a - 0.15) / 0.35) + 0.15,
          c,
          0.3,
        );
      }
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect chargeUpEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'lightning/charge-up',
    name: 'Charge up',
    desc:
        "Sparks streak and arcs whip in to a crackling core at the caster's hand that swells and pulses faster, then it flashes and bursts: bolts every way, a ring, a spray of sparks.",
    category: 'lightning',
    tags: [
      'lightning',
      'electric',
      'charge',
      'spell',
      'power-up',
      'actor',
      'one-shot',
    ],
    size: (272, 184),
    origin: (124, 148),
    duration: 2.7,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': voltPalette,
      'sparks': plasmaSparks,
      'charge': 1.6,
      'seed': 4,
    },
  ),
  act: _act,
  onCreate: (o) => _ChargeUpSim(o),
);
