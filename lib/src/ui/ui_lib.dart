// Helpers for the UI effects: big pixel words with a hand-made finish,
// a character lit or flashed by the effect, HUD plates and a whole-pixel shake.
// tintActor adapts the body flash of Sprite Fusion's open-source power-up
// (https://www.spritefusion.com/pixel-art-vfx/power-up), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

class SpelledLetter {
  final String ch;
  final PixelGlyph? g;
  final int x;
  final int w;
  final int h;

  const SpelledLetter({
    required this.ch,
    required this.g,
    required this.x,
    required this.w,
    required this.h,
  });
}

class SpelledWord {
  final List<SpelledLetter> letters;
  final int w;
  final int h;

  const SpelledWord({
    required this.letters,
    required this.w,
    required this.h,
  });
}

/// Lay out [str] left to right in font pixels.
SpelledWord spell(String str, [PixelFontKind font = PixelFontKind.big]) {
  final f = pixelFonts[font]!;
  final letters = <SpelledLetter>[];
  var x = 0;
  for (var i = 0; i < str.length; i++) {
    final ch = str[i];
    final g = f.glyphs[ch] ?? f.glyphs[ch.toUpperCase()];
    final w = g != null ? g.width : f.space;
    letters.add(SpelledLetter(ch: ch, g: g, x: x, w: w, h: f.height));
    x += w + f.gap;
  }
  return SpelledWord(letters: letters, w: math.max(0, x - f.gap), h: f.height);
}

class WordLetter {
  final PixelGlyph g;
  final double x;
  final double y;
  final double sx;
  final double sy;
  final double a;
  final double flash;
  final double slant;

  const WordLetter({
    required this.g,
    required this.x,
    required this.y,
    required this.sx,
    required this.sy,
    this.a = 1.0,
    this.flash = 0.0,
    this.slant = 0.0,
  });
}

class WordStyle {
  final List<int> fill;
  final int? edge;
  final int? under;
  final int outline;
  final int ow;
  final int? shadow;
  final double? shine;
  final double? shineY;
  final int? glint;

  const WordStyle({
    required this.fill,
    this.edge,
    this.under,
    required this.outline,
    this.ow = 1,
    this.shadow,
    this.shine,
    this.shineY,
    this.glint,
  });
}

Int16List _wordIds = Int16List(4096);
Uint8List _wordEdges = Uint8List(4096);

bool _rowBit(List<bool>? row, int idx) =>
    row != null && idx >= 0 && idx < row.length && row[idx];

/// Draw letters as one word with 1 px bevel, 1 px outline, drop shadow, optional diagonal shine & white flash.
void drawWord(Painter p, List<WordLetter> items, WordStyle st) {
  if (items.isEmpty) return;
  var x0d = double.infinity;
  var y0d = double.infinity;
  var x1d = double.negativeInfinity;
  var y1d = double.negativeInfinity;
  for (final it in items) {
    final h = it.g.rows.length * it.sy;
    final w = it.g.width * it.sx;
    final sl = it.slant.abs() * it.g.rows.length;
    x0d = math.min(x0d, it.x - sl);
    x1d = math.max(x1d, it.x + w + sl);
    y0d = math.min(y0d, it.y);
    y1d = math.max(y1d, it.y + h);
  }
  final ow = st.ow;
  final x0 = x0d.floor() - 1 - ow;
  final y0 = y0d.floor() - 1 - ow;
  final x1 = x1d.ceil() + 2 + ow;
  final y1 = y1d.ceil() + 3 + ow;
  final bw = x1 - x0;
  final bh = y1 - y0;
  if (bw * bh > _wordIds.length) {
    _wordIds = Int16List(bw * bh * 2);
    _wordEdges = Uint8List(bw * bh * 2);
  }
  _wordIds.fillRange(0, bw * bh, 0);

  for (var k = 0; k < items.length; k++) {
    final it = items[k];
    final g = it.g;
    final gh = g.rows.length;
    final h = gh * it.sy;
    final bot = it.y + h;
    final sl = it.slant;
    final pyEnd = bot.ceil();
    for (var py = it.y.floor(); py < pyEnd; py++) {
      final gy = ((py + 0.5 - it.y) / it.sy).floor();
      if (gy < 0 || gy >= gh) continue;
      final shift = (((bot - py - 0.5) / it.sy) * sl).round();
      final ry = py + 0.5 - it.y - gy * it.sy;
      final row = g.rows[gy];
      final pxEnd = (it.x + shift + g.width * it.sx).ceil();
      for (var px = (it.x + shift).floor() - 1; px <= pxEnd; px++) {
        final fx = px + 0.5 - it.x - shift;
        final gx = (fx / it.sx).floor();
        if (gx < 0 || gx >= g.width || !row[gx]) continue;
        final i = (py - y0) * bw + (px - x0);
        if (i < 0 || i >= bw * bh) continue;
        _wordIds[i] = k + 1;
        final rx = fx - gx * it.sx;
        final up = gy > 0 ? g.rows[gy - 1] : null;
        final dn = gy < gh - 1 ? g.rows[gy + 1] : null;
        bool open(List<bool>? r) =>
            r == null || (!_rowBit(r, gx) && !_rowBit(r, gx - 1) && !_rowBit(r, gx + 1));
        _wordEdges[i] = (ry < 1.0 && open(up) ? 1 : 0) |
            (ry >= it.sy - 1.0 && open(dn) ? 2 : 0) |
            (rx < 1.0 && !_rowBit(row, gx - 1) ? 4 : 0);
      }
    }
  }

  int at(int x, int y) =>
      (x < x0 || y < y0 || x >= x1 || y >= y1) ? 0 : _wordIds[(y - y0) * bw + (x - x0)];

  final fList = st.fill;
  final nF = fList.length;
  final shine = st.shine;
  final glint = st.glint ?? kWhite;
  final sy0 = st.shineY ?? y0.toDouble();

  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final id = at(x, y);
      if (id != 0) {
        final it = items[id - 1];
        final v = (y + 0.5 - it.y) / (it.g.rows.length * it.sy);
        final idx = math.min(nF - 1, math.max(0, ((1.0 - v) * nF).floor()));
        var c = fList[idx];
        final e = _wordEdges[(y - y0) * bw + (x - x0)];
        if ((e & 1) != 0) {
          c = st.edge ?? fList[nF - 1];
        } else if ((e & 2) != 0) {
          c = st.under ?? fList[0];
        } else if ((e & 4) != 0 && idx < nF - 1) {
          c = fList[idx + 1];
        }
        if (shine != null) {
          final d = (x + 0.5 - (y + 0.5 - sy0) * 0.6 - shine).abs();
          if (d < 1.1) {
            c = kWhite;
          } else if (d < 2.4) {
            c = glint;
          }
        }
        if (it.flash > 0.6 || (it.flash > 0.25 && v < 0.5)) c = kWhite;
        p.dot(x, y, c, it.a);
        continue;
      }
      var n = 0;
      for (var dy = -ow; dy <= ow && n == 0; dy++) {
        for (var dx = -ow; dx <= ow && n == 0; dx++) {
          if (ow < 2 || dx.abs() + dy.abs() < 4) n = at(x + dx, y + dy);
        }
      }
      if (n != 0) {
        p.dot(x, y, st.outline, items[n - 1].a);
        continue;
      }
      var s = at(x - ow, y - 1 - ow);
      if (s == 0) s = at(x + 1 - ow, y - 1 - ow);
      if (s == 0) s = at(x - ow, y - ow);
      if (s != 0 && st.shadow != null) {
        p.dot(x, y, st.shadow!, items[s - 1].a * 0.9);
      }
    }
  }
}

/// Flash a character in light: pixels recolored by brightness into [ramp].
void tintActor(Painter p, ActorDefinition? a, double k, List<int> ramp) {
  if (a == null || k <= 0.12) return;
  final m = a.mask;
  final pix = a.pixels;
  final cut = k > 0.6 ? 0.0 : (k > 0.3 ? 0.22 : 0.5);
  for (var j = 0; j < m.h; j++) {
    for (var i = 0; i < m.w; i++) {
      final q = j * m.w + i;
      if (m.data[q] == 0) continue;
      final l = luma(pix[q]);
      if (l < cut) continue;
      p.px(
        a.x + i,
        a.y + j,
        l > 0.5
            ? (k > 0.8 ? kWhite : ramp[2])
            : (l > 0.22 ? ramp[1] : ramp[0]),
      );
    }
  }
}

/// Light a character: warm additive light over its body and bright rim inside its dark outline.
void lightActor(
  Painter p,
  ActorDefinition? a,
  int c,
  double k, [
  double rim = 0.0,
  double t = 0.0,
]) {
  if (a == null || (k <= 0.01 && rim <= 0.01)) return;
  final m = a.mask;
  final pix = a.pixels;
  bool has(int i, int j) =>
      i >= 0 && j >= 0 && i < m.w && j < m.h && m.data[j * m.w + i] != 0;
  for (var j = 0; j < m.h; j++) {
    for (var i = 0; i < m.w; i++) {
      if (m.data[j * m.w + i] == 0) continue;
      if (k > 0.01) p.light(a.x + i, a.y + j, c, k * (1.1 - (0.5 * j) / m.h));
      if (rim <= 0.01 || !has(i - 1, j) || !has(i + 1, j) || !has(i, j - 1)) {
        continue;
      }
      if (has(i - 2, j) && has(i + 2, j) && has(i, j - 2)) continue;
      final f = rim * (0.75 + 0.35 * noise(j * 0.6 - t * 8.0, i * 3));
      if (f > 0.25) {
        final basePx = pix[j * m.w + i];
        p.px(a.x + i, a.y + j, mix(basePx != 0 ? basePx : c, c, math.min(0.85, f)));
      }
    }
  }
}

/// A glowing 1 px line just outside a character, flickering.
void haloActor(
  Painter p,
  ActorDefinition? a,
  int c,
  double k, [
  double t = 0.0,
]) {
  if (a == null || k <= 0.02) return;
  p.outlineShaded(
    a.mask,
    a.x,
    a.y,
    color: (_, _) => c,
    alpha: (mx, my) => k * (0.75 + 0.45 * noise(my * 0.45 - t * 7.0, mx * 3)),
  );
}

class PanelColors {
  final int outline;
  final int rim;
  final int top;
  final int body;
  final int low;

  const PanelColors({
    required this.outline,
    required this.rim,
    required this.top,
    required this.body,
    required this.low,
  });
}

void panel(
  Painter p,
  double x,
  double y,
  double w,
  double h,
  PanelColors col, {
  double r = 3.0,
  double a = 1.0,
  double? shine,
}) {
  if (w < 2.0 || h < 2.0) return;
  final x1 = x + w;
  final y1 = y + h;
  p.shade(x, y, x1, y1, (px, py, out) {
    final cx = math.max(x + r - px, math.max(0.0, px - (x1 - r)));
    final cy = math.max(y + r - py, math.max(0.0, py - (y1 - r)));
    final e = (cx > 0.0 && cy > 0.0)
        ? r - hypot(cx, cy)
        : math.min(math.min(px - x, x1 - px), math.min(py - y, y1 - py));
    if (e < 0.0) return null;
    out.a = a;
    if (e < 1.0) return col.outline;
    if (py - y < 2.0) return col.rim;
    if (y1 - py < 2.0) return col.low;
    if (shine != null) {
      final d = (px - (py - y) * 0.6 - shine).abs();
      if (d < 1.3) return kWhite;
      if (d < 3.0) return col.rim;
    }
    return py - y < h * 0.45 ? col.top : col.body;
  });
}

const List<String> kHeartSprite = [
  '..kkk...kkk..',
  '.khhok.khook.',
  'khwhookoooomk',
  'khwoooooooomk',
  'khoooooooommk',
  'kooooooooomdk',
  '.kooooooomdk.',
  '..kooooomdk..',
  '...kooomdk...',
  '....komdk....',
  '.....kdk.....',
  '......k......',
];

Map<String, Object> heartPal(List<int> c) => {
      'k': c[0],
      'w': kWhite,
      'h': c[5],
      'o': c[4],
      'm': c[3],
      'd': c[2],
    };

(int dx, int dy) shake(
  double t,
  double amp, [
  double t0 = 0.0,
  double len = 0.3,
  int seed = 1,
  double hz = 32.0,
]) {
  if (t < t0 || t > t0 + len) return (0, 0);
  final k = 1.0 - (t - t0) / len;
  return (
    (noise(t * hz, seed) * amp * k * 1.7).round(),
    (noise(t * hz, seed + 7) * amp * k * 1.3).round(),
  );
}
