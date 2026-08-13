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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = Api.ticketMessages(widget.ticket.id);
  }

  void _reload() => setState(() {
    _future = Api.ticketMessages(widget.ticket.id);
  });

  @override
  void dispose() {
    _reply.dispose();
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
      appBar: AppBar(title: Text(widget.ticket.subject, maxLines: 1)),
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
                return ListView.separated(
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
            child: Row(
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
