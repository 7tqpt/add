import 'package:flutter/material.dart';

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
      setState(() => _error = 'اكتب اسم المنشأة ورقمك، واختر محافظتك وقسماً واحداً على الأقل.');
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
      appBar: AppBar(title: const Text('تقديم خدمة')),
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
                  const SectionTitle('سجّل منشأتك'),
                  const SizedBox(height: Space.sm),
                  const Text(
                    'بعد الإرسال يصير ملفك «قيد المراجعة». ترفع مستنداتك، وحين تقبلها الإدارة تبدأ باستقبال الحجوزات.',
                    style: TextStyle(height: 1.8),
                  ),
                  const SizedBox(height: Space.lg),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'اسم المنشأة',
                      hintText: 'قاعة التاج',
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'رقم التواصل',
                      hintText: '+967 7XX XXX XXX',
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  TextField(
                    controller: _bio,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'نبذة',
                      hintText: 'ماذا تقدّم؟ وما الذي يميّزك؟',
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Muted('المحافظة'),
                  ),
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final g in governorates)
                        PickChip(
                          label: g.name,
                          active: _governorate == g.name,
                          onTap: () => setState(() => _governorate = g.name),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Muted('الأقسام التي تعمل فيها'),
                  ),
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final c in categories)
                        PickChip(
                          label: c.name,
                          active: _picked.contains(c.id),
                          onTap: () => setState(() {
                            if (!_picked.remove(c.id)) _picked.add(c.id);
                          }),
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Space.md),
                    Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 13)),
                  ],
                  const SizedBox(height: Space.lg),
                  FilledButton(onPressed: _busy ? null : _submit, child: const Text('إرسال الطلب')),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
