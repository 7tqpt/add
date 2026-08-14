import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';

/// إنشاء خطة العرس أو تعديلها.
///
/// شاشة الخطة كانت قراءةً محضة: حالتها الفارغة تصف ما تفعله الخطة ولا تعطي
/// طريقاً إلى إنشائها، فيقف من لا خطة له عند وصفٍ لشيء لا يملكه.
class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({super.key, required this.session, this.plan});
  final Session session;
  final WeddingPlan? plan;

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  late final _title = TextEditingController(text: widget.plan?.title ?? 'خطة العرس');
  late final _guests = TextEditingController(
    text: widget.plan == null ? '' : widget.plan!.guestsCount.toString(),
  );
  late final _budget = TextEditingController(
    text: widget.plan == null ? '' : widget.plan!.budget.toStringAsFixed(0),
  );
  late DateTime? _date = widget.plan == null ? null : DateTime.tryParse(widget.plan!.weddingDate);
  late String? _governorate = widget.plan?.governorate;

  late Future<List<Governorate>> _governorates;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _governorates = Api.governorates();
  }

  @override
  void dispose() {
    _title.dispose();
    _guests.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 30)),
      // الماضي مستبعَد: خطةُ عرسٍ مضى تاريخه لا معنى لها، ومنعُه هنا أوضح من
      // رسالة خطأ بعد الحفظ.
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final guests = int.tryParse(_guests.text.trim()) ?? 0;
    final budget = num.tryParse(_budget.text.trim()) ?? 0;

    if (_title.text.trim().isEmpty || _date == null || _governorate == null) {
      setState(() => _error = 'اكتب اسم الخطة، واختر تاريخ العرس ومحافظته.');
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await Api.savePlan(
        id: widget.plan?.id,
        appUserId: widget.session.appUserId ?? '',
        title: _title.text.trim(),
        weddingDate: _date!.toIso8601String().substring(0, 10),
        governorate: _governorate!,
        guests: guests,
        budget: budget,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.plan == null ? 'خطة جديدة' : 'تعديل الخطة')),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          AppCard(
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'اسم الخطة',
                  hintText: 'عرس أحمد ومريم',
                ),
              ),
              const SizedBox(height: Space.md),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 20),
                label: Text(
                  _date == null
                      ? 'اختر تاريخ العرس'
                      : formatDate(_date!.toIso8601String().substring(0, 10)),
                ),
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: _guests,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'عدد الضيوف'),
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: _budget,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'الميزانية (ر.ي)',
                  hintText: '2000000',
                ),
              ),
              const SizedBox(height: Space.lg),
              const Align(alignment: AlignmentDirectional.centerStart, child: Muted('المحافظة')),
              const SizedBox(height: Space.sm),
              FutureBuilder<List<Governorate>>(
                future: _governorates,
                builder: (context, snap) {
                  final rows = snap.data ?? const <Governorate>[];
                  if (rows.isEmpty) return const Muted('…');
                  return Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final g in rows)
                        PickChip(
                          label: g.name,
                          active: _governorate == g.name,
                          onTap: () => setState(() => _governorate = g.name),
                        ),
                    ],
                  );
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: Space.md),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.critical, fontSize: 13, height: 1.7),
                ),
              ],
              const SizedBox(height: Space.lg),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(widget.plan == null ? 'إنشاء الخطة' : 'حفظ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
