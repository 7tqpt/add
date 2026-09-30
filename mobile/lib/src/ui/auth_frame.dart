// إطارُ شاشات الباب — الدخولُ والإنشاءُ والاستعادةُ والقفل.
//
// أرسل صاحبُ المنصّة أربعَ صورٍ على نسقٍ واحد وقال: «نفذهم بنفس الاستيل»،
// وعُرض عليه المقترحُ مرسوماً قبل أن يُلمَس `lib/` فأقرّه:
//
//   • **رأسٌ نبيذيٌّ** فيه القوسُ الذهبيُّ والقلبُ و«فرحتي» والنجومُ والنقشُ
//     — القطعُ نفسُها التي في الترحيب — وساقا القوسِ تغيبان تحت البطاقة.
//   • **ووردٌ في الزاويتين** — طرفا شريط الترحيب المقصوصِ من صورته.
//   • **وبطاقةٌ عائمةٌ على حرير**: بيضاءُ بإطارٍ ذهبيّ، والحريرُ مرسومٌ
//     بالشيفرة لا صورة.
//
// **وواحدٌ للشاشات الثلاث لا ثلاثُ نسخ.** القفلُ والدخولُ أوّلُ ما يُرى من
// التطبيق، واختلافُهما يُقرأ تطبيقين — وقد وقع ذلك مرّةً قبل هذا.
//
// **ولا حركةَ فيه.** النجومُ ثابتة: شاشةٌ فيها حقولٌ تُكتب أو أرقامٌ تُضغط
// ليست مشهداً يُتفرَّج عليه، والحركةُ الدائمةُ تسحب العينَ عمّا يُكتب.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../screens/welcome.dart';

/// لونُ البطاقة — أبيضُ دافئٌ لا ناصع، كما في صوره.
const authPaper = Color(0xFFFFFDFA);

/// لونُ الحرير تحت البطاقة.
const authCream = Color(0xFFF7EEDF);

/// الذهبُ الفاتحُ لإطار البطاقة والحقول وخطوط الفاصل.
const authGoldLine = Color(0xFFE3CB9B);

/// الذهبُ الأغمقُ لإطار الزرّ المحاط ومفاتيح القفل.
const authGoldEdge = Color(0xFFD9B26A);

/// كم ينزل الرأسُ من الشاشة — **بنسبةٍ لا برقمٍ ثابت**.
///
/// والعلّةُ القديمةُ نفسُها: رقمٌ ثابتٌ يأكل نصفَ جوالٍ قصيرٍ فيدفع «دخول»
/// تحت لوحة المفاتيح.
double authHeadHeight(BuildContext context, {bool titled = false, bool compact = false}) {
  final mq = MediaQuery.of(context);
  final share = compact
      ? (mq.size.height * 0.17).clamp(120.0, 170.0)
      : (mq.size.height * 0.25).clamp(150.0, 220.0);
  return share + mq.padding.top + (titled ? 44 : 0);
}

class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.crest,
    required this.children,
    this.title,
    this.canLeave = true,
    this.cardKey,
    this.compact = false,
    this.crowned = false,
  });

  /// رأسٌ أقصر — لبطاقةٍ أطول («أكمل ملفك»: ثلاثةُ حقولٍ وصورةٌ فوقها).
  final bool compact;

  /// حافّةُ البطاقة العليا ترتفع في وسطها — كما في صورة «أكمل ملفك».
  final bool crowned;

  /// ما في القوس: القلبُ والاسم، أو رمزُ الاستعادة.
  final Widget crest;

  /// ما في البطاقة.
  final List<Widget> children;

  /// عنوانٌ في أعلى الرأس بسهم رجوع — للشاشات المدفوعة وحدَها.
  final String? title;

  /// أيُظهَر سهمُ الرجوع؟ يغيب في آخر خطوات الاستعادة.
  final bool canLeave;

  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;
    final head = authHeadHeight(context, titled: title != null, compact: compact);
    // **والقوسُ لا يتّسع بلا حدّ** — على لوحٍ عريضٍ يصير بوّابةً لا علامة.
    final archInset = math.max(size.width * 0.19, (size.width - 300) / 2);

    return Scaffold(
      backgroundColor: authCream,
      body: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _SilkPainter())),

          // ── الرأس ─────────────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: head,
            child: DecoratedBox(
              key: const ValueKey('auth-head'),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.accentDeep, AppColors.accent],
                ),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(child: IgnorePointer(child: _HeadLattice())),
                  // **والنجومُ تحت سطر العنوان لا عليه** — وقعت نجمةٌ على
                  // «استعادة» في أوّل لقطة.
                  Positioned.fill(
                    top: title == null ? 0 : top + 48,
                    child: const IgnorePointer(
                      child: CustomPaint(key: ValueKey('head-stars'), painter: _HeadStars()),
                    ),
                  ),
                  // القوس — ساقاه تحت البطاقة.
                  Positioned(
                    left: archInset,
                    right: archInset,
                    top: top + 14 + (title == null ? 0 : 44),
                    bottom: -40,
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: const ArchPainter(),
                        child: Padding(
                          // **وفي الرأس القصير يُترك تحت الاسم ما يسع ذيلَ
                          // «ي»** — كان يغيب تحت البطاقة في أوّل لقطة.
                          padding: EdgeInsets.fromLTRB(12, compact ? 26 : 34, 12, compact ? 62 : 44),
                          // **ويُصغَّر ما لا يتّسع** — خطُّ جهازٍ مضاعَفٌ في
                          // رأسٍ بارتفاعٍ محدود يفيض، والتصغيرُ أصدقُ من القصّ.
                          child: Center(
                            child: FittedBox(fit: BoxFit.scaleDown, child: crest),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (title != null)
                    Positioned(
                      top: top + 4,
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            const SizedBox(width: Space.xs),
                            if (canLeave)
                              const BackButton(color: AppColors.goldOnAccent)
                            else
                              const SizedBox(width: Space.md),
                            Expanded(
                              child: Text(
                                title!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.goldOnAccent,
                                  fontFamilyFallback: arabicFallback,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── الوردُ في الزاويتين — **تحت البطاقة** فلا يغطّي منها شيئاً ──
          Positioned(
            top: head - 130,
            left: -12,
            width: 124,
            height: 170,
            child: const IgnorePointer(child: _RoseCorner(left: true)),
          ),
          Positioned(
            top: head - 130,
            right: -12,
            width: 124,
            height: 170,
            child: const IgnorePointer(child: _RoseCorner(left: false)),
          ),

          // ── البطاقة ──────────────────────────────────────────────────────
          Positioned.fill(
            top: head - 4,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Center(
                  child: ConstrainedBox(
                    // على اللوح لا تمتدّ الحقولُ عرضَ الشاشة كلِّها.
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Container(
                      key: cardKey ?? const ValueKey('auth-card'),
                      padding: EdgeInsets.fromLTRB(22, 26 + (crowned ? CrownedCardBorder.rise : 0), 22, 22),
                      decoration: crowned
                          ? ShapeDecoration(
                              color: authPaper,
                              shape: CrownedCardBorder(
                                side: BorderSide(color: authGoldLine.withValues(alpha: 0.7)),
                              ),
                              shadows: _cardShadow,
                            )
                          : BoxDecoration(
                              color: authPaper,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: authGoldLine.withValues(alpha: 0.7)),
                              boxShadow: _cardShadow,
                            ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _cardShadow = [
  BoxShadow(
    color: AppColors.accentDeep.withValues(alpha: 0.06),
    blurRadius: 18,
    offset: const Offset(0, 4),
  ),
];

/// بطاقةٌ حافّتُها العليا ترتفع في وسطها ارتفاعاً ليّناً — كما في صورة
/// «أكمل ملفك». **ويبدأ الارتفاعُ وينتهي بمنحنى** لا بزاوية، فيُقرأ حليةً
/// لا كسراً في الإطار.
class CrownedCardBorder extends ShapeBorder {
  const CrownedCardBorder({this.side = BorderSide.none});

  final BorderSide side;

  /// كم ترتفع الحافّةُ في وسطها.
  static const rise = 14.0;
  static const radius = 28.0;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    const r = radius;
    final l = rect.left, rt = rect.right, b = rect.bottom, w = rect.width;
    final top = rect.top + rise;
    return Path()
      ..moveTo(l, top + r)
      ..arcToPoint(Offset(l + r, top), radius: const Radius.circular(r))
      ..lineTo(l + w * 0.17, top)
      ..cubicTo(l + w * 0.24, top, l + w * 0.24, rect.top, l + w * 0.31, rect.top)
      ..lineTo(l + w * 0.69, rect.top)
      ..cubicTo(l + w * 0.76, rect.top, l + w * 0.76, top, l + w * 0.83, top)
      ..lineTo(rt - r, top)
      ..arcToPoint(Offset(rt, top + r), radius: const Radius.circular(r))
      ..lineTo(rt, b - r)
      ..arcToPoint(Offset(rt - r, b), radius: const Radius.circular(r))
      ..lineTo(l + r, b)
      ..arcToPoint(Offset(l, b - r), radius: const Radius.circular(r))
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(getOuterPath(rect), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) => CrownedCardBorder(side: side.scale(t));
}

/// القلبُ و«فرحتي» — ما في القوس.
///
/// **ولا أيقونةُ التطبيق هنا.** كانت في الرأس بطلب صاحب المنصّة «في كل
/// مكان»، ثمّ أرسل هذه الصورَ وفيها القلبُ والاسمُ في القوس — والأحدثُ من
/// أمره هو أمرُه.
class AuthCrest extends StatelessWidget {
  const AuthCrest({super.key});

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('auth-crest'),
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.favorite_rounded, size: 40, color: AppColors.goldOnAccent),
      const SizedBox(height: Space.xs),
      Text(
        tr('فرحتي'),
        style: const TextStyle(
          fontSize: 44,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: AppColors.goldOnAccent,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    ],
  );
}

/// عنوانُ البطاقة وسطرُه الذهبيّ وفاصلُ القلب تحتهما.
class AuthHeading extends StatelessWidget {
  const AuthHeading(
    this.title, {
    super.key,
    this.sub,
    this.accentLastWord = false,
    this.rule = true,
  });

  final String title;
  final String? sub;

  /// فاصلُ القلب تحته — ولا فاصلَ في القفل: النقاطُ تحته مباشرةً في صورته.
  final bool rule;

  /// «أدخل رمز **القفل**» — الكلمةُ الأخيرةُ نبيذيّةٌ وما قبلها حبر.
  ///
  /// **وبالكلمة الأخيرة لا بنصٍّ ثانٍ:** العنوانُ يُترجَم جملةً واحدة، ولو
  /// قُسم نصّين لَترجم كلٌّ على حدة فخرجت الجملةُ مقلوبة.
  final bool accentLastWord;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.accent);
    final cut = accentLastWord ? title.lastIndexOf(' ') : -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cut > 0)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: title.substring(0, cut + 1),
                  style: const TextStyle(color: AppColors.ink),
                ),
                TextSpan(text: title.substring(cut + 1)),
              ],
            ),
            textAlign: TextAlign.center,
            style: style,
          )
        else
          Text(title, textAlign: TextAlign.center, style: style),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              sub!,
              textAlign: TextAlign.center,
              // `gold` لا `goldOnAccent`: هذا على الأبيض، والفاتحُ لا يُقرأ عليه.
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: AppColors.gold,
              ),
            ),
          ),
        if (rule) const AuthRule(),
      ],
    );
  }
}

/// خطّان ذهبيّان بينهما قلب.
class AuthRule extends StatelessWidget {
  const AuthRule({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 64, height: 1, color: authGoldLine),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.favorite_rounded, size: 14, color: Color(0xFFD9A94E)),
        ),
        Container(width: 64, height: 1, color: authGoldLine),
      ],
    ),
  );
}

/// زخرفةُ الحقل: إطارٌ ذهبيٌّ ورمزٌ في طرفه الأيسر — كما في صورتَي الدخول.
InputDecoration authInput(
  String label,
  IconData icon, {
  String? helper,
  Widget? eye,
  String? hint,
}) => InputDecoration(
  labelText: label,
  helperText: helper,
  hintText: hint,
  fillColor: const Color(0xFFFFFCF7),
  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
  suffixIcon: Icon(icon, color: AppColors.ink2),
  prefixIcon: eye,
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: authGoldLine),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
  ),
);

/// حقلُ كلمة مرورٍ بعينٍ تُظهرها.
///
/// **والعينُ جديدةٌ في التطبيق** — كانت في صوره فجاءت معها. ومن يكتب كلمةً
/// طويلةً على شاشةٍ صغيرةٍ يخطئ حرفاً ولا يرى أين.
class SecretField extends StatefulWidget {
  const SecretField({
    super.key,
    required this.controller,
    required this.label,
    required this.autofillHints,
    this.fieldKey,
    this.helper,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final Iterable<String> autofillHints;

  /// المفتاحُ على `TextField` نفسِه — **لا على الغلاف**: الاختباراتُ تسأل
  /// الحقلَ عن متحكّمه ونصّه.
  final Key? fieldKey;
  final String? helper;
  final bool autofocus;

  @override
  State<SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<SecretField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextField(
    key: widget.fieldKey,
    controller: widget.controller,
    obscureText: _hidden,
    autofocus: widget.autofocus,
    // الكلمةُ لاتينيّةٌ غالباً: تُترك من اليسار وإلّا تبعثرت رموزها.
    textDirection: TextDirection.ltr,
    autofillHints: widget.autofillHints,
    decoration: authInput(
      widget.label,
      Icons.lock_outline,
      helper: widget.helper,
      eye: IconButton(
        tooltip: _hidden ? tr('أظهر الكلمة') : tr('أخفِ الكلمة'),
        onPressed: () => setState(() => _hidden = !_hidden),
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: AppColors.ink2,
        ),
      ),
    ),
  );
}

/// زرُّ البطاقة الأوّل: نبيذيٌّ بتدرّج.
///
/// **واللونُ المصمتُ تحته باقٍ** — `backgroundColor` هو ما يُقاس عليه
/// التباين، والتدرّجُ فوقه لا ينزل عنه. (وهي الحيلةُ التي في ذهب الترحيب.)
final authPrimaryStyle = FilledButton.styleFrom(
  backgroundColor: AppColors.accent,
  foregroundColor: AppColors.accentInk,
  minimumSize: const Size.fromHeight(54),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    fontFamily: brandFont,
    fontFamilyFallback: arabicFallback,
  ),
  backgroundBuilder: (context, states, child) => DecoratedBox(
    key: const ValueKey('auth-primary-gradient'),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          for (final c in const [AppColors.accentLift, AppColors.accent, AppColors.accentDeep])
            states.contains(WidgetState.disabled) ? c.withValues(alpha: 0.55) : c,
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.accent.withValues(alpha: 0.18),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  ),
);

/// الزرُّ المحاط: إطارٌ ذهبيٌّ وحرفٌ نبيذيّ.
final authOutlinedStyle = OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(52),
  foregroundColor: AppColors.accent,
  side: const BorderSide(color: authGoldEdge),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    fontFamily: brandFont,
    fontFamilyFallback: arabicFallback,
  ),
);

/// الوردُ في زاوية الرأس — طرفُ شريط الترحيب.
///
/// **يذوب أعلاه وطرفُه الداخليّ بألفاه**، فلا يُرى للصورة حدٌّ على النبيذيّ.
/// وكان في أوّل رسمةٍ حدٌّ أعلاه يُرى مستقيماً.
class _RoseCorner extends StatelessWidget {
  const _RoseCorner({required this.left});
  final bool left;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (r) => RadialGradient(
      center: Alignment(left ? -1 : 1, 0.3),
      radius: 1.05,
      colors: const [Colors.black, Colors.black, Colors.transparent],
      stops: const [0, 0.6, 1],
    ).createShader(r),
    child: ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
        stops: [0, 0.35],
      ).createShader(r),
      child: ClipRect(
        child: OverflowBox(
          maxWidth: 360,
          alignment: left ? Alignment.centerLeft : Alignment.centerRight,
          child: Image.asset(
            WelcomeRoses.asset,
            key: ValueKey(left ? 'rose-left' : 'rose-right'),
            height: 170,
            fit: BoxFit.fitHeight,
            alignment: left ? Alignment.centerLeft : Alignment.centerRight,
            // الوردُ زينة، وعطبُ أصله لا يُسقط الباب.
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}

class _HeadLattice extends StatelessWidget {
  const _HeadLattice();

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (r) => const RadialGradient(
      radius: 0.9,
      colors: [Colors.transparent, Colors.transparent, Colors.black],
      stops: [0, 0.5, 1],
    ).createShader(r),
    child: const RepaintBoundary(
      child: CustomPaint(painter: LatticePainter(), size: Size.infinite),
    ),
  );
}

/// نجومُ الرأس — في مواضعها من صوره، **ثابتةٌ لا تومض**.
class _HeadStars extends CustomPainter {
  const _HeadStars();

  static const _light = Color(0xFFFFE7A8);

  /// (س، ص، نصفُ القطر، الضياء) — كسورٌ من الرأس.
  static const _spots = [
    (0.17, 0.30, 6.0, 0.80),
    (0.72, 0.18, 8.0, 1.00),
    (0.62, 0.42, 3.5, 0.60),
    (0.29, 0.62, 6.0, 0.85),
    (0.88, 0.70, 4.0, 0.55),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, r, a) in _spots) {
      final c = Offset(x * size.width, y * size.height);
      canvas.drawCircle(
        c,
        r * 1.8,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _light.withValues(alpha: 0.45 * a),
              _light.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.8)),
      );
      canvas.drawPath(starPath(c, r), Paint()..color = _light.withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(_HeadStars old) => false;
}

/// الحريرُ تحت البطاقة: تدرّجٌ كريميٌّ وطيّاتٌ وخيوطٌ ذهبيّة.
class _SilkPainter extends CustomPainter {
  const _SilkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBF6EE), authCream, Color(0xFFF1E3CC)],
        ).createShader(rect),
    );
    final fold = Paint()..color = Colors.white.withValues(alpha: 0.45);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = authGoldEdge.withValues(alpha: 0.55);
    final h = size.height, w = size.width;
    for (var k = 0; k < 3; k++) {
      final y0 = h * (0.74 + k * 0.08);
      final p = Path()
        ..moveTo(0, y0)
        ..cubicTo(w * 0.3, y0 - 60 + k * 20, w * 0.6, y0 + 50, w, y0 - 30 - k * 10);
      canvas.drawPath(
        Path.from(p)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close(),
        fold,
      );
      canvas.drawPath(p, line);
    }
  }

  @override
  bool shouldRepaint(_SilkPainter old) => false;
}
