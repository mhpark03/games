import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../../services/ad_service.dart';

/// Marble Sort Game

const List<Color> _colors = [
  Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047),
  Color(0xFFFDD835), Color(0xFF8E24AA), Color(0xFFFF6D00),
  Color(0xFF00ACC1), Color(0xFFD81B60),
];

const int _nSlots = 30;
const int _gridCols = 4;

/// 통일된 사이즈 계산
double _calcBSz(double pw, double h) => min((pw - 4.0 * 5) / 6, h * 0.065);
double _calcMR(double pw, double h) => max(_calcBSz(pw, h) * 0.24, 8.0);
double _calcBasketH(double mR) => mR * 3.8;

class MBox {
  final int colorIndex;
  bool released;
  MBox(this.colorIndex, [this.released = false]);
}

class Basket {
  final int colorIndex;
  int filled;
  int col, row;
  double slideY;
  Basket(this.colorIndex, this.col, this.row, [this.filled = 0, this.slideY = 0]);
  bool get full => filled >= 3;
  bool get done => filled >= 3;
}

class _Drop {
  final int colorIndex;
  double x, y, targetX, targetY;
  _Drop(this.colorIndex, this.x, this.y, this.targetX, this.targetY);
}

class _FunnelM {
  final int colorIndex, targetSlot;
  double progress;
  _FunnelM(this.colorIndex, this.targetSlot, this.progress);
}

class _Fx { final int col, row; double life; _Fx(this.col, this.row) : life = 1.0; }

class _ClearAnim {
  final int colorIndex, col, row, dir;
  double progress;
  _ClearAnim(this.colorIndex, this.col, this.row, this.dir, [this.progress = 0]);
}

/// Stadium track
class _Geo {
  final double cx, cy, halfW, r;
  late final double total, s1, s2, s3, s4;

  _Geo(this.cx, this.cy, this.halfW, this.r) {
    final cap = pi * r;
    total = 4 * halfW + 2 * cap;
    s1 = halfW / total;
    s2 = (halfW + cap) / total;
    s3 = (halfW + cap + 2 * halfW) / total;
    s4 = (halfW + cap + 2 * halfW + cap) / total;
  }

  Offset pos(double t) {
    t = t % 1.0; if (t < 0) t += 1;
    if (t <= s1) return Offset(cx + (t / s1) * halfW, cy - r);
    else if (t <= s2) {
      final a = -pi / 2 + ((t - s1) / (s2 - s1)) * pi;
      return Offset(cx + halfW + r * cos(a), cy + r * sin(a));
    } else if (t <= s3) {
      final f = (t - s2) / (s3 - s2);
      return Offset(cx + halfW - f * 2 * halfW, cy + r);
    } else if (t <= s4) {
      final a = pi / 2 + ((t - s3) / (s4 - s3)) * pi;
      return Offset(cx - halfW + r * cos(a), cy + r * sin(a));
    } else {
      final f = (t - s4) / (1.0 - s4);
      return Offset(cx - halfW + f * halfW, cy - r);
    }
  }

  bool isBottom(double t) { t = t % 1.0; if (t < 0) t += 1; return t >= s2 && t <= s3; }
}

class MarbleSortScreen extends StatefulWidget {
  final int startLevel;
  const MarbleSortScreen({super.key, this.startLevel = 1});
  @override
  State<MarbleSortScreen> createState() => _MarbleSortScreenState();
}

class _MarbleSortScreenState extends State<MarbleSortScreen> {
  int level = 1, score = 0, hiScore = 0, lives = 3;
  bool playing = false, over = false;

  List<MBox> boxes = [];
  List<Basket> baskets = [];
  List<int?> slots = List.filled(_nSlots, null);
  double trackOffset = 0;
  List<_Drop> dropping = [];
  List<_FunnelM> funneling = [];
  List<_ClearAnim> clearing = [];
  double speed = 0.002;
  Timer? loop;
  int combo = 0;
  String? comboTxt;
  double comboAlpha = 0;
  List<_Fx> fx = [];
  Size sz = Size.zero;
  _Geo? geo;
  double boxBottom = 0;
  int _clearDir = 1;

  int get nColors => min(3 + (level - 1) ~/ 2, 8);
  int get _emptySlots => slots.where((s) => s == null).length - funneling.length;

  @override
  void initState() { super.initState(); level = widget.startLevel; _start(); }
  @override
  void dispose() { loop?.cancel(); super.dispose(); }

  void _start() {
    final r = Random();
    final n = nColors;
    boxes = List.generate(n, (i) => MBox(i))..shuffle(r);
    final raw = <Basket>[];
    for (int c = 0; c < n; c++) for (int j = 0; j < 3; j++) raw.add(Basket(c, 0, 0));
    raw.shuffle(r);
    for (int i = 0; i < raw.length; i++) { raw[i].col = i % _gridCols; raw[i].row = i ~/ _gridCols; }
    baskets = raw;
    slots = List.filled(_nSlots, null);
    dropping = []; funneling = []; clearing = []; fx = [];
    combo = 0; comboTxt = null; comboAlpha = 0;
    trackOffset = 0; _clearDir = 1;
    speed = 0.0012 + level * 0.0003;
    if (speed > 0.005) speed = 0.005;
    playing = true; over = false;
    loop?.cancel();
    loop = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _tick() {
    if (!playing && clearing.isEmpty) return;
    setState(() {
      trackOffset -= speed;
      if (trackOffset < 0) trackOffset += 1;

      for (int i = funneling.length - 1; i >= 0; i--) {
        final fm = funneling[i];
        fm.progress += 0.055;
        if (fm.progress >= 1.0) {
          if (fm.targetSlot >= 0 && fm.targetSlot < _nSlots && slots[fm.targetSlot] == null)
            slots[fm.targetSlot] = fm.colorIndex;
          funneling.removeAt(i);
        }
      }

      if (playing) _autoCheck();

      for (int i = dropping.length - 1; i >= 0; i--) {
        final d = dropping[i]; d.y += 10; d.x += (d.targetX - d.x) * 0.15;
        if (d.y >= d.targetY) dropping.removeAt(i);
      }

      for (int i = clearing.length - 1; i >= 0; i--) {
        clearing[i].progress += 0.035;
        if (clearing[i].progress >= 1.0) {
          final ca = clearing.removeAt(i);
          for (final b in baskets) {
            if (b.col == ca.col && b.row > ca.row) { b.row--; b.slideY = 1.0; }
          }
        }
      }

      for (final b in baskets) { if (b.slideY > 0) { b.slideY -= 0.08; if (b.slideY < 0) b.slideY = 0; } }
      for (int i = fx.length - 1; i >= 0; i--) { fx[i].life -= 0.025; if (fx[i].life <= 0) fx.removeAt(i); }
      if (comboAlpha > 0) { comboAlpha -= 0.015; if (comboAlpha < 0) comboAlpha = 0; }
    });
  }

  void _autoCheck() {
    if (geo == null) return;
    final g = geo!;
    final margin = sz.width * 0.03, pw = sz.width - margin * 2;
    final bw = (pw - 4.0 * (_gridCols - 1)) / _gridCols;
    final threshold = bw * 0.2;

    final topPerCol = <int, Basket>{};
    for (int col = 0; col < _gridCols; col++) {
      Basket? top;
      for (final b in baskets) { if (b.col != col || b.full) continue; if (top == null || b.row < top.row) top = b; }
      if (top != null) topPerCol[col] = top;
    }

    for (int i = 0; i < _nSlots; i++) {
      if (slots[i] == null) continue;
      final t = (i / _nSlots + trackOffset) % 1.0;
      if (!g.isBottom(t)) continue;
      final pos = g.pos(t);
      final ci = slots[i]!;

      Basket? bestB; double bestDist = threshold;
      for (final entry in topPerCol.entries) {
        final b = entry.value;
        if (b.colorIndex != ci) continue;
        final bc = _basketCenterFor(b.col, b.row);
        final dx = (pos.dx - bc.dx).abs();
        if (dx < bestDist) { bestDist = dx; bestB = b; }
      }

      if (bestB != null) {
        slots[i] = null;
        bestB.filled++;
        score += 10 * (1 + combo); combo++;
        if (combo >= 3) { comboTxt = 'Combo x$combo!'; comboAlpha = 1; }
        if (bestB.done) {
          score += 50 * level; fx.add(_Fx(bestB.col, bestB.row));
          _clearDir *= -1;
          clearing.add(_ClearAnim(bestB.colorIndex, bestB.col, bestB.row, _clearDir));
          baskets.remove(bestB);
          topPerCol.remove(bestB.col);
          Basket? newTop;
          for (final b in baskets) { if (b.col != bestB.col || b.full) continue; if (newTop == null || b.row < newTop.row) newTop = b; }
          if (newTop != null) topPerCol[bestB.col] = newTop;
        }
        if (baskets.isEmpty) {
          playing = false; loop?.cancel();
          if (score > hiScore) hiScore = score;
          Future.delayed(const Duration(milliseconds: 600), () => _showClear());
        }
      }
    }
  }

  void _tap(Offset p) { if (!playing) return; _tapBox(p); }

  void _tapBox(Offset p) {
    final w = sz.width, margin = w * 0.03, pw = w - margin * 2;
    final topH = sz.height * 0.05, top = topH + 2;
    final cols = min(boxes.length, 6);
    const gap = 4.0;
    final bSz = _calcBSz(pw, sz.height);
    final tw = cols * bSz + (cols - 1) * gap;
    final sx = margin + (pw - tw) / 2;
    for (int i = 0; i < boxes.length; i++) {
      if (boxes[i].released) continue;
      final c = i % cols, r = i ~/ cols;
      final bx = sx + c * (bSz + gap), by = top + r * (bSz + gap);
      if (p.dx >= bx && p.dx <= bx + bSz && p.dy >= by && p.dy <= by + bSz) {
        if (_emptySlots >= 9) _releaseBox(i);
        return;
      }
    }
  }

  void _releaseBox(int boxIdx) {
    boxes[boxIdx].released = true;
    final ci = boxes[boxIdx].colorIndex;
    final indices = List.generate(_nSlots, (i) => i);
    indices.sort((a, b) {
      final ta = (a / _nSlots + trackOffset) % 1.0, tb = (b / _nSlots + trackOffset) % 1.0;
      return min(ta, 1 - ta).compareTo(min(tb, 1 - tb));
    });
    int filled = 0;
    for (final idx in indices) {
      if (filled >= 9) break;
      if (slots[idx] != null || funneling.any((f) => f.targetSlot == idx)) continue;
      funneling.add(_FunnelM(ci, idx, -filled * 0.12));
      filled++;
    }
  }

  Offset _basketCenterFor(int col, int row) {
    final margin = sz.width * 0.03, pw = sz.width - margin * 2;
    const gap = 4.0;
    final bw = (pw - gap * (_gridCols - 1)) / _gridCols;
    final mR = _calcMR(pw, sz.height);
    final bh = _calcBasketH(mR);
    final maxRows = _maxRow + 1;
    final x = margin + col * (bw + gap) + bw / 2;
    final basketTop = sz.height - 4 - maxRows * bh - (maxRows - 1) * gap;
    final y = basketTop + row * (bh + gap) + bh / 2;
    return Offset(x, y);
  }

  int get _maxRow {
    int m = 0;
    for (final b in baskets) { if (b.row > m) m = b.row; }
    for (final c in clearing) { if (c.row > m) m = c.row; }
    return m;
  }

  void _showClear() {
    showDialog(context: context, barrierDismissible: false, builder: (c) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.amber.withValues(alpha: 0.5), width: 2)),
      title: Text('games.marbleSort.levelClear'.tr(), textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('games.marbleSort.levelValue'.tr(namedArgs: {'level': '$level'}),
            style: const TextStyle(color: Colors.white70, fontSize: 18)),
        const SizedBox(height: 8),
        Text('games.marbleSort.scoreValue'.tr(namedArgs: {'score': '$score'}),
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      ]),
      actions: [
        TextButton(onPressed: () { Navigator.pop(c); Navigator.pop(c); },
            child: Text('app.close'.tr(), style: const TextStyle(color: Colors.grey))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () { Navigator.pop(c); setState(() { level++; _start(); }); },
            child: Text('games.marbleSort.nextLevel'.tr(), style: const TextStyle(color: Colors.black))),
      ],
    ));
  }

  void _showOver() {
    if (score > hiScore) hiScore = score;
    showDialog(context: context, barrierDismissible: false, builder: (c) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.5), width: 2)),
      title: Text('common.gameOver'.tr(), textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('games.marbleSort.finalScore'.tr(namedArgs: {'score': '$score'}),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('games.marbleSort.highScoreLabel'.tr(namedArgs: {'score': '$hiScore'}),
            style: const TextStyle(color: Colors.amber, fontSize: 16)),
      ]),
      actions: [
        TextButton(onPressed: () { Navigator.pop(c); Navigator.pop(c); },
            child: Text('app.close'.tr(), style: const TextStyle(color: Colors.grey))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () { Navigator.pop(c); setState(() { score = 0; lives = 3; level = 1; _start(); }); },
            child: Text('common.tryAgain'.tr(), style: const TextStyle(color: Colors.black))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(child: GestureDetector(
        onTapDown: (d) => _tap(d.localPosition),
        child: LayoutBuilder(builder: (ctx, cons) {
          sz = Size(cons.maxWidth, cons.maxHeight);
          return CustomPaint(
            painter: _P(
              boxes: boxes, baskets: baskets, slots: slots,
              trackOffset: trackOffset, dropping: dropping, funneling: funneling,
              clearing: clearing, fx: fx, comboTxt: comboTxt, comboAlpha: comboAlpha,
              score: score, level: level, lives: lives,
              onGeo: (g) { geo = g; }, onBoxBot: (v) { boxBottom = v; },
            ),
            size: sz,
            child: SizedBox(width: sz.width, height: sz.height, child: Stack(children: [
              Positioned(top: 4, left: 4, child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 22),
                  onPressed: () => Navigator.pop(context))),
              if (playing && lives <= 1)
                Positioned(top: 4, right: 4, child: IconButton(
                    icon: const Icon(Icons.favorite_border, color: Colors.green, size: 24),
                    onPressed: () {
                      showDialog(context: context, builder: (c) => AlertDialog(
                        backgroundColor: Colors.grey.shade900,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('games.marbleSort.extraLife'.tr(), style: const TextStyle(color: Colors.green)),
                        content: Text('games.marbleSort.extraLifeMessage'.tr(), style: const TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c),
                              child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.grey))),
                          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () async {
                              Navigator.pop(c);
                              final ad = AdService();
                              final ok = await ad.showRewardedAd(onUserEarnedReward: (_, __) { setState(() { lives++; }); });
                              if (!ok && mounted) { setState(() { lives++; }); ad.loadRewardedAd(); }
                            },
                            child: Text('common.watchAd'.tr(), style: const TextStyle(color: Colors.white))),
                        ],
                      ));
                    })),
            ])),
          );
        }),
      )),
    );
  }
}

// ─── Painter ───────────────────────────────────────────────────

class _P extends CustomPainter {
  final List<MBox> boxes;
  final List<Basket> baskets;
  final List<int?> slots;
  final double trackOffset;
  final List<_Drop> dropping;
  final List<_FunnelM> funneling;
  final List<_ClearAnim> clearing;
  final List<_Fx> fx;
  final String? comboTxt;
  final double comboAlpha;
  final int score, level, lives;
  final void Function(_Geo) onGeo;
  final void Function(double) onBoxBot;

  _P({required this.boxes, required this.baskets, required this.slots,
    required this.trackOffset, required this.dropping, required this.funneling,
    required this.clearing, required this.fx, required this.comboTxt,
    required this.comboAlpha, required this.score, required this.level,
    required this.lives, required this.onGeo, required this.onBoxBot});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final mg = w * 0.03, pw = w - mg * 2;
    final barH = h * 0.05;

    // ── 통일 사이즈 ──
    final bSz = _calcBSz(pw, h);       // 박스 크기 (6열 기준)
    final mR = _calcMR(pw, h);          // 구슬 반지름 (통일)
    final bktH = _calcBasketH(mR);      // 바구니 블록 높이

    // ── Box area ──
    final cols = min(boxes.length, 6);
    final bxRows = (boxes.length / cols).ceil();
    const bGap = 4.0;
    final bTop = barH + 2;
    final bBot = bTop + bxRows * bSz + (bxRows - 1) * bGap;
    final boxTotalW = cols * bSz + (cols - 1) * bGap;
    onBoxBot(bBot + 4);

    // ── Track ── (벨트 두께를 구슬에 맞춤)
    final trackW = mR * 3.2;           // 트랙 밴드 두께
    final halfW = pw * 0.44;
    final capR = max(halfW / (2 * pi), mR * 1.8); // 최소 구슬 2배
    final tCy = bBot + 24 + capR;
    final g = _Geo(w / 2, tCy, halfW, capR);
    onGeo(g);

    // ── Basket area ──
    final kTop = tCy + capR + 12;
    final kH = h - kTop - 4;
    int maxRow = 0;
    for (final b in baskets) { if (b.row > maxRow) maxRow = b.row; }
    for (final c in clearing) { if (c.row > maxRow) maxRow = c.row; }
    final maxRows = maxRow + 1;

    _bar(canvas, w, barH);
    _boxes(canvas, mg, bTop, pw, cols, bSz, bGap, mR);
    _funnel(canvas, g, bBot, boxTotalW);
    _drawTrack(canvas, g, trackW, mR);
    _drawSlotMarbles(canvas, g, mR);
    _drawFunnelMarbles(canvas, g, bBot, mR);
    _drawBaskets(canvas, mg, kTop, pw, kH, maxRows, mR, bktH);
    _drawClearing(canvas, mg, kTop, pw, kH, maxRows, w, mR, bktH);
    for (final d in dropping) _marble(canvas, d.x, d.y, mR, d.colorIndex);
    _drawFx(canvas, mg, kTop, pw, kH, maxRows, bktH);
    if (comboTxt != null && comboAlpha > 0)
      _txt(canvas, comboTxt!, w / 2, g.cy, TextStyle(
          color: Colors.amber.withValues(alpha: comboAlpha), fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.orange.withValues(alpha: comboAlpha), blurRadius: 10)]), c: true);
  }

  void _bar(Canvas canvas, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF0F0F23));
    _txt(canvas, 'Lv.$level', 48, h / 2,
        const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold));
    _txt(canvas, '$score', w / 2, h / 2,
        const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold), c: true);
    final p = Paint()..color = Colors.red;
    for (int i = 0; i < lives; i++) {
      final x = w - 28 - i * 22.0, y = h / 2;
      canvas.drawCircle(Offset(x - 3, y - 2), 5, p);
      canvas.drawCircle(Offset(x + 3, y - 2), 5, p);
      canvas.drawPath(Path()..moveTo(x - 8, y)..lineTo(x, y + 8)..lineTo(x + 8, y)..close(), p);
    }
  }

  void _boxes(Canvas canvas, double mg, double top, double pw, int cols,
      double sz, double gap, double mR) {
    final tw = cols * sz + (cols - 1) * gap;
    final sx = mg + (pw - tw) / 2;
    final miniR = mR * 0.45; // 박스 안 미니 구슬 = 통일 구슬의 45%
    for (int i = 0; i < boxes.length; i++) {
      final b = boxes[i];
      final col = i % cols, row = i ~/ cols;
      final bx = sx + col * (sz + gap), by = top + row * (sz + gap);
      final clr = _colors[b.colorIndex % _colors.length];
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, sz, sz), const Radius.circular(6));
      if (b.released) {
        canvas.drawRRect(r, Paint()..color = Colors.white.withValues(alpha: 0.03));
        canvas.drawRRect(r, Paint()..color = Colors.white.withValues(alpha: 0.08)..style = PaintingStyle.stroke..strokeWidth = 1);
      } else {
        canvas.drawRRect(r, Paint()..color = clr.withValues(alpha: 0.25));
        canvas.drawRRect(r, Paint()..color = clr.withValues(alpha: 0.7)..style = PaintingStyle.stroke..strokeWidth = 1.5);
        for (int ry = 0; ry < 3; ry++) for (int cx = 0; cx < 3; cx++) {
          final mx = bx + sz * (0.2 + cx * 0.3), my = by + sz * (0.2 + ry * 0.3);
          canvas.drawCircle(Offset(mx, my), miniR, Paint()..color = clr);
          canvas.drawCircle(Offset(mx - miniR * 0.2, my - miniR * 0.2), miniR * 0.3,
              Paint()..color = Colors.white.withValues(alpha: 0.3));
        }
      }
    }
  }

  void _funnel(Canvas canvas, _Geo g, double boxBottom, double boxTotalW) {
    final fxC = g.cx, fy = g.cy - g.r, fTop = boxBottom + 2;
    // 깔대기 윗쪽 폭 = 박스 전체 폭보다 넓게
    final topW = boxTotalW + 30;
    final funnelW = 30.0; // 아래쪽(트랙 입구) 폭

    final path = Path()..moveTo(fxC - topW / 2, fTop)..lineTo(fxC + topW / 2, fTop)
      ..lineTo(fxC + funnelW / 2, fy - 2)..lineTo(fxC - funnelW / 2, fy - 2)..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF4A4A6A));
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    final inner = Path()..moveTo(fxC - topW / 2 + 3, fTop + 2)..lineTo(fxC + topW / 2 - 3, fTop + 2)
      ..lineTo(fxC + funnelW / 2 - 2, fy - 3)..lineTo(fxC - funnelW / 2 + 2, fy - 3)..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFF2A2A4A));
    final ap = Paint()..color = Colors.amber.withValues(alpha: 0.5)..strokeWidth = 2
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(fxC, fTop + 4), Offset(fxC, fy - 4), ap);
    canvas.drawLine(Offset(fxC - 4, fy - 10), Offset(fxC, fy - 4), ap);
    canvas.drawLine(Offset(fxC + 4, fy - 10), Offset(fxC, fy - 4), ap);
  }

  void _drawTrack(Canvas canvas, _Geo g, double tw, double mR) {
    canvas.drawPath(_stadiumPath(g, tw / 2), Paint()..color = const Color(0xFF3A3A5C));
    canvas.drawPath(_stadiumPath(g, -tw / 2), Paint()..color = const Color(0xFF1A1A2E));
    final center = Path();
    for (int i = 0; i <= 100; i++) {
      final t = i / 100.0, p = g.pos(t);
      if (i == 0) center.moveTo(p.dx, p.dy); else center.lineTo(p.dx, p.dy);
    }
    center.close();
    canvas.drawPath(center, Paint()..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // 홈 표시
    final slotR = mR * 0.6;
    for (int i = 0; i < _nSlots; i++) {
      final t = (i / _nSlots + trackOffset) % 1.0, p = g.pos(t);
      if (slots[i] == null) {
        canvas.drawCircle(p, slotR, Paint()..color = Colors.white.withValues(alpha: 0.06));
        canvas.drawCircle(p, slotR, Paint()..color = Colors.white.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke..strokeWidth = 0.8);
      }
    }

    // CCW 화살표
    final ap = Paint()..color = Colors.white.withValues(alpha: 0.2)..strokeWidth = 2
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    for (int i = 0; i < 6; i++) {
      final t = i / 6.0, p1 = g.pos(t), p2 = g.pos(t - 0.01);
      final dx = p2.dx - p1.dx, dy = p2.dy - p1.dy;
      final l = sqrt(dx * dx + dy * dy); if (l < 0.1) continue;
      final nx = dx / l, ny = dy / l;
      canvas.drawLine(Offset(p1.dx - nx * 6 - ny * 3, p1.dy - ny * 6 + nx * 3), p1, ap);
      canvas.drawLine(Offset(p1.dx - nx * 6 + ny * 3, p1.dy - ny * 6 - nx * 3), p1, ap);
    }

    // 하단 드롭존 글로우
    final dp = Path(); bool first = true;
    for (double t = g.s2; t <= g.s3; t += 0.003) {
      final p = g.pos(t);
      if (first) { dp.moveTo(p.dx, p.dy); first = false; } else dp.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(dp, Paint()..color = Colors.amber.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke..strokeWidth = tw * 1.2);
  }

  Path _stadiumPath(_Geo g, double offset) {
    final r = g.r + offset, hw = g.halfW;
    return Path()..moveTo(g.cx - hw, g.cy - r)..lineTo(g.cx + hw, g.cy - r)
      ..arcToPoint(Offset(g.cx + hw, g.cy + r), radius: Radius.circular(r), clockwise: true)
      ..lineTo(g.cx - hw, g.cy + r)
      ..arcToPoint(Offset(g.cx - hw, g.cy - r), radius: Radius.circular(r), clockwise: true)..close();
  }

  void _drawSlotMarbles(Canvas canvas, _Geo g, double mR) {
    for (int i = 0; i < _nSlots; i++) {
      if (slots[i] == null) continue;
      final t = (i / _nSlots + trackOffset) % 1.0, p = g.pos(t);
      _marble(canvas, p.dx, p.dy, mR, slots[i]!);
    }
  }

  void _drawFunnelMarbles(Canvas canvas, _Geo g, double boxBottom, double mR) {
    final fTop = boxBottom + 4, fy = g.cy - g.r;
    for (final fm in funneling) {
      if (fm.progress < 0) continue;
      final p = fm.progress.clamp(0.0, 1.0);
      final slotT = (fm.targetSlot / _nSlots + trackOffset) % 1.0, slotPos = g.pos(slotT);
      double mx, my;
      if (p < 0.5) { final f = p / 0.5; mx = g.cx; my = fTop + (fy - fTop) * f; }
      else { final f = (p - 0.5) / 0.5; mx = g.cx + (slotPos.dx - g.cx) * f; my = fy + (slotPos.dy - fy) * f; }
      _marble(canvas, mx, my, mR, fm.colorIndex, a: 0.85);
    }
  }

  void _drawBaskets(Canvas canvas, double mg, double top, double pw, double aH,
      int maxRows, double mR, double bh) {
    const gap = 4.0;
    final bw = (pw - gap * (_gridCols - 1)) / _gridCols;

    for (final b in baskets) {
      final bx = mg + b.col * (bw + gap);
      final slideOffset = b.slideY * (bh + gap);
      final by = top + b.row * (bh + gap) + slideOffset;
      final clr = _colors[b.colorIndex % _colors.length];
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(5));

      canvas.drawRRect(rect, Paint()..color = clr.withValues(alpha: 0.25));
      canvas.drawRRect(rect, Paint()..color = clr.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke..strokeWidth = 2);

      for (int k = 0; k < 3; k++) {
        final mx = bx + bw * (0.2 + k * 0.3), my = by + bh / 2;
        if (k < b.filled) {
          _marble(canvas, mx, my, mR, b.colorIndex);
        } else {
          canvas.drawCircle(Offset(mx, my), mR, Paint()..color = clr.withValues(alpha: 0.12));
          canvas.drawCircle(Offset(mx, my), mR, Paint()..color = clr.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke..strokeWidth = 1);
        }
      }
    }
  }

  void _drawClearing(Canvas canvas, double mg, double top, double pw, double aH,
      int maxRows, double screenW, double mR, double bh) {
    const gap = 4.0;
    final bw = (pw - gap * (_gridCols - 1)) / _gridCols;

    for (final ca in clearing) {
      final p = ca.progress.clamp(0.0, 1.0);
      final alpha = 1.0 - p;
      final slideX = ca.dir * p * screenW * 0.6;
      final bx = mg + ca.col * (bw + gap) + slideX;
      final by = top + ca.row * (bh + gap);
      final clr = _colors[ca.colorIndex % _colors.length];

      canvas.save();
      canvas.translate(bx + bw / 2, by + bh / 2);
      canvas.scale(1.0 - p * 0.3);
      canvas.translate(-(bx + bw / 2), -(by + bh / 2));

      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(5));
      canvas.drawRRect(rect, Paint()..color = clr.withValues(alpha: 0.55 * alpha));
      canvas.drawRRect(rect, Paint()..color = clr.withValues(alpha: 0.9 * alpha)
        ..style = PaintingStyle.stroke..strokeWidth = 2);

      for (int k = 0; k < 3; k++) {
        final mx = bx + bw * (0.2 + k * 0.3), my = by + bh / 2;
        canvas.drawCircle(Offset(mx, my), mR, Paint()..color = clr.withValues(alpha: alpha));
        canvas.drawCircle(Offset(mx - mR * 0.2, my - mR * 0.2), mR * 0.3,
            Paint()..color = Colors.white.withValues(alpha: 0.3 * alpha));
      }
      canvas.restore();
    }
  }

  void _drawFx(Canvas canvas, double mg, double top, double pw, double aH, int maxRows, double bh) {
    const gap = 4.0;
    final bw = (pw - gap * (_gridCols - 1)) / _gridCols;
    for (final e in fx) {
      final cx = mg + e.col * (bw + gap) + bw / 2;
      final cy = top + e.row * (bh + gap) + bh / 2;
      final rnd = Random(e.col * 10 + e.row);
      for (int i = 0; i < 8; i++) {
        final a = rnd.nextDouble() * 2 * pi, d = (1 - e.life) * 35 + rnd.nextDouble() * 12;
        canvas.drawCircle(Offset(cx + cos(a) * d, cy + sin(a) * d), 3 * e.life,
            Paint()..color = Colors.amber.withValues(alpha: e.life * 0.8));
      }
    }
  }

  void _marble(Canvas canvas, double x, double y, double r, int ci, {double a = 1.0}) {
    final c = _colors[ci % _colors.length];
    canvas.drawCircle(Offset(x, y + r * 0.1), r, Paint()..color = Colors.black.withValues(alpha: 0.25 * a));
    final g = RadialGradient(center: const Alignment(-0.3, -0.3), radius: 0.9, colors: [
      Color.lerp(c, Colors.white, 0.4)!.withValues(alpha: a), c.withValues(alpha: a),
      Color.lerp(c, Colors.black, 0.3)!.withValues(alpha: a)]);
    canvas.drawCircle(Offset(x, y), r, Paint()..shader = g.createShader(Rect.fromCircle(center: Offset(x, y), radius: r)));
    canvas.drawCircle(Offset(x - r * 0.25, y - r * 0.25), r * 0.28, Paint()..color = Colors.white.withValues(alpha: 0.4 * a));
  }

  void _txt(Canvas canvas, String t, double x, double y, TextStyle s, {bool c = false}) {
    final tp = TextPainter(text: TextSpan(text: t, style: s), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(c ? x - tp.width / 2 : x, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => true;
}
