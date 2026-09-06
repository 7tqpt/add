import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
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
    ]);
    return _HomeData(
      plans: results[0] as List<WeddingPlan>,
      bookings: results[1] as List<Booking>,
      promos: results[2] as List<PromoSlot>,
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
              _HeroCards(
                data: data,
                onPlan: () => widget.onGoTo(3),
                onBookings: () => widget.onGoTo(1),
              ),
              const SizedBox(height: Space.lg),
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
  });
  final List<WeddingPlan> plans;
  final List<Booking> bookings;
  final List<PromoSlot> promos;

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

// ── البطاقتان الكبيرتان ──────────────────────────────────────────────────────
/// خطةُ العرس وحجوزاتك — بطاقتان تُمرَّران بالإبهام.
///
/// بطاقتان كبيرتان لا أربعُ بطاقاتٍ صغيرة: هذان هما سؤالا من يفتح التطبيق —
/// **كم بقي** و**ما حالُ حجوزاتي** — فيأخذان الشاشة كلَّها لا زاويةً منها.
/// والتمرير أرخص من الضغط: الإبهام يمرّ فتظهر الثانية، بلا خروجٍ من الشاشة
/// ولا زرِّ رجوع.
///
/// وتُطلّ الثانيةُ من الجانب (‏`viewportFraction` دون الواحد‏): بطاقةٌ تملأ
/// العرض تماماً لا تقول إن وراءها شيئاً، فلا يُمرِّر أحدٌ ما لا يعلم أنه هناك.
class _HeroCards extends StatefulWidget {
  const _HeroCards({required this.data, required this.onPlan, required this.onBookings});

  final _HomeData data;
  final VoidCallback onPlan;
  final VoidCallback onBookings;

  @override
  State<_HeroCards> createState() => _HeroCardsState();
}

class _HeroCardsState extends State<_HeroCards> {
  // ‎٠٫٨٨‎: تبقى من الثانية شريحةٌ تُرى ولا تُقرأ — كافيةٌ للدلالة، لا تُشتّت.
  final _controller = PageController(viewportFraction: 0.88);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = [_planCard(), _bookingsCard()];
    return Column(
      children: [
        SizedBox(
          // ارتفاعٌ ثابت: `PageView` لا يقيس أبناءه، فبلا حدٍّ يعلوه يرمي.
          // والرقم مقيسٌ على الرسم لا مقدَّر — أطولُ محتوىً هو بطاقة الخطة
          // بشريطها وسطرَي المبلغ.
          height: 196,
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (final card in cards)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: card),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        _Dots(active: _page, total: cards.length),
      ],
    );
  }

  Widget _planCard() {
    final p = widget.data.plan;
    final has = p != null && p.weddingDate.isNotEmpty;
    final days = has ? daysUntil(p.weddingDate) : null;
    final paid = has && p.totalCost > 0 ? (p.paidAmount / p.totalCost).clamp(0.0, 1.0).toDouble() : null;

    return BigHeroCard(
      // نبيذيٌّ من لون العلامة إلى أغمقَ منه: البطاقة سطحٌ لا لطخة.
      // والأبيضُ على أفتح طرفيه ‎٨٫٠٨:١‎.
      colors: const [AppColors.accentLift, AppColors.accentDeep],
      icon: Icons.favorite_rounded,
      title: 'خطة العرس',
      headline: has ? countdownLabel(days) : 'ابدأ خطة عرسك',
      subtitle: has
          ? [formatDate(p.weddingDate), if (p.governorate.isNotEmpty) p.governorate].join(' · ')
          : 'التاريخ والميزانية وعدد الضيوف في مكانٍ واحد',
      progress: paid,
      footer: has
          ? (paid == null
                ? 'لم تُضَف تكاليف بعد'
                : 'مدفوع ${(paid * 100).round()}٪ · متبقٍّ ${formatMoney(p.remainingAmount)}')
          : 'اضغط لإنشاء الخطة',
      onTap: widget.onPlan,
    );
  }

  Widget _bookingsCard() {
    final s = BookingsSummary.of(widget.data.bookings);
    final list = s.upcoming;
    final next = s.next;
    final confirmed = s.confirmed;
    final pending = s.pending;

    return BigHeroCard(
      // طَفليٌّ محروق: لونٌ ثانٍ يفصل البطاقتين بلمحةٍ قبل قراءة العنوان،
      // وهو من عائلة الكريم والذهب لا غريبٌ عنها — والأبيض عليه ‎٥٫٥٦:١‎.
      colors: const [Color(0xFFA3521A), Color(0xFF6B3208)],
      icon: Icons.event_available_rounded,
      title: 'حجوزاتي',
      headline: list.isEmpty ? 'لا حجوزات قادمة' : formatCount(list.length, bookingForms),
      subtitle: next == null
          ? 'تصفّح الخدمات واحجز أوّل خدمة'
          : 'أقربها ${_whenLabel(daysUntil(next.eventDate))} · ${next.providerName}',
      footer: list.isEmpty
          ? 'اضغط لعرض حجوزاتك'
          : [
              if (confirmed > 0) 'مؤكّد $confirmed',
              if (pending > 0) 'بانتظار المزوّد $pending',
            ].join(' · '),
      onTap: widget.onBookings,
    );
  }
}

String _whenLabel(int? days) {
  if (days == null) return '—';
  if (days == 0) return 'اليوم';
  if (days == 1) return 'غداً';
  return 'بعد ${formatCount(days, dayForms)}';
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
  late final Future<List<ServiceItem>> _future = Api.services();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceItem>>(
      future: _future,
      builder: (context, snap) {
        final items = snap.data ?? const <ServiceItem>[];
        // لا كتلةَ خطأٍ هنا ولا مؤشّر تحميل: هذا قسمٌ مكمّل، وعطبُه لا يجوز
        // أن يُفسد شاشةً بقيّتُها سليمة. يغيب بصمتٍ ويبقى ما فوقه.
        if (items.isEmpty) return const SizedBox.shrink();
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
            for (final item in items.take(3)) ...[
              AppCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceId: item.id)),
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (item.providerRating > 0) Rating(item.providerRating),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Muted('${item.providerName} · ${item.providerGovernorate}'),
                  const SizedBox(height: Space.sm),
                  Text(
                    formatMoney(item.price),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
            ],
          ],
        );
      },
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
