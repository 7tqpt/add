import 'package:flutter/material.dart';


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
            ? 'قُبل الحجز — أُغلق اليوم في تقويمك ووصل العميل إشعار.'
            : 'رُفض الحجز — أُعيد للعميل كل ما دفعه.',
      );
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _complete(String id) async {
    setState(() => _busyId = id);
    try {
      await Api.completeBooking(id);
      if (!mounted) return;
      showMessage(context, 'سُجّل تنفيذ الحجز، وفُتح للعميل باب التقييم.');
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
        if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
        if (snap.hasError) {
          return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
        }
        final rows = snap.data ?? const <Booking>[];
        if (rows.isEmpty) {
          return const EmptyBlock(
            title: 'لا طلبات بعد',
            description: 'ستصلك هنا حجوزات العملاء على خدماتك بعد توثيق ملفك.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              Space.lg, glassHeaderTop(context), Space.lg, Space.lg),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.md),
            itemBuilder: (context, i) {
              final b = rows[i];
              final busy = _busyId == b.id;
              return FadeSlideIn(index: i, child: AppCard(
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
                  Muted('${b.userName} · ${formatCount(b.guestsCount, guestForms)}'),
                  const SizedBox(height: Space.sm),
                  Text(
                    b.eventTime == null
                        ? formatDate(b.eventDate)
                        : '${formatDate(b.eventDate)} · ${formatTime(b.eventTime)}',
                    style: const TextStyle(fontSize: 14, color: AppColors.ink2),
                  ),
                  const SizedBox(height: Space.xs),
                  Muted(b.address),
                  // ── الموقع ────────────────────────────────────────────
                  //
                  // **وهذا هو سببُ الميزة كلِّها.** العنوانُ نصٌّ يكفي من
                  // يعرف الحيّ، ولا يكفي مصوّراً من محافظةٍ أخرى يبحث عن
                  // البيت ليلةَ العرس فيتّصل بالعروس ليسأل عن الطريق.
                  //
                  // ولا يُعرض إن لم يحدّد العميلُ موقعاً: زرٌّ يفتح خريطةً
                  // على نقطةٍ لا وجود لها أسوأُ من غيابه.
                  if (b.point != null) ...[
                    const SizedBox(height: Space.xs),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: ValueKey('open-map-${b.id}'),
                        onPressed: () => openMap(context, b.point!),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('افتح الموقع في الخرائط'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: Space.sm),
                  Text(
                    formatMoney(b.totalPrice),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                  if (b.status == BookingStatus.pendingProvider) ...[
                    const SizedBox(height: Space.md),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: busy ? null : () => _respond(b.id, true),
                            child: const Text('قبول'),
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy ? null : () => _respond(b.id, false),
                            child: const Text('اعتذار'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (b.status == BookingStatus.confirmed) ...[
                    const SizedBox(height: Space.md),
                    OutlinedButton(
                      onPressed: busy ? null : () => _complete(b.id),
                      child: const Text('تأكيد التنفيذ'),
                    ),
                  ],
                  const SizedBox(height: Space.sm),
                  // على كل حجزٍ مهما كانت حاله: قبل القبول يُسأل العميل عن
                  // تفصيلٍ ناقص، وبعده يُذكَّر بالعربون أو بموعد المعاينة.
                  // والاعتذارُ نفسه أهونُ إذا سبقته كلمة.
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _message(b),
                    icon: const Icon(Icons.forum_outlined, size: 19),
                    label: Text('راسل ${b.userName}'),
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


