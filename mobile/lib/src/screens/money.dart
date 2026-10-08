// فواتيري.
//
// وكانت هنا «مستحقّاتي» للمزوّد إلى جانبها، ثمّ صارت «تسويات سابقة» داخل
// «رصيد فرحتي» (`provider_wallet.dart`) — بندان لمالٍ واحدٍ كانا يُحيّران.
import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart' show messageOf;
import '../ui/kit.dart';
import 'booking_detail.dart';

/// فواتير العميل — إيصالُ ما دفعه.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key, required this.session});

  final Session session;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  Future<List<Invoice>>? _future;

  /// الفاتورةُ التي يُجلب حجزُها الآن — فتقول بطاقتُها إنّها تعمل.
  ///
  /// جلبُ الحجز طلبٌ على الشبكة، وضغطةٌ لا يتبعها شيءٌ في الشاشة تُعاد
  /// ثلاثاً — وهي الشكوى نفسُها التي بدأت هذه الجولة.
  String? _opening;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = Api.myInvoices();
    });
  }

  /// يفتح حجزَ الفاتورة.
  ///
  /// **والفاتورةُ لا تحمل حجزَها، تحمل معرّفَه.** فيُقرأ من «حجوزاتي»: هي
  /// القراءةُ نفسُها التي تبني تلك الشاشة، ولا دالّةَ في `Api` تجلب حجزاً
  /// واحداً بمعرّفه.
  ///
  /// **وقد لا يُوجد**: «حجوزاتي» تقرأ صفحةً محدودة، وفاتورةٌ قديمةٌ قد يقع
  /// حجزُها خارجَها. فيُقال ذلك ولا تُفتح شاشةٌ فارغة.
  Future<void> _open(Invoice invoice) async {
    final userId = widget.session.appUserId;
    if (userId == null || _opening != null) return;
    setState(() => _opening = invoice.id);
    try {
      final rows = await Api.myBookings(userId);
      Booking? booking;
      for (final b in rows) {
        if (b.id == invoice.bookingId) booking = b;
      }
      if (!mounted) return;
      if (booking == null) {
        showMessage(context, tr('لم يعد هذا الحجز في قائمة حجوزاتك.'));
        return;
      }

      // ما تحتاجه شاشةُ التفصيل لتقول الصوابَ في أزرارها — وفشلُ أيٍّ منهما
      // لا يمنع الفتح: الحجزُ يُعرض، وزرٌّ يظهر لمن قيّم أهونُ من شاشةٍ
      // لا تُفتح.
      var reviewed = false;
      if (booking.status == BookingStatus.completed) {
        try {
          reviewed = (await Api.reviewedBookingIds([booking.id])).contains(booking.id);
        } catch (_) {}
      }
      Dispute? dispute;
      try {
        for (final d in await Api.myDisputes()) {
          if (d.bookingId == booking.id) dispute = d;
        }
      } catch (_) {}

      if (!mounted) return;
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => BookingDetailScreen(
            booking: booking!,
            session: widget.session,
            reviewed: reviewed,
            dispute: dispute,
          ),
        ),
      );
      // دفعةٌ أو إلغاءٌ يغيّران الفاتورة — فتُعاد قراءتُها.
      if (changed == true && mounted) _load();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Invoice>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingBlock();
        }
        if (snapshot.hasError) {
          return ErrorBlock(message: messageOf(snapshot.error!), onRetry: _load);
        }
        final list = snapshot.data ?? <Invoice>[];
        if (list.isEmpty) {
          return EmptyBlock(
            title: tr('لا فواتير بعد'),
            description: tr('تصدر الفاتورة حين يؤكّد مقدّم الخدمة حجزك.'),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _InvoiceCard(
                invoice: list[i],
                busy: _opening == list[i].id,
                // **ولا تُفتح فاتورةٌ لا مرجعَ لها.** قاعدةٌ أقدمُ لا تُرجع
                // المرجع، وسهمٌ فوق بطاقةٍ لا تُفتح يَعِد بما لا يقع.
                onTap: list[i].bookingReference.isEmpty ? null : () => _open(list[i]),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// بطاقةُ فاتورة — **وتقول عن أيّ حجزٍ هي**.
///
/// شكا صاحبُ المنصّة أنّ الفاتورةَ لا يُعرف حجزُها ولا تُضغط، واختار من
/// ثلاثٍ: أن تقول رقمَ الحجز وحدَه (BK-…) وأن تفتحه الضغطةُ — فالرقمُ هو
/// ما يُعرف به الحجزُ في «حجوزاتي» وفي المحادثة مع مقدّم الخدمة.
class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, this.onTap, this.busy = false});

  final Invoice invoice;
  final VoidCallback? onTap;

  /// هل يُجلب حجزُها الآن؟
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: busy ? null : onTap,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                invoice.number,
                // رقمٌ لاتينيٌّ في نصٍّ عربي: يُقلب اتّجاهُه وحده وإلّا قُرئ
                // معكوساً — و«INV-2026-A1B2» ليس نصّاً عربياً.
                textDirection: TextDirection.ltr,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            // فرجةٌ بين الرقم والشارة: رقمُ الفاتورة يملأ ما أُعطي، فكانت
            // الشارةُ تلتصق به حتى يُقرآ كلمةً واحدة.
            const SizedBox(width: Space.sm),
            StatusBadge(
              invoice.status == 'paid' ? tr('مدفوعة') : tr('صادرة'),
              color: invoice.status == 'paid' ? AppColors.good : AppColors.ink2,
            ),
          ],
        ),
        SizedBox(height: 8),
        if (invoice.bookingReference.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Muted(tr('الحجز')),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // **ورقمُ الحجز من اليسار إلى اليمين**: «BK-2026-000318»
                    // تقذف خوارزميةُ البيدي شَرطتَه إلى الطرف الخطأ في سياقٍ
                    // عربيّ، فيُقرأ الرقمُ معكوساً.
                    Text(
                      invoice.bookingReference,
                      key: const ValueKey('invoice-booking-reference'),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: Space.xs),
                      // والسهمُ يقول إنّها تُفتح قبل أن تُجرَّب — وينقلب مع
                      // اللغة بنفسه (`matchTextDirection`)، فلا تُسأل الجهةُ
                      // وإلّا وقع انعكاسان فأشار إلى الخلف. وذلك مقولٌ في
                      // `CardTitleBar`.
                      busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppColors.muted,
                            ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        KeyValue(tr('الإجمالي'), formatMoney(invoice.total)),
        KeyValue(tr('صدرت في'), formatDay(invoice.issuedAt)),
      ],
    );
  }
}
