import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'spawn_lib.dart';

const Pose _fear = Pose(
  turn: 0.9,
  lean: -2,
  crouch: 2,
  fx: -9,
  fy: -31,
  bx: 9,
  by: -31,
  ffx: -3,
  fbx: 4,
);

const double _lock = 0.5;
const double _crack = 1.05;
const double _burst = 1.4;
const double _duration = 3.3;

final PixelEffect shatterDeathEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'spawn/shatter-death',
    name: 'Shatter death',
    desc:
        'Frost races up the body and seals it in faceted ice, a glint sweeps it, cracks spread from the chest, then it bursts into its own facets that tumble, bounce and melt.',
    category: 'spawn',
    tags: [
      'spawn',
      'death',
      'ice',
      'freeze',
      'shatter',
      'shards',
      'one-shot',
    ],
    size: (172, 96),
    origin: (84, 84),
    duration: _duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#0e1636',
        '#1a2f66',
        '#2557a3',
        '#3488d6',
        '#5fc0f0',
        '#a2e6ff',
        '#dcf8ff',
        '#ffffff',
      ],
      'seed': 14,
    },
  ),
  act: const ActSpec(
    onBody: true,
    poses: [
      PoseKey(-0.2, kReady),
      PoseKey(0.08, _fear, PoseEase.snap),
      PoseKey(
        0.3,
        Pose(
          turn: 0.9,
          lean: -3,
          crouch: 2,
          fx: -9,
          fy: -34,
          bx: 9,
          by: -31,
          ffx: -3,
          fbx: 4,
        ),
      ),
      PoseKey(0.5, _fear),
      PoseKey(_duration, _fear),
    ],
    hits: [
      HitSpec(t: 0.5, stop: 0.02, shake: 0.06, amp: 1),
      HitSpec(t: 1.4, stop: 0.09, shake: 0.26, amp: 3),
    ],
  ),
  onActorAlpha: (t, _) => t < _burst ? 1.0 : 0.0,
  onCreate: (o) => _ShatterDeathSim(o),
);

class _Spike {
  const _Spike({
    required this.x,
    required this.base,
    required this.h,
    required this.w,
    required this.lean,
    required this.at,
  });

  final double x;
  final double base;
  final double h;
  final double w;
  final double lean;
  final double at;
}

class _IcePiece {
  _IcePiece({
    required this.id,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.va,
    required this.r,
    required this.map,
    required this.life,
    required this.n,
  }) : max = life;

  final int id;
  double x;
  double y;
  double vx;
  double vy;
  double a = 0;
  double va;
  final double r;
  final Map<(int, int), int> map;
  double life;
  final double max;
  bool rest = false;
  final int n;
}

class _RimeSpot {
  const _RimeSpot({required this.x, required this.w, required this.t0});

  final double x;
  final double w;
  final double t0;
}

class _ShatterDeathSim extends BaseEffectSim {
  _ShatterDeathSim(Map<String, Object?> o) {
    cRamp = fit(o.palette, 8);
    rng = Rng(o.seed);
    body = bodyOf(o.actor, cRamp);
    w = body.w + 2;
    h = body.h + 1;
    x0 = body.x - 1;
    y0 = body.y - 1;
    ice = Int16List(w * h)..fillRange(0, w * h, -1);
    col = Uint32List(w * h);
    glass = Uint32List(w * h);
    solid = Uint8List(w * h);

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final mx = x - 1;
        final my = y - 1;
        if (body.on(mx, my) ||
            (my < body.h - 1 &&
                (body.on(mx - 1, my) ||
                    body.on(mx + 1, my) ||
                    body.on(mx, my - 1) ||
                    body.on(mx, my + 1)))) {
          ice[y * w + x] = 0;
        }
      }
    }

    final seeds = <(double, double)>[];
    for (var i = 0; i < 22; i++) {
      double x;
      double y;
      var tries = 0;
      do {
        x = rng.range(0, w.toDouble());
        y = rng.range(0, h.toDouble());
      } while (ice[y.floor() * w + x.floor()] < 0 && ++tries < 40);
      seeds.add((x, y));
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        if (ice[i] < 0) continue;
        var d1 = 1e9;
        var d2 = 1e9;
        var k = 0;
        for (var j = 0; j < seeds.length; j++) {
          final (sx, sy) = seeds[j];
          final d = hypot(x + 0.5 - sx, (y + 0.5 - sy) * 0.85);
          if (d < d1) {
            d2 = d1;
            d1 = d;
            k = j;
          } else if (d < d2) {
            d2 = d;
          }
        }
        ice[i] = k;
        final (sx, sy) = seeds[k];
        final lit = clamp(
          0.55 +
              0.35 * (rand(k, 41) - 0.5) -
              0.5 * ((sx - w / 2) / w) -
              0.55 * ((sy - h / 2) / h),
        );
        final own = body.cell(x - 1, y - 1)?.c;
        col[i] = own != null ? mix(own, cRamp[4], 0.36) : cRamp[3];
        glass[i] = cRamp[3 + math.min(2, (lit * 3).floor())];
        var sc = 0;
        if (d2 - d1 < 0.42 && own == null) {
          sc = lit > 0.5 ? cRamp[6] : cRamp[5];
        } else if (d2 - d1 < 0.42) {
          col[i] = mix(col[i], cRamp[6], 0.45);
        }
        if (!_at(x - 1, y) || !_at(x, y - 1)) sc = cRamp[6];
        if (!_at(x + 1, y) || (!_at(x, y + 1) && y < h - 1)) sc = cRamp[3];
        if (sc != 0) {
          col[i] = sc;
          solid[i] = 1;
        }
      }
    }

    for (var i = 0; i < 7; i++) {
      final x = rng.intRange(1, w - 2);
      final yInit = rng.intRange(2, h - 3);
      var y = yInit;
      while (y > 0 && _at(x, y - 1)) {
        y--;
      }
      if (_at(x, y)) {
        spikes.add(
          _Spike(
            x: x0 + x + 0.5,
            base: (y0 + y + 1).toDouble(),
            h: rng.range(3, 6),
            w: rng.range(2.5, 3.5),
            lean: rng.range(-2.5, 2.5),
            at: _lock + rng.range(-0.02, 0.08),
          ),
        );
      }
    }
    for (final sd in const [-1, 1]) {
      for (var i = 0; i < 2; i++) {
        final hh = i != 0 ? rng.range(5, 7) : rng.range(8, 11);
        spikes.add(
          _Spike(
            x: sd * (i != 0 ? rng.range(11, 13) : rng.range(7, 9)),
            base: 0,
            h: hh,
            w: i != 0 ? 3.5 : 4.5,
            lean: sd * hh * rng.range(0.25, 0.45),
            at: rng.range(0.08, 0.2),
          ),
        );
      }
    }

    ix = (w * 0.48 + 0.5).floor();
    iy = (h * 0.42 + 0.5).floor();

    void walk(double x, double y, double a, double len) {
      final pts = <(double, double)>[(x, y)];
      for (var s = 0; s < len; s++) {
        a += rng.range(-0.5, 0.5);
        x += math.cos(a) * rng.range(1.4, 2.4);
        y += math.sin(a) * rng.range(1.4, 2.4);
        if (!_at(x.floor(), y.floor())) break;
        pts.add((x, y));
        if (pts.length > 3 && cracks.length < 18 && rng.chance(0.15)) {
          walk(x, y, a + rng.sign() * rng.range(0.6, 1.1), len / 2);
        }
      }
      cracks.add(pts);
    }

    for (var i = 0; i < 7; i++) {
      walk(ix.toDouble(), iy.toDouble(), (i / 7) * tau + rng.range(-0.3, 0.3), 20);
    }

    ps = Particles(
      rng: rng,
      ground: (_) => 0,
      sparks: [kWhite, cRamp[6], cRamp[5], cRamp[4]],
      haze: cRamp[5],
    );
    bits = Bits(ground: (_) => 0);
    lights = Lights();
  }

  late final List<int> cRamp;
  late final Rng rng;
  late final BodyData body;
  late final int w;
  late final int h;
  late final int x0;
  late final int y0;
  late final Int16List ice;
  late final Uint32List col;
  late final Uint32List glass;
  late final Uint8List solid;
  final List<_Spike> spikes = [];
  late final int ix;
  late final int iy;
  final List<List<(double, double)>> cracks = [];
  late final Particles ps;
  late final Bits bits;
  late final Lights lights;
  final List<_IcePiece> pieces = [];
  final List<_RimeSpot> rime = [];
  double t = 0;
  bool locked = false;
  bool cracked = false;
  bool burst = false;

  bool _at(int x, int y) =>
      x >= 0 && y >= 0 && x < w && y < h && ice[y * w + x] >= 0;

  double _level(double t) => h * (1 - Ease.outCubic(clamp(t / _lock)));

  void _shatter() {
    final cells = <int, List<(int, int, int)>>{};
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final k = ice[y * w + x];
        if (k < 0) continue;
        final i = y * w + x;
        cells
            .putIfAbsent(k, () => [])
            .add((x, y, solid[i] != 0 ? col[i] : mix(col[i], glass[i], 0.3)));
      }
    }
    for (final px in cells.values) {
      var cx = 0.0;
      var cy = 0.0;
      for (final (x, y, _) in px) {
        cx += x + 0.5;
        cy += y + 0.5;
      }
      cx /= px.length;
      cy /= px.length;
      final map = <(int, int), int>{};
      var r = 0.0;
      for (final (x, y, c) in px) {
        final d = hypot(x + 0.5 - cx, y + 0.5 - cy);
        if (d > r) r = d;
        map[((x + 0.5 - cx + 0.5).floor(), (y + 0.5 - cy + 0.5).floor())] = c;
      }
      r += 1;
      final dx = cx - ix;
      final dy = cy - iy;
      final len = hypot(dx, dy);
      final d = len == 0 ? 1.0 : len;
      final sp = rng.range(55, 115);
      final life = rng.range(1.3, 1.85);
      pieces.add(
        _IcePiece(
          id: pieces.length + 1,
          x: x0 + cx,
          y: y0 + cy,
          vx: (dx / d) * sp + rng.range(-18, 18),
          vy: (dy / d) * sp * 0.6 - rng.range(110, 220),
          va: rng.range(-9, 9),
          r: r,
          map: map,
          life: life,
          n: px.length,
        ),
      );
    }
    for (var i = 0; i < 64; i++) {
      final a = -math.pi / 2 + rng.range(-1.45, 1.45);
      final sp = rng.range(60, 180);
      bits.add(
        DebrisBit(
          kind: B.shard,
          x: x0 + ix + rng.range(-6, 6),
          y: y0 + iy + rng.range(-8, 8),
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp,
          g: 0.85,
          drag: 0.6,
          bounce: 0.3,
          life: rng.range(0.9, 1.6),
          a: rng.range(0, tau),
          va: rng.range(-20, 20),
          s: rng.range(1.5, 3.2),
          c: rng.pick([cRamp[7], cRamp[6], cRamp[5]]),
        ),
      );
    }
    for (var i = 0; i < 14; i++) {
      ps.spawn(
        P.vapour,
        rng.range(-10, 10),
        -rng.range(1, 20),
        rng.sign() * rng.range(20, 80),
        -rng.range(4, 20),
        rng.range(0.6, 1.1),
        rng.chance(0.5) ? cRamp[6] : cRamp[5],
        rng.range(2.5, 4.5),
      );
    }
    for (var i = 0; i < 16; i++) {
      ps.spawn(
        P.star,
        rng.range(-16, 16),
        -rng.range(4, 38),
        rng.range(-40, 40),
        -rng.range(10, 60),
        rng.range(0.4, 1),
        rng.pick([kWhite, cRamp[6]]),
        rng.range(1, 2.4),
      );
    }
    lights.add(0, (y0 + iy).toDouble(), 46, kWhite, 0.75, 0.14);
    lights.add(0, (y0 + iy).toDouble(), 70, cRamp[4], 0.6, 0.5);
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t < _lock) {
      final y = y0 + _level(t);
      if (rng.chance(0.7)) {
        ps.spawn(
          P.star,
          rng.range(-10, 10),
          y,
          rng.range(-12, 12),
          -rng.range(0, 18),
          rng.range(0.25, 0.5),
          rng.chance(0.5) ? kWhite : cRamp[6],
          rng.range(0.8, 1.8),
        );
      }
      if (rng.chance(0.25)) {
        ps.spawn(
          P.vapour,
          rng.range(-8, 8),
          -1,
          rng.sign() * rng.range(15, 50),
          -rng.range(2, 10),
          rng.range(0.6, 1),
          cRamp[6],
          rng.range(2, 3.5),
        );
      }
    }
    if (!locked && t >= _lock) {
      locked = true;
      lights.add(0, -20, 54, cRamp[4], 0.6, 0.3);
      for (var i = 0; i < 6; i++) {
        ps.spawn(
          P.star,
          rng.range(-12, 12),
          -rng.range(4, 36),
          0,
          -4,
          rng.range(0.35, 0.7),
          rng.pick([kWhite, cRamp[6]]),
          rng.range(1.2, 2.4),
        );
      }
    }
    if (locked && t < _crack && rng.chance(0.08)) {
      ps.spawn(
        P.star,
        rng.range(-11, 11),
        -rng.range(2, 36),
        0,
        -3,
        rng.range(0.3, 0.6),
        rng.pick([kWhite, cRamp[6]]),
        rng.range(0.8, 2),
      );
    }
    if (!cracked && t >= _crack) {
      cracked = true;
      for (var i = 0; i < 5; i++) {
        final a = rng.range(0, tau);
        final sp = rng.range(60, 150);
        bits.add(
          DebrisBit(
            kind: B.shard,
            x: (x0 + ix).toDouble(),
            y: (y0 + iy).toDouble(),
            vx: math.cos(a) * sp,
            vy: math.sin(a) * sp - 60,
            g: 0.8,
            drag: 0.6,
            bounce: 0.3,
            life: rng.range(0.5, 0.9),
            a: rng.range(0, tau),
            va: rng.range(-20, 20),
            s: rng.range(1, 2),
            c: cRamp[6],
          ),
        );
      }
      lights.add(0, (y0 + iy).toDouble(), 24, kWhite, 0.7, 0.1);
    }
    if (!burst && t >= _burst) {
      burst = true;
      _shatter();
    }
    for (var i = pieces.length - 1; i >= 0; i--) {
      final q = pieces[i];
      q.life -= dt;
      if (q.life <= 0) {
        pieces.removeAt(i);
        continue;
      }
      if (q.rest) {
        if (t < _duration - 0.9 && rng.chance(0.02)) {
          ps.spawn(
            P.vapour,
            q.x,
            q.y - 1,
            rng.range(-4, 4),
            -rng.range(4, 10),
            rng.range(0.5, 0.8),
            cRamp[5],
            rng.range(1.5, 2.5),
          );
        }
        continue;
      }
      q.vy += 900 * dt;
      q.vx -= q.vx * 0.5 * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      q.a += q.va * dt;
      final g = -q.r * 0.55;
      if (q.y > g && q.vy > 0) {
        q.y = g;
        if (q.vy > 90) {
          rime.add(_RimeSpot(x: q.x, w: 2 + q.r * 0.6, t0: t));
          q.vy *= -0.32;
          q.vx *= 0.65;
          q.va = q.va * 0.5 + rng.range(-4, 4);
          if (q.n > 8) ps.spawn(P.star, q.x, q.y, 0, -6, 0.3, kWhite, 1.2);
          for (var j = 0; j < 2; j++) {
            ps.spawn(
              P.dust,
              q.x + rng.range(-2, 2),
              -0.5,
              rng.sign() * rng.range(10, 30),
              -rng.range(2, 8),
              rng.range(0.3, 0.5),
              cRamp[5],
              rng.range(1.2, 2),
            );
          }
        } else if (q.vx.abs() > 12) {
          q.vy = 0;
          q.vx *= 0.9;
          q.va *= 0.85;
        } else {
          q.rest = true;
          q.vx = 0;
          q.vy = 0;
        }
      }
    }
    bits.update(dt);
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final k =
        smooth(0.1, _lock, t) * (1 - smooth(_burst + 0.6, _burst + 1.6, t));
    final reach = 6 + 12 * smooth(0, _lock + 0.3, t);
    if (k > 0) {
      for (var x = (-reach).floor(); x <= reach.ceil(); x++) {
        final hVal = rand(x, 17);
        final e = 1 - x.abs() / (reach + 1);
        p.dot(x.toDouble(), 0, hVal < 0.3 ? kWhite : cRamp[6], k * math.min(1.0, e * 2));
        if (hVal < 0.5) p.dot(x.toDouble(), 1, cRamp[5], k * e);
        if (hVal < 0.35 && e > 0.3) p.dot(x.toDouble(), -1, cRamp[6], k * e);
      }
      p.glow(0, -2, 26, cRamp[4], 0.25 * k);
    }
    for (final r in rime) {
      final a =
          clamp((t - r.t0) / 0.08) *
          (1 - smooth(_duration - 1, _duration - 0.15, t));
      for (var x = (r.x - r.w).floor(); x <= r.x + r.w; x++) {
        final hVal = rand(x, 23);
        if (hVal < 0.7) p.dot(x.toDouble(), 0, hVal < 0.25 ? kWhite : cRamp[6], a);
        if (hVal < 0.3) p.dot(x.toDouble(), 1, cRamp[5], a * 0.7);
      }
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    if (!burst) {
      final lv = _level(t);
      final shake = t > _crack && t < _burst
          ? ((t * 50).floor() % 2 != 0 ? 1.0 : -1.0) *
              (t > _burst - 0.15 ? 1.0 : 0.5)
          : 0.0;
      final glint = t > _lock ? ((t - _lock) * 0.9) % 1.6 : -1.0;
      for (var y = 0; y < h; y++) {
        if (y < lv.floor()) continue;
        for (var x = 0; x < w; x++) {
          final i = y * w + x;
          if (ice[i] < 0) continue;
          var c = y == lv.floor() && t < _lock
              ? (rand(x, 5) < 0.6 ? kWhite : cRamp[6])
              : (t >= _lock && t < _lock + 0.05 ? kWhite : col[i]);
          final g = ((x + (h - y) * 0.6) / (w + h * 0.6) - glint).abs();
          final on = glint >= 0 && glint <= 1;
          if (on && g < 0.035) {
            c = kWhite;
          } else if (on && g < 0.07 && c != cRamp[3]) {
            c = cRamp[6];
          }
          p.px(x0 + x + shake, y0 + y, c);
          if (solid[i] == 0 && c == col[i]) {
            p.blend(x0 + x + shake, y0 + y, glass[i], 0.3);
          }
        }
      }
      for (var y = math.max(0, lv.floor() - 1); y <= h; y++) {
        for (var x = -1; x <= w; x++) {
          if (!_at(x, y) &&
              (_at(x - 1, y) ||
                  _at(x + 1, y) ||
                  (_at(x, y + 1) && y + 1 >= lv) ||
                  _at(x, y - 1)) &&
              y < h) {
            p.px(x0 + x + shake, y0 + y, cRamp[0]);
          }
        }
      }
      for (final s in spikes) {
        final g = Ease.outBack(clamp((t - s.at) / 0.12), 2.4);
        if (g > 0) {
          crystal(
            p,
            s.x + shake,
            s.base,
            s.h * g,
            s.w,
            s.lean * g,
            cRamp,
            white: t < s.at + 0.04,
          );
        }
      }
      if (cracked) {
        final k = clamp((t - _crack) / 0.25);
        for (final pts in cracks) {
          final n = (pts.length * k).floor();
          for (var i = 0; i < n; i++) {
            final (x, y) = pts[i];
            final fresh = i > n - 3 && t - _crack < 0.3;
            p.px(x0 + x + shake, y0 + y, fresh ? kWhite : cRamp[7]);
            if (!fresh) p.px(x0 + x + shake, y0 + y + 1, cRamp[1]);
          }
        }
      }
      p.glow(0, -18, 30, cRamp[4], 0.18 * smooth(0, _lock, t));
      if (t > _lock && t < _lock + 0.18) {
        sparkle(
          p,
          -4.0,
          (y0 + 8).toDouble(),
          (8 * (1 - (t - _lock) / 0.18) + 0.5).floorToDouble(),
          kWhite,
          cRamp[5],
          0.6,
        );
      }
    } else if (t < _burst + 0.08) {
      final k = (t - _burst) / 0.08;
      p.circle(x0 + ix, y0 + iy, 10 * (1 - k) + 3, kWhite);
    }

    for (final q in pieces) {
      final ca = math.cos(q.a);
      final sa = math.sin(q.a);
      final fade = math.min(1.0, q.life / 0.5);
      final r = q.r.ceil();
      for (var py = -r; py <= r; py++) {
        for (var px = -r; px <= r; px++) {
          final ux = (px * ca + py * sa + 0.5).floor();
          final uy = (-px * sa + py * ca + 0.5).floor();
          final c = q.map[(ux, uy)];
          if (c != null && rand(ux, uy, q.id) < fade) {
            p.px(
              q.x.floor() + px,
              q.y.floor() + py,
              q.max - q.life < 0.05 ? kWhite : c,
            );
          }
        }
      }
      if (q.n > 6) p.glow(q.x, q.y, 6, cRamp[5], 0.2 * fade);
    }
    bits.draw(p);
    ps.draw(p, 'front');
    lights.draw(p);
  }
}
