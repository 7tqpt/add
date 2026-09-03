// الاحتفال: قصاصاتٌ تتناثر، وقلبٌ ينبض، وزهرةٌ تتفتّح.
//
// ── لماذا مرسومةٌ بالشيفرة لا حزمةَ Lottie ─────────────────────────────────
//
// المعتادُ في هذا `lottie` وملفّاتُ JSON. وثلاثةُ أسبابٍ صرفتني عنها:
//
// **١) الحزمةُ لها سقفٌ مكتوب.** ‎٢٦‎ م.ب، والحزمةُ اليوم ‎٢٣‎. ورسمةُ Lottie
// الواحدةُ بين ‎٥٠‎ و‎٣٠٠‎ كيلوبايت، والثلاثُ تأكل ما بقي — لأجل ثوانٍ تُرى
// مرّةً عند تمام الحجز.
//
// **٢) والألوانُ تُحقن ولا تُبدَّل.** ملفُّ Lottie يحمل ألوانَه في متنه، فإن
// تبدّلت الهويّةُ بقيت الرسمةُ على لونها القديم — وقد تبدّلت مرّةً في هذا
// المشروع، ونُقلت الأيقونةُ من الأزرق إلى النبيذيّ قبل يومين.
//
// **٣) والمرسومُ يخرج حادّاً على كلّ كثافة** — وهذا مذهبُ المشروع من أوّله:
// قوسُ القمرية في شاشة البداية مرسومٌ بالشيفرة للسبب نفسه.
//
// ── وكلُّها تحترم «تقليل الحركة» ───────────────────────────────────────────
//
// من أطفأ الحركةَ لا يرى قصاصاتٍ تتطاير في وجهه. ويرى بدلها الحالةَ ساكنةً
// — القلبَ قائماً والزهرةَ متفتّحة — فلا ينقص عليه خبرٌ ولا معنى.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'motion.dart';

/// قصاصةٌ واحدةٌ في الهواء.
class _Bit {
  _Bit(Random r)
      : x = r.nextDouble(),
        // **وتبدأ فوق الشاشة لا فيها.** لو بدأت في وسطها لَظهرت من العدم؛
        // ومن فوقها تدخل كأنّها نُثرت.
        y = -r.nextDouble() * 0.4 - 0.05,
        size = 5 + r.nextDouble() * 7,
        speed = 0.45 + r.nextDouble() * 0.55,
        drift = (r.nextDouble() - 0.5) * 0.35,
        spin = (r.nextDouble() - 0.5) * 8,
        tilt = r.nextDouble() * pi,
        round = r.nextBool(),
        tone = r.nextInt(4);

  final double x, y, size, speed, drift, spin, tilt;
  final bool round;
  final int tone;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.t);

  final List<_Bit> bits;
  final double t;

  // ألوانُ الهويّة وحدها — لا قوسَ قزح.
  static const _tones = [
    AppColors.accent,
    AppColors.accentLift,
    AppColors.gold,
    AppColors.goldOnAccent,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final b in bits) {
      final y = b.y + b.speed * t;
      if (y > 1.15) continue;
      // **وتتلاشى في آخر الطريق.** قصاصةٌ تختفي فجأةً عند الحافّة تُرى
      // انقطاعاً؛ وتلاشيها يجعلها تغيب.
      final fade = t > 0.75 ? (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0) : 1.0;
      paint.color = _tones[b.tone].withValues(alpha: fade);

      final dx = (b.x + b.drift * t) * size.width;
      final dy = y * size.height;
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(b.tilt + b.spin * t);
      if (b.round) {
        canvas.drawCircle(Offset.zero, b.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * 0.55),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// قصاصاتٌ تتناثر مرّةً واحدة فوق ما تحتها.
///
/// **وتُوضع في `Stack` فوق المحتوى، ولا تلتقط لمسة.** صاحبُ الشاشة يريد أن
/// يضغط «تمّ» وهي تتساقط، فلو ابتلعت لمستَه لَبدا التطبيقُ معلَّقاً.
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.count = 34, this.duration = const Duration(milliseconds: 2400)});

  final int count;
  final Duration duration;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final List<_Bit> _bits;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final r = Random();
    _bits = List.generate(widget.count, (_) => _Bit(r));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!reduceMotion(context)) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _ConfettiPainter(_bits, _c.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// قلبٌ ينبض نبضةً واحدةً ثمّ يستقرّ.
///
/// **ونبضةٌ واحدةٌ لا نبضٌ دائم.** ما ينبض بلا انقطاع يسحب البصرَ إليه أبداً
/// فيمنع صاحبَه أن يقرأ ما حوله — وهذا ما يُصنع للإعلان لا للخبر.
class BeatingHeart extends StatefulWidget {
  const BeatingHeart({super.key, this.size = 64, this.color = AppColors.accent});

  final double size;
  final Color color;

  @override
  State<BeatingHeart> createState() => _BeatingHeartState();
}

class _BeatingHeartState extends State<BeatingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!reduceMotion(context)) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) {
      return Icon(Icons.favorite, size: widget.size, color: widget.color);
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.value;
        // يكبر إلى ‎١٫٢٥‎ عند ثلث الطريق ثمّ يستقرّ على ‎١‎ — نبضةٌ لا رجفة.
        final scale = t < 0.35
            ? 1 + 0.25 * Curves.easeOut.transform(t / 0.35)
            : 1 + 0.25 * (1 - Curves.easeOutBack.transform((t - 0.35) / 0.65));
        return Transform.scale(scale: scale, child: child);
      },
      child: Icon(Icons.favorite, size: widget.size, color: widget.color),
    );
  }
}

/// زهرةٌ تتفتّح — بتلاتٌ تدور وتكبر ثمّ تستقرّ.
///
/// **ومرسومةٌ بالشيفرة كأختيها.** ستُّ بتلاتٍ حول قلبٍ ذهبيّ، كلُّ بتلةٍ
/// قطعةٌ ناقصيّةٌ تدور بسدس دورة. والرسمُ يخرج حادّاً على كلّ كثافة.
class BloomingFlower extends StatefulWidget {
  const BloomingFlower({super.key, this.size = 72, this.petals = 6});

  final double size;
  final int petals;

  @override
  State<BloomingFlower> createState() => _BloomingFlowerState();
}

class _BloomingFlowerState extends State<BloomingFlower>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!reduceMotion(context)) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // **ولمن أطفأ الحركةَ تُرسم متفتّحةً لا غائبة** — الزهرةُ زينةٌ، لكنّ
    // غيابَها يترك فراغاً في التخطيط يُقرأ عطباً.
    final t = reduceMotion(context) ? 1.0 : null;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: t != null
          ? CustomPaint(painter: _FlowerPainter(1, widget.petals))
          : AnimatedBuilder(
              animation: _c,
              builder: (_, _) => CustomPaint(
                painter: _FlowerPainter(
                  Curves.easeOutBack.transform(_c.value.clamp(0.0, 1.0)),
                  widget.petals,
                ),
              ),
            ),
    );
  }
}

class _FlowerPainter extends CustomPainter {
  _FlowerPainter(this.t, this.petals);

  final double t;
  final int petals;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * t.clamp(0.0, 1.2);
    final paint = Paint()..color = AppColors.accentLift.withValues(alpha: 0.9);

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    // **وتدور ربعَ دورةٍ وهي تتفتّح** — التفتّحُ بلا دورانٍ يُقرأ تكبيراً
    // لا تفتّحاً.
    canvas.rotate(t * pi / 2);
    for (var i = 0; i < petals; i++) {
      canvas.save();
      canvas.rotate(2 * pi * i / petals);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -radius * 0.52),
          width: radius * 0.52,
          height: radius * 0.92,
        ),
        paint,
      );
      canvas.restore();
    }
    canvas.drawCircle(
      Offset.zero,
      radius * 0.28,
      Paint()..color = AppColors.goldOnAccent,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlowerPainter old) => old.t != t || old.petals != petals;
}

/// لوحُ التهنئة: قصاصاتٌ وقلبٌ ونصّ — يُعرض عند تمام الحجز.
class CelebrationOverlay extends StatelessWidget {
  const CelebrationOverlay({
    super.key,
    required this.title,
    this.body,
    this.action,
  });

  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // زهرتان تكتنفان القلبَ — أصغرُ منه فلا تسحبان البصرَ عنه.
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      BloomingFlower(size: 34),
                      SizedBox(width: Space.md),
                      BeatingHeart(size: 58),
                      SizedBox(width: Space.md),
                      BloomingFlower(size: 34),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  Text(
                    title,
                    key: const ValueKey('celebrate-title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  if (body != null) ...[
                    const SizedBox(height: Space.sm),
                    Text(
                      body!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted, height: 1.8),
                    ),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: Space.xl),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(child: Confetti()),
      ],
    );
  }
}

/// يعرض شاشةَ تهنئةٍ تملأ الشاشة، ثمّ يُرجع صاحبَها من حيث أتى.
///
/// **والخبرُ فيها لا في رسالةٍ تمرّ.** كان تمامُ الحجز يُقال في شريطٍ يظهر
/// ثانيتين ثمّ يذهب — وفيه **رقمُ الحجز ومبلغُ العربون**، وهما ما يحتاجه
/// صاحبُه ليحوّل. فمن نظر إلى جواله بعد ثانيتين فاته الرقمُ ولا سبيل إليه.
///
/// فصارت شاشةً تبقى حتى يُغلقها هو.
Future<void> showCelebration(
  BuildContext context, {
  required String title,
  String? body,
  required String actionLabel,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder(
      opaque: false,
      barrierColor: AppColors.page,
      transitionDuration: Motion.normal,
      pageBuilder: (_, _, _) => Material(
        color: AppColors.page,
        child: CelebrationOverlay(
          title: title,
          body: body,
          action: Builder(
            builder: (inner) => FilledButton(
              key: const ValueKey('celebrate-action'),
              onPressed: () => Navigator.of(inner).pop(),
              child: Text(actionLabel),
            ),
          ),
        ),
      ),
      transitionsBuilder: (context, animation, _, child) =>
          reduceMotion(context)
              ? child
              : FadeTransition(opacity: animation, child: child),
    ),
  );
}
