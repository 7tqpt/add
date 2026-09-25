import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/booking_stages.dart';
import '../ui/kit.dart';
import '../ui/media.dart';
import '../ui/motion.dart';
import 'booking_detail.dart';
import 'labels.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key, required this.session});
  final Session session;
  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late Future<List<Booking>> _future;

  /// الحجوزات التي قُيّمت. القاعدة تمنع تقييم الحجز مرّتين بقيد فريد، فإظهار
  /// الزرّ بعد التقييم يَعِد بما سيرفضه الخادم.
  Set<String> _reviewed = {};

  /// الحجوزات التي لها نزاعٌ مفتوح، ونزاعُ كلٍّ منها.
  ///
  /// تُقرأ مع الحجوزات لا عند الضغط: الزرّ يجب أن يقول «متابعة النزاع» لمن
  /// فتح واحداً — لا أن يعده بفتح ثانٍ ثم يرفضه شيء.
  Map<String, Dispute> _disputes = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Booking>> _load() async {
    final id = widget.session.appUserId;
    if (id == null) return const [];
    final rows = await Api.myBookings(id);
    final done = rows.where((b) => b.status == BookingStatus.completed).map((b) => b.id).toList();
    _reviewed = await Api.reviewedBookingIds(done);
    try {
      final disputes = await Api.myDisputes();
      _disputes = {
        for (final d in disputes)
          if (d.bookingId != null) d.bookingId!: d,
      };
    } catch (_) {
      // النزاعات زينةٌ على هذه الشاشة: تعذُّر قراءتها لا يمنع عرض الحجوزات.
      _disputes = {};
    }
    return rows;
  }

  void _reload() => setState(() {
    _future = _load();
  });

  /// يفتح شاشةَ التفصيل — وهي التي تحمل الأفعالَ الآن.
  ///
  /// **ولا تُعاد القراءةُ إلّا إن تغيّر شيء.** الشاشةُ تعود بـ`true` حين
  /// يقع دفعٌ أو إلغاءٌ أو تقييمٌ أو نزاع؛ ومن فتح ورجع لم يغيّر شيئاً،
  /// وقراءةٌ بلا سببٍ ومضةٌ في الشاشة وطلبٌ على الشبكة.
  Future<void> _open(Booking b) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookingDetailScreen(
          booking: b,
          session: widget.session,
          reviewed: _reviewed.contains(b.id),
          dispute: _disputes[b.id],
        ),
      ),
    );
    if (changed == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Booking>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          // هيكلٌ بشكل بطاقات الحجز لا دوّارةٌ في بياض.
          return const SkeletonList(rows: 3);
        }
        if (snap.hasError) {
          return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
        }
        final rows = snap.data ?? const <Booking>[];
        if (rows.isEmpty) {
          return EmptyBlock(
            title: tr('لا حجوزات بعد'),
            description: tr('ابدأ من «استكشف» واختر أول خدمة لعرسك.'),
          );
        }
        // **ملخّصٌ قبل التفاصيل.** من فتح «حجوزاتي» وعنده ستّةُ حجوزاتٍ يقرأ
        // بطاقةً بطاقةً ليعرف كم بقي وأيُّها أقرب. وهي البطاقةُ نفسها التي في
        // الرئيسية — يعرفها قبل أن يقرأها.
        final summary = BookingsSummary.of(rows);

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              Space.lg, glassHeaderTop(context), Space.lg, glassNavSpace),
            // زائدٌ واحد: الملخّصُ في الصدر ثمّ الحجوزات.
            itemCount: rows.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: Space.md),
            itemBuilder: (context, i) {
              if (i == 0) {
                return BigHeroCard(
                  // طَفليٌّ محروق — لونُ «حجوزاتي» في الرئيسية نفسه.
                  colors: const [Color(0xFFA3521A), Color(0xFF6B3208)],
                  icon: Icons.event_available_rounded,
                  title: tr('حجوزاتي'),
                  headline: summary.count == 0
                      ? tr('لا حجوزات قادمة')
                      : formatCount(summary.count, bookingForms),
                  subtitle: summary.next == null
                      ? tr('حجوزاتك السابقة محفوظة أدناه')
                      : trf('أقربها {0} · {1}', [
                          formatDate(summary.next!.eventDate),
                          summary.next!.providerName,
                        ]),
                  footer: summary.count == 0
                      ? tr('ابدأ من «استكشف» واحجز خدمتك القادمة')
                      : [
                          if (summary.confirmed > 0) trf('مؤكّد {0}', ['${summary.confirmed}']),
                          if (summary.pending > 0) trf('بانتظار المزوّد {0}', ['${summary.pending}']),
                        ].join(' · '),
                  // **ولا ضغطةَ لها هنا:** هي في الشاشة التي تشير إليها،
                  // وبطاقةٌ تفتح ما هو مفتوحٌ أصلاً تُعلّم المستخدم أنّ ضغطها
                  // لا يفعل شيئاً.
                  onTap: null,
                );
              }
              final b = rows[i - 1];
              // **وبطاقةٌ تُفتح لا استمارةٌ في قائمة.** كانت تحمل أفعالَها
              // كلَّها أزراراً — تدفع وتُلغي وتقيّم وتفتح نزاعاً — فطالت حتى
              // صارت القائمةُ سلسلةَ استمارات. ونُقلت إلى شاشة التفصيل بطلب
              // صاحب المنصّة، فبقي هنا ما يُقرأ بالعين: أين وصل، وكم، ومتى.
              return FadeSlideIn(
                index: i,
                child: BookingCard(booking: b, onTap: () => _open(b)),
              );
            },
          ),
        );
      },
    );
  }
}

/// بطاقةُ الحجز في «حجوزاتي» — على هيئة بطاقة رأس الخطّة.
///
/// ── لماذا تشبه بطاقةَ الخطّة ───────────────────────────────────────────────
///
/// اختار صاحبُ المنصّة أن تُصنع لها «نفسُ الشيء الذي صُنع في خطة العرس»:
/// صورةٌ إلى جانب لوح نصٍّ فاتح، والتاريخُ في قرص، وعدٌّ تنازليٌّ ذهبيٌّ
/// **داخلَ جملته**، ثمّ شريطُ تقدّمٍ بحلقته. **والشريطُ هنا شريطُ الدفع**:
/// كم دُفع من ثمن الحجز — وهو ما يُسأل عنه في هذه الشاشة.
///
/// ── وما بقي كما كان ────────────────────────────────────────────────────────
///
/// **مراحلُ الحجز باقيةٌ تحت الشريط** باختياره: «أين وصل حجزي؟» يُقرأ بلا
/// فتح. وبقيت البطاقةُ تُفتح بالضغط، وبقي رقمُ الحجز في ذيلها — فهو الذي
/// يُقال للمزوّد في الهاتف.
class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, this.onTap});

  final Booking booking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final ratio = b.totalPrice > 0
        ? (b.paidAmount / b.totalPrice).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final left = b.totalPrice - b.paidAmount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              key: ValueKey('booking-card-${b.id}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // **ولا ارتفاعَ ثابتٌ للرأس.** خطُّ الجهاز الكبيرُ يُطيل
                // العنوانَ والقرصَ والعدَّ، فارتفاعٌ مكتوبٌ يفيض بسبعةٍ
                // وعشرين بكسلاً — وقد فاض. فيُؤخذ الارتفاعُ من النصّ، ويُحدّ
                // من أسفلَ وحدَه لئلّا تقصر الصورةُ حين يقصر العنوان.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 58,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 150),
                          child: _Head(booking: b),
                        ),
                      ),
                      Expanded(
                        flex: 42,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // **وموضعُ الصورة محجوزٌ من أوّل رسمة** — ومن لم
                            // تُشغَّل قاعدتُه، أو حجز خدمةً بلا صور، يرى
                            // موضعاً هادئاً ولا تسقط بطاقةٌ لنقص صورة.
                            Container(
                              color: AppColors.surface2,
                              child: MediaThumb(
                                url: Api.mediaUrl(b.coverPath),
                                icon: Icons.photo_camera_back_outlined,
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 8,
                              left: 8,
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: _Ribbon(
                                  bookingStatusLabel(b.status),
                                  colour: bookingStatusColor(b.status),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.hairline),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payments_outlined,
                              size: 15, color: AppColors.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              trf('{0} من {1}', [
                                formatMoney(b.paidAmount),
                                formatMoney(b.totalPrice),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                                fontFamilyFallback: arabicFallback,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                key: ValueKey('paid-bar-${b.id}'),
                                value: ratio,
                                minHeight: 8,
                                backgroundColor: AppColors.surface2,
                                valueColor:
                                    const AlwaysStoppedAnimation(AppColors.accent),
                              ),
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          PercentRing(
                            key: ValueKey('paid-ring-${b.id}'),
                            value: ratio,
                            label: trf('{0}٪', ['${(ratio * 100).round()}']),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // **وكلاهما يَضيق ولا يفيض.** بخطّ الجهاز الكبير طال
                      // السطرُ أربعةً وأربعين بكسلاً خارجَ البطاقة — وقد فاض.
                      // فلكلٍّ نصيبُه من العرض، ويُقصّ ما زاد.
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Muted(
                              left <= 0
                                  ? tr('سُدّد كاملاً')
                                  : trf('بقي {0}', [formatMoney(left)]),
                              size: 11,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          // رقمُ الحجز — وهو الذي يُقال للمزوّد في الهاتف.
                          Flexible(
                            flex: 2,
                            child: Text(
                              b.reference,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.muted),
                            ),
                          ),
                          // **وسهمٌ يقول إنّها تُفتح** — اختاره صاحبُ المنصّة:
                          // الانخفاضُ تحت الإصبع لا يُعلم إلّا بعد أن يُجرَّب.
                          const SizedBox(width: Space.xs),
                          const Icon(Icons.chevron_right,
                              size: 18, color: AppColors.muted),
                        ],
                      ),
                      const SizedBox(height: Space.md),
                      BookingStages(stages: bookingStages(b)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// لوحُ نصّ البطاقة: الخدمةُ والمزوّدُ والموعدُ والعدُّ التنازلي.
class _Head extends StatelessWidget {
  const _Head({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            b.serviceTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontFamilyFallback: arabicFallback,
            ),
          ),
          const SizedBox(height: 3),
          Muted(b.providerName, size: 11.5, maxLines: 1),
          const SizedBox(height: 7),
          _Pill(
            b.eventTime == null
                ? formatDate(b.eventDate)
                : '${formatDate(b.eventDate)} · ${formatTime(b.eventTime)}',
          ),
          const SizedBox(height: 8),
          // **والجملةُ من `countdownLabel`** — بصيغة العدد العربيّة، ويُكبَّر
          // ما كان رقماً فيها. ولا يُركَّب نصٌّ ثانٍ في الشاشة.
          BigNumberIn(countdownLabel(daysUntil(b.eventDate))),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 12, color: AppColors.muted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
            ),
          ],
        ),
      );
}

/// شريطٌ فوق الصورة — أبيضُ نصفُ شفّافٍ ليُقرأ على أيّ صورةٍ كانت.
class _Ribbon extends StatelessWidget {
  const _Ribbon(this.label, {required this.colour});
  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: colour,
            fontFamilyFallback: arabicFallback,
          ),
        ),
      );
}
