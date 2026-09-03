import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/geo.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import 'kit.dart';
import 'media.dart';

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

  Widget _cover() {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 76,
        height: 76,
        child: MediaThumb(url: Api.mediaUrl(item.coverPath)),
      ),
    );
    if (!flyCover) return image;
    return Hero(tag: serviceHeroTag(item.id), child: image);
  }

  @override
  Widget build(BuildContext context) {
    final favourite = isFavourite;
    return AppCard(
      onTap: onOpen,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الغلاف إلى جانب العنوان لا فوقه: صفٌّ من عشرين بطاقةٍ بصورةٍ
            // بعرض الشاشة في كلٍّ منها يصير صفحةَ صورٍ تُمرَّر طويلاً، والقصد
            // مقارنةُ خدماتٍ لا تصفّحُ ألبوم.
            if (item.coverPath != null) ...[
              _cover(),
              const SizedBox(width: Space.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (item.providerIsFeatured && showProvider) ...[
                        const SizedBox(width: Space.sm),
                        const StatusBadge('مميّز', color: AppColors.warning),
                      ],
                      // القلب داخل البطاقة على InkWell البطاقة نفسها: يُعطى
                      // مساحته الخاصة كي لا تفتح الضغطةُ عليه صفحةَ التفاصيل.
                      if (favourite != null && onToggleFavourite != null)
                        IconButton(
                          onPressed: onToggleFavourite,
                          visualDensity: VisualDensity.compact,
                          tooltip: favourite ? 'أزل من المفضّلة' : 'أضف للمفضّلة',
                          icon: Icon(
                            favourite ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            // نبيذيُّ العلامة لا أحمرُ الخطأ: قلبٌ بلون «فشل» على خدمةٍ
                            // أحبَّها المستخدم يقرأه بعضُهم تحذيراً.
                            color: favourite ? AppColors.accent : AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  if (showProvider)
                    _ProviderLine(
                      item: item,
                      onOpenProvider: onOpenProvider,
                      from: from,
                    )
                  else
                    Muted(
                      '${item.categoryName} · ${item.providerGovernorate}'
                      '${distanceSuffix(from, item.providerPoint)}',
                    ),
                  // شارتان تقولان إن وراء البطاقة ما يُرى ويُسمع: بلا هذه
                  // العلامة لا يعرف أحدٌ أن للخدمة مقطعاً حتى يفتحها — ومن لم
                  // يفتحها لم يعرف.
                  if (item.hasVideo || item.hasAudio) ...[
                    const SizedBox(height: Space.sm),
                    Row(
                      children: [
                        if (item.hasVideo) const MediaChip(Icons.play_circle_outline, 'فيديو'),
                        if (item.hasVideo && item.hasAudio) const SizedBox(width: Space.xs),
                        if (item.hasAudio) const MediaChip(Icons.graphic_eq, 'مقطع صوتي'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        // النطاق السعري يطول: «850,000 ر.ي – 1,200,000 ر.ي» وحده يتجاوز عرض
        // الشاشة الضيّقة، فبلا Expanded يفيض الصفّ ويختفي التقييم خلف الحافة.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                item.priceTo == null
                    ? formatMoney(item.price)
                    : '${formatMoney(item.price)} – ${formatMoney(item.priceTo!)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: Space.sm),
            if (item.providerRating > 0 && showProvider)
              Rating(item.providerRating, count: item.providerReviewsCount)
            else if (showProvider)
              const Muted('جديد'),
          ],
        ),
        const SizedBox(height: Space.xs),
        Muted('العربون ${item.depositPercent}٪ · ${item.unit}', size: 11),
      ],
    );
  }
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
    final rest = '${item.categoryName} · ${item.providerGovernorate}'
        '${distanceSuffix(from, item.providerPoint)}';
    if (onOpenProvider == null) {
      return Muted('${item.providerName} · $rest');
    }
    return Row(
      children: [
        Flexible(
          child: GestureDetector(
            onTap: onOpenProvider,
            // الشفّاف يقع عليه اللمس: بلا هذا لا تُلتقط الضغطة إلا على الحروف
            // نفسها، فتذهب إلى البطاقة من بين الحروف.
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront_outlined, size: 13, color: AppColors.accent),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    item.providerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                // العلامة ملاصقةٌ للاسم في القائمة كما هي في الملفّ: صفةٌ له
                // لا خبرٌ مستقلّ. وحجمُها من حجم السطر لا ثابتٌ يزاحمه.
                if (item.providerVerified) ...[
                  const SizedBox(width: 3),
                  const VerifiedMark(size: 13),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: Space.xs),
        Flexible(child: Muted('· $rest')),
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
