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
                child: AppCard(
                  key: ValueKey('booking-card-${b.id}'),
                  onTap: () => _open(b),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            b.serviceTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        StatusBadge(
                          bookingStatusLabel(b.status),
                          color: bookingStatusColor(b.status),
                        ),
                        // **وسهمٌ يقول إنّها تُفتح** — اختاره صاحبُ المنصّة:
                        // الانخفاضُ تحت الإصبع لا يُعلم إلّا بعد أن يُجرَّب.
                        const SizedBox(width: Space.xs),
                        const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    Muted(b.providerName),
                    const SizedBox(height: Space.sm),
                    Text(
                      b.eventTime == null
                          ? formatDate(b.eventDate)
                          : '${formatDate(b.eventDate)} · ${formatTime(b.eventTime)}',
                      style: const TextStyle(fontSize: 14, color: AppColors.ink2),
                    ),
                    const SizedBox(height: Space.sm),
                    // لفٌّ لا صفّ: مبلغان بالريال اليمني — سبعةُ أرقامٍ لكلٍّ —
                    // تجاوزا عرض الجوال بخمسين بكسلاً. والقصُّ بالنقاط هنا
                    // **أسوأ من النزول سطراً**: «الإجمالي ١٢٠٠…» رقمٌ مبتور
                    // يُقرأ على أنه المبلغ. فينزل الثاني سطراً حين لا يتّسعان،
                    // ويبقيان في سطرٍ واحدٍ متباعدين حين يتّسعان.
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: Space.md,
                      runSpacing: Space.xs,
                      children: [
                        Text(
                          trf('الإجمالي {0}', [formatMoney(b.totalPrice)]),
                          style: const TextStyle(fontSize: 13, color: AppColors.ink),
                        ),
                        Muted(
                          b.paidAmount > 0 ? trf('مدفوع {0}', [formatMoney(b.paidAmount)]) : tr('لم يُدفع بعد'),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        b.reference,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    BookingStages(stages: bookingStages(b)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
