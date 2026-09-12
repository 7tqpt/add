import 'package:flutter/material.dart';

import '../core/i18n.dart';
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
  late final _title = TextEditingController(text: widget.plan?.title ?? tr('خطة العرس'));
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
      setState(() => _error = tr('اكتب اسم الخطة، واختر تاريخ العرس ومحافظته.'));
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
      appBar: AppBar(title: Text(widget.plan == null ? tr('خطة جديدة') : tr('تعديل الخطة'))),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          AppCard(
            children: [
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: tr('اسم الخطة'),
                  hintText: tr('عرس أحمد ومريم'),
                ),
              ),
              const SizedBox(height: Space.md),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 20),
                label: Text(
                  _date == null
                      ? tr('اختر تاريخ العرس')
                      : formatDate(_date!.toIso8601String().substring(0, 10)),
                ),
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: _guests,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: tr('عدد الضيوف')),
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: _budget,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: tr('الميزانية (ر.ي)'),
                  hintText: '2000000',
                ),
              ),
              const SizedBox(height: Space.md),
              // **جدارُ الشرائح سقط.** عشرون محافظةً كنّ يملأن البطاقةَ
              // ويدفعن «إنشاء الخطة» إلى أسفلها، فلا يُرى النموذجُ كلُّه في
              // شاشةٍ واحدة. وهو آخرُ جدارٍ للمحافظات في التطبيق.
              //
              // **وعنوانُ الحقل يطفو** فيبقى «المحافظة» مقروءاً بعد الاختيار:
              // كان سطراً منفصلاً فوق الجدار، فصار عنوانَ الحقل نفسِه.
              FutureBuilder<List<Governorate>>(
                future: _governorates,
                builder: (context, snap) {
                  final rows = snap.data ?? const <Governorate>[];
                  // **والقيمةُ لا تُمرَّر إلّا إن كانت في القائمة.** الخطّةُ
                  // المعدَّلةُ تحمل محافظتَها قبل أن تصل القائمةُ من الخادم،
                  // ومنسدلةٌ قيمتُها ليست في خياراتها تُسقط الشاشةَ بدعوى.
                  final value =
                      rows.any((g) => g.name == _governorate) ? _governorate : null;
                  return DropdownButtonFormField<String>(
                    key: const ValueKey('plan-governorate-field'),
                    initialValue: value,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr('المحافظة'),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                    hint: Text(
                      rows.isEmpty ? '…' : tr('اختر محافظة العرس'),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    items: [
                      for (final g in rows)
                        DropdownMenuItem<String>(
                          value: g.name,
                          child: Text(g.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    // **ولا تُفتح فارغةً وهي تُحمَّل**: منسدلةٌ تُضغط فلا
                    // تُظهر شيئاً تُقرأ عاطلة.
                    onChanged: rows.isEmpty
                        ? null
                        : (v) => setState(() => _governorate = v),
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
                child: Text(widget.plan == null ? tr('إنشاء الخطة') : tr('حفظ')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
