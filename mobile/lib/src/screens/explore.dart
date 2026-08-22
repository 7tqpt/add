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
