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

  /// ضلعُ الغلاف المربّع.
  ///
  /// **ومربّعٌ إلى جانب الاسم لا لوحٌ بعرض البطاقة.** كان اللوحُ ‎١٦٨‎ بكسلاً
  /// فصارت البطاقةُ ‎٣٩٧‎، ولا يظهر في الشاشة إلّا اثنتان ونصف — فقال صاحبُ
  /// المنصّة إنّها كبرت واختار المربّع. والبطاقةُ الآن ‎١٢٠‎ بكسلاً.
  ///
  /// **ومقياسٌ لا رقمٌ مكرَّر:** يُقاس في الاختبار، ويُقرأ من هنا فلا يفترق
  /// المقيسُ عن المرسوم.
  static const coverSide = 96.0;

  /// أضيقُ عمودٍ تُكتب فيه «التفاصيل» مع السهم — وما دونه السهمُ وحدَه.
  ///
  /// ‎١٩٦‎ عمودُ جوالٍ بعرض ‎٣٦٠‎ وفيه يسع الثلاثة، و‎١٥٦‎ عمودُ ‎٣٢٠‎ وفيه
  /// فاضت. والحدُّ بينهما.
  static const _detailsWordMinWidth = 180.0;

  Widget _cover() {
    final ground = SizedBox(
      // **ومفتاحٌ على الغلاف**: يُقاس ضلعُه ولونُ زاويته، ولا مرساةَ له في
      // الشجرة غيرُ هذا — `SizedBox` في بطاقةٍ فيها عشرة.
      key: ValueKey('cover-${item.id}'),
      height: coverSide,
      width: coverSide,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cover(),
              const SizedBox(width: Space.md),
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (item.providerIsFeatured && showProvider) ...[
                          const SizedBox(width: 6),
                          const _FeaturedPill(),
                        ],
                        // القلبُ له سطحُه الخاصّ فلا تفتح الضغطةُ عليه
                        // صفحةَ التفاصيل.
                        if (favourite != null && onToggleFavourite != null) ...[
                          const SizedBox(width: 2),
                          _Heart(on: favourite, onTap: onToggleFavourite!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (showProvider)
                      _ProviderLine(
                        item: item,
                        onOpenProvider: onOpenProvider,
                        from: from,
                      )
                    else
                      _Place(item: item, from: from),
                    // شارتان تقولان إن وراء البطاقة ما يُرى ويُسمع: بلا هذه
                    // العلامة لا يعرف أحدٌ أن للخدمة مقطعاً حتى يفتحها — ومن
                    // لم يفتحها لم يعرف.
                    if (item.hasVideo || item.hasAudio) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (item.hasVideo)
                            MediaChip(Icons.play_circle_outline, tr('فيديو')),
                          if (item.hasVideo && item.hasAudio)
                            const SizedBox(width: Space.xs),
                          if (item.hasAudio) MediaChip(Icons.graphic_eq, tr('مقطع صوتي')),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    // **والسعرُ وحدَه في سطره.** عمودُ النصّ إلى جانب مربّعٍ
                    // ‎٩٦‎ يضيق عن «850,000 ر.ي – 1,400,000 ر.ي» ومعه
                    // التقييم، فينقصّ الطرفُ الأعلى من النطاق — وهو أهمُّ
                    // رقمٍ في البطاقة. وقد خرج مقصوصاً في أوّل رسمة.
                    // **وسطران لا قصّ**: على جوالٍ بعرض ‎٣٢٠‎ لا يسع العمودُ
                    // النطاقَ بخطّ التطبيق — قيس في راسم اللقطة فخرج
                    // «850,000 – 1,400…». فينزل طرفُه الأعلى سطراً بدل أن
                    // يُقصّ، وعلى ما هو أعرضُ يبقى سطراً واحداً.
                    Text(
                      formatMoneyRange(item.price, item.priceTo),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // **وثلاثةٌ في صفٍّ ضيّق تفيض بلا مرونة**: عمودُ النصّ
                    // على جوالٍ بعرض ‎٣٦٠‎ يضيق عن العربون والتقييم
                    // و«التفاصيل ›» مجتمعةً — فاض بأربعةٍ وأربعين بكسلاً
                    // وكشفه اختبارُ «الأقرب إليّ». فصار الأوّلان يتقلّصان.
                    //
                    // **وعلى جوالٍ بعرض ‎٣٢٠‎ لا يكفي التقلّص**: العمودُ
                    // ‎١٥٦‎ بكسلاً، ففاض بسبعةَ عشرَ وكشفه اختبارُ مرشِّح
                    // المحافظات. فتسقط كلمةُ «التفاصيل» ويبقى السهمُ وحدَه
                    // — والسهمُ هو ما يقول إنّ البطاقةَ تُضغط، والكلمةُ
                    // شرحٌ له.
                    LayoutBuilder(builder: (context, box) {
                      final roomy = box.maxWidth >= _detailsWordMinWidth;
                      return Row(
                        children: [
                          // **والعربونُ والتقييمُ في صفٍّ داخل `Expanded` لا
                          // إلى جانب `Spacer`**: `Flexible` و`Spacer` في صفٍّ
                          // واحدٍ يقتسمان الفراغَ نصفين، فخرج «العربون …3»
                          // مقصوصاً وبجانبه فراغٌ لا يملؤه شيء — وظهر في
                          // اللقطة. وهنا يأخذ الاثنان كلَّ ما لم يأخذه
                          // «التفاصيل ›»، ولا يتقلّص العربونُ إلّا حين يضيق.
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Muted(
                                    trf('العربون {0}٪', ['${item.depositPercent}']),
                                    size: 11,
                                    maxLines: 1,
                                  ),
                                ),
                                if (showProvider) ...[
                                  const SizedBox(width: Space.sm),
                                  // **والتقييمُ لا يُلفّ في `Flexible`**: هو
                                  // صفٌّ بحجم أصغرِه فيه نصٌّ بلا حدِّ أسطر،
                                  // فتقليصُه يفيضه من داخله. والمتقلّصُ هو
                                  // العربونُ وحدَه.
                                  if (item.providerRating > 0)
                                    Rating(item.providerRating,
                                        count: item.providerReviewsCount, size: 11.5)
                                  else
                                    Muted(tr('جديد'), size: 11, maxLines: 1),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: Space.xs),
                          // **وبابٌ مرئيٌّ بلا زرّ.** البطاقةُ كلُّها تُضغط،
                          // وهذا يقول ذلك للعين — واختاره صاحبُ المنصّة على
                          // الزرّ الملوّن حين قصّرنا البطاقة.
                          if (roomy) ...[
                            Text(
                              tr('التفاصيل'),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 3),
                          ],
                          // **و`arrow_forward_ios` لا `chevron_left`:** هذا
                          // يتقلّب مع اتجاه الشاشة من نفسِه، وذاك ممنوعٌ في
                          // الشجرة.
                          const Icon(Icons.arrow_forward_ios,
                              size: 11, color: AppColors.accent),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
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
          // من ضلع المربّع لا رقماً ثابتاً: حرفٌ بحجم اللوح الكبير في مربّعٍ
          // صغير يخرج مقصوصاً.
          fontSize: ServiceListCard.coverSide * 0.4,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    ),
  );
}

/// القلب إلى جانب الاسم — وله سطحُه الخاصّ.
///
/// **وسطحٌ لا أيقونةٌ مرسومة:** البطاقةُ كلُّها تُضغط، فقلبٌ بلا `InkWell`
/// تنزل ضغطتُه إلى البطاقة وتُفتح الخدمة بدل أن تُحفظ.
class _Heart extends StatelessWidget {
  const _Heart({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Tooltip(
        message: on ? tr('أزل من المفضّلة') : tr('أضف للمفضّلة'),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            on ? Icons.favorite : Icons.favorite_border,
            size: 19,
            // نبيذيُّ العلامة لا أحمرُ الخطأ: قلبٌ بلون «فشل» على خدمةٍ
            // أحبَّها المستخدم يقرأه بعضُهم تحذيراً.
            color: on ? AppColors.accent : AppColors.muted,
          ),
        ),
      ),
    ),
  );
}

/// شارةُ «مميّز» إلى جانب الاسم — صبغةٌ كهرمانيّةٌ على البطاقة البيضاء.
class _FeaturedPill extends StatelessWidget {
  const _FeaturedPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: Tint.chip),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 13, color: AppColors.warning),
        const SizedBox(width: 2),
        Text(
          tr('مميّز'),
          style: const TextStyle(
            fontSize: 10.5,
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
        // **والخيطُ الرأسيُّ الفاصلُ ذهب حين قُصّرت البطاقة**، وكان في تصميم
        // صاحب المنصّة. عمودُ النصّ إلى جانب مربّعٍ ‎٩٦‎ أضيق من عرض
        // البطاقة كلِّها، والخيطُ بفراغَيه يأكل سبعةَ عشرَ بكسلاً — فكان
        // اسمُ المزوّد يخرج «مطبخ الأ…». والاسمُ أولى من خيط.
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
