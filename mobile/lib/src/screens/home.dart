import 'dart:async' show Timer;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import '../ui/media.dart';
import '../ui/motion.dart';
import 'provider_public.dart';
import 'service_detail.dart';

/// الشاشة الأولى.
///
/// ليست لوحةَ أرقام: من يفتح تطبيق أعراسٍ يسأل سؤالين — **كم بقي على
/// العرس** و**ما الذي عليّ فعله الآن**. فتُجاب هذه قبل أي شيءٍ آخر، ويأتي
/// التصفّح بعدها لا قبلها.
///
/// وتُعرض حالُ من لا خطّة له ولا حجز عرضاً كاملاً لا فراغاً: الشاشة الأولى
/// لمستخدمٍ جديد هي أوّل انطباعٍ عن التطبيق كلّه، وفراغُها يقول «لا شيء هنا».
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.onGoTo,
  });

  final Session session;

  /// الانتقال إلى تبويبٍ آخر في الشريط السفلي.
  ///
  /// تُمرَّر من القشرة لأنها هي مالكة المؤشّر: لو فتحت البطاقةُ شاشةً جديدة
  /// فوق الحالية لخرج المستخدم من الشريط السفلي كلّه وصار عليه زرُّ رجوع —
  /// وهو ليس انتقالاً بل مغادرة.
  final void Function(int index) onGoTo;

  // (وكان هنا `onSearch` لحقل بحثٍ في الرئيسية، ثمّ `onCategory` لبطاقات
  // الأقسام. حُذفا لعلّةٍ واحدة: كلاهما بابُ عبورٍ إلى شاشة «استكشف» يعيد
  // فيها المستخدمُ ما فعله هنا — يكتب في حقلٍ ليُنقل إلى حقلٍ آخر، ويضغط
  // قسماً ليُفتح تبويبٌ فيه صفُّ الأقسام نفسُه.)

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    // نداءاتٌ متوازية لا متتابعة: ثلاثةُ طلباتٍ على شبكة جوالٍ يمنية،
    // وتتابعُها يجمع زمنها كلّه بلا سبب.
    //
    // (وكانت أربعةً: `Api.categories()` معها. ذهب النداءُ مع الشبكة التي
    // كانت تعرضه — ولو بقي لَحُمّل على كلّ فتحةٍ للتطبيق ما لا يُرسم.)
    final results = await Future.wait([
      Api.myPlans(),
      widget.session.appUserId == null
          ? Future.value(<Booking>[])
          : Api.myBookings(widget.session.appUserId!),
      // والإعلانات معها: نداءٌ ثالثٌ في الحزمة نفسها لا رابعٌ بعدها. وفشلُه
      // لا يُسقط الرئيسية — شريطٌ ينقص لا شاشةٌ حمراء.
      Api.activePromotions().catchError((_) => <PromoSlot>[]),
      Api.activeBanners().catchError((_) => <PromoBanner>[]),
    ]);
    return _HomeData(
      plans: results[0] as List<WeddingPlan>,
      bookings: results[1] as List<Booking>,
      promos: results[2] as List<PromoSlot>,
      banners: results[3] as List<PromoBanner>,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
        if (snap.hasError) {
          return ErrorBlock(message: messageOf(snap.error!), onRetry: _refresh);
        }
        final data = snap.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.accent,
          // الحشوة الأفقية على الأبناء لا على القائمة: البطاقات الكبيرة تُمرَّر
          // من حافةٍ إلى حافة وتُطلّ التاليةُ من الجانب، وحشوةُ القائمة كانت
          // تحبسها في الوسط فتضيع الإطلالة التي تدلّ على أن هناك المزيد.
          child: ListView(
            padding: EdgeInsets.only(top: glassHeaderTop(context), bottom: glassNavSpace),
            children: [
              // اللافتاتُ الإعلانيّة — وتغيب كلَّها إن لم تكن هناك حملةٌ
              // جارية، فلا يبقى في أعلى الشاشة صندوقٌ فارغٌ ينتظر إعلاناً.
              if (data.banners.isNotEmpty) ...[
                _Banners(banners: data.banners),
                const SizedBox(height: Space.lg),
              ],
              if (data.promos.isNotEmpty) ...[
                _pad(_Promoted(promos: data.promos)),
                const SizedBox(height: Space.md),
              ],
              _pad(_Suggested(onExplore: () => widget.onGoTo(2))),
              const SizedBox(height: Space.lg),
            ],
          ),
        );
      },
    );
  }

  static Widget _pad(Widget child) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: Space.lg), child: child);
}

class _HomeData {
  _HomeData({
    required this.plans,
    required this.bookings,
    this.promos = const [],
    this.banners = const [],
  });
  final List<WeddingPlan> plans;
  final List<Booking> bookings;
  final List<PromoSlot> promos;
  final List<PromoBanner> banners;

  WeddingPlan? get plan => plans.isEmpty ? null : plans.first;

  /// الحجوزات القادمة مرتّبةً بالأقرب.
  ///
  /// والماضي يُستبعد: «حجزك القادم» عن عرسٍ انقضى الشهر الماضي خبرٌ خاطئ لا
  /// خبرٌ قديم. وكذلك الملغى والمرفوض — عدُّهما في «٣ حجوزات» يَعِد بما لا وجود
  /// له.
  List<Booking> get upcoming {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return bookings
        .where(
          (b) =>
              b.eventDate.compareTo(today) >= 0 &&
              b.status != BookingStatus.cancelled &&
              b.status != BookingStatus.rejected,
        )
        .toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
  }

  Booking? get next => upcoming.isEmpty ? null : upcoming.first;

  int countOf(BookingStatus status) => upcoming.where((b) => b.status == status).length;
}

// ── اللافتاتُ الإعلانيّة ─────────────────────────────────────────────────────
/// مساحةُ الإعلان في أعلى الرئيسية — صورةٌ تُمرَّر بالإبهام.
///
/// **وكانت هنا بطاقتان كبيرتان:** «خطة العرس» و«حجوزاتي». حُذفتا بطلبِ صاحب
/// المنصّة لتصير المساحةُ للإعلانات، وكلتاهما بابُها قائمٌ في الشريط السفلي.
///
/// **والمقاسُ مقاسُهما نفسُه** — ‎١٩٦‎ ارتفاعاً، وإطلالةُ التالية من الجانب،
/// والنقاطُ تحتها. فما تغيّر ما يملأ المساحةَ لا المساحةُ نفسُها.
///
/// **ومكتوبٌ عليها «إعلان» صراحةً.** مساحةٌ مدفوعةٌ تُعرض كأنّها اختيارُ
/// المنصّة تخدع من يقرؤها، ومن اكتشف ذلك لاحقاً لم يعد يثق بترتيبٍ آخرَ
/// فيها. وهو ما قيل في شريط «مزوّدون مميّزون» وهذا أَولى به: موضعُه أعلى
/// الشاشة.
class _Banners extends StatefulWidget {
  const _Banners({required this.banners});
  final List<PromoBanner> banners;

  @override
  State<_Banners> createState() => _BannersState();
}

class _BannersState extends State<_Banners> {
  // ‎٠٫٨٨‎: تبقى من التالية شريحةٌ تُرى ولا تُقرأ — كافيةٌ للدلالة على أنّ
  // وراءها شيئاً، لا تُشتّت. وهي نسبةُ البطاقتين قبلها.
  final _controller = PageController(viewportFraction: 0.88);
  int _page = 0;

  /// مؤقّتُ الدوران — يُحفظ ليُلغى.
  ///
  /// **ومؤقّتٌ لا يُلغى يُسقط الاختبارات كلَّها** («A Timer is still
  /// pending»)، وهو محقٌّ: التسريبُ واحدٌ في الاختبار وعلى الجهاز.
  Timer? _tick;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _arm();
  }

  /// يُشغَّل الدوران — أو لا يُشغَّل.
  ///
  /// **ولا يدور لواحدة:** لا شيءَ ينتقل إليه.
  ///
  /// **ولا يدور لمن أطفأ الحركة.** لافتةٌ تتبدّل تحت العين كلَّ ثلاثِ ثوانٍ
  /// من أشدّ ما يزعج أصحابَ حساسيّة الحركة، وهو إعدادٌ في النظام يُسأل عنه
  /// كما يُسأل في الدوّار وفي دخول البطاقات.
  void _arm() {
    _tick?.cancel();
    _tick = null;
    if (widget.banners.length < 2 || reduceMotion(context)) return;
    // ثلاثُ ثوانٍ: ما يكفي لقراءة لافتةٍ لا لحفظها.
    _tick = Timer.periodic(const Duration(seconds: 3), (_) => _next());
  }

  void _next() {
    if (!mounted || !_controller.hasClients) return;
    // الدورةُ تعود إلى الأولى: `%` لا حدٌّ يقف عنده، وإلّا وقفت اللافتاتُ
    // عند الأخيرة ولم يعد أحدٌ يرى الأولى.
    final next = (_page + 1) % widget.banners.length;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          // ارتفاعٌ ثابت: `PageView` لا يقيس أبناءه، فبلا حدٍّ يعلوه يرمي.
          // والرقمُ هو ارتفاعُ البطاقتين اللتين كانتا هنا — «بنفس حجم
          // البطاقة».
          height: 196,
          child: PageView(
            controller: _controller,
            onPageChanged: (i) {
              setState(() => _page = i);
              // **وتُعاد المهلةُ من الصفر بعد كلّ انتقال.** من مرّر بإبهامه
              // لافتةً لا يجوز أن تُسحب من تحت عينه بعد جزءٍ من الثانية
              // لأنّ المؤقّت كان قد قارب.
              _arm();
            },
            children: [
              for (final banner in widget.banners)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: BannerCard(banner: banner),
                ),
            ],
          ),
        ),
        // ولا نقاطَ للافتةٍ واحدة: نقطةٌ وحدها تقول «هنا واحدة» ولا تُفيد.
        if (widget.banners.length > 1) ...[
          const SizedBox(height: Space.md),
          _Dots(active: _page, total: widget.banners.length),
        ],
      ],
    );
  }
}

class BannerCard extends StatelessWidget {
  const BannerCard({super.key, required this.banner});
  final PromoBanner banner;

  @override
  Widget build(BuildContext context) {
    // نصفُ القطر ‎٢٢‎ — هو نصفُ قطر البطاقة الكبيرة، فلا تُقرأ اللافتةُ
    // جسماً غريباً عن الشاشة.
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // **والرابطُ كاملٌ لا مسارٌ في سلّة.** عمودُ القاعدة اسمُه
          // `image_url`، واللافتةُ قد تُرفع في سلّةٍ خاصّةٍ بها أو تأتي من
          // خارج المنصّة أصلاً — فلا يُفترض لها موضعُ تخزينٍ واحد.
          MediaThumb(url: banner.imageUrl.isEmpty ? null : banner.imageUrl),

          // كلماتُ الإعلان — وتحتها ستارٌ متدرّج.
          //
          // **والستارُ شرطٌ لا زينة.** الصورةُ تأتي من صاحب الإعلان ولا
          // نعرف ألوانها: نصٌّ أبيضُ على سماءٍ بيضاءَ في صورةِ قاعةٍ نهاراً
          // لا يُقرأ حرفاً منه. والتدرّجُ يضمن أرضيّةً غامقةً تحت الكلمات
          // مهما كانت الصورة، ويترك أعلاها كما هو.
          if (banner.headline.isNotEmpty)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.ink.withValues(alpha: 0.82),
                      AppColors.ink.withValues(alpha: 0.34),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.36, 0.62],
                  ),
                ),
              ),
            ),
          if (banner.headline.isNotEmpty)
            PositionedDirectional(
              start: 14,
              end: 14,
              bottom: 12,
              child: Text(
                banner.headline,
                // سطران وقصٌّ بعدهما: اللافتةُ مساحةٌ ثابتةٌ، ونصٌّ طويلٌ
                // يزحف عليها حتى يغطّي الصورةَ التي دُفع ثمنُها.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: Colors.white,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
            ),

          // شارةُ «إعلان» على ركنٍ أعلى: صغيرةٌ لا تبتلع الصورة، ومقروءةٌ
          // على أيّ صورةٍ لأنّ لها أرضيّتَها.
          PositionedDirectional(
            top: 8,
            start: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                child: Text(
                  'إعلان',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // **ولا تُضغط لافتةٌ لا وجهةَ لها.** ضغطةٌ لا يقع بعدها شيءٌ تُقرأ عطباً
    // في التطبيق لا إعلاناً بلا رابط.
    if (banner.providerId.isEmpty) return card;
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PublicProviderScreen(
            providerId: banner.providerId,
            // الاسمُ يُكتب في الشريط ريثما يصل الملفّ — فلا تُفتح الشاشةُ
            // على عنوانٍ عامٍّ ثمّ يتبدّل تحت العين.
            name: banner.providerName.isEmpty ? null : banner.providerName,
          ),
        ),
      ),
      child: card,
    );
  }
}

/// نقاطٌ تحت البطاقات — كم بطاقةً هناك وأينَ أنت منها.
class _Dots extends StatelessWidget {
  const _Dots({required this.active, required this.total});
  final int active;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < total; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        // المختارة تستطيل ولا تكتفي باللون: علامةٌ ثانية لمن لا يفرّق الألوان.
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: i == active ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == active ? AppColors.accent : AppColors.hairline,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    ],
  );
}

// (وكانت هنا **شبكةُ الأقسام** — اثنتا عشرة بطاقةً تشغل الشاشة الأولى
// كلَّها. حُذفت: الأقسامُ نفسُها صفٌّ في أعلى «استكشف»، وهي هناك مرشِّحٌ
// يعمل — يُضغط القسمُ فتُرشَّح القائمةُ تحته في مكانها. وهنا كانت بابَ
// عبورٍ إلى تلك الشاشة نفسِها، فيُضغط القسمُ لِيُفتح تبويبٌ آخرُ ويُعاد
// اختيارُ القسم فيه.
//
// وذهب معها زرُّ «الكل» فوقها — وهو يفتح «استكشف» بلا مرشِّح، أي ما يفعله
// تبويبُ «استكشف» في الشريط السفلي.)

// ── خدماتٌ مقترحة ────────────────────────────────────────────────────────────
class _Suggested extends StatefulWidget {
  const _Suggested({required this.onExplore});
  final VoidCallback onExplore;
  @override
  State<_Suggested> createState() => _SuggestedState();
}

class _SuggestedState extends State<_Suggested> {
  /// كم خدمةً تُعرض — **أربعٌ: بطاقتان في سطرين**.
  ///
  /// وثلاثٌ تترك في السطر الثاني خليّةً فارغةً تُقرأ نقصاً.
  static const _shown = 4;

  late final Future<List<ServiceItem>> _future = Api.services();

  /// ما حُفظ في المفضّلة — تُقرأ مرّةً وتُبدَّل في المكان.
  Set<String> _favourites = {};

  @override
  void initState() {
    super.initState();
    _loadFavourites();
  }

  Future<void> _loadFavourites() async {
    try {
      final rows = await Api.myFavourites();
      if (mounted) setState(() => _favourites = rows);
    } catch (_) {
      // المفضّلةُ زينةٌ لا شرط: فشلُ قراءتها لا يمنع عرضَ الخدمات، والقلبُ
      // يبقى فارغاً حتى يُضغط.
    }
  }

  /// التبديلُ يقع في الواجهة أوّلاً ثمّ يُرسَل.
  ///
  /// القلبُ يستجيب فوراً كما يتوقّع الإصبع، ويعود إن رفض الخادم — ونسخةٌ
  /// واحدةٌ من هذا السلوك في «استكشف» ومثلُها هنا، لأنّ الحالةَ محليّةٌ لكلّ
  /// شاشة.
  Future<void> _toggleFavourite(String serviceId) async {
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
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceItem>>(
      future: _future,
      builder: (context, snap) {
        final all = snap.data ?? const <ServiceItem>[];
        // لا كتلةَ خطأٍ هنا ولا مؤشّر تحميل: هذا قسمٌ مكمّل، وعطبُه لا يجوز
        // أن يُفسد شاشةً بقيّتُها سليمة. يغيب بصمتٍ ويبقى ما فوقه.
        if (all.isEmpty) return const SizedBox.shrink();
        // **والعددُ مقطوعٌ هنا مرّةً واحدة.** كان محدوداً في موضعين — شرطُ
        // الحلقة وشرطُ البطاقة الثانية — فبدّلتُ أحدَهما في ضابطٍ سالبٍ
        // فلم يتبدّل شيء: البطاقةُ الرابعة تأتي من الشرط الآخر. وحدٌّ في
        // موضعين ليس حدّاً.
        final items = all.take(_shown).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: SectionTitle('خدماتٌ لك')),
                TextButton(onPressed: widget.onExplore, child: const Text('المزيد')),
              ],
            ),
            const SizedBox(height: Space.sm),
            // **بطاقتان في السطر — وأربعٌ لا ثلاث.** الثلاثةُ تترك في السطر
            // الثاني خليّةً فارغةً تُقرأ نقصاً.
            //
            // **و`IntrinsicHeight` لا نسبةَ أبعادٍ ثابتة.** شبكةٌ بنسبةٍ
            // ثابتة تفيض حين يطول عنوانٌ أو يكبر خطُّ الجهاز — وقد ضاقت
            // شبكةُ الأقسام ثلاث مرّاتٍ لهذا السبب قبل أن تُقاس. وهنا
            // يأخذ السطرُ ارتفاعَ أطولِ بطاقتيه، فلا فيضَ أصلاً.
            for (var i = 0; i < items.length; i += 2) ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SuggestedCard(
                        item: items[i],
                        isFavourite: _favourites.contains(items[i].id),
                        onToggleFavourite: () => _toggleFavourite(items[i].id),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    // خليّةٌ فارغةٌ للفردِ الأخير — لا بطاقةٌ تتمدّد على
                    // السطر كلِّه فتُقرأ صنفاً آخرَ من البطاقات.
                    Expanded(
                      child: i + 1 < items.length
                          ? _SuggestedCard(
                              item: items[i + 1],
                              isFavourite: _favourites.contains(items[i + 1].id),
                              onToggleFavourite: () =>
                                  _toggleFavourite(items[i + 1].id),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.sm),
            ],
          ],
        );
      },
    );
  }
}

/// بطاقةُ خدمةٍ في سطرٍ من بطاقتين — غلافٌ فوق، والاسمُ والسعرُ تحته.
///
/// **ولمَ ليست `ServiceListCard`.** تلك صفٌّ أفقيّ: غلافٌ ‎٧٦×٧٦‎ إلى جانب
/// عمودٍ فيه الاسمُ والمزوّدُ والسعرُ والمسافةُ والقلب. وهي مبنيّةٌ لعرض
/// الشاشة كاملاً؛ فلو حُشرت في نصفِه لَبقي للنصّ أقلُّ من ستّين بكسلاً.
///
/// وهذه قِطعةٌ لا صفّ: الغلافُ بعرض البطاقة، والنصُّ تحته في ثلاثة أسطرٍ
/// قصيرة. والحشوةُ ‎٨‎ لا ‎١٦‎ كما في `AppCard` — ستّةَ عشرَ من كلّ جانبٍ
/// تبتلع خُمسَ البطاقة.
class _SuggestedCard extends StatelessWidget {
  const _SuggestedCard({
    required this.item,
    required this.isFavourite,
    required this.onToggleFavourite,
  });
  final ServiceItem item;
  final bool isFavourite;
  final VoidCallback onToggleFavourite;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceId: item.id)),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: MediaThumb(url: Api.mediaUrl(item.coverPath)),
                    ),
                  ),
                  // **على ركن الغلاف لا تحت الاسم.** البطاقةُ نصفُ شاشة،
                  // والسطرُ الذي فيه الاسمُ لا يحتمل زرّاً ‎٤٠‎ بكسلاً إلى
                  // جانبه. والركنُ الأقصى — يسارُ الأعلى في العربية —
                  // موضعٌ تعوّدته الأصابع من كلّ تطبيقٍ فيه حفظ.
                  PositionedDirectional(
                    top: 4,
                    end: 4,
                    child: _HeartButton(
                      isFavourite: isFavourite,
                      onTap: onToggleFavourite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              // سطران للاسم: أسماءُ الخدمات جملٌ لا كلمات — «قاعة التاج —
              // باقة شاملة» لا يكتمل في سطرٍ داخل نصف شاشة.
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
              const SizedBox(height: 2),
              // المزوّدُ وحده بلا محافظته: سطرٌ واحدٌ في مئةٍ وأربعين بكسلاً،
              // والاسمان معاً يُقصّان فلا يُقرأ أيٌّ منهما.
              Muted(item.providerName, size: 10.5),
              const SizedBox(height: Space.xs),
              // السعرُ والتقييم في سطرٍ واحد — وهما ما تُقارَن به البطاقتان.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatMoney(item.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        fontFamilyFallback: arabicFallback,
                      ),
                    ),
                  ),
                  if (item.providerRating > 0) Rating(item.providerRating, size: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// قلبُ المفضّلة على ركن الغلاف.
///
/// **وقرصٌ أبيضُ تحته لا قلبٌ عارٍ.** الغلافُ صورةٌ لا يُعرف لونُها: قلبٌ
/// نبيذيٌّ على قاعةٍ مظلمةٍ لا يُرى، وأبيضُ على كوشةٍ فاتحةٍ كذلك. فالقرصُ
/// يعطيه أرضيّةً ثابتةً مهما كانت الصورة.
///
/// **ونبيذيٌّ لا أحمر.** أحمرُ الخطأ على خدمةٍ يُقرأ إنذاراً — وهو `accent`
/// نفسُه في `ServiceListCard`، فلا يفترق القلبان بين شاشتين.
class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.isFavourite, required this.onTap});
  final bool isFavourite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.86),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // **ومساحتُه الخاصّة تحته.** البطاقةُ كلُّها تفتح صفحةَ الخدمة،
        // فقلبٌ بلا حَلبةِ إيماءاتٍ خاصّةٍ به يُضغط فتُفتح الصفحة ولا يُحفظ
        // شيء.
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            isFavourite ? Icons.favorite : Icons.favorite_border,
            size: 17,
            color: AppColors.accent,
            semanticLabel: isFavourite ? 'أزل من المفضّلة' : 'أضف للمفضّلة',
          ),
        ),
      ),
    );
  }
}

/// شريطُ المزوّدين المميَّزين — ما تبيعه المنصّة في «الإعلانات».
///
/// **ومكتوبٌ عليه «إعلان» صراحةً.** ترتيبٌ مدفوعٌ يُعرض كأنه اختيارُ المنصّة
/// يخدع من يقرؤه، ومن اكتشفه لاحقاً لم يعد يثق بترتيبٍ آخر فيها.
class _Promoted extends StatelessWidget {
  const _Promoted({required this.promos});

  final List<PromoSlot> promos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('مزوّدون مميّزون')),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: Tint.chip),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'إعلان',
                style: TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: promos.length,
            separatorBuilder: (context, index) => const SizedBox(width: Space.sm),
            itemBuilder: (context, i) {
              final promo = promos[i];
              return SizedBox(
                width: 148,
                child: AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PublicProviderScreen(providerId: promo.providerId, name: promo.providerName),
                    ),
                  ),
                  children: [
                    Row(
                      children: [
                        ProviderAvatar(
                          name: promo.providerName,
                          imageUrl: Api.avatarUrl(promo.logoPath),
                          size: 32,
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Text(
                            promo.providerName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    Muted(promo.governorate, size: 11),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
