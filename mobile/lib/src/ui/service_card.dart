import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/format.dart';
import '../core/geo.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import 'kit.dart';
import 'media.dart';
import 'motion.dart';

/// بطاقةُ خدمةٍ في قائمة.
///
/// واحدةٌ لا اثنتان: كانت في شاشة الاستكشاف وحدها، فلمّا صار لملفّ المزوّد
/// قائمةُ خدماتٍ أيضاً كان الطريق الأسهل نسخَها. والمنسوخُ يفترق: يُصلَح عيبٌ
/// في إحداهما ويبقى في الأخرى، ويُضاف شيءٌ هنا فيغيب هناك.
///
/// وما يختلف بين الموضعين مُعامِلاتٌ لا شيفرة: القلب يظهر حيث تُفتح المفضّلة،
/// واسمُ المزوّد يُذكر حيث لا يكون هو صاحب الصفحة.
/// وسمُ الغلاف الطائر — واحدٌ يُشتقّ من المعرّف، فلا يفترق الطرفان.
String serviceHeroTag(String serviceId) => 'service-cover-$serviceId';

class ServiceListCard extends StatelessWidget {
  const ServiceListCard({
    super.key,
    required this.item,
    required this.onOpen,
    this.isFavourite,
    this.onToggleFavourite,
    this.onOpenProvider,
    this.showProvider = true,
    this.from,
    this.flyCover = false,
  });

  final ServiceItem item;
  final VoidCallback onOpen;

  /// القلب. يُترك فارغاً فيغيب — وهو حال ملفّ المزوّد.
  final bool? isFavourite;
  final VoidCallback? onToggleFavourite;

  /// فتحُ ملفّ المزوّد من اسمه. يُترك فارغاً داخل ملفّه هو.
  final VoidCallback? onOpenProvider;

  final bool showProvider;

  /// نقطةُ العميل — إن أُعطيت كُتبت المسافةُ على البطاقة.
  ///
  /// **ورقمٌ لا ترتيبٌ صامت:** من رفع «الأقرب إليّ» يرى القائمةَ تتبدّل ولا
  /// يعرف لماذا. و«على بُعد ٤ كم» تقول له سببَ الترتيب وتُغنيه عن الثقة به.
  final GeoPoint? from;

  /// أيطير الغلافُ إلى صفحة الخدمة؟
  ///
  /// **واختياريٌّ لا مفروض.** وسمُ `Hero` يجب أن يكون **فريداً في الشاشة**،
  /// وشاشةٌ تعرض الخدمةَ نفسَها في موضعين — مميَّزةً وفي قائمة — ترمي
  /// استثناءً وقت الانتقال. فمن عرف أنّ قائمتَه لا تكرّر يرفعه.
  final bool flyCover;

  /// ارتفاعُ الغلاف — واحدٌ لكلّ بطاقةٍ، بغلافٍ وبلا غلاف.
  ///
  /// **ومقياسٌ لا رقمٌ مكرَّر:** يُقاس في الاختبار ليُعرف أنّ القائمةَ لا
  /// تتعرّج، ويُقرأ من هنا فلا يفترق المقيسُ عن المرسوم.
  static const coverHeight = 168.0;

  Widget _cover() {
    final ground = SizedBox(
      // **ومفتاحٌ على الغلاف**: يُقاس عرضُه وارتفاعُه ولونُ زاويته، ولا
      // مرساةَ له في الشجرة غيرُ هذا — `SizedBox` في بطاقةٍ فيها عشرة.
      key: ValueKey('cover-${item.id}'),
      height: coverHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // **والتدرّجُ تحت الصورة دائماً لا بديلاً عنها**: يُرى ريثما تصل
          // الصورةُ على شبكة جوالٍ يمنية، ويبقى وحدَه لمن لا غلافَ له —
          // فلا يخرج مربّعٌ رماديٌّ يُقرأ صورةً مكسورة.
          _LetterGround(title: item.title),
          if (item.coverPath != null)
            MediaThumb(url: Api.mediaUrl(item.coverPath), blank: true),
        ],
      ),
    );
    if (!flyCover) return ground;
    return Hero(tag: serviceHeroTag(item.id), child: ground);
  }

  @override
  Widget build(BuildContext context) {
    final favourite = isFavourite;
    return Pressable(
      onTap: onOpen,
      child: Card(
        // الغلافُ يبلغ حافّةَ البطاقة، فالقصُّ على نصف قطرها لا على مستطيل.
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                _cover(),
                // القلبُ على الغلاف في قرصٍ أبيض: يُقرأ على أيّ صورةٍ تحته،
                // وله مساحتُه الخاصّة فلا تفتح الضغطةُ عليه صفحةَ التفاصيل.
                if (favourite != null && onToggleFavourite != null)
                  PositionedDirectional(
                    top: Space.sm,
                    end: Space.sm,
                    child: _HeartDisc(
                      on: favourite,
                      onTap: onToggleFavourite!,
                    ),
                  ),
                if (item.providerIsFeatured && showProvider)
                  const PositionedDirectional(
                    top: Space.sm,
                    start: Space.sm,
                    child: _FeaturedPill(),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (showProvider)
                    _ProviderLine(
                      item: item,
                      onOpenProvider: onOpenProvider,
                      from: from,
                    )
                  else
                    _Place(item: item, from: from),
                  // شارتان تقولان إن وراء البطاقة ما يُرى ويُسمع: بلا هذه
                  // العلامة لا يعرف أحدٌ أن للخدمة مقطعاً حتى يفتحها — ومن لم
                  // يفتحها لم يعرف.
                  if (item.hasVideo || item.hasAudio) ...[
                    const SizedBox(height: Space.sm),
                    Row(
                      children: [
                        if (item.hasVideo) MediaChip(Icons.play_circle_outline, tr('فيديو')),
                        if (item.hasVideo && item.hasAudio) const SizedBox(width: Space.xs),
                        if (item.hasAudio) MediaChip(Icons.graphic_eq, tr('مقطع صوتي')),
                      ],
                    ),
                  ],
                  const SizedBox(height: Space.md),
                  // النطاق السعري يطول: «850,000 ر.ي – 1,200,000 ر.ي» وحده
                  // يتجاوز عرض الشاشة الضيّقة، فبلا Expanded يفيض الصفّ
                  // ويختفي التقييم خلف الحافة.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          item.priceTo == null
                              ? formatMoney(item.price)
                              : '${formatMoney(item.price)} – ${formatMoney(item.priceTo!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      if (item.providerRating > 0 && showProvider)
                        Rating(item.providerRating, count: item.providerReviewsCount, size: 13)
                      else if (showProvider)
                        Muted(tr('جديد')),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Muted(trf('العربون {0}٪', ['${item.depositPercent}']), size: 12),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(Space.md),
              child: FilledButton(
                // **ومفتاحٌ لكلّ بطاقة**: بابُ الخدمة يُقاس من زرّه هو، لا من
                // أيّ زرٍّ في الشاشة.
                key: ValueKey('open-${item.id}'),
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentInk,
                  minimumSize: const Size.fromHeight(46),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // **والحجمُ والوزنُ على `Text` لا في `styleFrom`:** نمطٌ
                    // عارٍ هناك يستبدل `fontFamily` الثيمةِ كلَّه، فتخرج
                    // الحروفُ العربيّةُ مربّعاتٍ بيضاء.
                    Text(
                      tr('عرض التفاصيل'),
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    // **و`arrow_forward_ios` لا `chevron_left`:** هذا يتقلّب
                    // مع اتجاه الشاشة من نفسِه، وذاك ممنوعٌ في الشجرة.
                    const Icon(Icons.arrow_forward_ios, size: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// أرضيّةُ الغلاف: تدرّجُ العلامة وحرفُ أوّلِ الاسم.
///
/// **وحرفٌ لا مربّعٌ رماديّ:** الخدمةُ بلا غلافٍ حالٌ حقيقيّةٌ — مزوّدٌ سجّل
/// خدمتَه ولم يرفع صورةً بعد — ومربّعُ «صورةٌ لم تُحمَّل» يقول إنّ في
/// التطبيق عطباً، وهذا يقول إنّ الصورةَ لم تُرفع.
class _LetterGround extends StatelessWidget {
  const _LetterGround({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [AppColors.accentLift, AppColors.accentDeep],
      ),
    ),
    child: Center(
      child: Text(
        title.trim().isEmpty ? tr('؟') : title.trim().characters.first,
        style: TextStyle(
          fontSize: 54,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    ),
  );
}

/// قرصُ القلب فوق الغلاف.
class _HeartDisc extends StatelessWidget {
  const _HeartDisc({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.92),
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Tooltip(
        message: on ? tr('أزل من المفضّلة') : tr('أضف للمفضّلة'),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(
            on ? Icons.favorite : Icons.favorite_border,
            size: 20,
            // نبيذيُّ العلامة لا أحمرُ الخطأ: قلبٌ بلون «فشل» على خدمةٍ
            // أحبَّها المستخدم يقرأه بعضُهم تحذيراً.
            color: on ? AppColors.accent : AppColors.muted,
          ),
        ),
      ),
    ),
  );
}

/// شارةُ «مميّز» على الغلاف — قرصٌ أبيضُ لا إطارٌ ملوّن.
///
/// **والإطارُ الملوّنُ لا يُقرأ على صورة:** حدٌّ كهرمانيٌّ بحرفٍ كهرمانيٍّ
/// فوق قاعةٍ مضاءةٍ بالذهب يذوب فيها. والأبيضُ المصمت يحمل لونَه معه.
class _FeaturedPill extends StatelessWidget {
  const _FeaturedPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
        const SizedBox(width: 3),
        Text(
          tr('مميّز'),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.warning,
          ),
        ),
      ],
    ),
  );
}

/// المكانُ وحدَه — في صفحة المزوّد حيث لا يُكرَّر اسمُه.
class _Place extends StatelessWidget {
  const _Place({required this.item, this.from});
  final ServiceItem item;
  final GeoPoint? from;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.place_outlined, size: 14, color: AppColors.muted),
      const SizedBox(width: 3),
      Flexible(
        child: Muted(
          '${item.providerGovernorate}'
          '${distanceSuffix(from, item.providerPoint)}',
        ),
      ),
    ],
  );
}

/// سطرُ المزوّد تحت العنوان، واسمُه فيه بابٌ إلى ملفّه.
///
/// والاسمُ وحده هو الذي يُضغط لا السطر كلّه: القسمُ والمحافظة يقعان على
/// ضغطة البطاقة فتُفتح الخدمة، وهو الأغلب. وللاسم لونُ العلامة وأيقونةٌ
/// صغيرة، فيُعرف أنه يُضغط قبل أن يُضغط.
class _ProviderLine extends StatelessWidget {
  const _ProviderLine({required this.item, this.onOpenProvider, this.from});
  final ServiceItem item;
  final VoidCallback? onOpenProvider;
  final GeoPoint? from;

  @override
  Widget build(BuildContext context) {
    final name = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.storefront_outlined, size: 15, color: AppColors.accent),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            item.providerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ),
        // العلامة ملاصقةٌ للاسم في القائمة كما هي في الملفّ: صفةٌ له
        // لا خبرٌ مستقلّ. وحجمُها من حجم السطر لا ثابتٌ يزاحمه.
        if (item.providerVerified) ...[
          const SizedBox(width: 4),
          const VerifiedMark(size: 15),
        ],
      ],
    );
    return Row(
      children: [
        Flexible(
          child: onOpenProvider == null
              ? name
              : GestureDetector(
                  onTap: onOpenProvider,
                  // الشفّاف يقع عليه اللمس: بلا هذا لا تُلتقط الضغطة إلا على
                  // الحروف نفسها، فتذهب إلى البطاقة من بين الحروف.
                  behavior: HitTestBehavior.opaque,
                  child: name,
                ),
        ),
        const SizedBox(width: Space.sm),
        // خيطٌ رأسيٌّ يفصل الاسمَ عن المكان — كما في تصميم صاحب المنصّة.
        Container(width: 1, height: 13, color: AppColors.hairline),
        const SizedBox(width: Space.sm),
        Flexible(child: _Place(item: item, from: from)),
      ],
    );
  }
}

/// شارةٌ صغيرة: للخدمة فيديو أو صوت.
class MediaChip extends StatelessWidget {
  const MediaChip(this.icon, this.label, {super.key});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: Tint.chip),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.accent),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// «‏ · ٤ كم» أو فراغٌ — تُلحَق بسطر البطاقة.
///
/// **وفراغٌ لمن لا نقطةَ له، لا «غير معروف».** هو مزوّدٌ يعمل ولم يضع دبّوسه،
/// وكتابةُ نقصٍ على بطاقته عقوبةٌ لا خبر.
String distanceSuffix(GeoPoint? from, GeoPoint? to) {
  if (from == null || to == null) return '';
  return ' · ${distanceLabel(distanceKm(from, to))}';
}
