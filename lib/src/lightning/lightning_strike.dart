// The stepped leader, the stroke flicker, the cooling channel and the scorch follow Sprite Fusion's open-source
// lightning (https://www.spritefusion.com/pixel-art-vfx/lightning), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'lightning_lib.dart';

const double _w = 120.0;
const double _top = -224.0;
const double _rx = 28.0;
const double _sy = 0.22;
const double _reach = 52.0;
const double _lead0 = 0.48;
const int _steps = 9;
const double _meet = -30.0;

const List<(double t, double k)> _strokes = [
  (0.76, 1.0),
  (1.04, 0.8),
  (1.26, 0.55),
];

const List<double> _flick = [1.0, 0.72, 0.3, 0.95, 0.5, 0.8, 0.22];

double _level(double a) {
  if (a < 0.0) return 0.0;
  final idx = (a * 30.0 + 1e-4).floor();
  return idx < _flick.length ? _flick[idx] : 0.0;
}

final int _night = hex('#04030a');
final int _dust = hex('#6e6382');
final int _ash = hex('#5b5566');
final List<int> _stoneCols = ramp(['#655b7a', '#4a4263', '#342d45']);
final double _s1 = _strokes[0].$1;

class _CrackBranch {
  final List<(double x, double y, double d)> pts;
  final double w;
  const _CrackBranch(this.pts, this.w);
}

List<_CrackBranch> _cracks(Rng r) {
  final out = <_CrackBranch>[];
  void grow(
    double x,
    double y,
    double a,
    double len,
    double w,
    double d,
    int depth,
  ) {
    final pts = <(double, double, double)>[(x, y, d)];
    for (var s = 0.0; s < len; s += 1.5) {
      a += r.range(-0.32, 0.32);
      x += math.cos(a) * 1.5;
      y = clamp(y + math.sin(a) * 0.45, 0.0, 5.0);
      d += 1.5;
      pts.add((x, y, d));
      if (depth < 2 && s > 3.0 && r.chance(0.09)) {
        grow(
          x,
          y,
          a + r.sign() * r.range(0.5, 1.2),
          (len - s) * r.range(0.3, 0.6),
          w * 0.6,
          d,
          depth + 1,
        );
      }
    }
    out.add(_CrackBranch(pts, w));
  }

  for (var i = 0; i < 6; i++) {
    grow(
      r.range(-1, 1),
      r.range(0, 1),
      i.isOdd ? r.range(-0.5, 0.7) : math.pi + r.range(-0.7, 0.5),
      _reach * r.range(0.55, 1.0),
      1.0,
      0.0,
      0,
    );
  }
  return out;
}

void _sigil(Painter p, double t, List<int> c, double k, bool near) {
  final reveal = clamp(t / 0.22);
  final spin = t * 0.8;
  final burnt = t > _s1 ? t - _s1 : -1.0;
  if (burnt > 0.45) return;
  final a0 = burnt < 0.0 ? 1.0 : (burnt < 0.07 ? 1.0 : 1.0 - (burnt - 0.07) / 0.38);
  final hot = burnt >= 0.0 && burnt < 0.07;
  bool on(double a) => (math.sin(a) >= 0.0) == near;
  double from(double a) =>
      (((((a - math.pi / 2.0) % tau) + tau + math.pi) % tau) - math.pi).abs() /
      math.pi;

  for (var i = 0; i < 22; i++) {
    final a = (i / 22.0) * tau + spin;
    if (!on(a) || from(a) > reveal) continue;
    for (final da in const [0.0, 0.06, 0.12]) {
      final x = math.cos(a + da) * _rx;
      final y = math.sin(a + da) * _rx * _sy;
      p.dot(
        x,
        y,
        hot
            ? kWhite
            : (near
                ? (k > 0.7 ? c[6] : c[5])
                : (k > 0.7 ? c[4] : c[3])),
        a0,
      );
      if (near) p.dot(x, y + 1.0, hot ? c[6] : c[2], a0);
    }
    if (i % 3 == 0) {
      p.glow(math.cos(a) * _rx, math.sin(a) * _rx * _sy, 5, c[4], 0.3 * k * a0);
    }
  }
  for (var j = 0; j < 4; j++) {
    final a = spin * -0.5 + (j * tau) / 4.0 + math.pi / 4.0;
    if (!on(a) || reveal < 1.0) continue;
    p.line(
      math.cos(a) * (_rx - 5.0),
      math.sin(a) * (_rx - 5.0) * _sy,
      math.cos(a) * (_rx + 5.0),
      math.sin(a) * (_rx + 5.0) * _sy,
      hot ? kWhite : (near ? c[6] : c[4]),
      a0,
    );
  }
  if (t > 0.3) {
    final alpha = a0 * clamp((t - 0.3) / 0.12);
    for (var a = 0.0; a < tau; a += 0.09) {
      if (!on(a)) continue;
      p.dot(math.cos(a) * 14.0, math.sin(a) * 14.0 * _sy,
          hot ? kWhite : (near ? c[4] : c[2]), alpha);
    }
  }
  if (near && burnt < 0.0) {
    final pulse = 0.6 + 0.4 * math.sin(t * (10.0 + 30.0 * k));
    p.px(0, 0, k > 0.5 ? kWhite : c[6]);
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, -1)]) {
      p.px(dx, dy, c[5]);
    }
    p.glow(0, -1, 10.0 + 10.0 * k, c[5], 0.3 + 0.4 * k * pulse);
  }
}

BoltTree _keep(BoltTree b) {
  final paths = <BoltPath>[];
  for (final q in b.paths) {
    final pts = <Point2>[];
    for (final pt in q.pts) {
      if (pt.$1.abs() > _w - 5.0 || pt.$2 > -3.0 || pt.$2 < _top + 6.0) break;
      pts.add(pt);
    }
    if (q.w >= 1.0 || pts.length > 3) {
      paths.add(BoltPath(q.w >= 1.0 ? q.pts : pts, q.w));
    }
  }
  return BoltTree(paths);
}

class _LightningStrikeSim extends BaseEffectSim {
  final List<int> c;
  final int seed;
  final Rng r;
  late final Particles ps;
  late final Particles hot;
  final Lights lights = Lights();
  late final double x0;
  late final BoltTree main;
  late final List<BoltTree> bolts;
  late final List<_CrackBranch> tree;
  late final List<double> gone;
  double t = 0.0;
  int struck = -1;

  _LightningStrikeSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        seed = o.seed,
        r = Rng(o.seed) {
    ps = Particles(
        rng: r,
        ground: (_) => 0.0,
        sparks: (o['sparks'] as List).cast<Object>());
    hot = Particles(rng: r, ground: (_) => 0.0);
    x0 = r.range(8.0, 18.0) * (r.chance(0.5) ? 1.0 : -1.0);
    main = _keep(zigzag(r, x0, _top, 0.0, -1.0, 0.17, 0.5));
    final trunk = main.paths[0].pts;
    Point2 Function(double, double) driftFn(double dx) =>
        (x, y) => (x + dx * math.sin((math.pi * y) / _top), y);
    bolts = [
      main,
      bendBolt(BoltTree([BoltPath(trunk, 1.0)]), driftFn(1.5)),
      bendBolt(BoltTree([BoltPath(trunk, 1.0)]), driftFn(3.0)),
    ];
    final last = _strokes.last;
    final end = _chan(_strokes.length - 1);
    tree = _cracks(r);
    gone = [
      for (var i = 0; i < end.length; i++)
        last.$1 +
            0.25 +
            0.75 * (0.55 * rand(seed, i, 5) + 0.45 * (1.0 - end[i].$2 / _top)),
    ];
  }

  List<Point2> _chan(int i) => bolts[i].paths[0].pts;

  ({int i, double t, double k0, double a, double k})? _now() {
    for (var i = _strokes.length - 1; i >= 0; i--) {
      final (st, sk) = _strokes[i];
      if (t >= st) {
        final a = t - st;
        return (i: i, t: st, k0: sk, a: a, k: _level(a) * sk);
      }
    }
    return null;
  }

  double _charge() => math.pow(clamp(t / _s1), 1.5).toDouble();

  double _heatAt() {
    if (struck < 0) return 0.0;
    var best = 0.0;
    for (var i = 0; i <= struck; i++) {
      final (st, sk) = _strokes[i];
      final v = sk * math.pow(clamp(1.0 - (t - st) / 1.6), 1.4).toDouble();
      if (v > best) best = v;
    }
    return best;
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    for (var i = 0; i < _strokes.length; i++) {
      final (st, k) = _strokes[i];
      if (struck >= i || t < st) continue;
      struck = i;
      lights.add(0, -50, 120, c[4], 0.55 * k, 0.4);
      lights.add(0, -3, 24, kWhite, 0.5 * k, 0.1);
      for (var j = 0; j < (44 * k).round(); j++) {
        final a = -math.pi / 2.0 + r.range(-1.3, 1.3);
        final sp = r.range(110, 320) * (0.65 + 0.35 * k);
        ps.spawn(P.spark, r.range(-1.5, 1.5), -2, math.cos(a) * sp,
            math.sin(a) * sp, r.range(0.2, 0.55));
      }
      for (var j = 0; j < (12 * k).round(); j++) {
        final a = -math.pi / 2.0 + r.range(-1.2, 1.2);
        final sp = r.range(70, 220);
        hot.spawn(P.spark, r.range(-2, 2), -1, math.cos(a) * sp,
            math.sin(a) * sp, r.range(0.5, 1.0));
      }
      for (var j = 0; j < (5 * k).round(); j++) {
        hot.spawn(P.ember, r.range(-4, 4), -2, r.range(-25, 25),
            -r.range(30, 80), r.range(0.8, 1.5));
      }
      for (var j = 0; j < (18 * k).round(); j++) {
        final a = -math.pi / 2.0 + r.range(-1.1, 1.1);
        final sp = r.range(50, 190);
        ps.spawn(P.grit, r.range(-3, 3), -1, math.cos(a) * sp, math.sin(a) * sp,
            r.range(1.0, 1.5), r.pick(_stoneCols), r.chance(0.35) ? 2.0 : 1.0);
      }
      for (var j = 0; j < 8; j++) {
        ps.spawn(P.dust, r.range(-3, 3), -1, r.sign() * r.range(30, 110),
            -r.range(4, 24), r.range(0.4, 0.8), _dust, r.range(1.5, 3.0));
      }
      for (var j = 0; j < (4 * k).round(); j++) {
        ps.spawn(
            P.smoke,
            r.range(-8, 8),
            -4,
            r.range(-10, 10),
            -r.range(10, 25),
            r.range(1.1, 1.6),
            mix(_ash, c[2], 0.3),
            r.range(3, 6),
            r.range(0.05, 0.25));
      }
    }
    if (struck >= 0 && t < 1.7 && r.chance(6.0 * dt)) {
      ps.spawn(P.smoke, r.range(-8, 8), -2, r.range(-4, 4), -r.range(9, 17),
          r.range(1.0, 1.3), 0, r.range(2, 3.5));
    }
    final end = _chan(_strokes.length - 1);
    for (var i = 0; i < gone.length - 1; i++) {
      if (gone[i] <= t && gone[i] > t - dt && rand(seed, i, 6) < 0.5) {
        final (x, y) = end[i];
        ps.spawn(P.mote, x, y, r.range(-8, 8), r.range(6, 22),
            r.range(0.4, 0.8), r.chance(0.5) ? c[5] : c[4], r.range(0.5, 0.9));
      }
    }
    ps.update(dt);
    hot.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final dark = 0.5 *
        smooth(0.46, 0.66, t) *
        (1.0 - smooth(_s1 - 0.01, _s1 + 0.02, t));
    if (dark > 0.01) {
      for (var y = -228; y < 36; y++) {
        for (var x = -_w.toInt(); x < _w.toInt(); x++) {
          final d = hypot(x / _w, (y + 96.0) / 132.0);
          final a = dark * (1.0 - smooth(0.55, 1.0, d));
          if (a > 0.01) p.blend(x + 0.5, y + 0.5, _night, a);
        }
      }
    }
    _sigil(p, t, c, _charge(), false);
    if (struck >= 0) {
      final s = _now()!;
      final front = _reach * Ease.outCubic(clamp((t - _s1) / 0.35));
      final t0 = _heatAt();
      final fade = 1.0 - smooth(2.3, 2.95, t);
      final elec = s.a < 0.14 ? s.k0 * (1.0 - s.a / 0.14) : 0.0;
      for (final br in tree) {
        for (final (x, y, d) in br.pts) {
          if (d > front) break;
          final q = d / _reach;
          final n = rand((x * 2.0).round(), (y * 2.0).round(), 9);
          final fresh = d > front - 6.0 && front < _reach;
          final temp = t0 * (1.15 - q) * (br.w < 1.0 ? 0.8 : 1.0) - n * 0.25;
          final col = fresh || (elec > 0.3 && n < 0.85)
              ? (q < 0.5 ? kWhite : c[6])
              : (heatColor(temp) != 0 ? heatColor(temp) : kLightningSoot2);
          p.dot(x, y + 1.0, kLightningSoot, fade);
          p.dot(x, y, col, fade);
          if (br.w >= 1.0 && d < 9.0) p.dot(x, y + 2.0, kLightningSoot, fade);
          if ((fresh || elec > 0.3) && (d.round() & 3) == 0) {
            p.glow(x, y, 7, c[5], 0.4);
          } else if (temp > 0.2 && (d.round() & 3) == 0) {
            p.glow(x, y, 5, col, 0.2 * temp);
          }
        }
      }
      lightningScorch(p, 0, 0, 12, t0, fade);
      if (t0 > 0.0) p.glow(0, -2, 34, heatColor(0.55), 0.3 * t0);
    }
    ps.draw(p, 'back');
    hot.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final s = _now();
    final f = (t * 30.0 + 1e-4).floor();
    final k = _charge();
    _sigil(p, t, c, k, true);

    if (t > 0.15 && t < _s1) {
      final rNow = rng(seed, 61, f);
      final count = (1.0 + 4.0 * k).round();
      for (var i = 0; i < count; i++) {
        final a = rNow.range(0, tau);
        final x = math.cos(a) * _rx;
        final y = math.sin(a) * _rx * _sy;
        crackle(
          p,
          zigzag(rNow, x, y, x + rNow.range(-2.5, 2.5),
              y - rNow.range(4, 9) * (0.6 + k), 0.45, 0.3),
          0.45 + 0.4 * k,
          c,
          0.3,
        );
      }
      p.glow(0, -2, 36, c[4], 0.12 + 0.3 * k);
    }

    if (t >= _lead0 && t < _s1) {
      final u = clamp((t - _lead0) / (_s1 - _lead0));
      final st = math.min(_steps, (u * _steps).floor() + 1);
      final fresh = 1.0 - ((u * _steps) % 1.0);
      final reach = _top + (_meet - _top) * math.pow(st / _steps, 1.2);
      final prev = _top + (_meet - _top) * math.pow((st - 1) / _steps, 1.2);
      for (final q in main.paths) {
        final tk = q.w >= 1.0;
        for (var i = 0; i < q.pts.length - 1; i++) {
          final (ax, ay) = q.pts[i];
          final (bx, by) = q.pts[i + 1];
          if (by > reach) {
            if (ay <= reach && i > 0) {
              p.px(ax, ay, kWhite);
              p.glow(ax, ay, 7, c[5], 0.5 * fresh + 0.15);
            }
            break;
          }
          final young = by > prev;
          p.line(
            ax,
            ay,
            bx,
            by,
            young
                ? (fresh > 0.4 ? (tk ? c[6] : c[5]) : c[4])
                : (tk ? c[3] : c[2]),
          );
          if (i % 4 == 0 && ay > _top + 14.0) {
            p.glow(ax, ay, young ? 8 : 5, c[4],
                young ? 0.3 * fresh + 0.1 : 0.12);
          }
        }
      }
      if (t > 0.62) {
        final h = -_meet * Ease.outQuad((t - 0.62) / (_s1 - 0.62));
        final rNow = rng(seed, 77, f);
        final b = zigzag(
            rNow, 0, -1, rNow.range(-2, 2), -math.max(3.0, h), 0.3, 0.3);
        final tip = b.paths[0].pts.last;
        crackle(p, b, 0.85, c, 0.45);
        p.px(tip.$1, tip.$2, kWhite);
        p.glow(tip.$1, tip.$2, 9, c[5], 0.5);
      }
    }

    int? nextIdx;
    for (var i = 0; i < _strokes.length; i++) {
      if (_strokes[i].$1 > t) {
        nextIdx = i;
        break;
      }
    }
    if (nextIdx != null && nextIdx != 0 && t > _strokes[nextIdx].$1 - 0.06) {
      final tr = _chan(nextIdx);
      final u = (t - (_strokes[nextIdx].$1 - 0.06)) / 0.06;
      final i1 = (u * tr.length).floor();
      traceBolt(p, tr, c[3]);
      traceBolt(p, tr, c[6], 1.0, i1 - 18, i1);
      for (var i = math.max(0, i1 - 18); i < math.min(tr.length, i1); i += 4) {
        if (tr[i].$2 > _top + 14.0) p.glow(tr[i].$1, tr[i].$2, 9, c[4], 0.35);
      }
    } else if (s != null && s.k > 0.0) {
      final hero = s.i == 0 && s.a < 1.0 / 30.0;
      boltStroke(
        p,
        bolts[s.i],
        s.k,
        c,
        s.i == 0 ? 1.5 : 1.2,
        hero,
        0.5,
        1.0,
        s.k > 0.6 ? (hero ? 1.2 : 0.8) : 0.0,
        _top + 14.0,
      );
      final rRad = 4.5 * s.k;
      p.circle(0, -1, rRad + 1.5, c[2]);
      p.circle(0, -1, rRad + 0.5, c[5]);
      p.circle(0, -1, rRad * 0.65, kWhite);
      if (s.a < 0.07) {
        sparkle(p, 0, -2, (12.0 * s.k * (1.0 - s.a / 0.07)).roundToDouble(),
            c[6], c[4], 0.25);
      }
      p.glow(0, -16, 96, c[3], 0.42 * s.k);
      p.glow(0, -3, 22, c[5], 0.3 * s.k);
      if (hero) p.glow(x0 * 0.5, -110, 170, c[3], 0.3);
    } else if (s != null) {
      final last = _strokes.last;
      final crumble = s.i == _strokes.length - 1;
      final cool = clamp((s.a - 0.23) / 0.45);
      final tr = _chan(s.i);
      for (var i = 0; i < tr.length - 1; i++) {
        if (crumble && t >= gone[i]) continue;
        final h = crumble
            ? 1.0 - clamp((t - last.$1 - 0.23) / (gone[i] - last.$1 - 0.23))
            : 1.0 - cool;
        p.line(
          tr[i].$1,
          tr[i].$2,
          tr[i + 1].$1,
          tr[i + 1].$2,
          h > 0.7 ? c[5] : (h > 0.4 ? c[4] : (h > 0.15 ? c[3] : c[2])),
        );
        if (i % 6 == 0 && h > 0.3 && tr[i].$2 > _top + 14.0) {
          p.glow(tr[i].$1, tr[i].$2, 6, c[4], 0.15 * h);
        }
      }
    }

    if (s != null && s.a < 0.4) {
      final rNow = rng(seed, 91, f);
      final run = s.i == 0
          ? _reach * Ease.outCubic(clamp(s.a / 0.35))
          : _reach * clamp(s.a / 0.22);
      for (final br in tree) {
        if (br.w < 1.0 || rNow.next() < 0.3) continue;
        final i1 = br.pts.indexWhere((pt) => pt.$3 > run);
        final j1 = i1 < 0 ? br.pts.length : i1;
        final j0 = math.max(0, j1 - rNow.intRange(7, 13));
        final pts = [
          for (var idx = j0; idx < j1; idx++)
            (
              br.pts[idx].$1 + rNow.range(-0.6, 0.6),
              br.pts[idx].$2 - 1.5 - rNow.range(0.0, 2.5),
            ),
        ];
        if (pts.length > 1) {
          crackle(
            p,
            BoltTree([BoltPath(pts, 1.0)]),
            0.9 * (1.0 - s.a / 0.4) + 0.1,
            c,
            0.35,
          );
        }
      }
    }

    ps.draw(p, 'front');
    hot.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect lightningStrikeEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'lightning/lightning-strike',
    name: 'Lightning strike',
    desc:
        'A targeted strike: a sigil charges on the floor, the scene darkens, a thick bolt slams into it, arcs race out along the cracks it splits, the channel crumbles to a scorch.',
    category: 'lightning',
    tags: [
      'lightning', 'electric', 'strike', 'spell',
      'target', 'impact', 'ground', 'one-shot',
    ],
    size: (240, 264),
    origin: (120, 228),
    duration: 3.0,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': voltPalette,
      'sparks': plasmaSparks,
      'seed': 5,
    },
  ),
  onCreate: (o) => _LightningStrikeSim(o),
);
