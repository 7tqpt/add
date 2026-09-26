// شاشةُ تفصيلِ الحجز — الخطواتُ والمبالغُ والعنوانُ والأفعال.
//
// ── لماذا وُجدت ───────────────────────────────────────────────────────────
//
// شكا صاحبُ المنصّة أنّ «البطاقات غير قابلة للضغط وتطبيقٌ غير تفاعليّ».
// وبطاقةُ «حجوزاتي» لم تكن لها وجهةٌ أصلاً: كانت تحمل أفعالَها كلَّها
// أزراراً في أسفلها — تدفع وتُلغي وتقيّم وتفتح نزاعاً — فطالت حتى صارت
// القائمةُ سلسلةَ استمارات، ولم يبقَ للضغطة شيءٌ تفتحه.
//
// فاختار أن تُبنى الشاشة، وأن **تُنقل إليها الأفعال** فتصير البطاقةُ ملخّصاً
// هادئاً يُفتح. وهذا الملفُّ هو ما نُقل.
//
// ── وشريطٌ ثابتٌ أسفلَها ─────────────────────────────────────────────────
//
// اختار (ب) من شكلين: الفعلُ الأوّل — الدفعُ — في شريطٍ لا ينزل مع الصفحة،
// ومعه المبلغُ الذي سيُدفع. **والسببُ أنّ الصفحةَ طويلة**: مراحلُ ومبالغُ
// وتفاصيل، ومن نزل إلى آخرها ليدفع نسي كم يدفع. والباقي من الأفعال في
// آخرها: الإلغاءُ والنزاعُ لا يُطلبان في العجلة.
//
// ── وما تعود به ─────────────────────────────────────────────────────────
//
// `true` إن تغيّر شيءٌ يمسّ القائمة (دفعٌ أو إلغاءٌ أو تقييمٌ أو نزاع)، فتُعيد
// القائمةُ قراءتَها. **ولا تُعاد القراءةُ لمجرّد الفتح**: من فتح ورجع لم
// يغيّر شيئاً، وقراءةٌ بلا سببٍ ومضةٌ في الشاشة وطلبٌ على الشبكة.
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/booking_stages.dart';
import '../ui/kit.dart';
import '../ui/map_open.dart';
import 'disputes.dart';
import 'labels.dart';
import 'payment.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({
    super.key,
    required this.booking,
    required this.session,
    this.reviewed = false,
    this.dispute,
  });

  final Booking booking;
  final Session session;

  /// هل قُيّم هذا الحجز؟ — القاعدةُ تمنع تقييمَه مرّتين بقيدٍ فريد، فإظهارُ
  /// الزرّ بعده يَعِد بما سيرفضه الخادم.
  final bool reviewed;

  /// نزاعُه المفتوح إن كان — فيقول الزرُّ «متابعة» لا «فتح».
  final Dispute? dispute;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  // **ولا تُنسخ الوسائطُ في حقولٍ تُهيَّأ مرّةً.** `late final` يُهيَّأ عند
  // أوّل قراءة، فلو أُعيد بناءُ الشاشة بحجزٍ آخرَ بقيت على الأوّل — تعرض
  // حجزاً وتفعل في غيره. **وقد وقع ذلك فعلاً وكشفه اختبار.** فتُقرأ من
  // `widget` أبداً.
  Booking get _b => widget.booking;

  /// نزاعُ هذا الحجز — **وحالٌ محلّيّةٌ لا وسيطٌ يُقرأ**.
  ///
  /// **ولولا ذلك لَما انقلب الزرُّ بعد فتحه من هنا**: الوسيطُ يأتي من
  /// القائمة وقت الفتح، ومن فتح نزاعَه في هذه الشاشة يبقى يقرأ «عندي مشكلة
  /// في هذا الحجز» فيظنّ أنّ فتحَه لم يقع فيفتح ثانياً. **وقد وقع ذلك
  /// وكشفه اختبار.**
  late Dispute? _dispute = widget.dispute;

  /// وهذه وحدَها حالٌ محلّيّة: تصير `true` بعد أن يُرسَل التقييمُ من هنا،
  /// فيختفي زرُّه بلا انتظار قراءةٍ جديدة.
  late bool _reviewed = widget.reviewed;

  @override
  void didUpdateWidget(BookingDetailScreen old) {
    super.didUpdateWidget(old);
    // ولو جاء الجوابُ من فوقُ أنّه قُيّم أو أنّ له نزاعاً، أُخذ به.
    if (widget.reviewed != old.reviewed) _reviewed = widget.reviewed;
    if (widget.dispute != old.dispute) _dispute = widget.dispute;
  }

  /// هل وقع ما يُلزم القائمةَ بإعادة القراءة؟
  bool _changed = false;

  bool _busy = false;

  /// المتبقّي بعد الخصم وما دُفع — **للعرض وحدَه**.
  ///
  /// الخادمُ يحسبه من جديدٍ عند الإرسال ولا يقبل رقماً من التطبيق: لو قُبل
  /// لأمكن دفعُ ريالٍ واحدٍ في قاعة.
  num get _remaining {
    final due = _b.totalPrice - _b.discountAmount - _b.paidAmount;
    return due < 0 ? 0 : due;
  }

  Future<void> _pay() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          booking: _b,
          kind: _b.paidAmount < _b.depositAmount ? 'deposit' : 'balance',
        ),
      ),
    );
    // عند العودة: قد يكون أُبلغ بحوالةٍ أو أُكّدت، فتتغيّر أرقامُ الحجز.
    if (mounted) setState(() => _changed = true);
  }

  Future<void> _cancel() async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('إلغاء الحجز')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // المبلغ المستردّ يحسبه الخادم من سلّم الإلغاء، فلا يُوعَد هنا برقم.
            Text(
              tr('ما يُستردّ لك يُحسب حسب سياسة الإلغاء وقُرب الموعد. '
                  'الإلغاء لا رجعة فيه.'),
              style: const TextStyle(height: 1.7),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: reason,
              decoration: InputDecoration(labelText: tr('السبب (اختياري)')),
            ),
          ],
        ),
        // أزرار الحوار نصّية لا مملوءة: نمط `FilledButton` في هذا التطبيق
        // يفرض ارتفاعاً وعرضاً كاملين، فيبتلع الصفَّ ويصير الفعل المدمّر أضخم
        // ما في الشاشة. والأحمر يكفي للدلالة على خطورته.
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('تراجع')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.critical),
            child: Text(tr('إلغاء الحجز')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await Api.cancelBooking(_b.id, reason: reason.text.trim());
      if (!mounted) return;
      showMessage(context, tr('أُلغي الحجز.'));
      // **وتُغلق الشاشة بعده**: حجزٌ أُلغي لا فعلَ فيه، والبقاءُ في صفحته
      // يعرض أزراراً سيرفضها الخادم.
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review() async {
    final result = await showModalBottomSheet<({int rating, String comment})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ReviewSheet(booking: _b),
    );
    if (result == null) return;

    setState(() => _busy = true);
    try {
      await Api.submitReview(_b.id, result.rating, result.comment);
      if (!mounted) return;
      showMessage(context, tr('شكراً — نُشر تقييمك.'));
      setState(() {
        _reviewed = true;
        _changed = true;
      });
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDispute() async {
    final existing = _dispute;
    if (existing != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DisputeScreen(dispute: existing, session: widget.session),
        ),
      );
      if (mounted) setState(() => _changed = true);
      return;
    }
    final opened = await openDisputeSheet(context, _b);
    if (!opened || !mounted) return;
    showMessage(context, tr('فُتح النزاع — تنظر فيه الإدارة وتصلك ردودها هنا.'));
    setState(() => _changed = true);

    // **ويُقرأ النزاعُ بعد فتحه ليُعرف صفُّه.** الورقةُ تقول «فُتح» ولا
    // تعطي الصفّ، والزرُّ يحتاجه ليفتح خيطَه. وتعذُّرُ القراءة لا يُفسد
    // شيئاً: الزرُّ يبقى كما كان ويُقرأ الصفُّ عند العودة إلى القائمة.
    try {
      final all = await Api.myDisputes();
      if (!mounted) return;
      for (final d in all) {
        if (d.bookingId == _b.id) {
          setState(() => _dispute = d);
          break;
        }
      }
    } catch (_) {
      // تُترك.
    }
  }

  @override
  Widget build(BuildContext context) {
    final payLabel = bookingPayLabel(_b);
    return PopScope(
      // **والنتيجةُ تُعاد ولو رجع بزرّ النظام.** من دفع ثمّ سحب للخلف يجب أن
      // تُحدَّث قائمتُه كما لو ضغط سهمَ الرجوع.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(tr('تفاصيل الحجز'))),
        body: ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            _head(),
            const SizedBox(height: Space.md),
            _stages(),
            const SizedBox(height: Space.md),
            _amounts(),
            const SizedBox(height: Space.md),
            _details(),
            const SizedBox(height: Space.md),
            ..._slowActions(),
          ],
        ),
        bottomNavigationBar: payLabel == null ? null : _payBar(payLabel),
      ),
    );
  }

  // ── الرأس ───────────────────────────────────────────────────────────────
  Widget _head() => HeroCard(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _b.serviceTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentInk,
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              StatusBadge(
                bookingStatusLabel(_b.status),
                color: bookingStatusColor(_b.status),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _b.providerName,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.accentInk.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  _b.eventTime == null
                      ? formatDate(_b.eventDate)
                      : '${formatDate(_b.eventDate)} · ${formatTime(_b.eventTime)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentInk,
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              // **ورقمُ الحجز من اليسار إلى اليمين**: «BK-2026-000318» تقذف
              // خوارزميةُ البيدي شَرطتَه إلى الطرف الخطأ في سياقٍ عربيّ.
              //
              // **ويَضيق ولا يفيض**: بخطّ الجهاز المضاعَف طال هذا الصفُّ
              // أربعةً وعشرين بكسلاً خارجَ الشاشة — وهو عطبٌ قديمٌ لم يظهر
              // لأنّ الشاشةَ لم تُقَس بخطٍّ كبيرٍ قطّ.
              Flexible(
                child: Text(
                  _b.reference,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.accentInk.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      );

  // ── المراحل ─────────────────────────────────────────────────────────────
  //
  // **وبلا زرٍّ فيها هنا.** الزرُّ في الشريط الثابت أسفلَ الشاشة، وزرّان
  // لفعلٍ واحدٍ في صفحةٍ واحدةٍ يجعل أحدَهما يبدو غيرَ الآخر.
  Widget _stages() => AppCard(
        children: [
          SectionTitle(tr('أين وصل حجزك')),
          const SizedBox(height: Space.md),
          BookingStages(stages: bookingStages(_b)),
        ],
      );

  // ── المبالغ ─────────────────────────────────────────────────────────────
  Widget _money(String label, String value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(child: Muted(label, size: 12.5)),
            const SizedBox(width: Space.sm),
            // وكذلك المبلغُ يَضيق: «850,000 ر.ي» بخطٍّ مضاعَفٍ يفيض بخمسةٍ.
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: strong ? 15 : 13.5,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                  color: strong ? AppColors.accent : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _amounts() => AppCard(
        children: [
          SectionTitle(tr('المبالغ')),
          const SizedBox(height: Space.md),
          _money(tr('إجمالي الخدمة'), formatMoney(_b.totalPrice)),
          // **والخصمُ لا يُذكر إن لم يكن.** سطرٌ بصفرٍ يُقرأ خصماً لم يصل.
          if (_b.discountAmount > 0)
            _money(
              _b.couponCode.isEmpty
                  ? tr('الخصم')
                  : trf('خصمُ الكود {0}', [_b.couponCode]),
              '− ${formatMoney(_b.discountAmount)}',
            ),
          _money(tr('العربون المطلوب'), formatMoney(_b.depositAmount)),
          const Divider(height: Space.lg),
          _money(tr('المدفوع'), formatMoney(_b.paidAmount), strong: true),
          _money(tr('المتبقّي عند التسليم'), formatMoney(_remaining)),
        ],
      );

  // ── تفاصيل المناسبة ─────────────────────────────────────────────────────
  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: Space.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.muted),
            const SizedBox(width: Space.sm),
            SizedBox(width: 78, child: Muted(label, size: 12)),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _details() {
    final point = _b.point;
    return AppCard(
      children: [
        SectionTitle(tr('تفاصيل المناسبة')),
        const SizedBox(height: Space.md),
        _row(
          Icons.event_outlined,
          tr('التاريخ'),
          _b.eventTime == null
              ? formatDate(_b.eventDate)
              : '${formatDate(_b.eventDate)} · ${formatTime(_b.eventTime)}',
        ),
        _row(Icons.groups_outlined, tr('الضيوف'), formatNumber(_b.guestsCount)),
        if (_b.address.isNotEmpty)
          _row(Icons.place_outlined, tr('العنوان'), _b.address),
        if (_b.createdAt.isNotEmpty)
          _row(
            Icons.schedule_outlined,
            tr('حُجز في'),
            formatDate(_b.createdAt.split('T').first),
          ),
        // **ولا زرَّ خريطةٍ لمن لا نقطةَ له**: زرٌّ يفتح خريطةً على لا شيء
        // أسوأُ من غيابه.
        if (point != null) ...[
          const SizedBox(height: Space.xs),
          OutlinedButton.icon(
            key: const ValueKey('booking-map'),
            onPressed: () => openMap(context, point),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: Text(tr('افتح الموقع على الخريطة')),
          ),
        ],
      ],
    );
  }

  // ── الأفعالُ التي لا تُطلب في عجلة ──────────────────────────────────────
  List<Widget> _slowActions() {
    final can = !_busy;
    return [
      // الإلغاء متاحٌ ما دام الحجز قائماً؛ والقاعدة ترفضه بعد التنفيذ، فإخفاؤه
      // هنا يوافق ما ستقوله هناك.
      if (_b.status == BookingStatus.pendingProvider ||
          _b.status == BookingStatus.confirmed) ...[
        OutlinedButton(
          key: const ValueKey('booking-cancel'),
          onPressed: can ? _cancel : null,
          child: Text(tr('إلغاء الحجز')),
        ),
        const SizedBox(height: Space.sm),
      ],
      if (_b.status == BookingStatus.completed && !_reviewed) ...[
        FilledButton.icon(
          key: const ValueKey('booking-review'),
          onPressed: can ? _review : null,
          icon: const Icon(Icons.star_rounded, size: 20),
          label: Text(tr('قيّم الخدمة')),
        ),
        const SizedBox(height: Space.sm),
      ],
      // النزاع متاحٌ على كل حجزٍ تجاوز الانتظار.
      //
      // والملغى والمرفوض منها عمداً: أكثرُ ما يُختلف عليه مالٌ دُفع ولم يُعَد
      // بعد إلغاء — ومن أُغلق عليه هذا الباب لم يبقَ له إلّا تذكرةُ دعمٍ
      // عامّة أو ترك حقّه.
      if (_b.status != BookingStatus.pendingProvider)
        TextButton.icon(
          key: const ValueKey('booking-dispute'),
          onPressed: can ? _openDispute : null,
          icon: Icon(
            _dispute != null
                ? Icons.gavel_rounded
                : Icons.report_gmailerrorred_outlined,
            size: 19,
          ),
          style: TextButton.styleFrom(
            foregroundColor: _dispute != null ? AppColors.accent : AppColors.muted,
          ),
          label: Text(
            _dispute != null ? tr('متابعة النزاع') : tr('عندي مشكلة في هذا الحجز'),
          ),
        ),
    ];
  }

  // ── الشريطُ الثابت ──────────────────────────────────────────────────────
  //
  // **والمبلغُ فيه لا الزرُّ وحدَه.** من نزل إلى آخر صفحةٍ فيها ثلاثةُ أقسامٍ
  // من أرقامٍ نسي كم يدفع، وزرٌّ يقول «ادفع» بلا رقمٍ يُضغط على الظنّ.
  Widget _payBar(String label) => Container(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Muted(tr('المطلوب الآن'), size: 12)),
                  Text(
                    formatMoney(
                      _b.paidAmount < _b.depositAmount
                          ? _b.depositAmount - _b.paidAmount
                          : _remaining,
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              FilledButton(
                key: const ValueKey('booking-pay'),
                onPressed: _busy ? null : _pay,
                child: Text(label),
              ),
            ],
          ),
        ),
      );
}

/// ورقة التقييم — نجومٌ وتعليق.
///
/// النجوم أيقونات لا أحرف: «★» خارج تغطية خطوط الواجهة فيظهر مربّعاً فارغاً.
///
/// **وعامّةٌ لا خاصّة**: نُقلت من `my_bookings.dart` حين انتقل التقييمُ إلى
/// شاشة التفصيل، وتبقى هنا مع الفعل الذي يستدعيها.
class ReviewSheet extends StatefulWidget {
  const ReviewSheet({super.key, required this.booking});
  final Booking booking;

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
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
            SectionTitle(trf('كيف كانت {0}؟', [widget.booking.serviceTitle])),
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
                    tooltip: trf('{0} من 5', ['$i']),
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
              decoration: InputDecoration(
                labelText: tr('تعليقك (اختياري)'),
                hintText: tr('ما الذي أعجبك؟ وما الذي كان يمكن أن يكون أفضل؟'),
              ),
            ),
            const SizedBox(height: Space.lg),
            FilledButton(
              onPressed: () => Navigator.of(context)
                  .pop((rating: _rating, comment: _comment.text.trim())),
              child: Text(tr('إرسال التقييم')),
            ),
            const SizedBox(height: Space.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('لاحقاً')),
            ),
          ],
        ),
      ),
    );
  }
}
