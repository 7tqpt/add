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

  /// **قسمٌ واحدٌ لا مجموعة.** قرّر صاحبُ المنصّة أنّ المزوّد لا يعمل في
  /// أكثر من قسم: القاعةُ قاعةٌ ولا تطبخ. وكان الحقلُ اختياراً متعدّداً.
  ///
  /// و**القسمُ غيرُ الخدمة**: المزوّدُ يعرض داخلَ قسمه باقاتٍ عدّة
  /// (`provider_services`) — وتلك لم تُمسّ.
  String? _category;
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
        _category == null) {
      setState(() => _error = tr('اكتب اسم المنشأة ورقمك، واختر محافظتك وقسمك.'));
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
        categoryId: _category!,
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
                    key: const ValueKey('governorate-field'),
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

                  // ── القسم ───────────────────────────────────────────────
                  //
                  // **واحدٌ لا أكثر، وقرارُ صاحب المنصّة.** كان اختياراً
                  // متعدّداً بورقةٍ ومربّعاتٍ وزرِّ «تمّ» — فلمّا صار واحداً
                  // سقط ذلك كلُّه، وصار حقلاً كالمحافظة تماماً. وحقلان
                  // متطابقان أهدأ من حقلين يفتحان سطحين مختلفين.
                  DropdownButtonFormField<String>(
                    key: const ValueKey('category-field'),
                    initialValue: _category,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr('القسم الذي تعمل فيه'),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                    hint: Text(
                      tr('اختر قسمك'),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    items: [
                      for (final c in categories)
                        DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _category = v),
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
