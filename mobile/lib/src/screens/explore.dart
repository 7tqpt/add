import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'service_detail.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _search = TextEditingController();
  String _applied = '';
  String? _categoryId;
  late Future<List<ServiceCategory>> _categories;
  late Future<List<ServiceItem>> _services;
  Set<String> _favourites = {};

  @override
  void initState() {
    super.initState();
    _categories = Api.categories();
    _reload();
    _loadFavourites();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
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
                padding: const EdgeInsets.all(Space.lg),
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
            // القلب داخل البطاقة على InkWell البطاقة نفسها: يُعطى مساحته
            // الخاصة كي لا تفتح الضغطةُ عليه صفحةَ التفاصيل.
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
        Muted('${item.providerName} · ${item.categoryName} · ${item.providerGovernorate}'),
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
