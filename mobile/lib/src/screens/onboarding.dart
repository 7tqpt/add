import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';

/// إكمال الملف — مرة واحدة بعد أول تسجيل.
///
/// بلا صفٍّ في `app_users` لا يستطيع الحساب أن يحجز ولا أن يفتح تذكرة: كل دوال
/// الـ API تبدأ بالبحث عنه. فالشاشة شرطُ عملٍ لا ترحيبٌ تجميلي.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.session});
  final Session session;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _governorate;
  late Future<List<Governorate>> _future;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = Api.governorates();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty || _governorate == null) {
      setState(() => _error = 'اكتب اسمك ورقمك واختر محافظتك.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await Api.registerProfile(
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        governorate: _governorate!,
        platform: Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android',
      );
      await widget.session.refreshIdentity();
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أكمل ملفك')),
      body: FutureBuilder<List<Governorate>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
          final governorates = snap.data ?? const <Governorate>[];
          return ListView(
            padding: const EdgeInsets.all(Space.lg),
            children: [
              AppCard(
                children: [
                  const SectionTitle('أهلاً بك'),
                  const SizedBox(height: Space.sm),
                  const Text(
                    'عرّفنا بنفسك لنكمل حجوزاتك ونتواصل معك عند الحاجة.',
                    style: TextStyle(height: 1.7),
                  ),
                  const SizedBox(height: Space.lg),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل',
                      hintText: 'محمد الصنعاني',
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'رقم الجوال',
                      hintText: '+967 7XX XXX XXX',
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
                  if (_error != null) ...[
                    const SizedBox(height: Space.md),
                    Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 13)),
                  ],
                  const SizedBox(height: Space.lg),
                  FilledButton(onPressed: _busy ? null : _submit, child: const Text('متابعة')),
                ],
              ),
              const SizedBox(height: Space.md),
              TextButton(
                onPressed: () => widget.session.signOut(),
                child: const Text('تسجيل الخروج'),
              ),
            ],
          );
        },
      ),
    );
  }
}
