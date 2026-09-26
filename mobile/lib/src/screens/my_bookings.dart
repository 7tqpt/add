import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import '../ui/media.dart';
import '../ui/motion.dart';
import 'booking_detail.dart';
import 'chat.dart';
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

  /// يفتح المحادثةَ مع مقدّم خدمةِ هذا الحجز ثمّ يدخلها.
  ///
  /// **والفتحُ من القاعدة لا من التطبيق**: الضغطُ مرّتين بسرعةٍ كان سينتج
  /// خيطين لو بحث التطبيقُ ثمّ أنشأ بنفسه، فتنقسم الرسائل بينهما ولا يرى
  /// أحدٌ نصفها. و`api_open_conversation` تأخذ معرّفَ الحجز كذلك، فيُعرف
  /// الخيطُ عن أيّ حجزٍ فُتح.
  Future<void> _message(Booking b) async {
    try {
      final id = await Api.openConversation(b.providerId, bookingId: b.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: id,
            otherName: b.providerName,
            providerId: b.providerId,
            mySide: ChatSide.customer,
          ),
        ),
      );
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    }
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
                return BookingsSummaryCard(summary: summary);
              }
              final b = rows[i - 1];
              // **وبطاقةٌ تُفتح لا استمارةٌ في قائمة.** كانت تحمل أفعالَها
              // كلَّها أزراراً — تدفع وتُلغي وتقيّم وتفتح نزاعاً — فطالت حتى
              // صارت القائمةُ سلسلةَ استمارات. ونُقلت إلى شاشة التفصيل بطلب
              // صاحب المنصّة، فبقي هنا ما يُقرأ بالعين: أين وصل، وكم، ومتى.
              return FadeSlideIn(
                index: i,
                child: BookingCard(
                  booking: b,
                  onTap: () => _open(b),
                  onMessage: () => _message(b),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// بطاقةُ الحجز في «حجوزاتي» — على تصميمٍ أرسله صاحبُ المنصّة.
///
/// ── ما فيها ────────────────────────────────────────────────────────────────
///
/// غلافٌ صغيرٌ في الصدر، وإلى جانبه اسمُ الخدمة ومقدّمُها وشارةُ الحالة، ثمّ
/// خيطٌ فاصل، ثمّ **صفُّ حقائقَ من أربعة**: التاريخُ والوقتُ ورقمُ الحجز
/// والسعر، ثمّ زرّان: «عرض الحجز» و«تواصل مع المزوّد».
///
/// ── وما شيل منها، وبأمرِه ──────────────────────────────────────────────────
///
/// كان فيها **شريطُ الدفع وحلقتُه**، و**العدُّ التنازليُّ** «بقي ٢٨ يوماً»،
/// و**مراحلُ الحجز**. وعُرضت عليه ثلاثُ خلايا: تصميمُه حرفاً، وتصميمُه
/// بالشريط، وتصميمُه بالشريط والمراحل — فاختار «**تُشال كلُّها كما في
/// صورتك**». وكلُّها باقيةٌ في **صفحة الحجز** التي تفتحها البطاقة.
///
/// ── وصفُّ الحقائق أربعةٌ في صفٍّ واحدٍ باختياره ────────────────────────────
///
/// وعُرض عليه أنّ العمودَ على جوالٍ عرضُه ٣٦٠ يصير نحوَ ثمانين بكسلاً، فاختار
/// الصفَّ الواحد. **فتُصغَّر القيمةُ لتُقرأ كاملةً ولا تُقصّ**
/// (`BoxFit.scaleDown`): رقمُ الحجز يُقال للمزوّد في الهاتف، و«BK-2026-0…»
/// لا يُقال.
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    this.onTap,
    this.onMessage,
  });

  final Booking booking;
  final VoidCallback? onTap;

  /// يفتح المحادثةَ مع مقدّم الخدمة — و`null` فلا زرَّ محادثة.
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final b = booking;
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
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            key: ValueKey('booking-card-${b.id}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Head(booking: b),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.hairline),
              const SizedBox(height: 10),
              _Facts(booking: b),
              const SizedBox(height: 12),
              _Actions(booking: b, onTap: onTap, onMessage: onMessage),
            ],
          ),
        ),
      ),
    );
  }
}

/// صدرُ البطاقة: الغلافُ والعنوانُ والمزوّدُ وشارةُ الحالة.
class _Head extends StatelessWidget {
  const _Head({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    // **وارتفاعُ الغلاف يتبع خطَّ الجهاز.** ثابتٌ مكتوبٌ يُقصّ العنوانَ
    // بخطٍّ كبير، و`Image` بارتفاعٍ بلا نهايةٍ داخلَ `IntrinsicHeight` تُخفي
    // البطاقةَ كلَّها — وقد وقع ذلك على جهازٍ حقيقيّ.
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 74,
            height: 58 * scale,
            child: ColoredBox(
              color: AppColors.surface2,
              child: MediaThumb(
                url: Api.mediaUrl(b.coverPath),
                icon: Icons.photo_camera_back_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                b.serviceTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.storefront_outlined,
                      size: 13, color: AppColors.gold),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      b.providerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.gold,
                        fontFamilyFallback: arabicFallback,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatusChip(b.status),
      ],
    );
  }
}

/// شارةُ الحالة — **ولونُها من `bookingStatusColor` لا لونٌ مكتوبٌ هنا**:
/// الحالاتُ ستٌّ، ولونٌ ثانٍ لها يفترق عن لونها في صفحة الحجز.
class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final c = bookingStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(bookingStatusIcon(status), size: 14, color: c),
          const SizedBox(width: 5),
          Text(
            bookingStatusLabel(status),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c,
              fontFamilyFallback: arabicFallback,
            ),
          ),
        ],
      ),
    );
  }
}

/// صفُّ الحقائق الأربع.
class _Facts extends StatelessWidget {
  const _Facts({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Row(
      children: [
        Expanded(
          child: _Fact(
            icon: Icons.calendar_today_rounded,
            label: tr('التاريخ'),
            value: formatDate(b.eventDate),
          ),
        ),
        const _VLine(),
        Expanded(
          child: _Fact(
            icon: Icons.schedule_rounded,
            label: tr('الوقت'),
            value: formatTime(b.eventTime),
          ),
        ),
        const _VLine(),
        Expanded(
          child: _Fact(
            icon: Icons.confirmation_number_outlined,
            label: tr('رقم الحجز'),
            value: b.reference,
            ltr: true,
          ),
        ),
        const _VLine(),
        Expanded(
          child: _Fact(
            icon: Icons.payments_outlined,
            label: tr('السعر'),
            value: formatMoney(b.totalPrice),
          ),
        ),
      ],
    );
  }
}

/// حقيقةٌ واحدة: أيقونةٌ ذهبيّةٌ وعنوانٌ باهتٌ فوق، والقيمةُ تحت.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.ltr = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// رقمُ الحجز لاتينيٌّ يُقرأ من اليسار — وبدونها تُقلب شرطاتُه.
  final bool ltr;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: AppColors.gold),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // **وتُقصّ ولا تُصغَّر.** جُرّب `BoxFit.scaleDown` فخرج رقمُ الحجز
          // بخُمس حجمه — يُقرأ كاملاً ولا يُقرأ. والقصُّ هو ما عُرض على صاحب
          // المنصّة حين اختار الصفَّ الواحد، **والرقمُ كاملاً في صفحة الحجز**.
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: ltr ? TextDirection.ltr : null,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontFamilyFallback: arabicFallback,
            ),
          ),
        ],
      );
}

class _VLine extends StatelessWidget {
  const _VLine();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 34 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
        color: AppColors.hairline,
      );
}

/// زرّا الذيل.
///
/// **وزرُّ المحادثة يُخفى لمن لا معرّفَ لمزوّده** بدل أن يَعِد بفتحٍ يسقط:
/// صفٌّ من قاعدةٍ أقدمَ من هذه النسخة لا يحمل العمود.
class _Actions extends StatelessWidget {
  const _Actions({required this.booking, this.onTap, this.onMessage});
  final Booking booking;
  final VoidCallback? onTap;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final chat = booking.providerId.isEmpty ? null : onMessage;
    return Row(
      children: [
        Expanded(
          child: _Button(
            key: ValueKey('open-${booking.id}'),
            label: tr('عرض الحجز'),
            icon: Icons.chevron_right,
            filled: true,
            onTap: onTap,
          ),
        ),
        if (chat != null) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _Button(
              key: ValueKey('chat-${booking.id}'),
              label: tr('تواصل مع المزوّد'),
              icon: Icons.chat_bubble_outline_rounded,
              filled: false,
              onTap: chat,
            ),
          ),
        ],
      ],
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    super.key,
    required this.label,
    required this.icon,
    required this.filled,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = filled ? AppColors.accentInk : AppColors.accent;
    return Material(
      color: filled ? AppColors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 42 *
              MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5),
          alignment: Alignment.center,
          decoration: filled
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent, width: 1.2),
                ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: ink),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ملخّصُ «حجوزاتي» في صدر الشاشة.
///
/// ── الشكلُ من تصميمٍ أرسله صاحبُ المنصّة ───────────────────────────────────
///
/// قال عن القديمة «ذي صورة مو مناسبة»، ثمّ أرسل تصميماً وقال «تقدر نفس ذي».
/// وفيه: صورةٌ تملأ نصفَ البطاقة وتتلاشى في لونها، وعنوانٌ إلى جانبه قرصٌ
/// فيه العدد، وخيطٌ فاصل، ثمّ «أقرب حجز» بتاريخه، ثمّ قرصان ملوّنان لحالتي
/// الحجز.
///
/// ── والصورةُ من حجزه هو ────────────────────────────────────────────────────
///
/// في تصميمه باقةُ وردٍ — **ولا ملفَّ لها في الشجرة**. فتُملأ بغلاف **أقرب
/// حجزٍ قادم** (`next.coverPath`)، وهو بيانٌ حقيقيٌّ يخصّه ويأتي مع الصفّ
/// بلا نداءٍ ثانٍ. ومن لا غلافَ لحجزه يرى تدرّجاً هادئاً لا مربّعاً مكسوراً.
///
/// ── ولا سهمَ في الزاوية ────────────────────────────────────────────────────
///
/// في تصميمه سهم، **وهو في القديمة كان يُضغط فلا يقع شيء**: البطاقةُ في
/// الشاشة التي تشير إليها، فليس لها ما تفتحه. فتُرك حتى يكون لها وجهةٌ
/// تذهب إليها.
class BookingsSummaryCard extends StatelessWidget {
  const BookingsSummaryCard({super.key, required this.summary});
  final BookingsSummary summary;

  static const _brand = [Color(0xFFA3521A), Color(0xFF6B3208)];

  @override
  Widget build(BuildContext context) {
    final next = summary.next;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: _brand,
          ),
        ),
        child: SizedBox(
          height: 164 *
              MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5),
          // **والغلافُ يُطبَّق لا يُجاور.** لو كان عمودَ `Row` لوقع بينه وبين
          // النصّ حدٌّ مستقيمٌ يُرى — وقد رآه صاحبُ المنصّة في اللقطة. فهو
          // الآن طبقةٌ تحت النصّ تمتدّ إلى ما بعد منتصف البطاقة وتتلاشى
          // بشفافيّتها، فيظهر تدرّجُ البطاقة من تحتها ولا خيطَ.
          child: Stack(
            children: [
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerEnd,
                  widthFactor: 0.52,
                  child: _FadedCover(path: next?.coverPath),
                ),
              ),
              Row(
                children: [
                  Expanded(flex: 63, child: _SummaryText(summary: summary)),
                  const Spacer(flex: 37),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// لوحُ نصّ الملخّص.
class _SummaryText extends StatelessWidget {
  const _SummaryText({required this.summary});
  final BookingsSummary summary;

  @override
  Widget build(BuildContext context) {
    final next = summary.next;
    final soft = Colors.white.withValues(alpha: 0.82);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available_rounded,
                  size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  tr('حجوزاتي'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // **والعددُ في قرصٍ لا في الجملة**: يُلتقط بلمحةٍ ولا يُقرأ.
              _CountBadge(count: summary.count),
            ],
          ),
          const SizedBox(height: 9),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.28)),
          const SizedBox(height: 9),
          if (next == null)
            Text(
              tr('حجوزاتك السابقة محفوظة أدناه'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: soft,
                fontFamilyFallback: arabicFallback,
              ),
            )
          else
            Row(
              children: [
                Text(
                  tr('أقرب حجز'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldOnAccent,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                    width: 1,
                    height: 13,
                    color: Colors.white.withValues(alpha: 0.35)),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    formatDate(next.eventDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamilyFallback: arabicFallback,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          if (summary.count == 0)
            Text(
              tr('ابدأ من «استكشف» واحجز خدمتك القادمة'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: soft,
                fontFamilyFallback: arabicFallback,
              ),
            )
          else
            // **والحالتان قرصان بنقطتين** — واللونُ يفرّقهما قبل النصّ.
            // **وصفٌّ يَضيق لا `Wrap` يفيض**: قرصٌ أعرضُ من البطاقة بخطّ
            // الجهاز الكبير يخرج منها، و`Wrap` لا تُضيّق ابناً واحداً.
            Row(
              children: [
                // **والنصيبُ بقدر الكلمة**: «مؤكّد» كلمةٌ و«بانتظار
                // الموافقة» كلمتان، فقسمةٌ بالسويّة تقصّ الثانية.
                Flexible(
                  flex: 3,
                  child: _DotPill(
                    key: const ValueKey('pill-confirmed'),
                    dot: AppColors.good,
                    text: trf('{0} مؤكّد', ['${summary.confirmed}']),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  flex: 5,
                  child: _DotPill(
                    key: const ValueKey('pill-pending'),
                    dot: AppColors.warning,
                    text: trf('{0} بانتظار الموافقة', ['${summary.pending}']),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// قرصٌ فيه العدد، بإطارٍ ذهبيّ.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.12),
          border: Border.all(color: AppColors.goldOnAccent, width: 1.4),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
}

/// قرصُ حالةٍ بنقطةٍ ملوّنة.
class _DotPill extends StatelessWidget {
  const _DotPill({super.key, required this.dot, required this.text});
  final Color dot;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamilyFallback: arabicFallback,
              ),
            ),
            ),
          ],
        ),
      );
}

/// الصورةُ تتلاشى **بشفافيّتها هي** لا بلوحِ لونٍ فوقها.
///
/// **والفرقُ ليس ذوقاً.** لوحُ التلاشي القديم كان يبدأ بلونٍ **صلب**
/// (`_brand.first`)، ولونُ البطاقة تحتَه **متدرّجٌ قُطريّاً** — فلا يطابقه
/// إلّا في ركنٍ واحد، فيقع عند حدّ اللوح **خيطٌ رأسيٌّ يُرى**. وقد رآه صاحبُ
/// المنصّة في اللقطة واختار (ب).
///
/// فالآن `ShaderMask` بـ`BlendMode.dstIn`: يُضرب في الصورة تدرّجُ شفافيّةٍ
/// فتذوب هي، ويظهر ما تحتها — تدرّجُ البطاقة نفسُه أيّاً كان لونُه عند تلك
/// النقطة. فلا لونَ يُطابَق ولا خيطَ يقع.
///
/// **ومن لا غلافَ لحجزه لا يُرسم له شيء**: تدرّجُ البطاقة وحدَه. وقد كان له
/// لوحٌ أسودُ خفيف، وهو خيطٌ باهتٌ آخر بلا فائدة.
class _FadedCover extends StatelessWidget {
  const _FadedCover({required this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    final url = Api.mediaUrl(path);
    if (url == null) return const SizedBox.shrink();
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: [Color(0x00FFFFFF), Color(0xCCFFFFFF)],
        stops: [0.0, 0.72],
      ).createShader(rect, textDirection: Directionality.of(context)),
      child: MediaThumb(url: url, icon: Icons.photo_camera_back_outlined),
    );
  }
}
