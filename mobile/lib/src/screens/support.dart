import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'labels.dart';
import 'ticket.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.session});
  final Session session;
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late Future<List<SupportTicket>> _future;
  bool _composing = false;
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String _category = 'booking';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = Api.myTickets();
  }

  void _reload() => setState(() {
    _future = Api.myTickets();
  });

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subject.text.trim().isEmpty || _body.text.trim().isEmpty) {
      setState(() => _error = 'اكتب الموضوع وتفاصيل المشكلة.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await Api.openTicket(
        subject: _subject.text.trim(),
        body: _body.text.trim(),
        category: _category,
        asProvider: widget.session.asProvider,
      );
      _subject.clear();
      _body.clear();
      if (mounted) setState(() => _composing = false);
      _reload();
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('خدمة العملاء')),
      body: _composing ? _compose() : _list(),
    );
  }

  Widget _compose() => ListView(
    padding: const EdgeInsets.all(Space.lg),
    children: [
      AppCard(
        children: [
          const SectionTitle('تذكرة جديدة'),
          const SizedBox(height: Space.sm),
          const Text(
            'اشرح مشكلتك بالتفصيل، وسيصلك ردّ الإدارة هنا وبإشعار.',
            style: TextStyle(height: 1.7),
          ),
          const SizedBox(height: Space.lg),
          const Align(alignment: AlignmentDirectional.centerStart, child: Muted('التصنيف')),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final c in ticketCategories)
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
              labelText: 'الموضوع',
              hintText: 'خُصم المبلغ ولم يظهر الحجز',
            ),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _body,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'التفاصيل',
              hintText: 'اشرح ما حدث بالتفصيل…',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: Space.md),
            Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 13)),
          ],
          const SizedBox(height: Space.lg),
          FilledButton(onPressed: _busy ? null : _submit, child: const Text('إرسال')),
          TextButton(
            onPressed: () => setState(() => _composing = false),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    ],
  );

  Widget _list() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: FilledButton.icon(
          onPressed: () => setState(() => _composing = true),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('فتح تذكرة جديدة'),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<SupportTicket>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
            if (snap.hasError) {
              return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
            }
            final rows = snap.data ?? const <SupportTicket>[];
            if (rows.isEmpty) {
              return const EmptyBlock(
                title: 'لا تذاكر',
                description: 'لو واجهتك مشكلة، افتح تذكرة وسنردّ عليك.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.md),
              itemBuilder: (context, i) {
                final t = rows[i];
                return AppCard(
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => TicketScreen(ticket: t))),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            t.subject,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        StatusBadge(
                          ticketStatusLabel(t.status),
                          color: switch (t.status) {
                            'resolved' => AppColors.good,
                            'waiting_customer' => AppColors.warning,
                            'closed' => AppColors.muted,
                            _ => AppColors.critical,
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        t.reference,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Muted('آخر حركة ${formatRelative(t.lastMessageAt)}'),
                  ],
                );
              },
            );
          },
        ),
      ),
    ],
  );
}
