import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';

/// «أريد تقديم خدمة».
///
/// كل من يسجّل يبدأ عميلاً، وهذه الشاشة تضيف له ملفَّ مقدّم خدمة **قيد
/// المراجعة** — لا تحوّله ولا تسحب منه صفة العميل.
class BecomeProviderScreen extends StatefulWidget {
  const BecomeProviderScreen({super.key, required this.session});
  final Session session;
  @override
  State<BecomeProviderScreen> createState() => _BecomeProviderScreenState();
}

class _BecomeProviderScreenState extends State<BecomeProviderScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _bio = TextEditingController();
  String? _governorate;
  final _picked = <String>{};
  late Future<(List<Governorate>, List<ServiceCategory>)> _future;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<Governorate>, List<ServiceCategory>)> _load() async =>
      (await Api.governorates(), await Api.categories());

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _governorate == null ||
        _picked.isEmpty) {
      setState(() => _error = tr('اكتب اسم المنشأة ورقمك، واختر محافظتك وقسماً واحداً على الأقل.'));
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await Api.applyAsProvider(
        businessName: _name.text.trim(),
        phone: _phone.text.trim(),
        bio: _bio.text.trim(),
        governorate: _governorate!,
        categoryIds: _picked.toList(),
      );
      await widget.session.refreshIdentity();
      if (!mounted) return;
      widget.session.switchTo(provider: true);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('تقديم خدمة'))),
      body: FutureBuilder<(List<Governorate>, List<ServiceCategory>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
          if (snap.hasError) return ErrorBlock(message: messageOf(snap.error!));
          final (governorates, categories) = snap.data!;

          return ListView(
            padding: const EdgeInsets.all(Space.lg),
            children: [
              AppCard(
                children: [
                  SectionTitle(tr('سجّل منشأتك')),
                  const SizedBox(height: Space.sm),
                  Text(
                    tr('بعد الإرسال يصير ملفك «قيد المراجعة». ترفع مستنداتك، وحين تقبلها الإدارة تبدأ باستقبال الحجوزات.'),
                    style: TextStyle(height: 1.8),
                  ),
                  const SizedBox(height: Space.lg),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: tr('اسم المنشأة'),
                      hintText: tr('قاعة التاج'),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: tr('رقم التواصل'),
                      hintText: '+967 7XX XXX XXX',
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  TextField(
                    controller: _bio,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: tr('نبذة'),
                      hintText: tr('ماذا تقدّم؟ وما الذي يميّزك؟'),
                    ),
                  ),
                  const SizedBox(height: Space.md),

                  // ── المحافظة ────────────────────────────────────────────
                  //
                  // **قائمةٌ منسدلةٌ لا جدارُ شرائح.** المحافظاتُ عشرون في
                  // `seed.sql`، فكانت تملأ الشاشةَ صفوفاً تُدفع بها بقيّةُ
                  // النموذج تحت الطيّة — ومن فتح الشاشةَ لا يرى زرَّ الإرسال
                  // ولا يعرف كم بقي عليه.
                  //
                  // وهي الصورةُ نفسُها في «عنوان جديد» و«تعديل الملف»: حقلٌ
                  // مغلقٌ بعنوانه. وكانت هذه الشاشةُ وحدَها شاذّةً عنهما.
                  DropdownButtonFormField<String>(
                    initialValue: _governorate,
                    isExpanded: true,
                    // **والعنوانُ يطفو دائماً كجارِه تحته.** حقلُ الأقسام
                    // يحمل نصّاً أبداً فعنوانُه طافٍ، فلو بقي هذا الحقلُ
                    // بعنوانٍ في الداخل لَوقف حقلان متجاوران بشكلين — وهي
                    // فوضى تُقرأ قبل أن تُسمّى. كشفتها لقطةٌ لا اختبار.
                    decoration: InputDecoration(
                      labelText: tr('المحافظة'),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                    hint: Text(
                      tr('اختر محافظتك'),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    items: [
                      for (final g in governorates)
                        DropdownMenuItem<String>(
                          value: g.name,
                          child: Text(g.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _governorate = v),
                  ),
                  const SizedBox(height: Space.lg),

                  // ── الأقسام ─────────────────────────────────────────────
                  //
                  // **وهذه اختيارٌ متعدّد، فلا تصلح لها المنسدلةُ نفسُها:**
                  // قائمةُ المادّة تُغلق عند كلّ اختيار، فمن أراد ثلاثةَ
                  // أقسامٍ فتحها ثلاثاً. فحقلٌ مغلقٌ بصورتها يفتح ورقةً فيها
                  // مربّعاتُ اختيار — يختار ما شاء ثمّ يُغلق مرّةً واحدة.
                  _CategoriesField(
                    all: categories,
                    picked: _picked,
                    onDone: (next) => setState(() {
                      _picked
                        ..clear()
                        ..addAll(next);
                    }),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Space.md),
                    Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 13)),
                  ],
                  const SizedBox(height: Space.lg),
                  FilledButton(onPressed: _busy ? null : _submit, child: Text(tr('إرسال الطلب'))),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// حقلُ الأقسام — مغلقٌ بصورة الاختيار، يفتح ورقةً فيها مربّعاتُ اختيار.
///
/// **ولمَ ورقةٌ لا `DropdownButton`.** المنسدلةُ تُغلق عند كلّ اختيار، وهذه
/// اختيارٌ متعدّد — فمن أراد ثلاثةَ أقسامٍ فتحها ثلاث مرّات. والورقةُ تُفتح
/// مرّةً ويُختار فيها ما شاء.
///
/// وهو `InputDecorator` لا زرّاً: فيرث حدودَ الحقول وعنوانَها من الثيمة،
/// فيقف في صفٍّ واحدٍ مع «المحافظة» فوقه ولا يُقرأ جسماً غريباً.
class _CategoriesField extends StatelessWidget {
  const _CategoriesField({
    required this.all,
    required this.picked,
    required this.onDone,
  });

  final List<ServiceCategory> all;
  final Set<String> picked;
  final ValueChanged<Set<String>> onDone;

  /// ما يُكتب في الحقل المغلق.
  ///
  /// **والأسماءُ ما دامت تُقرأ، ثمّ العدد.** «٣ أقسام» لا يقول أيَّها، ومن
  /// عاد إلى النموذج ليراجعه يريد أن يعرف ما اختار بلا أن يفتح شيئاً.
  String _summary() {
    if (picked.isEmpty) return '';
    final names = all.where((c) => picked.contains(c.id)).map((c) => c.name).toList();
    if (names.length <= 2) return names.join(tr('، '));
    return trf('{0} — و{1} غيرها', [names.first, '${names.length - 1}']);
  }

  Future<void> _open(BuildContext context) async {
    final draft = {...picked};
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => SheetBody(
          title: tr('الأقسام التي تعمل فيها'),
          children: [
            for (final c in all)
              CheckboxListTile(
                value: draft.contains(c.id),
                onChanged: (_) => setSheet(() {
                  if (!draft.remove(c.id)) draft.add(c.id);
                }),
                title: Text(c.name),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            const SizedBox(height: Space.md),
            // **والزرُّ يُطفأ حتى يُختار واحد.** الخادمُ يرفض طلباً بلا قسم،
            // فزرٌّ يُغلق الورقةَ ثمّ يردّه النموذجُ بخطأٍ أسوأُ من زرٍّ
            // مطفأ.
            FilledButton(
              onPressed: draft.isEmpty
                  ? null
                  : () => Navigator.of(sheetContext).pop(true),
              child: Text(tr('تمّ')),
            ),
          ],
        ),
      ),
    );
    if (saved == true) onDone(draft);
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary();
    return InkWell(
      key: const ValueKey('categories-field'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => _open(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: tr('الأقسام التي تعمل فيها'),
          // العنوانُ يعلو الحقلَ دائماً — وإلّا نزل فوق النصّ حين يفرغ.
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          summary.isEmpty ? tr('اختر قسماً واحداً على الأقل') : summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: summary.isEmpty ? AppColors.muted : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
