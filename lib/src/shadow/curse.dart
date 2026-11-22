import 'dart:math' as math;
import 'package:pixelfx_core/pixelfx_core.dart';
import 'shadow_lib.dart';

const double _sy = -60;
const double _stamp = 0.55;
const double _crack = 1.72;
const double _break = 1.98;

const List<String> _skullRows = [
  '......kkkkk......',
  '....kkhhhhlkk....',
  '...khhhhhhlllk...',
  '..khhhhhllllllk..',
  '.khhhhlllllllmmk.',
  '.khhhllllllllmmk.',
  'khhllllllllllmmdk',
  'khlldddllldddmmdk',
  'khleeeeelleeeeedk',
  'kleeeeeelleeeeedk',
  'kleeeeeemleeeeedk',
  'kmleeeelmmleeedkk',
  '.kmmlllmnnmlmddk.',
  '..kmmlmnnnnmddk..',
  '..kdmlllmmlmddk..',
  '...kgtgtgtgtgk...',
  '...kdgtgtgtgdk...',
  '....kkkkkkkkk....',
];

const int _sw = 17;
const int _sh = 18;
const List<(double, double)> _eyes = [(-3.5, 1.5), (3.5, 1.5)];

bool _inSkull(int u, int v) =>
    u >= 0 && v >= 0 && u < _sw && v < _sh && _skullRows[v][u] != '.';

final Map<int, double> _cracks = () {
  final out = <int, double>{};
  const paths = [
    [(8, 1), (7, 3), (8, 5), (6, 6), (5, 7)],
    [(9, 1), (10, 3), (10, 4), (12, 6), (12, 7)],
    [(4, 3), (3, 5), (2, 6)],
    [(13, 4), (14, 6)],
  ];
  for (final path in paths) {
    final len = path.length - 1;
    for (int k = 0; k < len; k++) {
      final (x0, y0) = path[k];
      final (x1, y1) = path[k + 1];
      final steps = math.max((x1 - x0).abs(), (y1 - y0).abs());
      for (int s = 0; s <= steps; s++) {
        final x = (x0 + ((x1 - x0) * s) / steps + 0.5).floor();
        final y = (y0 + ((y1 - y0) * s) / steps + 0.5).floor();
        final key = y * _sw + x;
        out.putIfAbsent(key, () => (k + s / math.max(1, steps)) / len);
      }
    }
  }
  return out;
}();

void _drawSkull(
  Painter p,
  List<int> C,
  List<int> K,
  double s,
  double sq,
  double ox,
  double oy,
  bool white,
  double crack,
) {
  final pal = <String, int>{
    'k': K[0],
    'd': K[1],
    'm': K[2],
    'l': K[3],
    'h': K[4],
    'e': C[0],
    'n': C[0],
    't': K[3],
    'g': K[0],
  };
  final cx = ox;
  final cy = _sy + oy;
  final hw = (_sw / 2) * s + 1;
  final hh = (_sh / 2) * s * sq + 1;
  p.shade(cx - hw, cy - hh, cx + hw, cy + hh, (x, y, _) {
    final u = ((x - cx) / s + _sw / 2).floor();
    final v = ((y - cy) / (s * sq) + _sh / 2).floor();
    if (!_inSkull(u, v)) return null;
    final ch = _skullRows[v][u];
    if (white) return ch == 'e' || ch == 'n' ? C[5] : kWhite;
    final ck = _cracks[v * _sw + u];
    if (ck != null && ck < crack) {
      return crack > 0.55 && (u + v) % 2 != 0 ? C[6] : K[0];
    }
    return pal[ch];
  });
}

void _eyeFire(
  Painter p,
  List<int> C,
  double x,
  double y,
  double t,
  double k,
  int i,
) {
  if (k <= 0) return;
  for (final j in const [-0.6, 0.7]) {
    final h = (1.5 + 3 * (0.5 + 0.5 * noise(t * 8 + j * 3.1 + i * 7, 4))) * k;
    final sw = noise(t * 4 + j * 2 + i * 3, 8) * 1.2;
    for (double d = 1; d <= h; d += 0.5) {
      final u = d / h;
      p.dot(
        x + j + sw * u * u,
        y - d,
        u < 0.3
            ? C[7]
            : u < 0.6
                ? C[6]
                : u < 0.85
                    ? C[5]
                    : C[4],
        u < 0.75 ? 1.0 : (1 - u) * 4,
      );
    }
  }
  p.px(x, y, kWhite);
  p.px(x - 1, y, C[6]);
  p.glow(x, y, 8, C[5], 0.5 * k);
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

class _CurseSim extends BaseEffectSim {
  _CurseSim(Map<String, Object?> o)
      : C = fit(o.palette, 8),
        K = fit(
          o['bone'] is List
              ? o.rampOpt('bone')
              : const ['#170f26', '#4a3a6e', '#7f6ea6', '#b3a4d4', '#e2d8f6'],
          5,
        ),
        R = Rng(o.seed),
        A = o.actor {
    ps = Particles(
      rng: R,
      ground: (_) => 0,
      sparks: [kWhite, C[7], C[6], C[5]],
      haze: C[4],
    );
    puffs = Puffs(
      rng: R,
      flame: [kWhite, C[7], C[6], C[5], C[4], C[3], C[2], C[1], C[0]],
      soot: [mix(C[3], C[2], 0.5), mix(C[1], C[0], 0.3)],
      cap: mix(C[4], C[2], 0.5),
      rim: [C[6], C[5], C[4]],
      floor: (_) => 0,
    );
    dust = Puffs(
      rng: R,
      flame: [
        kWhite,
        kWhite,
        kWhite,
        kWhite,
        kWhite,
        kWhite,
        kWhite,
        kWhite,
        kWhite,
      ],
      soot: [mix(K[2], K[1], 0.4), mix(K[1], K[0], 0.5)],
      cap: K[3],
      rim: [K[4], K[3], K[2]],
      floor: (_) => 0,
    );
    final actor = A;
    head = actor != null ? actor.y.toDouble() : -38.0;
  }

  final List<int> C;
  final List<int> K;
  final Rng R;
  final ActorDefinition? A;
  late final Particles ps;
  late final Puffs puffs;
  late final Puffs dust;
  final Bits bits = Bits(ground: (_) => 0);
  final List<_Light> lights = [];
  final Set<DebrisBit> _dustedBits = {};
  late final double head;

  double t = 0;
  bool stamped = false;
  bool broke = false;
  double acc = 0;

  void _light(double x, double y, double r, int c, double k, double life) =>
      lights.add(_Light(x, y, r, c, k, life));

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t < _stamp - 0.05) {
      final k = t / _stamp;
      for (acc += dt * (40 + 60 * k); acc > 1; acc--) {
        final a = R.range(0, tau);
        final D = R.range(22, 44);
        ps.spawn(
          ParticleKind.mote,
          math.cos(a) * D,
          _sy + math.sin(a) * D * 0.8,
          -math.sin(a) * 60,
          math.cos(a) * 60,
          0.8,
          R.pick([kWhite, C[7], C[6], C[5]]),
          R.range(0.6, 1),
        );
      }
      if (R.chance(dt * 14)) {
        final a = R.range(0, tau);
        final D = R.range(20, 34);
        puffs.spawn(
          PuffKind.soot,
          math.cos(a) * D,
          _sy + math.sin(a) * D * 0.7,
          -math.sin(a) * 40,
          math.cos(a) * 30,
          R.range(0.5, 0.7),
          R.range(3, 5.5),
        );
      }
      attractParticles(
        ps.list,
        0,
        _sy,
        9e5 * (0.4 + k),
        70,
        0.6,
        2.5,
        dt,
        (q) => q.k == ParticleKind.mote ? 1.0 : 0.0,
        300,
      );
      attractPuffs(
        puffs.list,
        0,
        _sy,
        5e5 * (0.4 + k),
        60,
        0.7,
        3.5,
        dt,
        (_) => 1.0,
        120,
      );
    }
    if (t >= _stamp && !stamped) {
      stamped = true;
      ps.list.clear();
      puffs.list.clear();
      _light(0, _sy, 64, C[5], 1, 0.35);
      _light(0, _sy, 30, kWhite, 1, 0.1);
      _light(0, head + 12, 40, C[4], 0.6, 0.5);
      for (int i = 0; i < 22; i++) {
        final a = R.range(0, tau);
        final sp = R.range(80, 160);
        ps.spawn(
          ParticleKind.spark,
          math.cos(a) * 6,
          _sy + math.sin(a) * 6,
          math.cos(a) * sp,
          math.sin(a) * sp - 30,
          R.range(0.2, 0.5),
        );
      }
      for (int i = 0; i < 6; i++) {
        final a = R.range(0, tau);
        final sp = R.range(20, 45);
        puffs.spawn(
          PuffKind.soot,
          math.cos(a) * 8,
          _sy + math.sin(a) * 6,
          math.cos(a) * sp,
          math.sin(a) * sp * 0.6 - 10,
          R.range(0.6, 0.9),
          R.range(2.5, 4.5),
        );
      }
    }
    if (stamped && !broke) {
      for (final (ex, ey) in _eyes) {
        if (R.chance(dt * 9)) {
          ps.spawn(
            ParticleKind.ember,
            ex,
            _sy + ey - 3,
            R.range(-10, 10),
            -R.range(20, 45),
            R.range(0.5, 0.9),
            C[6],
          );
        }
        if (R.chance(dt * 7)) {
          puffs.spawn(
            PuffKind.soot,
            ex + R.range(-1, 1),
            _sy + ey - 3,
            R.range(-5, 5),
            -R.range(14, 26),
            R.range(0.5, 0.8),
            R.range(1.4, 2.4),
          );
        }
      }
      if (R.chance(dt * 8)) {
        ps.spawn(
          ParticleKind.vapour,
          R.range(-7, 7),
          _sy + R.range(-6, 6),
          R.range(-12, 12),
          R.range(-12, 4),
          R.range(0.5, 0.8),
          R.chance(0.5) ? C[3] : C[4],
          R.range(5, 8),
        );
      }
      if (R.chance(dt * 12)) {
        ps.spawn(
          ParticleKind.mote,
          R.range(-4, 4),
          _sy + 9,
          R.range(-6, 6),
          R.range(40, 70),
          R.range(0.25, 0.4),
          R.chance(0.5) ? C[6] : C[5],
          0.8,
        );
      }
      if (R.chance(dt * 10)) {
        puffs.spawn(
          PuffKind.soot,
          R.range(-3.5, 3.5),
          _sy + 9,
          R.range(-3, 3),
          R.range(14, 26),
          R.range(0.45, 0.7),
          R.range(1.2, 2.2),
        );
      }
      if (t > _stamp + 0.3 && R.chance(dt * 5)) {
        final actor = A;
        ps.spawn(
          ParticleKind.star,
          R.range(-1, 1) * (actor != null ? actor.w / 2 : 10),
          head + R.range(4, actor != null ? actor.h - 4 : 30),
          0,
          -6,
          R.range(0.3, 0.5),
          C[6],
          R.range(1, 2),
        );
      }
    }
    if (t >= _break && !broke) {
      broke = true;
      for (int i = 0; i < 24; i++) {
        double x;
        double y;
        do {
          x = R.range(-8.5, 8.5);
          y = R.range(-9, 9);
        } while (!_inSkull((x + _sw / 2).floor(), (y + _sh / 2).floor()));
        bits.add(DebrisBit(
          kind: DebrisKind.chunk,
          x: x,
          y: _sy + y,
          vx: x * R.range(2.5, 6) + R.range(-12, 12),
          vy: R.range(-70, 10),
          g: 0.85,
          drag: 0.4,
          bounce: 0.35,
          life: R.range(0.8, 1.2),
          a: R.range(0, tau),
          va: R.range(-14, 14),
          s: R.range(1, 2.4),
          rampColors: [K[0], K[1], K[2], K[3], K[4]],
        ));
      }
      for (int i = 0; i < 26; i++) {
        ps.spawn(
          ParticleKind.grit,
          R.range(-7, 7),
          _sy + R.range(-8, 8),
          R.range(-32, 32),
          R.range(-60, 20),
          R.range(0.8, 1.3),
          R.pick([K[2], K[3], K[3], K[4]]),
          R.chance(0.3) ? 2 : 1,
        );
      }
      for (int i = 0; i < 7; i++) {
        dust.spawn(
          PuffKind.soot,
          R.range(-7, 7),
          _sy + R.range(-8, 6),
          R.range(-25, 25),
          R.range(-20, 5),
          R.range(0.5, 0.8),
          R.range(2, 4),
          R.range(0, 0.1),
        );
      }
      for (final (ex, ey) in _eyes) {
        puffs.spawn(
          PuffKind.flame,
          ex,
          _sy + ey,
          ex >= 0 ? 6.0 : -6.0,
          -30,
          0.5,
          2.6,
          0,
          false,
        );
      }
      _light(0, _sy, 40, C[5], 0.5, 0.25);
    }
    for (int i = lights.length - 1; i >= 0; i--) {
      if ((lights[i].life -= dt) <= 0) lights.removeAt(i);
    }
    bits.update(dt);
    for (final b in bits.list) {
      if (b.rest && !_dustedBits.contains(b)) {
        _dustedBits.add(b);
        dust.spawn(
          PuffKind.soot,
          b.x,
          -1.5,
          R.range(-12, 12),
          -R.range(4, 10),
          R.range(0.35, 0.6),
          R.range(1.5, 2.5),
        );
      }
    }
    ps.update(dt);
    puffs.update(dt);
    dust.update(dt);
  }

  @override
  void drawBack(Painter p) {
    puffs.draw(
      p,
      PuffKind.soot,
      PuffLight(x: 0, y: _sy, k: stamped && !broke ? 0.8 : 0.3, reach: 50),
    );
    dust.draw(p, PuffKind.soot);
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final flood = smooth(_stamp + 0.04, _stamp + 0.42, t);
    final ebb = 1 - smooth(_break + 0.15, _break + 0.75, t);
    final actor = A;
    if (actor != null && flood > 0 && ebb > 0) {
      final k = ebb;
      final pulse = 0.85 + 0.15 * math.sin(t * 9);
      for (int my = 0; my < actor.h; my++) {
        final u = my / actor.h;
        if (u > flood + 0.06) break;
        final edge = flood < 1 && (u - flood).abs() < 0.05;
        final bandCond =
            flood >= 1 && (u - (((t - _stamp) * 1.3) % 1.4) + 0.2).abs() < 0.06;
        for (int mx = 0; mx < actor.w; mx++) {
          final c0 = actor.pixels[my * actor.w + mx];
          if (c0 == 0) continue;
          final l = luma(c0);
          final cc = l > 0.72
              ? C[6]
              : l > 0.5
                  ? C[5]
                  : l > 0.33
                      ? C[4]
                      : l > 0.18
                          ? C[3]
                          : C[2];
          p.blend(
            actor.x + mx,
            actor.y + my,
            edge ? C[7] : bandCond ? C[6] : cc,
            edge ? 0.85 : bandCond ? 0.7 * k : 0.6 * k * pulse,
          );
        }
      }
      p.outlineShaded(
        actor.mask,
        actor.x,
        actor.y,
        color: (mx, my) =>
            math.sin(my * 0.7 - t * 14 + mx * 0.3) > 0.2 ? C[6] : C[4],
        alpha: (mx, my) => my / actor.h <= flood ? k : 0.0,
      );
      p.glow(0, actor.y + actor.h * 0.45, 30, C[4], 0.3 * k * pulse);
    }
    if (t < _stamp) {
      final q = t / _stamp;
      p.glow(0, _sy, 14 + 16 * q, C[5], 0.2 + 0.5 * q);
      if (q > 0.15) {
        ringFast(
          p,
          0,
          _sy,
          4 + 30 * (1 - Ease.inQuad(q)),
          1,
          q > 0.7 ? C[5] : q > 0.4 ? C[4] : C[3],
        );
      }
    }
    if (t >= _stamp && t < _break) {
      final u = (t - _stamp) / 0.1;
      final s = u < 1 ? 1.7 - 0.7 * Ease.inQuad(u) : 1.0;
      final land = t - _stamp - 0.1;
      final sq = land > 0
          ? 1 - 0.16 * math.exp(-land * 18) * math.cos(land * 40)
          : 1.0;
      final shake = t > _crack ? (t - _crack) * 4 : 0.0;
      final ox = (math.sin(t * 61) * shake + 0.5).floor().toDouble();
      final oy =
          land > 0 ? (math.sin(t * 3.4) * 1.2 + 0.5).floor().toDouble() : 0.0;
      _drawSkull(
        p,
        C,
        K,
        s,
        sq,
        ox,
        oy,
        t < _stamp + 0.067,
        smooth(_crack, _break, t),
      );
      final burn = smooth(_stamp + 0.1, _stamp + 0.25, t);
      if (u >= 1) {
        for (int i = 0; i < _eyes.length; i++) {
          final (ex, ey) = _eyes[i];
          _eyeFire(
            p,
            C,
            ox + ex,
            _sy + oy + ey,
            t,
            burn * (1 + 0.4 * smooth(_crack, _break, t)),
            i,
          );
        }
      }
      if (u < 1.2) sparkle(p, 0, _sy, 14 * (1 - u / 1.2), C[7], C[5], 0.6);
      p.glow(0, _sy, 26, C[4], 0.25);
    }
    final ru = (t - _stamp - 0.08) / 0.3;
    if (ru > 0 && ru < 1) {
      ringFastFn(
        p,
        0,
        _sy + 2,
        10 + 26 * Ease.outCubic(ru),
        math.max(1.0, 2.5 * (1 - ru)),
        (v, _) => v > 0.5 ? kWhite : C[6],
        1.2 - ru,
      );
    }
    bits.draw(p);
    puffs.draw(p, PuffKind.flame);
    ps.draw(p, 'front');
    for (final l in lights) {
      final q = l.life / l.max;
      p.glow(l.x, l.y, l.r * (0.6 + 0.4 * q), l.c, l.k * q * q);
    }
    if (t >= _stamp + 0.067 && t < _break) {
      unlight(p, -10, _sy - 10, 10, _sy + 10, (x, y) {
        final u = (x + _sw / 2).floor();
        final v = (y - _sy + _sh / 2).floor();
        return _inSkull(u, v) && _skullRows[v][u] != 'e';
      }, 0.2);
    }
  }
}

const Pose _cower = Pose(
  turn: 1,
  crouch: 6,
  lean: 2,
  hy: 1,
  fx: -6,
  fy: -38,
  bx: 7,
  by: -38,
  ffx: -4,
  fbx: 5,
);

final PixelEffect curseEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'shadow/curse',
    name: 'Curse',
    desc:
        'Wisps gather over the head, a skull stamps down with a flash, its eyes burn as the curse floods the body violet, then it cracks and crumbles.',
    category: 'shadow',
    kind: AssetKind.effect,
    tags: [
      'shadow',
      'curse',
      'debuff',
      'skull',
      'status',
      'dark',
      'magic',
      'one-shot',
    ],
    size: (112, 124),
    origin: (56, 108),
    duration: 3.4,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': kVoidPalette,
      'bone': ['#170f26', '#4a3a6e', '#7f6ea6', '#b3a4d4', '#e2d8f6'],
      'seed': 9,
    },
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      const PoseKey(-0.2, kReady),
      const PoseKey(
        0.3,
        Pose(
          turn: 0.9,
          hy: -1,
          fx: -9,
          fy: -19,
          bx: 10,
          by: -19,
          ffx: -3,
          fbx: 4,
        ),
      ),
      const PoseKey(0.55, _cower, PoseEase.snap),
      PoseKey(0.8, _cower.copyWith(crouch: 7)),
      PoseKey(1.2, _cower.copyWith(crouch: 6, lean: 3)),
      PoseKey(1.72, _cower.copyWith(crouch: 7, lean: 2)),
      const PoseKey(
        2.1,
        Pose(
          turn: 1,
          crouch: 4,
          lean: 3,
          hy: 2,
          fx: -8,
          fy: -15,
          bx: 9,
          by: -15,
          ffx: -4,
          fbx: 5,
        ),
      ),
      const PoseKey(
        2.9,
        Pose(
          turn: 1,
          crouch: 3,
          lean: 1,
          fx: -8,
          fy: -16,
          bx: 9,
          by: -16,
          ffx: -3,
          fbx: 4,
        ),
      ),
      const PoseKey(3.4, kReady),
    ],
    hits: const [HitSpec(t: 0.55, stop: 0.09, shake: 0.2, amp: 2)],
  ),
  onCreate: (o) => _CurseSim(o),
);
