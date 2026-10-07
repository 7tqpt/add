import 'package:flutter/material.dart';


import '../core/i18n.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/motion.dart';
import '../ui/kit.dart';
import '../ui/map_open.dart';
import 'chat.dart';
import 'labels.dart';
import 'provider_wallet.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key, required this.session});
  final Session session;
  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  late Future<List<Booking>> _future;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Booking>> _load() {
    final id = widget.session.providerId;
    return id == null ? Future.value(const []) : Api.providerRequests(id);
  }

  void _reload() => setState(() {
    _future = _load();
  });

  /// يفتح المحادثة مع صاحب الحجز ثم يدخلها.
  ///
  /// والمدخل حجزٌ لا عميل: لا يفتح صاحب القاعة محادثةً مع من لم يتعامل معه —
  /// والقاعدة هي التي تتحقّق، لا هذه الشاشة.
  Future<void> _message(Booking booking) async {
    setState(() => _busyId = booking.id);
    try {
      final id = await Api.openConversationWithCustomer(booking.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: id,
            otherName: booking.userName,
            mySide: ChatSide.provider,
          ),
        ),
      );
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _respond(String id, bool accept) async {
    setState(() => _busyId = id);
    try {
      await Api.respondToBooking(id, accept);
      if (!mounted) return;
      showMessage(
        context,
        accept
            ? tr('قُبل الحجز — أُغلق اليوم في تقويمك ووصل العميل إشعار.')
            : tr('رُفض الحجز — أُعيد للعميل كل ما دفعه.'),
      );
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// المزوّد يطلب اعتمادَ التنفيذ — بسؤالٍ قبله.
  ///
  /// **ولا يُتمّ الحجزَ بنفسه.** `api_complete_booking` صارت للإدارة وحدَها،
  /// وهذا الطلبُ يختم وقتاً لا غير. فلو نُودي من ملفِّ APK مفكوكٍ ألفَ مرّةٍ
  /// لم يتحرّك ريالٌ واحد.
  ///
  /// والسؤالُ يقول ما سيقع — لا «هل أنت متأكّد؟» وحدَها: من لا يعرف أنّ
  /// مالَه ينتظر مراجعةً يظنّ التطبيقَ معطوباً حين لا يصله شيء.
  Future<void> _requestCompletion(String id) async {
    final ok = await confirmChoice(
      context,
      title: tr('تأكيد التنفيذ'),
      body: tr('هل أنت متأكّد أنّ الحجز نُفِّذ؟ يُرسَل إلى الإدارة للمراجعة، '
          'وتُحتسب مستحقّاتك بعد موافقتها.'),
      confirm: tr('نعم، نُفِّذ'),
      cancel: tr('لا'),
      tone: AppColors.good,
    );
    if (ok != true || !mounted) return;

    setState(() => _busyId = id);
    try {
      await Api.requestCompletion(id);
      if (!mounted) return;
      showMessage(context, tr('أُرسل إلى الإدارة للمراجعة.'));
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Booking>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SkeletonList(rows: 3);
        }
        if (snap.hasError) {
          return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
        }
        final rows = snap.data ?? const <Booking>[];
        if (rows.isEmpty) {
          return EmptyBlock(
            title: tr('لا طلبات بعد'),
            description: tr('ستصلك هنا حجوزات العملاء على خدماتك بعد توثيق ملفك.'),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            // **وآخرُ الطلبات فوق الزجاج لا تحته** — الشريطُ السفليُّ يطفو
            // فوق المحتوى، فبلا هذه المسافة اختفى آخرُ طلبٍ خلفه.
            padding: EdgeInsets.fromLTRB(
              Space.lg, glassHeaderTop(context), Space.lg, glassNavSpace),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.md),
            itemBuilder: (context, i) {
              final b = rows[i];
              final busy = _busyId == b.id;
              return FadeSlideIn(index: i, child: AppCard(
                children: [
                  CardTitleBar(
                    b.serviceTitle,
                    badge: bookingStatusLabel(b.status),
                    badgeColor: bookingStatusColor(b.status),
                    badgeIcon: bookingStatusIcon(b.status),
                    icon: Icons.apartment_rounded,
                  ),
                  const SizedBox(height: Space.sm),
                  const Divider(height: 1, color: AppColors.hairline),
                  const SizedBox(height: Space.sm),
                  // **وكلُّ سطرٍ بأيقونته** — كما في تصميم صاحب المنصّة:
                  // البطاقةُ تُمسح بالعين مسحاً، والأيقونةُ تقول ما نوعُ
                  // السطر قبل أن يُقرأ.
                  _Fact(
                    Icons.person_outline_rounded,
                    '${b.userName} · ${formatCount(b.guestsCount, guestForms)}',
                  ),
                  _Fact(
                    Icons.calendar_today_rounded,
                    b.eventTime == null
                        ? formatDate(b.eventDate)
                        : '${formatDate(b.eventDate)} · ${formatTime(b.eventTime)}',
                  ),
                  if (b.address.isNotEmpty)
                    _Fact(Icons.place_outlined, b.address),
                  // ── الموقع ────────────────────────────────────────────
                  //
                  // **وهذا هو سببُ الميزة كلِّها.** العنوانُ نصٌّ يكفي من
                  // يعرف الحيّ، ولا يكفي مصوّراً من محافظةٍ أخرى يبحث عن
                  // البيت ليلةَ العرس فيتّصل بالعروس ليسأل عن الطريق.
                  //
                  // ولا يُعرض إن لم يحدّد العميلُ موقعاً: زرٌّ يفتح خريطةً
                  // على نقطةٍ لا وجود لها أسوأُ من غيابه.
                  if (b.point != null) ...[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: ValueKey('open-map-${b.id}'),
                        onPressed: () => openMap(context, b.point!),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: Text(tr('افتح الموقع في الخرائط')),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: Space.sm),
                  const Divider(height: 1, color: AppColors.hairline),
                  const SizedBox(height: Space.sm),
                  // **والمبلغُ يُقال ما هو** — رقمٌ عارٍ في بطاقةٍ فيها عددُ
                  // ضيوفٍ وتاريخٌ يُقرأ على غير وجهه.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Muted(tr('المبلغ الإجمالي')),
                      Flexible(
                        child: Text(
                          formatMoney(b.totalPrice),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (b.status == BookingStatus.pendingProvider) ...[
                    const SizedBox(height: Space.md),
                    Row(
                      children: [
                        Expanded(
                          // **طَفليٌّ لا نبيذيّ** — كما في تصميم صاحب
                          // المنصّة، وقد عُرض عليه أنّه يفترق عن كلّ زرٍّ
                          // مملوءٍ في التطبيق فاختار تصميمَه كما أرسله.
                          child: FilledButton(
                            onPressed: busy ? null : () => _respond(b.id, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brand,
                            ),
                            child: Text(tr('قبول')),
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy ? null : () => _respond(b.id, false),
                            child: Text(tr('اعتذار')),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // ── المؤكَّد: طلبُ اعتمادٍ، أو انتظارُ الإدارة ──────────
                  if (b.status == BookingStatus.confirmed) ...[
                    const SizedBox(height: Space.md),
                    if (b.awaitingCompletionReview)
                      const _ReviewBar()
                    else ...[
                      // **وسببُ الردّ فوق الزرّ لا تحته.** من رُدّ طلبُه
                      // ولم يرَ السببَ أعاده كما هو، فيدور الطابورُ على
                      // نفسه.
                      if (b.completionRejectReason.isNotEmpty) ...[
                        _RejectNote(b.completionRejectReason),
                        const SizedBox(height: Space.sm),
                      ],
                      FilledButton(
                        key: ValueKey('request-completion-${b.id}'),
                        onPressed:
                            busy ? null : () => _requestCompletion(b.id),
                        // أخضرُ لا نبيذيّ: ختمُ عملٍ تمّ لا بابٌ إلى شيء.
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.good,
                        ),
                        child: Text(tr('تأكيد التنفيذ')),
                      ),
                    ],
                  ],
                  const SizedBox(height: Space.sm),
                  // ── قاعُ البطاقة: خبرٌ أو باب ──────────────────────────
                  //
                  // **والمنفَّذُ وحدَه يُختم ولا يُراسَل من هنا.** طلب صاحبُ
                  // المنصّة ذلك واختار من ثلاثةِ أشكالٍ عُرضت عليه:
                  // **(ب) شريطٌ أخضرُ مصبوغ** — يملأ مكانَ الزرّ الذاهب فلا
                  // يبقى القاعُ ناقصاً.
                  //
                  // **وما دون المنفَّذ يبقى له بابُه مهما كانت حاله:** قبل
                  // القبول يُسأل العميل عن تفصيلٍ ناقص، وبعده يُذكَّر
                  // بالعربون أو بموعد المعاينة. والاعتذارُ نفسه أهونُ إذا
                  // سبقته كلمة.
                  //
                  // **والمحادثةُ لا تضيع بعد الختم** — تبقى في «الرسائل»،
                  // لكنّها تبعد خطوتين. وقد قيل له ذلك قبل أن يختار.
                  if (b.status == BookingStatus.completed)
                    _DoneBar(session: widget.session)
                  else
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _message(b),
                      icon: const Icon(Icons.forum_outlined, size: 19),
                      label: Text(trf('راسل {0}', [b.userName])),
                    ),
                ],
              ));
            },
          ),
        );
      },
    );
  }
}



/// خَتمُ الحجز المنفَّذ — شريطٌ أخضرُ مصبوغٌ في قاع البطاقة، **ويُضغط**.
///
/// اختار صاحبُ المنصّة الشكلَ **(ب)** من ثلاثةٍ عُرضت عليه، ثمّ طلب أن يصير
/// باباً: «خلّه قابل للضغط وعند ضغط يروح للمستحقات».
///
/// **والسهمُ هو ما يقول إنّه باب.** شريطٌ يُضغط بلا علامةٍ تدلّ عليه لا
/// يعرفه أحد، فيبقى الطريقُ إلى المستحقّات مقفولاً وهو مفتوح.
///
/// **والأيقونةُ لا تحمل المعنى وحدَها:** «تم تنفيذ الحجز» مكتوبةٌ إلى
/// جانبها، فمن لا يفرّق الأخضرَ من الأحمر يقرؤها — وهي العادةُ نفسُها في
/// `StatusBadge`.
class _DoneBar extends StatelessWidget {
  const _DoneBar({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) => Material(
    // صبغةٌ خفيفةٌ لا خضرةٌ صمّاء: القاعُ يُملأ ولا يُصرَخ به، والحجزُ
    // المنفَّذُ خبرٌ انتهى لا شيءٌ يُنتظر.
    color: AppColors.good.withValues(alpha: Tint.chip),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      key: const ValueKey('booking-done'),
      borderRadius: BorderRadius.circular(12),
      // **وإلى «رصيد فرحتي»** — «عند ضغط يروح للمستحقات»، ومستحقُّ الحجز
      // المنفَّذ صار يدخل الرصيدَ حين يُعتمد التنفيذ (لا تسويةً شهريّة).
      // والشاشةُ تبني `Scaffold` لنفسها بعنوانٍ وسهمِ رجوع.
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProviderWalletScreen()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 20, color: AppColors.good),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                tr('تم تنفيذ الحجز'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.good,
                ),
              ),
            ),
            Text(
              tr('رصيد فرحتي'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.good,
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.good),
          ],
        ),
      ),
    ),
  );
}

/// ما بين ضغطِ المزوّد وموافقةِ الإدارة.
///
/// **وكهرمانيٌّ لا أخضر:** الأخضرُ يقول «تمّ»، وهذا لم يتمّ بعد. ولو
/// تشابها لَظنّ المزوّدُ أنّ مالَه احتُسب فلا يسأل حين يتأخّر.
class _ReviewBar extends StatelessWidget {
  const _ReviewBar();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('booking-under-review'),
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: Tint.chip),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.hourglass_top, size: 20, color: AppColors.warning),
        const SizedBox(width: Space.sm),
        Flexible(
          child: Text(
            tr('قيد مراجعة الإدارة'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
            ),
          ),
        ),
      ],
    ),
  );
}

/// سببُ ردِّ الإدارة لطلب الاعتماد — يُعرض فوق الزرّ ليُقرأ قبل أن يُعاد.
class _RejectNote extends StatelessWidget {
  const _RejectNote(this.reason);

  final String reason;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('completion-rejected'),
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: AppColors.critical.withValues(alpha: Tint.chip),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 20, color: AppColors.critical),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('رُدَّ طلبُ اعتماد التنفيذ'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.critical,
                ),
              ),
              const SizedBox(height: 2),
              // **والسببُ نصُّ الإدارة لا يُترجَم:** كتبه إنسانٌ بلغته.
              Text(
                reason,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.ink2,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


/// سطرُ حقيقةٍ في بطاقة الطلب: أيقونةٌ باهتةٌ ونصُّها.
class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: AppColors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: AppColors.ink2,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
            ),
          ],
        ),
      );
}
