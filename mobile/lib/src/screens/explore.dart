import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import '../ui/service_card.dart';
import 'provider_public.dart';
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
  Future<List<PublicProvider>>? _providers;
  Set<String> _favourites = {};

  /// أنتصفّح خدماتٍ أم مزوّدين.
  ///
  /// **وليسا شاشتين:** المرشِّحان واحد — القسمُ والبحث — وشاشتان تفترقان
  /// بمرور الوقت فيُصلَح عيبٌ في إحداهما ويبقى في الأخرى. والتبديل هنا يبدّل
  /// ما يُعرض تحت المرشِّح لا الشاشة كلَّها.
  bool _asProviders = false;

  /// اسمُ القسم المختار — دليلُ المزوّدين يُرشَّح به لا بالمعرّف.
  String? _categoryName;

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
      if (_asProviders) {
        _providers = Api.providers(search: _applied, categoryName: _categoryName);
      }
    });
  }

  /// اسمُ القسم من معرّفه — يُقرأ من القائمة المحمَّلة أصلاً، بلا نداءٍ ثانٍ.
  Future<void> _rememberCategoryName() async {
    if (_categoryId == null) {
      _categoryName = null;
      return;
    }
    try {
      final cats = await _categories;
      _categoryName = cats.where((c) => c.id == _categoryId).firstOrNull?.name;
    } catch (_) {
      _categoryName = null;
    }
  }

  Future<void> _switchTo(bool providers) async {
    await _rememberCategoryName();
    if (!mounted) return;
    setState(() => _asProviders = providers);
    _reload();
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
        // التبديل بين ما يُعرض: خدماتٌ أم مزوّدون.
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
          child: Row(
            children: [
              Expanded(
                child: _Toggle(
                  label: 'خدمات',
                  icon: Icons.sell_outlined,
                  active: !_asProviders,
                  onTap: () => _switchTo(false),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _Toggle(
                  label: 'مقدّمو الخدمة',
                  icon: Icons.storefront_outlined,
                  active: _asProviders,
                  onTap: () => _switchTo(true),
                ),
              ),
            ],
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
                      _categoryName = null;
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
                        _categoryName = c.name;
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
          child: _asProviders
              ? _Providers(future: _providers, onRetry: _reload)
              : FutureBuilder<List<ServiceItem>>(
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
                itemBuilder: (context, i) => ServiceListCard(
                  item: items[i],
                  isFavourite: _favourites.contains(items[i].id),
                  onToggleFavourite: () => _toggleFavourite(items[i].id),
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServiceDetailScreen(serviceId: items[i].id),
                    ),
                  ),
                  // اسمُ المزوّد بابٌ إلى ملفّه: من رأى «كوشة ورد» قد يريد أن
                  // يرى ما يعرضه صاحبها كلَّه قبل أن يقارن ثمناً بثمن.
                  onOpenProvider: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PublicProviderScreen(
                        providerId: items[i].providerId,
                        name: items[i].providerName,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


/// زرُّ تبديلٍ بين ما يُعرض.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: active ? AppColors.accent : AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: active ? AppColors.accent : AppColors.hairline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: active ? AppColors.accentInk : AppColors.ink2),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.accentInk : AppColors.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// دليلُ المزوّدين.
class _Providers extends StatelessWidget {
  const _Providers({required this.future, required this.onRetry});
  final Future<List<PublicProvider>>? future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PublicProvider>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
        if (snap.hasError) {
          return ErrorBlock(message: messageOf(snap.error!), onRetry: onRetry);
        }
        final rows = snap.data ?? const <PublicProvider>[];
        if (rows.isEmpty) {
          return const EmptyBlock(
            title: 'لا مزوّدين في هذا القسم',
            description: 'جرّب قسماً آخر أو امسح البحث.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, glassNavSpace),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: Space.md),
          itemBuilder: (context, i) => _ProviderRow(provider: rows[i]),
        );
      },
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.provider});
  final PublicProvider provider;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PublicProviderScreen(providerId: p.id, name: p.businessName),
        ),
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProviderAvatar(name: p.businessName, imageUrl: Api.avatarUrl(p.logoPath), size: 52),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (p.isVerified) ...[
                        const SizedBox(width: 4),
                        const VerifiedMark(size: 14),
                      ],
                      if (p.isFeatured) ...[
                        const SizedBox(width: Space.xs),
                        const StatusBadge('مميّز', color: AppColors.warning),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Muted(
                    [
                      p.governorate,
                      if (p.categories.isNotEmpty) p.categories.first,
                    ].where((t) => t.isNotEmpty).join(' · '),
                  ),
                  const SizedBox(height: Space.sm),
                  Row(
                    children: [
                      if (p.rating > 0)
                        Rating(p.rating, count: p.reviewsCount)
                      else
                        const Muted('جديد'),
                      const SizedBox(width: Space.md),
                      // عددُ ما نُفِّذ هو ما يفرّق مزوّداً عن مزوّد أكثر من
                      // التقييم: خمسُ نجومٍ من تقييمين ليست كأربعٍ من مئة.
                      if (p.completedBookings > 0)
                        Muted('${p.completedBookings} حجزاً منفَّذاً', size: 11),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (p.bio.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          Text(
            p.bio,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.7, color: AppColors.ink2),
          ),
        ],
      ],
    );
  }
}
