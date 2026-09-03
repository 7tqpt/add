import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/theme.dart';
import '../ui/kit.dart';
import '../ui/motion.dart';
import 'auth.dart';

/// شاشة البداية — أوّلُ ما يراه من فتح التطبيق ولم يسجّل بعد.
///
/// **ولمن تُعرض ولمن لا تُعرض:** لمن لا جلسة له وحده. ومن سجّل دخوله مرّةً
/// يفتح التطبيق على شاشته مباشرةً — شاشةُ ترحيبٍ تسبق كلَّ فتحةٍ للتطبيق
/// عائقٌ يوميٌّ لا مقدّمة.
///
/// **والقوسُ مرسومٌ بالشيفرة لا صورةً مرفقة:** صورةٌ بحجم الشاشة تزيد الحزمة
/// مئاتِ الكيلوبايتات وتبهت على الشاشات العالية، والقوسُ المرسوم يخرج حادّاً
/// على كل كثافة. ولو أُريدت صورةُ صنعاء خلفه فمكانُها `assets/` — وتُطلب من
/// صاحبها لا تُؤخذ من الشبكة.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.session});
  final Session session;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  /// **ومقودٌ واحدٌ لكلّ ما في الشاشة.** لو كان لكلّ عنصرٍ مقودُه لَبدأ كلٌّ
  /// في لحظته فتفكّك المشهد؛ وواحدٌ يُقسَم بالفترات يجعلها حركةً واحدةً
  /// لها بدايةٌ ونهاية.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // **يُبدأ هنا لا في `initState`:** قراءةُ `MediaQuery` قبل هذه اللحظة ترمي.
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _c.value = 1;
      return;
    }
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrandBackdrop(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            children: [
              const Spacer(),
              Expanded(flex: 6, child: ArchMark(t: _c)),
              const Spacer(),
              // زرٌّ ذهبيٌّ بحبرٍ نبيذيّ — لا نبيذيٌّ على نبيذيّ فيختفي.
              // والأبيضُ على الذهب لا يُقرأ (‎١٫٦٦:١‎)، والنبيذيُّ عليه
              // ‎٨٫٢٨:١‎.
              //
              // **ويصعد آخرَ الجميع.** الزرُّ دعوةٌ إلى الفعل، ودعوةٌ تسبق
              // التعريفَ بالنفس تُضغط قبل أن يُقرأ ما فوقها.
              Stage(
                t: _c,
                from: 0.78,
                to: 1,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.goldOnAccent,
                    foregroundColor: AppColors.accentDeep,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => RolePickerScreen(session: widget.session)),
                  ),
                  child: const Text(
                    'ابدأ رحلتك',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamilyFallback: arabicFallback,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// أرضيّةُ الهويّة — تدرّجٌ نبيذيٌّ تُبنى عليه شاشتا الدخول والترحيب.
///
/// **وواحدةٌ للشاشتين عمداً.** كانت شاشةُ التحقّق بيضاءَ ثمّ تنقلب إلى
/// نبيذيٍّ كاملٍ عند الترحيب، فيرى فاتحُ التطبيقِ ومضةً بيضاء ثمّ لوناً —
/// وهي أوّلُ ما يراه من التطبيق كلِّه.
class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.accentDeep, AppColors.accent, AppColors.accentDeep],
      ),
    ),
    child: SafeArea(child: child),
  );
}

/// شاشةُ الدخول — ما يُرى وحسابُ صاحب الجهاز يُتحقَّق منه.
///
/// **وهي أوّلُ ما يراه من فتح التطبيق، وأقصرُ ما يراه.** فلا قوسَ يُرسم فيها
/// ولا اسمَ يصعد: التحقّقُ يعود في جزءٍ من ثانيةٍ غالباً، وحركةٌ تبدأ ثمّ
/// تُقطع في منتصفها ثمّ تُستأنف من أوّلها في شاشة الترحيب تُقرأ تعثّراً لا
/// ترحيباً. فالذي فيها أرضيّةُ الهويّة — تظهر فوراً بلا ومضةٍ بيضاء — ثمّ
/// دوّارٌ يُكشف بعد مهلةٍ لمن طال انتظارُه وحده.
class BootScreen extends StatelessWidget {
  const BootScreen({super.key, this.label = 'جارٍ التحقق…'});
  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BrandBackdrop(
      child: LoadingBlock(
        label: label,
        color: AppColors.goldOnAccent,
        tint: Colors.white,
        labelColor: Colors.white70,
      ),
    ),
  );
}

/// عنصرٌ يظهر صاعداً في فترةٍ من مقودٍ مشترك.
///
/// **ولمَ لا `FadeSlideIn`:** تلك تبدأ من نفسها بمجرّد بنائها، وهذه تنتظر
/// دورَها من مقودٍ يملكه غيرُها — وهو ما يجعل الشاشةَ مشهداً مرتَّباً لا
/// عناصرَ تتسابق.
class Stage extends StatelessWidget {
  const Stage({
    super.key,
    required this.t,
    required this.from,
    required this.to,
    required this.child,
    this.rise = Motion.rise,
  });

  final Animation<double> t;

  /// حدَّا الفترة من المقود — من ٠ إلى ١.
  final double from;
  final double to;
  final double rise;
  final Widget child;

  /// كم اكتمل من فترةٍ حدُّها [from]–[to] عند القيمة [v].
  static double at(double v, double from, double to) =>
      Motion.enter.transform(((v - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: t,
    child: child,
    builder: (context, child) {
      final s = at(t.value, from, to);
      return Opacity(
        opacity: s,
        child: Transform.translate(
          offset: Offset(0, rise * (1 - s)),
          child: child,
        ),
      );
    },
  );
}

/// علامةُ «فرحتي» — قوسٌ يُرسم كأنّ يداً ترسمه، ثمّ يمتلئ باسمها.
///
/// **ولا مقودَ لها من عندها:** تأخذه ممّن يعرضها، فتكون حركتُها جزءاً من
/// حركة الشاشة لا حركةً مستقلّةً تبدأ متى شاءت.
class ArchMark extends StatelessWidget {
  const ArchMark({super.key, required this.t, this.showTagline = true});

  final Animation<double> t;

  /// «كل خدمات زفافك في مكان واحد» — تُعرض في الترحيب لا في شاشة الانتظار.
  final bool showTagline;

  /// كم رُسم من القوس عند القيمة [v].
  ///
  /// **ويُخرَج من البناء ليُقاس.** ما يُحسب داخل `builder` لا يُسأل عنه إلّا
  /// بقراءة البكسلات، وهذه دالّةٌ صافيةٌ تُسأل مباشرةً.
  static double archAt(double v) =>
      Curves.easeInOutCubic.transform((v / 0.62).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    // القوسُ يحوي الاسم لا يجاوره: هكذا يُقرأ إطاراً لا زخرفةً ملقاةً في
    // الأعلى.
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) => CustomPaint(
        painter: ArchPainter(progress: archAt(t.value)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // القلبُ يكبر إلى حجمه لا يصعد — فيُقرأ نبضةً أولى.
              _heart(Stage.at(t.value, 0.34, 0.64)),
              const SizedBox(height: Space.md),
              Stage(
                t: t,
                from: 0.44,
                to: 0.76,
                child: const Text(
                  'فرحتي',
                  style: TextStyle(
                    fontSize: 44,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldOnAccent,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
              ),
              const SizedBox(height: Space.xs),
              Stage(
                t: t,
                from: 0.56,
                to: 0.86,
                child: Text(
                  'للأعراس اليمنية',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldOnAccent.withValues(alpha: 0.9),
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
              ),
              if (showTagline) ...[
                const SizedBox(height: Space.lg),
                Stage(
                  t: t,
                  from: 0.66,
                  to: 0.96,
                  child: Text(
                    'كل خدمات زفافك في مكان واحد',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.7,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontFamilyFallback: arabicFallback,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _heart(double s) => Opacity(
    opacity: s,
    child: Transform.scale(
      scale: 0.6 + 0.4 * s,
      child: const Icon(
        Icons.favorite_rounded,
        size: 40,
        color: AppColors.goldOnAccent,
      ),
    ),
  );
}

/// قوسٌ يمنيٌّ بخطٍّ ذهبيّ — قوسان متداخلان وتاجٌ مدبَّب.
class ArchPainter extends CustomPainter {
  const ArchPainter({this.progress = 1});

  /// كم رُسم من القوس — من ٠ إلى ١.
  ///
  /// **ويُرسم بقياس الطول لا بقطع الإحداثيّات.** `PathMetric.extractPath`
  /// تعطي أوّلَ كذا بكسلاً من المسار مهما التوى، فيخرج الخطُّ زاحفاً من
  /// أسفل اليسار إلى القمّة ثمّ نازلاً — كأنّ يداً ترسمه. وقطعُ الإحداثيّات
  /// يُظهره ينمو من الجانبين معاً، وهو حركةُ آلةٍ لا حركةُ يد.
  final double progress;

  /// كم رُسم من القوس الداخليّ حين رُسم من الخارجيّ [outer].
  ///
  /// **ودالّةٌ صافيةٌ لتُقاس:** تأخّرُ الداخليّ لا يُرى إلّا في البكسلات،
  /// وقد كُتب مرّةً فلم يعمل — كانت النسبةُ تُحسب ثمّ تُرمى، ويُنادى القوسُ
  /// الداخليُّ بنسبة الخارجيّ نفسِها، فيُرسمان معاً. والشيفرةُ تُترجَم
  /// وتعمل ولا تقول شيئاً.
  static double inner(double outer) =>
      ((outer - 0.25) / 0.75).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.goldOnAccent.withValues(alpha: 0.75)
      ..strokeWidth = 2;

    void arch(double inset, double alpha, double width, double t) {
      gold
        ..color = AppColors.goldOnAccent.withValues(alpha: alpha)
        ..strokeWidth = width;

      final w = size.width - inset * 2;
      final h = size.height - inset * 2;
      if (w <= 0 || h <= 0) return;

      final left = inset;
      final right = inset + w;
      final bottom = inset + h;
      // ثلثُ الارتفاع قوسٌ مدبَّب وثلثاه قائمان: نسبةُ القمرية الصنعانية.
      final shoulder = inset + h * 0.42;
      final peak = inset;

      final path = Path()
        ..moveTo(left, bottom)
        ..lineTo(left, shoulder)
        // ضلعان يلتقيان في رأسٍ مدبَّب لا نصفِ دائرة.
        ..quadraticBezierTo(left, peak + h * 0.10, size.width / 2, peak)
        ..quadraticBezierTo(right, peak + h * 0.10, right, shoulder)
        ..lineTo(right, bottom);

      if (t >= 1) {
        canvas.drawPath(path, gold);
        return;
      }
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * t), gold);
      }
    }

    // **والنسبةُ تُمرَّر إلى `arch` ولا تُقرأ من الحقل.** كانت هنا حيلةٌ
    // تضع النسبةَ في متغيّرٍ ساكنٍ قبل النداء لتقرأه الدالّة — وكان ذلك
    // المتغيّرُ يُكتب ولا يُقرأ، فيرسم القوسان معاً ولا يتأخّر الداخليّ،
    // ولا يقول عن ذلك شيءٌ لأنّ الشيفرةَ تُترجَم وتعمل. والوسيطُ الصريح
    // لا يُخطئ بهذه الطريقة أصلاً.
    final outer = progress.clamp(0.0, 1.0);
    arch(0, 0.85, 2.2, outer);

    // **والقوسُ الداخليّ يتأخّر عن الخارجيّ.** لو رُسما معاً لَبدَوا خطّاً
    // واحداً سميكاً؛ وتأخّرُ الثاني يجعلهما قوسين.
    final in2 = inner(outer);
    if (in2 > 0) arch(math.min(14, size.width * 0.06), 0.45, 1.2, in2);
  }

  @override
  bool shouldRepaint(ArchPainter old) => old.progress != progress;
}

/// «اختر نوع الحساب» — ثلاثةُ أبوابٍ إلى بابٍ واحد.
///
/// **وهي طريقٌ لا قسمة:** الحسابُ واحدٌ في الحالات الثلاث. عروسٌ وعريسٌ
/// كلاهما عميل، ومقدّمُ الخدمة عميلٌ **زاد** عليه ملفَّ عرض — والشخص نفسه قد
/// يحجز لعرس أخيه ويبيع خدمة التصوير، فحبسه في أحد الطرفين يُلزمه بحسابين.
///
/// فما تفعله أنها تختصر الطريق: من قال «مقدّم خدمة» يُساق إلى إنشاء ملفّه فور
/// إكمال بياناته، بدل أن يبحث عنه في «حسابي» بعد أسبوع — وأكثرُهم لم يكن
/// يبحث، فيبقى مسجَّلاً عميلاً وهو جاء ليبيع.
class RolePickerScreen extends StatelessWidget {
  const RolePickerScreen({super.key, required this.session});
  final Session session;

  void _go(BuildContext context, String intent) {
    session.signUpIntent = intent;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AuthScreen(session: session, startOnSignUp: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.page, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xl),
        children: [
          const Center(
            child: Text(
              'فرحتي',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                fontFamilyFallback: arabicFallback,
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
          const Center(
            child: Text(
              'مرحباً بك في فرحتي',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                fontFamilyFallback: arabicFallback,
              ),
            ),
          ),
          const SizedBox(height: Space.xs),
          const Center(child: Muted('اختر نوع الحساب', size: 13)),
          const SizedBox(height: Space.xl),

          _RoleCard(
            icon: Icons.favorite_rounded,
            title: 'أنا عروس',
            body: 'أبحث عن خدمات وأخطّط لحفل زفافي',
            onTap: () => _go(context, 'bride'),
          ),
          const SizedBox(height: Space.md),
          _RoleCard(
            icon: Icons.favorite_border_rounded,
            title: 'أنا عريس',
            body: 'أبحث عن خدمات وأخطّط لحفل زفافي',
            onTap: () => _go(context, 'groom'),
          ),
          const SizedBox(height: Space.md),
          _RoleCard(
            icon: Icons.storefront_rounded,
            title: 'مقدّم خدمة',
            body: 'أعرض خدماتي وأستقبل الحجوزات',
            onTap: () => _go(context, 'provider'),
          ),

          const SizedBox(height: Space.lg),
          // **يُقال صراحةً:** الاختيارُ طريقٌ لا قفل. ومن لم يُقل له ذلك ظنّ
          // أنه يفتح حساباً من نوعٍ لا يُبدَّل، فتردّد أو فتح حسابين.
          const Center(
            child: Muted(
              'الحساب واحد — تستطيع أن تعرض خدماتك لاحقاً أو أن تحجز، أيّاً كان اختيارك',
              size: 12,
            ),
          ),
          const SizedBox(height: Space.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Muted('لديك حساب بالفعل؟', size: 13),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => AuthScreen(session: session)),
                ),
                child: const Text('تسجيل الدخول'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    children: [
      Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: Tint.disc),
            ),
            child: Icon(icon, size: 24, color: AppColors.accent),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Muted(body, size: 12.5),
              ],
            ),
          ),
          const Icon(Icons.chevron_left, size: 22, color: AppColors.muted),
        ],
      ),
    ],
  );
}
