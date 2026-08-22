import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'labels.dart';

/// النزاعات: خصومةٌ على حجزٍ بعينه، تنظر فيها الإدارة.
///
/// **وغيرُ تذكرة الدعم:** التذكرة سؤالٌ للمنصّة عن نفسها — «لا يصلني رمز»،
/// «كيف أضيف خدمة». والنزاع خصومةٌ بين طرفَي حجز، لها رقمُ حجزٍ وطرفان ومبلغٌ
/// قد تأمر الإدارة بإعادته. ولذلك جدولها غيرُ جدولها، وشاشتها غيرُ شاشتها.
///
/// وكان `api_open_dispute` في القاعدة منذ أوّل يوم، والإدارة تقرأ النزاعات من
/// اللوحة — **ولم يكن للعميل بابٌ يفتح منه واحداً**. فمن خُصم منه ولم يُنفَّذ
/// حجزُه لم يجد إلّا تذكرة دعمٍ عامّة، تُقرأ في صفٍّ واحد مع «نسيت كلمتي».

/// قائمةُ نزاعاتي.
class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key, required this.session});
  final Session session;

  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen> {
  late Future<List<Dispute>> _future = Api.myDisputes();

  void _reload() => setState(() {
    _future = Api.myDisputes();
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النزاعات')),
      body: FutureBuilder<List<Dispute>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
          if (snap.hasError) {
            return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
          }
          final rows = snap.data ?? const <Dispute>[];
          if (rows.isEmpty) {
            return const EmptyBlock(
              title: 'لا نزاعات',
              description: 'وهذا هو الأصل. وإن اختلفت مع مقدّم خدمة على حجزٍ '
                  'فافتح نزاعاً من بطاقة الحجز في «حجوزاتي».',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(Space.lg),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.md),
              itemBuilder: (context, i) => _Row(
                dispute: rows[i],
                session: widget.session,
                onBack: _reload,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.dispute, required this.session, required this.onBack});
  final Dispute dispute;
  final Session session;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final d = dispute;
    return AppCard(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DisputeScreen(dispute: d, session: session)),
        );
        onBack();
      },
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                d.subject,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(width: Space.sm),
            StatusBadge(disputeStatusLabel(d.status), color: disputeStatusColor(d.status)),
          ],
        ),
        const SizedBox(height: Space.xs),
        Muted('${disputeCategoryLabel(d.category)} · ${d.providerName}'),
        const SizedBox(height: Space.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Muted(formatRelative(d.createdAt), size: 11),
            Text(
              d.reference,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        // المبلغ المُعاد يُقال في القائمة لا في الداخل وحده: هو خلاصةُ ما وقع،
        // ومن فتح نزاعاً على مالٍ يريد أن يرى مصيره بلا أن يدخل.
        if (d.refundAmount > 0) ...[
          const SizedBox(height: Space.sm),
          Text(
            'أعادت الإدارة ${formatMoney(d.refundAmount)}',
            style: const TextStyle(fontSize: 13, color: AppColors.good, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

/// خيطُ نزاعٍ واحد: ما قيل فيه، وما قرّرته الإدارة.
class DisputeScreen extends StatefulWidget {
  const DisputeScreen({super.key, required this.dispute, required this.session});
  final Dispute dispute;
  final Session session;

  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen> {
  late Future<List<DisputeMessage>> _future;
  final _reply = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;

  /// هل هبطت الشاشة على آخر رسالة بعد آخر تحميل.
  ///
  /// حارسٌ لا زينة: بلا هذا يقع الهبوط في كل إعادة بناء، فيُقفز بالمستخدم إلى
  /// الأسفل كلّما لمس شيئاً وهو يقرأ رسالةً قديمة.
  bool _landed = false;

  @override
  void initState() {
    super.initState();
    _future = Api.disputeMessages(widget.dispute.id);
  }

  void _reload() => setState(() {
    _future = Api.disputeMessages(widget.dispute.id);
    _landed = false;
  });

  /// الهبوط على آخر رسالة — الخيط يُقرأ من أعلى إلى أسفل، وجوابُ الإدارة آخره.
  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty) return;
    setState(() => _busy = true);
    try {
      await Api.replyDispute(
        disputeId: widget.dispute.id,
        body: body,
        // الطرفُ يُحسب من الدور المفتوح لا من نصٍّ يُرسَل: سياسةُ الجدول تقارن
        // `author` بطرفك الحقيقي وترفض ما عداه، فلو أرسل التطبيق غيرَه لسقط
        // الإرسال بلا سببٍ مفهوم.
        asProvider: widget.session.asProvider,
        authorName: widget.session.email,
      );
      _reply.clear();
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dispute;
    return Scaffold(
      appBar: AppBar(title: Text(d.subject, maxLines: 1)),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<DisputeMessage>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
                if (snap.hasError) {
                  return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
                }
                final rows = snap.data ?? const <DisputeMessage>[];
                if (!_landed && rows.isNotEmpty) {
                  _landed = true;
                  _toBottom();
                }
                return ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(Space.lg),
                  children: [
                    _Head(dispute: d),
                    const SizedBox(height: Space.md),
                    for (final m in rows) ...[
                      _Bubble(message: m, asProvider: widget.session.asProvider),
                      const SizedBox(height: Space.md),
                    ],
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            // المحسوم لا يُستقبل ردوداً: القرار وقع، وحقلٌ يكتب فيه المستخدم
            // ثم لا يقرؤه أحد أسوأ من ألّا يُعرض.
            child: d.isOpen
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          decoration: const InputDecoration(hintText: 'أضف ما يوضّح موقفك…'),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      IconButton.filled(
                        onPressed: _busy ? null : _send,
                        icon: const Icon(Icons.send),
                        style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                      ),
                    ],
                  )
                : const Center(child: Muted('حُسم النزاع — لا تُقبل ردودٌ بعده.')),
          ),
        ],
      ),
    );
  }
}

/// بطاقةُ رأس الخيط: رقمُ النزاع والحجز وسببُه، وقرارُ الإدارة إن صدر.
class _Head extends StatelessWidget {
  const _Head({required this.dispute});
  final Dispute dispute;

  @override
  Widget build(BuildContext context) {
    final d = dispute;
    return AppCard(
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('النزاع')),
            StatusBadge(disputeStatusLabel(d.status), color: disputeStatusColor(d.status)),
          ],
        ),
        const SizedBox(height: Space.sm),
        KeyValue('الرقم', d.reference),
        if (d.bookingReference.isNotEmpty) KeyValue('الحجز', d.bookingReference),
        KeyValue('السبب', disputeCategoryLabel(d.category)),
        KeyValue('مقدّم الخدمة', d.providerName),
        if (d.resolution.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: AppColors.good.withValues(alpha: Tint.row),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Muted('قرار الإدارة', size: 11),
                const SizedBox(height: Space.xs),
                Text(d.resolution, style: const TextStyle(height: 1.8, color: AppColors.ink)),
                if (d.refundAmount > 0) ...[
                  const SizedBox(height: Space.sm),
                  Text(
                    'المبلغ المُعاد: ${formatMoney(d.refundAmount)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.good,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// فقاعةُ رسالة. كلامُك على اليمين، وغيرُك على اليسار.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.asProvider});
  final DisputeMessage message;
  final bool asProvider;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final mine = m.author == (asProvider ? 'provider' : 'customer');
    final label = switch (m.author) {
      'admin' => 'الإدارة',
      'provider' => mine ? 'أنت' : 'مقدّم الخدمة',
      _ => mine ? 'أنت' : 'العميل',
    };
    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: Container(
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: mine ? AppColors.surface : AppColors.surface2,
            border: Border.all(color: mine ? AppColors.hairline : AppColors.surface2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Muted('$label · ${formatRelative(m.createdAt)}', size: 11),
              const SizedBox(height: Space.xs),
              Text(m.body, style: const TextStyle(height: 1.8, color: AppColors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// ورقةُ فتح النزاع — سببٌ وعنوانٌ وشرح.
///
/// تُعيد `true` إن فُتح.
Future<bool> openDisputeSheet(BuildContext context, Booking booking) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _OpenSheet(booking: booking),
  );
  return done == true;
}

class _OpenSheet extends StatefulWidget {
  const _OpenSheet({required this.booking});
  final Booking booking;

  @override
  State<_OpenSheet> createState() => _OpenSheetState();
}

class _OpenSheetState extends State<_OpenSheet> {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String _category = 'no_show';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final subject = _subject.text.trim();
    if (subject.length < 4) {
      setState(() => _error = 'اكتب عنواناً يوضّح المشكلة في سطر.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await Api.openDispute(
        bookingId: widget.booking.id,
        subject: subject,
        description: _description.text.trim(),
        category: _category,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = messageOf(e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionTitle('فتح نزاع'),
            const SizedBox(height: Space.xs),
            Muted('${widget.booking.serviceTitle} · ${widget.booking.reference}'),
            const SizedBox(height: Space.lg),
            const Align(alignment: AlignmentDirectional.centerStart, child: Muted('السبب')),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final c in disputeCategories)
                  PickChip(
                    label: c.label,
                    active: _category == c.value,
                    onTap: () => setState(() => _category = c.value),
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            TextField(
              controller: _subject,
              decoration: const InputDecoration(
                labelText: 'العنوان',
                hintText: 'لم تحضر الفرقة ليلة العرس',
              ),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'ماذا حدث؟',
                hintText: 'اذكر التواريخ والمبالغ وما اتُّفق عليه — هذا ما تنظر فيه الإدارة.',
              ),
            ),
            const SizedBox(height: Space.sm),
            const Muted(
              'يصل النزاع إلى إدارة المنصّة، ويرى مقدّم الخدمة ما تكتبه هنا.',
              size: 11,
            ),
            if (_error != null) ...[
              const SizedBox(height: Space.sm),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.critical, fontSize: 13, height: 1.7),
              ),
            ],
            const SizedBox(height: Space.lg),
            FilledButton(onPressed: _busy ? null : _open, child: const Text('افتح النزاع')),
            const SizedBox(height: Space.sm),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('تراجع'),
            ),
          ],
        ),
      ),
    );
  }
}
