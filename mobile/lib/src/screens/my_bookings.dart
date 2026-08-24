import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'disputes.dart';
import 'labels.dart';
import 'payment.dart';

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
  String? _busyId;

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

  Future<void> _cancel(Booking b) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الحجز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // المبلغ المستردّ يحسبه الخادم من سلّم الإلغاء، فلا يُوعَد هنا برقم.
            const Text(
              'ما يُستردّ لك يُحسب حسب سياسة الإلغاء وقُرب الموعد. '
              'الإلغاء لا رجعة فيه.',
              style: TextStyle(height: 1.7),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'السبب (اختياري)'),
            ),
          ],
        ),
        // أزرار الحوار نصّية لا مملوءة: نمط `FilledButton` في هذا التطبيق
        // يفرض ارتفاعاً وعرضاً كاملين، فيبتلع الصفَّ ويصير الفعل المدمّر أضخم
        // ما في الشاشة. والأحمر يكفي للدلالة على خطورته.
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.critical),
            child: const Text('إلغاء الحجز'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyId = b.id);
    try {
      await Api.cancelBooking(b.id, reason: reason.text.trim());
      if (!mounted) return;
      showMessage(context, 'أُلغي الحجز.');
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _review(Booking b) async {
    final result = await showModalBottomSheet<({int rating, String comment})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReviewSheet(booking: b),
    );
    if (result == null) return;

    setState(() => _busyId = b.id);
    try {
      await Api.submitReview(b.id, result.rating, result.comment);
      if (!mounted) return;
      showMessage(context, 'شكراً — نُشر تقييمك.');
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _pay(Booking b) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          booking: b,
          kind: b.paidAmount < b.depositAmount ? 'deposit' : 'balance',
        ),
      ),
    );
    // عند العودة: قد يكون أُبلغ بحوالةٍ أو أُكّدت، فتتغيّر أرقام البطاقة.
    if (mounted) _reload();
  }

  Future<void> _dispute(Booking b) async {
    final existing = _disputes[b.id];
    if (existing != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DisputeScreen(dispute: existing, session: widget.session),
        ),
      );
      _reload();
      return;
    }
    final opened = await openDisputeSheet(context, b);
    if (!opened || !mounted) return;
    showMessage(context, 'فُتح النزاع — تنظر فيه الإدارة وتصلك ردودها هنا.');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Booking>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
        if (snap.hasError) {
          return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
        }
        final rows = snap.data ?? const <Booking>[];
        if (rows.isEmpty) {
          return const EmptyBlock(
            title: 'لا حجوزات بعد',
            description: 'ابدأ من «استكشف» واختر أول خدمة لعرسك.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              Space.lg, glassHeaderTop(context), Space.lg, glassNavSpace),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.md),
            itemBuilder: (context, i) {
              final b = rows[i];
              return AppCard(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الإجمالي ${formatMoney(b.totalPrice)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.ink),
                      ),
                      Muted(
                        b.paidAmount > 0 ? 'مدفوع ${formatMoney(b.paidAmount)}' : 'لم يُدفع بعد',
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
                  // الدفع أوّل ما يُعرض بعد الأرقام: الحجز لا يصير حجزاً
                  // حتى يصل عربونه، ومن حجز اليوم لا يعرف أين يدفع.
                  //
                  // والمستحقُّ يُحسب هنا للعرض وحده — والخادم يحسبه من جديد
                  // عند الإرسال ولا يقبل رقماً من التطبيق.
                  if ((b.status == BookingStatus.pendingProvider ||
                          b.status == BookingStatus.confirmed) &&
                      b.paidAmount < b.totalPrice) ...[
                    const SizedBox(height: Space.md),
                    FilledButton.icon(
                      onPressed: _busyId == null ? () => _pay(b) : null,
                      icon: const Icon(Icons.account_balance_wallet_outlined, size: 19),
                      label: Text(
                        b.paidAmount < b.depositAmount
                            ? 'ادفع العربون ${formatMoney(b.depositAmount - b.paidAmount)}'
                            : 'أكمل المبلغ ${formatMoney(b.totalPrice - b.paidAmount)}',
                      ),
                    ),
                  ],
                  // الإلغاء متاحٌ ما دام الحجز قائماً؛ والقاعدة ترفضه بعد
                  // التنفيذ، فإخفاؤه هنا يوافق ما ستقوله هناك.
                  if (b.status == BookingStatus.pendingProvider ||
                      b.status == BookingStatus.confirmed) ...[
                    const SizedBox(height: Space.md),
                    OutlinedButton(
                      onPressed: _busyId == null ? () => _cancel(b) : null,
                      child: const Text('إلغاء الحجز'),
                    ),
                  ],
                  if (b.status == BookingStatus.completed && !_reviewed.contains(b.id)) ...[
                    const SizedBox(height: Space.md),
                    FilledButton.icon(
                      onPressed: _busyId == null ? () => _review(b) : null,
                      icon: const Icon(Icons.star_rounded, size: 20),
                      label: const Text('قيّم الخدمة'),
                    ),
                  ],
                  // النزاع متاحٌ على كل حجزٍ تجاوز الانتظار.
                  //
                  // والملغى والمرفوض منها عمداً: أكثرُ ما يُختلف عليه مالٌ
                  // دُفع ولم يُعَد بعد إلغاء — ومن أُغلق عليه هذا الباب لم
                  // يبقَ له إلّا تذكرةُ دعمٍ عامّة أو ترك حقّه.
                  if (b.status != BookingStatus.pendingProvider) ...[
                    const SizedBox(height: Space.sm),
                    TextButton.icon(
                      onPressed: _busyId == null ? () => _dispute(b) : null,
                      icon: Icon(
                        _disputes.containsKey(b.id)
                            ? Icons.gavel_rounded
                            : Icons.report_gmailerrorred_outlined,
                        size: 19,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: _disputes.containsKey(b.id)
                            ? AppColors.accent
                            : AppColors.muted,
                      ),
                      label: Text(
                        _disputes.containsKey(b.id) ? 'متابعة النزاع' : 'عندي مشكلة في هذا الحجز',
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// ورقة التقييم — نجومٌ وتعليق.
///
/// النجوم أيقونات لا أحرف: «★» خارج تغطية خطوط الواجهة فيظهر مربّعاً فارغاً.
class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.booking});
  final Booking booking;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _rating = 5;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, glassNavSpace),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionTitle('كيف كانت ${widget.booking.serviceTitle}؟'),
            const SizedBox(height: Space.xs),
            Muted(widget.booking.providerName),
            const SizedBox(height: Space.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setState(() => _rating = i),
                    // بلا وصفٍ تظهر النجوم في شجرة الدلالات أزراراً بلا اسم،
                    // فلا يعرف قارئ الشاشة أيَّها يضغط.
                    tooltip: '$i من 5',
                    icon: Icon(
                      i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 36,
                      color: i <= _rating ? AppColors.warning : AppColors.hairline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _comment,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'تعليقك (اختياري)',
                hintText: 'ما الذي أعجبك؟ وما الذي كان يمكن أن يكون أفضل؟',
              ),
            ),
            const SizedBox(height: Space.lg),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop((rating: _rating, comment: _comment.text.trim())),
              child: const Text('إرسال التقييم'),
            ),
            const SizedBox(height: Space.sm),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('لاحقاً')),
          ],
        ),
      ),
    );
  }
}
