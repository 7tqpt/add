import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/i18n.dart';
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

/// مدّةُ مشهد الافتتاح — **واحدةٌ للشاشتين**.
const introDuration = Duration(milliseconds: 1700);

/// لحظةُ بدء المشهد. `null` تعني أنّه لم يبدأ بعد.
DateTime? _introStart;

/// كم مضى من المشهد — ٠ لأوّل من سأل، ثمّ ما مضى فعلاً لمن جاء بعده.
///
/// **وهذه الساعةُ هي التي تجعله مشهداً واحداً لا مشهدين.** شاشةُ الإقلاع
/// تُعرض ثمّ تحلّ محلَّها شاشةُ الترحيب، وكلتاهما ترسم العلامةَ نفسَها. فلو
/// بدأت كلٌّ من أوّلها لَرُئي المشهدُ مرّتين: يُقطع في منتصفه ويُستأنف من
/// الصفر — وهو تعثّرٌ لا ترحيب. وهذا بعينه ما منع القوسَ من شاشة الإقلاع
/// قبل اليوم، فصار له جوابٌ غيرُ الحذف.
///
/// **ولا تُؤخَّر الشاشةُ ولا جزءاً من ثانية.** المشهدُ يمضي فوق ما يقع، فمن
/// عاد تحقّقُه في مئتي جزءٍ من الثانية مضى إلى شاشته ورأى بقيّةَ المشهد
/// هناك؛ ومن طال انتظارُه رآه كلَّه. والحبسُ ثانيتين في كلّ فتحةٍ ضريبةٌ
/// يوميّةٌ على من يفتح التطبيق كلَّ يوم.
double introProgress() {
  final now = DateTime.now();
  final start = _introStart ??= now;
  return (now.difference(start).inMilliseconds / introDuration.inMilliseconds)
      .clamp(0.0, 1.0);
}

/// تُعيد الساعةَ إلى ما قبل البدء — **للاختبار وحدَه**.
@visibleForTesting
void resetIntroClock() => _introStart = null;

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  /// **ومقودٌ واحدٌ لكلّ ما في الشاشة.** لو كان لكلّ عنصرٍ مقودُه لَبدأ كلٌّ
  /// في لحظته فتفكّك المشهد؛ وواحدٌ يُقسَم بالفترات يجعلها حركةً واحدةً
  /// لها بدايةٌ ونهاية.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: introDuration,
  );
  bool _started = false;

  /// مقودُ الحياة في الشاشة — البتلاتُ والوردُ وبريقُ «دخول».
  ///
  /// **ودورتُه دورةُ العلامة نفسُها** (`_ambienceCycle`) فيتّسق ما يدور في
  /// الشاشة وما يدور في القوس. و`null` لمن طلب تقليلَ الحركة: لا بتلاتٌ
  /// تسقط ولا بريقٌ يمرّ.
  AnimationController? _amb;

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
    // **ويُستأنَف من حيث وصل لا من الصفر.** شاشةُ الإقلاع قبلها ترسم
    // العلامةَ نفسَها، فبدءٌ من الصفر هنا يُعيد المشهدَ مرّتين.
    _c.forward(from: introProgress());
    _amb = AnimationController(vsync: this, duration: _ambienceCycle)..repeat();
  }

  @override
  void dispose() {
    _amb?.dispose();
    _c.dispose();
    super.dispose();
  }

  void _open({required bool signUp}) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              AuthScreen(session: widget.session, startOnSignUp: signUp),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrandBackdrop(
        // ── الترحيبُ على تصميم صاحب المنصّة ──────────────────────────────
        //
        // أرسل صورةً فيها وردٌ على مخملٍ في أسفل الشاشة، وزخرفةٌ خفيفةٌ على
        // الأطراف، ونجومٌ بدل الذرّات، و«دخول» بتدرّجٍ ذهبيّ — وقال:
        // «احتفظ بالأنيميشن». فبقي القوسُ والقلبُ والاسمُ بحركتها، ودخلت
        // الطبقاتُ الجديدةُ في الحركة نفسِها: تظهر في أواخر الدخول.
        //
        // **والترتيبُ طبقاتٌ لا عمود:** الزخرفةُ تحت كلّ شيء، والوردُ **فوق
        // القوس** يغطّي ساقيه كما في صورته — وكان في أوّل رسمةٍ تحته فخرج
        // القوسُ مرسوماً على الورد — **وفوق الزرّين لا عليهما.**
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: _doorsHeight,
              child: Stage(t: _c, from: 0.5, to: 0.9, child: const _Lattice()),
            ),
            // ── البتلاتُ — تسقط خلف القوس وتتقلّب ──────────────────────────
            //
            // طلب صاحبُ المنصّة «انميش احترافي» هنا. **وخلف القوس لا
            // أمامه**: بتلةٌ تمرّ على «فرحتي» تُقطّع الاسمَ للعين، وخلفه
            // تُحسّ ولا تُزاحم. **وتقف فوق الزرّين** كالزخرفة والورد.
            if (_amb != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: _doorsHeight,
                child: IgnorePointer(
                  child: Stage(
                    t: _c,
                    from: 0.7,
                    to: 1,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: const ValueKey('petals'),
                        painter: PetalsPainter(t: _amb!),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(Space.xl),
              child: Column(
                children: [
                  Spacer(),
                  Expanded(flex: 6, child: ArchMark(t: _c)),
                  Spacer(),
                  // ── بابان لا بابٌ واحد ────────────────────────────────────
                  //
                  // **ويصعدان آخرَ الجميع.** الزرُّ دعوةٌ إلى الفعل، ودعوةٌ تسبق
                  // التعريفَ بالنفس تُضغط قبل أن يُقرأ ما فوقها.
                  //
                  // كان زرّاً واحداً اسمُه «ابدأ رحلتك» يفتح **إنشاء الحساب**،
                  // والعائدُ يبحث عن بابه في قاع شاشةٍ ليست له. فقال صاحبُ
                  // المنصّة: «عند ضغط ابدأ رحلتك خلّه ينطلق إلى تسجيل الدخول
                  // وليس العكس»، ثمّ اختار من ثلاثٍ عُرضت عليه **(ج): زرّان**.
                  //
                  // **و«دخول» هو الذهبيُّ.** شاشةُ الترحيب لا تُعرض إلّا لمن لا
                  // جلسةَ له — ومن سجّل مرّةً يفتح التطبيق على شاشته مباشرةً.
                  // فمن يراها إمّا جديدٌ لم يسجّل قطّ، وإمّا عائدٌ خرج أو بدّل
                  // جهازَه. والأوّلُ يأتي مرّةً واحدةً في عمره، والثاني يعود.
                  //
                  // **ولا صفحةَ بينهما.** كانت «اختر نوع الحساب» تسبق التسجيل
                  // فحُذفت بأمر صاحب المنصّة: خطوةٌ تُسأل قبل أن يُعرف السائلُ
                  // من هو. ثمّ انتقل السؤالُ إلى أوّل «أكمل ملفك»، **فحُذف من
                  // هناك أيضاً**: «احذف لي هذا صفحة نهائي». فلا يُسأل أحدٌ من
                  // هو، ومقدّمُ الخدمة يفتح ملفّه من «حسابي».
                  Stage(
                    t: _c,
                    from: 0.78,
                    to: 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // زرٌّ ذهبيٌّ بحبرٍ نبيذيّ — لا نبيذيٌّ على نبيذيّ
                        // فيختفي. والأبيضُ على الذهب لا يُقرأ (‎١٫٦٦:١‎)،
                        // والنبيذيُّ عليه ‎٨٫٢٨:١‎.
                        //
                        // **وبتدرّجٍ ذهبيٍّ كما في صورته، واللونُ المصمتُ تحته
                        // باقٍ**: `backgroundColor` هو ما يُقاس عليه التباين،
                        // والتدرّجُ لا ينزل عنه — طرفُه الداكنُ ‎٦٫٦:١‎ مع الحبر.
                        FilledButton(
                          key: const ValueKey('welcome-sign-in'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.goldOnAccent,
                            foregroundColor: AppColors.accentDeep,
                            minimumSize: Size.fromHeight(52),
                            backgroundBuilder: (context, states, child) =>
                                DecoratedBox(
                              key: const ValueKey('welcome-gold'),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: welcomeGold,
                              ),
                              // **وبريقٌ يمرّ على الذهب** مرّةً في الدورة —
                              // **تحت الحرف لا فوقه**: ضوءٌ على «دخول»
                              // يُبهت الكلمةَ لحظةَ مروره.
                              child: _amb == null
                                  ? child
                                  : Stack(
                                      // **ويمرّ ما تحته كما هو**: بلا هذا
                                      // يُوضع الحرفُ في زاوية الزرّ لا في
                                      // وسطه — وقد وقع في أوّل لقطة.
                                      fit: StackFit.passthrough,
                                      children: [
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: _Shimmer(t: _amb!),
                                          ),
                                        ),
                                        ?child,
                                      ],
                                    ),
                            ),
                          ),
                          onPressed: () => _open(signUp: false),
                          child: Text(
                            tr('دخول'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamilyFallback: arabicFallback,
                            ),
                          ),
                        ),
                        SizedBox(height: Space.md),
                        // **ومحاطٌ بالذهب لا شفّافٌ بحرفٍ أبيض.** إطارٌ باهتٌ
                        // على تدرّجٍ نبيذيٍّ لا يُرى، فيُقرأ الزرُّ نصّاً لا
                        // باباً — وهو بابُ كلِّ قادمٍ جديدٍ إلى المنصّة.
                        OutlinedButton(
                          key: const ValueKey('welcome-sign-up'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.goldOnAccent,
                            side: BorderSide(color: AppColors.goldOnAccent),
                            minimumSize: Size.fromHeight(52),
                          ),
                          onPressed: () => _open(signUp: true),
                          child: Text(
                            tr('إنشاء حساب'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamilyFallback: arabicFallback,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: _doorsHeight + 6,
              child: IgnorePointer(
                child: _Bloom(
                  t: _c,
                  life: _amb,
                  from: 0.55,
                  to: 0.95,
                  child: const RepaintBoundary(child: WelcomeRoses()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ارتفاعُ ما يشغله الزرّان من قاع الشاشة: الحشوةُ وزرّان والفراغُ بينهما.
///
/// **والوردُ والزخرفةُ يقفان عنده** — فلا يُرسم شيءٌ منهما خلف الزرّين.
/// والزخرفةُ كانت تُرى من داخل «إنشاء حساب» المحاط في الرسمة.
const _doorsHeight = Space.xl + 52 + Space.md + 52;

/// تدرّجُ «دخول» الذهبيّ — فاتحٌ في أعلاه، والذهبُ المقيسُ في وسطه.
const welcomeGold = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF6D68A), AppColors.goldOnAccent, Color(0xFFD9A94E)],
);

/// شريطُ الورد والمخمل — مقصوصٌ من تصميم صاحب المنصّة.
///
/// **يذوب أعلاه وأسفلُه بألفاه لا بلونٍ فوقه**: التلاشي بلونٍ مصمتٍ على
/// أرضيّةٍ متدرّجةٍ يترك خيطاً يُرى — وقد تُرك مثلُه في ملخّص «حجوزاتي».
class WelcomeRoses extends StatelessWidget {
  const WelcomeRoses({super.key});

  static const asset = 'assets/brand/welcome_roses.webp';

  /// ما يذوب من أعلاه — وما تحته هو الوردُ ظاهراً.
  static const fadeTop = 0.38;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (r) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        Colors.black,
        Colors.black,
        Colors.transparent,
      ],
      stops: [0, fadeTop, 0.82, 1],
    ).createShader(r),
    child: Image.asset(
      asset,
      fit: BoxFit.fitWidth,
      width: double.infinity,
      // وعطبُ الأصل لا يُسقط الشاشة: الوردُ زينةٌ والبابان هما الخبر.
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  );
}

/// الوردُ يتفتّح داخلاً ثمّ يتنفّس.
///
/// **يدخل صاعداً ويكبر قليلاً من أسفله** — كأنّه يتفتّح لا كأنّه يُلصق.
/// ثمّ **يتنفّس** ببطءٍ ما دامت الشاشة: نفَسٌ واحدٌ في الدورة، وعلى محورٍ
/// من أسفله فلا يتحرّك حدُّه فوق الزرّين.
///
/// **والنفَسُ ينقبض ولا ينبسط**: لا يطول الوردُ عن مقاسه أبداً، فلا يغطّي
/// «كل خدمات زفافك» على الجوالات القصيرة — وهو مقيسٌ هناك بمقاسه التامّ.
class _Bloom extends StatelessWidget {
  const _Bloom({
    required this.t,
    required this.life,
    required this.from,
    required this.to,
    required this.child,
  });

  final Animation<double> t;
  final Animation<double>? life;
  final double from;
  final double to;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([t, ?life]),
    child: child,
    builder: (context, child) {
      final s = Stage.at(t.value, from, to);
      final l = life;
      final breath = l == null ? 1.0 : roseBreathAt(l.value);
      return Opacity(
        opacity: s,
        child: Transform.translate(
          offset: Offset(0, 28 * (1 - s)),
          child: Transform.scale(
            scale: 0.94 + 0.06 * s,
            alignment: Alignment.bottomCenter,
            child: Transform(
              key: const ValueKey('rose-breath'),
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(1, breath, 1),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// نفَسُ الورد عند اللحظة [v] من الدورة — **لا يزيد عن ١ أبداً**.
double roseBreathAt(double v) =>
    1 - 0.018 * (0.5 - 0.5 * math.cos(2 * math.pi * v));

/// بريقٌ يمرّ على «دخول».
class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.t});
  final Animation<double> t;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: t,
    builder: (context, _) {
      final c = shimmerAt(t.value);
      if (c == null) {
        return const SizedBox.expand(key: ValueKey('welcome-shimmer'));
      }
      return DecoratedBox(
        key: const ValueKey('welcome-shimmer'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-1, -0.6),
            end: const Alignment(1, 0.6),
            colors: const [
              Color(0x00FFFFFF),
              Color(0x8CFFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [
              (c - 0.14).clamp(0.0, 1.0),
              c.clamp(0.0, 1.0),
              (c + 0.14).clamp(0.0, 1.0),
            ],
          ),
        ),
      );
    },
  );
}

/// أين يقف بريقُ «دخول» عند اللحظة [v] — أو `null` في راحته.
///
/// **مرّةً في الدورة، وبعد مرور المذنّب على القوس لا معه**: ضوءان يتحرّكان
/// معاً يتنازعان العين. ومن خارج الحافّة إلى خارجها فلا يُرى يبدأ ولا ينتهي.
double? shimmerAt(double v) {
  // بعد مرّة شريط الضوء الثانية (‎٠٫٥–٠٫٦٧٥‎) لا فيها — وكانت فيها أوّلاً.
  const start = 0.78, span = 0.12;
  final g = _frac(v) - start;
  if (g < 0 || g > span) return null;
  return -0.2 + 1.4 * (g / span);
}

/// بذورُ البتلات: (موضعُها من العرض، نصفُ طولها، سرعتُها).
///
/// **والسرعاتُ أعدادٌ صحيحةٌ من الدورة** — العبرةُ التي في النجوم والذرّات
/// قبلها: كسرٌ هنا يجعل البتلاتِ تقفز إلى أعلى الشاشة كلَّ تسع ثوانٍ معاً.
const petalSeeds = [
  (0.10, 11.0, 1), (0.24, 9.0, 1), (0.37, 10.0, 2), (0.52, 8.0, 1),
  (0.66, 12.0, 1), (0.80, 9.0, 2), (0.91, 10.5, 1), (0.30, 7.5, 1),
];

/// البتلةُ رقم [i] عند اللحظة [v] من الدورة.
///
/// تسقط من فوق الحافّة العليا إلى تحت منطقتها، وتتمايل يمنةً ويسرة،
/// وتتقلّب — `flip` عرضُها الظاهر، كأنّها تدور على نفسها في الهواء.
/// **وتظهر وتختفي تدريجاً** فلا تنبت من العدم ولا تُقصّ عند الحافّة.
({double x, double y, double angle, double flip, double size, double alpha})
petalAt(int i, double v) {
  final (x0, size, speed) = petalSeeds[i];
  final phase = _frac(i * 0.3819660113);
  final fall = _frac(v * speed + phase);
  final sway = math.sin(2 * math.pi * (v * speed * 2 + phase));
  final edge = math.min(fall / 0.12, (1 - fall) / 0.2).clamp(0.0, 1.0);
  return (
    x: x0 + 0.035 * sway,
    y: -0.06 + 1.12 * fall,
    angle: 2 * math.pi * (v * speed + phase) + 0.5 * sway,
    flip: 0.3 + 0.7 * math.cos(2 * math.pi * (v * speed * 3 + phase)).abs(),
    size: size,
    alpha: 0.8 * Curves.easeInOut.transform(edge),
  );
}

/// البتلاتُ الساقطة — تُرسم من مقود الحياة مباشرةً بلا إعادة بناء.
class PetalsPainter extends CustomPainter {
  PetalsPainter({required this.t}) : super(repaint: t);

  final Animation<double> t;

  static const _light = Color(0xFFFFF4DE);
  static const _deep = Color(0xFFEBCB98);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < petalSeeds.length; i++) {
      final p = petalAt(i, t.value);
      if (p.alpha <= 0.01) continue;
      final r = p.size;
      canvas.save();
      canvas.translate(p.x * size.width, p.y * size.height);
      canvas.rotate(p.angle);
      canvas.scale(p.flip, 1);
      // بتلةٌ كقطرة: رأسٌ مدبَّبٌ وبطنٌ مستدير.
      final path = Path()
        ..moveTo(0, -r)
        ..quadraticBezierTo(r * 0.95, -r * 0.15, 0, r)
        ..quadraticBezierTo(-r * 0.95, -r * 0.15, 0, -r)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _light.withValues(alpha: p.alpha),
              _deep.withValues(alpha: p.alpha * 0.9),
            ],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(PetalsPainter old) => old.t != t;
}

/// **الزخرفة**: شبكةُ دوائرَ متداخلةٍ بخطٍّ ذهبيٍّ باهت — نقشٌ لا صورة.
///
/// **وتذوب نحو الوسط** فلا تزاحم القوسَ والاسم، وتبقى على الأطراف كما في
/// صورة صاحب المنصّة.
class _Lattice extends StatelessWidget {
  const _Lattice();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ShaderMask(
      key: const ValueKey('welcome-lattice'),
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const RadialGradient(
        center: Alignment(0, -0.2),
        radius: 0.95,
        colors: [Colors.transparent, Colors.transparent, Colors.black],
        stops: [0, 0.5, 1],
      ).createShader(r),
      child: const RepaintBoundary(
        child: CustomPaint(painter: LatticePainter(), size: Size.infinite),
      ),
    ),
  );
}

/// **وواحدٌ للترحيب ورأسِ الدخول والقفل** — نقشٌ واحدٌ في كلّ ما يُرى قبل
/// التطبيق.
class LatticePainter extends CustomPainter {
  const LatticePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = AppColors.goldOnAccent.withValues(alpha: 0.10);
    const step = 34.0;
    for (var y = -step; y < size.height + step; y += step) {
      final odd = (y / step).round().isOdd;
      for (var x = -step; x < size.width + step; x += step) {
        canvas.drawCircle(
          Offset(x + (odd ? step / 2 : 0), y),
          step * 0.62,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(LatticePainter old) => false;
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
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.accentDeep, AppColors.accent, AppColors.accentDeep],
      ),
    ),
    child: SafeArea(child: child),
  );
}

/// شاشةُ الانطلاق — أوّلُ ما يراه من فتح التطبيق.
///
/// طلب صاحبُ المنصّة شعاراً نبيذيّاً متحرّكاً هنا، وعُرض عليه فيديوٌ بخيارين
/// قبل أن يُلمَس `lib/`، فاختار **(أ) نبضٌ وتوهّج**.
///
/// ── وما كان قبلها، ولماذا تبدّل ────────────────────────────────────────────
///
/// كان فيها دوّارٌ وسطرٌ ولا قوسَ ولا اسم، **وكان لذلك سببٌ صحيح**: التحقّقُ
/// يعود في جزءٍ من ثانيةٍ غالباً، وحركةٌ تبدأ ثمّ تُقطع ثمّ تُستأنف من أوّلها
/// في شاشة الترحيب تُقرأ تعثّراً لا ترحيباً.
///
/// **والسببُ لم يسقط، بل وُجد له جوابٌ غيرُ الحذف**: `introProgress()` ساعةٌ
/// واحدةٌ للشاشتين — فالمشهدُ لا يُستأنف من الصفر بل من حيث وصل، ويُرى مشهداً
/// واحداً متّصلاً عبر الشاشتين.
///
/// **ولا تُحبس الشاشةُ ولا جزءاً من ثانية.** المشهدُ يمضي فوق ما يقع تحته.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key, this.label});

  /// السطرُ تحت العلامة — يُترك فارغاً فيكون «جارٍ التحقق…».
  ///
  /// **وفارغاً لا نصّاً افتراضيّاً:** المُنشئُ `const` فلا تُنادى فيه
  /// `tr()`، والنداءُ يقع عند البناء حيث تُعرف لغةُ الشاشة.
  final String? label;

  /// متى يُكشف الدوّارُ والسطر.
  ///
  /// **وبعد المشهد لا قبله.** كانت المهلةُ ‎٢٢٠‎ جزءاً من الثانية لأنّ
  /// الشاشةَ لم يكن فيها غيرُ الدوّار؛ وصار فيها ما يُنظر إليه، فالدوّارُ
  /// إنّما يُكشف لمن **طال** انتظارُه فعلاً. ومن عاد تحقّقُه في نصف ثانيةٍ
  /// لا يرى دوّاراً ولا سطراً — ولا يحتاجهما.
  static const slowAfter = Duration(milliseconds: 1700);

  /// كم ظهرت العلامةُ عند القيمة [v].
  ///
  /// **ومقدَّمةٌ على الاسم عمداً.** أكثرُ الإقلاعات تنتهي قبل نصف الثانية،
  /// فعلامةٌ تبدأ بعدها لا يراها أحد. وتُخرَج من البناء لتُقاس: ما يُحسب
  /// داخل `builder` لا يُسأل عنه إلّا بقراءة البكسلات.
  static double markAt(double v) =>
      Curves.easeOutCubic.transform((v / 0.38).clamp(0.0, 1.0));

  /// كم صعد الاسمُ عند القيمة [v].
  static double nameAt(double v) => Curves.easeOutCubic
      .transform(((v - 0.34) / 0.36).clamp(0.0, 1.0));

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen>
    with TickerProviderStateMixin {
  /// مقودُ الدخول — يمشي مرّةً ويقف.
  late final AnimationController _c =
      AnimationController(vsync: this, duration: introDuration);

  /// مقودُ الحياة — يدور بلا انقطاع: نَفَسٌ وشريطُ ضوء.
  ///
  /// `null` تعني أنّ صاحب الجهاز طلب تقليلَ الحركة.
  AnimationController? _amb;

  Timer? _slowTimer;
  bool _slow = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _slowTimer = Timer(BootScreen.slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

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
    _c.forward(from: introProgress());
    _amb ??= AnimationController(vsync: this, duration: _ambienceCycle)
      ..repeat();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _amb?.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amb = _amb;
    return Scaffold(
      body: BrandBackdrop(
        child: AnimatedBuilder(
          animation: Listenable.merge([_c, ?amb]),
          builder: (context, _) => _scene(context, _c.value, amb?.value),
        ),
      ),
    );
  }

  Widget _scene(BuildContext context, double v, double? amb) {
    final mark = BootScreen.markAt(v);
    final name = BootScreen.nameAt(v);
    // نَفَسٌ بطيءٌ لا يقف — الشاشةُ تبقى حيّةً ما دام الانتظار.
    final breath = amb == null ? 1.0 : 1 + 0.025 * math.sin(amb * math.pi * 2);

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: ArchPainter(progress: ArchMark.archAt(v)),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: mark,
                child: Transform.scale(
                  scale: (0.72 + 0.28 * mark) * breath,
                  child: _Sheen(
                    // شريطُ الضوء يمرّ في ثلث الدورة ويستريح ثلثيها —
                    // بريقٌ لا يهدأ يصير وميضاً يُتعب العين.
                    progress: amb == null ? 0 : (amb * 3).clamp(0.0, 1.0),
                    child: Image.asset(
                      'assets/brand/app_mark.png',
                      width: 104,
                      height: 104,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
              SizedBox(height: Space.md),
              Opacity(
                opacity: name,
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - name)),
                  child: Text(
                    tr('فرحتي'),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentInk,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── الدوّارُ والسطر — لمن طال انتظارُه وحدَه ────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 72,
          child: AnimatedOpacity(
            key: const ValueKey('boot-slow'),
            opacity: _slow ? 1 : 0,
            duration: const Duration(milliseconds: 260),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandSpinner(
                  size: 26,
                  stroke: 2.4,
                  color: AppColors.goldOnAccent,
                  tint: Colors.white,
                ),
                SizedBox(height: Space.sm),
                Text(
                  widget.label ?? tr('جارٍ التحقق…'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// شريطُ ضوءٍ يمرّ فوق ما تحته — ويُقصّ عليه فلا يسيل خارجَه.
///
/// **و`srcATop` لا `srcIn`:** الثانيةُ تستبدل لونَ الأيقونة بالتدرّج فتمحوها،
/// والأولى تضع الضوءَ **فوقها** فتبقى الأيقونةُ وتلمع.
class _Sheen extends StatelessWidget {
  const _Sheen({required this.progress, required this.child});

  /// ٠ و١ يعنيان: لا شريطَ الآن. وما بينهما موضعُه.
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return child;
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment(-3 + 6 * progress, -1),
        end: Alignment(-2 + 6 * progress, 1),
        colors: [
          Colors.transparent,
          AppColors.goldOnAccent.withValues(alpha: 0.8),
          Colors.transparent,
        ],
        stops: const [0.35, 0.5, 0.65],
      ).createShader(rect),
      child: child,
    );
  }
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

/// النجومُ في مواضعها — كسورٌ من عرض العلامة وارتفاعها، ونصفُ قطرها.
///
/// **ومنقولةٌ من صورة صاحب المنصّة لا مولَّدة**: نجومٌ حول القوس وعلى
/// جانبيه، وقليلٌ في داخله. (وكانت هنا ذرّاتٌ تصعد، فأرسل تصميماً فيه نجومٌ
/// ثابتة واختار أن تحلّ محلّها.)
const starSpots = [
  (0.95, 0.02, 9.0), (0.03, 0.12, 7.0), (0.72, 0.14, 5.0), (0.14, 0.30, 6.0),
  (0.83, 0.38, 4.0), (0.16, 0.50, 4.5), (0.90, 0.55, 6.0), (0.14, 0.68, 5.0),
  (0.95, 0.66, 3.5), (0.05, 0.82, 3.5),
];

/// النجمةُ رقم [i] عند اللحظة [v] من الدورة — تومض في مكانها.
///
/// **وسرعاتُ الوميض أعدادٌ صحيحةٌ من الدورة عمداً** — مرّةً أو مرّتين أو
/// ثلاثاً — وهي العبرةُ نفسُها التي كانت في الذرّات: لو كانت كسراً لَقفز
/// لمعانُ النجمة عند تمام الدورة، فتومض النجومُ كلُّها معاً كلَّ تسع ثوانٍ.
///
/// **ولا تنطفئ تماماً**: أخفتُها ثلثُ ضيائها — فهي نجومٌ في الصورة لا
/// أضواءٌ تُطفأ وتُشعل.
({double x, double y, double r, double alpha}) starAt(int i, double v) {
  final (x, y, r) = starSpots[i];
  final speed = 1 + (i % 3);
  final phase = _frac(i * 0.6180339887);
  final wave = 0.5 + 0.5 * math.sin(2 * math.pi * (v * speed + phase));
  return (x: x, y: y, r: r, alpha: 0.35 + 0.65 * wave);
}

/// كم ظهرت النجمةُ رقم [i] عند القيمة [t] من مقود الدخول.
///
/// **تتفتّح واحدةً بعد واحدة** بعد أن يُرسم القوس — لا دفعةً واحدة. وتكبر
/// فوق حجمها قليلاً ثمّ تستقرّ (`easeOutBack` في الرسّام) فتُقرأ ومضةَ ولادة.
double starEntryAt(int i, double t) {
  // **وآخرُها يكتمل قبل تمام المشهد** — كانت الخطوةُ ‎٠٫٠٣‎ فبقيت العاشرةُ
  // ناقصةً بعده.
  final from = 0.58 + 0.025 * i;
  return ((t - from) / 0.16).clamp(0.0, 1.0);
}

/// أين يقف المذنّبُ على القوس عند اللحظة [v] — كسرٌ من طوله، أو `null`.
///
/// **مرّةً في الدورة، وفي فجوةٍ بين مرّتي شريط الضوء** (`glintAt`): ضوءان
/// يتحرّكان في العلامة معاً يتنازعان العين.
double? cometAt(double v) {
  const start = 0.2, span = 0.26;
  final g = _frac(v) - start;
  if (g < 0 || g > span) return null;
  return Curves.easeInOut.transform(g / span);
}

/// موجةُ الضوء من القلب حين يصل — من ٠ إلى ١، ثمّ تبقى ١ (أي: انقضت).
double rippleAt(double t) => ((t - 0.5) / 0.32).clamp(0.0, 1.0);

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
          // النجومُ خلف القوس والحرف.
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey('stars'),
                painter: StarsPainter(t: life, entry: t),
              ),
            ),
          ),
          Positioned.fill(child: mark),
          // **والمذنّبُ بعد أن يكتمل الدخول** — ضوءٌ يجري على القوس
          // المرسوم، لا على قوسٍ لم يُرسم بعد.
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey('arch-comet'),
                painter: CometPainter(progress: t >= 1 ? cometAt(life) : null),
              ),
            ),
          ),
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
            _heart(Stage.at(t, 0.34, 0.64), life, rippleAt(t)),
            const SizedBox(height: Space.sm),
            _rise(
              Stage.at(t, 0.44, 0.76),
              Text(
                tr('فرحتي'),
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
                tr('للأعراس اليمنية'),
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
                  tr('كل خدمات زفافك في مكان واحد'),
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
  Widget _heart(double s, double? life, double ripple) {
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
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // **موجةُ الوصول** — حلقةٌ تتّسع من القلب وتذوب، مرّةً واحدة.
              if (ripple > 0 && ripple < 1)
                Transform.scale(
                  key: const ValueKey('heart-ripple'),
                  scale: 0.7 + 1.5 * ripple,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.goldOnAccent
                            .withValues(alpha: 0.6 * (1 - ripple)),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              const Icon(
                Icons.favorite_rounded,
                size: 40,
                color: AppColors.goldOnAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ذرّاتٌ ذهبيّةٌ تصعد داخل القوس — كغبارٍ في ضوء.
class StarsPainter extends CustomPainter {
  const StarsPainter({required this.t, this.entry = 1});
  final double t;

  /// لحظةُ مقود الدخول — النجومُ تتفتّح فيه واحدةً بعد واحدة.
  final double entry;

  static const _light = Color(0xFFFFE7A8);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < starSpots.length; i++) {
      final s0 = starAt(i, t);
      final e = starEntryAt(i, entry);
      if (e <= 0) continue;
      final pop = Curves.easeOutBack.transform(e);
      final s = (x: s0.x, y: s0.y, r: s0.r * pop, alpha: s0.alpha * e);
      final c = Offset(s.x * size.width, s.y * size.height);
      // هالةٌ ليّنةٌ خلف النجمة.
      canvas.drawCircle(
        c,
        s.r * 1.8,
        Paint()
          ..shader = RadialGradient(colors: [
            _light.withValues(alpha: 0.45 * s.alpha),
            _light.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: c, radius: s.r * 1.8)),
      );
      canvas.drawPath(
        starPath(c, s.r),
        Paint()..color = _light.withValues(alpha: s.alpha),
      );
    }
  }

  @override
  bool shouldRepaint(StarsPainter old) => old.t != t || old.entry != entry;
}

/// نجمةٌ رباعيّةٌ بأضلاعٍ مقعّرة — المركزُ نقطةُ التحكّم في كلّ ضلع.
///
/// **وواحدةٌ للترحيب ورأسِ الدخول** فلا تُرسم نجمتان مختلفتان في تطبيقٍ واحد.
Path starPath(Offset c, double r) {
  final path = Path()..moveTo(c.dx, c.dy - r);
  for (var k = 1; k <= 4; k++) {
    final a = -math.pi / 2 + k * math.pi / 2;
    path.quadraticBezierTo(
      c.dx,
      c.dy,
      c.dx + r * math.cos(a),
      c.dy + r * math.sin(a),
    );
  }
  return path;
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

      final path = outline(size, inset);
      if (path == null) return;

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

  /// خطُّ القوس — **واحدٌ للرسم وللمذنّب** فلا يجري الضوءُ على غير الخطّ.
  static Path? outline(Size size, double inset) {
    final w = size.width - inset * 2;
    final h = size.height - inset * 2;
    if (w <= 0 || h <= 0) return null;

    final left = inset;
    final right = inset + w;
    final bottom = inset + h;
    // ثلثُ الارتفاع قوسٌ مدبَّب وثلثاه قائمان: نسبةُ القمرية الصنعانية.
    final shoulder = inset + h * 0.42;
    final peak = inset;

    return Path()
      ..moveTo(left, bottom)
      ..lineTo(left, shoulder)
      // ضلعان يلتقيان في رأسٍ مدبَّب لا نصفِ دائرة.
      ..quadraticBezierTo(left, peak + h * 0.10, size.width / 2, peak)
      ..quadraticBezierTo(right, peak + h * 0.10, right, shoulder)
      ..lineTo(right, bottom);
  }

  @override
  bool shouldRepaint(ArchPainter old) => old.progress != progress;
}

/// مذنّبُ ضوءٍ يجري على القوس — رأسٌ مضيءٌ وذيلٌ يذوب.
class CometPainter extends CustomPainter {
  const CometPainter({this.progress});

  /// أين رأسُه من طول القوس — `null` تعني: لا مذنّبَ الآن.
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress;
    if (p == null) return;
    final path = ArchPainter.outline(size, 0);
    if (path == null) return;
    final metric = path.computeMetrics().first;
    final head = metric.length * p;
    final tail = math.max(0.0, head - metric.length * 0.14);
    if (head - tail < 1) return;
    // يشتدّ في وسط رحلته ويخفت عند طرفيها — فلا يولد ولا يموت فجأة.
    final a = math.sin(math.pi * p);
    final from = metric.getTangentForOffset(tail)!.position;
    final at = metric.getTangentForOffset(head)!.position;
    canvas.drawPath(
      metric.extractPath(tail, head),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
        ..shader = LinearGradient(
          colors: [
            const Color(0x00FFE7A8),
            const Color(0xFFFFE7A8).withValues(alpha: a),
          ],
        ).createShader(Rect.fromPoints(from, at)),
    );
    canvas.drawCircle(
      at,
      10,
      Paint()
        ..color = const Color(0xFFFFE7A8).withValues(alpha: 0.7 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(
      at,
      2.8,
      Paint()..color = Colors.white.withValues(alpha: a),
    );
  }

  @override
  bool shouldRepaint(CometPainter old) => old.progress != progress;
}


