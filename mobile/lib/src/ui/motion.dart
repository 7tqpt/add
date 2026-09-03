// حركةُ الواجهة: مددٌ ومنحنياتٌ وثلاثةُ أدواتٍ تُبنى عليها.
//
// ── ثلاثةُ قراراتٍ تستحقّ أن تُقرأ ──────────────────────────────────────────
//
// **١) وكلُّ حركةٍ تُطفأ إن طلب صاحبُ الجهاز ذلك.** في أندرويد وآيفون إعدادٌ
// اسمه «تقليل الحركة»، يشغّله من تدوخه الحركةُ ومن يعاني اضطرابَ الدهليز —
// وليست تلك قلّة. وتطبيقٌ يتجاهله يُدير رأسَ صاحبه في كلّ شاشة.
//
// وهو يصل عبر `MediaQuery.disableAnimations`، فيُقرأ في موضعٍ واحدٍ هنا،
// وكلُّ ما في هذا الملفّ يسأله. **ولا يُترك لكلّ شاشةٍ أن تتذكّره** — شاشةٌ
// تنسى تكفي لإفساد الإعداد كلِّه.
//
// **٢) والمددُ أسماءٌ لا أرقامٌ متناثرة.** ‎٢٠٠‎ هنا و‎٣٠٠‎ هناك و‎٢٥٠‎ في
// ثالثةٍ تجعل التطبيق يبدو مصنوعاً في ثلاثة أيّامٍ بثلاث أيدٍ. والأسماءُ
// تُبدَّل من موضعٍ واحد.
//
// **٣) والحركةُ خدمةٌ للفهم لا زينة.** الشاشةُ تنزلق من الجهة التي جاءت
// منها ليعرف صاحبُها أين هو، والبطاقاتُ تظهر بترتيبها ليتبعها بصرُه،
// والزرُّ ينخفض تحت إصبعه ليعلم أنّها وصلت. وما لا يقول شيئاً من ذلك
// يُحذف.
library;

import 'package:flutter/material.dart';

/// مددُ الحركة — ثلاثٌ لا غير.
///
/// **وثلاثٌ تكفي:** واحدةٌ للمسةٍ تحت الإصبع، وواحدةٌ لتبدُّلٍ في مكانه،
/// وواحدةٌ لانتقال شاشة. وكلُّ مدّةٍ رابعةٍ تُضاف تُقرَّب من إحداهنّ.
abstract final class Motion {
  /// لمسةٌ تحت الإصبع — تُحسّ ولا تُنتظر.
  static const fast = Duration(milliseconds: 120);

  /// تبدُّلٌ في مكانه: بطاقةٌ تظهر، لونٌ ينتقل.
  static const normal = Duration(milliseconds: 260);

  /// انتقالُ شاشة.
  static const page = Duration(milliseconds: 320);

  /// **الدخولُ يبطئ في آخره والخروجُ يسرع.** ما يدخل يُنظر إليه فيُترك له
  /// وقتٌ ليستقرّ، وما يخرج لا يُنتظر.
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;

  /// للمسة: ارتدادٌ خفيفٌ يجعلها محسوسة.
  static const press = Curves.easeOut;

  /// إزاحةُ الظهور المتدرّج — بكسلاتٌ قليلة.
  ///
  /// **وقليلةٌ عمداً:** بطاقةٌ تقفز أربعين بكسلاً تُقرأ اضطراباً لا ترحيباً،
  /// وثمانيةَ عشرَ تُحسّ ولا تُلاحَظ.
  static const rise = 18.0;
}

/// أطلب صاحبُ الجهاز تقليلَ الحركة؟
///
/// ويُستعمل في `flutter test` كذلك: الإطارُ يشغّل الاختبارات وهذا `false`،
/// فتُقاس الحركةُ كما يراها الناس. ومن أراد قياسَ حالِ الإطفاء يلفّ الشجرة
/// بـ`MediaQuery` فيه `disableAnimations: true` — وهو ما يفعله
/// `motion_test.dart`.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// يُظهر ابنَه صاعداً ومتلاشياً — ومتدرّجاً إن كان في قائمة.
///
/// **والتدرّجُ محدودٌ عمداً.** قائمةٌ فيها مئتا بطاقةٍ لو أُخّرت كلُّ واحدةٍ
/// عن أختها لَظهرت الأخيرةُ بعد ثماني ثوانٍ — وصاحبُها ينظر إلى فراغ. فبعد
/// [maxStagger] يظهر الباقي معاً.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.maxStagger = 8,
    this.step = const Duration(milliseconds: 45),
  });

  final Widget child;

  /// ترتيبُ العنصر في قائمته — صفرٌ لما ليس في قائمة.
  final int index;
  final int maxStagger;
  final Duration step;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.normal,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // **يُبدأ هنا لا في `initState`.** قراءةُ `MediaQuery` قبل هذه اللحظة
    // ترمي، والإطفاءُ يجب أن يُعرف قبل أن تتحرّك.
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _c.value = 1;
      return;
    }
    final delay = widget.step *
        (widget.index.clamp(0, widget.maxStagger));
    Future.delayed(delay, () {
      // الشاشةُ قد تُغلق قبل أن يحين دورُ البطاقة العاشرة.
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Motion.enter);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, Motion.rise * (1 - curved.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// يخفض ابنَه قليلاً ما دام الإصبعُ عليه.
///
/// **ولمَ لا يكفي `InkWell`:** موجتُه تقع **خلف** المحتوى، فبطاقةٌ لها
/// أرضيّةٌ معتمة تبتلعها فلا يُرى شيء. وهذا حالُ بطاقاتنا كلِّها. والانخفاضُ
/// يُرى على كلّ لونٍ وكلّ أرضيّة.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// **و‍٠٫٩٧ لا ٠٫٩٠:** الأخيرةُ تُقرأ ارتجاجاً، والأولى تُحسّ ولا تُرى.
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (widget.onTap == null || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      // **وشفّافٌ لا مبهم:** بلا هذا لا تصل اللمسةُ إلى الفراغ بين
      // عناصر البطاقة، فيضغط صاحبُها بين سطرين فلا يقع شيء.
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down && !still ? widget.scale : 1,
        duration: Motion.fast,
        curve: Motion.press,
        child: widget.child,
      ),
    );
  }
}

/// انتقالُ الشاشة — يُركَّب في السمة فيعمّ التطبيق كلَّه.
///
/// **ولمَ في السمة لا في كلّ نداء.** في التطبيق سبعةٌ وأربعون موضعاً يُدفع
/// فيها `MaterialPageRoute`. ولو بُدّلت واحداً واحداً لَبقي موضعٌ يُنسى —
/// ثمّ يُضاف ثامنٌ وأربعون بعد شهرٍ فينسى كاتبُه. والسمةُ تمسّها كلَّها،
/// وما يُكتب غداً يأخذها بلا أن يعلم كاتبُه بها.
///
/// **والجهةُ تتبع اتّجاهَ اللغة.** في العربيّة يُتقدَّم إلى اليسار وفي
/// الإنجليزيّة إلى اليمين — فالشاشةُ الجديدة تأتي من حيث يتوقّعها بصرُ
/// قارئها. وافتراضُ أندرويد يصعد بها من الأسفل، وهو صحيحٌ لكنّه لا يقول
/// «تقدّمتَ» ولا «رجعتَ».
class FarhatiPageTransitions extends PageTransitionsBuilder {
  const FarhatiPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion(context)) return child;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final from = Offset(rtl ? -0.18 : 0.18, 0);
    return SlideTransition(
      position: Tween(begin: from, end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Motion.enter)),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}
