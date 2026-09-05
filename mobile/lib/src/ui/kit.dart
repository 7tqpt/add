import 'dart:async' show Timer;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/supabase.dart' show offlineMessage;
import 'motion.dart';

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
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(dialogContext).pop(true),
        style: FilledButton.styleFrom(backgroundColor: AppColors.critical),
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
                  Positioned(
                    top: -46,
                    left: -30,
                    child: _Blob(size: 150, alpha: 0.10),
                  ),
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
                                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
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
            Icon(Icons.chevron_left, size: 20, color: AppColors.muted),
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
class MenuGap extends StatelessWidget {
  const MenuGap({super.key});
  @override
  Widget build(BuildContext context) =>
      Container(height: Space.sm, color: AppColors.page);
}

/// الرأسُ النبيذيّ في أعلى شاشة الملفّ — «حسابي» وملفّ مقدّم الخدمة.
///
/// **وواحدٌ للشاشتين لا نسختان.** الصورةُ بطوقٍ ذهبيّ، والاسمُ، وسطرٌ ثانويّ،
/// وشارةٌ ذهبيّة. وما يفترق بين الشاشتين محتوىً لا شكل: العميلُ اسمُه وجوالُه
/// ودورُه، والمزوّدُ اسمُ عمله ومحافظتُه وحالُ توثيقه.
///
/// ويمتدّ إلى حافّتَي الشاشة ويبدأ من أعلاها — فيمرّ تحت الشريط الزجاجي بدل
/// أن يقف تحته بحاشيةٍ بيضاء تقطع النبيذيّ نصفين.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.titleTrailing,
    this.titleLtr = false,
    this.subtitleLtr = false,
    this.footer,
  });

  final Widget avatar;
  final String title;
  final String subtitle;

  /// نصُّ الشارة الذهبية — دورُ العميل أو حالُ توثيق المزوّد.
  final String badge;

  /// ما يلي الاسمَ مباشرةً — علامةُ التوثيق مثلاً.
  final Widget? titleTrailing;

  /// الاسمُ نفسه لاتينيّ — يقع البريدُ مكانه قبل أن يصل الملفّ.
  final bool titleLtr;

  /// السطرُ الثانوي لاتينيٌّ (جوالٌ أو بريد) فيُرسم من اليسار.
  final bool subtitleLtr;

  /// سطرٌ تحت الشارة — تحذيرٌ أو سببُ رفض.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        Space.lg, glassHeaderTop(context), Space.lg, Space.xl),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.accentLift, AppColors.accentDeep],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: OnAccent.ink,
                              fontFamilyFallback: arabicFallback,
                            ),
                          ),
                        ),
                        if (titleTrailing != null) ...[
                          const SizedBox(width: 5),
                          titleTrailing!,
                        ],
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        // **والاتجاهُ يتبع ما يُعرض لا الصفحة:** جوالٌ أو
                        // بريدٌ لاتينيٌّ بلا `ltr` تتقدّم نقطتُه وامتدادُه إلى
                        // غير موضعهما فيُقرأ مقلوباً.
                        textDirection: subtitleLtr ? TextDirection.ltr : null,
                        textAlign: subtitleLtr ? TextAlign.left : null,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: OnAccent.inkSoft,
                          fontFamilyFallback: arabicFallback,
                        ),
                      ),
                    ],
                    const SizedBox(height: Space.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.goldOnAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentDeep,
                          fontFamilyFallback: arabicFallback,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.lg),
              // **والطوقُ الذهبيُّ ليس زينةً وحده:** صورةٌ داكنةٌ على نبيذيٍّ
              // داكنٍ تذوب فيه بلا حدٍّ يفصلها.
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.goldOnAccent, width: 2),
                ),
                child: avatar,
              ),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: Space.md),
            footer!,
          ],
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
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
    this.tooltip = 'مزوّد موثَّق',
    this.color = verifiedBlue,
  });

  final double size;
  final String tooltip;

  /// **ويُمرَّر ليُسأل عنه.** لونٌ محبوسٌ في رسّامٍ خاصٍّ لا يُقاس إلّا
  /// بقراءة البكسلات، فيُخرَج إلى حيث يُقرأ.
  final Color color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _VerifiedPainter(color: color),
        child: Center(
          // الأبيضُ على هذا الأزرق ‎٣٫٠٩:١‎ — وهو حدُّ النصّ الكبير والرموز.
          child: Icon(
            Icons.check_rounded,
            size: size * 0.56,
            color: Colors.white,
          ),
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
    final letter = name.trim().isEmpty ? '؟' : name.trim().characters.first;
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
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
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

class _BrandSpinnerState extends State<BrandSpinner>
    with SingleTickerProviderStateMixin {
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
    _c ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
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
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) => _paint(c.value),
    );
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
    this.label = 'جارٍ التحميل…',
    this.delay = const Duration(milliseconds: 220),
    this.color = AppColors.accent,
    this.tint = AppColors.gold,
    this.labelColor,
  });

  final String label;
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
              Muted(widget.label)
            else
              Text(
                widget.label,
                style: TextStyle(fontSize: 12, color: widget.labelColor),
              ),
          ],
        ),
      ),
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
  const ErrorBlock({
    super.key,
    required this.message,
    this.onRetry,
    this.details,
  });
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
              OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
            ],
            if (technical != null && technical.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const ValueKey('error-details'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Muted('تفاصيل تقنية', size: 11),
                  children: [
                    SelectableText(
                      technical,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                          fontSize: 11, height: 1.6, color: AppColors.muted),
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
          const Text(
            'لا يوجد اتصال بالإنترنت',
            key: ValueKey('offline-title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: Space.sm),
          const Text(
            // **ويُقال ما يُفعل لا ما وقع فقط.** «لا يوجد اتصال» خبرٌ،
            // و«شغّل البيانات أو الواي‑فاي» عملٌ يُفعل الآن.
            'شغّل بيانات الجوال أو الواي‑فاي، ثم أعد المحاولة.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.7, color: AppColors.muted),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: Space.lg),
            FilledButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
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
  'halls' => Icons.meeting_room_outlined,
  'catering' => Icons.restaurant_outlined,
  'artists' => Icons.music_note_outlined,
  'sound' => Icons.speaker_outlined,
  'photography' => Icons.photo_camera_outlined,
  'support' => Icons.water_drop_outlined,
  'cars' => Icons.directions_car_outlined,
  'attire' => Icons.checkroom_outlined,
  'planners' => Icons.event_note_outlined,
  'beauty' => Icons.brush_outlined,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.sm,
                  vertical: Space.md,
                ),
                decoration: BoxDecoration(
                  // زجاجٌ مصبوغ: تدرّجٌ من أبيضَ شبه صافٍ إلى صبغةٍ خفيفة،
                  // فيبدو السطح ذا عمقٍ لا لوحةً مسطّحة.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.96),
                      tone.withValues(alpha: active ? 0.16 : 0.07),
                    ],
                  ),
                  border: Border.all(
                    color: tone.withValues(alpha: active ? 0.55 : 0.18),
                    width: active ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    // ظلٌّ يُغلق عند الضغط فتبدو البطاقة وقد غاصت في مكانها.
                    BoxShadow(
                      color: tone.withValues(alpha: _down ? 0.10 : 0.18),
                      blurRadius: _down ? 4 : 12,
                      offset: Offset(0, _down ? 1 : 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            tone.withValues(alpha: active ? 0.26 : 0.15),
                            tone.withValues(alpha: active ? 0.14 : 0.07),
                          ],
                        ),
                      ),
                      child: _CategoryGlyph(
                        imageUrl: widget.imageUrl,
                        icon: widget.icon,
                        tone: tone,
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    // ثلاثة أسطرٍ بحدٍّ أقصى ثم قصٌّ. وثلاثةٌ لا سطران: أطولُ
                    // اسمٍ في البذرة — «الموية والطليع والخدمات المساندة» —
                    // يُقصّ عند سطرين فيضيع آخره، ويكتمل عند ثلاثة.
                    Text(
                      widget.label,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: active ? tone : AppColors.ink,
                        fontFamilyFallback: arabicFallback,
                      ),
                    ),
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
  const PickChip({super.key, required this.label, required this.active, required this.onTap});
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
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

/// ارتفاع الشريط الزجاجي مع هامشه — تحتاجه القوائم لتُنهي محتواها فوقه.
///
/// ثابتٌ مشترك لا رقمٌ مكرّر: الشريط يطفو والمحتوى يمرّ تحته، فآخرُ بطاقةٍ في
/// أي قائمةٍ تختفي خلفه ما لم تُحسب هذه المسافة. ونسيانُها في شاشةٍ واحدة عيبٌ
/// لا يظهر إلا حين يصل المستخدم إلى آخر القائمة.
const double glassNavSpace = 96;

/// شريط تنقّلٍ سفليٌّ زجاجيّ يطفو فوق المحتوى.
///
/// **والأيقونات ليست بيضاء.** الزجاج أبيض والصفحة `#F4F7FC`، فأبيضُ على
/// أبيضَ يعطي ‎١٫٠٤:١‎ — أي لا شيء. فالمختار بلون العلامة وغيرُه رماديّ، وكلاهما
/// مقيسٌ على الزجاج نفسه لا مقدَّر. والزجاج الأبيض بأيقوناتٍ بيضاء إنما يصلح
/// فوق خلفيةٍ داكنة.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({super.key, required this.index, required this.onSelect, required this.items});

  final int index;
  final ValueChanged<int> onSelect;
  final List<GlassNavItem> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            // التمويه هو ما يجعله زجاجاً لا لوناً شفّافاً: بدونه يُرى ما تحته
            // كما هو، فيبدو الشريط ورقةً باهتة لا سطحاً.
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _GlassNavCell(
                        item: items[i],
                        active: i == index,
                        onTap: () => onSelect(i),
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

class GlassNavItem {
  const GlassNavItem({required this.label, required this.icon, required this.activeIcon});
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _GlassNavCell extends StatelessWidget {
  const _GlassNavCell({required this.item, required this.active, required this.onTap});
  final GlassNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = active ? AppColors.accent : AppColors.ink2;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // حبّةٌ مصبوغة تحت الأيقونة المختارة: علامةٌ ثانية غير اللون، فمن لا
          // يفرّق الألوان يعرف أين هو. والأيقونة مصمتةٌ للمختار ومفرَّغة لغيره
          // — علامةٌ ثالثة.
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: active ? AppColors.accent.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(active ? item.activeIcon : item.icon, size: 21, color: tone),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.2,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: tone,
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
        // قرصٌ شفّافٌ تحت الأيقونة: هذا موضع الزجاجيّة — لا في لون الرمز.
        // فاللون مقيسٌ (‏`ink2`‏ يعطي ‎٧٫٥٨:١‎ على الزجاج و‎٤٫٥٥‎ حين تمرّ
        // البطاقة الزرقاء تحته)، والشكلُ حرّ.
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.55),
          shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
          foregroundColor: AppColors.ink2,
        ),
        icon: Icon(icon, size: 20),
      ),
      if (count > 0)
        // على ركن الرمز لا على حافّة الزرّ: صندوق `IconButton` ‎٤٨‎ بكسلاً
        // والرمز ‎٢٢‎ في وسطه، فحبّةٌ عند الحافّة تطفو على بُعد أحد عشر بكسلاً
        // منه — تُقرأ عائمةً لا تابعةً له، وتزدحم بجارتها حين يكون في الشريط
        // زرّان. وقد رُئي ذلك في الرسم لا في الشيفرة.
        Positioned(
          top: 5,
          left: 5,
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
    tooltip: 'المحادثات',
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
    tooltip: 'الإشعارات',
    count: unread,
    onTap: onTap,
  );
}

/// ارتفاع الشريط العلوي الزجاجي مع هامشه — تحتاجه القوائم لتبدأ تحته.
///
/// نظيرُ `glassNavSpace` في الأعلى: الشريط يطفو والمحتوى يمرّ **تحته**، وهذا
/// هو ما يعطي التمويهَ ما يموّهه. فبلا هذه المسافة تبدأ أولُ بطاقةٍ خلف
/// الزجاج ولا تُقرأ.
const double glassHeaderBar = 56;
const double glassHeaderSpace = glassHeaderBar + Space.sm + Space.md;

/// المسافة الكاملة من أعلى الشاشة: شريط الحالة ثم الزجاج.
double glassHeaderTop(BuildContext context) =>
    MediaQuery.paddingOf(context).top + glassHeaderSpace;

/// شريطٌ علويٌّ زجاجيٌّ يطفو فوق المحتوى.
///
/// **والأيقونات ليست بيضاء** — كما في الشريط السفلي، وللسبب نفسه مقيساً:
/// الزجاج أبيض بشفافية ‎٠٫٧٢‎ والصفحة `#F4F7FC`، فما يظهر خلفه ‎#FCFDFE‎.
/// والأبيض عليه يعطي **‎١٫٠٢:١‎** — أي لا شيء. وحتى حين تمرّ بطاقةُ الخطة
/// الزرقاء تحته فيصير ‎#BDC6E3‎، يبقى الأبيض عند ‎١٫٧٠:١‎.
///
/// وأزرقُ العلامة نفسه لا يصلح للأيقونات هنا: ‎٦٫٥٧:١‎ فوق الصفحة، لكنه يهبط
/// إلى **‎٣٫٩٥:١‎** حين تمرّ البطاقة الزرقاء تحته — وهو ما يقع في الشاشة
/// الأولى كلَّما مُرِّرت. فالحبر ‎#0B1220‎ للعنوان و`ink2` للأيقونات: ‎١٨٫٣٦‎
/// و‎٧٫٥٨‎ فوق الصفحة، و‎١١٫٠٣‎ و‎٤٫٥٥‎ فوق البطاقة.
///
/// والزجاجيّةُ تبقى حيث تُرى: التمويه، والحدُّ الأبيض الرقيق، والزوايا، وقرصٌ
/// شفّافٌ تحت كل أيقونة.
class GlassHeader extends StatelessWidget {
  const GlassHeader({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            // التمويه هو ما يجعله زجاجاً لا لوناً شفّافاً: بدونه يُرى ما تحته
            // كما هو، فيبدو الشريط ورقةً باهتة لا سطحاً.
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: glassHeaderBar,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        fontFamilyFallback: arabicFallback,
                      ),
                    ),
                  ),
                  ...actions,
                  // ‎١٢‎ لا ‎٤‎: الشريط مقصوصٌ بزاويةٍ نصفُ قطرها ‎٢٤‎، وأقصى
                  // أيقونةٍ تقع في منحنى الزاوية — فحبّةُ عددها تُقصّ. رُئي
                  // في الرسم مكبَّراً لا في الشيفرة.
                  const SizedBox(width: Space.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ما داخل دائرة بطاقة القسم: صورتُه إن كانت، وإلّا أيقونتُه.
class _CategoryGlyph extends StatelessWidget {
  const _CategoryGlyph({
    required this.imageUrl,
    required this.icon,
    required this.tone,
  });

  final String? imageUrl;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final fallback = Icon(icon, size: 19, color: tone);
    if (url == null || url.isEmpty) return fallback;

    return ClipOval(
      child: Image.network(
        url,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        // **والعودةُ إلى الأيقونة عند الفشل لا مربّعٌ مكسور.** الشاشةُ الأولى
        // تُفتح على شبكةٍ يمنيّةٍ قد تنقطع، ومن رآها اثنتي عشرة أيقونةَ خطأٍ
        // حكم على التطبيق كلِّه.
        errorBuilder: (_, _, _) => fallback,
        // وأثناء التحميل تبقى الأيقونةُ مكانها، فلا تومض الدائرةُ فارغةً.
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}
