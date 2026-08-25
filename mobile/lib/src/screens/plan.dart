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

/// منظِّم حفل الزفاف.
///
/// **وكانت أربعة أرقام:** تاريخٌ وميزانيةٌ وعددُ ضيوفٍ ومحافظة، تُملأ مرّةً
/// ثم لا يعود إليها أحد. والعرس ليس أربعة أرقام — هو ثلاثون شيئاً يجب أن
/// يُفعل قبل يومٍ بعينه. فمن لا يجد قائمةً هنا يكتبها في مذكّرة جواله،
/// ويخرج تجهيزُ العرس من المنصّة ويبقى فيها الحجزُ وحده.
///
/// والترتيب من أعلى إلى أسفل ترتيبُ ما يُسأل عنه: **كم بقي؟** ثم **أين
/// وصلت؟** ثم **ما التالي؟** ثم الأرقام لمن أرادها.
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
                    description:
                        'خطة العرس تجمع حجوزاتك، وتحسب المتبقّي من ميزانيتك، '
                        'وتفتح لك قائمة تجهيزٍ تشطبها مهمّةً مهمّة.',
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
          separatorBuilder: (_, _) => const SizedBox(height: Space.xl),
          itemBuilder: (context, i) => _PlanBlock(
            key: ValueKey(rows[i].id),
            plan: rows[i],
            onEdit: () => _edit(rows[i]),
          ),
        );
      },
    );
  }
}

class _PlanBlock extends StatefulWidget {
  const _PlanBlock({super.key, required this.plan, required this.onEdit});
  final WeddingPlan plan;
  final VoidCallback onEdit;

  @override
  State<_PlanBlock> createState() => _PlanBlockState();
}

class _PlanBlockState extends State<_PlanBlock> {
  late Future<(PlanProgress, List<PlanTask>)> _future;
  final _newTask = TextEditingController();

  /// المهامّ المشطوبة مطويّة أوّلاً.
  ///
  /// قائمةٌ من عشرين نصفُها منجَز تدفن **ما بقي** تحت ما انتهى. والمطلوب من
  /// الشاشة أن تقول «ما التالي؟» لا أن تعرض أرشيفاً.
  bool _showDone = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _newTask.dispose();
    super.dispose();
  }

  Future<(PlanProgress, List<PlanTask>)> _load() async {
    final progress = await Api.planProgress(widget.plan.id);
    final tasks = await Api.planTasks(widget.plan.id);
    return (progress, tasks);
  }

  void _reload() => setState(() {
    _future = _load();
  });

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageOf(e))));
    }
  }

  Future<void> _add() async {
    final title = _newTask.text.trim();
    if (title.isEmpty) return;
    _newTask.clear();
    await _run(() => Api.addPlanTask(widget.plan.id, title));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final days = daysUntil(p.weddingDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CountdownCard(plan: p, days: days),
        const SizedBox(height: Space.md),
        FutureBuilder<(PlanProgress, List<PlanTask>)>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: Space.xl),
                child: LoadingBlock(),
              );
            }
            if (snap.hasError) {
              return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
            }
            final (progress, tasks) = snap.data!;
            final left = tasks.where((t) => !t.done).toList();
            final done = tasks.where((t) => t.done).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProgressCard(progress: progress),
                const SizedBox(height: Space.md),
                _Tiles(plan: p, progress: progress),
                const SizedBox(height: Space.md),

                // ── قائمة التجهيز ──────────────────────────────────────────
                AppCard(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: SectionTitle('قائمة التجهيز')),
                        if (done.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() => _showDone = !_showDone),
                            child: Text(_showDone
                                ? 'إخفاء المنجَز'
                                : 'المنجَز (${done.length})'),
                          ),
                      ],
                    ),
                    if (tasks.isEmpty) ...[
                      const SizedBox(height: Space.sm),
                      // قاعدةٌ لم يُشغَّل عليها `plan_tasks.sql` بعد: تنقص
                      // ميزةٌ ولا تسقط شاشة.
                      const Muted('لم تُفتح قائمة التجهيز بعد. أضف أول مهمّة بنفسك.'),
                    ],
                    for (final t in left) _TaskRow(
                      task: t,
                      onToggle: () => _run(() => Api.togglePlanTask(t.id)),
                      onDelete: () => _run(() => Api.deletePlanTask(t.id)),
                    ),
                    if (left.isEmpty && tasks.isNotEmpty) ...[
                      const SizedBox(height: Space.sm),
                      const Text(
                        'انتهى كل شيء — مبارك!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.good,
                        ),
                      ),
                    ],
                    if (_showDone)
                      for (final t in done) _TaskRow(
                        task: t,
                        onToggle: () => _run(() => Api.togglePlanTask(t.id)),
                        onDelete: () => _run(() => Api.deletePlanTask(t.id)),
                      ),

                    const SizedBox(height: Space.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newTask,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _add(),
                            decoration: const InputDecoration(
                              hintText: 'أضف مهمّة…',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        IconButton.filled(
                          onPressed: _add,
                          tooltip: 'أضف',
                          icon: const Icon(Icons.add, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),

        const SizedBox(height: Space.md),
        _MoneyCard(plan: p, onEdit: widget.onEdit),
      ],
    );
  }
}

/// العدُّ التنازلي — أكبرُ رقمٍ في الشاشة لأنه أوّلُ ما يُسأل عنه.
class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.plan, required this.days});
  final WeddingPlan plan;
  final int? days;

  @override
  Widget build(BuildContext context) {
    final passed = days != null && days! < 0;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.accentLift, AppColors.accentDeep],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamilyFallback: arabicFallback,
                        ),
                      ),
                    ),
                    StatusBadge(planStatusLabel(plan.status), color: Colors.white),
                  ],
                ),
                const SizedBox(height: Space.md),
                // الرقمُ وحدَه ثمّ وحدتُه: «٤٥» ثم «يوماً على العرس» — عينٌ
                // تمرّ على الشاشة تلتقط الرقم قبل أن تقرأ سطراً.
                Text(
                  passed ? '—' : '${days ?? 0}',
                  style: const TextStyle(
                    fontSize: 44,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
                Text(
                  countdownLabel(days),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldOnAccent,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
                const SizedBox(height: Space.sm),
                Text(
                  [
                    formatDate(plan.weddingDate),
                    if (plan.governorate.isNotEmpty) plan.governorate,
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Icon(
            Icons.favorite_rounded,
            size: 56,
            color: AppColors.goldOnAccent.withValues(alpha: 0.65),
          ),
        ],
      ),
    );
  }
}

/// التقدّمُ الكلّي — نسبةٌ **محسوبةٌ من المشطوب** لا مكتوبة.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});
  final PlanProgress progress;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('التقدّم الكلّي')),
            Text(
              '${progress.percent}٪',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.percent / 100,
            minHeight: 10,
            backgroundColor: AppColors.surface2,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
        const SizedBox(height: Space.sm),
        Muted(
          progress.tasksTotal == 0
              ? 'لا مهامّ بعد'
              : progress.tasksLeft == 0
                  ? 'لم يبقَ شيء'
                  : 'بقيت ${formatCount(progress.tasksLeft, taskForms)} '
                    'من ${progress.tasksTotal}',
        ),
      ],
    );
  }
}

/// أربعُ مربّعاتٍ: ما يُسأل عنه بلمحة.
class _Tiles extends StatelessWidget {
  const _Tiles({required this.plan, required this.progress});
  final WeddingPlan plan;
  final PlanProgress progress;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (
        Icons.checklist_rounded,
        'المهامّ',
        progress.tasksTotal == 0 ? '—' : '${progress.tasksLeft} متبقّية',
      ),
      (Icons.account_balance_wallet_outlined, 'الميزانية', formatMoney(plan.budget)),
      (
        Icons.event_available_outlined,
        'المواعيد',
        progress.upcomingBookings == 0 ? 'لا مواعيد' : '${progress.upcomingBookings} قادمة',
      ),
      (Icons.groups_outlined, 'قائمة الضيوف', formatCount(plan.guestsCount, guestForms)),
    ];

    // شبكةٌ بعمودين تلتفّ: `GridView` بنسبةٍ ثابتة يقصّ النصّ على الشاشات
    // الضيّقة، و`Wrap` بعرضٍ محسوب يترك كل مربّعٍ يأخذ ارتفاعه.
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - Space.md) / 2;
        return Wrap(
          spacing: Space.md,
          runSpacing: Space.md,
          children: [
            for (final (icon, label, value) in tiles)
              SizedBox(
                width: w,
                child: AppCard(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withValues(alpha: Tint.disc),
                          ),
                          child: Icon(icon, size: 18, color: AppColors.accent),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(child: Muted(label, maxLines: 1)),
                      ],
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.onToggle, required this.onDelete});
  final PlanTask task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: task.done,
              onChanged: (_) => onToggle(),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 14,
                  color: task.done ? AppColors.muted : AppColors.ink,
                  // الشطبُ خطٌّ لا لونٌ وحده: اللون يُقرأ «باهت» على شاشةٍ
                  // في الشمس، والخطّ يُقرأ «انتهت» في كل ضوء.
                  decoration: task.done ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.muted,
                ),
              ),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: 'احذف المهمّة',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// الأرقام — آخرَ الشاشة لا أوّلها: تُقرأ حين تُطلب.
class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.plan, required this.onEdit});
  final WeddingPlan plan;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    final ratio = p.budget > 0 ? (p.totalCost / p.budget).clamp(0.0, 1.0) : 0.0;
    final over = p.budget > 0 && p.totalCost > p.budget;

    return AppCard(
      children: [
        const SectionTitle('الميزانية'),
        const SizedBox(height: Space.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.toDouble(),
            minHeight: 8,
            backgroundColor: AppColors.surface2,
            valueColor: AlwaysStoppedAnimation(over ? AppColors.critical : AppColors.gold),
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
        OutlinedButton(onPressed: onEdit, child: const Text('تعديل الخطة')),
      ],
    );
  }
}
