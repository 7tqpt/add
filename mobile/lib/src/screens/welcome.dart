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

/// **مدّةُ دورة الحياة.** كلُّ ما يبقى يتحرّك بعد استقرار المشهد يُشتقّ منها،
/// فيدور معاً ولا يتنافر.
const _ambienceCycle = Duration(seconds: 9);

double _frac(double x) => x - x.floorToDouble();

/// موضعُ الذرّة الذهبيّة رقم [i] وحجمُها وشفافيّتُها عند اللحظة [v] من الدورة.
///
/// و[x] و[y] كسران من العرض والارتفاع لا بكسلات، فتُسأل الدالّةُ بلا شاشة.
///
/// **وسرعاتُها أعدادٌ صحيحةٌ من الدورة عمداً** — مرّةً أو مرّتين أو ثلاثاً.
/// ولو كانت كسراً (١٫٤ مثلاً) لَقفزت الذرّةُ إلى موضعٍ آخر عند تمام الدورة،
/// وهي قفزةٌ تقع كلَّ تسع ثوانٍ في أربعَ عشرةَ ذرّةً معاً فتُرى ارتجاجةً في
/// الشاشة كلِّها. وهذا لا يُكتشف إلّا بالنظر إلى الشاشة عشرَ ثوانٍ متّصلة.
({double x, double y, double r, double alpha}) moteAt(int i, double v) {
  // توزيعٌ ثابتٌ لا عشوائيّ: يُسأل في الاختبار، ويخرج واحداً في كلّ تشغيل.
  final phase = _frac(i * 0.7548776662);
  final lane = _frac(i * 0.6180339887);
  final speed = 1 + (i % 3);

  // ٠ في أسفل المنطقة، ١ في أعلاها.
  final p = _frac(v * speed + phase);
  final sway = math.sin(p * 2 * math.pi + phase * 6.0) * 0.03;

  return (
    x: (0.07 + 0.86 * lane + sway).clamp(0.0, 1.0),
    y: 1 - p,
    r: 1.1 + 2.0 * _frac(i * 0.3819660113),
    // **تولد وتنطفئ في طرفَيها.** ذرّةٌ تظهر فجأةً في أسفل الشاشة وتنقطع
    // في أعلاها تُقرأ عطباً في الرسم لا ضوءاً.
    alpha: math.sin(p * math.pi).clamp(0.0, 1.0),
  );
}

/// أين يقف شريطُ الضوء الذي يمرّ على الذهب — أو `null` إن كان في راحته.
///
/// **ولمَ يرتاح أكثرَ ممّا يمرّ:** بريقٌ متّصلٌ يصير خلفيّةً متحرّكةً تُتعب
/// العين وتسحب البصرَ عن الزرّ. ومرّةٌ كلَّ أربعِ ثوانٍ ونصفٍ تُلاحَظ ثمّ
/// تُترك المشهدَ يستقرّ.
double? glintAt(double v) {
  const share = 0.35; // نصيبُ المرور من نصف الدورة
  final g = _frac(v * 2);
  if (g > share) return null;
  // من خارج الحافّة إلى خارج الحافّة الأخرى، فلا يُرى يبدأ ولا ينتهي.
  return -0.3 + 1.6 * (g / share);
}

/// علامةُ «فرحتي» — قوسٌ يُرسم كأنّ يداً ترسمه، ثمّ يمتلئ باسمها ويبقى حيّاً.
///
/// **ومقودُ الدخول لا يأتي من عندها:** تأخذه ممّن يعرضها، فتكون حركةُ دخولها
/// جزءاً من حركة الشاشة لا حركةً مستقلّةً تبدأ متى شاءت. وأمّا حياتُها بعد
/// الدخول فمن عندها، لأنّها لا تنتهي فلا معنى لأن يملكها غيرُها.
class ArchMark extends StatefulWidget {
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
  State<ArchMark> createState() => _ArchMarkState();
}

/// **ومقودان لا واحد، ولكلٍّ عملُه:**
///
///   • `widget.t` مقودُ **الدخول** — يمشي مرّةً ويقف. يرسم القوسَ ويرفع
///     الاسم. وهو ملكُ الشاشة لا ملكُ العلامة، لأنّ الزرَّ يتبع فترتَه.
///   • و`_amb` مقودُ **الحياة** — يدور بلا انقطاع. ذرّاتٌ ذهبيّةٌ تصعد،
///     وشريطُ ضوءٍ يمرّ على الذهب، وهالةٌ تتنفّس خلف القلب.
///
/// **والثاني هو المقصود من هذا كلِّه.** كانت الشاشةُ تحيا ثانيةً ونصفاً ثمّ
/// تسكن سكوناً تامّاً — وصاحبُها يقف أمامها يقرأ ويقرّر، فيرى صورةً لا
/// شاشة. وأوّلُ ما يُحكم به على تطبيقٍ هو هذه الثواني.
class _ArchMarkState extends State<ArchMark>
    with SingleTickerProviderStateMixin {
  /// `null` تعني أنّ صاحب الجهاز طلب تقليلَ الحركة.
  AnimationController? _amb;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _amb?.dispose();
      _amb = null;
      return;
    }
    _amb ??= AnimationController(vsync: this, duration: _ambienceCycle)
      ..repeat();
  }

  @override
  void dispose() {
    _amb?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amb = _amb;
    if (amb == null) return _build(widget.t.value, null);
    return AnimatedBuilder(
      animation: Listenable.merge([widget.t, amb]),
      builder: (context, _) => _build(widget.t.value, amb.value),
    );
  }

  /// [life] هي لحظةُ دورة الحياة، أو `null` إن كانت الحركةُ مطفأة.
  Widget _build(double t, double? life) {
    Widget mark = _mark(t, life);

    // شريطُ الضوء: يُطلى على الذهب وحده — `srcATop` لا يمسّ ما تحته شفّافاً،
    // فلا يُضيء الأرضيّةَ النبيذيّةَ داخل القوس وإنّما الخطَّ والحرف.
    final c = life == null ? null : glintAt(life);
    if (c != null && c > -0.18 && c < 1.18) {
      mark = ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (r) => LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: const [
            Colors.transparent,
            Color(0x8CFFFFFF),
            Colors.transparent,
          ],
          stops: [
            (c - 0.16).clamp(0.0, 1.0),
            c.clamp(0.0, 1.0),
            (c + 0.16).clamp(0.0, 1.0),
          ],
        ).createShader(r),
        child: mark,
      );
    }

    if (life != null) {
      mark = Stack(
        children: [
          // الذرّاتُ خلف القوس والحرف.
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey('motes'),
                painter: _MotesPainter(t: life),
              ),
            ),
          ),
          Positioned.fill(child: mark),
        ],
      );
    }

    // ======================================================================
    //  **ولا تلتقط هذه العلامةُ كلُّها لمسةً — وهذا سطرٌ لازم.**
    //
    //  `CustomPaint` ذاتُ الرسّام **تبتلع كلَّ لمسةٍ في مربّعها افتراضاً**:
    //
    //      bool hitTestSelf(Offset p) =>
    //          _painter != null && (_painter!.hitTest(p) ?? true);
    //
    //  فالافتراضُ `true` لا `false` — وهو عكسُ ما يظنّه من يقرأ. وقد ظننتُه
    //  أنا، ثمّ كسر ضابطٌ سالبٌ ظنّي: زرٌّ وُضع تحت المربّع فلم يُضغط.
    //
    //  ولم يكن ذلك يضرّ إلى اليوم لأنّ مربّعَ العلامة فارغٌ ممّا يُضغط. لكنّه
    //  فخٌّ منصوبٌ لمن يضع فيه شيئاً غداً: يضغط فلا يقع شيء، فيبحث في زرّه
    //  وفي `onPressed` — والعلّةُ في طبقةِ زينةٍ فوقه.
    //
    //  والعلامةُ زينةٌ محضة: لا زرَّ فيها ولا حقل. فتُرفع يدُها عن اللمس
    //  كلِّها دفعةً واحدة.
    // ======================================================================
    return IgnorePointer(child: mark);
  }

  Widget _mark(double t, double? life) {
    // القوسُ يحوي الاسم لا يجاوره: هكذا يُقرأ إطاراً لا زخرفةً ملقاةً في
    // الأعلى.
    return CustomPaint(
      painter: ArchPainter(progress: ArchMark.archAt(t)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // القلبُ يكبر إلى حجمه لا يصعد — فيُقرأ نبضةً أولى.
            _heart(Stage.at(t, 0.34, 0.64), life),
            const SizedBox(height: Space.sm),
            _rise(
              Stage.at(t, 0.44, 0.76),
              const Text(
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
            _rise(
              Stage.at(t, 0.56, 0.86),
              Text(
                'للأعراس اليمنية',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.goldOnAccent.withValues(alpha: 0.9),
                  fontFamilyFallback: arabicFallback,
                ),
              ),
            ),
            if (widget.showTagline) ...[
              const SizedBox(height: Space.lg),
              _rise(
                Stage.at(t, 0.66, 0.96),
                Text(
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
    );
  }

  /// **و`Stage` لا تُستعمل هنا وإن كانت أوضح.** هذه العلامةُ تُبنى في كلّ
  /// إطارٍ أصلاً (الذرّاتُ تتحرّك)، و`Stage` تُنشئ `AnimatedBuilder` لكلّ
  /// عنصرٍ فيها — أي أربعةٌ تُبنى وتُهدَم ستّين مرّةً في الثانية بلا فائدة.
  /// والحسابُ نفسُه: `Stage.at`.
  Widget _rise(double s, Widget child) => Opacity(
    opacity: s,
    child: Transform.translate(
      offset: Offset(0, Motion.rise * (1 - s)),
      child: child,
    ),
  );

  /// القلبُ وهالتُه — والهالةُ هي التي تتنفّس لا القلب.
  ///
  /// **ولمَ الهالةُ لا القلب:** قلبٌ يكبر ويصغر بلا انقطاع يسحب البصرَ إليه
  /// أبداً فيمنع قراءةَ ما حوله؛ وضوءٌ يشتدّ ويخفت خلفه يُحسّ ولا يُنظر
  /// إليه.
  Widget _heart(double s, double? life) {
    // ثلاثُ نفَساتٍ في الدورة — عددٌ صحيحٌ فلا تنقطع النفَسُ عند تمامها.
    final breath =
        life == null ? 0.55 : 0.35 + 0.65 * (0.5 - 0.5 * math.cos(life * 6 * math.pi));
    return Opacity(
      opacity: s,
      child: Transform.scale(
        scale: 0.6 + 0.4 * s,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.goldOnAccent.withValues(alpha: 0.26 * breath),
                AppColors.goldOnAccent.withValues(alpha: 0),
              ],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.favorite_rounded,
              size: 40,
              color: AppColors.goldOnAccent,
            ),
          ),
        ),
      ),
    );
  }
}

/// ذرّاتٌ ذهبيّةٌ تصعد داخل القوس — كغبارٍ في ضوء.
class _MotesPainter extends CustomPainter {
  const _MotesPainter({required this.t});
  final double t;

  /// **أربعَ عشرةَ لا أربعين.** أربعون تصير ثلجاً متساقطاً بالمقلوب، وهي
  /// زخرفةٌ تُلاحَظ فتُشغل؛ وأربعَ عشرةَ تُحسّ الشاشةَ حيّةً ولا تُعدّ.
  static const count = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final m = moteAt(i, t);
      if (m.alpha <= 0.01) continue;
      paint.color = AppColors.goldOnAccent.withValues(alpha: 0.34 * m.alpha);
      canvas.drawCircle(
        Offset(m.x * size.width, m.y * size.height),
        m.r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MotesPainter old) => old.t != t;
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
