import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

enum VectorMood { idle, listening, thinking, speaking, sleep }

class VectorFace extends StatefulWidget {
  final VectorMood mood;
  final double height;
  final Color background;

  const VectorFace({super.key, required this.mood, this.height = 160, this.background = const Color(0xFF121212)});

  @override
  State<VectorFace> createState() => _VectorFaceState();
}

class _VectorFaceState extends State<VectorFace> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  late double _blinkOpen; // 0..1
  Timer? _blinkTimer;
  final math.Random _rng = math.Random();
  DateTime _lastTick = DateTime.now();
  double _idleMs = 0; // accumulated idle time in ms

  @override
  void initState() {
    super.initState();
    _blinkOpen = 1.0;
    _ticker = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..addListener(() => setState(() {}))
      ..repeat();
    _scheduleNextBlink();
  }

  @override
  void didUpdateWidget(covariant VectorFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mood == VectorMood.sleep) {
      // No random fast blinks in sleep
      _blinkTimer?.cancel();
    } else if (!_blinkTimerActive) {
      _scheduleNextBlink();
    }
  }

  bool get _blinkTimerActive => _blinkTimer != null && _blinkTimer!.isActive;

  void _scheduleNextBlink() {
    _blinkTimer?.cancel();
    if (widget.mood == VectorMood.sleep) return; // Do not schedule blinks in sleep
    final delay = Duration(milliseconds: 1200 + _rng.nextInt(3000));
    _blinkTimer = Timer(delay, _blink);
  }

  void _blink() async {
    // Quick close and open
    const dur = Duration(milliseconds: 110);
    final sw = Stopwatch()..start();
    while (sw.elapsed < dur) {
      final t = sw.elapsed.inMilliseconds / dur.inMilliseconds;
      setState(() => _blinkOpen = 1.0 - Curves.easeIn.transform(t));
      await Future.delayed(const Duration(milliseconds: 16));
    }
    _blinkOpen = 0.05;
    setState(() {});
    final durUp = Duration(milliseconds: 90 + _rng.nextInt(60));
    final sw2 = Stopwatch()..start();
    while (sw2.elapsed < durUp) {
      final t = sw2.elapsed.inMilliseconds / durUp.inMilliseconds;
      setState(() => _blinkOpen = Curves.easeOut.transform(t));
      await Future.delayed(const Duration(milliseconds: 16));
    }
    _blinkOpen = 1.0;
    setState(() {});
    _scheduleNextBlink();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _ticker.value * 2 * math.pi; // 0..2pi
    // Track idle time accumulation
    final now = DateTime.now();
    final dtMs = now.difference(_lastTick).inMilliseconds.toDouble().clamp(0, 200);
    _lastTick = now;
    if (widget.mood == VectorMood.idle) {
      _idleMs += dtMs;
    } else {
      _idleMs = 0;
    }
    final baseOpen = switch (widget.mood) {
      VectorMood.idle => 0.95,
      VectorMood.listening => 1.0,
      VectorMood.thinking => 0.9,
      VectorMood.speaking => 1.0,
      VectorMood.sleep => 0.0, // fully shut eyes in sleep
    };
    final open = widget.mood == VectorMood.sleep ? 0.0 : (baseOpen * _blinkOpen).clamp(0.02, 1.0);

    // Subtle eyelid pulse when speaking (no pupils)
    final speakPulse = widget.mood == VectorMood.speaking ? (1.0 + 0.03 * math.sin(t * 3.0)) : 1.0;
    final showThinking = widget.mood == VectorMood.thinking;
    final showZzz = widget.mood == VectorMood.idle && _idleMs > 8000; // show zzz after 8s idle

    return Center(
      child: SizedBox(
        height: widget.height,
        width: widget.height * 1.8,
        child: CustomPaint(
          painter: _VectorFacePainter(open: open, pulse: speakPulse, bg: widget.background, mood: widget.mood, tick: t, showThinking: showThinking, showZzz: showZzz, idleMs: _idleMs),
        ),
      ),
    );
  }
}

class _VectorFacePainter extends CustomPainter {
  final double open; // 0..1
  final double pulse;
  final Color bg;
  final VectorMood mood;
  final double tick; // 0..2pi
  final bool showThinking;
  final bool showZzz;
  final double idleMs;

  _VectorFacePainter({required this.open, required this.pulse, required this.bg, required this.mood, required this.tick, required this.showThinking, required this.showZzz, required this.idleMs});

  @override
  void paint(Canvas canvas, Size size) {
    final faceR = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24));
    final facePaint = Paint()..color = bg;
    canvas.drawRRect(faceR, facePaint);

    final margin = size.width * 0.06;
    final eyeW = (size.width - margin * 3) / 2;
    final eyeH = size.height * 0.58;
    final eyeTop = (size.height - eyeH) / 2;
    final leftRect = Rect.fromLTWH(margin, eyeTop, eyeW, eyeH);
    final rightRect = Rect.fromLTWH(margin * 2 + eyeW, eyeTop, eyeW, eyeH);
    final eyeR = Radius.circular(eyeH * 0.22);
    final eyeColor = const Color(0xFFE6F6FF);

    // Eye slit height based on open
    final visibleH = (eyeH * open).clamp(1.0, eyeH);
    final slitTop = eyeTop + (eyeH - visibleH) / 2;

    void drawEye(Rect rect) {
      // Clip to slit (eyelids)
      final slit = Rect.fromLTWH(rect.left, slitTop, rect.width, visibleH);
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(slit, eyeR));

      // Pixel grid parameters
      const cols = 20;
      const rows = 12;
      final margin = math.min(rect.width, rect.height) * 0.10; // inner padding
      final gridW = rect.width - margin * 2;
      final gridH = rect.height - margin * 2;
      final gutter = math.min(gridW / cols, gridH / rows) * 0.25; // spacing between pixels
      final cellSize = math.min((gridW - gutter * (cols - 1)) / cols, (gridH - gutter * (rows - 1)) / rows);
      final startX = rect.left + (rect.width - (cellSize * cols + gutter * (cols - 1))) / 2;
      final startY = rect.top + (rect.height - (cellSize * rows + gutter * (rows - 1))) / 2;

      // Colors
      final pixelOn = eyeColor;
      final pixelOff = eyeColor.withValues(alpha: 0.10);
      final hiColor = const Color(0xFFBFE7FF); // highlight for animations

      // Thinking scan animation: highlight a moving column
      int highlightCol = ((tick * 2.0) % (cols.toDouble())).floor();

      final onPaint = Paint()
        ..color = pixelOn
        ..isAntiAlias = false;
      final offPaint = Paint()
        ..color = pixelOff
        ..isAntiAlias = false;
      final hiPaint = Paint()
        ..color = hiColor
        ..isAntiAlias = false;

      // Draw grid pixels
      for (int row = 0; row < rows; row++) {
        for (int col = 0; col < cols; col++) {
          final x = startX + col * (cellSize + gutter);
          final y = startY + row * (cellSize + gutter);
          final cellRect = Rect.fromLTWH(x, y, cellSize, cellSize);

          // Determine if pixel is visible considering slit
          final centerY = y + cellSize / 2;
          final visible = centerY >= slit.top && centerY <= slit.bottom;
          if (!visible) {
            // draw off pixel faintly to show the matrix
            canvas.drawRRect(RRect.fromRectAndRadius(cellRect, Radius.circular(cellSize * 0.2)), offPaint);
            continue;
          }

          // Speaking pulse subtly scales pixel size
          final localSize = cellSize * (mood == VectorMood.speaking ? pulse : 1.0);
          final dx = (cellSize - localSize) / 2;
          final dy = (cellSize - localSize) / 2;
          final pxRect = Rect.fromLTWH(x + dx, y + dy, localSize, localSize);
          final r = Radius.circular(localSize * 0.2);

          // Choose paint based on mood/animation
          Paint paint;
          if (showThinking && col == highlightCol) {
            paint = hiPaint;
          } else {
            paint = onPaint;
          }
          canvas.drawRRect(RRect.fromRectAndRadius(pxRect, r), paint);
        }
      }

      canvas.restore();

      // Eyelid edges (top and bottom) for visual style
      final lidPaint = Paint()..color = bg.withValues(alpha: 0.9);
      final topLid = Rect.fromLTWH(rect.left, rect.top, rect.width, (rect.height - visibleH) / 2);
      final bottomLid = Rect.fromLTWH(rect.left, rect.bottom - (rect.height - visibleH) / 2, rect.width, (rect.height - visibleH) / 2);
      canvas.drawRRect(RRect.fromRectAndRadius(topLid, eyeR), lidPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(bottomLid, eyeR), lidPaint);
    }

    // Draw each eye with its own centered scaling to keep alignment during speaking pulse
    void drawScaledEye(Rect rect) {
      final cx = rect.center.dx;
      final cy = rect.center.dy;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(pulse, pulse);
      canvas.translate(-cx, -cy);
      drawEye(rect);
      canvas.restore();
    }

    drawScaledEye(leftRect);
    drawScaledEye(rightRect);

    // Thinking animation is now inside the eyes (scanning column), so no external dots

    // Idle Zzz overlay: after some idle time, show floating Zs on the top-right
    if (showZzz) {
      final zColor = Colors.white.withValues(alpha: 0.7);
      final phases = [0.0, 0.7, 1.4];
      for (int i = 0; i < phases.length; i++) {
        final p = (tick + phases[i]) % (2 * math.pi);
        final lift = (math.sin(p) * 0.5 + 0.5) * (size.height * 0.08) + i * 6;
        final x = size.width - (size.width * 0.12) + math.sin(p * 1.3) * 6 - i * 6;
        final y = size.height * 0.18 - lift;
        final scale = 0.8 + i * 0.15;
        _drawText(canvas, 'Z', Offset(x, y), zColor, 24 * scale);
      }
    }
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _VectorFacePainter oldDelegate) {
    return oldDelegate.open != open || oldDelegate.pulse != pulse || oldDelegate.bg != bg || oldDelegate.mood != mood || oldDelegate.showThinking != showThinking || oldDelegate.showZzz != showZzz || oldDelegate.idleMs != idleMs;
  }
}
