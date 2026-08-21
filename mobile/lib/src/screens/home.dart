import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'labels.dart';
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
    final results = await Future.wait([
      Api.myPlans(),
      widget.session.appUserId == null
          ? Future.value(<Booking>[])
          : Api.myBookings(widget.session.appUserId!),
      Api.categories(),
    ]);
    return _HomeData(
      plans: results[0] as List<WeddingPlan>,
      bookings: results[1] as List<Booking>,
      categories: results[2] as List<ServiceCategory>,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, glassNavSpace),
            children: [
              _Countdown(plan: data.plan, onPlan: () => widget.onGoTo(3)),
              const SizedBox(height: Space.md),
              if (data.next != null) ...[
                _NextBooking(booking: data.next!, onAll: () => widget.onGoTo(1)),
                const SizedBox(height: Space.md),
              ],
              _Categories(
                categories: data.categories,
                onExplore: () => widget.onGoTo(2),
              ),
              const SizedBox(height: Space.md),
              _Suggested(onExplore: () => widget.onGoTo(2)),
              const SizedBox(height: Space.lg),
            ],
          ),
        );
      },
    );
  }
}

class _HomeData {
  _HomeData({required this.plans, required this.bookings, required this.categories});
  final List<WeddingPlan> plans;
  final List<Booking> bookings;
  final List<ServiceCategory> categories;

  WeddingPlan? get plan => plans.isEmpty ? null : plans.first;

  /// أقربُ حجزٍ قادمٍ لم يُلغَ ولم يُرفض.
  ///
  /// والماضي يُستبعد: «حجزك القادم» عن عرسٍ انقضى الشهر الماضي خبرٌ خاطئ لا
  /// خبرٌ قديم.
  Booking? get next {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final upcoming =
        bookings
            .where(
              (b) =>
                  b.eventDate.compareTo(today) >= 0 &&
                  b.status != BookingStatus.cancelled &&
                  b.status != BookingStatus.rejected,
            )
            .toList()
          ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    return upcoming.isEmpty ? null : upcoming.first;
  }
}

// ── العدّ التنازلي ───────────────────────────────────────────────────────────
class _Countdown extends StatelessWidget {
  const _Countdown({required this.plan, required this.onPlan});
  final WeddingPlan? plan;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    if (p == null || p.weddingDate.isEmpty) {
      return AppCard(
        children: [
          const SectionTitle('ابدأ خطة عرسك'),
          const SizedBox(height: Space.sm),
          const Text(
            'حدّد التاريخ والميزانية وعدد الضيوف، فيحسب لك التطبيق ما دفعتَه وما بقي، '
            'ويجمع خدماتك كلّها في مكانٍ واحد.',
            style: TextStyle(height: 1.7, color: AppColors.ink2),
          ),
          const SizedBox(height: Space.md),
          FilledButton.icon(
            onPressed: onPlan,
            icon: const Icon(Icons.favorite_outline, size: 20),
            label: const Text('أنشئ الخطة'),
          ),
        ],
      );
    }

    final days = _daysUntil(p.weddingDate);
    return AppCard(
      onTap: onPlan,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Muted(p.title.isEmpty ? 'خطة العرس' : p.title),
                  const SizedBox(height: Space.xs),
                  Text(
                    _countdownLabel(days),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Muted(formatDate(p.weddingDate)),
                ],
              ),
            ),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite, color: AppColors.accent, size: 22),
            ),
          ],
        ),
        if (p.totalCost > 0) ...[
          const SizedBox(height: Space.md),
          // شريطٌ ورقمان: نسبةُ ما دُفع تُقرأ بلمحة، والرقم يليها لمن يريد
          // الدقّة. والشريط وحده لا يكفي — «نصف الميزانية» غير «٤٠٠ ألف».
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (p.paidAmount / p.totalCost).clamp(0.0, 1.0).toDouble(),
              minHeight: 7,
              backgroundColor: AppColors.surface2,
              valueColor: const AlwaysStoppedAnimation(AppColors.good),
            ),
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Flexible(child: Muted('مدفوع ${formatMoney(p.paidAmount)}', maxLines: 1)),
              const SizedBox(width: Space.md),
              Flexible(child: Muted('متبقٍّ ${formatMoney(p.remainingAmount)}', maxLines: 1)),
            ],
          ),
        ],
      ],
    );
  }

  /// الفرق بالأيام التقويمية لا بالساعات.
  ///
  /// `DateTime.difference` يحسب بالساعات ثم يقسم، فعرسٌ غداً ظهراً يخرج «صفر
  /// يوم» إن نُظر إليه صباحاً. والمستخدم يعدّ الأيام لا الساعات.
  static int? _daysUntil(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return null;
    final now = DateTime.now();
    return DateTime(date.year, date.month, date.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  static String _countdownLabel(int? days) {
    if (days == null) return '—';
    if (days > 1) return 'بقي $days يوماً';
    if (days == 1) return 'غداً بإذن الله';
    if (days == 0) return 'اليوم — مبارك!';
    return 'مضى ${-days} يوماً';
  }
}

// ── الحجز القادم ─────────────────────────────────────────────────────────────
class _NextBooking extends StatelessWidget {
  const _NextBooking({required this.booking, required this.onAll});
  final Booking booking;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onAll,
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('حجزك القادم')),
            const SizedBox(width: Space.sm),
            Flexible(
              child: StatusBadge(
                bookingStatusLabel(booking.status),
                color: bookingStatusColor(booking.status),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        Text(
          booking.serviceTitle,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
        ),
        const SizedBox(height: Space.xs),
        Muted('${booking.providerName} · ${formatDate(booking.eventDate)}'),
      ],
    );
  }
}

// ── الأقسام ──────────────────────────────────────────────────────────────────
class _Categories extends StatelessWidget {
  const _Categories({required this.categories, required this.onExplore});
  final List<ServiceCategory> categories;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('ابحث عن خدمة')),
            TextButton(onPressed: onExplore, child: const Text('الكل')),
          ],
        ),
        const SizedBox(height: Space.sm),
        // شبكةٌ هنا لا صفٌّ أفقيّ — عكسَ شاشة التصفّح: هناك الأقسام مرشِّحٌ
        // فوق قائمة، وهنا هي المحتوى نفسه ولا شيء تحتها يُزاحمها.
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.sm,
          crossAxisSpacing: Space.sm,
          // ٧٦ عرضاً إلى ١٠٨ ارتفاعاً على شاشة ٣٦٠: قِيست بالرسم بعد أن
          // أفاضت النسبةُ السابقة سبعةَ بكسلاتٍ ونصفاً.
          childAspectRatio: 0.70,
          children: [
            for (final c in categories.take(8))
              CategoryCard(
                label: c.name,
                icon: categoryIcon(c.slug),
                active: false,
                onTap: onExplore,
              ),
          ],
        ),
      ],
    );
  }
}

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
