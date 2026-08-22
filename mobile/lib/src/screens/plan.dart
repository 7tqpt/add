import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'labels.dart';
import 'plan_editor.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.session});
  final Session session;
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late Future<List<WeddingPlan>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.myPlans();
  }

  void _reload() => setState(() {
    _future = Api.myPlans();
  });

  Future<void> _edit([WeddingPlan? plan]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlanEditorScreen(session: widget.session, plan: plan),
      ),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WeddingPlan>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
        if (snap.hasError) {
          return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
        }
        final rows = snap.data ?? const <WeddingPlan>[];
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyBlock(
                    title: 'لا خطة بعد',
                    description: 'خطة العرس تجمع حجوزاتك وتحسب لك المتبقّي من ميزانيتك.',
                  ),
                  const SizedBox(height: Space.lg),
                  FilledButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('أنشئ خطتك'),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            Space.lg, glassHeaderTop(context), Space.lg, glassNavSpace),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: Space.md),
          itemBuilder: (context, i) {
            final p = rows[i];
            final ratio = p.budget > 0 ? (p.totalCost / p.budget).clamp(0.0, 1.0) : 0.0;
            final over = p.budget > 0 && p.totalCost > p.budget;
            return AppCard(
              children: [
                Row(
                  children: [
                    Expanded(child: SectionTitle(p.title)),
                    // الحالة تُقرأ من الخطّة لا تُفترض: خطةٌ ملغاة كانت تظهر
                    // «قيد التجهيز» لأن النصّ كان مكتوباً في الشاشة.
                    StatusBadge(planStatusLabel(p.status), color: planStatusColor(p.status)),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Muted(
                  '${formatDate(p.weddingDate)} · ${p.governorate} · ${formatCount(p.guestsCount, guestForms)}',
                ),
                const SizedBox(height: Space.md),
                // شريط الميزانية: النسبة تُقرأ بلمحة، والأرقام تحته للدقّة.
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio.toDouble(),
                    minHeight: 8,
                    backgroundColor: AppColors.surface2,
                    valueColor: AlwaysStoppedAnimation(
                      over ? AppColors.critical : AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: Space.sm),
                KeyValue('الميزانية', formatMoney(p.budget)),
                KeyValue('إجمالي الحجوزات', formatMoney(p.totalCost)),
                KeyValue('المدفوع', formatMoney(p.paidAmount)),
                KeyValue('المتبقّي عليك', formatMoney(p.remainingAmount)),
                if (over) ...[
                  const SizedBox(height: Space.sm),
                  Text(
                    'تجاوزت الميزانية بـ ${formatMoney(p.totalCost - p.budget)}.',
                    style: const TextStyle(color: AppColors.critical, fontSize: 13),
                  ),
                ],
                const SizedBox(height: Space.md),
                OutlinedButton(onPressed: () => _edit(p), child: const Text('تعديل الخطة')),
              ],
            );
          },
        );
      },
    );
  }
}
