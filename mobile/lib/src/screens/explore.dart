import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import '../ui/media.dart';
import 'service_detail.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.categoryId});

  /// القسم الذي تُفتح عليه الشاشة.
  ///
  /// يُمرَّر حين يأتي المستخدم من بطاقة قسمٍ في الرئيسية: من ضغط «القاعات»
  /// يريد القاعات، لا قائمةً بكل شيءٍ يبحث فيها عنها من جديد. ويُترك فارغاً
  /// حين يُفتح التبويب من الشريط السفلي — فيُعرض كلُّ شيء.
  final String? categoryId;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _search = TextEditingController();
  String _applied = '';
  late String? _categoryId = widget.categoryId;
  late Future<List<ServiceCategory>> _categories;
  late Future<List<ServiceItem>> _services;
  Set<String> _favourites = {};

  /// صفُّ الأقسام — يُمسك ليُمرَّر إلى القسم المفتوح عليه.
  final _catsScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _categories = Api.categories();
    _reload();
    _loadFavourites();
    _revealCategory();
  }

  @override
  void didUpdateWidget(ExploreScreen old) {
    super.didUpdateWidget(old);
    // القشرة تبني صفحةَ التبويب المفتوح وحدها، فالشاشة تُنشأ من جديد في
    // العادة ويكفي `initState`. وهذا للحال الأخرى — إن بقيت الشاشة حيّةً
    // وتغيّر القسمُ المطلوب من فوقها.
    //
    // والفراغُ طلبٌ كذلك: ضغطُ «استكشف» في الشريط السفلي يمسح المرشِّح، فلو
    // أُهمل الفراغُ هنا لبقيت القائمة مقصوصةً على قسمٍ ضُغط قبل قليل.
    if (widget.categoryId != old.categoryId) {
      _categoryId = widget.categoryId;
      _reload();
      _revealCategory();
    }
  }

  /// إظهارُ القسم المفتوح عليه داخل الصفّ الأفقي.
  ///
  /// الصفُّ فيه اثنتا عشرة بطاقة ولا يظهر منه إلا ثلاثٌ أو أربع. فمن جاء من
  /// الرئيسية على «السيارات» يرى قائمةً مُرشَّحة وفوقها صفٌّ لا علامةَ نشطةَ
  /// فيه — فيظنّ أن ضغطته ضاعت، وهو يرى نتيجتها.
  Future<void> _revealCategory() async {
    final id = _categoryId;
    // ولا مرشِّحَ يعني العودة إلى أوّل الصفّ حيث «الكل»: لو تُرك الصفُّ حيث
    // كان لظلّت البطاقة النشطة خارج الشاشة.
    if (id == null) {
      _scrollCatsTo(0);
      return;
    }
    final List<ServiceCategory> cats;
    try {
      cats = await _categories;
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final i = cats.indexWhere((c) => c.id == id);
    if (i < 0) return;
    // بطاقةٌ عرضها ٩٦ وبينها وبين جارتها ٨، و«الكل» تسبقهنّ جميعاً.
    _scrollCatsTo((i + 1) * (96 + Space.sm));
  }

  void _scrollCatsTo(double offset) {
    // بعد الإطار لا فيه: الصفُّ يُبنى في هذه الدورة، ولا موضعَ له قبل ذلك.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_catsScroll.hasClients) return;
      _catsScroll.animateTo(
        offset.clamp(0.0, _catsScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  void _reload() {
    setState(() {
      _services = Api.services(search: _applied, categoryId: _categoryId);
    });
  }

  Future<void> _loadFavourites() async {
    try {
      final rows = await Api.myFavourites();
      if (mounted) setState(() => _favourites = rows);
    } catch (_) {
      // المفضّلة زينةٌ لا شرط: فشلُ قراءتها لا يمنع تصفّح الخدمات.
    }
  }

  Future<void> _toggleFavourite(String serviceId) async {
    // التبديل يقع في الواجهة أولاً ثم يُرسَل: القلب يستجيب فوراً كما يتوقّع
    // الإصبع، ويعود إن رفض الخادم.
    setState(() {
      if (!_favourites.remove(serviceId)) _favourites.add(serviceId);
    });
    try {
      await Api.toggleFavourite(serviceId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!_favourites.remove(serviceId)) _favourites.add(serviceId);
      });
      showMessage(context, messageOf(e));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _catsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            Space.lg, glassHeaderTop(context), Space.lg, Space.sm),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            // البحث عند الإرسال لا عند كل حرف: كل ضغطة طلبٌ للشبكة، وشبكة
            // الجوال هنا ليست دائماً سخيّة.
            onSubmitted: (v) {
              _applied = v;
              _reload();
            },
            decoration: const InputDecoration(
              hintText: 'ابحث عن قاعة، مصوّر، طبّاخ…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
        ),
        // الأقسام بطاقاتٌ في صفٍّ يُمرَّر، لا شرائح.
        //
        // وصفٌّ أفقيٌّ لا شبكةٌ بملء الشاشة: هذه شاشةُ **تصفّح خدمات** والأقسام
        // مرشِّحٌ فوقها. شبكةٌ من اثنتي عشرة بطاقة تدفع الخدمات تحت الطيّة،
        // فيصير المرشِّح هو الصفحة وما يُرشَّح مخفيّاً.
        SizedBox(
          height: 116,
          child: FutureBuilder<List<ServiceCategory>>(
            future: _categories,
            builder: (context, snap) {
              final cats = snap.data ?? const <ServiceCategory>[];
              return ListView(
                controller: _catsScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                children: [
                  CategoryCard(
                    label: 'الكل',
                    icon: Icons.apps,
                    active: _categoryId == null,
                    onTap: () {
                      _categoryId = null;
                      _reload();
                    },
                  ),
                  for (final c in cats) ...[
                    const SizedBox(width: Space.sm),
                    CategoryCard(
                      label: c.name,
                      icon: categoryIcon(c.slug),
                      tone: categoryTone(c.slug),
                      active: _categoryId == c.id,
                      onTap: () {
                        _categoryId = c.id;
                        _reload();
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ServiceItem>>(
            future: _services,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
              if (snap.hasError) {
                return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
              }
              final items = snap.data ?? const <ServiceItem>[];
              if (items.isEmpty) {
                return const EmptyBlock(
                  title: 'لا توجد خدمات مطابقة',
                  description: 'جرّب قسماً آخر أو امسح البحث.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, glassNavSpace),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                itemBuilder: (context, i) => _ServiceCard(
                  item: items[i],
                  isFavourite: _favourites.contains(items[i].id),
                  onToggleFavourite: () => _toggleFavourite(items[i].id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.item,
    required this.isFavourite,
    required this.onToggleFavourite,
  });
  final ServiceItem item;
  final bool isFavourite;
  final VoidCallback onToggleFavourite;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceId: item.id))),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الغلاف إلى جانب العنوان لا فوقه: صفٌّ من عشرين بطاقةٍ بصورةٍ
            // بعرض الشاشة في كلٍّ منها يصير صفحةَ صورٍ تُمرَّر طويلاً، والقصد
            // مقارنةُ خدماتٍ لا تصفّحُ ألبوم.
            if (item.coverPath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: MediaThumb(url: Api.mediaUrl(item.coverPath)),
                ),
              ),
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
                      if (item.providerIsFeatured) ...[
                        const SizedBox(width: Space.sm),
                        const StatusBadge('مميّز', color: AppColors.warning),
                      ],
                      // القلب داخل البطاقة على InkWell البطاقة نفسها: يُعطى
                      // مساحته الخاصة كي لا تفتح الضغطةُ عليه صفحةَ التفاصيل.
                      IconButton(
                        onPressed: onToggleFavourite,
                        visualDensity: VisualDensity.compact,
                        tooltip: isFavourite ? 'أزل من المفضّلة' : 'أضف للمفضّلة',
                        icon: Icon(
                          isFavourite ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: isFavourite ? AppColors.critical : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Muted(
                    '${item.providerName} · ${item.categoryName} · ${item.providerGovernorate}',
                  ),
                  // شارتان تقولان إن وراء البطاقة ما يُرى ويُسمع: بلا هذه
                  // العلامة لا يعرف أحدٌ أن للخدمة مقطعاً حتى يفتحها — ومن لم
                  // يفتحها لم يعرف.
                  if (item.hasVideo || item.hasAudio) ...[
                    const SizedBox(height: Space.sm),
                    Row(
                      children: [
                        if (item.hasVideo) const _MediaChip(Icons.play_circle_outline, 'فيديو'),
                        if (item.hasVideo && item.hasAudio) const SizedBox(width: Space.xs),
                        if (item.hasAudio) const _MediaChip(Icons.graphic_eq, 'مقطع صوتي'),
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
            if (item.providerRating > 0)
              Rating(item.providerRating, count: item.providerReviewsCount)
            else
              const Muted('جديد'),
          ],
        ),
        const SizedBox(height: Space.xs),
        Muted('العربون ${item.depositPercent}٪ · ${item.unit}', size: 11),
      ],
    );
  }
}

/// شارةٌ صغيرة: للخدمة فيديو أو صوت.
class _MediaChip extends StatelessWidget {
  const _MediaChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.accent),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: AppColors.accent, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
