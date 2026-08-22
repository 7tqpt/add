import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key, required this.ticket});
  final SupportTicket ticket;
  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  late Future<List<SupportMessage>> _future;
  final _reply = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;

  /// هل هبطت الشاشة على آخر رسالة بعد آخر تحميل.
  ///
  /// حارسٌ لا زينة: بلا هذا يقع الهبوط في كل إعادة بناء، فيُقفز بالمستخدم
  /// إلى الأسفل كلّما لمس شيئاً وهو يقرأ رسالةً قديمة.
  bool _landed = false;

  /// الحالة تُتابَع محلّياً بعد الإغلاق: الشاشة لا تعيد جلب التذكرة نفسها،
  /// فبلا ذلك يبقى زرّ الإغلاق ظاهراً بعد الضغط.
  late String _status = widget.ticket.status;

  /// المغلقة وحدها. و«resolved» ليست منها: القاعدة تقبل الردّ عليها فتُعيد
  /// فتحها، فإخفاء حقل الردّ عندها يقطع طريقاً مشروعاً على من لم تُحلّ مشكلته.
  bool get _closed => _status == 'closed';

  Future<void> _close() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إغلاق التذكرة'),
        content: const Text(
          'أغلقها إن حُلّت مشكلتك. تبقى المحادثة محفوظة، ويمكنك فتح تذكرة جديدة متى شئت.',
          style: TextStyle(height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('أغلقها'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await Api.closeTicket(widget.ticket.id);
      if (!mounted) return;
      setState(() => _status = 'closed');
      showMessage(context, 'أُغلقت التذكرة.');
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _future = Api.ticketMessages(widget.ticket.id);
  }

  void _reload() => setState(() {
    _future = Api.ticketMessages(widget.ticket.id);
    _landed = false;
  });

  /// الهبوط على آخر رسالة.
  ///
  /// **ولماذا لزم:** التذكرة تُقرأ الآن من أعلى إلى أسفل — الأقدم أوّلاً —
  /// فمن فتحها بلا هذا وجد **شكواه هو** أمامه، وردُّ الإدارة تحت الطيّة. وهو
  /// جوابُ ما فتح التذكرة لأجله.
  ///
  /// وبعد الإطار لا فيه: الشريط لم يُقَس بعدُ أثناء البناء، فالقفز إليه الآن
  /// يقع إلى حدٍّ قديم ويقف قبل آخر رسالة.
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
    if (_reply.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await Api.replyTicket(widget.ticket.id, _reply.text.trim());
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ticket.subject, maxLines: 1),
        actions: [
          if (!_closed) TextButton(onPressed: _busy ? null : _close, child: const Text('إغلاق')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<SupportMessage>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
                if (snap.hasError) {
                  return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
                }
                final rows = snap.data ?? const <SupportMessage>[];
                if (!_landed && rows.isNotEmpty) {
                  _landed = true;
                  _toBottom();
                }
                return ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.all(Space.lg),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                  itemBuilder: (context, i) {
                    final m = rows[i];
                    final mine = m.author != 'admin';
                    return Align(
                      // رسائلك على اليمين والإدارة على اليسار — كترتيب المحادثة
                      // العربية، فيُعرف صاحب الكلام بلا قراءة الاسم.
                      alignment: mine
                          ? AlignmentDirectional.centerStart
                          : AlignmentDirectional.centerEnd,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.82,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(Space.md),
                          decoration: BoxDecoration(
                            color: mine ? AppColors.surface : AppColors.surface2,
                            border: Border.all(
                              color: mine ? AppColors.hairline : AppColors.surface2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Muted(
                                '${mine ? 'أنت' : 'الإدارة'} · ${formatRelative(m.createdAt)}',
                                size: 11,
                              ),
                              const SizedBox(height: Space.xs),
                              Text(
                                m.body,
                                style: const TextStyle(height: 1.8, color: AppColors.ink),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
            // المغلقة لا تُستقبل ردوداً — القاعدة ترفضها. وعرضُ حقلٍ يكتب فيه
            // المستخدم ثم يُرفض ما كتبه أسوأ من ألّا يُعرض.
            child: _closed
                ? const Center(child: Muted('التذكرة مغلقة — افتح تذكرة جديدة إن عادت المشكلة.'))
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          decoration: const InputDecoration(hintText: 'اكتب ردّك…'),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      IconButton.filled(
                        onPressed: _busy ? null : _send,
                        icon: const Icon(Icons.send),
                        style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
