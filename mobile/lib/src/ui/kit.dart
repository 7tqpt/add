import 'dart:async' show Timer;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/format.dart' show formatRelative;
import '../core/i18n.dart';
import '../core/presence.dart';
import '../core/theme.dart';
import '../data/supabase.dart' show offlineMessage;
import 'motion.dart';
import 'photo_view.dart';

/// عناصر الواجهة المشتركة.

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.children, this.onTap});
  final List<Widget> children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
    if (onTap == null) return card;
    // **واللمسةُ تُحسّ هنا لا في كلّ شاشة.** البطاقاتُ في التطبيق كلِّه
    // تُبنى من هذه، فانخفاضُها تحت الإصبع يُركَّب مرّةً ويعمّ.
    //
    // **و`InkWell` أُزيل من هنا، وأُزيل عن قصد.** كنتُ لففتُه بـ`Pressable`
    // فبقيت البطاقةُ لا تنخفض: `InkWell` يكسب حَلبةَ الإيماءات فلا يصل
    // `onTapDown` إلى ما فوقه أصلاً. أي أنّ اللمسةَ كانت **ميّتةً في كلّ
    // بطاقةٍ في التطبيق** ولا يظهر ذلك إلّا بالإصبع — وكشفه اختبار.
    //
    // ولا تُفقد موجتُه شيئاً: أرضيّةُ بطاقاتنا معتمةٌ تبتلعها، وقد قيل ذلك
    // في `Pressable` نفسِها.
    return Pressable(onTap: onTap, child: card);
  }
}

/// البطاقةُ النبيذيّة — الوجهُ الكبير للعلامة داخل الشاشات.
///
/// **وواحدةٌ في موضعين لا نسختان.** بطاقةُ العدّ في «خطة العرس» وبطاقةُ الحجز
/// في «حجوزاتي» تُبنيان من هذه: تدرّجٌ واحدٌ ونصفُ قطرٍ واحدٌ وحشوةٌ واحدة.
/// ونسختان متطابقتان تفترقان بمرور الوقت — يُعدَّل التدرّج في إحداهما فتبقى
/// الأخرى، فتصير الشاشتان من تطبيقين.
///
/// والتدرّج من أعلى اليمين إلى أسفل اليسار: العربيّةُ تُقرأ من اليمين، فيبدأ
/// الفاتحُ حيث تقع العين أوّلاً.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.children, this.onTap});
  final List<Widget> children;
  final VoidCallback? onTap;

  static final BorderRadius radius = BorderRadius.circular(20);

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.accentLift, AppColors.accentDeep],
        ),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
    if (onTap == null) return card;
    return InkWell(onTap: onTap, borderRadius: radius, child: card);
  }
}

/// الحبرُ والأزرار **على أرضيةٍ نبيذيّة**.
///
/// **وليست ترفاً.** زرُّ التطبيق المملوء نبيذيٌّ لأنه يقع على فاتح، فوضعُه
/// كما هو داخل بطاقةٍ نبيذيّة يجعله يذوب فيها فلا يُرى أصلاً. وحبرُ «عندي
/// مشكلة» رماديٌّ باهتٌ على الفاتح، وهو على النبيذيّ غيرُ مقروء.
///
/// وكلُّ لونٍ هنا مقيسٌ في `kit_test` كبقيّة ألوان المنصّة.
class OnAccent {
  /// الحبرُ الأوّل على النبيذيّ.
  static const ink = Color(0xFFFFFFFF);

  /// السطرُ الثانوي — تاريخٌ أو اسمُ مزوّد.
  static const inkSoft = Color(0xFFEBDCE1);

  /// الرقمُ المميَّز والحبرُ الخفيف على الأزرار الشفّافة.
  static const gold = AppColors.goldOnAccent;

  /// زرٌّ مملوء: **ذهبيٌّ بحبرٍ نبيذيّ** لا نبيذيٌّ على نبيذيّ.
  static ButtonStyle get filled => FilledButton.styleFrom(
    backgroundColor: AppColors.goldOnAccent,
    foregroundColor: AppColors.accentDeep,
    // والمعطَّل يبقى مرئيّاً: زرٌّ يختفي أثناء الانتظار يُقرأ عطباً لا انشغالاً.
    disabledBackgroundColor: const Color(0x55D9B45C),
    disabledForegroundColor: const Color(0x99FFFFFF),
  );

  static ButtonStyle get outlined => OutlinedButton.styleFrom(
    foregroundColor: ink,
    side: const BorderSide(color: Color(0x8CFFFFFF)),
    disabledForegroundColor: const Color(0x80FFFFFF),
  );

  static ButtonStyle get text => TextButton.styleFrom(
    foregroundColor: gold,
    disabledForegroundColor: const Color(0x80FFFFFF),
  );
}

/// جسمُ ورقةٍ سفليّة: عنوانٌ ثمّ محتوى، فوق لوحة المفاتيح لا تحتها.
///
/// **و`viewInsets` ليست تجميلاً:** ورقةٌ فيها حقلُ كتابةٍ بلا هذه الحاشية
/// تختفي تحت لوحة المفاتيح فور فتحها، فلا يرى صاحبُها ما يكتب.
class SheetBody extends StatelessWidget {
  const SheetBody({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: Space.lg,
      right: Space.lg,
      top: Space.lg,
      bottom: MediaQuery.of(context).viewInsets.bottom + Space.lg,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: Space.md),
          ...children,
        ],
      ),
    ),
  );
}

/// دوّارُ الانتظار داخل زرّ — بحجم النصّ الذي حلّ محلّه.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 18,
    width: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

/// سطرُ توضيحٍ في أرضيّةٍ مصبوغة — لِما يجب أن يُقرأ قبل الفعل لا بعده.
class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Space.md),
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: Tint.chip),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 18, color: AppColors.accent),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5, height: 1.7, color: AppColors.ink2),
          ),
        ),
      ],
    ),
  );
}

/// سؤالٌ قبل فعلٍ لا رجعةَ فيه.
///
/// **ونصُّ الزرّ يقول ما سيقع لا «موافق».** «موافق» تُضغط بلا قراءة، و«احذف
/// حسابي» تُقرأ قبل أن تُضغط.
Future<bool?> confirmDanger(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
}) => confirmChoice(
  context,
  title: title,
  body: body,
  confirm: confirm,
  cancel: tr('إلغاء'),
  tone: AppColors.critical,
);

/// سؤالٌ قبل فعلٍ لا رجعةَ فيه — أو فعلٍ يمضي إلى غيرك ولا تملك سحبَه.
///
/// **وواحدٌ في موضعين لا نسختان.** `confirmDanger` أعلاه هي هذه بلونِ
/// الخطر؛ ونسختان متطابقتان تفترقان بمرور الوقت فيصير لحواري التطبيق
/// شكلان.
///
/// و`tone` يصبغ زرَّ التأكيد: أحمرُ للحذف، **وأخضرُ لختمِ عملٍ تمّ** —
/// فليس كلُّ سؤالٍ تحذيراً. وسؤالُ «تأكيد التنفيذ» بزرٍّ أحمرَ يُقرأ
/// إنذاراً من فعلٍ صحيح.
Future<bool?> confirmChoice(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  required String cancel,
  Color tone = AppColors.critical,
}) => showDialog<bool>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: Text(title),
    content: SingleChildScrollView(
      child: Text(body, style: const TextStyle(height: 1.7)),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(dialogContext).pop(false),
        child: Text(cancel),
      ),
      FilledButton(
        key: const ValueKey('confirm-yes'),
        onPressed: () => Navigator.of(dialogContext).pop(true),
        style: FilledButton.styleFrom(backgroundColor: tone),
        child: Text(confirm),
      ),
    ],
  ),
);

/// بطاقةٌ كبيرة بتدرّجٍ لونيّ — الرئيسيةُ وأعلى «حجوزاتي».
///
/// **وواحدةٌ في موضعين لا نسختان:** بطاقةُ «حجوزاتي» تُعرض في الرئيسية وفي
/// أعلى شاشتها. ونسختان متطابقتان تفترقان بمرور الوقت — يُعدَّل التدرّج في
/// إحداهما فتبقى الأخرى، فيظنّ العميل أنّهما شيئان.
///
/// **والنصّ أبيضُ مقيسٌ لا مفترَض**: التدرّج يفتحُ في أعلاه، فلو أُخذ اللون
/// من أغمق طرفيه لبدا مقروءاً في القياس ومغسولاً على الجهاز. وقد قيس على
/// الرسم نفسه: ‎٩٫٧٠:١‎ على الأزرق و‎٨٫٥٥:١‎ على الورديّ.
class BigHeroCard extends StatefulWidget {
  const BigHeroCard({
    super.key,
    required this.colors,
    required this.icon,
    required this.title,
    required this.headline,
    required this.subtitle,
    required this.footer,
    required this.onTap,
    this.progress,
  });

  final List<Color> colors;
  final IconData icon;
  final String title;
  final String headline;
  final String subtitle;
  final String footer;

  /// نسبة ما دُفع — تُترك فارغةً فيغيب الشريط ويرتفع النصّ مكانه.
  final double? progress;

  /// تُترك فارغةً حين تكون البطاقةُ **في** الشاشة التي تشير إليها: بطاقةٌ
  /// تُضغط فتفتح ما هو مفتوحٌ أصلاً تُعلّم المستخدم أنّ ضغطها لا يفعل شيئاً.
  final VoidCallback? onTap;

  @override
  State<BigHeroCard> createState() => _BigHeroCardState();
}

class _BigHeroCardState extends State<BigHeroCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: widget.colors,
              ),
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: widget.colors.last.withValues(alpha: _down ? 0.18 : 0.34),
                  blurRadius: _down ? 10 : 22,
                  offset: Offset(0, _down ? 3 : 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  // قرصان زجاجيّان في الزاوية: عمقٌ بلا صورة — والصورة تحتاج
                  // شبكةً وتحميلاً وقد لا تصل.
                  Positioned(top: -46, left: -30, child: _Blob(size: 150, alpha: 0.10)),
                  Positioned(
                    bottom: -60,
                    right: -24,
                    child: _Blob(size: 130, alpha: 0.07),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.28),
                                ),
                              ),
                              child: Icon(widget.icon, size: 20, color: Colors.white),
                            ),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontFamilyFallback: arabicFallback,
                                ),
                              ),
                            ),
                            // «forward» لا «back»: أيقونات الأسهم تنعكس مع
                            // اتجاه النصّ (‏`matchTextDirection`‏)، فـ«back»
                            // في العربية يشير يميناً — أي رجوعاً. وقد رُسم
                            // فرُئي مقلوباً قبل أن يُبدَّل.
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              widget.headline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 24,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamilyFallback: arabicFallback,
                              ),
                            ),
                            const SizedBox(height: Space.xs),
                            Text(
                              widget.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.white.withValues(alpha: 0.82),
                                fontFamilyFallback: arabicFallback,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.progress != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: widget.progress,
                                  minHeight: 6,
                                  backgroundColor: Colors.white.withValues(alpha: 0.26),
                                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                                ),
                              ),
                              const SizedBox(height: Space.sm),
                            ],
                            Text(
                              widget.footer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.92),
                                fontFamilyFallback: arabicFallback,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.alpha});
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}

/// صفٌّ في قائمة ملفّ — «حسابي» وملفّ مقدّم الخدمة.
///
/// **قائمةٌ لا بطاقاتٌ متتابعة، وهذا هو الفرق.** كانت الصفحةُ ستَّ بطاقاتٍ في
/// كلٍّ منها عنوانٌ وسطرا شرحٍ وزرّ — فيصير البابُ الواحد أربعةَ أسطر، وستّةُ
/// أبوابٍ شاشتين ونصفاً من التمرير. وما يُبحث عنه هنا **اسمُ الباب** لا
/// شرحُه: من فتح «حسابي» يعرف ما يريد، ويريد أن يصل إليه بضغطة.
class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// لونٌ يخصّ الصفّ — للخروج وحده. وما عداه بلون العلامة.
  final Color? tone;

  /// آخرُ صفٍّ في مجموعته فلا خطَّ تحته.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colour = tone ?? AppColors.accent;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colour),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: tone ?? AppColors.ink,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
            ),
            // سهمٌ لا أيقونةٌ ثانية: الصفُّ يُفتح، والسهمُ يقول ذلك.
            //
            // **وصورتُه اللاتينيّةُ تُكتب ويقلبها الإطار**: الأيقونةُ
            // `matchTextDirection`، فكتابةُ `chevron_left` في تطبيقٍ عربيٍّ
            // انعكاسٌ ثانٍ يجعل السهمَ يشير إلى الخلف. (مقولٌ في `CardTitleBar`.)
            Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// الورقةُ الفاتحة التي تحمل الصفوف — بحوافّ عليا مستديرة تحت الرأس النبيذيّ.
///
/// **وواحدةٌ للشاشتين لا نسختان:** «حسابي» وملفُّ مقدّم الخدمة يبنيان منها،
/// فنصفُ القطر والحشوة والخطُّ الفاصل تُعدَّل في موضعٍ واحد.
class MenuSheet extends StatelessWidget {
  const MenuSheet({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

/// فاصلٌ بين مجموعتين من الصفوف.
///
/// **وكان بلون الأرضيّة، فلمّا ابيضّت اختفى.** كان `AppColors.page` — وهو
/// أرضيّةُ الشاشة يومَها — فكان الفصلُ يُرى لأنّ ما حوله أبيضُ البطاقات.
/// فلمّا صارت الأرضيّةُ بيضاءَ في ١٫٥٥ صار الفاصلُ أبيضَ على أبيضَ، فالتصق
/// «أريد تقديم خدمة» بـ«الإعدادات» في «حسابي».
///
/// **فصار `surface2`** — وهو الورديُّ الذي كان يفصل، لا الأرضيّةُ التي صارت.
class MenuGap extends StatelessWidget {
  const MenuGap({super.key});
  @override
  Widget build(BuildContext context) =>
      Container(height: Space.sm, color: AppColors.surface2);
}

/// مقاسُ القرص في رأس الملفّ.
///
/// **ثابتٌ واحدٌ لا رقمان.** الرأسُ يحسب بمقداره كم يزيح القرصَ فوق حافّة
/// الغلاف، والشاشةُ تبني القرصَ به. ولو كتبت كلٌّ رقمَها لَطلّ القرصُ بمقدارٍ
/// لا يطابق مقاسَه فوقع نصفُه في البياض ونصفُه في الصورة بلا محاذاة.
const double profileAvatarSize = 92;

/// الرأسُ في أعلى شاشة الملفّ — «حسابي» وملفّ مقدّم الخدمة.
///
/// **وواحدٌ للشاشتين لا نسختان.** غلافٌ يملأ عرضَ الشاشة، والقرصُ يطلّ على
/// حافّته السفلى، والاسمُ وسطرٌ ثانويٌّ وشارةٌ ذهبيّةٌ تحته على البياض. وما
/// يفترق بين الشاشتين محتوىً لا شكل: العميلُ اسمُه وجوالُه ودورُه، والمزوّدُ
/// اسمُ عمله ومحافظتُه وحالُ توثيقه.
///
/// **والغلافُ صورةُ صاحبه إن رفعها، وإلّا فالتدرّجُ النبيذيّ.** اختار صاحبُ
/// المنصّة هذا الشكل — «(ب) غلافٌ مستقلٌّ فوق الرأس» — بعد أن عُرض عليه
/// الشكلان. وأكثرُ الناس لن يرفعوا شيئاً، فحالُ الفراغ ليست حالَ عطبٍ تُعالج
/// بمربّعٍ رماديّ: هي الرأسُ القديمُ كما كان.
///
/// ويمتدّ إلى حافّتَي الشاشة ويبدأ من أعلاها — فيمرّ تحت الشريط الزجاجي بدل
/// أن يقف تحته بحاشيةٍ بيضاء تقطعه.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.badgeBesideTitle = false,
    this.titleTrailing,
    this.titleLtr = false,
    this.subtitleLtr = false,
    this.footer,
    this.coverUrl,
    this.onEditCover,
    this.coverBusy = false,
  });

  final Widget avatar;
  final String title;
  final String subtitle;

  /// نصُّ الشارة الذهبية — دورُ العميل أو حالُ توثيق المزوّد.
  ///
  /// **وفارغٌ يُسقطها.** ولولا ذلك لَرُسم قرصٌ ذهبيٌّ صغيرٌ بلا نصّ.
  final String badge;

  /// أتقف الشارةُ إلى جانب الاسم بدل أن تكون تحته؟
  ///
  /// **وفي شاشةٍ من اليمين إلى اليسار «جانبُه» هو يسارُه** — وهو ما طلبه
  /// صاحبُ المنصّة لرأس «حسابي». وتبقى تحته في ملفّ المزوّد: هناك الشارةُ
  /// حالُ توثيقٍ قد تطول («بانتظار المراجعة»)، و«يسارَ الاسم» يزاحمها
  /// العلامةُ الزرقاء.
  final bool badgeBesideTitle;

  /// ما يلي الاسمَ مباشرةً — علامةُ التوثيق مثلاً.
  final Widget? titleTrailing;

  /// الاسمُ نفسه لاتينيّ — يقع البريدُ مكانه قبل أن يصل الملفّ.
  final bool titleLtr;

  /// السطرُ الثانوي لاتينيٌّ (جوالٌ أو بريد) فيُرسم من اليسار.
  final bool subtitleLtr;

  /// سطرٌ تحت الشارة — تحذيرٌ أو سببُ رفض.
  final Widget? footer;

  /// رابطُ الغلاف — `null` لمن لم يرفع، وهم الأكثرون.
  final String? coverUrl;

  /// يُنادى حين يُطلب تبديلُ الغلاف. `null` يُخفي الزرَّ كلَّه — فلا يُعرض
  /// زرٌّ في شاشةٍ لا تملك رفعاً.
  final VoidCallback? onEditCover;

  /// الرفعُ جارٍ — يُستبدل بالرمز دوّارةٌ، فلا يضغط مرّتين ولا يظنّه معلَّقاً.
  final bool coverBusy;

  /// ارتفاعُ شريط الغلاف تحت شريط الحالة.
  static const double coverBand = 152;

  /// سطرُ المحافظة (أو البريد) — **يُبنى في موضعٍ واحدٍ ويُركَّب في اثنين:**
  /// وحدَه لمن لا شارةَ معه، وداخلَ صفٍّ مع الشارة لمن معه شارة. ولو كُتب
  /// مرّتين لَافترقَ نمطاهما يومَ يُصحَّح أحدُهما.
  Widget _subtitleText() => Text(
        subtitle,
        // **والاتجاهُ يتبع ما يُعرض لا الصفحة:** جوالٌ أو بريدٌ لاتينيٌّ
        // بلا `ltr` تتقدّم نقطتُه وامتدادُه إلى غير موضعهما فيُقرأ مقلوباً.
        textDirection: subtitleLtr ? TextDirection.ltr : null,
        textAlign: subtitleLtr ? TextAlign.left : null,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.muted,
          fontFamilyFallback: arabicFallback,
        ),
      );

  @override
  Widget build(BuildContext context) {
    // **ويمتدّ تحت شريط الحالة.** الصورةُ تبدأ من أعلى الشاشة كما كان
    // التدرّجُ يبدأ، وإلّا ظهرت حاشيةٌ بيضاء فوق الغلاف تقطعه عن الحافّة.
    final band = MediaQuery.paddingOf(context).top + coverBand;

    return Container(
      color: AppColors.surface,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            height: band,
            child: _Cover(
              url: coverUrl,
              // **والشريطُ يُعرض، والحبّةُ تُبدّل.** اختار صاحبُ المنصّة (ب):
              // «يُضغط فتكبر ملءَ الشاشة». والحبّةُ مكتوبٌ عليها «تغيير»
              // فتمضي إلى التبديل مباشرةً — ولو فتحت العارضَ لَخالف الزرُّ
              // اسمَه.
              //
              // **ومن لا غلافَ له يمضي إلى التبديل**: شاشةٌ سوداءُ فارغةٌ لا
              // تقول شيئاً، والضغطةُ عنده تعني «أضِف» لا «انظر».
              onView: () => openPhoto(context, url: coverUrl, onEdit: onEditCover),
              onEdit: onEditCover,
              busy: coverBusy,
            ),
          ),
          // **وعرضُه يُفرض فرضاً.** الطفلُ غيرُ المموضَع في `Stack` يأخذ
          // قيوداً مرنة، فعمودٌ بلا هذا ينكمش إلى عرض أطولِ نصٍّ فيه —
          // فتنزاح الحشوةُ الجانبيّةُ والأرضيّةُ البيضاء معه.
          SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: band - profileAvatarSize / 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // **والطوقُ أبيضُ لا ذهبيّ.** القرصُ يقع على حدّ
                      // الصورة والبياض، فطوقٌ بلون الورقة يفصله عن كليهما —
                      // وذهبيٌّ هنا يضيع في غلافٍ ذهبيّ الإضاءة.
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                        ),
                        child: avatar,
                      ),
                      const SizedBox(height: Space.sm),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              textDirection: titleLtr ? TextDirection.ltr : null,
                              textAlign: titleLtr ? TextAlign.left : null,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                                fontFamilyFallback: arabicFallback,
                              ),
                            ),
                          ),
                          if (titleTrailing != null) ...[
                            const SizedBox(width: 5),
                            titleTrailing!,
                          ],
                          // **والشارةُ بعد الاسم في الصفّ — أي يسارَه.**
                          // و`Flexible` فوق الاسم تقصُّه بنقاطٍ إن طال وتُبقي
                          // الشارةَ كاملة: الشارةُ هي المعلومة، والاسمُ
                          // يعرفه صاحبُه.
                          if (badgeBesideTitle && badge.isNotEmpty) ...[
                            const SizedBox(width: Space.sm),
                            _GoldBadge(badge),
                          ],
                        ],
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        // **والشارةُ تركب سطرَ المحافظة بدل سطرٍ تستقلّ به**
                        // — بطلب صاحب المنصّة: «كلمة موثّق أخذت مساحة،
                        // أريدها جنب المحافظة». والرأسُ يقصُر سطراً فترتفع
                        // الأبوابُ تحته.
                        //
                        // **و`Flexible` على المحافظة لا على الشارة:**
                        // «قيد المراجعة» ضِعفُ «موثّق» طولاً وهي حالُ كلِّ
                        // مزوّدٍ جديد — فتُقَصّ المحافظةُ بنقاطٍ إن ضاق
                        // العرضُ وتبقى الشارةُ كاملة. والحالُ هي المعلومة،
                        // والمحافظةُ يعرفها صاحبُها.
                        if (!badgeBesideTitle && badge.isNotEmpty)
                          Row(
                            children: [
                              Flexible(child: _subtitleText()),
                              const SizedBox(width: Space.sm),
                              _GoldBadge(badge),
                            ],
                          )
                        else
                          _subtitleText(),
                      ],
                      // **ومن لا محافظةَ له تبقى شارتُه في سطرها** — لا
                      // تُرفع لأنّ سطرَها الجديدَ غيرُ موجود.
                      if (subtitle.isEmpty && !badgeBesideTitle && badge.isNotEmpty) ...[
                        const SizedBox(height: Space.sm),
                        _GoldBadge(badge),
                      ],
                      if (footer != null) ...[const SizedBox(height: Space.md), footer!],
                      const SizedBox(height: Space.lg),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// شريطُ الغلاف: صورةُ صاحبه، أو التدرّجُ النبيذيّ لمن لم يرفع.
class _Cover extends StatelessWidget {
  const _Cover({
    required this.url,
    required this.onView,
    required this.onEdit,
    required this.busy,
  });

  final String? url;

  /// ضغطةُ الشريط — تفتح العارضَ، أو تمضي إلى التبديل لمن لا غلافَ له.
  final VoidCallback? onView;

  final VoidCallback? onEdit;
  final bool busy;

  static const _gradient = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [AppColors.accentLift, AppColors.accentDeep],
      ),
    ),
    child: SizedBox.expand(),
  );

  @override
  Widget build(BuildContext context) {
    final link = url;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (link == null)
          _gradient
        else ...[
          Image.network(
            link,
            fit: BoxFit.cover,
            // **وشبكةٌ تسقط لا تُخرج مربّعاً مكسوراً**، ولا تُخرج فراغاً
            // أبيضَ يطفو فيه القرص: يعود التدرّجُ كأنّ لا غلاف.
            errorBuilder: (_, _, _) => _gradient,
          ),
          // حجابٌ في الأسفل — يفصل الصورةَ عن البياض تحتها ولا يطفئها،
          // ويُبقي الزرَّ الأبيضَ مقروءاً على غلافٍ فاتح.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x595C0820)],
              ),
            ),
            child: SizedBox.expand(),
          ),
        ],
        if (onEdit != null) ...[
          // **والغلافُ كلُّه يُضغط لا حبّةٌ في زاويته.**
          //
          // أخرج صاحبُ المنصّة عيباً: «ما يقدر العميل ولا مقدم الخدمة تحديد
          // الصورة». وقِيس الزرُّ في القشرة الحقيقيّة فوُجد ويُضغط وتُفتح به
          // الورقة — فالطبقةُ البرمجيّةُ سليمة. **والباقي أنّه لم يُرَ**:
          // شريطٌ عريضٌ كلُّه صورة، وحبّةٌ عرضُها تسعون بكسلاً في طرفه.
          //
          // ومبدأُ التطبيق مكتوبٌ عند قرص الصورة منذ كُتب: «مكانُ تغيير
          // الصورة هو الصورةُ نفسها». فلزم الغلافَ ما لزم القرص.
          //
          // **وحبّةُ «تغيير الغلاف» رُفعت بطلب صاحب المنصّة.**
          //
          // وكان مكتوباً هنا أنّها لا تُرفع لأنّها العلامةُ التي تقول إنّ
          // الشريطَ يُضغط. **والحجّةُ تبقى مكتوبةً ولا تُمحى**، وقد نُقضت
          // بقرارٍ لا سهواً: «شيلها وخلّي لي تغيير عند ضغط». فصار الغلافُ
          // كالقرص سواءً — يُضغط بلا كلمةٍ عليه، و«تغيير» في العارض.
          //
          // **ويبقى ما يُرى أثناء الرفع.** حبّةٌ ذهبت ودوّارةٌ بقيت: رفعٌ
          // صامتٌ يُقرأ تعطّلاً، فيُضغط مرّةً ثانيةً فوق رفعٍ جارٍ.
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: const ValueKey('cover-tap'),
                onTap: busy ? null : onView,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          if (busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x4D000000),
                child: Center(
                  child: SizedBox(
                    key: ValueKey('cover-busy'),
                    height: 26,
                    width: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
  );
}

class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.size = 12, this.maxLines});
  final String text;
  final double size;

  /// حدُّ الأسطر — يُترك فارغاً فيلتفّ النصّ كما كان.
  ///
  /// يُمرَّر حيث يكون النصّ في صفٍّ ضيّق: مبلغان بالريال اليمني جنباً إلى جنب
  /// تجاوزا عرض الجوال بستّةٍ وأربعين بكسلاً، والأرقام هنا تطول بطبعها.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    style: TextStyle(fontSize: size, color: AppColors.muted),
  );
}

/// «متّصل الآن» أو «آخر ظهور منذ ٣ ساعات».
///
/// **ولا يُكتب «غير متّصل» أبداً.** عبارةٌ نافيةٌ تحت اسم صاحب القاعة تقول
/// للعميل «لن يردّ» — وهو قد يردّ بعد دقيقة. و«آخر ظهور منذ ٣ ساعات» تقول
/// الشيء نفسه بلا حكم، وتزيد عليه ما ينفع: كم انتظر.
///
/// ومن لا ظهورَ له مسجَّلٌ بعدُ لا يُرسم له سطرٌ أصلاً. فالبديل — «آخر ظهور
/// غير معروف» — سطرٌ يشغل مكاناً ولا يحمل خبراً، وهو حالُ كلِّ مستخدمٍ لم
/// يفتح التطبيق منذ إضافة النبضة.
class PresenceLine extends StatelessWidget {
  const PresenceLine({
    super.key,
    required this.lastSeen,
    this.size = 12,
    this.center = false,
  });

  final DateTime? lastSeen;
  final double size;

  /// يُتوسَّط تحت اسمٍ متوسَّط — كما في الملفّ العامّ.
  final bool center;

  @override
  Widget build(BuildContext context) {
    final seen = lastSeen;
    if (seen == null) return const SizedBox.shrink();

    if (Presence.isOnline(seen)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          // النقطةُ زينةٌ تسبق الخبر لا تحملُه: من لا يميّز الأخضرَ يقرأ
          // «متّصل الآن» كاملةً بجوارها.
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.good,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            tr('متّصل الآن'),
            style: TextStyle(
              fontSize: size,
              color: AppColors.good,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Text(
      trf('آخر ظهور {0}', [formatRelative(seen.toIso8601String())]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: TextStyle(fontSize: size, color: AppColors.muted),
    );
  }
}

/// تقييمٌ بنجمة وعدد.
///
/// النجمة أيقونة لا حرف «★»: الحرف خارج تغطية معظم خطوط الواجهة، فيظهر مربّعاً
/// فارغاً على الأجهزة التي لا تحمل خطّ الرموز. وأيقونات Material مرفقة بالحزمة
/// فترسم دائماً.
class Rating extends StatelessWidget {
  const Rating(this.value, {super.key, this.count, this.size = 12});
  final num value;
  final int? count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ذهبٌ لا كهرمانُ التحذير: نجمةٌ بلون «انتبه» تجعل التقييمَ العاليَ
        // يُقرأ إنذاراً. وهو `gold` المقيس (‎٤٫٦٨:١‎) لا ذهبُ الشعار الفاتح
        // الذي لا يُقرأ على أبيض.
        Icon(Icons.star_rounded, size: size + 4, color: AppColors.gold),
        const SizedBox(width: 2),
        Muted(count == null ? '$value' : '$value ($count)', size: size),
      ],
    );
  }
}

/// عنوانُ البطاقة — شريطٌ نبيذيٌّ وحبرٌ أبيض، والشارةُ في طرفه.
///
/// اختاره صاحبُ المنصّة من ثلاثةِ أشكالٍ عُرضت عليه: **(ج) شريطٌ داخلَ
/// الحشوة** — بعرض السطر لا بعرض البطاقة، فتبقى للبطاقة حافّتُها البيضاء.
///
/// **وواحدٌ في موضعين لا نسختان.** «خدماتي» و«الطلبات» يعرضان العنوانَ
/// نفسَه، ونسختان متطابقتان تفترقان بمرور الوقت: يُعدَّل اللونُ في إحداهما
/// فتبقى الأخرى، فيظنّ المزوّدُ أنّهما شيئان.
///
/// ── والشارةُ تفقد لونَها هنا، وقد قيل له ذلك ────────────────────────────
///
/// `StatusBadge` يرسم «معروضة» بأخضرَ على شفّاف، **وأخضرُ على النبيذيّ لا
/// يُقرأ — ‎١٫٧:١‎**. فشارةُ هذا الشريط بيضاءُ كلُّها: تُقرأ الحالُ من
/// الكلمة لا من اللمحة. وهو ثمنُ الشكل الذي اختاره بعد أن عُرض عليه.
class CardTitleBar extends StatelessWidget {
  const CardTitleBar(this.title, {super.key, this.badge, this.opens = false});
  final String title;

  /// نصُّ الحالة — أو `null` فلا شارة.
  final String? badge;

  /// هل تُفتح البطاقةُ بالضغط؟ فيُرسم سهمٌ يقول ذلك.
  ///
  /// **والعلامةُ تُطلب لا تُستنتج**: بطاقةٌ لها `onTap` قد يكون فعلُها
  /// تبديلاً في مكانه لا فتحَ شاشة، وسهمٌ فوقها يَعِد بما لا يقع. فمن يفتح
  /// شاشةً يقولها.
  ///
  /// **ولمَ سهمٌ والبطاقةُ تنخفض تحت الإصبع:** الانخفاضُ لا يُعلم إلّا بعد
  /// أن يُجرَّب، والسهمُ يُعلم قبله. اختاره صاحبُ المنصّة حين شكا أنّ
  /// «البطاقات غير قابلة للضغط» — وكانت تُضغط بعضُها ولا يُرى ذلك.
  final bool opens;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          // سطرٌ واحدٌ وقصٌّ عند الضيق: عنوانٌ يلتفّ سطرين داخل شريطٍ ملوَّن
          // يجعل الشريطَ كتلةً، واسمُ الخدمة يكتبه صاحبُها فلا حدَّ لطوله.
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.accentInk,
            ),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: Space.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accentInk),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.accentInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (opens) ...[
          const SizedBox(width: Space.xs),
          // **والجهةُ تتبع اتّجاهَ اللغة**: في العربيّة يُتقدَّم إلى اليسار.
          //
          // **ولا تُسأل الجهةُ هنا، فالأيقونةُ تنقلب بنفسها.** كنتُ كتبتُ
          // `rtl ? chevron_left : chevron_right` وفي رأسي أنّ الأيقونةَ
          // ثابتة — وليست كذلك: `chevron_left` و`chevron_right` كلتاهما
          // `matchTextDirection: true` في Flutter، أي تنعكسان مع اللغة.
          // فكان سؤالُ الجهة انعكاساً ثانياً يُلغي الأوّل، **والسهمُ يشير
          // إلى الخلف في العربيّة كلِّها**. ولم يظهر ذلك إلّا في لقطةٍ
          // للشاشة الحقيقيّة.
          //
          // فتُكتب الصورةُ اللاتينيّةُ وحدَها (تشير إلى الأمام في الإنجليزيّة)
          // ويتكفّل الإطارُ بقلبها في العربيّة.
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.accentInk,
          ),
        ],
      ],
    ),
  );
}

/// شارة حالة — لون وحدّ، مع نصّ يُقرأ بلا الاعتماد على اللون.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.color = AppColors.muted});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(999),
    ),
    // سطرٌ واحد وقصٌّ عند الضيق: شارةٌ تلتفّ سطرين تكسر ارتفاع الصفّ الذي
    // هي فيه، وشارةٌ تفيض تُسقط التخطيط كلّه. و«بانتظار مقدّم الخدمة» أطولُ
    // نصٍّ فيها — وقد أفاض بطاقةَ الرئيسية ستّةً وأربعين بكسلاً.
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );
}

/// أزرقُ التوثيق.
///
/// **وهو أزرقُ لا نبيذيّ، وهذا خروجٌ عن لوح الألوان عن قصد.** علامةُ التوثيق
/// الزرقاء ليست زينةً من عندنا: هي عُرفٌ تعلّمه الناسُ من فيسبوك وإنستغرام
/// وتويتر وتيك توك، فيقرؤونها في لمحةٍ بلا أن يقرأوا حرفاً. وصبغُها بلون
/// الهويّة يجعلها زخرفةً أخرى في شاشةٍ نبيذيّةٍ كلُّها — تُرى ولا تُفهم.
const verifiedBlue = Color(0xFF1D9BF0);

/// علامةُ التوثيق — قرصٌ مسنَّنٌ أزرقُ فيه صحّ.
///
/// تقع **إلى جانب الاسم** لا في سطرٍ تحته: هي صفةٌ للاسم لا خبرٌ مستقلّ، ومن
/// رآها لصيقةً به عرف من فوره أن هذا هو المزوّد الذي وثّقته الإدارة لا اسماً
/// كتبه من شاء.
///
/// وحجمُها من حجم النصّ الذي تجاوره: علامةٌ بحجمٍ ثابت إلى جانب اسمٍ كبير
/// تبدو منسيّة، وإلى جانب اسمٍ صغير تبدو دخيلة.
class VerifiedMark extends StatelessWidget {
  const VerifiedMark({
    super.key,
    this.size = 18,
    this.tooltip,
    this.color = verifiedBlue,
  });

  final double size;

  /// نصُّ التلميح — يُترك فارغاً فيكون «مزوّد موثَّق».
  ///
  /// **وفارغاً لا نصّاً افتراضيّاً:** المُنشئُ `const` فلا تُنادى
  /// فيه `tr()`، والنداءُ يقع عند البناء حيث تُعرف لغةُ الشاشة.
  final String? tooltip;

  /// **ويُمرَّر ليُسأل عنه.** لونٌ محبوسٌ في رسّامٍ خاصٍّ لا يُقاس إلّا
  /// بقراءة البكسلات، فيُخرَج إلى حيث يُقرأ.
  final Color color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? tr('مزوّد موثَّق'),
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _VerifiedPainter(color: color),
        child: Center(
          // الأبيضُ على هذا الأزرق ‎٣٫٠٩:١‎ — وهو حدُّ النصّ الكبير والرموز.
          child: Icon(Icons.check_rounded, size: size * 0.56, color: Colors.white),
        ),
      ),
    ),
  );
}

/// القرصُ المسنَّن — اثنا عشرَ فصّاً حول دائرة.
///
/// **ويُرسم باتّحاد دوائرَ لا بمضلّعٍ نجميّ.** المضلّعُ يعطي تروساً حادّةَ
/// الأطراف، والفصوصُ في هذه العلامة **مستديرة**. واتّحادُ اثنتَي عشرةَ دائرةً
/// صغيرةً حول دائرةٍ كبرى يعطي الشكلَ نفسَه بلا حسابِ منحنيات.
class _VerifiedPainter extends CustomPainter {
  const _VerifiedPainter({required this.color});
  final Color color;

  static const _lobes = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2;
    if (r <= 0) return;
    final centre = Offset(size.width / 2, size.height / 2);

    // القرصُ الداخليّ يبتلع أنصافَ الدوائر الداخلة فيه فلا يبقى إلّا نتوءُها.
    final core = r * 0.80;
    final lobe = r * 0.235;
    final ring = r - lobe;

    var path = Path()..addOval(Rect.fromCircle(center: centre, radius: core));
    for (var i = 0; i < _lobes; i++) {
      final a = i * 2 * math.pi / _lobes - math.pi / 2;
      final c = centre + Offset(math.cos(a) * ring, math.sin(a) * ring);
      path = Path.combine(
        PathOperation.union,
        path,
        Path()..addOval(Rect.fromCircle(center: c, radius: lobe)),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_VerifiedPainter old) => old.color != color;
}

/// صورةُ مقدّم الخدمة: شعارُه إن رفعه، وإلّا حرفُه في قرص.
///
/// **والحرفُ ليس عيباً يُخفى:** جدولُ المزوّدين لا يفرض شعاراً، فمن لم يرفع
/// شيئاً يُعرض بحرفه بلونٍ من لون العلامة — لا بإطارٍ رماديٍّ فارغ يقول إن
/// صورةً لم تُحمَّل، ولا بأيقونةِ صورةٍ مكسورة.
class ProviderAvatar extends StatelessWidget {
  const ProviderAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 54,
    this.ring = 0,
  });

  final String name;
  final String? imageUrl;
  final double size;

  /// إطارٌ أبيضُ حولها — يُستعمل حين تقع على غلافٍ ملوّن.
  final double ring;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final letter = name.trim().isEmpty ? tr('؟') : name.trim().characters.first;
    return Container(
      width: size + ring * 2,
      height: size + ring * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring > 0 ? AppColors.surface : Colors.transparent,
      ),
      alignment: Alignment.center,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: url == null || url.isEmpty
              ? _letter(letter)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  // وعطبُ الشبكة يعود إلى الحرف لا إلى أيقونةٍ مكسورة: الصورة
                  // زينةٌ والاسمُ هو الخبر.
                  errorBuilder: (_, _, _) => _letter(letter),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : _letter(letter),
                ),
        ),
      ),
    );
  }

  Widget _letter(String letter) => Container(
    color: AppColors.accent.withValues(alpha: Tint.disc),
    alignment: Alignment.center,
    child: Text(
      letter,
      style: TextStyle(
        fontSize: size * 0.42,
        fontWeight: FontWeight.w700,
        color: AppColors.accent,
      ),
    ),
  );
}

/// سطر «اسم: قيمة» بمحاذاة طرفَي البطاقة.
class KeyValue extends StatelessWidget {
  const KeyValue(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.sm),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Muted(label),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

// ============================================================================
//  الانتظار
// ============================================================================

/// أين يقف رأسُ القوس وكم طولُه عند اللحظة [v] من الدورة (‎٠–١‎).
///
/// **وشرطان يجب أن يصحّا وإلّا اهتزّ الدوّار:**
///
///   ١. **أن يعود إلى حيث بدأ عند تمام الدورة** — أي أنّ ما يقطعه الذيلُ في
///      الدورة الواحدة دوراتٌ صحيحةٌ لا كسر. وإلّا قفز القوسُ قفزةً مع كلّ
///      دورة، وهي قفزةٌ تُرى ولا يُعرف سببُها.
///   ٢. **وألّا يسبق الذيلُ الرأسَ** — وإلّا انقلب الطولُ سالباً فاختفى
///      القوسُ لحظةً في كلّ دورة.
///
/// وكلاهما مقيسٌ في `loading_test.dart` على مئة نقطةٍ من الدورة، لأنّ
/// أيَّهما انكسر لا يظهر إلّا لعينٍ تنظر إلى الدوّار ثوانيَ متّصلة.
({double start, double sweep}) spinnerPhase(double v) {
  // الرأسُ يسبق في نصف الدورة الأوّل، والذيلُ يلحقه في الثاني.
  final head = Curves.easeInOut.transform((v / 0.5).clamp(0.0, 1.0));
  final tail = Curves.easeInOut.transform(((v - 0.5) / 0.5).clamp(0.0, 1.0));
  const turn = 2 * math.pi;
  const minSweep = 0.05;
  const span = 0.78;
  return (
    // ‎−π/٢‎: تبدأ من أعلى الدائرة لا من يمينها.
    start: (v + tail) * turn - math.pi / 2,
    sweep: (minSweep + span * (head - tail)) * turn,
  );
}

/// دوّارُ الانتظار — قوسٌ يلفّ ويتنفّس، من الذهبيّ إلى نبيذيّ الهويّة.
///
/// **ولمَ لا `CircularProgressIndicator`:** لأنّه دوّارُ أندرويد نفسُه في كلّ
/// تطبيقٍ على الجهاز، أزرقَ كان أو مصبوغاً. وأكثرُ ما يُرى من التطبيق في
/// أوّل ثانيتين هو هذا الدوّار — فأن يكون من الهويّة أَولى من أن يكون من
/// النظام.
class BrandSpinner extends StatefulWidget {
  const BrandSpinner({
    super.key,
    this.size = 40,
    this.stroke = 3.4,
    this.color = AppColors.accent,
    this.tint = AppColors.gold,
  });

  final double size;
  final double stroke;

  /// طرفُ القوس الغامق، وهو لونُ أثره الباهت كذلك.
  final Color color;

  /// طرفُه الفاتح.
  final Color tint;

  @override
  State<BrandSpinner> createState() => _BrandSpinnerState();
}

class _BrandSpinnerState extends State<BrandSpinner> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // **ويُطفأ ويُشعل في الاتّجاهين.** الإعدادُ يُبدَّل والتطبيقُ مفتوح،
    // فمن شغّله وشاشةُ انتظارٍ معروضةٌ يبقى الدوّارُ يلفّ في وجهه لو لم
    // يُسأل إلّا مرّةً عند البناء.
    if (reduceMotion(context)) {
      _c?.dispose();
      _c = null;
      return;
    }
    _c ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Widget _paint(double v) => CustomPaint(
    size: Size.square(widget.size),
    painter: _SpinnerPainter(
      phase: spinnerPhase(v),
      stroke: widget.stroke,
      color: widget.color,
      tint: widget.tint,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = _c;
    // **ولمن أطفأ الحركةَ قوسٌ ساكنٌ لا فراغ.** غيابُ الدوّار يُقرأ «لا شيء
    // يحدث»، وهو أسوأ ما يُقال لمن ينتظر.
    if (c == null) return _paint(0.28);
    return AnimatedBuilder(animation: c, builder: (context, _) => _paint(c.value));
  }
}

class _SpinnerPainter extends CustomPainter {
  const _SpinnerPainter({
    required this.phase,
    required this.stroke,
    required this.color,
    required this.tint,
  });

  final ({double start, double sweep}) phase;
  final double stroke;
  final Color color;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (math.min(size.width, size.height) - stroke) / 2;
    if (r <= 0) return;
    final centre = Offset(size.width / 2, size.height / 2);
    final box = Rect.fromCircle(center: centre, radius: r);

    // أثرٌ باهتٌ يُري الدائرةَ كلَّها، فيُقرأ القوسُ ماضياً فيها لا معلَّقاً.
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: 0.10),
    );

    canvas.drawArc(
      box,
      phase.start,
      phase.sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        // **والتدرّجُ يُدار مع القوس.** لو تُرك ثابتاً في مكانه لَتبدّل لونُ
        // الرأس كلّما مرّ بجهة، وهو وميضٌ لا تدرّج.
        ..shader = SweepGradient(
          endAngle: phase.sweep,
          colors: [tint, color],
          transform: GradientRotation(phase.start),
        ).createShader(box),
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) =>
      old.phase != phase ||
      old.stroke != stroke ||
      old.color != color ||
      old.tint != tint;
}

/// كتلةُ الانتظار — دوّارُ الهويّة وسطرٌ يقول ما يُنتظر.
class LoadingBlock extends StatefulWidget {
  const LoadingBlock({
    super.key,
    this.label,
    this.delay = const Duration(milliseconds: 220),
    this.color = AppColors.accent,
    this.tint = AppColors.gold,
    this.labelColor,
  });

  /// السطرُ تحت الدوّار — يُترك فارغاً فيكون «جارٍ التحميل…».
  final String? label;
  final Color color;
  final Color tint;

  /// لونُ السطر — يُترك فارغاً على الأرضيّات الفاتحة، ويُمرَّر على النبيذيّ.
  ///
  /// **ولا يُترك للافتراض هناك:** لونُ `Muted` رماديٌّ نبيذيٌّ باهتٌ صُنع
  /// للأرضيّة الكريميّة، ونسبتُه على النبيذيّ الغامق ‎١٫٢:١‎ — أي لا يُقرأ.
  final Color? labelColor;

  /// كم تُمهَل الشاشةُ قبل أن يظهر شيء.
  ///
  /// **وهذه المهلةُ هي أهمُّ ما في هذه الكتلة.** أكثرُ القراءات تعود في أقلّ
  /// من عُشر ثانية، فدوّارٌ يظهر فوراً يومض ويختفي قبل أن تُدركه العين —
  /// وشاشةٌ تومض في كلّ فتحةٍ تُقرأ متعثّرةً وإن كانت أسرعَ من غيرها. ومن
  /// انتظر فعلاً لم تضرّه خُمسُ ثانيةٍ من السكون.
  final Duration delay;

  @override
  State<LoadingBlock> createState() => _LoadingBlockState();
}

class _LoadingBlockState extends State<LoadingBlock> {
  bool _show = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay <= Duration.zero) {
      _show = true;
      return;
    }
    // ويُلغى في `dispose`: أكثرُ هذه الكتل تُبنى ثمّ تُرمى قبل أن تحين مهلتُها.
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return Center(
      // **والمساحةُ محجوزةٌ قبل الظهور.** لو بُني الفراغُ ثمّ حلَّ محلَّه
      // المحتوى لَقفز ما حوله بعد خُمس ثانية.
      child: AnimatedOpacity(
        opacity: _show ? 1 : 0,
        duration: still ? Duration.zero : Motion.normal,
        curve: Motion.enter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandSpinner(color: widget.color, tint: widget.tint),
            const SizedBox(height: Space.md),
            if (widget.labelColor == null)
              Muted(widget.label ?? tr('جارٍ التحميل…'))
            else
              Text(
                widget.label ?? tr('جارٍ التحميل…'),
                style: TextStyle(fontSize: 12, color: widget.labelColor),
              ),
          ],
        ),
      ),
    );
  }
}

/// هيكلُ تحميلٍ بشكل ما سيأتي — بدل دوّارةٍ في منتصف بياض.
///
/// ── لماذا ─────────────────────────────────────────────────────────────────
///
/// شكا صاحبُ المنصّة أنّ التطبيق «متحجّز»، واختار الدرجةَ الثالثة. والدوّارةُ
/// تقول «انتظر» ولا تقول ماذا تنتظر: الشاشةُ تبيضّ، ثمّ تمتلئ دفعةً واحدةً
/// فتقفز. والهيكلُ يقول «بطاقاتٌ قادمة» ويحجز مكانَها، فلا قفزةَ حين تصل.
///
/// ── وليس لكلّ انتظارٍ هيكل ───────────────────────────────────────────────
///
/// **ولا يحلّ محلَّ كلّ دوّارة.** ما ينتظر صفوفاً يُهيكَل، وما ينتظر فعلاً —
/// زرٌّ يُرسل، خريطةٌ تُفتح — تبقى دوّارتُه: هيكلُ بطاقةٍ داخلَ زرّ كذبٌ في
/// الشكل. والدوّاراتُ التي في الأزرار باقيةٌ كما هي.
///
/// ── والنبضُ يُطفأ لمن طلب ────────────────────────────────────────────────
///
/// كلُّ حركةٍ في هذا التطبيق تسأل «تقليلَ الحركة» — ومن أطفأها رأى رماديّاً
/// ساكناً، وهو يؤدّي المعنى نفسَه.
class SkeletonList extends StatefulWidget {
  const SkeletonList({
    super.key,
    this.rows = 3,
    this.thumb = false,
    this.padding = const EdgeInsets.all(Space.lg),
    this.scrollable = true,
  });

  /// كم بطاقةً تُرسم. ثلاثٌ تكفي: الهيكلُ يقول «قادمٌ» لا «هذا عددُها».
  final int rows;

  /// أفي البطاقة صورةٌ مربّعةٌ إلى جانبها؟ — كبطاقات الخدمات.
  final bool thumb;

  final EdgeInsets padding;

  /// أيمرَّر الهيكلُ بنفسه؟
  ///
  /// **ويُرفع حيث يكون داخلَ ممرَّرٍ آخر.** قائمةٌ داخل قائمةٍ رأسيّةٍ ترمي
  /// «ارتفاعٌ بلا حدّ» — والشاشةُ تسقط حمراءَ وقتَ التحميل وحدَه، فلا يراها
  /// إلّا من فتح على شبكةٍ بطيئة. **وقد وقع ذلك وكشفه اختبار.**
  final bool scrollable;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bar(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.ink.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(6),
    ),
  );

  Widget _card() => AppCard(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.thumb) ...[
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: Space.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(double.infinity, 14),
                const SizedBox(height: Space.sm),
                _bar(140, 11),
                const SizedBox(height: Space.sm),
                _bar(96, 13),
              ],
            ),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    final list = widget.scrollable
        ? ListView.separated(
            padding: widget.padding,
            itemCount: widget.rows,
            separatorBuilder: (_, _) => const SizedBox(height: Space.md),
            itemBuilder: (_, _) => _card(),
          )
        : Padding(
            padding: widget.padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < widget.rows; i++) ...[
                  if (i > 0) const SizedBox(height: Space.md),
                  _card(),
                ],
              ],
            ),
          );
    // **ولا يُضغط الهيكل.** هو صورةُ ما سيأتي لا ما أتى، وضغطةٌ عليه تفتح
    // لا شيء — فتُعلّم صاحبَها أنّ الضغط لا يُجدي.
    final quiet = IgnorePointer(child: list);
    if (still) return quiet;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: quiet,
    );
  }
}

class EmptyBlock extends StatelessWidget {
  const EmptyBlock({super.key, required this.title, this.description});
  final String title;
  final String? description;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SectionTitle(title),
          if (description != null) ...[
            const SizedBox(height: Space.sm),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.7),
            ),
          ],
        ],
      ),
    ),
  );
}

class ErrorBlock extends StatelessWidget {
  const ErrorBlock({super.key, required this.message, this.onRetry, this.details});
  final String message;
  final VoidCallback? onRetry;

  /// نصٌّ تقنيٌّ يُطوى — رمزُ العطب وردُّ الخادم.
  ///
  /// **ويُطوى ولا يُحذف.** عرضُه في وجه العميل يُريه أقواساً لا تعنيه؛ وحذفُه
  /// بالكلّيّة يُعمي صاحبَ المنصّة حين يسأله عميلٌ «ماذا ظهر لك؟». فيبقى
  /// خلف طيّةٍ لا تُفتح إلّا بقصد.
  final String? details;

  @override
  Widget build(BuildContext context) {
    // **وانقطاعُ الشبكة ليس عطباً، فلا يُعرض بوجه العطب.** لا حبرَ أحمرَ
    // ولا «تفاصيل تقنية»: صاحبُ الجوال لم يُخطئ ولا التطبيقُ أخطأ، وإنّما
    // انقطعت شبكتُه — ورمزُ الواي‑فاي المشطوب يقولها في لحظةٍ بلا قراءة،
    // وهو رمزٌ يعرفه الناسُ في كلّ تطبيقٍ وكلّ لغة.
    if (message == offlineMessage) return _offline(context);

    final technical = details?.trim();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.critical, height: 1.7),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: Space.lg),
              OutlinedButton(onPressed: onRetry, child: Text(tr('إعادة المحاولة'))),
            ],
            if (technical != null && technical.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const ValueKey('error-details'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Muted(tr('تفاصيل تقنية'), size: 11),
                  children: [
                    SelectableText(
                      technical,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.6,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// وجهُ الانقطاع — رمزٌ عالميٌّ وسطران وزرُّ إعادة.
  Widget _offline(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: Tint.disc),
            ),
            child: const Icon(
              // **ورمزُ الواي‑فاي المشطوب لا السحابةُ ولا علامةُ التعجّب.**
              // هذا هو الرمزُ الذي يعرفه الناسُ من كلّ تطبيقٍ استعملوه، ومن
              // شريط الحالة في أعلى جوالهم نفسِه.
              Icons.wifi_off_rounded,
              key: ValueKey('offline-icon'),
              size: 36,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: Space.lg),
          Text(
            tr('لا يوجد اتصال بالإنترنت'),
            key: ValueKey('offline-title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            // **ويُقال ما يُفعل لا ما وقع فقط.** «لا يوجد اتصال» خبرٌ،
            // و«شغّل البيانات أو الواي‑فاي» عملٌ يُفعل الآن.
            tr('شغّل بيانات الجوال أو الواي‑فاي، ثم أعد المحاولة.'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.7, color: AppColors.muted),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: Space.lg),
            FilledButton(onPressed: onRetry, child: Text(tr('إعادة المحاولة'))),
          ],
        ],
      ),
    ),
  );
}

/// أيقونة القسم من `slug`.
///
/// من الـ`slug` لا من عمود `icon` في القاعدة: العمود موجودٌ لكنه فارغٌ في
/// البذرة، و`slug` معرّفٌ برمجيٌّ لا يُترجم ولا يُغيَّر بعد أن تُبنى عليه
/// بيانات — فهو الأثبت.
///
/// والافتراضيّ ليس زينة: من يضيف قسماً جديداً من اللوحة غداً يجد له أيقونةً
/// معقولة بدل فراغٍ في بطاقةٍ نصفُها فارغ.
IconData categoryIcon(String slug) => switch (slug) {
  // **خيمةٌ لا باب.** كان `meeting_room` — وهو بابٌ يخرج منه سهم، يُقرأ
  // «خروج» لا «قاعة». والقسمُ اسمُه «القاعات والخيام»، و`festival` سرادقٌ
  // مضروبٌ بأعمدة: هو الشيءُ نفسُه الذي يُحجَز.
  'halls' => Icons.festival_outlined,
  'catering' => Icons.restaurant_outlined,
  // **ميكروفونٌ لا نوتة.** النوتةُ تقول «موسيقى»، والقسمُ مغنّون وفرقٌ
  // تُحجَز لتُحيي ليلة — والميكروفونُ يقول ذلك بلا حرف.
  'artists' => Icons.mic_outlined,
  'sound' => Icons.speaker_outlined,
  'photography' => Icons.photo_camera_outlined,
  'support' => Icons.water_drop_outlined,
  'cars' => Icons.directions_car_outlined,
  'attire' => Icons.checkroom_outlined,
  // **ولا دفترَ مواعيدَ لمتعهّدي الحفلات.** كان `event_note` — وهو التقويمُ
  // نفسُه الذي في شريط التنقّل، فيلتبس القسمُ بالتبويب.
  'planners' => Icons.celebration_outlined,
  // **مقصٌّ لا فرشاةُ دهان.** كان `brush` — وهي فرشاةُ طلاءٍ تُقرأ «دهان»؛
  // والقسمُ «التجميل والكوافير».
  'beauty' => Icons.content_cut_outlined,
  'decor' => Icons.local_florist_outlined,
  'printing' => Icons.print_outlined,
  _ => Icons.category_outlined,
};

/// صبغة القسم.
///
/// لونٌ لكل قسمٍ لا لونٌ واحد: صفٌّ من اثنتي عشرة بطاقةٍ بلونٍ واحد يُقرأ
/// كتلةً تُبحث بالقراءة، والصبغةُ تجعل كلَّ بطاقةٍ تُعرف قبل أن يُقرأ اسمها.
///
/// **وعائلةٌ دافئة لا قوسُ قزح:** كانت الاثنتا عشرة أزرقَ وبنفسجيّاً
/// وفيروزيّاً، فتُقرأ فوق الكريم كأنها من تطبيقٍ آخر لُصقت هنا. فنُقلت كلُّها
/// إلى جيرانِ النبيذيّ — طَفلٌ وصدأٌ وزيتونٌ وخُزاميّ — فتبقى كلُّ بطاقةٍ
/// تُعرف قبل أن يُقرأ اسمها، ويبقى الصفُّ كلُّه من عائلةٍ واحدة.
///
/// والاثنتا عشرة مقيسةٌ على أرضية البطاقة: أدناها ‎٥٫٥٥:١‎ وأعلاها ‎١٠٫٧٦:١‎
/// — فلا واحدةَ منها زينةٌ لا تُقرأ. وقياسٌ لا ذوق، لأن «يبدو واضحاً» على
/// شاشةِ من يكتب غيرُه في شمسِ من يستعمل.
Color categoryTone(String slug) => switch (slug) {
  'halls' => AppColors.accent,
  'catering' => const Color(0xFFA3521A),
  'artists' => const Color(0xFF6B2E8F),
  'sound' => const Color(0xFF14615F),
  'photography' => const Color(0xFFB01C5B),
  'support' => const Color(0xFF1F5D8C),
  'cars' => const Color(0xFF4A3F86),
  'attire' => const Color(0xFF93174A),
  'planners' => const Color(0xFF2F6B33),
  'beauty' => const Color(0xFF8E2270),
  'decor' => const Color(0xFFB23C12),
  'printing' => const Color(0xFF5F6B12),
  _ => AppColors.ink2,
};

/// بطاقة قسم — قرصٌ بأيقونته واسمُه تحته.
///
/// بطاقةٌ لا شريحة: الشريحة نصٌّ في إطار، وصفٌّ منها يُقرأ كتلةً واحدة يُبحث
/// فيها بالقراءة. والأيقونة تُعرف قبل أن يُقرأ الاسم، فيُمسح الصفُّ بالعين
/// مسحاً واحداً.
///
/// وارتفاعها ثابتٌ لا يتبع طول الاسم: «الموية والطليع والخدمات المساندة»
/// و«السيارات» في صفٍّ واحد، ولو تفاوت الارتفاع لتعرّج الصفّ كلّه.
class CategoryCard extends StatefulWidget {
  const CategoryCard({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.tone,
    this.width = 96,
    this.enterDelay = Duration.zero,
    this.imageUrl,
  });

  final String label;
  final IconData icon;

  /// صورةُ القسم — تحلّ محلّ الأيقونة في الدائرة نفسها.
  ///
  /// **وتعلو الأيقونةَ ولا تُلغيها:** ما لم يُرفع لقسمٍ صورةٌ بعدُ يبقى على
  /// أيقونته، وإن فشل تحميلُها عاد إليها كذلك. فلا تصير الشاشةُ الأولى دوائرَ
  /// فارغةً على شبكةٍ بطيئة.
  ///
  /// وفي الدائرة نفسها لا فوقها: مقاسُ البطاقة لا يتغيّر، فلا تنكسر الشبكةُ
  /// بين قسمٍ ذي صورةٍ وقسمٍ بلا صورة.
  final String? imageUrl;
  final bool active;
  final VoidCallback onTap;

  /// صبغة البطاقة. تُترك فارغةً فتأخذ لون العلامة — وهو حال «الكل».
  final Color? tone;

  /// عرضٌ ثابت في الصفّ الأفقي، ويُترك للشبكة أن تملأه فيها.
  final double? width;

  /// تأخير ظهورها — يُمرَّر متدرّجاً فتدخل البطاقات تباعاً لا دفعةً واحدة.
  final Duration enterDelay;

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _down = false;
  bool _shown = false;

  /// مؤقّت الدخول — يُحفظ ليُلغى.
  ///
  /// `Future.delayed` لا يُلغى: يبقى معلّقاً بعد زوال البطاقة ممسكاً بها،
  /// وإطارُ الاختبار يُسقط أي اختبارٍ يتركه («Pending timers») — وهو محقٌّ،
  /// فالتسريب واحدٌ في الحالتين. والمستخدم يمرّر الشبكة سريعاً فتُبنى
  /// بطاقاتٌ وتزول قبل أن يحين دخولها.
  Timer? _enter;

  @override
  void initState() {
    super.initState();
    // الدخول المتدرّج يُجدول لا يُحسب في البناء: `setState` أثناء البناء
    // ممنوع، والمؤقّت يضع التغيير في الإطار التالي.
    if (widget.enterDelay == Duration.zero) {
      _shown = true;
    } else {
      _enter = Timer(widget.enterDelay, () {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  void dispose() {
    _enter?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone ?? AppColors.accent;
    final active = widget.active;

    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        // تنزلق صاعدةً قليلاً عند الدخول: حركةٌ تدلّ على الترتيب، لا قفزة.
        offset: _shown ? Offset.zero : const Offset(0, 0.12),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: Listener(
          onPointerDown: (_) => setState(() => _down = true),
          onPointerUp: (_) => setState(() => _down = false),
          onPointerCancel: (_) => setState(() => _down = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: _down ? 0.94 : 1,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: widget.width,
                // **والحشوةُ الرأسيّةُ ثمانيةٌ لا اثنا عشر.** الخليّةُ على
                // شاشة ٣٢٠ — وهي أضيقُ ما يُباع — ستٌّ وستّون عرضاً ومئةٌ
                // وستّةٌ ارتفاعاً، و«الموية والطليع والخدمات المساندة» يملؤها
                // ويفيض بكسلاً ونصفاً. قِستُه بالاختبار عند ٣٢٠ لا بالنظر
                // على ٣٦٠ حيث لا يقع.
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.sm,
                  vertical: Space.sm,
                ),
                decoration: BoxDecoration(
                  // أرضيّةٌ بيضاء لا مصبوغة. والصبغةُ كانت تملأ البطاقة كلَّها
                  // فيصير الصفُّ ثمانيةَ ألوانٍ متجاورة، تتزاحم فلا يبرز
                  // منها لون. واللونُ الآن في القرص وحده، والبياضُ حوله يخدمه.
                  color: Colors.white,
                  border: Border.all(
                    color: active ? tone.withValues(alpha: 0.55) : AppColors.hairline,
                    width: active ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    // ظلٌّ يُغلق عند الضغط فتبدو البطاقة وقد غاصت في مكانها.
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: _down ? 0.03 : 0.05),
                      blurRadius: _down ? 4 : 10,
                      offset: Offset(0, _down ? 1 : 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // قرصٌ زجاجيّ: ضوءٌ أبيضُ من أعلى ينحدر إلى صبغة القسم،
                    // وحافّةٌ رقيقةٌ بلونه، وظلٌّ مصبوغٌ تحته. وهو أصغرُ من
                    // سابقه — ٣٤ لا ٣٦ — لأنّ البياضَ حوله صار يحمله.
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.95),
                            tone.withValues(alpha: active ? 0.28 : 0.16),
                          ],
                        ),
                        border: Border.all(
                          color: tone.withValues(alpha: active ? 0.42 : 0.22),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tone.withValues(alpha: 0.14),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _CategoryGlyph(
                        imageUrl: widget.imageUrl,
                        icon: widget.icon,
                        tone: tone,
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    _CategoryLabel(label: widget.label, active: active, tone: tone),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// شريحة اختيار — للأقسام والمحافظات.
class PickChip extends StatelessWidget {
  const PickChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      decoration: BoxDecoration(
        color: active ? AppColors.accent : AppColors.surface,
        border: Border.all(color: active ? AppColors.accent : AppColors.hairline),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: active ? AppColors.accentInk : AppColors.ink2,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    ),
  );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

/// ارتفاع الشريط الزجاجي مع هامشه — تحتاجه القوائم لتُنهي محتواها فوقه.
///
/// ثابتٌ مشترك لا رقمٌ مكرّر: الشريط يطفو والمحتوى يمرّ تحته، فآخرُ بطاقةٍ في
/// أي قائمةٍ تختفي خلفه ما لم تُحسب هذه المسافة. ونسيانُها في شاشةٍ واحدة عيبٌ
/// لا يظهر إلا حين يصل المستخدم إلى آخر القائمة.
///
/// **وزادت بمقدار ارتفاع القرص** (`GlassNavBar.raise`): المختارُ صار يعلو
/// حافّةَ الشريط، فلو بقيت على قدره لَحجب القرصُ آخرَ سطرٍ في كلّ قائمة.
///
/// **وبهامشه السفليّ معه**: الشريطُ صار عائماً لا ملتصقاً، فتحته فرجةٌ
/// يجب أن تُحسب أيضاً.
const double glassNavSpace =
    GlassNavBar.barHeight + GlassNavBar.raise + GlassNavBar.bottomGap + 36;

/// شريط تنقّلٍ سفليٌّ زجاجيّ يطفو فوق المحتوى.
///
/// **والأيقونات ليست بيضاء.** الزجاج أبيض والصفحة `#F4F7FC`، فأبيضُ على
/// أبيضَ يعطي ‎١٫٠٤:١‎ — أي لا شيء. فالمختار بلون العلامة وغيرُه رماديّ، وكلاهما
/// مقيسٌ على الزجاج نفسه لا مقدَّر. والزجاج الأبيض بأيقوناتٍ بيضاء إنما يصلح
/// فوق خلفيةٍ داكنة.
/// حفرةُ الشريط حول القرص — ومعها استدارةُ أركانه الأربعة.
///
/// **والشكلُ معياريٌّ لا مُخترَع:** `CircularNotchedRectangle` هي التي تقصّ
/// بها فلاتر `BottomAppBar` حول زرّها العائم، فمدخلا الحفرة يلتقيان بحافّة
/// الشريط التقاءً أملسَ لا بزاويةٍ حادّة. ثمّ تُقاطَع بمستطيلٍ مستديرِ
/// الأركان لتُستدير حوافُّه.
class _NavNotchClipper extends CustomClipper<Path> {
  const _NavNotchClipper({required this.cx});

  /// مركزُ القرص من يسار الشريط — يُحسب لا يُكتب، فالاتّجاهان يقلبانه.
  final double cx;

  Path build(Size size) {
    final host = Rect.fromLTWH(
      0,
      GlassNavBar.raise,
      size.width,
      size.height - GlassNavBar.raise,
    );
    final rounded = Path()
      ..addRRect(RRect.fromRectAndRadius(
        host,
        const Radius.circular(GlassNavBar.corner),
      ));
    // **والضيفُ أوسعُ من القرص بـ`notchGap`** — وتلك الفرجةُ هي التي يُرى
    // منها ما تحت الشريط، فيبدو القرصُ جالساً في حفرته لا واقفاً عليها.
    final guest = Rect.fromCircle(
      center: Offset(cx, GlassNavBar.raise),
      radius: GlassNavBar.discSize / 2 + GlassNavBar.notchGap,
    );
    final notched = const CircularNotchedRectangle().getOuterPath(host, guest);
    return Path.combine(PathOperation.intersect, rounded, notched);
  }

  @override
  Path getClip(Size size) => build(size);

  @override
  bool shouldReclip(_NavNotchClipper old) => old.cx != cx;
}

/// ظلُّ الشريط — يُرسم على شكل حفرته نفسِه.
///
/// **ولا يصلح `BoxShadow` هنا**: الصندوقُ مقصوصٌ بـ`ClipPath`، والقصُّ يبتلع
/// ظلَّ ما بداخله. فلو تُرك الظلُّ في الصندوق لَخرج الشريطُ بلا ظلٍّ إطلاقاً
/// — ولا يُرى النقصُ إلّا بمقارنةٍ جنباً إلى جنب.
class _NavShadowPainter extends CustomPainter {
  const _NavShadowPainter(this.clipper);
  final _NavNotchClipper clipper;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      clipper.build(size).shift(const Offset(0, -2)),
      Paint()
        ..color = AppColors.ink.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(_NavShadowPainter old) => old.clipper != clipper;
}

/// خطٌّ رفيعٌ يحدّ الشريطَ وحفرتَه.
///
/// **وهو لازمٌ لا زينة.** الشريطُ الذي أرسله صاحبُ المنصّة أزرقُ داكنٌ على
/// أبيضَ فحفرتُه تُرى بنفسها؛ وشريطُنا زجاجٌ فاتحٌ على صفحةٍ فاتحة — فبلا
/// خطٍّ لا يكاد يُعرف أين انقطع الزجاجُ وأين بدأت الصفحة. **وهو الخطُّ الذي
/// طلبه أوّلاً** («خطّ خفيف يفصل بين أيقونة وشريط»)، فصار جزءاً من الشكل.
class _NavOutlinePainter extends CustomPainter {
  const _NavOutlinePainter(this.clipper);
  final _NavNotchClipper clipper;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      clipper.build(size),
      Paint()
        ..color = AppColors.ink.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_NavOutlinePainter old) => old.clipper != clipper;
}

class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<GlassNavItem> items;

  /// ارتفاعُ الشريط نفسِه — دون القرص الذي يعلوه.
  static const double barHeight = 66;

  /// كم يعلو القرصُ المختارُ حافّةَ الشريط.
  ///
  /// **وهو ما يُزاد على `glassNavSpace`**: القرصُ يخرج عن الشريط إلى أعلى،
  /// فلو بقيت المسافةُ على قدر الشريط لَحجب القرصُ آخرَ ما في القائمة.
  ///
  /// **وهو نصفُ القرص بالضبط لا رقمٌ يُختار**: مركزُ القرص على حافّة الشريط،
  /// فنصفُه فوقها ونصفُه في حفرته — وعليه تُبنى الحفرةُ نفسُها.
  static const double raise = discSize / 2;

  /// قطرُ القرص المرتفع.
  static const double discSize = 44;

  /// الفرجةُ بين القرص وحافّة حفرته.
  ///
  /// **وهي التي أغنت عن الطوق الأبيض**: كان القرصُ يقف على الزجاج فيُطوَّق
  /// بلون الصفحة ليُفصَل عنه؛ وصار في حفرةٍ تفصله بفرجةٍ حقيقيّةٍ يُرى منها
  /// ما تحت الشريط — فطوقٌ فوق فرجةٍ حدّان لشيءٍ واحد.
  static const double notchGap = 7;

  /// هامشُ الشريط من جانبَي الشاشة، ومن أسفلِها فوق خطّ النظام.
  ///
  /// **وهذا نقضٌ لاختيارٍ سابقٍ بطلب صاحبه.** كان ملتصقاً بالحافّة («خليه
  /// جزء من التطبيق»، ثمّ «ألصِقه بحافّة الشاشة»)، فلمّا أرسل شريطاً عائماً
  /// ذا حفرةٍ وقال «أريد نفس الاستايل» عُرضت عليه الحالان مفرَّقتين — ومعهما
  /// التنبيهُ أنّ العائمَ ينقض طلبَه السابق — فاختار العائمَ بالأسماء.
  static const double sideMargin = Space.lg;
  static const double bottomGap = 10;

  /// استدارةُ أركانه الأربعة.
  static const double corner = 24;

  /// مقاسُ أيقونة الجار — **اختاره صاحبُ المنصّة من أربعةٍ عُرضت عليه**
  /// («بس صغّر حجم أيقونات»). وهو وقطرُ القرص وأيقونتُه ثلاثةٌ تتحرّك معاً،
  /// فلو صُغّر أحدُها وحدَه لَاختلّت نسبتُه إلى أخويه.
  static const double iconSize = 17;

  @override
  Widget build(BuildContext context) {
    // **وشريطُ النظام تحته ليس فراغاً.** في جوالات الإيماءة خطٌّ للنظام
    // أسفلَ الشاشة؛ والملتصقُ يمتدّ تحته **ويُزاح محتواه فوقه** — ولولا ذلك
    // لَوقعت الأيقوناتُ على خطّه. ولذلك لا `SafeArea` هنا: هي تدفع الشريطَ
    // كلَّه فوق الخطّ فيعود هامشاً من حيث أُريد الالتصاق.
    final systemBar = MediaQuery.paddingOf(context).bottom;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return SizedBox(
      // **عائمٌ له هامشٌ من الجوانب وأسفلِه** — اختار صاحبُ المنصّة ذلك من
      // ثلاثةٍ عُرضت عليه بعد أن أرسل شريطاً ذا حفرة.
      height: barHeight + raise + bottomGap + systemBar,
      child: Padding(
        padding: EdgeInsets.only(
          left: sideMargin,
          right: sideMargin,
          // **والهامشُ فوق خطّ النظام لا تحته**: الشريطُ لم يعد يمتدّ إلى
          // حافّة الشاشة، فلو تُرك على قدر `bottomGap` وحدَه لَوقع على خطّ
          // الإيماءة في جوالاتٍ وبقي معلّقاً في أخرى.
          bottom: bottomGap + systemBar,
        ),
        // العرضُ يُقاس لا يُقدَّر: مركزُ الحفرة نصفُ خانةٍ من طرف الشريط،
        // والخانةُ عرضُ الشريط مقسوماً على البنود.
        child: LayoutBuilder(
          builder: (context, box) {
            final cell = box.maxWidth / items.length;
            // **والاتّجاهُ يقلب الحساب**: البندُ الأوّل في العربيّة أقصى
            // اليمين. وموضعُ القصّ بكسلٌ من اليسار لا بندٌ في صفّ.
            final centre = (index + 0.5) * cell;
            final raw = rtl ? box.maxWidth - centre : centre;
            // **وتُحبس عن الركنين.** الحفرةُ تُقاطَع بمستطيلٍ مستديرِ
            // الأركان، فلو وقعت على ركنٍ أكل القطعُ المشترَك نصفَها: لا
            // حفرةَ تتشكّل، ويتدلّى القرصُ خارجَ الشريط.
            //
            // **وهو عطبٌ وقع فعلاً**: مركزُ الخانة الطرفيّة نحوُ ٣٦ بكسلاً
            // من الحافّة، وهذا الحدُّ ٥٣ — فكسر التبويبَ الأوّل والأخير
            // وحدَهما، وهما أكثرُ ما يُفتح. ورآه صاحبُ المنصّة فظنّ أنّ
            // الشكلَ لم يُنفَّذ أصلاً.
            //
            // والقرصُ يتبع الحفرةَ إلى الداخل فيبقيان متراكزين — وثمنُه أنّ
            // القرصَ في الطرفين ينزاح قليلاً عن مركز خانته، وخانتُه فارغةٌ
            // فلا يُزاحم شيئاً.
            final limit = corner + discSize / 2 + notchGap;
            final cx = box.maxWidth < limit * 2
                // شريطٌ أضيقُ من حفرتين: لا موضعَ إلّا الوسط.
                ? box.maxWidth / 2
                : raw.clamp(limit, box.maxWidth - limit);
            final clipper = _NavNotchClipper(cx: cx);

            return Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                // الظلُّ خارجَ القصّ — وإلّا ابتلعه.
                CustomPaint(painter: _NavShadowPainter(clipper)),
                ClipPath(
                  clipper: clipper,
                  child: BackdropFilter(
                    // التمويه هو ما يجعله زجاجاً لا لوناً شفّافاً: بدونه يُرى
                    // ما تحته كما هو، فيبدو الشريط ورقةً باهتة لا سطحاً.
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Padding(
                      // الزجاجُ يبدأ تحت القرص: ما فوق `raise` حفرةٌ وهواء.
                      padding: const EdgeInsets.only(top: raise),
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.72),
                        child: Row(
                          children: [
                            for (var i = 0; i < items.length; i++)
                              Expanded(
                                child: i == index
                                    // المختارُ في قرصه فوق — وخانتُه هنا
                                    // فارغةٌ تحفظ عرضَها فلا ينزاح جيرانُه.
                                    ? const SizedBox.shrink()
                                    : _GlassNavCell(
                                        item: items[i],
                                        onTap: () => onSelect(i),
                                      ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // والخطُّ فوق الزجاج ليحدّ الحفرةَ نفسَها.
                IgnorePointer(
                  child: CustomPaint(painter: _NavOutlinePainter(clipper)),
                ),
                // **والقرصُ يُضغط كما تُضغط الخانة** — ولولا ذلك لَصار
                // المختارُ وحدَه لا يُضغط، وهو أكبرُ هدفٍ في الشريط.
                Positioned(
                  left: cx - discSize / 2,
                  top: 0,
                  child: _GlassNavDisc(
                    icon: items[index].activeIcon,
                    label: items[index].label,
                    onTap: () => onSelect(index),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class GlassNavItem {
  const GlassNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.unread = 0,
  });
  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// عددُ ما لم يُقرأ على هذا البند — صفرٌ يُسقط الحبّة.
  ///
  /// **ودخلت حين خرجت أيقونةُ الرسائل من الشريط العلويّ**: كانت تحمل
  /// عدّادَها هناك، فلمّا رُفعت لم يبقَ في الشاشة موضعٌ يقول «عندك رسالة».
  final int unread;
}

/// القرصُ المرتفع — المختارُ وحدَه، نصفُه فوق الشريط.
///
/// اختار صاحبُ المنصّة (أ) من ثلاثٍ عُرضت عليه: «الزجاجُ يبقى كما هو،
/// والمختارُ يرتفع في قرصٍ نبيذيّ».
///
/// **وكان يُطوَّق بلون الصفحة، فأغنت الحفرةُ عن طوقه.** القرصُ كان يقف على
/// الزجاج فيلتصق به ما لم يُفصل بطوق؛ وصار مركزُه على حافّة الشريط وحولَه
/// فرجةٌ مقصوصةٌ من الزجاج نفسِه يُرى منها ما تحته — والطوقُ فوق ذلك حدٌّ
/// ثانٍ لشيءٍ واحد، يسدّ الفرجةَ التي هي كلُّ الفكرة.
///
/// **ولا كلمةَ تحته.** الكلماتُ باقيةٌ لجيرانه، وهذه هي الصورةُ التي أُقرّت.
/// ومن هو في تبويبه يعرفه من شاشته، ومن أراد اسمَه فهو في `Semantics` لقارئ
/// الشاشة.
class _GlassNavDisc extends StatelessWidget {
  const _GlassNavDisc({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  static const double size = GlassNavBar.discSize;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        selected: true,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: AppColors.accentInk),
          ),
        ),
      );
}

class _GlassNavCell extends StatelessWidget {
  const _GlassNavCell({required this.item, required this.onTap});
  final GlassNavItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // **وخانةُ غيرِ المختار وحدَها هنا** — المختارُ صار قرصاً فوق الشريط،
    // فلا حالَ ثانيةً في هذه الخليّة ولا حبّةَ تحت أيقونتها.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // **والحبّةُ فوق الأيقونة لا تزيحُها.** `Stack` لا `Row`: صفٌّ
          // يدفع الأيقونةَ عن مركز خانتها فتقف بنداً واحداً منحرفاً عن
          // إخوته — ويُرى ذلك قبل أن يُسمّى.
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(item.icon, size: GlassNavBar.iconSize, color: AppColors.ink2),
              if (item.unread > 0)
                Positioned(
                  top: -7,
                  left: -12,
                  child: UnreadDot(count: item.unread),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: AppColors.ink2,
              fontFamilyFallback: arabicFallback,
            ),
          ),
        ],
      ),
    );
  }
}

/// حبّةٌ بعدد ما لم يُقرأ.
///
/// والعدد فيها لا نقطةٌ صمّاء: «٣» تقول إن ثمّة حديثاً يجري، والنقطة تقول
/// «شيءٌ ما». والحدُّ عند تسعة فـ«٩+» — رقمٌ من ثلاث خانات يمطّ الحبّة حتى
/// تكسر الصفّ الذي هي فيه.
class UnreadDot extends StatelessWidget {
  const UnreadDot({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w700,
          color: AppColors.accentInk,
        ),
      ),
    );
  }
}

/// أيقونةٌ في الشريط العلوي وعليها حبّةُ ما لم يُقرأ.
///
/// في الشريط العلوي لا في الشريط السفلي: بنوده الخمسة محدَّدة، وإضافةُ سادسٍ
/// تضيّق الخمسة كلَّها. والأيقونة هنا في المكان الذي تعوّده الناس من كل تطبيق.
class BadgeIconButton extends StatelessWidget {
  const BadgeIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        // **ولا قرصَ أبيضَ تحتها.** كان تحت كلّ رمزٍ قرصٌ شفّافٌ يقول
        // «زجاج»، فصار في الشريط قرصان وحبّتا عددٍ في ستٍّ وتسعين بكسلاً —
        // أربعةُ أشكالٍ متجاورةٍ تُقرأ ضجيجاً. والزجاجيّةُ موضعُها السطحُ
        // نفسُه لا ما تحت كل رمز.
        //
        // واللون كما هو مقيسٌ: `ink2` على أرضيّة الصفحة ‎٩٫٥٨:١‎، وعلى
        // الزجاج حين تمرّ البطاقةُ النبيذيّة تحته ‎٧٫٣٧:١‎ — والقياسُ في
        // `header_test.dart` يُحسب لا يُنقل.
        style: IconButton.styleFrom(foregroundColor: AppColors.ink2),
        icon: Icon(icon, size: 23),
      ),
      if (count > 0)
        // على ركن الرمز لا على حافّة الزرّ: صندوق `IconButton` ‎٤٨‎ بكسلاً
        // والرمز ‎٢٣‎ في وسطه، فحبّةٌ عند الحافّة تطفو على بُعد أحد عشر بكسلاً
        // منه — تُقرأ عائمةً لا تابعةً له، وتزدحم بجارتها حين يكون في الشريط
        // زرّان. وقد رُئي ذلك في الرسم لا في الشيفرة.
        Positioned(
          top: 7,
          left: 7,
          child: IgnorePointer(child: UnreadDot(count: count)),
        ),
    ],
  );
}

/// أيقونة المحادثات.
class ChatIconButton extends StatelessWidget {
  const ChatIconButton({super.key, required this.unread, required this.onTap});
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BadgeIconButton(
    icon: Icons.forum_outlined,
    tooltip: tr('المحادثات'),
    count: unread,
    onTap: onTap,
  );
}

/// جرس الإشعارات.
class BellIconButton extends StatelessWidget {
  const BellIconButton({super.key, required this.unread, required this.onTap});
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BadgeIconButton(
    icon: Icons.notifications_none_rounded,
    tooltip: tr('الإشعارات'),
    count: unread,
    onTap: onTap,
  );
}

/// ارتفاع الشريط العلوي الزجاجي مع هامشه — تحتاجه القوائم لتبدأ تحته.
///
/// نظيرُ `glassNavSpace` في الأعلى: الشريط يطفو والمحتوى يمرّ **تحته**، وهذا
/// هو ما يعطي التمويهَ ما يموّهه. فبلا هذه المسافة تبدأ أولُ بطاقةٍ خلف
/// الزجاج ولا تُقرأ.
///
/// **وهذه المسافةُ شرطُ سلامةٍ لا ذوق.** الشريطُ بلا سطحٍ ما دامت الشاشةُ في
/// أعلاها، فلو بدأ المحتوى تحته مباشرةً لَوقع الرمزُ الحبريُّ على أوّل بطاقةٍ
/// نبيذيّةٍ بلا زجاجٍ يفصله — وهو ما يجعله غيرَ مقروء. فما دام أوّلُ محتوىً
/// يبدأ **بعد** الشريط، فما خلفه أرضيّةُ الصفحة وحدها.
const double glassHeaderBar = 56;
const double glassHeaderSpace = glassHeaderBar + Space.sm;

/// المسافة الكاملة من أعلى الشاشة: شريط الحالة ثم الزجاج.
double glassHeaderTop(BuildContext context) =>
    MediaQuery.paddingOf(context).top + glassHeaderSpace;

/// شريطٌ علويٌّ ممتدٌّ إلى الحافّة، يظهر سطحُه حين يمرّ المحتوى تحته.
///
/// **وكان بطاقةً عائمة** — مقصوصةً بزاويةِ ‎٢٤‎ ولها ظلٌّ وحدٌّ أبيض، وتحت كلّ
/// أيقونةٍ فيها قرصٌ شفّاف. وعابها ثلاثةُ أشياء:
///
///   ١. أنّها **سطحٌ ثابت**: زجاجُها هو هو سواءٌ كان تحته فراغٌ أو محتوى، فلا
///      يقول للعين أين هي من الصفحة. والرأسُ الذي يتغيّر بالتمرير هو ما
///      يُميّز التطبيقات المصقولة.
///   ٢. أنّ **القرصَ تحت كل رمزٍ ضجيج**: قرصان وحبّتا عددٍ في ستٍّ وتسعين
///      بكسلاً.
///   ٣. أنّ **عنوانَها ١٧ بوزن ٦٠٠** — خجولٌ في موضعٍ هو مرساةُ الشاشة.
///
/// فصار: ممتدّاً من حافّةٍ إلى حافّة، بلا سطحٍ ما دامت الشاشةُ في أعلاها، ثمّ
/// زجاجٌ وشعرةٌ تفصله حين يمرّ المحتوى تحته.
///
/// **والألوان مقيسةٌ لا مذوقة** — و`header_test.dart` يحسبها ولا ينقلها:
/// الحبرُ ‎#2A1119‎ للعنوان على أرضيّة الصفحة ‎١٦٫٢:١‎، و`ink2` للأيقونات
/// ‎٩٫٥٨:١‎. وحين تمرّ البطاقةُ النبيذيّةُ تحت الزجاج (أبيضُ ‎٠٫٨٢‎ فوق
/// ‎#7B0F2E‎) يبقى العنوانُ عند ‎١٢٫٣‎ و`ink2` عند ‎٧٫٣٧‎.
///
/// **ولا حاجةَ به إلى `AppBar`:** خانةُ `Scaffold.appBar` تحجز ارتفاعَها
/// وتدفع المحتوى تحتها، فلا يمرّ شيءٌ خلف الزجاج ولا يجد التمويهُ ما يموّهه.
class GlassHeader extends StatelessWidget {
  const GlassHeader({
    super.key,
    required this.title,
    this.start,
    this.end,
    this.scrolled = false,
  });

  final String title;

  /// ما يقع في **أوّل** الشريط — وهو في العربية أقصى اليمين.
  final Widget? start;

  /// وما يقع في آخره — أقصى اليسار.
  final Widget? end;

  /// هل مرّ المحتوى تحته؟ فيظهر السطحُ والشعرة.
  final bool scrolled;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ClipRect(
      child: BackdropFilter(
        // التمويه هو ما يجعله زجاجاً لا لوناً شفّافاً: بدونه يُرى ما تحته
        // كما هو، فيبدو الشريط ورقةً باهتة لا سطحاً.
        //
        // **ويُطفأ إطفاءً حين لا سطحَ له.** كتبتُه أوّلاً يعمل في الحالتين
        // بحجّة أنّ تبديلَ المرشِّح يعيد بناءَ طبقةٍ ثقيلة. ثمّ رأيتُ في
        // الرسم شريطاً **أفتحَ من الصفحة** وهو بلا سطحٍ أصلاً: `BackdropFilter`
        // يأخذ ما خلفه من داخل قصّه وحده، وعند حافّة القصّ يخلط اللونَ
        // بالشفافيّة فيبيضّ الطرف. والقديمُ كان يخفيه تحت سطحٍ أبيضَ دائم.
        //
        // فـ`sigma` صفرٌ في السكون: لا مزجَ ولا حافّةَ تبيضّ. والتبديلُ يقع
        // مرّتين في التمريرة لا في كلّ إطار.
        filter: ImageFilter.blur(sigmaX: scrolled ? 20 : 0, sigmaY: scrolled ? 20 : 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(top: top),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: scrolled ? 0.82 : 0),
            // **والشعرةُ موجودةٌ في الحالتين، شفّافةً في إحداهما.** حدٌّ يظهر
            // ويختفي يزيد ارتفاعَ الشريط بكسلاً ويُنقصه، فيقفز المحتوى تحته
            // مع كل تمريرة.
            border: Border(
              bottom: BorderSide(
                color: scrolled ? AppColors.hairline : Colors.transparent,
              ),
            ),
          ),
          child: SizedBox(
            height: glassHeaderBar,
            // **طبقاتٌ لا صفّ.** العنوانُ مطلوبٌ في وسط الشريط، والصفُّ يضعه
            // في وسط ما بقي من عرضٍ بعد الأيقونات — فيميل كلّما اختلف عددُها
            // بين الجانبين. وهنا يُعلَّق العنوانُ في وسط الشريط نفسِه،
            // والأيقونتان فوقه على الطرفين.
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  // ‎٥٦‎ على الجانبين: عرضُ الأيقونة ‎٤٨‎ ثمّ فُرجة. فالعنوانُ
                  // الطويل يُقصّ قبل أن يزحف تحت رمزٍ فيصير غيرَ مقروء.
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      fontFamilyFallback: arabicFallback,
                    ),
                  ),
                ),
                if (start != null) PositionedDirectional(start: Space.xs, child: start!),
                if (end != null) PositionedDirectional(end: Space.xs, child: end!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// الشاشةُ ورأسُها معاً — والرأسُ يصغي لتمريرها.
///
/// **ولمَ لا يُترك لكلّ قشرةٍ أن تبنيَ الكومةَ بيدها:** لأنّ الإصغاءَ للتمرير
/// شرطٌ في الرأس الآن، ولو كُتب في قشرتين لَافترقا عند أوّل تعديل — وقد وقع
/// هذا في هذا الملفّ نفسِه أكثرَ من مرّة.
class GlassHeaderHost extends StatefulWidget {
  const GlassHeaderHost({
    super.key,
    required this.title,
    required this.tab,
    required this.child,
    this.start,
    this.end,
  });

  final String title;
  final Widget? start;
  final Widget? end;

  /// التبويبُ المفتوح — يُعاد الرأسُ إلى حاله كلّما تبدّل.
  final int tab;

  final Widget child;

  @override
  State<GlassHeaderHost> createState() => _GlassHeaderHostState();
}

class _GlassHeaderHostState extends State<GlassHeaderHost> {
  bool _under = false;

  bool _onScroll(ScrollNotification n) {
    // **الرأسيُّ وحده.** في الرئيسية صفُّ أقسامٍ أفقيٌّ وبطاقاتٌ تُمرَّر
    // بالإبهام، وكلاهما يبثّ إشعاراتِ تمرير — فلولا هذا الشرطُ لَظهر
    // الزجاجُ لمن مرّر بطاقةً وهو في أعلى الشاشة.
    if (n.metrics.axis != Axis.vertical) return false;
    final under = n.metrics.pixels > 2;
    if (under != _under) setState(() => _under = under);
    return false;
  }

  @override
  void didUpdateWidget(GlassHeaderHost old) {
    super.didUpdateWidget(old);
    // **وتبديلُ التبويب يعيده إلى حاله.** الشاشةُ الجديدة تُبنى عند الصفر
    // ولا تبثّ إشعارَ تمريرٍ أصلاً — فلولا هذا لَبقي الزجاجُ والشعرةُ فوق
    // شاشةٍ لم تُمرَّر، ولا شيءَ يزيلهما حتى يمرّرها صاحبُها ويعود.
    if (old.tab != widget.tab) _under = false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
    onNotification: _onScroll,
    child: Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GlassHeader(
            title: widget.title,
            start: widget.start,
            end: widget.end,
            scrolled: _under,
          ),
        ),
      ],
    ),
  );
}

/// يشقّ اسمَ القسم عند أوّل واوٍ مبتدئةٍ كلمةً: أصلٌ وتتمّة.
///
/// **ولمَ يُشقّ أصلاً.** أسماءُ الأقسام متفاوتةُ الطول — «السيارات» و«الموية
/// والطليع والخدمات المساندة» — وكانت تُلفّ في ثلاثة أسطرٍ متساوية الحجم،
/// فيبتلع الطويلُ بطاقتَه ولا يُقرأ منه المهمّ إلّا بالتأمّل. والمهمّ هو ما
/// قبل الواو: «القاعات»، «التصوير»، «الطبخ». فيُكتب غامقاً في سطرٍ واحد،
/// وتُكتب التتمّةُ تحته أهدأَ وأصغر.
///
/// **ولا يُشقّ ما لا ينفع شقُّه.** أصلٌ من حرفٍ واحدٍ لا يقول شيئاً، وكذلك
/// تتمّةٌ من حرفين — فيُترك الاسمُ في الحالتين كما هو.
///
/// (وكان الحدُّ الأوّلُ `at <= 0` يُراد به «واوٌ في أوّل الاسم». وهو شرطٌ
/// **ميّت**: الاسمُ يُقلَّم قبله، فلا يبدأ بفراغٍ، فلا يقع الفراغُ المطلوبُ
/// في الموضع صفر أبداً. كشفه ضابطٌ سالبٌ لم يسقط.)
({String head, String tail}) splitCategoryLabel(String label) {
  final clean = label.trim();
  // أداةُ تقسيمٍ لا نصُّ واجهة: تُشقُّ بها أسماءُ الأقسام الآتيةُ من
  // القاعدة، وهي عربيّةٌ أبداً مهما كانت لغةُ الشاشة. i18n-ignore
  final at = clean.indexOf(' و');
  if (at < 2) return (head: clean, tail: '');
  final tail = clean.substring(at + 1).trim();
  if (tail.length < 3) return (head: clean, tail: '');
  return (head: clean.substring(0, at).trim(), tail: tail);
}

/// اسمُ القسم: أصلُه غامقاً وتتمّتُه تحته.
class _CategoryLabel extends StatelessWidget {
  const _CategoryLabel({required this.label, required this.active, required this.tone});

  final String label;
  final bool active;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final parts = splitCategoryLabel(label);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // **سطرٌ واحدٌ للأصل ما دامت له تتمّة.** ولو لُفّ في سطرين لَنزلت
        // التتمّةُ في بطاقةٍ دون جارتها فتعرّج الصفُّ.
        //
        // **وسطران إن لم تكن له تتمّة.** «منظمي الحفلات» لا واوَ فيه فيبقى
        // كلَّه في الأصل، وسطرٌ واحدٌ يقصّه إلى «منظمي ال…» — رأيتُه في
        // اللقطة. ولا صفَّ يتعرّج بذلك: ما تحته لا شيء.
        Text(
          parts.head,
          maxLines: parts.tail.isEmpty ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: active ? tone : AppColors.ink,
            fontFamilyFallback: arabicFallback,
          ),
        ),
        if (parts.tail.isNotEmpty)
          Text(
            parts.tail,
            // سطران للتتمّة: «والطليع والخدمات المساندة» لا يكتمل في سطر.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              height: 1.3,
              color: active ? tone.withValues(alpha: 0.85) : AppColors.muted,
              fontFamilyFallback: arabicFallback,
            ),
          ),
      ],
    );
  }
}

/// ما داخل دائرة بطاقة القسم: صورتُه إن كانت، وإلّا أيقونتُه.
class _CategoryGlyph extends StatelessWidget {
  const _CategoryGlyph({required this.imageUrl, required this.icon, required this.tone});

  final String? imageUrl;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final fallback = Icon(icon, size: 17, color: tone);
    if (url == null || url.isEmpty) return fallback;

    // والصورةُ بمقاس القرص — ٣٤ لا ٣٦ بعد تصغيره. وحافّةُ القرص تُزيحها
    // فتُرسم اثنين وثلاثين وتُحيط بها الحلقةُ المصبوغة، وهو المقصود.
    return ClipOval(
      child: Image.network(
        url,
        width: 34,
        height: 34,
        fit: BoxFit.cover,
        // **والعودةُ إلى الأيقونة عند الفشل لا مربّعٌ مكسور.** الشاشةُ الأولى
        // تُفتح على شبكةٍ يمنيّةٍ قد تنقطع، ومن رآها اثنتي عشرة أيقونةَ خطأٍ
        // حكم على التطبيق كلِّه.
        errorBuilder: (_, _, _) => fallback,
        // وأثناء التحميل تبقى الأيقونةُ مكانها، فلا تومض الدائرةُ فارغةً.
        loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
      ),
    );
  }
}

/// الشارةُ الذهبيّة — واحدةٌ لموضعَيها: جانبَ الاسم أو تحته.
///
/// ولو نُسخت لافترق لونُها أو مقاسُها عند أوّل تعديل.
class _GoldBadge extends StatelessWidget {
  const _GoldBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.goldOnAccent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.accentDeep,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    );
  }
}
